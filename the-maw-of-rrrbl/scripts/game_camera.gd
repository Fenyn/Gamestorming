extends Camera3D
class_name GameCamera

@export var target: Vector3 = Vector3.ZERO
@export var distance: float = 20.0
@export var min_distance: float = 5.0
@export var max_distance: float = 50.0
@export var orbit_sensitivity: float = 0.3
@export var pan_sensitivity: float = 0.015
@export var zoom_factor: float = 0.1
@export var smoothing: float = 10.0
@export var pitch: float = -45.0
@export var yaw: float = 30.0
@export var min_pitch: float = -85.0
@export var max_pitch: float = -5.0

var _orbiting: bool = false
var _panning: bool = false
var _goal_target: Vector3
var _goal_distance: float
var _goal_pitch: float
var _goal_yaw: float

func _ready() -> void:
	_goal_target = target
	_goal_distance = distance
	_goal_pitch = pitch
	_goal_yaw = yaw
	_snap_to_goal()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_orbiting = mb.pressed
			MOUSE_BUTTON_MIDDLE:
				_panning = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_goal_distance = maxf(_goal_distance * (1.0 - zoom_factor), min_distance)
			MOUSE_BUTTON_WHEEL_DOWN:
				_goal_distance = minf(_goal_distance * (1.0 + zoom_factor), max_distance)

	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _orbiting:
			_goal_yaw -= motion.relative.x * orbit_sensitivity
			_goal_pitch = clampf(
				_goal_pitch - motion.relative.y * orbit_sensitivity,
				min_pitch, max_pitch
			)
		elif _panning:
			var cam_right: Vector3 = global_transform.basis.x
			var cam_up: Vector3 = global_transform.basis.y
			var scale: float = pan_sensitivity * distance
			_goal_target -= cam_right * motion.relative.x * scale
			_goal_target += cam_up * motion.relative.y * scale

func _process(delta: float) -> void:
	var t: float = 1.0 - exp(-smoothing * delta)
	pitch = lerpf(pitch, _goal_pitch, t)
	yaw = lerpf(yaw, _goal_yaw, t)
	distance = lerpf(distance, _goal_distance, t)
	target = target.lerp(_goal_target, t)
	_apply_transform()

func reset_target(new_target: Vector3) -> void:
	_goal_target = new_target
	target = new_target
	_apply_transform()

func _snap_to_goal() -> void:
	pitch = _goal_pitch
	yaw = _goal_yaw
	distance = _goal_distance
	target = _goal_target
	_apply_transform()

func _apply_transform() -> void:
	var p: float = deg_to_rad(pitch)
	var y: float = deg_to_rad(yaw)
	var offset: Vector3 = Vector3(
		distance * cos(p) * sin(y),
		-distance * sin(p),
		distance * cos(p) * cos(y)
	)
	global_position = target + offset
	look_at(target, Vector3.UP)
