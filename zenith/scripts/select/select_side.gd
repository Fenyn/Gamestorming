class_name SelectSide
extends PanelContainer
## One player's column on the select screen: name, one tile per shipped deck, and the chosen
## deck's duelist, Aspects, and Life Deck make-up. Tiles are spawned per deck.

signal deck_chosen(player: int, deck: DeckList)
signal name_changed(player: int, player_name: String)

const ASPECT_ROW_MIN: float = 24.0
const HOVER_SCALE: float = 1.05
const FLIP_TIME: float = 0.11
const TYPE_ORDER: Array[CardDef.Type] = [
	CardDef.Type.STRIKE, CardDef.Type.ART, CardDef.Type.COMBAT, CardDef.Type.NON_COMBAT,
	CardDef.Type.DRILL, CardDef.Type.ALLY, CardDef.Type.SEAL, CardDef.Type.GROUNDS,
]

@onready var tag: Label = $Column/Header/Tag
@onready var name_edit: LineEdit = $Column/Header/Name
@onready var tiles: VBoxContainer = $Column/Tiles
@onready var empty: Label = $Column/Empty
@onready var detail: PanelContainer = $Column/Detail
@onready var portrait: TextureRect = $Column/Detail/Row/PortraitBox/Portrait
@onready var portrait_caption: Label = $Column/Detail/Row/PortraitBox/Caption
@onready var duelist_label: Label = $Column/Detail/Row/Info/Duelist
@onready var school_chip: Label = $Column/Detail/Row/Info/Chips/School
@onready var alignment_chip: Label = $Column/Detail/Row/Info/Chips/Alignment
@onready var mastery_chip: Label = $Column/Detail/Row/Info/Chips/Mastery
@onready var archetype_chip: Label = $Column/Detail/Row/Info/Chips/Archetype
@onready var plan_label: Label = $Column/Detail/Row/Info/Plan
@onready var might_tile: StatTile = $Column/Detail/Row/Info/Stats/Might
@onready var surge_tile: StatTile = $Column/Detail/Row/Info/Stats/Surge
@onready var life_tile: StatTile = $Column/Detail/Row/Info/Stats/Life
@onready var pages_tile: StatTile = $Column/Detail/Row/Info/Stats/Pages
@onready var aspects_box: VBoxContainer = $Column/Detail/Row/Info/Aspects
@onready var comp_header: Label = $Column/Detail/Row/Info/CompHeader
@onready var comp_bar: HBoxContainer = $Column/Detail/Row/Info/CompBar
@onready var comp_legend: HFlowContainer = $Column/Detail/Row/Info/CompLegend
@onready var side_cards: Label = $Column/Detail/Row/Info/SideCards
@onready var problems_label: Label = $Column/Detail/Row/Info/Problems

var player: int = 0
var _decks: Array[DeckList] = []
var _faces: CardFaceCache = null
var _might_max: int = 1
var _group: ButtonGroup = ButtonGroup.new()
var _tile_buttons: Array[Button] = []
var _deck: DeckList = null            # the deck on show
var _aspect: int = 1                    # the duelist aspect the portrait shows
var _aspect_names: Dictionary = {}      # aspect -> its name label in the aspect rows
var _hovered: bool = false
var _hover_tween: Tween = null
var _flip_tween: Tween = null


func setup(index: int, decks: Array[DeckList], faces: CardFaceCache, might_max: int) -> void:
	player = index
	_decks = decks
	_faces = faces
	_might_max = maxi(1, might_max)
	tag.text = "PLAYER %d" % (index + 1)
	name_edit.text = Session.player_names[index]
	name_edit.text_changed.connect(func(t: String) -> void:
		Session.player_names[index] = t if t.strip_edges() != "" else "Player %d" % (index + 1)
		name_changed.emit(index, Session.player_names[index]))
	for child in tiles.get_children():
		child.queue_free()
	_tile_buttons.clear()
	for i in range(decks.size()):
		var b: Button = _make_tile(decks[i])
		var pos: int = i
		b.pressed.connect(func() -> void: select(pos))
		tiles.add_child(b)
		_tile_buttons.append(b)
	detail.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.BORDER, 12, 1, 16, 14))
	if not portrait.gui_input.is_connected(_on_portrait_input):
		portrait.gui_input.connect(_on_portrait_input)
		portrait.mouse_entered.connect(func() -> void: _hover_portrait(true))
		portrait.mouse_exited.connect(func() -> void: _hover_portrait(false))


## The portrait lifts a little under the pointer, the way a hand card does, so it reads as
## something to click.
func _hover_portrait(over: bool) -> void:
	_hovered = over
	portrait.pivot_offset = portrait.size * 0.5
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(portrait, "scale", Vector2.ONE * (HOVER_SCALE if over else 1.0), 0.12)
	_hover_tween.tween_property(portrait, "modulate", Color(1.08, 1.08, 1.08) if over else Color.WHITE, 0.12)
	portrait_caption.add_theme_color_override("font_color", ZenithTheme.ACCENT if over else ZenithTheme.MUTED)


## The portrait cycles through the duelist's aspects on click, so every face can be read before
## the duel; the matching row in the aspect list lights up.
func _on_portrait_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var aspects: Array[int] = _shown_aspects()
		if aspects.size() < 2:
			return
		show_aspect(aspects[(aspects.find(_aspect) + 1) % aspects.size()], true)


## Aspects the deck plays with, lowest first.
func _shown_aspects() -> Array[int]:
	var out: Array[int] = []
	var duelist: CardDef = Session.library.defs.get(_deck.duelist_id) if _deck != null else null
	if duelist == null:
		return out
	for t in duelist.aspects:
		var aspect: int = int(t.get("aspect", 0))
		if aspect <= _deck.aspects:
			out.append(aspect)
	out.sort()
	return out


## With `flip`, the card turns edge-on, swaps its face and turns back, as a card being turned
## over; a fresh deck pick just shows the face.
func show_aspect(aspect: int, flip: bool = false) -> void:
	var duelist: CardDef = Session.library.defs.get(_deck.duelist_id) if _deck != null else null
	if duelist == null:
		portrait.texture = null
		portrait_caption.text = ""
		return
	_aspect = aspect
	var aspects: Array[int] = _shown_aspects()
	var last: bool = aspects.size() < 2
	portrait_caption.text = CardText.aspect_name(aspect, duelist) + ("" if last else "  ·  click for the next aspect")
	for t in _aspect_names.keys():
		var l: Label = _aspect_names[t]
		l.add_theme_color_override("font_color", ZenithTheme.ACCENT if int(t) == aspect else ZenithTheme.TEXT)
	var face: Texture2D = await _faces.render_face(duelist, aspect)
	if _aspect != aspect:
		return   # another click or pick came in while the face rendered
	if not flip:
		portrait.texture = face
		return
	if _flip_tween != null:
		_flip_tween.kill()
	portrait.pivot_offset = portrait.size * 0.5
	var rest: float = HOVER_SCALE if _hovered else 1.0
	_flip_tween = create_tween()
	_flip_tween.tween_property(portrait, "scale:x", 0.0, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flip_tween.tween_callback(func() -> void: portrait.texture = face)
	_flip_tween.tween_property(portrait, "scale:x", rest, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func select(pos: int) -> void:
	if pos < 0 or pos >= _decks.size():
		return
	_tile_buttons[pos].button_pressed = true
	var deck: DeckList = _decks[pos]
	_show(deck)
	deck_chosen.emit(player, deck)


## Online: the other seat is chosen by the other client, so this column only reflects it.
func set_locked(locked: bool, tag_text: String) -> void:
	tag.text = tag_text
	name_edit.editable = not locked
	for b in _tile_buttons:
		b.disabled = locked
	empty.text = "Waiting for them to pick a duelist." if locked else "Pick a duelist to see their deck."


## Reflect the other client's name without emitting name_changed.
func show_name(player_name: String) -> void:
	if name_edit.text != player_name:
		name_edit.text = player_name
	Session.player_names[player] = player_name


func _make_tile(d: DeckList) -> Button:
	var b: Button = Button.new()
	b.theme_type_variation = &"TileButton"
	b.toggle_mode = true
	b.button_group = _group
	b.custom_minimum_size = Vector2(0, 46)
	var duelist: CardDef = Session.library.defs.get(d.duelist_id)
	var school_color: Color = Palette.school_ui(d.style)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.offset_top = 3
	row.offset_bottom = -3
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	var stripe: Panel = Panel.new()
	stripe.custom_minimum_size = Vector2(5, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.add_theme_stylebox_override("panel", ZenithTheme.box(school_color, Color(0, 0, 0, 0), 3, 0, 0, 0))
	row.add_child(stripe)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	var deck_name: Label = Label.new()
	deck_name.text = d.name
	deck_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_name.add_theme_font_size_override("font_size", 16)
	col.add_child(deck_name)
	var sub: Label = Label.new()
	sub.text = "%s  ·  %s %s  ·  %d Aspects" % [
		duelist.title if duelist != null else d.duelist_id,
		CardText.school_name(d.style), d.alignment.capitalize(), d.aspects]
	if Archetype.label(d.archetype) != "":
		sub.text = "%s  ·  %s" % [Archetype.label(d.archetype), sub.text]
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.theme_type_variation = &"MutedLabel"
	col.add_child(sub)
	row.add_child(col)
	var school: Label = Label.new()
	school.text = CardText.school_name(d.style).to_upper()
	school.mouse_filter = Control.MOUSE_FILTER_IGNORE
	school.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	school.add_theme_font_size_override("font_size", 12)
	ZenithTheme.chip(school, school_color)
	row.add_child(school)
	b.add_child(row)
	return b


func _show(d: DeckList) -> void:
	var lib: CardLibrary = Session.library
	var duelist: CardDef = lib.defs.get(d.duelist_id)
	empty.visible = false
	detail.visible = true
	var school_color: Color = Palette.school_ui(d.style)
	duelist_label.text = duelist.title if duelist != null else d.duelist_id
	school_chip.text = CardText.school_name(d.style)
	ZenithTheme.chip(school_chip, school_color)
	alignment_chip.text = d.alignment.capitalize()
	ZenithTheme.chip(alignment_chip, ZenithTheme.MUTED)
	mastery_chip.visible = d.mastery_id != ""
	mastery_chip.text = "Mastery"
	ZenithTheme.chip(mastery_chip, ZenithTheme.ACCENT)
	archetype_chip.visible = Archetype.label(d.archetype) != ""
	archetype_chip.text = Archetype.label(d.archetype)
	ZenithTheme.chip(archetype_chip, ZenithTheme.DEFEND)
	var plan_parts: PackedStringArray = PackedStringArray()
	if Archetype.plan(d.archetype) != "":
		plan_parts.append(Archetype.plan(d.archetype))
	if not d.subthemes.is_empty():
		plan_parts.append("Focus: %s." % ", ".join(Archetype.subtheme_labels(d.subthemes)))
	if d.difficulty != "":
		plan_parts.append("%s to play." % d.difficulty.capitalize())
	plan_label.visible = not plan_parts.is_empty()
	plan_label.text = " ".join(plan_parts)
	_deck = d
	_fill_stats(duelist, d)
	_fill_aspects(duelist, d.aspects)
	show_aspect(duelist.lowest_aspect() if duelist != null else 1)
	_fill_composition(d, lib)
	var sides: PackedStringArray = PackedStringArray()
	if d.mastery_id != "":
		sides.append(_title(lib, d.mastery_id))
	if d.grimoire_id != "":
		sides.append("%s with %d Pages cards" % [_title(lib, d.grimoire_id), d.pages.size()])
	side_cards.text = "  ·  ".join(sides) if not sides.is_empty() else "None"
	var problems: Array[String] = Session.deck_problems(d)
	problems_label.visible = not problems.is_empty()
	problems_label.text = "\n".join(problems)


func _title(lib: CardLibrary, id: String) -> String:
	var def: CardDef = lib.defs.get(id)
	return def.title if def != null else id


## The four numbers that set a deck's ceiling: top Might, starting Surge, deck size, Pages.
func _fill_stats(duelist: CardDef, d: DeckList) -> void:
	var top_might: int = 0
	var top_aspect: int = 0
	var first_surge: int = 0
	if duelist != null:
		for t in duelist.aspects:
			var aspect: int = int(t.get("aspect", 0))
			if aspect > d.aspects:
				continue
			var might: Array = t.get("might", [])
			var top: int = int(might[might.size() - 1]) if might.size() > 0 else 0
			if top > top_might:
				top_might = top
				top_aspect = aspect
			if aspect == duelist.lowest_aspect():
				first_surge = int(t.get("surge", 0))
	might_tile.set_stat("Top Might", CardText.short_number(top_might), "at %s" % CardText.aspect_name(top_aspect, duelist), ZenithTheme.MIGHT)
	surge_tile.set_stat("Surge", str(first_surge), "Energy per turn", ZenithTheme.ENERGY)
	life_tile.set_stat("Life Deck", str(d.cards.size()), "cards", ZenithTheme.TEXT)
	pages_tile.set_stat("Pages", str(d.pages.size()), "swap-in cards", ZenithTheme.TEXT)


func _fill_aspects(duelist: CardDef, aspects: int) -> void:
	for child in aspects_box.get_children():
		child.queue_free()
	_aspect_names.clear()
	if duelist == null:
		return
	for t in duelist.aspects:
		var aspect: int = int(t.get("aspect", 0))
		if aspect > aspects:
			break
		var might: Array = t.get("might", [])
		var top: int = int(might[might.size() - 1]) if might.size() > 0 else 0
		var row: HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, ASPECT_ROW_MIN)
		row.add_theme_constant_override("separation", 10)
		var name_label: Label = Label.new()
		name_label.text = CardText.aspect_name(aspect, duelist)
		name_label.custom_minimum_size = Vector2(92, 0)
		row.add_child(name_label)
		_aspect_names[aspect] = name_label
		var surge: Label = Label.new()
		surge.text = "Surge %d" % int(t.get("surge", 0))
		surge.custom_minimum_size = Vector2(64, 0)
		surge.theme_type_variation = &"MutedLabel"
		row.add_child(surge)
		var bar: ProgressBar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = _might_max
		bar.value = top
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("fill", ZenithTheme.box(ZenithTheme.MIGHT, Color(0, 0, 0, 0), 4, 0, 0, 0))
		row.add_child(bar)
		var value: Label = Label.new()
		value.text = CardText.short_number(top)
		value.custom_minimum_size = Vector2(64, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_color_override("font_color", ZenithTheme.MIGHT)
		row.add_child(value)
		aspects_box.add_child(row)


## Icon plus "Strike 53", in the type's colour, so the legend matches the bar and the faces.
func _legend_entry(type: CardDef.Type, n: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var icon: TypeIcon = TypeIcon.new()
	icon.custom_minimum_size = Vector2(14, 14)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.type = type
	icon.color = Palette.type_ui(type)
	row.add_child(icon)
	var label: Label = Label.new()
	label.text = "%s %d" % [CardText.TYPE_LABELS[type], n]
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	return row


func _fill_composition(d: DeckList, lib: CardLibrary) -> void:
	for child in comp_bar.get_children():
		child.queue_free()
	var counts: Dictionary = {}
	for id in d.cards:
		var def: CardDef = lib.defs.get(id)
		if def == null:
			continue
		counts[def.type] = int(counts.get(def.type, 0)) + 1
	for type in TYPE_ORDER:
		var n: int = int(counts.get(type, 0))
		if n == 0:
			continue
		var seg: Panel = Panel.new()
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_stretch_ratio = float(n)
		seg.add_theme_stylebox_override("panel", ZenithTheme.box(Palette.type_ui(type), Color(0, 0, 0, 0), 3, 0, 0, 0))
		seg.tooltip_text = "%s %d" % [CardText.TYPE_LABELS[type], n]
		comp_bar.add_child(seg)
	comp_header.text = "LIFE DECK  ·  %d CARDS" % d.cards.size()
	for child in comp_legend.get_children():
		child.queue_free()
	for type in TYPE_ORDER:
		var n: int = int(counts.get(type, 0))
		if n > 0:
			comp_legend.add_child(_legend_entry(type, n))
