extends PanelContainer
class_name PiecePalette

signal piece_selected(piece_id: String)

@export var catalog: PieceCatalog

var spark_manager: SparkManager
var prestige_manager: PrestigeManager
var _category_container: VBoxContainer
var _buttons: Dictionary = {}
var _category_nodes: Dictionary = {}
var _selected_id: String = ""

var _scroll: ScrollContainer

func _ready() -> void:
	custom_minimum_size = Vector2(230, 0)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)

	_category_container = VBoxContainer.new()
	_category_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_category_container)

func set_catalog(cat: PieceCatalog) -> void:
	catalog = cat
	_build_palette()

func bind_spark_manager(sm: SparkManager) -> void:
	spark_manager = sm
	spark_manager.sparks_changed.connect(_on_sparks_changed)

func bind_prestige(pm: PrestigeManager) -> void:
	prestige_manager = pm
	prestige_manager.piece_category_unlocked.connect(_on_category_unlocked)
	_refresh_all()

func _build_palette() -> void:
	if catalog == null:
		return

	var categories: Dictionary = {}

	for piece: TrackPieceData in catalog.get_all_pieces():
		var cat_name: String = TrackPieceData.PieceCategory.keys()[piece.category]
		if not categories.has(cat_name):
			categories[cat_name] = []
		categories[cat_name].append(piece)

	var display_order: Array[String] = [
		"STRAIGHT", "CORNER", "CURVE", "TUNNEL", "END_CAP",
		"RAMP", "BEND",
		"S_CURVE", "WAVE", "SPLIT",
		"BUMP", "FUNNEL",
		"HELIX", "CROSS",
	]

	for cat_name: String in display_order:
		if not categories.has(cat_name):
			continue

		var pieces: Array = categories[cat_name]
		var section: VBoxContainer = VBoxContainer.new()
		section.name = "Cat_%s" % cat_name

		var header: Label = Label.new()
		header.text = cat_name.replace("_", " ").capitalize()
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
		section.add_child(header)

		var grid: GridContainer = GridContainer.new()
		grid.columns = 1
		section.add_child(grid)

		for piece: TrackPieceData in pieces:
			var cost_text: String = "FREE" if piece.spark_cost <= 0 else str(int(piece.spark_cost))
			var btn: Button = Button.new()
			btn.text = "%s  [%s]" % [piece.display_name, cost_text]
			btn.tooltip_text = "%s — %s" % [piece.piece_id, cost_text]
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.pressed.connect(_on_piece_button_pressed.bind(piece.piece_id))
			grid.add_child(btn)
			_buttons[piece.piece_id] = btn

		var sep: HSeparator = HSeparator.new()
		section.add_child(sep)

		_category_container.add_child(section)
		_category_nodes[cat_name] = section

func _on_piece_button_pressed(piece_id: String) -> void:
	var data: TrackPieceData = catalog.get_piece(piece_id)
	if data == null:
		return

	if spark_manager and not spark_manager.can_afford(data.spark_cost):
		return

	piece_selected.emit(piece_id)
	_selected_id = piece_id
	_refresh_all()

func _on_sparks_changed(_total: float) -> void:
	_refresh_all()

func _on_category_unlocked(_cat: String) -> void:
	_refresh_all()

func _refresh_all() -> void:
	for cat_name: String in _category_nodes:
		var section: VBoxContainer = _category_nodes[cat_name] as VBoxContainer
		var unlocked: bool = true
		if prestige_manager:
			unlocked = prestige_manager.is_category_unlocked(cat_name)
		section.visible = unlocked

	for id: String in _buttons:
		var btn: Button = _buttons[id] as Button
		var data: TrackPieceData = catalog.get_piece(id)
		if data == null:
			continue

		var can_afford: bool = true
		if spark_manager:
			can_afford = spark_manager.can_afford(data.spark_cost)

		btn.disabled = not can_afford
		btn.button_pressed = (id == _selected_id)
		btn.modulate = Color.WHITE if can_afford else Color(0.5, 0.5, 0.5, 0.7)
