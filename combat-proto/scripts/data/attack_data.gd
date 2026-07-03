class_name AttackData
extends Resource

enum AttackType { LIGHT, HEAVY, SHOVE, PERILOUS_LUNGE, PERILOUS_SWEEP, PERILOUS_GRAB }

@export_group("Identity")
@export var attack_name: String = ""
@export var attack_type: AttackType = AttackType.LIGHT
@export var stance: StanceDirection.Direction = StanceDirection.Direction.TOP

@export_group("Timing (seconds)")
@export var startup_time: float = 0.2
@export var active_time: float = 0.1
@export var recovery_time: float = 0.2
@export var feint_window: float = 0.0

@export_group("Charge")
@export var is_chargeable: bool = false
@export var charge_time: float = 1.0
@export var charge_damage_multiplier: float = 1.6

@export_group("Damage")
@export var hp_damage: int = 12
@export var posture_on_hit: int = 10
@export var posture_on_block: int = 8
@export var posture_on_deflect: int = 20
@export var stamina_cost: float = 10.0

@export_group("Behavioral Flags")
@export var is_blockable: bool = true
@export var is_deflectable: bool = true
@export var is_dodgeable: bool = true
@export var has_hyper_armor: bool = false
@export var unblockable_at_full_charge: bool = false

@export_group("Perilous")
@export var is_perilous: bool = false
@export var perilous_counter: StringName = &""
@export var indicator_color: Color = Color.WHITE


func get_total_time() -> float:
	return startup_time + active_time + recovery_time


func get_charged_hp_damage() -> int:
	return int(hp_damage * charge_damage_multiplier)


func get_charged_posture_on_hit() -> int:
	return int(posture_on_hit * charge_damage_multiplier)
