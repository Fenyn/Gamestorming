extends Node

@export var config: InputConfig = null

var look_input: Vector2 = Vector2.ZERO
var raw_mouse_delta: Vector2 = Vector2.ZERO
var move_input: Vector2 = Vector2.ZERO
var mouse_captured: bool = false

var _mouse_delta: Vector2 = Vector2.ZERO
var _context: InputContext = InputContext.new()


func _ready() -> void:
	if config == null:
		config = InputConfig.new()
	_context.register_mode(InputContext.Mode.GAMEPLAY, PackedStringArray([
		"move_forward", "move_back", "move_left", "move_right",
		"light_attack", "heavy_attack", "guard", "dodge", "jump",
		"shove", "lock_on", "feint",
		"stance_top", "stance_bottom_left", "stance_bottom_right",
		"stance_next", "stance_prev",
	]))
	_context.register_mode(InputContext.Mode.MENU, PackedStringArray([
		"ui_accept", "ui_cancel", "ui_up", "ui_down",
	]))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_mouse_delta += motion.relative


func _process(_delta: float) -> void:
	raw_mouse_delta = _mouse_delta
	var mouse_look: Vector2 = _mouse_delta * config.mouse_sensitivity
	_mouse_delta = Vector2.ZERO

	if config.invert_mouse_x:
		mouse_look.x = -mouse_look.x
	if config.invert_mouse_y:
		mouse_look.y = -mouse_look.y

	look_input = mouse_look

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
