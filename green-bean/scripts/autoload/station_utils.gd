extends Node

func set_item_collision(item: Node3D, enabled: bool) -> void:
	for child in item.get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled

func place_at_slot(item: Node3D, slot_position: Vector3) -> void:
	item.global_rotation = Vector3.ZERO
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	set_item_collision(item, false)
	# Drop the last few centimetres with a small bounce so placing feels physical.
	cancel_settle(item)
	item.global_position = slot_position + Vector3(0, 0.04, 0)
	var tween := item.create_tween()
	tween.tween_property(item, "global_position", slot_position, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	item.set_meta("settle_tween", tween)

## Stops a placement bounce, e.g. when the item is picked up again straight away.
func cancel_settle(item: Node3D) -> void:
	if item and item.has_meta("settle_tween"):
		var tween: Tween = item.get_meta("settle_tween")
		if tween and tween.is_valid():
			tween.kill()
		item.remove_meta("settle_tween")

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
			elif child is Node3D and child.name == "Model":
				front_z = maxf(front_z, _model_front_z(parent, child as Node3D))
		pos = Vector3(0, 0.12, front_z + 0.03)
	var label := Label3D.new()
	label.text = ""
	label.font_size = 12
	label.position = pos
	label.pixel_size = 0.002
	label.add_to_group("world_label")
	parent.add_child(label)
	return label

# Front (+Z) edge of an imported model, in the station's local space.
# Stations name their visual model node "Model" so labels clear it like a grey box.
func _model_front_z(parent: Node3D, model: Node3D) -> float:
	var front_z := 0.05
	var to_parent: Transform3D = parent.global_transform.affine_inverse()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var aabb: AABB = to_parent * mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		front_z = maxf(front_z, aabb.end.z)
	return front_z

func is_same_frame(stored_frame: int) -> bool:
	return Engine.get_process_frames() == stored_frame

const KETTLE_SPOUT_TIP := Vector3(0.04, 0.04, -0.06)

var _pour_streams := {}

## flow_check: optional Callable returning true while water is actually flowing.
func start_kettle_pour(player: Player, kettle: Node3D, target_position: Vector3, offset: Vector3, flow_check: Callable = Callable()) -> Tween:
	player.detach_held_item()
	var pour_pos := target_position + offset
	kettle.global_position = pour_pos
	kettle.global_rotation_degrees = Vector3(0, 0, -35)
	var tween := player.create_tween().set_loops()
	tween.tween_property(kettle, "global_rotation_degrees:z", -45.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(kettle, "global_rotation_degrees:z", -30.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_start_stream(kettle, target_position, flow_check)
	return tween

func stop_kettle_pour(tween: Tween, kettle: Node3D, player: Player) -> void:
	if tween and tween.is_valid():
		tween.kill()
	_stop_stream(kettle)
	if kettle and is_instance_valid(kettle):
		kettle.global_rotation_degrees = Vector3.ZERO
		if player and is_instance_valid(player):
			player.pickup_item(kettle)

func _start_stream(kettle: Node3D, target_position: Vector3, flow_check: Callable) -> void:
	_stop_stream(kettle)
	# Drop entries whose stream already freed itself (its kettle was freed mid-pour).
	for key in _pour_streams.keys():
		if not is_instance_valid(_pour_streams[key]):
			_pour_streams.erase(key)
	var stream := PourStream.new()
	stream.source = kettle
	stream.source_offset = KETTLE_SPOUT_TIP
	stream.target_point = target_position
	stream.flow_check = flow_check
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(stream)
	_pour_streams[kettle.get_instance_id()] = stream

func _stop_stream(kettle: Node3D) -> void:
	if kettle == null or not is_instance_valid(kettle):
		return
	var key := kettle.get_instance_id()
	if _pour_streams.has(key):
		var stream: Node = _pour_streams[key]
		if is_instance_valid(stream):
			stream.queue_free()
		_pour_streams.erase(key)
