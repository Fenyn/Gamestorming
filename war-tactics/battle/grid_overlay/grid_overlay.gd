class_name GridOverlay
extends Node2D

const MOVE_RANGE_COLOR: Color = Color(0.2, 0.8, 0.2, 0.25)
const PATH_PREVIEW_COLOR: Color = Color(0.2, 0.8, 0.2, 0.5)
const SELECTION_COLOR: Color = Color(1.0, 0.9, 0.2, 0.8)
const ATTACK_RANGE_BOUNDARY_COLOR: Color = Color(0.9, 0.2, 0.2, 0.1)
const ATTACK_TARGET_COLOR: Color = Color(0.9, 0.2, 0.2, 0.4)
const ATTACK_TARGET_HOVER_COLOR: Color = Color(1.0, 0.2, 0.2, 0.7)
const TARGETING_LINE_COLOR: Color = Color(1.0, 0.3, 0.3, 0.6)
const OVERLAY_SCALE: float = 0.9

var _move_range_tiles: Array[Vector2i] = []
var _path_preview_tiles: Array[Vector2i] = []
var _attack_range_boundary: Array[Vector2i] = []
var _attack_target_tiles: Array[Vector2i] = []
var _selection_tile: Vector2i = Vector2i(-1, -1)
var _targeting_from: Vector2 = Vector2.ZERO
var _targeting_to: Vector2 = Vector2.ZERO
var _targeting_active: bool = false
var _hovered_target_tile: Vector2i = Vector2i(-1, -1)


func show_move_range(tiles: Array[Vector2i]) -> void:
	_move_range_tiles = tiles
	queue_redraw()


func show_path_preview(tiles: Array[Vector2i]) -> void:
	_path_preview_tiles = tiles
	queue_redraw()


func show_attack_range(boundary: Array[Vector2i], targets: Array[Vector2i]) -> void:
	_attack_range_boundary = boundary
	_attack_target_tiles = targets
	queue_redraw()


func show_selection(tile: Vector2i) -> void:
	_selection_tile = tile
	queue_redraw()


func show_targeting_line(from_tile: Vector2i, to_tile: Vector2i) -> void:
	_targeting_from = Grid.tile_to_world(from_tile)
	_targeting_to = Grid.tile_to_world(to_tile)
	_targeting_active = true
	_hovered_target_tile = to_tile
	queue_redraw()


func clear_targeting_line() -> void:
	_targeting_active = false
	_hovered_target_tile = Vector2i(-1, -1)
	queue_redraw()


func clear_all() -> void:
	_move_range_tiles.clear()
	_path_preview_tiles.clear()
	_attack_range_boundary.clear()
	_attack_target_tiles.clear()
	_selection_tile = Vector2i(-1, -1)
	_targeting_active = false
	_hovered_target_tile = Vector2i(-1, -1)
	queue_redraw()


func clear_path_preview() -> void:
	_path_preview_tiles.clear()
	queue_redraw()


func _draw() -> void:
	for tile: Vector2i in _attack_range_boundary:
		var world: Vector2 = Grid.tile_to_world(tile)
		var points: PackedVector2Array = Grid.diamond_points(world, OVERLAY_SCALE)
		draw_colored_polygon(points, ATTACK_RANGE_BOUNDARY_COLOR)

	for tile: Vector2i in _move_range_tiles:
		var world: Vector2 = Grid.tile_to_world(tile)
		var points: PackedVector2Array = Grid.diamond_points(world, OVERLAY_SCALE)
		draw_colored_polygon(points, MOVE_RANGE_COLOR)

	for tile: Vector2i in _attack_target_tiles:
		var world: Vector2 = Grid.tile_to_world(tile)
		var points: PackedVector2Array = Grid.diamond_points(world, OVERLAY_SCALE)
		var color: Color = ATTACK_TARGET_HOVER_COLOR if tile == _hovered_target_tile else ATTACK_TARGET_COLOR
		draw_colored_polygon(points, color)

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

	if _targeting_active:
		draw_line(_targeting_from, _targeting_to, TARGETING_LINE_COLOR, 2.0)
		_draw_targeting_reticle(_targeting_to)


func _draw_targeting_reticle(center: Vector2) -> void:
	var r: float = 12.0
	var color: Color = TARGETING_LINE_COLOR
	draw_arc(center, r, 0.0, TAU, 24, color, 1.5)
	draw_line(center + Vector2(-r - 4, 0), center + Vector2(-r + 4, 0), color, 1.5)
	draw_line(center + Vector2(r - 4, 0), center + Vector2(r + 4, 0), color, 1.5)
	draw_line(center + Vector2(0, -r - 4), center + Vector2(0, -r + 4), color, 1.5)
	draw_line(center + Vector2(0, r - 4), center + Vector2(0, r + 4), color, 1.5)
