extends RigidBody3D

@export var item_id: String = ""
@export var display_name: String = ""
@export var sell_price: float = 0.0
@export var hunger_restore: float = 0.0
@export var thirst_restore: float = 0.0


func _ready() -> void:
	add_to_group("carriable")
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
