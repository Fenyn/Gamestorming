class_name TableCamera
extends Camera3D
## Free look over the table. The wheel dollies toward the point under the cursor, middle-drag or
## WASD / arrows pan along the table, and after a few idle seconds the view glides back to its
## home framing. Pitch and yaw never change, so the perspective the layout was tuned for holds.
## Everything happens in the rig's local space, so the hotseat swing keeps working underneath.

const LOOK_AT: Vector3 = Vector3(0, 0, 0.15)
const IDLE_SECONDS: float = 4.0
const GLIDE: float = 9.0                 # exponential smoothing rate toward the target position
const ZOOM_STEP: float = 0.14            # share of the distance to the cursor point per wheel notch
const MIN_HEIGHT: float = 3.0
const MAX_HEIGHT: float = 9.6
const KEY_PAN_SPEED: float = 3.2         # table units per second at home height
const DRAG_PAN: float = 0.0075           # table units per pixel of middle-drag at home height
## The board, centred on the home look point; the look point stays inside.
const BOUNDS: Rect2 = Rect2(-5.6, -3.25, 11.2, 6.8)
## Table units kept clear of each edge, per unit of camera height. At the home height the margin
## takes the whole of BOUNDS, so the full-board framing cannot be panned off.
const ROAM_MARGIN: Vector2 = Vector2(0.6, 0.37)

## While an exchange is live the view leans in on the centre line between the fighters, a slower,
## eased glide than an ordinary return so the push reads as a deliberate move.
const ARENA_LOOK: Vector3 = Vector3(0, 0, 0)
const ARENA_DISTANCE: float = 9.3
const ARENA_GLIDE: float = 4.5

## The opening shot under a lead-in: high over the courtyard's open corner, looking down on the
## dais, then a slow descending swing to the home framing.
const INTRO_FROM: Vector3 = Vector3(-5.0, 12.0, 6.0)
const INTRO_LOOK: Vector3 = Vector3(0, 0, -1.0)

var _home: Transform3D
var _intro: Tween = null
var _fly_t: float = 1.0
var _target: Vector3
var _glide: float = GLIDE
## Set by the duel view; the rest position moves in on the arena and glides back out after.
var arena_focus: bool = false:
	set(value):
		if arena_focus == value:
			return
		arena_focus = value
		return_home()
		_glide = ARENA_GLIDE
var _idle: float = 0.0
var _kick: Tween = null
var _dragging: bool = false
var hand_navigation: bool = false


func _ready() -> void:
	look_at(LOOK_AT)
	_home = transform
	_target = position


## A single punch of the view for a heavy hit: the lens offset jumps `strength` table units along
## `direction` (screen right, screen up) and settles back. It moves the offsets, not the camera,
## so the glide and the pan never see it. The caller skips it under Reduced motion.
func kick(direction: Vector2, strength: float = 0.04) -> void:
	if _kick != null and _kick.is_valid():
		_kick.kill()
	var push: Vector2 = direction.normalized() * strength
	_kick = create_tween()
	_kick.tween_property(self, "h_offset", push.x, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_kick.parallel().tween_property(self, "v_offset", push.y, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_kick.tween_property(self, "h_offset", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_kick.parallel().tween_property(self, "v_offset", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Starts the opening shot at INTRO_FROM and flies to the home framing over `seconds`. Input and
## the idle glide wait until it lands.
func fly_in(seconds: float) -> void:
	_fly(0.0, seconds, Tween.EASE_IN_OUT)


## Finishes a running opening shot within `seconds`, along the same path from where it has got to.
func land(seconds: float) -> void:
	if flying():
		_fly(_fly_t, seconds, Tween.EASE_OUT)


func flying() -> bool:
	return _intro != null and _intro.is_valid()


## Waits for the opening shot to land. Returns at once when there is none.
func landed() -> void:
	if flying():
		await _intro.finished


func _fly(from: float, seconds: float, ease: Tween.EaseType) -> void:
	if _intro != null:
		_intro.kill()
	_fly_step(from)
	_intro = create_tween()
	_intro.tween_method(_fly_step, from, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(ease)
	_intro.finished.connect(_on_landed)


## Position and look point both travel, so the dais stays framed the whole way.
func _fly_step(t: float) -> void:
	_fly_t = t
	var at: Vector3 = INTRO_FROM.lerp(_home.origin, t)
	var look: Vector3 = INTRO_LOOK.lerp(LOOK_AT, t)
	transform = Transform3D(Basis.looking_at(look - at), at)


func _on_landed() -> void:
	transform = _home
	_target = position
	_idle = 0.0


## Glide back to the home framing now (hand-offs, swings).
func return_home() -> void:
	_target = _rest()
	_idle = 0.0


func _rest() -> Vector3:
	if arena_focus:
		return ARENA_LOOK + _home.basis.z * ARENA_DISTANCE
	return _home.origin


func _input(event: InputEvent) -> void:
	# Any input at all counts as activity; the return starts only when the player has stopped.
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		_idle = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if flying():
		return
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
	if flying():
		return
	var keys: Vector2 = _key_axis()
	if keys != Vector2.ZERO:
		_idle = 0.0
		var step: float = KEY_PAN_SPEED * _height_ratio() * delta
		_pan(keys.x * step, keys.y * step)
	else:
		_idle += delta
		if _idle >= IDLE_SECONDS and not _dragging:
			_target = _rest()
	position = position.lerp(_target, 1.0 - exp(-_glide * delta))


## Dev flags: pan by (dx, dz) table units and zoom `notches` toward the screen centre, then snap.
func dev_set(pan: Vector2, notches: int) -> void:
	var centre: Vector2 = get_viewport().get_visible_rect().size * 0.5
	for i in range(absi(notches)):
		_zoom(signf(notches), centre)
		position = _target
	_pan(pan.x, pan.y)
	position = _target
	_idle = -1e9


func _key_axis() -> Vector2:
	if hand_navigation or get_viewport().gui_get_focus_owner() != null:
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
	_glide = GLIDE
	_target += _home.basis.x * right + _forward_flat() * ahead
	_clamp_target()


## Dolly along the line to the point under the cursor on the table plane: the spot under the
## pointer stays under the pointer, so zooming reads as leaning in rather than as a lens change.
func _zoom(direction: float, screen_pos: Vector2) -> void:
	_glide = GLIDE
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
