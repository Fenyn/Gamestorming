extends StaticBody3D

const MAX_SLOTS := 4

var _placed_items: Array[Node3D] = []
var _slots: Array[Marker3D] = []

func _ready() -> void:
	add_to_group("station")

	for i in range(MAX_SLOTS):
		var slot := get_node_or_null("Model/Slot%d" % i) as Marker3D
		if slot == null:
			slot = Marker3D.new()
			slot.name = "Slot%d" % i
			slot.position = Vector3(0.16 * float(i % 2) - 0.08, 0.016, 0.16 * float(i / 2) - 0.08)
			add_child(slot)
		_slots.append(slot)

func receive_item(item: Node3D) -> bool:
	if not item.is_in_group("carriable"):
		return false
	if _placed_items.size() >= MAX_SLOTS:
		return false
	_placed_items.append(item)
	var idx := _placed_items.size() - 1
	StationUtils.place_at_slot(item, _slot_position(idx, item))
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
		StationUtils.set_item_collision(closest, true)
		player.pickup_item(closest)
		_reposition_items()

func _reposition_items() -> void:
	for i in range(_placed_items.size()):
		var item := _placed_items[i]
		if is_instance_valid(item):
			item.global_position = _slot_position(i, item)

func _process(_delta: float) -> void:
	var changed := false
	for i in range(_placed_items.size() - 1, -1, -1):
		var item := _placed_items[i]
		if not item or StationUtils.is_item_removed(item, _slot_position(mini(i, _slots.size() - 1), item)):
			_placed_items.remove_at(i)
			changed = true
	if changed:
		_reposition_items()

## Where an item's centre sits so its base rests on the mat.
func _slot_position(i: int, item: Node3D) -> Vector3:
	return _slots[i].global_position + Vector3(0, StationUtils.item_half_height(item), 0)
