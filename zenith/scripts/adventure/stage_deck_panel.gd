class_name StageDeckPanel
extends ColorRect
## A modal browser for the run's Life Deck: DeckInfo's stats up top, every distinct card grouped
## by type and sorted by title below, and a large face preview on hover or click. Esc or Close
## dismisses it. The dim scrim blocks input to everything behind it, the same as the duel HUD's
## overlays.

@onready var panel: PanelContainer = $Center/Panel
@onready var close_button: Button = $Center/Panel/Column/Header/Close
@onready var info: DeckInfo = $Center/Panel/Column/Info
@onready var list_caption: Label = $Center/Panel/Column/Body/List/Caption
@onready var column_a: VBoxContainer = $Center/Panel/Column/Body/List/Scroll/Columns/A
@onready var column_b: VBoxContainer = $Center/Panel/Column/Body/List/Scroll/Columns/B
@onready var preview_caption: Label = $Center/Panel/Column/Body/Preview/Caption
@onready var preview_face: TextureRect = $Center/Panel/Column/Body/Preview/Face

var _faces: CardFaceCache = null
var _selected_id: String = ""
var _row_group: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	# The theme's default PanelContainer style carries BG's own alpha (0.9), which let the ladder
	# and the opponent card show through behind this modal. Force the fill opaque.
	panel.add_theme_stylebox_override("panel", ZenithTheme.box(Color(ZenithTheme.BG, 1.0), ZenithTheme.BORDER, 12, 1, 14, 12))


func open(deck: DeckList, might_max: int, faces: CardFaceCache) -> void:
	_faces = faces
	_selected_id = ""
	info.show_deck(deck, might_max, faces)
	# The full list below replaces DeckInfo's own three-card highlight reel, which would otherwise
	# push the panel taller than the window; the stats/Aspects/composition block above stays.
	# show_deck() sets these visible again each time, so they are hidden after, not just once.
	(info.get_node("KeyHeader") as Control).visible = false
	(info.get_node("KeyCards") as Control).visible = false
	_build_list(deck)
	preview_face.texture = null
	preview_caption.text = "Hover or select a card"
	visible = true
	close_button.grab_focus()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Every distinct card in the deck, grouped by type in DeckInfo's own type order and sorted by
## title, split across two columns by running row count so a big group stays together.
func _build_list(deck: DeckList) -> void:
	for col in [column_a, column_b]:
		for child in col.get_children():
			child.queue_free()
	var lib: CardLibrary = Session.library
	var counts: Dictionary = {}
	for id in deck.cards:
		counts[id] = int(counts.get(id, 0)) + 1
	var mastery_def: CardDef = lib.defs.get(deck.mastery_id)
	list_caption.text = "Mastery: %s   ·   Aspects %d   ·   %d cards" % [mastery_def.title if mastery_def != null else "None", deck.aspects, deck.cards.size()]
	var rows_a: int = 0
	var rows_b: int = 0
	for type in DeckInfo.TYPE_ORDER:
		var ids: Array[String] = []
		for id in counts.keys():
			var def: CardDef = lib.defs.get(id)
			if def != null and def.type == type:
				ids.append(id)
		if ids.is_empty():
			continue
		ids.sort_custom(func(a: String, b: String) -> bool: return lib.defs[a].title < lib.defs[b].title)
		var target: VBoxContainer = column_a if rows_a <= rows_b else column_b
		var header: Label = Label.new()
		header.text = str(CardText.TYPE_LABELS.get(type, "Card")).to_upper()
		header.theme_type_variation = &"MutedLabel"
		target.add_child(header)
		for id in ids:
			target.add_child(_build_row(lib.defs[id], int(counts[id])))
		var group_rows: int = ids.size() + 1
		if target == column_a:
			rows_a += group_rows
		else:
			rows_b += group_rows


## One clickable row: a type icon and title tinted by school, and the copy count.
func _build_row(def: CardDef, count: int) -> Button:
	var row: Button = Button.new()
	row.theme_type_variation = &"TileButton"
	row.toggle_mode = true
	row.button_group = _row_group
	row.custom_minimum_size = Vector2(0, 32)
	row.mouse_entered.connect(func() -> void: _preview(def))
	row.mouse_exited.connect(_revert_preview)
	row.pressed.connect(func() -> void: _select(def))

	var h: HBoxContainer = HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	row.add_child(h)

	var tint: Color = Palette.school_ui(def.school)
	var icon: TypeIcon = TypeIcon.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.type = def.type
	icon.color = tint
	h.add_child(icon)

	var title_l: Label = Label.new()
	title_l.text = def.title
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_l.add_theme_color_override("font_color", tint)
	h.add_child(title_l)

	var count_l: Label = Label.new()
	count_l.text = "x%d" % count
	count_l.theme_type_variation = &"MutedLabel"
	count_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(count_l)
	return row


func _preview(def: CardDef) -> void:
	if _faces == null:
		return
	preview_caption.text = def.title
	var tex: Texture2D = await _faces.render_face(def)
	if preview_caption.text == def.title:
		preview_face.texture = tex


func _revert_preview() -> void:
	if _selected_id != "" and Session.library.defs.has(_selected_id):
		_preview(Session.library.defs[_selected_id])
	else:
		preview_face.texture = null
		preview_caption.text = "Hover or select a card"


func _select(def: CardDef) -> void:
	_selected_id = def.id
	_preview(def)
