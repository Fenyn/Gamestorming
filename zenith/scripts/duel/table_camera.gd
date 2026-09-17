class_name TableCamera
extends Camera3D
## Free look over the table. The wheel dollies toward the point under the cursor, middle-drag or
## WASD / arrows pan along the table, and after a few idle seconds the view glides back to its
## home framing. Pitch and yaw never change, so the perspective the layout was tuned for holds.
## Everything happens in the rig's local space, so the hotseat swing keeps working underneath.

const LOOK_AT: Vector3 = Vector3(0, 0, 0.2)
const IDLE_SECONDS: float = 4.0
const GLIDE: float = 9.0                 # exponential smoothing rate toward the target position
const ZOOM_STEP: float = 0.14            # share of the distance to the cursor point per wheel notch
const MIN_HEIGHT: float = 1.6
const MAX_HEIGHT: float = 7.6
const KEY_PAN_SPEED: float = 3.2         # table units per second at home height
const DRAG_PAN: float = 0.0075           # table units per pixel of middle-drag at home height
const BOUNDS: Rect2 = Rect2(-5.2, -3.7, 10.4, 7.4)   # the table top; the look point stays inside
const ROAM_MARGIN: Vector2 = Vector2(0.62, 0.45)     # table units kept clear of each edge, per unit of camera height

var _home: Transform3D
var _target: Vector3
var _idle: float = 0.0
var _dragging: bool = false


func _ready() -> void:
	look_at(LOOK_AT)
	_home = transform
	_target = position


## Glide back to the home framing now (hand-offs, swings).
func return_home() -> void:
	_target = _home.origin
	_idle = 0.0


func _input(event: InputEvent) -> void:
	# Any input at all counts as activity; the return starts only when the player has stopped.
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		_idle = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom(1.0, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom(-1.0, mb.position)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		var scale: float = DRAG_PAN * _height_ratio()
		_pan(-mm.relative.x * scale, mm.relative.y * scale)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var keys: Vector2 = _key_axis()
	if keys != Vector2.ZERO:
		_idle = 0.0
		var step: float = KEY_PAN_SPEED * _height_ratio() * delta
		_pan(keys.x * step, keys.y * step)
	else:
		_idle += delta
		if _idle >= IDLE_SECONDS and not _dragging:
			_target = _home.origin
	position = position.lerp(_target, 1.0 - exp(-GLIDE * delta))


## Dev flags: pan by (dx, dz) table units and zoom `notches` toward the screen centre, then snap.
func dev_set(pan: Vector2, notches: int) -> void:
	_pan(pan.x, pan.y)
	var centre: Vector2 = get_viewport().get_visible_rect().size * 0.5
	for i in range(absi(notches)):
		_zoom(signf(notches), centre)
	position = _target
	_idle = -1e9


func _key_axis() -> Vector2:
	if get_viewport().gui_get_focus_owner() != null:
		return Vector2.ZERO
	var axis: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		axis.x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		axis.x -= 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		axis.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		axis.y -= 1.0
	return axis


## Pans feel the same at every height: slower close in, faster from above.
func _height_ratio() -> float:
	return _target.y / _home.origin.y


func _forward_flat() -> Vector3:
	var f: Vector3 = -_home.basis.z
	f.y = 0.0
	return f.normalized()


## `right` and `ahead` in table units along the camera's own axes, look point kept on the table.
func _pan(right: float, ahead: float) -> void:
	_target += _home.basis.x * right + _forward_flat() * ahead
	_clamp_target()


## Dolly along the line to the point under the cursor on the table plane: the spot under the
## pointer stays under the pointer, so zooming reads as leaning in rather than as a lens change.
func _zoom(direction: float, screen_pos: Vector2) -> void:
	var origin: Vector3 = project_ray_origin(screen_pos)
	var dir: Vector3 = project_ray_normal(screen_pos)
	if is_zero_approx(dir.y):
		return
	var hit: Vector3 = origin + dir * (-origin.y / dir.y)
	# Into the rig's space, and from the current target, so notches during a glide accumulate cleanly.
	var local_hit: Vector3 = (get_parent() as Node3D).to_local(hit)
	var to_hit: Vector3 = local_hit - _target
	var share: float = ZOOM_STEP if direction > 0.0 else -ZOOM_STEP / (1.0 - ZOOM_STEP)
	var next: Vector3 = _target + to_hit * share
	var height: float = clampf(next.y, MIN_HEIGHT, MAX_HEIGHT)
	if not is_equal_approx(height, next.y) and not is_zero_approx(to_hit.y):
		# Cut the move short on the same line so the pointer stays over the same spot.
		next = _target + to_hit * ((height - _target.y) / to_hit.y)
	_target = next
	_clamp_target()


## Keeps the point the camera looks at inside the table, less a margin that grows with height:
## close in the view may roam to the edges, from above it stays near the centre so the table
## never slides off into the void.
func _clamp_target() -> void:
	var f: Vector3 = -_home.basis.z
	var reach: float = _target.y / -f.y
	var look: Vector3 = _target + f * reach
	var margin: Vector2 = ROAM_MARGIN * _target.y
	var half: Vector2 = (BOUNDS.size * 0.5 - margin).maxf(0.0)
	var centre: Vector2 = BOUNDS.get_center()
	var clamped: Vector2 = Vector2(clampf(look.x, centre.x - half.x, centre.x + half.x), clampf(look.z, centre.y - half.y, centre.y + half.y))
	_target += Vector3(clamped.x - look.x, 0.0, clamped.y - look.z)
