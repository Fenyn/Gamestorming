class_name UnitData
extends CardData

@export var attack: int = 0
@export var health: int = 0
@export var keywords: Array[KeywordData] = []

func _init() -> void:
	card_type = CardType.UNIT
