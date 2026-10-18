class_name WeightedTable
extends RefCounted

var _entries: Array[Dictionary] = []
var _total_weight: float = 0.0


func add_entry(item: Variant, weight: float) -> void:
	_entries.append({"item": item, "weight": weight})
	_total_weight += weight


func add_entries(entries: Array[Dictionary]) -> void:
	for entry: Dictionary in entries:
		add_entry(entry["item"], entry["weight"] as float)


func pick() -> Variant:
	if _entries.is_empty():
		return null
	var roll: float = randf() * _total_weight
	var cumulative: float = 0.0
	for entry: Dictionary in _entries:
		cumulative += entry["weight"] as float
		if roll <= cumulative:
			return entry["item"]
	return _entries.back()["item"]


func pick_multiple(count: int, allow_duplicates: bool = true) -> Array:
	var results: Array = []
	if allow_duplicates:
		for _i: int in count:
			results.append(pick())
	else:
		var temp_entries: Array[Dictionary] = _entries.duplicate(true)
		var temp_total: float = _total_weight
		for _i: int in mini(count, temp_entries.size()):
			var roll: float = randf() * temp_total
			var cumulative: float = 0.0
			for j: int in temp_entries.size():
				cumulative += temp_entries[j]["weight"] as float
				if roll <= cumulative:
					results.append(temp_entries[j]["item"])
					temp_total -= temp_entries[j]["weight"] as float
					temp_entries.remove_at(j)
					break
	return results


func clear() -> void:
	_entries.clear()
	_total_weight = 0.0


func get_entry_count() -> int:
	return _entries.size()


func get_total_weight() -> float:
	return _total_weight
