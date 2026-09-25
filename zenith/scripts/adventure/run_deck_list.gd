class_name RunDeckList
extends HBoxContainer
## A run's Life Deck as a browsable list: every distinct card grouped by type and sorted by title
## across two columns, with a large face preview on hover or click. The stage screen's View Deck
## modal and the reward screen's cut dialog both show this.

signal card_selected(id: String)

const PREVIEW_HINT: String = "Hover or select a card"

## The cut dialog says how many copies the run holds; the View Deck modal has that in its stats.
@export var show_copies: bool = false

@onready var list_caption: Label = $List/Caption
@onready var column_a: VBoxContainer = $List/Scroll/Columns/A
@onready var column_b: VBoxContainer = $List/Scroll/Columns/B
@onready var preview_caption: Label = $Preview/Caption
@onready var preview_face: TextureRect = $Preview/Face
@onready var preview_count: Label = $Preview/Count

var _library: CardLibrary = null
var _faces: CardFaceCache = null
var _counts: Dictionary = {}          # card id -> copies in the run
var _selected_id: String = ""
var _row_group: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	preview_count.visible = show_copies


## Rebuilds the list from `ids`, one entry per copy the way AdventureRun.cards holds them, and
## drops any selection.
func show_cards(ids: Array[String], library: CardLibrary, faces: CardFaceCache) -> void:
	_library = library
	_faces = faces
	_selected_id = ""
	_counts = {}
	for id in ids:
		_counts[id] = int(_counts.get(id, 0)) + 1
	_build()
	_clear_preview()


## The muted line above the list. Empty text hides it.
func set_caption(text: String) -> void:
	list_caption.text = text
	list_caption.visible = text != ""


func selected_id() -> String:
	return _selected_id


## Groups by type in DeckInfo's own type order, sorts each group by title, and splits the groups
## across the two columns by running row count so a group stays together.
func _build() -> void:
	for col: VBoxContainer in [column_a, column_b]:
		for child in col.get_children():
			col.remove_child(child)
			child.queue_free()
	var rows_a: int = 0
	var rows_b: int = 0
	for type: CardDef.Type in DeckInfo.TYPE_ORDER:
		var ids: Array[String] = []
		for id in _counts.keys():
			var def: CardDef = _library.defs.get(id)
			if def != null and def.type == type:
				ids.append(id)
		if ids.is_empty():
			continue
		ids.sort_custom(func(a: String, b: String) -> bool: return _library.defs[a].title < _library.defs[b].title)
		var target: VBoxContainer = column_a if rows_a <= rows_b else column_b
		var header: Label = Label.new()
		header.text = str(CardText.TYPE_LABELS.get(type, "Card")).to_upper()
		header.theme_type_variation = &"MutedLabel"
		target.add_child(header)
		for id in ids:
			target.add_child(_build_row(_library.defs[id], int(_counts[id])))
		var group_rows: int = ids.size() + 1
		if target == column_a:
			rows_a += group_rows
		else:
			rows_b += group_rows


## One clickable row: a type icon and title tinted by card group, and the copy count.
func _build_row(def: CardDef, count: int) -> Button:
	var row: Button = Button.new()
	row.theme_type_variation = &"TileButton"
	row.toggle_mode = true
	row.button_group = _row_group
	row.custom_minimum_size = Vector2(0, 42)
	row.mouse_entered.connect(func() -> void: _preview(def))
	row.mouse_exited.connect(_revert_preview)
	row.pressed.connect(func() -> void: _select(def))

	var h: HBoxContainer = HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -12
	row.add_child(h)

	var tint: Color = Palette.card_ui(def)
	var icon: TypeIcon = TypeIcon.new()
	icon.custom_minimum_size = Vector2(18, 18)
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
	preview_count.text = "In deck: %d" % int(_counts.get(def.id, 0))
	var tex: Texture2D = await _faces.render_face(def)
	if preview_caption.text == def.title:
		preview_face.texture = tex


## The pointer leaving a row falls back to the selected card, or to the empty state.
func _revert_preview() -> void:
	if _selected_id != "" and _library.defs.has(_selected_id):
		_preview(_library.defs[_selected_id])
	else:
		_clear_preview()


func _clear_preview() -> void:
	preview_face.texture = null
	preview_caption.text = PREVIEW_HINT
	preview_count.text = ""


func _select(def: CardDef) -> void:
	_selected_id = def.id
	_preview(def)
	card_selected.emit(def.id)
