class_name DeckInfo
extends VBoxContainer
## What a deck is made of: the four headline numbers, the Aspect ladder with Surge and top
## Might per Aspect, the Life Deck make-up by card type, the Mastery and Relic, and any
## validator problems. Shared by the select screen and the matchup screen.

signal aspect_clicked(aspect: int)

const ASPECT_ROW_MIN: float = 24.0
const TYPE_ORDER: Array[CardDef.Type] = [
	CardDef.Type.STRIKE, CardDef.Type.ART, CardDef.Type.COMBAT, CardDef.Type.NON_COMBAT,
	CardDef.Type.DRILL, CardDef.Type.PERSONALITY, CardDef.Type.SEAL, CardDef.Type.GROUNDS,
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

const KEY_CARD_SIZE: Vector2 = Vector2(160, 224)
const KEY_CARD_ZOOM: Vector2 = Vector2(380, 532)
const KEY_CARD_MAX: int = 3
const NAME_SKIP: Array[String] = ["the", "dame", "sir"]

var _aspect_names: Dictionary = {}      # aspect -> its name label in the aspect chips
var _aspect_chips: Dictionary = {}      # aspect -> its chip button
var _chip_group: ButtonGroup = ButtonGroup.new()
var _key_generation: int = 0            # bumps per show_deck so a slow render never lands on a newer deck
var _zoom: TextureRect = null           # the hovered key card at readable size, following the pointer
var _duelist: CardDef = null
var _stack: PersonalityStack = null   # the Duelist's Aspect cards, one per tier


func _ready() -> void:
	# Reuse the stat API, but let the resources read as emblems on the character sheet.
	for tile: StatTile in [might_tile, surge_tile, life_tile, reserve_tile]:
		var space: StyleBoxEmpty = StyleBoxEmpty.new()
		space.content_margin_left = 6
		space.content_margin_right = 6
		space.content_margin_top = 4
		space.content_margin_bottom = 5
		tile.add_theme_stylebox_override("panel", space)
		tile.value_label.add_theme_font_size_override("font_size", ZenithTheme.SIZE_GROUP if tile == might_tile or tile == surge_tile else ZenithTheme.SIZE_ROW)
		tile.name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(tile.get_node("Column") as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		if tile == life_tile or tile == reserve_tile:
			tile.size_flags_stretch_ratio = 0.8
		else:
			tile.size_flags_stretch_ratio = 1.2
	might_tile.draw.connect(_draw_might_crest)
	might_tile.resized.connect(might_tile.queue_redraw)
	might_tile.value_label.resized.connect(might_tile.queue_redraw)
	surge_tile.pips_box.alignment = BoxContainer.ALIGNMENT_CENTER
	surge_tile.pips_box.add_theme_constant_override("separation", 4)


func _draw_might_crest() -> void:
	var value: Label = might_tile.value_label
	var center: Vector2 = value.position + (value.get_parent() as Control).position + value.size * 0.5
	var half_width: float = minf(might_tile.size.x * 0.44, 62.0)
	var half_height: float = value.size.y * 0.46
	var points: PackedVector2Array = PackedVector2Array([center + Vector2(0, -half_height), center + Vector2(half_width, 0), center + Vector2(0, half_height), center + Vector2(-half_width, 0)])
	might_tile.draw_colored_polygon(points, Color(ZenithTheme.MIGHT, 0.07))
	points.append(points[0])
	might_tile.draw_polyline(points, Color(ZenithTheme.MIGHT, 0.6), 1.5, true)


## Mirrors the flowing rows for a sheet that reads right to left.
func set_mirrored(on: bool) -> void:
	key_cards.alignment = FlowContainer.ALIGNMENT_END if on else FlowContainer.ALIGNMENT_BEGIN
	comp_legend.alignment = FlowContainer.ALIGNMENT_END if on else FlowContainer.ALIGNMENT_BEGIN


## `might_max` is the highest top Might among all shipped decks, so the bars compare across decks.
## `faces` renders the key card row, up to `key_max` faces; pass null to leave it out.
func show_deck(d: DeckList, might_max: int, faces: CardFaceCache = null, key_max: int = KEY_CARD_MAX) -> void:
	var lib: CardLibrary = Session.library
	var duelist: CardDef = lib.defs.get(d.duelist_face_id())
	_duelist = duelist
	_stack = d.duelist_stack(lib)
	_fill_stats(duelist, d)
	_fill_aspects(_stack, maxi(1, might_max))
	_fill_composition(d, lib)
	_fill_key_cards(d, duelist, lib, faces, key_max)
	var problems: Array[String] = Session.deck_problems(d)
	problems_label.visible = not problems.is_empty()
	problems_label.text = "\n".join(problems)


## Lights the chip of the Aspect on show.
func highlight_aspect(aspect: int) -> void:
	_show_aspect_stats(aspect)
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
		for def in d.duelist_stack(Session.library).defs:
			var might: Array = def.aspect_data(def.aspect).get("might", [])
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
	_hide_zoom()
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
		var column: VBoxContainer = VBoxContainer.new()
		column.custom_minimum_size.x = KEY_CARD_SIZE.x
		key_cards.add_child(column)
		var rect: TextureRect = TextureRect.new()
		rect.custom_minimum_size = KEY_CARD_SIZE
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.focus_mode = Control.FOCUS_ALL
		rect.focus_entered.connect(func() -> void: _show_zoom(rect))
		rect.focus_exited.connect(_hide_zoom)
		rect.mouse_entered.connect(func() -> void: _show_zoom(rect))
		rect.mouse_exited.connect(_hide_zoom)
		column.add_child(rect)
		var caption: Label = Label.new()
		caption.text = def.title
		caption.custom_minimum_size.x = KEY_CARD_SIZE.x
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(caption)
		var face: Texture2D = await faces.render_face(def, 0, CardFace.mastery_backdrop(d, lib))
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
	pos.x = clampf(pos.x, 8.0, maxf(8.0, view.x - KEY_CARD_ZOOM.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, view.y - KEY_CARD_ZOOM.y - 8.0))
	_zoom.global_position = pos


func _hide_zoom() -> void:
	if _zoom != null:
		_zoom.visible = false


## Resource statistics always describe the Aspect currently selected for inspection.
func _fill_stats(duelist: CardDef, d: DeckList) -> void:
	_show_aspect_stats(_stack.lowest_aspect() if _stack != null and not _stack.is_empty() else 1)
	life_tile.set_stat("Life Deck", "%d cards" % d.cards.size(), "", ZenithTheme.MUTED)
	reserve_tile.set_stat("Reserve", "%d cards" % d.reserve.size(), "swap before play", ZenithTheme.MUTED)


func _show_aspect_stats(aspect: int) -> void:
	var data: Dictionary = _stack.aspect_data(aspect) if _stack != null else {}
	var might: Array = data.get("might", [])
	var top: int = int(might[might.size() - 1]) if not might.is_empty() else 0
	might_tile.set_stat("Peak Might", CardText.short_number(top), "selected Aspect", ZenithTheme.MIGHT)
	var surge: int = int(data.get("surge", 0))
	surge_tile.set_stat("Surge", "+%d" % surge, "Energy per turn", ZenithTheme.ENERGY)
	surge_tile.set_pips(surge, surge, ZenithTheme.ENERGY)
	might_tile.queue_redraw()


## One chip per Aspect the deck plays with: the title, then Surge and top Might beneath it.
## Clicking a chip asks the screen to show that Aspect.
func _fill_aspects(stack: PersonalityStack, _might_max: int) -> void:
	for child in aspects_box.get_children():
		child.queue_free()
	_aspect_names.clear()
	_aspect_chips.clear()
	if stack == null:
		return
	# A stack may climb through more than one of a character's printed lines, so a rung says which
	# line it came from. A one-line stack stays quiet, and so does a tier two lines share.
	var mixed: bool = CardText.stack_mixes_lines(stack)
	for duelist in stack.defs:
		var aspect: int = duelist.aspect
		var t: Dictionary = duelist.aspect_data(aspect)
		var might: Array = t.get("might", [])
		var top: int = int(might[might.size() - 1]) if might.size() > 0 else 0
		var chip: Button = Button.new()
		chip.theme_type_variation = &"TileButton"
		chip.toggle_mode = true
		chip.button_group = _chip_group
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(72, 60)   # the labels clip, so five chips always fit the column
		chip.tooltip_text = "%s\n%s\nSurge %d · Peak Might %s" % [
			CardText.rung_label(duelist, mixed), CardText.personality_name(duelist),
			int(t.get("surge", 0)), CardText.short_number(top)]
		chip.pressed.connect(func() -> void: aspect_clicked.emit(aspect))
		var col: VBoxContainer = VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 12
		col.offset_right = -12
		col.offset_top = 6
		col.offset_bottom = -6
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 0)
		var name_label: Label = Label.new()
		# The chip is narrow, so it carries the tier and the title only; the line word and the
		# character's name are in the tooltip and in the Aspect block beside it.
		name_label.text = CardText.rung_label(duelist)
		name_label.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_label)
		_aspect_names[aspect] = name_label
		var nums: HBoxContainer = HBoxContainer.new()
		nums.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var surge: Label = Label.new()
		surge.text = "Surge %d" % int(t.get("surge", 0))
		surge.theme_type_variation = &"MutedLabel"
		surge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		surge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		surge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nums.add_child(surge)
		var value: Label = Label.new()
		value.text = CardText.short_number(top)
		value.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
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
	line.add_theme_constant_override("separation", 6)
	var icon: TypeIcon = TypeIcon.new()
	icon.custom_minimum_size = Vector2(18, 18)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.type = type
	icon.color = Palette.type_ui(type)
	line.add_child(icon)
	var label: Label = Label.new()
	label.text = "%s %d" % [CardText.TYPE_LABELS[type], n]
	label.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
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
		seg.add_theme_stylebox_override("panel", ZenithTheme.box(Palette.type_ui(type), Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 0, 0))
		seg.tooltip_text = "%s %d" % [CardText.TYPE_LABELS[type], n]
		comp_bar.add_child(seg)
	comp_header.text = "LIFE DECK  ·  %d CARDS" % d.cards.size()
	for child in comp_legend.get_children():
		child.queue_free()
	for type in TYPE_ORDER:
		var n: int = int(counts.get(type, 0))
		if n > 0:
			comp_legend.add_child(_legend_entry(type, n))
