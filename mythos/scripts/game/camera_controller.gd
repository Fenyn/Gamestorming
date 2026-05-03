class_name CameraController
extends Camera3D

const PAN_SPEED: float = 10.0
const EDGE_MARGIN: float = 40.0
const EDGE_SPEED: float = 8.0
const MIN_X: float = -6.0
const MAX_X: float = 6.0
const MIN_Z: float = -12.0
const MAX_Z: float = 16.0
const SCROLL_ZOOM_STEP: float = 1.5
const MIN_Y: float = 5.0
const MAX_Y: float = 18.0

var _target_pos: Vector3

func _ready() -> void:
	_target_pos = global_position

func _process(delta: float) -> void:
	var move: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	if mouse_pos.x < EDGE_MARGIN:
		move.x -= 1.0
	elif mouse_pos.x > viewport_size.x - EDGE_MARGIN:
		move.x += 1.0
	if mouse_pos.y < EDGE_MARGIN:
		move.y -= 1.0
	elif mouse_pos.y > viewport_size.y - EDGE_MARGIN:
		move.y += 1.0

	if move != Vector2.ZERO:
		move = move.normalized()
		_target_pos.x += move.x * PAN_SPEED * delta
		_target_pos.z += move.y * PAN_SPEED * delta
		_target_pos.x = clampf(_target_pos.x, MIN_X, MAX_X)
		_target_pos.z = clampf(_target_pos.z, MIN_Z, MAX_Z)

	global_position = global_position.lerp(_target_pos, 10.0 * delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_pos.y = clampf(_target_pos.y - SCROLL_ZOOM_STEP, MIN_Y, MAX_Y)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_pos.y = clampf(_target_pos.y + SCROLL_ZOOM_STEP, MIN_Y, MAX_Y)
