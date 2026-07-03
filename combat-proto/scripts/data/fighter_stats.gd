class_name FighterStats
extends Resource

@export_group("Vitality")
@export var max_hp: int = 100

@export_group("Posture")
@export var max_posture: int = 100
@export var posture_recovery_rate: float = 5.0
@export var guard_recovery_bonus: float = 3.0

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_recovery_rate: float = 15.0
@export var stamina_recovery_pause: float = 0.5
@export var exhaustion_threshold: float = 0.2
@export var exhaustion_speed_penalty: float = 0.3

@export_group("Movement")
@export var move_speed: float = 5.0
@export var dodge_speed: float = 10.0
@export var dodge_duration: float = 0.6
@export var dodge_iframe_start: float = 0.05
@export var dodge_iframe_duration: float = 0.2
@export var jump_duration: float = 0.6
@export var jump_iframe_start: float = 0.1
@export var jump_iframe_duration: float = 0.2
@export var jump_height: float = 1.5

@export_group("Defense Timing")
@export var deflect_window: float = 0.2
@export var counter_shove_window: float = 0.267

@export_group("Posture Break")
@export var posture_break_stun_duration: float = 3.0
@export var deathblow_damage_percent: float = 0.65

@export_group("Posture Recovery Scaling")
@export var hp_bracket_100_75: float = 1.0
@export var hp_bracket_75_50: float = 0.66
@export var hp_bracket_50_25: float = 0.33
@export var hp_bracket_25_0: float = 0.05


func get_posture_recovery_multiplier(hp_percent: float) -> float:
	if hp_percent > 0.75:
		return hp_bracket_100_75
	if hp_percent > 0.50:
		return hp_bracket_75_50
	if hp_percent > 0.25:
		return hp_bracket_50_25
	return hp_bracket_25_0
