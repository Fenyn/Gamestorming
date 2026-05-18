class_name GridOverlay
extends Node2D

const MOVE_RANGE_COLOR: Color = Color(0.2, 0.8, 0.2, 0.25)
const PATH_PREVIEW_COLOR: Color = Color(0.2, 0.8, 0.2, 0.5)
const SELECTION_COLOR: Color = Color(1.0, 0.9, 0.2, 0.8)
const ATTACK_RANGE_BOUNDARY_COLOR: Color = Color(0.9, 0.2, 0.2, 0.1)
const ATTACK_TARGET_COLOR: Color = Color(0.9, 0.2, 0.2, 0.4)
const ATTACK_TARGET_HOVER_COLOR: Color = Color(1.0, 0.2, 0.2, 0.7)
const TARGETING_LINE_COLOR: Color = Color(1.0, 0.3, 0.3, 0.6)
const GRENADE_RANGE_COLOR: Color = Color(1.0, 0.6, 0.1, 0.15)
const GRENADE_AOE_COLOR: Color = Color(1.0, 0.6, 0.1, 0.5)
const OVERWATCH_RANGE_COLOR: Color = Color(0.3, 0.5, 1.0, 0.15)
const OVERWATCH_CONE_COLOR: Color = Color(0.3, 0.5, 1.0, 0.35)
const SHIELD_HALF_COLOR: Color = Color(0.3, 0.6, 1.0, 0.8)
const SHIELD_FULL_COLOR: Color = Color(0.2, 0.4, 1.0, 0.9)
const OVERLAY_SCALE: float = 0.9

var _move_range_tiles: Array[Vector2i] = []
var _cover_shields: Array[Dictionary] = [] # [{tile, direction, full}]
var _overwatch_range_tiles: Array[Vector2i] = []
var _overwatch_cone_tiles: Array[Vector2i] = []
var _path_preview_tiles: Array[Vector2i] = []
var _attack_range_boundary: Array[Vector2i] = []
var _attack_target_tiles: Array[Vector2i] = []
var _grenade_range_tiles: Array[Vector2i] = []
var _grenade_aoe_tiles: Array[Vector2i] = []
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


func show_grenade_range(tiles: Array[Vector2i]) -> void:
	_grenade_range_tiles = tiles
	queue_redraw()


func show_grenade_aoe(tiles: Array[Vector2i]) -> void:
	_grenade_aoe_tiles = tiles
	queue_redraw()


func clear_grenade() -> void:
	_grenade_range_tiles.clear()
	_grenade_aoe_tiles.clear()
	queue_redraw()


func show_overwatch_range(tiles: Array[Vector2i]) -> void:
	_overwatch_range_tiles = tiles
	queue_redraw()


func show_overwatch_cone(tiles: Array[Vector2i]) -> void:
	_overwatch_cone_tiles = tiles
	queue_redraw()


func clear_overwatch() -> void:
	_overwatch_range_tiles.clear()
	_overwatch_cone_tiles.clear()
	queue_redraw()


func show_selection(tile: Vector2i) -> void:
	_selection_tile = tile
	queue_redraw()


func show_targeting_line(from_tile: Vector2i, to_tile: Vector2i) -> void:
	_targeting_from = Grid.tile_to_world_elevated(from_tile)
	_targeting_to = Grid.tile_to_world_elevated(to_tile)
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
	_grenade_range_tiles.clear()
	_grenade_aoe_tiles.clear()
	_overwatch_range_tiles.clear()
	_overwatch_cone_tiles.clear()
	_cover_shields.clear()
	_selection_tile = Vector2i(-1, -1)
	_targeting_active = false
	_hovered_target_tile = Vector2i(-1, -1)
	queue_redraw()


func show_cover_shields(shields: Array[Dictionary]) -> void:
	_cover_shields = shields
	queue_redraw()


func clear_cover_shields() -> void:
	_cover_shields.clear()
	queue_redraw()


func clear_path_preview() -> void:
	_path_preview_tiles.clear()
	_cover_shields.clear()
	queue_redraw()


func _draw() -> void:
	for tile: Vector2i in _overwatch_range_tiles:
		draw_colored_polygon(_elevated_diamond(tile), OVERWATCH_RANGE_COLOR)

	for tile: Vector2i in _overwatch_cone_tiles:
		draw_colored_polygon(_elevated_diamond(tile), OVERWATCH_CONE_COLOR)

	for tile: Vector2i in _grenade_range_tiles:
		draw_colored_polygon(_elevated_diamond(tile), GRENADE_RANGE_COLOR)

	for tile: Vector2i in _grenade_aoe_tiles:
		draw_colored_polygon(_elevated_diamond(tile), GRENADE_AOE_COLOR)

	for tile: Vector2i in _attack_range_boundary:
		draw_colored_polygon(_elevated_diamond(tile), ATTACK_RANGE_BOUNDARY_COLOR)

	for tile: Vector2i in _move_range_tiles:
		draw_colored_polygon(_elevated_diamond(tile), MOVE_RANGE_COLOR)

	for tile: Vector2i in _attack_target_tiles:
		var color: Color = ATTACK_TARGET_HOVER_COLOR if tile == _hovered_target_tile else ATTACK_TARGET_COLOR
		draw_colored_polygon(_elevated_diamond(tile), color)

	for tile: Vector2i in _path_preview_tiles:
		draw_colored_polygon(_elevated_diamond(tile), PATH_PREVIEW_COLOR)

	if _selection_tile != Vector2i(-1, -1):
		var points: PackedVector2Array = _elevated_diamond(_selection_tile)
		var outline: PackedVector2Array = points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, SELECTION_COLOR, 2.0)

	for shield: Dictionary in _cover_shields:
		_draw_shield(shield)

	if _targeting_active:
		draw_line(_targeting_from, _targeting_to, TARGETING_LINE_COLOR, 2.0)
		_draw_targeting_reticle(_targeting_to)


func _draw_shield(shield: Dictionary) -> void:
	var tile: Vector2i = shield.get("tile", Vector2i.ZERO) as Vector2i
	var dir: Vector2i = shield.get("direction", Vector2i.ZERO) as Vector2i
	var full: bool = shield.get("full", false) as bool
	var world: Vector2 = Grid.tile_to_world_elevated(tile)
	var hw: float = Grid.TILE_W / 2.0
	var hh: float = Grid.TILE_H / 2.0

	var adj_world: Vector2 = Grid.tile_to_world_elevated(tile + dir)
	var edge_pos: Vector2 = (world + adj_world) * 0.5

	var color: Color = SHIELD_FULL_COLOR if full else SHIELD_HALF_COLOR
	var s: float = 5.0
	# Shield shape: pointed bottom
	var shield_pts: PackedVector2Array = PackedVector2Array([
		edge_pos + Vector2(-s, -s * 1.2),
		edge_pos + Vector2(s, -s * 1.2),
		edge_pos + Vector2(s, 0.0),
		edge_pos + Vector2(0.0, s),
		edge_pos + Vector2(-s, 0.0),
	])
	draw_colored_polygon(shield_pts, color)
	if not full:
		# Half shield: draw a dark bottom half
		var half_pts: PackedVector2Array = PackedVector2Array([
			edge_pos + Vector2(-s, 0.0),
			edge_pos + Vector2(s, 0.0),
			edge_pos + Vector2(0.0, s),
		])
		draw_colored_polygon(half_pts, Color(0.15, 0.25, 0.5, 0.6))


func _elevated_diamond(tile: Vector2i) -> PackedVector2Array:
	var world: Vector2 = Grid.tile_to_world_elevated(tile)
	return Grid.diamond_points(world, OVERLAY_SCALE)


func _draw_targeting_reticle(center: Vector2) -> void:
	var r: float = 12.0
	var color: Color = TARGETING_LINE_COLOR
	draw_arc(center, r, 0.0, TAU, 24, color, 1.5)
	draw_line(center + Vector2(-r - 4, 0), center + Vector2(-r + 4, 0), color, 1.5)
	draw_line(center + Vector2(r - 4, 0), center + Vector2(r + 4, 0), color, 1.5)
	draw_line(center + Vector2(0, -r - 4), center + Vector2(0, -r + 4), color, 1.5)
	draw_line(center + Vector2(0, r - 4), center + Vector2(0, r + 4), color, 1.5)
