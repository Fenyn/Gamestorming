class_name CargoPod
extends StaticBody2D

signal pod_opened

var _cargo: Dictionary = {}


func get_cargo() -> Dictionary:
	return _cargo


func interact(_player: Node2D) -> void:
	pod_opened.emit()


func get_interact_hint() -> String:
	var total: int = _count_cargo_items()
	if total == 0:
		return "E/Click: Open _cargo pod (empty)"
	return "E/Click: Open _cargo pod (%d items loaded)" % total


func add_to_cargo(item_id: String, count: int) -> void:
	_cargo[item_id] = _cargo.get(item_id, 0) + count


func remove_from_cargo(item_id: String, count: int) -> bool:
	var current: int = _cargo.get(item_id, 0)
	if current < count:
		return false
	_cargo[item_id] = current - count
	if _cargo[item_id] <= 0:
		_cargo.erase(item_id)
	return true


func launch() -> Dictionary:
	var shipped: Dictionary = _cargo.duplicate()
	_cargo.clear()
	return shipped


func get_cargo_food_total() -> int:
	var total: int = 0
	for item_id: String in _cargo:
		var crop: CropData = Database.get_crop(item_id)
		if crop:
			total += crop.food_units * _cargo[item_id]
	return total


func _count_cargo_items() -> int:
	var total: int = 0
	for item_id: String in _cargo:
		total += _cargo[item_id]
	return total
