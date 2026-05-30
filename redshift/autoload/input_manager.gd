extends Node

const DEFAULT_CONFIG_PATH: String = "res://resources/default_input_config.tres"

var config: InputConfig

var look_input: Vector2 = Vector2.ZERO
var thrust_input: Vector3 = Vector3.ZERO
var roll_input: float = 0.0

var _mouse_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	if ResourceLoader.exists(DEFAULT_CONFIG_PATH):
		config = load(DEFAULT_CONFIG_PATH) as InputConfig
	if config == null:
		config = InputConfig.new()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_mouse_delta += motion.relative


func _process(delta: float) -> void:
	_update_look(delta)
	_update_thrust()
	_update_roll()


func _update_look(delta: float) -> void:
	var mouse_look: Vector2 = Vector2.ZERO
	var stick_look: Vector2 = Vector2.ZERO

	if _mouse_delta.length_squared() > 0.0:
		var y_sign: float = -1.0 if config.mouse_invert_y else 1.0
		mouse_look = Vector2(-_mouse_delta.y * y_sign, -_mouse_delta.x) * config.mouse_sensitivity
		_mouse_delta = Vector2.ZERO

	var stick_x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var stick_y: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if Vector2(stick_x, stick_y).length() > config.stick_deadzone:
		var y_sign: float = -1.0 if config.stick_invert_y else 1.0
		stick_look = Vector2(-stick_y * y_sign, -stick_x) * config.stick_sensitivity * delta

	if mouse_look.length_squared() > stick_look.length_squared():
		look_input = mouse_look
	else:
		look_input = stick_look


func _update_thrust() -> void:
	var digital_forward: float = Input.get_action_strength(&"thrust_forward")
	var digital_backward: float = Input.get_action_strength(&"thrust_backward")
	var digital_left: float = Input.get_action_strength(&"thrust_left")
	var digital_right: float = Input.get_action_strength(&"thrust_right")
	var digital_up: float = Input.get_action_strength(&"thrust_up")
	var digital_down: float = Input.get_action_strength(&"thrust_down")

	var forward: float = digital_forward - digital_backward
	var lateral: float = digital_right - digital_left
	var vertical: float = digital_up - digital_down

	thrust_input = Vector3(lateral, vertical, forward)


func _update_roll() -> void:
	var left: float = Input.get_action_strength(&"roll_left")
	var right: float = Input.get_action_strength(&"roll_right")
	roll_input = right - left


func is_action_pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action)


func is_action_just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action)
