extends RigidBody3D

var item_id: String = "fish_common"
var display_name: String = "Common Fish"
var sell_price: float = 8.0


func _ready() -> void:
	add_to_group("carriable")
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC


func set_fish_type(id: String, name: String, price: float) -> void:
	item_id = id
	display_name = name
	sell_price = price
