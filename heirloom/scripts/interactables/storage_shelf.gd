extends StaticBody3D

@export var slots: int = 6
@export var slot_spacing: float = 0.4

var _stored_items: Array[Node3D] = []
var _slot_markers: Array[Marker3D] = []


func _ready() -> void:
	_create_slots()


func _create_slots() -> void:
	var half: float = float(slots - 1) * slot_spacing / 2.0
	for i: int in slots:
		var marker := Marker3D.new()
		marker.name = "Slot%d" % i
		marker.position = Vector3(float(i) * slot_spacing - half, 0.8, 0.0)
		add_child(marker)
		_slot_markers.append(marker)


func get_interact_hint(player: Node3D) -> String:
	if player.has_held_item():
		var open: int = _get_open_slot()
		if open >= 0:
			return "[Click] Store item (%d/%d)" % [_stored_items.size(), slots]
		return "Storage full"
	if not _stored_items.is_empty():
		var top: Node3D = _stored_items.back()
		var name: String = top.get("display_name") as String
		if name.is_empty():
			name = top.name
		return "[Click] Take %s (%d stored)" % [name, _stored_items.size()]
	return ""


func receive_item(item: Node3D) -> bool:
	var slot_idx: int = _get_open_slot()
	if slot_idx < 0:
		return false

	_stored_items.append(item)
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	item.global_position = _slot_markers[slot_idx].global_position
	item.global_rotation = global_rotation
	return true


func interact(player: Node3D) -> void:
	if _stored_items.is_empty():
		return
	if player.has_held_item():
		return

	var item: Node3D = _stored_items.pop_back()
	if not is_instance_valid(item):
		return
	player.pickup_item(item)


func _get_open_slot() -> int:
	if _stored_items.size() >= slots:
		return -1
	return _stored_items.size()
