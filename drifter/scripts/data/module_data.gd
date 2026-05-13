class_name ModuleData
extends Resource

enum EffectType { DAMAGE, SHIELD, HEAL, DEBUFF_WEAK, DEBUFF_VULNERABLE, BUFF_STRENGTH }
enum AttackAnim { MELEE_COMBO, SUPERCHARGED, RANGED_ORB, BLASTER_LIGHT, BLASTER_HEAVY, DASH }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

@export_group("Sockets")
@export var socket_requirements: Array[SocketRequirement] = []

@export_group("Effect")
@export var effect_type: EffectType = EffectType.DAMAGE
@export var base_value: int = 0
@export var pip_scaling: float = 0.0

@export_group("Behavior")
@export var fires_per_turn: int = 1

@export_group("Visuals")
@export var attack_anim: AttackAnim = AttackAnim.MELEE_COMBO


func get_difficulty() -> int:
	var difficulty: int = 0
	for req: SocketRequirement in socket_requirements:
		match req.type:
			SocketRequirement.Type.ANY:
				difficulty += 1
			SocketRequirement.Type.SPECIFIC:
				difficulty += 5
			SocketRequirement.Type.RANGE:
				difficulty += 3
			SocketRequirement.Type.PARITY:
				difficulty += 2
			SocketRequirement.Type.MATCH:
				difficulty += 4
			SocketRequirement.Type.SEQUENCE:
				difficulty += 4
			SocketRequirement.Type.SUM:
				difficulty += 3
	return difficulty
