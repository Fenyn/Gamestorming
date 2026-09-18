class_name DeckInfo
extends VBoxContainer
## What a deck is made of: the four headline numbers, the Aspect ladder with Surge and top
## Might per Aspect, the Life Deck make-up by card type, the Mastery and Relic, and any
## validator problems. Shared by the select screen and the matchup screen.

signal aspect_clicked(aspect: int)

const ASPECT_ROW_MIN: float = 24.0
const TYPE_ORDER: Array[CardDef.Type] = [
	CardDef.Type.STRIKE, CardDef.Type.ART, CardDef.Type.COMBAT, CardDef.Type.NON_COMBAT,
	CardDef.Type.DRILL, CardDef.Type.ALLY, CardDef.Type.SEAL, CardDef.Type.GROUNDS,
]

@onready var might_tile: StatTile = $Stats/Might
@onready var surge_tile: StatTile = $Stats/Surge
@onready var life_tile: StatTile = $Stats/Life
@onready var reserve_tile: StatTile = $Stats/Reserve
@onready var aspects_box: HBoxContainer = $Aspects
@onready var comp_header: Label = $CompHeader
@onready var comp_bar: HBoxContainer = $CompBar
@onready var comp_legend: HFlowContainer = $CompLegend
@onready var key_cards: HFlowContainer = $KeyCards
@onready var problems_label: Label = $Problems

const KEY_CARD_SIZE: Vector2 = Vector2(128, 179)
const KEY_CARD_ZOOM: Vector2 = Vector2(300, 420)
const KEY_CARD_MAX: int = 8
const NAME_SKIP: Array[String] = ["the", "dame", "sir"]

var _aspect_names: Dictionary = {}      # aspect -> its name label in the aspect chips
var _aspect_chips: Dictionary = {}      # aspect -> its chip button
var _chip_group: ButtonGroup = ButtonGroup.new()
var _key_generation: int = 0            # bumps per show_deck so a slow render never lands on a newer deck
var _zoom: TextureRect = null           # the hovered key card at readable size, following the pointer


## Mirrors the flowing rows for a sheet that reads right to left.
func set_mirrored(on: bool) -> void:
	key_cards.alignment = FlowContainer.ALIGNMENT_END if on else FlowContainer.ALIGNMENT_BEGIN
	comp_legend.alignment = FlowContainer.ALIGNMENT_END if on else FlowContainer.ALIGNMENT_BEGIN


## `might_max` is the highest top Might among all shipped decks, so the bars compare across decks.
## `faces` renders the key card row, up to `key_max` faces; pass null to leave it out.
func show_deck(d: DeckList, might_max: int, faces: CardFaceCache = null, key_max: int = KEY_CARD_MAX) -> void:
	var lib: CardLibrary = Session.library
	var duelist: CardDef = lib.defs.get(d.duelist_id)
	_fill_stats(duelist, d)
	_fill_aspects(duelist, d.aspects, maxi(1, might_max))
	_fill_composition(d, lib)
	_fill_key_cards(d, duelist, lib, faces, key_max)
	var problems: Array[String] = Session.deck_problems(d)
	problems_label.visible = not problems.is_empty()
	problems_label.text = "\n".join(problems)


## Lights the chip of the Aspect on show.
func highlight_aspect(aspect: int) -> void:
	for t in _aspect_names.keys():
		var l: Label = _aspect_names[t]
		l.add_theme_color_override("font_color", ZenithTheme.ACCENT if int(t) == aspect else ZenithTheme.TEXT)
	# Every chip is set here, not just the one being lit. A ButtonGroup only clears its siblings
	# when the press goes through the button, and `set_pressed_no_signal` goes around it, so
	# lighting one this way used to leave every earlier one lit as well.
	for t in _aspect_chips.keys():
		(_aspect_chips[t] as Button).set_pressed_no_signal(int(t) == aspect)


## Highest Might any shipped duelist reaches within its deck's aspects.
static func might_max_of(decks: Array[DeckList]) -> int:
	var best: int = 1
	for d in decks:
		var def: CardDef = Session.library.defs.get(d.duelist_id)
		if def == null:
			continue
		for t in def.aspects:
			if int(t.get("aspect", 0)) > d.aspects:
				continue
			var might: Array = t.get("might", [])
			if might.size() > 0:
				best = maxi(best, int(might[might.size() - 1]))
	return best


## The Mastery, the Relic, then the duelist's signature cards (any card whose title carries a
## word of the duelist's name), in deck order, up to `key_max` faces.
func _key_card_ids(d: DeckList, duelist: CardDef, lib: CardLibrary, key_max: int) -> Array[String]:
	var ids: Array[String] = []
	for id in [d.mastery_id, d.relic_id]:
		if id != "" and lib.defs.has(id):
			ids.append(id)
	var words: Array[String] = []
	if duelist != null:
		for w in duelist.title.split(" "):
			if w.length() >= 3 and not NAME_SKIP.has(w.to_lower()):
				words.append(w)
	for id in d.cards:
		if ids.has(id) or ids.size() >= key_max:
			continue
		var def: CardDef = lib.defs.get(id)
		if def == null:
			continue
		for w in words:
			if def.title.contains(w):
				ids.append(id)
				break
	return ids


func _fill_key_cards(d: DeckList, duelist: CardDef, lib: CardLibrary, faces: CardFaceCache, key_max: int) -> void:
	_key_generation += 1
	var generation: int = _key_generation
	for child in key_cards.get_children():
		child.queue_free()
	var ids: Array[String] = _key_card_ids(d, duelist, lib, key_max)
	key_cards.visible = faces != null and not ids.is_empty()
	$KeyHeader.visible = key_cards.visible
	if faces == null:
		return
	for id in ids:
		var def: CardDef = lib.defs.get(id)
		var rect: TextureRect = TextureRect.new()
		rect.custom_minimum_size = KEY_CARD_SIZE
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_entered.connect(func() -> void: _show_zoom(rect))
		rect.mouse_exited.connect(_hide_zoom)
		key_cards.add_child(rect)
		var face: Texture2D = await faces.render_face(def)
		if generation != _key_generation:
			return   # a newer deck took over while this face rendered
		rect.texture = face


## A readable copy of the hovered card, drawn over everything and kept inside the window.
func _show_zoom(rect: TextureRect) -> void:
	if _zoom == null:
		_zoom = TextureRect.new()
		_zoom.top_level = true
		_zoom.z_index = 100
		_zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_zoom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_zoom.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_zoom.size = KEY_CARD_ZOOM
		add_child(_zoom)
	_zoom.texture = rect.texture
	_zoom.visible = rect.texture != null
	_place_zoom(rect)


func _place_zoom(rect: TextureRect) -> void:
	var view: Vector2 = get_viewport_rect().size
	var origin: Vector2 = rect.global_position
	var pos: Vector2 = Vector2(origin.x + rect.size.x + 8, origin.y + rect.size.y * 0.5 - KEY_CARD_ZOOM.y * 0.5)
	if pos.x + KEY_CARD_ZOOM.x > view.x:
		pos.x = origin.x - KEY_CARD_ZOOM.x - 8
	pos.y = clampf(pos.y, 8.0, view.y - KEY_CARD_ZOOM.y - 8.0)
	_zoom.global_position = pos


func _hide_zoom() -> void:
	if _zoom != null:
		_zoom.visible = false


## The four numbers that set a deck's ceiling: top Might, starting Surge, deck size, Reserve.
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
	reserve_tile.set_stat("Reserve", str(d.reserve.size()), "swap-in cards", ZenithTheme.TEXT)


## One chip per Aspect the deck plays with: the title, then Surge and top Might beneath it.
## Clicking a chip asks the screen to show that Aspect.
func _fill_aspects(duelist: CardDef, aspects: int, _might_max: int) -> void:
	for child in aspects_box.get_children():
		child.queue_free()
	_aspect_names.clear()
	_aspect_chips.clear()
	if duelist == null:
		return
	for t in duelist.aspects:
		var aspect: int = int(t.get("aspect", 0))
		if aspect > aspects:
			break
		var might: Array = t.get("might", [])
		var top: int = int(might[might.size() - 1]) if might.size() > 0 else 0
		var chip: Button = Button.new()
		chip.theme_type_variation = &"TileButton"
		chip.toggle_mode = true
		chip.button_group = _chip_group
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(72, 44)   # the labels clip, so five chips always fit the column
		chip.pressed.connect(func() -> void: aspect_clicked.emit(aspect))
		var col: VBoxContainer = VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 10
		col.offset_right = -10
		col.offset_top = 4
		col.offset_bottom = -4
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 0)
		var name_label: Label = Label.new()
		name_label.text = CardText.aspect_name(aspect, duelist)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_label)
		_aspect_names[aspect] = name_label
		var nums: HBoxContainer = HBoxContainer.new()
		nums.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var surge: Label = Label.new()
		surge.text = "Surge %d" % int(t.get("surge", 0))
		surge.theme_type_variation = &"MutedLabel"
		surge.add_theme_font_size_override("font_size", 12)
		surge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		surge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		surge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nums.add_child(surge)
		var value: Label = Label.new()
		value.text = CardText.short_number(top)
		value.add_theme_font_size_override("font_size", 12)
		value.add_theme_color_override("font_color", ZenithTheme.MIGHT)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nums.add_child(value)
		col.add_child(nums)
		chip.add_child(col)
		aspects_box.add_child(chip)
		_aspect_chips[aspect] = chip


## Icon plus "Strike 53", in the type's colour, so the legend matches the bar and the faces.
func _legend_entry(type: CardDef.Type, n: int) -> Control:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	var icon: TypeIcon = TypeIcon.new()
	icon.custom_minimum_size = Vector2(14, 14)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.type = type
	icon.color = Palette.type_ui(type)
	line.add_child(icon)
	var label: Label = Label.new()
	label.text = "%s %d" % [CardText.TYPE_LABELS[type], n]
	label.add_theme_font_size_override("font_size", 13)
	line.add_child(label)
	return line


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
