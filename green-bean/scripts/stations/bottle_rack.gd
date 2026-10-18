extends StaticBody3D

const MAX_SLOTS := 3

var _placed_bottles: Array[SauceBottle] = []
var _slots: Array[Marker3D] = []

func _ready() -> void:
	add_to_group("station")

	for i in range(MAX_SLOTS):
		var slot := get_node_or_null("Model/Slot%d" % i) as Marker3D
		if slot == null:
			slot = Marker3D.new()
			slot.name = "Slot%d" % i
			slot.position = Vector3((float(i) - 1.0) * 0.075, 0.004, 0)
			add_child(slot)
		_slots.append(slot)

func receive_item(item: Node3D) -> bool:
	if not item is SauceBottle:
		return false
	if _placed_bottles.size() >= MAX_SLOTS:
		return false
	_placed_bottles.append(item as SauceBottle)
	var idx := _placed_bottles.size() - 1
	StationUtils.place_at_slot(item, _slot_position(idx, item))
	return true

func take_item(player: Player) -> bool:
	if _placed_bottles.is_empty() or player.has_held_item():
		return false
	var closest: SauceBottle = null
	var closest_dist := 999.0
	var ray_origin := player.camera.global_position
	var ray_dir := -player.camera.global_transform.basis.z
	for bottle in _placed_bottles:
		if not is_instance_valid(bottle):
			continue
		var to_item := bottle.global_position - ray_origin
		var proj := to_item.dot(ray_dir)
		if proj < 0:
			continue
		var perp := (to_item - ray_dir * proj).length()
		if perp < closest_dist:
			closest_dist = perp
			closest = bottle
	if not closest and not _placed_bottles.is_empty():
		closest = _placed_bottles.back()
	if closest and is_instance_valid(closest):
		_placed_bottles.erase(closest)
		StationUtils.set_item_collision(closest, true)
		player.pickup_item(closest)
		_reposition()
		return true
	return false

func _reposition() -> void:
	for i in range(_placed_bottles.size()):
		if is_instance_valid(_placed_bottles[i]):
			_placed_bottles[i].global_position = _slot_position(i, _placed_bottles[i])

func _process(_delta: float) -> void:
	var changed := false
	for i in range(_placed_bottles.size() - 1, -1, -1):
		var bottle := _placed_bottles[i]
		if not bottle or StationUtils.is_item_removed(bottle, _slot_position(mini(i, _slots.size() - 1), bottle)):
			_placed_bottles.remove_at(i)
			changed = true
	if changed:
		_reposition()

## Bottle centre so its base sits on the rack floor.
func _slot_position(i: int, item: Node3D) -> Vector3:
	return _slots[i].global_position + Vector3(0, StationUtils.item_half_height(item, 0.1), 0)
