extends RigidBody3D

@export var part_id: String = ""
@export var display_name: String = ""

var item_id: String = ""
var sell_price: float = 0.0


func _ready() -> void:
	add_to_group("carriable")
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	item_id = part_id
