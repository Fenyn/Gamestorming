class_name UnitMoving
extends State

var _unit: Unit = null
var _connected: bool = false


func enter(msg: Dictionary = {}) -> void:
	_unit = owner as Unit
	var tile_path: Array[Vector2i] = msg.get("tile_path", [] as Array[Vector2i])
	var move_cost: int = msg.get("move_cost", 1) as int
	if tile_path.size() < 2:
		state_machine.transition_to("Idle")
		return
	if not _connected:
		_unit.mover.walk_finished.connect(_on_walk_finished)
		_connected = true
	_unit.mover.walk_path(tile_path, move_cost)


func _on_walk_finished() -> void:
	if state_machine.current_state == self:
		state_machine.transition_to("Idle")
