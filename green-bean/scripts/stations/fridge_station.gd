extends StaticBody3D

var _milk_jug: MilkJug = null
var _jug_in_fridge := true
var _status_label: Label3D = null

func _ready() -> void:
	add_to_group("station")

	_milk_jug = MilkJug.new()
	_milk_jug.name = "MilkJug"
	add_child(_milk_jug)
	_milk_jug.position = Vector3(0, 0.3, 0)
	_milk_jug.visible = false

	_status_label = StationUtils.create_status_label(self)
	_update_label()

func interact(player: Player) -> void:
	var held := player.get_held_item()

	if held is MilkJug:
		player.drop_held_item()
		held.visible = false
		held.global_position = global_position + Vector3(0, 0.3, 0)
		if held is RigidBody3D:
			(held as RigidBody3D).freeze = true
		_milk_jug = held
		_jug_in_fridge = true
		_update_label()
		return

	if not held and _jug_in_fridge and _milk_jug and is_instance_valid(_milk_jug):
		_milk_jug.visible = true
		_milk_jug.global_position = global_position + Vector3(0, 0.5, 0.3)
		StationUtils.set_item_collision(_milk_jug, true)
		player.pickup_item(_milk_jug)
		_jug_in_fridge = false
		_update_label()
		return

func receive_item(item: Node3D) -> bool:
	if item is MilkJug:
		item.visible = false
		item.global_position = global_position + Vector3(0, 0.3, 0)
		if item is RigidBody3D:
			(item as RigidBody3D).freeze = true
		_milk_jug = item
		_jug_in_fridge = true
		_update_label()
		return true
	return false

func _update_label() -> void:
	if not _status_label:
		return
	if _jug_in_fridge:
		_status_label.text = "[E] Take out milk"
	else:
		_status_label.text = "Milk jug is out"
