class_name ItemData
extends Resource

enum ItemType { SELLABLE, CONSUMABLE, MATERIAL, CAMARO_PART }

@export var item_id: String = ""
@export var display_name: String = ""
@export var item_type: ItemType = ItemType.SELLABLE
@export var sell_price: float = 0.0
@export var buy_price: float = 0.0
@export var hunger_restore: float = 0.0
@export var thirst_restore: float = 0.0
@export var stackable: bool = true
