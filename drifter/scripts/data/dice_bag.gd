class_name DiceBag
extends RefCounted

var _bag: Array[CellData] = []
var _discard: Array[CellData] = []
var _all_dice: Array[CellData] = []
var draw_count: int = 3
var draw_bonus: int = 0


func setup(dice: Array[CellData], base_draw: int, bonus: int) -> void:
	_all_dice = dice.duplicate()
	draw_count = base_draw
	draw_bonus = bonus
	reshuffle_all()


func reshuffle_all() -> void:
	_bag = _all_dice.duplicate()
	_discard.clear()
	_shuffle_bag()


func get_draw_total() -> int:
	return draw_count + draw_bonus


func draw(count: int = -1) -> Array[CellData]:
	if count < 0:
		count = get_draw_total()

	var drawn: Array[CellData] = []
	for i: int in count:
		if _bag.is_empty():
			_reshuffle_discard()
		if _bag.is_empty():
			break
		drawn.append(_bag.pop_back())
	return drawn


func discard(cell: CellData) -> void:
	_discard.append(cell)


func discard_multiple(cells: Array[CellData]) -> void:
	for cell: CellData in cells:
		_discard.append(cell)


func add_die(cell: CellData) -> void:
	_all_dice.append(cell)
	_bag.append(cell)
	_shuffle_bag()


func remove_die(cell: CellData) -> bool:
	var idx: int = _all_dice.find(cell)
	if idx < 0:
		return false
	_all_dice.remove_at(idx)

	var bag_idx: int = _bag.find(cell)
	if bag_idx >= 0:
		_bag.remove_at(bag_idx)
		return true

	var disc_idx: int = _discard.find(cell)
	if disc_idx >= 0:
		_discard.remove_at(disc_idx)
	return true


func get_bag_contents() -> Array[CellData]:
	return _bag.duplicate()


func get_discard_contents() -> Array[CellData]:
	return _discard.duplicate()


func get_all_dice() -> Array[CellData]:
	return _all_dice.duplicate()


func get_bag_size() -> int:
	return _bag.size()


func get_discard_size() -> int:
	return _discard.size()


func get_total_size() -> int:
	return _all_dice.size()


func _reshuffle_discard() -> void:
	_bag.append_array(_discard)
	_discard.clear()
	_shuffle_bag()


func _shuffle_bag() -> void:
	for i: int in range(_bag.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var temp: CellData = _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = temp
