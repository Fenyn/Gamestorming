class_name CockpitCam
extends Camera3D

const FOV_MIN: float = 75.0
const FOV_MAX: float = 85.0
const FOV_SPEED_REF: float = 100.0
const FOV_LERP_SPEED: float = 4.0

const GFORCE_OFFSET_MAX: float = 0.08
const GFORCE_LERP_SPEED: float = 3.0
const GFORCE_SCALE: float = 0.004

var _ship: RigidBody3D
var _rest_position: Vector3
var _current_offset: Vector3 = Vector3.ZERO
var _prev_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	_ship = get_parent() as RigidBody3D
	_rest_position = position
	fov = FOV_MIN


func _physics_process(delta: float) -> void:
	if _ship == null:
		return

	var accel_world: Vector3 = (_ship.linear_velocity - _prev_velocity) / maxf(delta, 0.001)
	_prev_velocity = _ship.linear_velocity

	var accel_local: Vector3 = _ship.basis.inverse() * accel_world
	var target_offset: Vector3 = Vector3(
		clampf(-accel_local.x * GFORCE_SCALE, -GFORCE_OFFSET_MAX, GFORCE_OFFSET_MAX),
		clampf(-accel_local.y * GFORCE_SCALE, -GFORCE_OFFSET_MAX, GFORCE_OFFSET_MAX),
		clampf(-accel_local.z * GFORCE_SCALE * 0.5, -GFORCE_OFFSET_MAX * 0.5, GFORCE_OFFSET_MAX * 0.5)
	)

	_current_offset = _current_offset.lerp(target_offset, GFORCE_LERP_SPEED * delta)
	position = _rest_position + _current_offset


func _process(delta: float) -> void:
	if _ship == null:
		return

	var speed_ratio: float = clampf(_ship.linear_velocity.length() / FOV_SPEED_REF, 0.0, 1.0)
	var target_fov: float = lerpf(FOV_MIN, FOV_MAX, speed_ratio)
	fov = lerpf(fov, target_fov, FOV_LERP_SPEED * delta)
