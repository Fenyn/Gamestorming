extends CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var _desc_label: Label = $Panel/Margin/VBox/DescLabel
@onready var _req_label: RichTextLabel = $Panel/Margin/VBox/ReqLabel
@onready var _status_label: Label = $Panel/Margin/VBox/StatusLabel

var _visible_upgrade: String = ""
var _hide_timer: float = 0.0


func _ready() -> void:
	_panel.visible = false
	EventBus.upgrade_inspected.connect(_on_inspected)
	EventBus.upgrade_completed.connect(_on_completed)


func _process(delta: float) -> void:
	if _hide_timer > 0.0:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_panel.visible = false
			_visible_upgrade = ""


func _on_inspected(upgrade_id: String) -> void:
	var upgrade: Dictionary = HomesteadManager.get_upgrade(upgrade_id)
	if upgrade.is_empty():
		return

	_visible_upgrade = upgrade_id
	_title_label.text = upgrade.get("display_name", "") as String
	_desc_label.text = upgrade.get("description", "") as String

	var req_lines: Array[String] = []

	var money_cost: float = upgrade.get("money_cost", 0.0) as float
	if money_cost > 0.0:
		var has_money: bool = GameState.money >= money_cost
		var color: String = "green" if has_money else "red"
		req_lines.append("[color=%s]$%.0f[/color]" % [color, money_cost])

	var mat_costs: Dictionary = upgrade.get("material_costs", {}) as Dictionary
	for mat_id: String in mat_costs:
		var needed: int = mat_costs[mat_id] as int
		var have: int = GameState.get_material_count(mat_id)
		var color: String = "green" if have >= needed else "red"
		var mat_name: String = _material_display_name(mat_id)
		req_lines.append("[color=%s]%s: %d/%d[/color]" % [color, mat_name, have, needed])

	_req_label.text = "  ".join(req_lines)

	var prereqs: Array = upgrade.get("prerequisites", []) as Array
	var missing_prereqs: Array[String] = []
	for prereq: String in prereqs:
		if not GameState.is_upgrade_complete(prereq):
			var p: Dictionary = HomesteadManager.get_upgrade(prereq)
			missing_prereqs.append(p.get("display_name", prereq) as String)

	if not missing_prereqs.is_empty():
		_status_label.text = "Requires: %s" % ", ".join(missing_prereqs)
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
	elif HomesteadManager.has_resources(upgrade_id):
		_status_label.text = "[E] Build"
		_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	else:
		_status_label.text = "Gather materials"
		_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))

	_panel.visible = true
	_hide_timer = 5.0


func _on_completed(upgrade_id: String) -> void:
	if upgrade_id == _visible_upgrade:
		var upgrade: Dictionary = HomesteadManager.get_upgrade(upgrade_id)
		_title_label.text = upgrade.get("display_name", "") as String
		_desc_label.text = "Complete!"
		_req_label.text = ""
		_status_label.text = ""
		_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		_hide_timer = 3.0


func _material_display_name(mat_id: String) -> String:
	match mat_id:
		"wood_plank": return "Wood"
		"salvage_part": return "Salvage"
		"stone": return "Stone"
		"wire_pipe": return "Wire"
	return mat_id
