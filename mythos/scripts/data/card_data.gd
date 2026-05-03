class_name CardData
extends Resource

enum CardType { UNIT, BUILDING, SPELL }

@export var id: String = ""
@export var display_name: String = ""
@export var card_type: CardType = CardType.UNIT
@export var cost: int = 0
@export var faction: String = "nordic"
@export var description: String = ""
