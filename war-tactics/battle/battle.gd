class_name BattleScene
extends Node2D

enum InputState { IDLE, UNIT_SELECTED }

const TILE_FILL_COLOR: Color = Color(0.35, 0.45, 0.30)
const TILE_BORDER_COLOR: Color = Color(0.15, 0.20, 0.12)
const UNIT_SCENE: PackedScene = preload("res://battle/unit/unit.tscn")
const GRID_SIZE: Vector2i = Vector2i(12, 12)

var _input_state: InputState = InputState.IDLE
var _selected_unit: Unit = null
var _hovered_tile: Vector2i = Vector2i(-1, -1)
var _reachable_cache: Array[Vector2i] = []
var _unit_at_tile: Dictionary = {}

@onready var _tile_layer: Node2D = %TileLayer
@onready var _grid_overlay: GridOverlay = %GridOverlay
@onready var _entity_layer: Node2D = %EntityLayer
@onready var _tile_pick_layer: Node2D = %TilePickLayer


func _ready() -> void:
	Grid.setup(GRID_SIZE)
	_spawn_tiles()
	_spawn_tile_colliders()
	_spawn_unit(Vector2i(5, 5))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _input_state == InputState.UNIT_SELECTED:
				_deselect_unit()


func _spawn_tiles() -> void:
	var base_points: PackedVector2Array = Grid.diamond_points(Vector2.ZERO)
	var border_points: PackedVector2Array = base_points.duplicate()
	border_points.append(base_points[0])

	for y: int in GRID_SIZE.y:
		for x: int in GRID_SIZE.x:
			var coord: Vector2i = Vector2i(x, y)
			var world_pos: Vector2 = Grid.tile_to_world(coord)

			var tile_root: Node2D = Node2D.new()
			tile_root.position = world_pos

			var fill: Polygon2D = Polygon2D.new()
			fill.polygon = base_points
			fill.color = TILE_FILL_COLOR
			tile_root.add_child(fill)

			var border: Line2D = Line2D.new()
			border.points = border_points
			border.width = 1.0
			border.default_color = TILE_BORDER_COLOR
			tile_root.add_child(border)

			_tile_layer.add_child(tile_root)


func _spawn_tile_colliders() -> void:
	var collision_points: PackedVector2Array = Grid.diamond_points(Vector2.ZERO, 0.95)

	for y: int in GRID_SIZE.y:
		for x: int in GRID_SIZE.x:
			var coord: Vector2i = Vector2i(x, y)
			var world_pos: Vector2 = Grid.tile_to_world(coord)

			var area: Area2D = Area2D.new()
			area.position = world_pos
			area.input_pickable = true

			var shape: CollisionPolygon2D = CollisionPolygon2D.new()
			shape.polygon = collision_points
			area.add_child(shape)

			area.mouse_entered.connect(_on_tile_hovered.bind(coord))
			area.mouse_exited.connect(_on_tile_unhovered.bind(coord))
			area.input_event.connect(_on_tile_input.bind(coord))

			_tile_pick_layer.add_child(area)


func _spawn_unit(tile: Vector2i) -> void:
	var unit: Unit = UNIT_SCENE.instantiate() as Unit
	_entity_layer.add_child(unit)
	unit.setup(tile)
	_unit_at_tile[tile] = unit


func _on_tile_hovered(coord: Vector2i) -> void:
	_hovered_tile = coord
	if _input_state == InputState.UNIT_SELECTED and _selected_unit.can_move():
		if _reachable_cache.has(coord):
			var tile_path: Array[Vector2i] = Grid.path(_selected_unit.current_tile, coord)
			var max_steps: int = _selected_unit.action_points + 1
			if tile_path.size() > max_steps:
				tile_path.resize(max_steps)
			_grid_overlay.show_path_preview(tile_path)
		else:
			_grid_overlay.clear_path_preview()


func _on_tile_unhovered(coord: Vector2i) -> void:
	if _hovered_tile == coord:
		_hovered_tile = Vector2i(-1, -1)
		if _input_state == InputState.UNIT_SELECTED:
			_grid_overlay.clear_path_preview()


func _on_tile_input(viewport: Node, event: InputEvent, _shape_idx: int, coord: Vector2i) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_tile_click(coord)


func _handle_tile_click(coord: Vector2i) -> void:
	match _input_state:
		InputState.IDLE:
			if _unit_at_tile.has(coord):
				_select_unit(_unit_at_tile[coord] as Unit)
		InputState.UNIT_SELECTED:
			if _unit_at_tile.has(coord):
				var clicked_unit: Unit = _unit_at_tile[coord] as Unit
				if clicked_unit == _selected_unit:
					_deselect_unit()
				else:
					_deselect_unit()
					_select_unit(clicked_unit)
			elif _reachable_cache.has(coord) and _selected_unit.can_move():
				_execute_move(coord)
			else:
				_deselect_unit()


func _select_unit(unit: Unit) -> void:
	_selected_unit = unit
	_input_state = InputState.UNIT_SELECTED
	_grid_overlay.show_selection(unit.current_tile)
	if unit.can_move():
		_reachable_cache = Grid.reachable_tiles(unit.current_tile, unit.action_points)
		_grid_overlay.show_move_range(_reachable_cache)
	else:
		_reachable_cache.clear()


func _deselect_unit() -> void:
	_selected_unit = null
	_input_state = InputState.IDLE
	_reachable_cache.clear()
	_grid_overlay.clear_all()


func _execute_move(target: Vector2i) -> void:
	var unit: Unit = _selected_unit
	var tile_path: Array[Vector2i] = Grid.path(unit.current_tile, target)
	var max_steps: int = unit.action_points + 1
	if tile_path.size() > max_steps:
		tile_path.resize(max_steps)

	var final_tile: Vector2i = tile_path[tile_path.size() - 1]

	_unit_at_tile.erase(unit.current_tile)
	_unit_at_tile[final_tile] = unit

	_grid_overlay.clear_all()
	_input_state = InputState.IDLE
	_selected_unit = null

	await unit.walk_path(tile_path)

	if unit.can_move():
		_select_unit(unit)
