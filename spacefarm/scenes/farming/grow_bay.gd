class_name GrowBay
extends Node2D

const TILE_SPACING: int = 34
const GRID_WIDTH: int = 4
const GRID_HEIGHT: int = 4

var _tiles: Array[CropTile] = []


func get_biome() -> String:
	var room: BaseRoom = get_parent() as BaseRoom
	return room.biome if room else "verdant"


func _ready() -> void:
	var half_grid: float = (GRID_WIDTH - 1) * TILE_SPACING / 2.0
	for child: Node in get_children():
		if child is CropTile:
			var tile: CropTile = child as CropTile
			var grid_x: int = roundi((tile.position.x + half_grid) / TILE_SPACING)
			var grid_y: int = roundi((tile.position.y + half_grid) / TILE_SPACING)
			tile.grid_position = Vector2i(grid_x, grid_y)
			tile.is_near_window = (grid_y == 0)
			_tiles.append(tile)


func get_tile_at(grid_pos: Vector2i) -> CropTile:
	for tile: CropTile in _tiles:
		if tile.grid_position == grid_pos:
			return tile
	return null


func get_all_tiles() -> Array[CropTile]:
	return _tiles


func get_adjacent_crop_count(grid_pos: Vector2i, crop_id: String) -> int:
	var count: int = 0
	var offsets: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(0, 1),
	]
	for offset: Vector2i in offsets:
		var neighbor: CropTile = get_tile_at(grid_pos + offset)
		if neighbor and neighbor.crop_data and neighbor.crop_data.crop_id == crop_id:
			count += 1
	return count
