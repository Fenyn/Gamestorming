class_name GridOverlay
extends Node2D

const MOVE_RANGE_COLOR: Color = Color(0.2, 0.8, 0.2, 0.25)
const PATH_PREVIEW_COLOR: Color = Color(0.2, 0.8, 0.2, 0.5)
const SELECTION_COLOR: Color = Color(1.0, 0.9, 0.2, 0.8)
const OVERLAY_SCALE: float = 0.9

var _move_range_tiles: Array[Vector2i] = []
var _path_preview_tiles: Array[Vector2i] = []
var _selection_tile: Vector2i = Vector2i(-1, -1)


func show_move_range(tiles: Array[Vector2i]) -> void:
	_move_range_tiles = tiles
	queue_redraw()


func show_path_preview(tiles: Array[Vector2i]) -> void:
	_path_preview_tiles = tiles
	queue_redraw()


func show_selection(tile: Vector2i) -> void:
	_selection_tile = tile
	queue_redraw()


func clear_all() -> void:
	_move_range_tiles.clear()
	_path_preview_tiles.clear()
	_selection_tile = Vector2i(-1, -1)
	queue_redraw()


func clear_path_preview() -> void:
	_path_preview_tiles.clear()
	queue_redraw()


func _draw() -> void:
	for tile: Vector2i in _move_range_tiles:
		var world: Vector2 = Grid.tile_to_world(tile)
		var points: PackedVector2Array = Grid.diamond_points(world, OVERLAY_SCALE)
		draw_colored_polygon(points, MOVE_RANGE_COLOR)

	for tile: Vector2i in _path_preview_tiles:
		var world: Vector2 = Grid.tile_to_world(tile)
		var points: PackedVector2Array = Grid.diamond_points(world, OVERLAY_SCALE)
		draw_colored_polygon(points, PATH_PREVIEW_COLOR)

	if _selection_tile != Vector2i(-1, -1):
		var world: Vector2 = Grid.tile_to_world(_selection_tile)
		var points: PackedVector2Array = Grid.diamond_points(world, OVERLAY_SCALE)
		var outline: PackedVector2Array = points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, SELECTION_COLOR, 2.0)
