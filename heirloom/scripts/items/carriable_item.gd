extends RigidBody3D

enum ToolType { NONE, AXE, SHOVEL, WATERING_CAN, FISHING_ROD }
enum ItemCategory { GENERIC, TOOL, FOOD, MATERIAL, CAMARO_PART }

@export var item_id: String = ""
@export var display_name: String = ""
@export var sell_price: float = 0.0
@export var tool_type: ToolType = ToolType.NONE
@export var item_category: ItemCategory = ItemCategory.GENERIC
@export var hunger_restore: float = 0.0
@export var thirst_restore: float = 0.0


func _ready() -> void:
	add_to_group("carriable")
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC


func is_tool() -> bool:
	return tool_type != ToolType.NONE


func is_food() -> bool:
	return item_category == ItemCategory.FOOD


func is_material() -> bool:
	return item_category == ItemCategory.MATERIAL
