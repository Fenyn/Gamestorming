class_name Coin
extends RigidBody3D

const LIFETIME_AFTER_REST := 10.0
const STICK_TIME := 0.0
const COIN_MASS := 0.5

var _spawn_time_ms: int = 0
var _rest_timer: float = 0.0
var _stick_timer: float = 0.0

func _ready() -> void:
	mass = COIN_MASS
	add_to_group("metal")
	add_to_group("coins")
	_spawn_time_ms = Time.get_ticks_msec()
	contact_monitor = false
	can_sleep = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	linear_damp = 3.0
	angular_damp = 8.0
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 1.0
	phys_mat.bounce = 0.0
	physics_material_override = phys_mat

func _physics_process(delta: float) -> void:
	if freeze:
		_rest_timer += delta
		if _rest_timer >= LIFETIME_AFTER_REST:
			queue_free()
		return

	if linear_velocity.length() < 0.2:
		_stick_timer += delta
		if _stick_timer >= STICK_TIME:
			freeze = true
		_rest_timer += delta
		if _rest_timer >= LIFETIME_AFTER_REST:
			queue_free()
	else:
		_stick_timer = 0.0
		_rest_timer = 0.0

func age_seconds() -> float:
	return (Time.get_ticks_msec() - _spawn_time_ms) / 1000.0
