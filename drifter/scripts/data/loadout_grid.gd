class_name LoadoutGrid
extends RefCounted

const COLS: int = 3
const ROWS: int = 4
const CELL_UNLOCK_COST: int = 20

var _unlocked: Array[Array] = []
var _cells: Array[Array] = []
var _placements: Array[Dictionary] = []


func _init() -> void:
	clear()


func clear() -> void:
	_unlocked = []
	_cells = []
	for y: int in ROWS:
		var unlock_row: Array[bool] = []
		var cell_row: Array[int] = []
		unlock_row.resize(COLS)
		cell_row.resize(COLS)
		unlock_row.fill(false)
		cell_row.fill(-1)
		_unlocked.append(unlock_row)
		_cells.append(cell_row)
	_placements.clear()
	_unlock_starting_cells()


func _unlock_starting_cells() -> void:
	for row: int in 3:
		for col: int in 2:
			_unlocked[row][col] = true


func is_unlocked(col: int, row: int) -> bool:
	if not _in_bounds(col, row):
		return false
	return _unlocked[row][col]


func get_unlocked_count() -> int:
	var count: int = 0
	for row: int in ROWS:
		for col: int in COLS:
			if _unlocked[row][col]:
				count += 1
	return count


func get_locked_expandable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row: int in ROWS:
		for col: int in COLS:
			if not _unlocked[row][col] and _has_unlocked_neighbor(col, row):
				result.append(Vector2i(col, row))
	return result


func can_unlock_cell(col: int, row: int) -> bool:
	if not _in_bounds(col, row):
		return false
	if _unlocked[row][col]:
		return false
	return _has_unlocked_neighbor(col, row)


func unlock_cell(col: int, row: int) -> bool:
	if not can_unlock_cell(col, row):
		return false
	_unlocked[row][col] = true
	return true


func is_fully_unlocked() -> bool:
	return get_unlocked_count() >= COLS * ROWS


func _has_unlocked_neighbor(col: int, row: int) -> bool:
	for dir: Vector2i in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
		var nc: int = col + dir.x
		var nr: int = row + dir.y
		if _in_bounds(nc, nr) and _unlocked[nr][nc]:
			return true
	return false


func get_module_count() -> int:
	var count: int = 0
	for placement: Dictionary in _placements:
		if placement["module"] != null:
			count += 1
	return count


func get_placements() -> Array[Dictionary]:
	return _placements


func get_module_at(col: int, row: int) -> ModuleData:
	if not _in_bounds(col, row):
		return null
	var idx: int = _cells[row][col]
	if idx < 0:
		return null
	return _placements[idx]["module"] as ModuleData


func get_placement_index_at(col: int, row: int) -> int:
	if not _in_bounds(col, row):
		return -1
	return _cells[row][col]


func can_place(module: ModuleData, origin_col: int, origin_row: int, rotation: int = 0) -> bool:
	var shape: Array[Vector2i] = module.get_rotated_shape(rotation)
	for offset: Vector2i in shape:
		var c: int = origin_col + offset.x
		var r: int = origin_row + offset.y
		if not _in_bounds(c, r):
			return false
		if not _unlocked[r][c]:
			return false
		if _cells[r][c] >= 0:
			return false
	return true


func place(module: ModuleData, origin_col: int, origin_row: int, rotation: int = 0) -> bool:
	if not can_place(module, origin_col, origin_row, rotation):
		return false

	var shape: Array[Vector2i] = module.get_rotated_shape(rotation)
	var idx: int = _placements.size()
	_placements.append({
		"module": module,
		"origin": Vector2i(origin_col, origin_row),
		"rotation": rotation,
		"shape": shape,
	})

	for offset: Vector2i in shape:
		_cells[origin_row + offset.y][origin_col + offset.x] = idx

	return true


func remove_at(col: int, row: int) -> ModuleData:
	var idx: int = get_placement_index_at(col, row)
	if idx < 0:
		return null

	var placement: Dictionary = _placements[idx]
	var module: ModuleData = placement["module"] as ModuleData
	var shape: Array = placement.get("shape", module.grid_shape) as Array
	var origin: Vector2i = placement["origin"] as Vector2i

	for offset: Variant in shape:
		var v: Vector2i = offset as Vector2i
		_cells[origin.y + v.y][origin.x + v.x] = -1

	_placements[idx] = {"module": null, "origin": Vector2i(-1, -1), "rotation": 0, "shape": []}
	return module


func get_all_modules() -> Array[ModuleData]:
	var result: Array[ModuleData] = []
	for placement: Dictionary in _placements:
		var module: ModuleData = placement["module"] as ModuleData
		if module:
			result.append(module)
	return result


func get_neighbors(col: int, row: int) -> Array[ModuleData]:
	var result: Array[ModuleData] = []
	var seen_indices: Array[int] = []
	var self_idx: int = get_placement_index_at(col, row)

	for dir: Vector2i in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
		var nc: int = col + dir.x
		var nr: int = row + dir.y
		var idx: int = get_placement_index_at(nc, nr)
		if idx >= 0 and idx != self_idx and idx not in seen_indices:
			var module: ModuleData = _placements[idx]["module"] as ModuleData
			if module:
				result.append(module)
				seen_indices.append(idx)

	return result


func is_cell_empty(col: int, row: int) -> bool:
	if not _in_bounds(col, row):
		return false
	if not _unlocked[row][col]:
		return false
	return _cells[row][col] < 0


func find_valid_placements(module: ModuleData, rotation: int = 0) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row: int in ROWS:
		for col: int in COLS:
			if can_place(module, col, row, rotation):
				result.append(Vector2i(col, row))
	return result


func find_any_valid_placement(module: ModuleData) -> Dictionary:
	for rot: int in 4:
		var placements: Array[Vector2i] = find_valid_placements(module, rot)
		if not placements.is_empty():
			return {"position": placements[0], "rotation": rot}
	return {}


func _in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < COLS and row >= 0 and row < ROWS
