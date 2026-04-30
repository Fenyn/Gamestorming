extends StaticBody3D

const MAX_SLOTS := 4

var _placed_items: Array[Node3D] = []
var _slots: Array[Marker3D] = []

func _ready() -> void:
	add_to_group("station")

	var offsets := [
		Vector3(-0.08, 0.04, -0.05),
		Vector3(0.08, 0.04, -0.05),
		Vector3(-0.08, 0.04, 0.05),
		Vector3(0.08, 0.04, 0.05),
	]
	for i in range(MAX_SLOTS):
		var slot := Marker3D.new()
		slot.name = "Slot%d" % i
		slot.position = offsets[i]
		add_child(slot)
		_slots.append(slot)

func receive_item(item: Node3D) -> bool:
	if not item.is_in_group("carriable"):
		return false
	if _placed_items.size() >= MAX_SLOTS:
		return false
	_placed_items.append(item)
	var idx := _placed_items.size() - 1
	item.global_position = _slots[idx].global_position
	item.global_rotation = Vector3.ZERO
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	for child in item.get_children():
		if child is CollisionShape3D:
			child.disabled = true
	return true

func interact(player: Player) -> void:
	if _placed_items.is_empty() or player.has_held_item():
		return
	var closest: Node3D = null
	var closest_dist := 999.0
	var ray_origin := player.camera.global_position
	var ray_dir := -player.camera.global_transform.basis.z
	for item in _placed_items:
		if not is_instance_valid(item):
			continue
		var to_item := item.global_position - ray_origin
		var proj := to_item.dot(ray_dir)
		if proj < 0:
			continue
		var perp := (to_item - ray_dir * proj).length()
		if perp < closest_dist:
			closest_dist = perp
			closest = item
	if not closest:
		closest = _placed_items.back()
	if closest and is_instance_valid(closest):
		_placed_items.erase(closest)
		for child in closest.get_children():
			if child is CollisionShape3D:
				child.disabled = false
		player.pickup_item(closest)
		_reposition_items()

func _reposition_items() -> void:
	for i in range(_placed_items.size()):
		var item := _placed_items[i]
		if is_instance_valid(item):
			item.global_position = _slots[i].global_position

func _process(_delta: float) -> void:
	var changed := false
	for i in range(_placed_items.size() - 1, -1, -1):
		var item := _placed_items[i]
		if not is_instance_valid(item):
			_placed_items.remove_at(i)
			changed = true
		elif item.global_position.distance_to(_slots[mini(i, _slots.size() - 1)].global_position) > 0.5:
			_placed_items.remove_at(i)
			changed = true
	if changed:
		_reposition_items()
