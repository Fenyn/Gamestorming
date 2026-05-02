extends Node

var blueprints: Array[Resource] = []
var active_ghosts: Array[Node3D] = []
var hub_radius: float = 25.0


func is_within_hub_radius(pos: Vector3) -> bool:
	return pos.length() <= hub_radius


func can_place_at(pos: Vector3) -> bool:
	if not is_within_hub_radius(pos):
		return false
	return true


func register_ghost(ghost: Node3D) -> void:
	if ghost not in active_ghosts:
		active_ghosts.append(ghost)


func unregister_ghost(ghost: Node3D) -> void:
	active_ghosts.erase(ghost)


func reset_to_defaults() -> void:
	blueprints.clear()
	active_ghosts.clear()
