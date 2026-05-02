extends Node


func set_item_collision(item: Node3D, enabled: bool) -> void:
	for child in item.get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled


func place_at_slot(item: Node3D, slot_position: Vector3) -> void:
	item.global_position = slot_position
	item.global_rotation = Vector3.ZERO
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	set_item_collision(item, false)


func try_pickup(player: Node3D, item: Node3D) -> bool:
	if not player.has_method("has_held_item") or player.has_held_item():
		return false
	if not item or not is_instance_valid(item):
		return false
	set_item_collision(item, true)
	player.pickup_item(item)
	return true


func create_status_label(parent: Node3D, offset: Vector3 = Vector3(0, 1.5, 0)) -> Label3D:
	var label := Label3D.new()
	label.text = ""
	label.font_size = 16
	label.position = offset
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.add_to_group("world_label")
	parent.add_child(label)
	return label
