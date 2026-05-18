extends Node

const TILE_W: int = 64
const TILE_H: int = 32

const _NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1),
]

var _grid_size: Vector2i = Vector2i.ZERO
var _astar: AStarGrid2D


func setup(size: Vector2i, solid_tiles: Array[Vector2i] = []) -> void:
	_grid_size = size
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(Vector2i.ZERO, size)
	_astar.cell_size = Vector2i(1, 1)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	_astar.jumping_enabled = false
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	for tile: Vector2i in solid_tiles:
		_astar.set_point_solid(tile, true)


func tile_to_world(tile: Vector2i) -> Vector2:
	var tx: float = float(tile.x - tile.y) * (TILE_W / 2.0)
	var ty: float = float(tile.x + tile.y) * (TILE_H / 2.0)
	return Vector2(tx, ty)


func world_to_tile(world: Vector2) -> Vector2i:
	var half_w: float = TILE_W / 2.0
	var half_h: float = TILE_H / 2.0
	var fx: float = (world.x / half_w + world.y / half_h) / 2.0
	var fy: float = (world.y / half_h - world.x / half_w) / 2.0
	return Vector2i(roundi(fx), roundi(fy))


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
