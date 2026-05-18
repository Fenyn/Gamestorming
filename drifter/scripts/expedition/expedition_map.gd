class_name ExpeditionMap
extends Control

const NODE_BUTTON_SIZE: Vector2 = Vector2(64, 64)
const ROW_SPACING: float = 100.0
const COL_SPACING: float = 160.0
const MAP_OFFSET: Vector2 = Vector2(0, 60)

@onready var _map_container: Control = %MapContainer
@onready var _info_label: Label = %InfoLabel
@onready var _line_layer: MapLineLayer = %LineLayer
@onready var _loadout_button: Button = %LoadoutButton

var _map: Array[Array] = []
var _node_buttons: Dictionary = {}
var _info_tween: Tween


func get_node_button(coord: Vector2i) -> Button:
	return _node_buttons.get(coord) as Button


func _ready() -> void:
	theme = ThemeBuilder.build()
	_loadout_button.pressed.connect(_on_loadout_pressed)

	if RunState.map_nodes.is_empty():
		_map = MapGenerator.generate()
		RunState.map_nodes = _map
	else:
		_map = RunState.map_nodes

	if _is_expedition_complete():
		_complete_expedition()
		return

	_line_layer.map_ref = self
	_build_map_ui()
	_update_available_nodes()


func _build_map_ui() -> void:
	var map_width: float = 1280.0
	for row: int in _map.size():
		var nodes: Array = _map[row]
		var total_width: float = (nodes.size() - 1) * COL_SPACING
		var start_x: float = (map_width - total_width) / 2.0

		for col: int in nodes.size():
			var node_data: MapNodeData = nodes[col] as MapNodeData
			var pos: Vector2 = MAP_OFFSET + Vector2(
				start_x + col * COL_SPACING - NODE_BUTTON_SIZE.x / 2.0,
				row * ROW_SPACING
			)
			var btn: Button = _create_node_button(node_data, pos)
			_map_container.add_child(btn)
			_node_buttons[Vector2i(row, col)] = btn

	_draw_connections()


func _create_node_button(node_data: MapNodeData, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text = node_data.get_icon_text()
	btn.tooltip_text = _build_node_tooltip(node_data)
	btn.position = pos
	btn.custom_minimum_size = NODE_BUTTON_SIZE
	btn.size = NODE_BUTTON_SIZE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var color: Color = node_data.get_color()
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color.lightened(0.3))
	btn.add_theme_font_size_override("font_size", 22)

	if node_data.visited:
		btn.modulate = Color(0.4, 0.4, 0.4)

	var coord: Vector2i = Vector2i(node_data.row, node_data.column)
	btn.pressed.connect(_on_node_pressed.bind(coord))
	return btn


func _build_node_tooltip(node_data: MapNodeData) -> String:
	var tip: String = node_data.get_display_name()
	match node_data.type:
		MapNodeData.NodeType.ENCOUNTER:
			tip += "\nFight a creature. Earn salvage."
		MapNodeData.NodeType.ELITE:
			tip += "\nDangerous fight. Guaranteed rare reward."
		MapNodeData.NodeType.TRADER:
			tip += "\nBuy modules, implants, and grid upgrades."
		MapNodeData.NodeType.SHELTER:
			tip += "\nHeal 30% of max HP."
		MapNodeData.NodeType.ANOMALY:
			tip += "\nRandom event. Risk and reward."
		MapNodeData.NodeType.APEX:
			tip += "\nBoss fight. End of expedition."
	if node_data.visited:
		tip += "\n(Visited)"
	return tip


func _draw_connections() -> void:
	_line_layer.queue_redraw()


func _on_node_pressed(coord: Vector2i) -> void:
	if not _is_reachable(coord):
		return
	var row: int = coord.x
	var col: int = coord.y
	var node_data: MapNodeData = _map[row][col] as MapNodeData

	node_data.visited = true
	RunState.visited_nodes.append(coord)
	RunState.current_row = row

	match node_data.type:
		MapNodeData.NodeType.ENCOUNTER:
			_start_combat(_pick_trash_creature())
		MapNodeData.NodeType.ELITE:
			_start_combat(load("res://resources/creatures/hive_caller.tres") as CreatureData)
		MapNodeData.NodeType.APEX:
			_start_combat(load("res://resources/creatures/the_warden.tres") as CreatureData)
		MapNodeData.NodeType.SHELTER:
			_apply_shelter()
		MapNodeData.NodeType.TRADER:
			_apply_trader()
		MapNodeData.NodeType.ANOMALY:
			_apply_anomaly()


func _start_combat(creature: CreatureData) -> void:
	RunState.current_creature = creature
	EventBus.screen_transition_requested.emit("combat")


func _pick_trash_creature() -> CreatureData:
	var options: Array[String] = [
		"res://resources/creatures/lurker.tres",
		"res://resources/creatures/spewer.tres",
	]
	return load(options[randi() % options.size()]) as CreatureData


func _apply_shelter() -> void:
	var heal_amount: int = RunState.drifter_max_hp * 30 / 100
	RunState.heal(heal_amount)
	_show_info("Shelter: healed " + str(heal_amount) + " HP")
	_update_available_nodes()


func _apply_trader() -> void:
	EventBus.screen_transition_requested.emit("trader")


func _apply_anomaly() -> void:
	var roll: float = randf()
	if roll < 0.5:
		var heal_amount: int = 10
		RunState.heal(heal_amount)
		_show_info("Anomaly: found a med-cache +" + str(heal_amount) + " HP")
	else:
		var damage: int = 5
		RunState.take_damage(damage)
		_show_info("Anomaly: energy spike! -" + str(damage) + " HP")
	_update_available_nodes()


func _update_available_nodes() -> void:
	var next_row: int = RunState.current_row + 1
	if RunState.current_row == 0 and RunState.visited_nodes.is_empty():
		next_row = 0

	for coord: Vector2i in _node_buttons:
		var btn: Button = _node_buttons[coord] as Button
		var node_data: MapNodeData = _map[coord.x][coord.y] as MapNodeData
		if node_data.visited:
			btn.disabled = true
			btn.modulate = Color(0.35, 0.35, 0.35)
		elif coord.x == next_row and _is_reachable(coord):
			btn.disabled = false
			btn.modulate = Color(1.2, 1.2, 1.2)
			var glow_style: StyleBoxFlat = ThemeBuilder.create_flat_style(
				Color(0.15, 0.25, 0.20), node_data.get_color(), 2, 4, 8
			)
			btn.add_theme_stylebox_override("normal", glow_style)
		else:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)


func _is_expedition_complete() -> bool:
	if _map.is_empty():
		return false
	var last_row: int = _map.size() - 1
	for col: int in (_map[last_row] as Array).size():
		var coord: Vector2i = Vector2i(last_row, col)
		if coord in RunState.visited_nodes:
			return true
	return false


func _complete_expedition() -> void:
	GameState.record_expedition()
	GameState.add_data_logs(10)
	EventBus.expedition_completed.emit()
	EventBus.screen_transition_requested.emit("camp")


func _show_info(text: String) -> void:
	_info_label.text = text
	_info_label.modulate.a = 1.0
	if _info_tween:
		_info_tween.kill()
	_info_tween = create_tween()
	_info_tween.tween_property(_info_label, "modulate:a", 0.0, 0.5).set_delay(3.0)


func _on_loadout_pressed() -> void:
	EventBus.screen_transition_requested.emit("loadout")


func _is_reachable(target: Vector2i) -> bool:
	if RunState.visited_nodes.is_empty():
		return target.x == 0

	var prev_row: int = target.x - 1
	if prev_row < 0:
		return false

	for col: int in (_map[prev_row] as Array).size():
		var node_data: MapNodeData = _map[prev_row][col] as MapNodeData
		var coord: Vector2i = Vector2i(prev_row, col)
		if coord in RunState.visited_nodes:
			if target in node_data.connections:
				return true
	return false
