class_name Ship
extends RigidBody3D

@export var config: ShipConfig

var rotation_dampening: bool = true
var translation_dampening: bool = true
var afterburner_fuel: float = 0.0
var is_afterburning: bool = false

var _thrust_current: Vector3 = Vector3.ZERO
var _torque_current: Vector3 = Vector3.ZERO
var _emit_tick: int = 0

var _rcs_activity: Vector3 = Vector3.ZERO

@onready var _thruster_light: OmniLight3D = %ThrusterLight
@onready var _effects: ShipEffects = %ShipEffects


func _ready() -> void:
	if config == null:
		config = ShipConfig.new()
	afterburner_fuel = config.afterburner_fuel_max
	inertia = config.inertia_tensor


func _physics_process(delta: float) -> void:
	var thrust: Vector3 = InputManager.thrust_input
	var look: Vector2 = InputManager.look_input
	var roll: float = InputManager.roll_input

	_apply_thrust(thrust, delta)
	_apply_rotation(look, roll, delta)

	if rotation_dampening:
		_apply_rotation_dampening(look, roll)
	if translation_dampening:
		_apply_translation_dampening(thrust)

	_apply_drift_coupling()
	_apply_velocity_cap()
	_handle_afterburner(thrust, delta)
	_handle_toggles()
	_emit_state()


func _apply_thrust(thrust: Vector3, delta: float) -> void:
	var forward_target: float = thrust.z * config.main_thrust
	if thrust.z < 0.0:
		forward_target = thrust.z * config.retro_thrust

	if is_afterburning and thrust.z > 0.0:
		forward_target *= config.afterburner_thrust_mult

	var target: Vector3 = Vector3(
		thrust.x * config.lateral_thrust,
		thrust.y * config.vertical_thrust,
		-forward_target
	)

	_thrust_current = _thrust_current.move_toward(target, config.thrust_spool_rate * delta)
	apply_central_force(basis * _thrust_current)

	var thrust_ratio: float = clampf(_thrust_current.length() / config.main_thrust, 0.0, 1.0)
	var light_energy: float = thrust_ratio * 3.0
	if is_afterburning:
		light_energy *= 2.0
		_thruster_light.light_color = Color(1.0, 0.4, 0.1, 1)
	else:
		_thruster_light.light_color = Color(1.0, 0.6, 0.2, 1)
	_thruster_light.light_energy = light_energy

	_effects.update_effects(thrust_ratio, is_afterburning, _rcs_activity)


func _apply_rotation(look: Vector2, roll: float, delta: float) -> void:
	var target: Vector3 = Vector3(
		look.x * config.pitch_torque,
		look.y * config.yaw_torque,
		-roll * config.roll_torque
	)

	_torque_current = _torque_current.move_toward(target, config.torque_spool_rate * delta)
	apply_torque(basis * _torque_current)


func _apply_rotation_dampening(look: Vector2, roll: float) -> void:
	var rcs: Vector3 = Vector3.ZERO

	if absf(look.x) < 0.001 and absf(angular_velocity.x) > 0.001:
		rcs.x = -signf(angular_velocity.x) * minf(absf(angular_velocity.x) * 50.0, config.rcs_torque)
	if absf(look.y) < 0.001 and absf(angular_velocity.y) > 0.001:
		rcs.y = -signf(angular_velocity.y) * minf(absf(angular_velocity.y) * 50.0, config.rcs_torque)
	if absf(roll) < 0.1 and absf(angular_velocity.z) > 0.001:
		rcs.z = -signf(angular_velocity.z) * minf(absf(angular_velocity.z) * 80.0, config.rcs_roll_torque)

	apply_torque(rcs)


func _apply_translation_dampening(thrust: Vector3) -> void:
	var local_vel: Vector3 = basis.inverse() * linear_velocity
	var rcs: Vector3 = Vector3.ZERO

	if absf(thrust.x) < 0.1 and absf(local_vel.x) > 0.1:
		rcs.x = -signf(local_vel.x) * minf(absf(local_vel.x) * 20.0, config.rcs_thrust)
	if absf(thrust.y) < 0.1 and absf(local_vel.y) > 0.1:
		rcs.y = -signf(local_vel.y) * minf(absf(local_vel.y) * 20.0, config.rcs_thrust)
	if absf(thrust.z) < 0.1 and absf(local_vel.z) > 0.1:
		rcs.z = -signf(local_vel.z) * minf(absf(local_vel.z) * 20.0, config.rcs_thrust)

	_rcs_activity = rcs / maxf(config.rcs_thrust, 1.0)
	apply_central_force(basis * rcs)


func _apply_drift_coupling() -> void:
	var local_vel: Vector3 = basis.inverse() * linear_velocity
	var speed: float = linear_velocity.length()
	if speed < 5.0:
		return

	var lateral_ratio: float = absf(local_vel.x) / maxf(speed, 1.0)
	var yaw_coupling: float = signf(local_vel.x) * lateral_ratio * config.coupling_torque
	apply_torque(basis * Vector3(0.0, -yaw_coupling, 0.0))

	var vertical_ratio: float = absf(local_vel.y) / maxf(speed, 1.0)
	var pitch_coupling: float = signf(local_vel.y) * vertical_ratio * config.coupling_torque
	apply_torque(basis * Vector3(pitch_coupling, 0.0, 0.0))


func _apply_velocity_cap() -> void:
	var speed: float = linear_velocity.length()
	if speed > config.velocity_cap:
		var overshoot: float = speed - config.velocity_cap
		var brake_force: float = minf(overshoot * 100.0, config.rcs_thrust * 2.0)
		apply_central_force(-linear_velocity.normalized() * brake_force)


func _handle_afterburner(thrust: Vector3, delta: float) -> void:
	var wants_burn: bool = InputManager.is_action_pressed(&"afterburner") and thrust.z > 0.0

	if wants_burn and afterburner_fuel > 0.0:
		is_afterburning = true
		afterburner_fuel -= config.afterburner_burn_rate * delta
		afterburner_fuel = maxf(afterburner_fuel, 0.0)
	else:
		is_afterburning = false
		afterburner_fuel += config.afterburner_recharge_rate * delta
		afterburner_fuel = minf(afterburner_fuel, config.afterburner_fuel_max)

	EventBus.afterburner_changed.emit(
		afterburner_fuel, config.afterburner_fuel_max, is_afterburning
	)


func _handle_toggles() -> void:
	if InputManager.is_action_just_pressed(&"toggle_rot_dampen"):
		rotation_dampening = not rotation_dampening
		EventBus.rotation_dampening_changed.emit(rotation_dampening)

	if InputManager.is_action_just_pressed(&"toggle_trans_dampen"):
		translation_dampening = not translation_dampening
		EventBus.translation_dampening_changed.emit(translation_dampening)


func _emit_state() -> void:
	_emit_tick += 1
	if _emit_tick % 3 == 0:
		EventBus.speed_changed.emit(linear_velocity.length())
		EventBus.angular_velocity_changed.emit(angular_velocity)
		EventBus.input_state_changed.emit(
			InputManager.thrust_input, InputManager.look_input, InputManager.roll_input
		)
