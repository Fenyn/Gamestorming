class_name ShipConfig
extends Resource

@export_group("Thrust")
@export var main_thrust: float = 5000.0
@export var retro_thrust: float = 2500.0
@export var lateral_thrust: float = 3000.0
@export var vertical_thrust: float = 3000.0

@export_group("Rotation")
@export var pitch_torque: float = 5000.0
@export var yaw_torque: float = 5000.0
@export var roll_torque: float = 600.0

@export_group("Spool-Up")
@export var thrust_spool_rate: float = 30000.0
@export var torque_spool_rate: float = 16000.0

@export_group("Inertia")
@export var inertia_tensor: Vector3 = Vector3(250.0, 350.0, 200.0)

@export_group("Drift Coupling")
@export var coupling_torque: float = 80.0

@export_group("Rotation Dampening (RCS)")
@export var rcs_torque: float = 2000.0
@export var rcs_roll_torque: float = 3500.0

@export_group("Translation Dampening (RCS)")
@export var rcs_thrust: float = 3500.0
@export var velocity_cap: float = 120.0

@export_group("Afterburner")
@export var afterburner_thrust_mult: float = 2.0
@export var afterburner_fuel_max: float = 3.0
@export var afterburner_burn_rate: float = 1.0
@export var afterburner_recharge_rate: float = 0.4
