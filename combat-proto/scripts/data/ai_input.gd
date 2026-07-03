class_name AIInput
extends FighterInput

var _pressed_actions: Dictionary = {}
var _just_pressed_actions: Dictionary = {}


func set_move(direction: Vector2) -> void:
	move_vector = direction


func set_stance(direction: StanceDirection.Direction) -> void:
	stance_direction = direction


func press_action(action: StringName) -> void:
	_pressed_actions[action] = true
	_just_pressed_actions[action] = true


func release_action(action: StringName) -> void:
	_pressed_actions.erase(action)


func release_all() -> void:
	_pressed_actions.clear()
	_just_pressed_actions.clear()
	move_vector = Vector2.ZERO


func is_action_pressed(action: StringName) -> bool:
	return _pressed_actions.get(action, false)


func _check_just_pressed(action: StringName) -> bool:
	return _just_pressed_actions.get(action, false)


func tick() -> void:
	super.tick()
	_just_pressed_actions.clear()
