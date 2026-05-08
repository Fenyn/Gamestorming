extends ScrollContainer

@onready var row_container: VBoxContainer = %RowContainer

var _upgrade_row_scene: PackedScene
var _rows: Dictionary = {}


func _ready() -> void:
	_upgrade_row_scene = preload("res://scenes/ui/upgrade_row.tscn")
	_build_sections()
	EventBus.tick_fired.connect(func(_t: float) -> void: _update_rows())
	EventBus.loop_completed.connect(func(_c: int) -> void: _rebuild())


func _build_sections() -> void:
	var spell_rituals: Array[UpgradeData] = []
	var arcane_rituals: Array[UpgradeData] = []

	for data in UpgradeManager.upgrade_data:
		if data.effect_type == "generator_mult":
			spell_rituals.append(data)
		else:
			arcane_rituals.append(data)

	spell_rituals.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool:
		if a.effect_target == "all":
			return false
		if b.effect_target == "all":
			return true
		return int(a.effect_target) < int(b.effect_target)
	)

	_add_section_header("Spell Rituals")
	for data in spell_rituals:
		_add_row(data)

	_add_section_header("Arcane Rituals")
	for data in arcane_rituals:
		_add_row(data)


func _add_section_header(title: String) -> void:
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 2)
	margin.add_child(header)
	row_container.add_child(margin)


func _add_row(data: UpgradeData) -> void:
	var row: PanelContainer = _upgrade_row_scene.instantiate()
	row.setup(data)
	row_container.add_child(row)
	_rows[data.id] = row


func _update_rows() -> void:
	for id in _rows:
		var row: PanelContainer = _rows[id]
		if row.has_method("_update_display"):
			row._update_display()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_rows.clear()
	for child in row_container.get_children():
		row_container.remove_child(child)
		child.queue_free()
	_build_sections()
