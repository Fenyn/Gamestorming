## Input Manager Template
##
## Copy this file to your project's scripts/autoload/ directory and rename it
## to input_manager.gd. Register it as an autoload named "InputManager" in
## project.godot.
##
## This template aggregates raw input (mouse motion, keyboard, gamepad) into
## clean semantic values (look_input, move_input). Customize the action names
## and add game-specific input polling in _process().
##
## Requires: InputConfig resource (from godot_base addon).
## Optional: InputContext (from godot_base addon) for multi-mode input filtering.

extends Node

@export var config: InputConfig = null

var look_input: Vector2 = Vector2.ZERO
var move_input: Vector2 = Vector2.ZERO
var mouse_captured: bool = false

var _mouse_delta: Vector2 = Vector2.ZERO
var _context: InputContext = InputContext.new()


func _ready() -> void:
	if config == null:
		config = InputConfig.new()
	# Register which actions are active per mode. Customize for your project.
	# _context.register_mode(InputContext.Mode.GAMEPLAY, PackedStringArray([
	#     "move_forward", "move_back", "move_left", "move_right",
	#     "jump", "interact", "sprint",
	# ]))
	# _context.register_mode(InputContext.Mode.MENU, PackedStringArray([
	#     "ui_accept", "ui_cancel", "ui_up", "ui_down",
	# ]))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_mouse_delta += motion.relative


func _process(_delta: float) -> void:
	# --- Look input (mouse + gamepad right stick) ---
	var mouse_look: Vector2 = _mouse_delta * config.mouse_sensitivity
	_mouse_delta = Vector2.ZERO

	if config.invert_mouse_x:
		mouse_look.x = -mouse_look.x
	if config.invert_mouse_y:
		mouse_look.y = -mouse_look.y

	# Gamepad right stick (customize action names for your project)
	# var stick_look: Vector2 = Vector2(
	#     Input.get_action_strength("look_right") - Input.get_action_strength("look_left"),
	#     Input.get_action_strength("look_down") - Input.get_action_strength("look_up"),
	# )
	# if stick_look.length() < config.stick_deadzone:
	#     stick_look = Vector2.ZERO
	# if config.invert_gamepad_x:
	#     stick_look.x = -stick_look.x
	# if config.invert_gamepad_y:
	#     stick_look.y = -stick_look.y
	# stick_look *= config.gamepad_sensitivity * _delta

	look_input = mouse_look  # + stick_look when gamepad is enabled

	# --- Move input (WASD + gamepad left stick) ---
	# Customize these action names for your project's input map.
	move_input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"),
	)
	if move_input.length() > 1.0:
		move_input = move_input.normalized()


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false


func get_context() -> InputContext:
	return _context


func set_mode(mode: InputContext.Mode) -> void:
	_context.set_mode(mode)
