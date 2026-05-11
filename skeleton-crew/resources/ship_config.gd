class_name ShipConfig
extends Resource

@export_group("Flight - Thrust")
@export var base_thrust: float = 40.0
@export var retro_ratio: float = 0.5
@export var lateral_ratio: float = 0.4
@export var vertical_ratio: float = 0.4

@export_group("Flight - Rotation")
@export var base_torque: float = 3.0
@export var angular_drag: float = 4.0
@export var bank_amount: float = 0.3
@export var pitch_ratio: float = 0.6
@export var roll_speed: float = 2.0

@export_group("Flight - Handling")
@export var base_coupling: float = 0.7
@export var drag_coefficient: float = 0.02

@export_group("Flight - Afterburner")
@export var afterburner_thrust_mult: float = 1.5
@export var afterburner_coupling_mult: float = 0.6
@export var afterburner_duration: float = 2.5
@export var afterburner_cooldown: float = 6.0

@export_group("Hull")
@export var face_max_hp: int = 50

@export_group("Shields")
@export var shield_max: float = 100.0
@export var shield_regen_base: float = 5.0
@export var shield_min_absorption: float = 0.3
@export var shield_max_absorption: float = 1.0
@export var shield_emitter_direction: Vector3 = Vector3.UP

@export_group("Weapons")
@export var turret_energy_max: float = 100.0
@export var turret_energy_per_shot: float = 15.0
@export var turret_fire_cooldown: float = 0.4
@export var projectile_speed: float = 80.0
@export var projectile_damage: int = 10
@export var projectile_lifetime: float = 5.0

@export_group("Power")
@export var total_pips: int = 6
@export var max_pips_per_system: int = 4
@export var default_weapons: int = 2
@export var default_shields: int = 2
@export var default_engines: int = 2

@export_group("Crew")
@export var crew_max_health: int = 100
@export var o2_damage_rate: float = 5.0
@export var downed_bleedout_time: float = 30.0
@export var revive_health: int = 25
