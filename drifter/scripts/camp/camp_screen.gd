class_name CampScreen
extends Control

@onready var _hp_label: Label = %HPLabel
@onready var _scrap_label: Label = %ScrapLabel
@onready var _module_list: VBoxContainer = %ModuleList
@onready var _implant_list: VBoxContainer = %ImplantList
@onready var _expedition_button: Button = %ExpeditionButton
@onready var _logs_label: Label = %LogsLabel


func _ready() -> void:
	theme = ThemeBuilder.build()
	_expedition_button.pressed.connect(_on_expedition_pressed)
	_refresh_display()


func _refresh_display() -> void:
	_hp_label.text = "HP: " + str(RunState.drifter_hp) + "/" + str(RunState.drifter_max_hp)
	_scrap_label.text = "Scrap: " + str(RunState.scrap)
	_logs_label.text = "Data Logs: " + str(GameState.data_logs) + " | Bag: " + _format_dice_bag()

	for child: Node in _module_list.get_children():
		child.queue_free()

	if RunState.modules.is_empty():
		var empty := Label.new()
		empty.text = "No modules — defaults will load"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
		_module_list.add_child(empty)
	else:
		for placement: Dictionary in RunState.loadout_grid.get_placements():
			var module: ModuleData = placement["module"] as ModuleData
			if not module:
				continue
			var origin: Vector2i = placement["origin"] as Vector2i
			var label := Label.new()
			label.text = module.display_name + " [" + str(origin.x) + "," + str(origin.y) + "] — " + module.description
			label.add_theme_font_size_override("font_size", 12)
			_module_list.add_child(label)

	for child: Node in _implant_list.get_children():
		child.queue_free()

	if RunState.implants.is_empty():
		var empty := Label.new()
		empty.text = "No implants equipped"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
		_implant_list.add_child(empty)
	else:
		for implant: ImplantData in RunState.implants:
			var label := Label.new()
			label.text = implant.display_name + " — " + implant.description
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", ThemeBuilder.ACCENT_GLOW)
			_implant_list.add_child(label)


func _format_dice_bag() -> String:
	var counts: Dictionary = {}
	for die: CellData in RunState.dice_bag.get_all_dice():
		var key: String = die.display_name
		counts[key] = counts.get(key, 0) + 1
	var parts: Array[String] = []
	for key: String in counts:
		parts.append(str(counts[key]) + "x " + key)
	return str(RunState.dice_bag.get_total_size()) + " dice (draw " + str(RunState.dice_bag.get_draw_total()) + ") — " + ", ".join(parts)


func _on_expedition_pressed() -> void:
	RunState.reset_for_new_expedition()
	EventBus.expedition_started.emit()
	EventBus.screen_transition_requested.emit("map")
