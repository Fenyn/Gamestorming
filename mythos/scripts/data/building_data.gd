class_name BuildingData
extends CardData

@export var health: int = 0
@export var resource_generation: int = 0
@export var is_hq: bool = false
@export var effect_text: String = ""
@export var adjacency_text: String = ""

func _init() -> void:
	card_type = CardType.BUILDING
