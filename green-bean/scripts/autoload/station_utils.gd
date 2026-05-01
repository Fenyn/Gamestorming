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

func is_item_removed(item: Node3D, slot_position: Vector3, threshold: float = 0.5) -> bool:
	if not item or not is_instance_valid(item):
		return true
	if item.global_position.distance_to(slot_position) > threshold:
		return true
	return false

func try_pickup_shelf(player: Player, item: Node3D) -> bool:
	if player.has_held_item():
		return false
	if not item or not is_instance_valid(item):
		return false
	player.pickup_item(item)
	return true

func try_pickup_placed(player: Player, item: Node3D) -> bool:
	if player.has_held_item():
		return false
	if not item or not is_instance_valid(item):
		return false
	set_item_collision(item, true)
	player.pickup_item(item)
	return true

func create_status_label(parent: Node3D, offset := Vector3(-999, 0, 0)) -> Label3D:
	var pos := offset
	if pos.x == -999:
		var front_z := 0.05
		for child in parent.get_children():
			if child is CSGBox3D:
				front_z = maxf(front_z, child.position.z + (child as CSGBox3D).size.z * 0.5)
			elif child is CSGCylinder3D:
				front_z = maxf(front_z, child.position.z + (child as CSGCylinder3D).radius)
		pos = Vector3(0, 0.12, front_z + 0.03)
	var label := Label3D.new()
	label.text = ""
	label.font_size = 12
	label.position = pos
	label.pixel_size = 0.002
	label.add_to_group("world_label")
	parent.add_child(label)
	return label

func is_same_frame(stored_frame: int) -> bool:
	return Engine.get_process_frames() == stored_frame

func start_kettle_pour(player: Player, kettle: Node3D, target_position: Vector3, offset: Vector3) -> Tween:
	player.detach_held_item()
	var pour_pos := target_position + offset
	kettle.global_position = pour_pos
	kettle.global_rotation_degrees = Vector3(0, 0, -35)
	var tween := player.create_tween().set_loops()
	tween.tween_property(kettle, "global_rotation_degrees:z", -45.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(kettle, "global_rotation_degrees:z", -30.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

func stop_kettle_pour(tween: Tween, kettle: Node3D, player: Player) -> void:
	if tween and tween.is_valid():
		tween.kill()
	if kettle and is_instance_valid(kettle):
		kettle.global_rotation_degrees = Vector3.ZERO
		if player and is_instance_valid(player):
			player.pickup_item(kettle)
