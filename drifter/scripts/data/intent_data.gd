class_name IntentData
extends Resource

enum IntentType {
	ATTACK,
	DEFEND,
	BUFF,
	DEBUFF,
	SPECIAL_SUMMON,
	SPECIAL_SUSTAINED_FIRE,
	SPECIAL_MAGNETIC_PULSE,
}

@export var type: IntentType = IntentType.ATTACK
@export var value: int = 0
@export var description: String = ""
