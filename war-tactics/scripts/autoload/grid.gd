extends Node

const TILE_W: int = 64
const TILE_H: int = 32

const CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]

const _NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
]

var _grid_size: Vector2i = Vector2i.ZERO
var _rotation: int = 0
var _astar: AStarGrid2D
var _elevation: Dictionary = {}
var _cover_tiles: Dictionary = {}
var _structural_solids: Dictionary = {}


func setup_from_level(level: LevelData) -> void:
	_grid_size = level.grid_size
	_elevation.clear()
	_cover_tiles.clear()
	_structural_solids.clear()

	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(Vector2i.ZERO, _grid_size)
	_astar.cell_size = Vector2i(1, 1)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	_astar.jumping_enabled = false
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()

	for tile: Vector2i in level.solid_tiles:
		_astar.set_point_solid(tile, true)
		_structural_solids[tile] = true

	for tile: Vector2i in level.cover_tiles:
		_astar.set_point_solid(tile, true)
		_cover_tiles[tile] = true

	for tile_key: Variant in level.elevation.keys():
		var tile: Vector2i = tile_key as Vector2i
		_elevation[tile] = level.elevation[tile_key]


func setup(size: Vector2i, solid_tiles: Array[Vector2i] = []) -> void:
	var level: LevelData = LevelData.new()
	level.grid_size = size
	level.solid_tiles = solid_tiles
	setup_from_level(level)


func get_grid_size() -> Vector2i:
	return _grid_size


func get_rotation() -> int:
	return _rotation


func rotate_view(direction: int) -> void:
	_rotation = (_rotation + direction) % 4
	if _rotation < 0:
		_rotation += 4


func _rotated_tile(tile: Vector2i) -> Vector2i:
	match _rotation:
		1:
			return Vector2i(tile.y, _grid_size.x - 1 - tile.x)
		2:
			return Vector2i(_grid_size.x - 1 - tile.x, _grid_size.y - 1 - tile.y)
		3:
			return Vector2i(_grid_size.y - 1 - tile.y, tile.x)
	return tile


func tile_to_world(tile: Vector2i) -> Vector2:
	var r: Vector2i = _rotated_tile(tile)
	var tx: float = float(r.x - r.y) * (TILE_W / 2.0)
	var ty: float = float(r.x + r.y) * (TILE_H / 2.0)
	return Vector2(tx, ty)


func world_to_tile(world: Vector2) -> Vector2i:
	var half_w: float = TILE_W / 2.0
	var half_h: float = TILE_H / 2.0
	var fx: float = (world.x / half_w + world.y / half_h) / 2.0
	var fy: float = (world.y / half_h - world.x / half_w) / 2.0
	var rotated: Vector2i = Vector2i(roundi(fx), roundi(fy))
	match _rotation:
		1:
			return Vector2i(_grid_size.x - 1 - rotated.y, rotated.x)
		2:
			return Vector2i(_grid_size.x - 1 - rotated.x, _grid_size.y - 1 - rotated.y)
		3:
			return Vector2i(rotated.y, _grid_size.y - 1 - rotated.x)
	return rotated


func get_elevation(tile: Vector2i) -> int:
	return _elevation.get(tile, 0) as int


func tile_to_world_elevated(tile: Vector2i) -> Vector2:
	var base: Vector2 = tile_to_world(tile)
	var lift: float = get_elevation(tile) * 8.0
	return Vector2(base.x, base.y - lift)


func is_cover_tile(tile: Vector2i) -> bool:
	return _cover_tiles.has(tile)


func is_solid_obstacle(tile: Vector2i) -> bool:
	return _structural_solids.has(tile)


func get_tile_info(tile: Vector2i) -> Dictionary:
	return {
		"tile": tile,
		"elevation": get_elevation(tile),
		"is_cover": is_cover_tile(tile),
		"is_wall": is_solid_obstacle(tile),
		"is_walkable": is_in_bounds(tile) and not _astar.is_point_solid(tile),
	}


func get_cover_at(tile: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for dir: Vector2i in CARDINAL_OFFSETS:
		var adjacent: Vector2i = tile + dir
		if not is_in_bounds(adjacent):
			continue
		if is_cover_tile(adjacent):
			result.append({"direction": dir, "full": false})
		elif is_solid_obstacle(adjacent):
			result.append({"direction": dir, "full": true})
	return result


func get_combat_context(attacker_tile: Vector2i, defender_tile: Vector2i) -> Dictionary:
	var atk_elev: int = get_elevation(attacker_tile)
	var def_elev: int = get_elevation(defender_tile)
	return {
		"elev_diff": atk_elev - def_elev,
		"in_cover": defender_has_cover_from(defender_tile, attacker_tile),
		"has_los": has_line_of_sight(attacker_tile, defender_tile),
	}


func defender_has_cover_from(defender_tile: Vector2i, attacker_tile: Vector2i) -> bool:
	var delta: Vector2i = attacker_tile - defender_tile
	var dirs_to_check: Array[Vector2i] = []
	if delta.x > 0:
		dirs_to_check.append(Vector2i(1, 0))
	elif delta.x < 0:
		dirs_to_check.append(Vector2i(-1, 0))
	if delta.y > 0:
		dirs_to_check.append(Vector2i(0, 1))
	elif delta.y < 0:
		dirs_to_check.append(Vector2i(0, -1))
	for dir: Vector2i in dirs_to_check:
		var adjacent: Vector2i = defender_tile + dir
		if is_cover_tile(adjacent):
			return true
	return false


func tiles_on_line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dx: int = absi(to.x - from.x)
	var dy: int = absi(to.y - from.y)
	var sx: int = 1 if from.x < to.x else -1
	var sy: int = 1 if from.y < to.y else -1
	var err: int = dx - dy
	var current: Vector2i = from
	while current != to:
		result.append(current)
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			current.x += sx
		if e2 < dx:
			err += dx
			current.y += sy
	result.append(to)
	return result


func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return true
	var line: Array[Vector2i] = tiles_on_line(from, to)
	var from_elev: int = get_elevation(from)
	var to_elev: int = get_elevation(to)
	var max_elev: int = maxi(from_elev, to_elev)
	for i: int in range(1, line.size() - 1):
		var tile: Vector2i = line[i]
		if not is_in_bounds(tile):
			return false
		var tile_elev: int = get_elevation(tile)
		if _astar.is_point_solid(tile) and tile_elev >= max_elev:
			return false
		if tile_elev > from_elev and tile_elev > to_elev:
			return false
	return true


func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_in_bounds(from) or not is_in_bounds(to):
		return []
	if _astar.is_point_solid(from) or _astar.is_point_solid(to):
		return []
	var raw_path: PackedVector2Array = _astar.get_point_path(from, to)
	var result: Array[Vector2i] = []
	for point: Vector2 in raw_path:
		result.append(Vector2i(roundi(point.x), roundi(point.y)))
	return result


func reachable_tiles(origin: Vector2i, max_cost: int) -> Array[Vector2i]:
	var costs: Dictionary = {}
	var queue: Array[Vector2i] = [origin]
	costs[origin] = 0

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		var current_cost: int = costs[current] as int

		for offset: Vector2i in _NEIGHBOR_OFFSETS:
			var neighbor: Vector2i = current + offset
			if not is_in_bounds(neighbor):
				continue
			if _astar.is_point_solid(neighbor):
				continue
			if costs.has(neighbor):
				continue

			var is_diagonal: bool = offset.x != 0 and offset.y != 0
			if is_diagonal:
				var adj_a: Vector2i = current + Vector2i(offset.x, 0)
				var adj_b: Vector2i = current + Vector2i(0, offset.y)
				var a_walkable: bool = is_in_bounds(adj_a) and not _astar.is_point_solid(adj_a)
				var b_walkable: bool = is_in_bounds(adj_b) and not _astar.is_point_solid(adj_b)
				if not a_walkable and not b_walkable:
					continue

			var new_cost: int = current_cost + 1
			if new_cost > max_cost:
				continue

			costs[neighbor] = new_cost
			queue.append(neighbor)

	var result: Array[Vector2i] = []
	for tile: Variant in costs.keys():
		var t: Vector2i = tile as Vector2i
		if t != origin:
			result.append(t)
	return result


func tiles_in_diamond_aoe(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if absi(dx) + absi(dy) <= radius:
				var tile: Vector2i = center + Vector2i(dx, dy)
				if is_in_bounds(tile):
					result.append(tile)
	return result


func tiles_in_cone(origin: Vector2i, anchor: Vector2i, max_range: int) -> Array[Vector2i]:
	var dir: Vector2 = Vector2(anchor - origin).normalized()
	if dir.length_squared() < 0.01:
		return []
	var aim_angle: float = atan2(dir.y, dir.x)
	var half_cone: float = PI / 4.0
	var result: Array[Vector2i] = []
	for dy: int in range(-max_range, max_range + 1):
		for dx: int in range(-max_range, max_range + 1):
			if dx == 0 and dy == 0:
				continue
			var dist: int = maxi(absi(dx), absi(dy))
			if dist > max_range:
				continue
			var tile: Vector2i = origin + Vector2i(dx, dy)
			if not is_in_bounds(tile):
				continue
			var tile_angle: float = atan2(float(dy), float(dx))
			var angle_diff: float = absf(fposmod(aim_angle - tile_angle + PI, TAU) - PI)
			if angle_diff <= half_cone and has_line_of_sight(origin, tile):
				result.append(tile)
	return result


func tiles_in_range(origin: Vector2i, max_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy: int in range(-max_range, max_range + 1):
		for dx: int in range(-max_range, max_range + 1):
			if dx == 0 and dy == 0:
				continue
			var dist: int = maxi(absi(dx), absi(dy))
			if dist > max_range:
				continue
			var tile: Vector2i = origin + Vector2i(dx, dy)
			if is_in_bounds(tile):
				result.append(tile)
	return result


func is_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < _grid_size.x and tile.y >= 0 and tile.y < _grid_size.y


func set_tile_solid(tile: Vector2i, solid: bool) -> void:
	if is_in_bounds(tile):
		_astar.set_point_solid(tile, solid)


func diamond_points(center: Vector2, scale_factor: float = 1.0) -> PackedVector2Array:
	var hw: float = (TILE_W / 2.0) * scale_factor
	var hh: float = (TILE_H / 2.0) * scale_factor
	return PackedVector2Array([
		center + Vector2(0.0, -hh),
		center + Vector2(hw, 0.0),
		center + Vector2(0.0, hh),
		center + Vector2(-hw, 0.0),
	])
