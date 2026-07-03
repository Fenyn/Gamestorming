class_name HumanInput
extends FighterInput

var device_id: int = -1
var _stance_index: int = 0

const STANCES: Array[StanceDirection.Direction] = [
	StanceDirection.Direction.TOP,
	StanceDirection.Direction.BOTTOM_LEFT,
	StanceDirection.Direction.BOTTOM_RIGHT,
]


func setup(p_device_id: int) -> void:
	device_id = p_device_id
	stance_direction = StanceDirection.Direction.TOP


func poll(_raw_delta: Vector2) -> void:
	tick()
	_update_move_vector()
	_update_stance()


func is_action_pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action)


func _check_just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action)


func _update_move_vector() -> void:
	move_vector = Vector2(
		Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left"),
		Input.get_action_strength(&"move_back") - Input.get_action_strength(&"move_forward"),
	)
	if move_vector.length() > 1.0:
		move_vector = move_vector.normalized()


func _update_stance() -> void:
	if Input.is_action_just_pressed(&"stance_top"):
		stance_direction = StanceDirection.Direction.TOP
		_stance_index = 0
	elif Input.is_action_just_pressed(&"stance_bottom_left"):
		stance_direction = StanceDirection.Direction.BOTTOM_LEFT
		_stance_index = 1
	elif Input.is_action_just_pressed(&"stance_bottom_right"):
		stance_direction = StanceDirection.Direction.BOTTOM_RIGHT
		_stance_index = 2
	elif Input.is_action_just_pressed(&"stance_next"):
		_stance_index = (_stance_index + 1) % STANCES.size()
		stance_direction = STANCES[_stance_index]
	elif Input.is_action_just_pressed(&"stance_prev"):
		_stance_index = (_stance_index - 1 + STANCES.size()) % STANCES.size()
		stance_direction = STANCES[_stance_index]
