class_name SpellData
extends CardData

enum TargetMode { NONE, TARGET_ON_CAST, TARGET_ON_RESOLVE }
enum TriggerType { ON_CAST, WHILE_ACTIVE, ON_POSITION, ON_RESOLVE }

@export var start_position: int = 1
@export var target_mode: TargetMode = TargetMode.NONE
@export var trigger_types: Array[TriggerType] = []
@export var effect_description: String = ""

func _init() -> void:
	card_type = CardType.SPELL
