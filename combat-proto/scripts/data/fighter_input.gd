class_name FighterInput
extends RefCounted

var move_vector: Vector2 = Vector2.ZERO
var stance_direction: StanceDirection.Direction = StanceDirection.Direction.TOP
var _consumed_actions: Dictionary = {}


func get_move_vector() -> Vector2:
	return move_vector


func get_stance_direction() -> StanceDirection.Direction:
	return stance_direction


func is_action_pressed(_action: StringName) -> bool:
	return false


func is_action_just_pressed(action: StringName) -> bool:
	if _consumed_actions.get(action, false):
		return false
	return _check_just_pressed(action)


func consume_action(action: StringName) -> void:
	_consumed_actions[action] = true


func _check_just_pressed(_action: StringName) -> bool:
	return false


func tick() -> void:
	_consumed_actions.clear()
