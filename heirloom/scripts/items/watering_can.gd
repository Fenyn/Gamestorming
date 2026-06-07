extends RigidBody3D

enum ToolType { NONE, AXE, SHOVEL, WATERING_CAN, FISHING_ROD }
enum ItemCategory { GENERIC, TOOL, FOOD, MATERIAL, CAMARO_PART }

@export var item_id: String = "watering_can"
@export var display_name: String = "Watering Can"
@export var sell_price: float = 0.0
@export var tool_type: ToolType = ToolType.WATERING_CAN
@export var item_category: ItemCategory = ItemCategory.TOOL
@export var hunger_restore: float = 0.0
@export var thirst_restore: float = 0.0

@export var max_uses: int = 4
var uses_remaining: int = 0


func _ready() -> void:
	add_to_group("carriable")
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC


func is_tool() -> bool:
	return true


func is_food() -> bool:
	return false


func is_material() -> bool:
	return false


func is_filled() -> bool:
	return uses_remaining > 0


func fill() -> void:
	uses_remaining = max_uses


func use_water() -> bool:
	if uses_remaining <= 0:
		return false
	uses_remaining -= 1
	return true


func get_status() -> String:
	if uses_remaining <= 0:
		return "empty"
	return "%d/%d" % [uses_remaining, max_uses]
