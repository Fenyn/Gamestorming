class_name HitResult
extends RefCounted

enum Outcome {
	HIT,
	BLOCKED,
	DEFLECTED,
	DODGED,
	PERILOUS_COUNTERED,
	GRABBED,
	MISSED,
}

var outcome: Outcome = Outcome.HIT
var hp_damage_to_defender: int = 0
var posture_damage_to_defender: int = 0
var posture_damage_to_attacker: int = 0
var stamina_cost_to_defender: float = 0.0
var defender_state_transition: StringName = &""
var attacker_state_transition: StringName = &""
var counter_type: StringName = &""


static func hit(attack: AttackData) -> HitResult:
	var result: HitResult = HitResult.new()
	result.outcome = Outcome.HIT
	result.hp_damage_to_defender = attack.hp_damage
	result.posture_damage_to_defender = attack.posture_on_hit
	result.defender_state_transition = &"Hitstun"
	return result


static func blocked(attack: AttackData) -> HitResult:
	var result: HitResult = HitResult.new()
	result.outcome = Outcome.BLOCKED
	result.posture_damage_to_defender = attack.posture_on_block
	result.stamina_cost_to_defender = 5.0
	return result


static func deflected(attack: AttackData) -> HitResult:
	var result: HitResult = HitResult.new()
	result.outcome = Outcome.DEFLECTED
	result.posture_damage_to_attacker = attack.posture_on_deflect
	result.defender_state_transition = &"Deflecting"
	return result


static func dodged() -> HitResult:
	var result: HitResult = HitResult.new()
	result.outcome = Outcome.DODGED
	return result


static func missed() -> HitResult:
	var result: HitResult = HitResult.new()
	result.outcome = Outcome.MISSED
	return result


static func perilous_countered(counter: StringName, posture_to_attacker: int) -> HitResult:
	var result: HitResult = HitResult.new()
	result.outcome = Outcome.PERILOUS_COUNTERED
	result.posture_damage_to_attacker = posture_to_attacker
	result.counter_type = counter
	return result


static func grabbed(attack: AttackData) -> HitResult:
	var result: HitResult = HitResult.new()
	result.outcome = Outcome.GRABBED
	result.hp_damage_to_defender = attack.hp_damage
	result.posture_damage_to_defender = attack.posture_on_hit
	result.defender_state_transition = &"Grabbed"
	return result
