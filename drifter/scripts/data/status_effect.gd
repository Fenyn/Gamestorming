class_name StatusEffect
extends Resource

enum Type { WEAK, VULNERABLE, STRENGTH, REGEN }

@export var type: Type = Type.WEAK
@export var stacks: int = 1
@export var duration_turns: int = 1


func tick() -> bool:
	duration_turns -= 1
	return duration_turns <= 0
