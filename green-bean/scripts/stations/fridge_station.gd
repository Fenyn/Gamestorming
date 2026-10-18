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

func take_item(player: Player) -> bool:
	if player.has_held_item() or not _jug_in_fridge or not _milk_jug or not is_instance_valid(_milk_jug):
		return false
	_milk_jug.visible = true
	_milk_jug.global_position = global_position + Vector3(0, 0.5, 0.3)
	StationUtils.set_item_collision(_milk_jug, true)
	player.pickup_item(_milk_jug)
	_jug_in_fridge = false
	_update_label()
	return true

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
		_status_label.text = "[Click] Take out milk"
	else:
		_status_label.text = ""
