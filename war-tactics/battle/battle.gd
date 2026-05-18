class_name BattleScene
extends Node2D

enum InputState { IDLE, UNIT_SELECTED, GRENADE_TARGETING, OVERWATCH_TARGETING }

const TURN_PLAYER: StringName = &"PlayerTurn"
const TURN_ENEMY: StringName = &"EnemyTurn"
const TURN_WON: StringName = &"Won"
const TURN_LOST: StringName = &"Lost"

const TILE_FILL_COLOR: Color = Color(0.35, 0.45, 0.30)
const TILE_BORDER_COLOR: Color = Color(0.15, 0.20, 0.12)
const TILE_ELEV_HEIGHT: float = 8.0
const TILE_SIDE_COLOR_RIGHT: Color = Color(0.35, 0.25, 0.18)
const TILE_SIDE_COLOR_LEFT: Color = Color(0.28, 0.20, 0.14)
const COVER_FILL_COLOR: Color = Color(0.50, 0.38, 0.26)
const COVER_SIDE_RIGHT: Color = Color(0.42, 0.30, 0.20)
const COVER_SIDE_LEFT: Color = Color(0.35, 0.25, 0.16)
const COVER_HEIGHT: float = 8.0
const RUIN_FILL_COLOR: Color = Color(0.42, 0.40, 0.36)
const RUIN_SIDE_RIGHT: Color = Color(0.35, 0.33, 0.30)
const RUIN_SIDE_LEFT: Color = Color(0.28, 0.26, 0.24)
const RUIN_HEIGHT: float = 18.0
const UNIT_SCENE: PackedScene = preload("res://battle/unit/unit.tscn")
const RESULT_DELAY: float = 1.5
const CAMERA_PAN_SPEED: float = 300.0
const CAMERA_ZOOM_STEP: float = 0.1
const CAMERA_ZOOM_MIN: float = 0.5
const CAMERA_ZOOM_MAX: float = 2.0

var _input_state: InputState = InputState.IDLE
var _action_in_progress: bool = false
var _battle_over: bool = false
var _turn_count: int = 0
var _selected_unit: Unit = null
var _hovered_tile: Vector2i = Vector2i(-1, -1)
var _reachable_cache: Array[Vector2i] = []
var _attack_range_cache: Array[Vector2i] = []
var _unit_at_tile: Dictionary = {}
var _player_units: Array[Unit] = []
var _enemy_units: Array[Unit] = []

@onready var _camera: Camera2D = %Camera2D
@onready var _tile_layer: Node2D = %TileLayer
@onready var _grid_overlay: GridOverlay = %GridOverlay
@onready var _entity_layer: Node2D = %EntityLayer
@onready var _tile_pick_layer: Node2D = %TilePickLayer
@onready var _turn_machine: StateMachine = %TurnMachine
@onready var _hud: BattleHUD = %BattleHUD
@onready var _minigame_layer: MinigameLayer = %MinigameLayer


var _level: LevelData = null


func _ready() -> void:
	_level = LevelData.build_level_01()
	Grid.setup_from_level(_level)
	var center_tile: Vector2i = _level.grid_size / 2
	_camera.position = Grid.tile_to_world(center_tile)
	_spawn_tiles()
	_spawn_tile_colliders()
	_spawn_squad()
	_spawn_enemies()
	_connect_turn_signals()
	_turn_machine.start()


func _process(delta: float) -> void:
	var pan: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if pan != Vector2.ZERO:
		_camera.position += pan.normalized() * CAMERA_PAN_SPEED * delta / _camera.zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_camera.zoom = (_camera.zoom * (1.0 + CAMERA_ZOOM_STEP)).clampf(CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
			return
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_camera.zoom = (_camera.zoom * (1.0 - CAMERA_ZOOM_STEP)).clampf(CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
			return
	if _battle_over:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_SPACE:
				_on_end_turn()
			elif key.keycode == KEY_TAB and _can_accept_input():
				_cycle_to_next_unit()
			elif key.keycode == KEY_G and _can_accept_input():
				if _input_state == InputState.UNIT_SELECTED and _selected_unit and _selected_unit.can_grenade():
					_enter_grenade_targeting()
			elif key.keycode == KEY_Q:
				_rotate_view(-1)
			elif key.keycode == KEY_E:
				_rotate_view(1)
			elif key.keycode == KEY_O and _can_accept_input():
				if _input_state == InputState.UNIT_SELECTED and _selected_unit and _selected_unit.can_attack():
					_enter_overwatch_targeting()
			elif key.keycode == KEY_ESCAPE and _can_accept_input():
				if _input_state == InputState.OVERWATCH_TARGETING:
					_exit_overwatch_targeting()
				elif _input_state == InputState.GRENADE_TARGETING:
					_exit_grenade_targeting()
				elif _input_state == InputState.UNIT_SELECTED:
					_deselect_unit()
	if not _can_accept_input():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _input_state == InputState.OVERWATCH_TARGETING:
				_exit_overwatch_targeting()
			elif _input_state == InputState.GRENADE_TARGETING:
				_exit_grenade_targeting()
			elif _input_state == InputState.UNIT_SELECTED:
				_deselect_unit()


func _can_accept_input() -> bool:
	return not _action_in_progress and not _battle_over and _is_player_turn()


func _is_player_turn() -> bool:
	return _turn_machine.current_state is TurnPlayer


# --- Turn system ---

func _connect_turn_signals() -> void:
	var player_turn: TurnPlayer = _turn_machine.get_node(NodePath(TURN_PLAYER)) as TurnPlayer
	var enemy_turn: TurnEnemy = _turn_machine.get_node(NodePath(TURN_ENEMY)) as TurnEnemy
	var won: TurnWon = _turn_machine.get_node(NodePath(TURN_WON)) as TurnWon
	var lost: TurnLost = _turn_machine.get_node(NodePath(TURN_LOST)) as TurnLost

	player_turn.player_turn_started.connect(_on_player_turn_started)
	enemy_turn.enemy_turn_started.connect(_on_enemy_turn_started)
	enemy_turn.enemy_turn_finished.connect(_on_enemy_turn_finished)
	won.battle_won.connect(_on_battle_won)
	lost.battle_lost.connect(_on_battle_lost)

	_hud.end_turn_pressed.connect(_on_end_turn)


func _on_player_turn_started() -> void:
	_turn_count += 1
	for unit: Unit in _player_units:
		if unit.is_alive():
			unit.clear_overwatch()
			unit.refresh_ap()
	_update_exhausted_visuals()
	_hud.set_player_turn()
	_hud.set_turn_count(_turn_count)
	_update_end_turn_count()


func _on_enemy_turn_started() -> void:
	_deselect_unit()
	_hud.set_enemy_turn()


func _on_enemy_turn_finished() -> void:
	_turn_machine.transition_to(TURN_PLAYER)


func _on_end_turn() -> void:
	if not _is_player_turn() or _action_in_progress:
		return
	_deselect_unit()
	_turn_machine.transition_to(TURN_ENEMY, {"battle": self})


func _on_battle_won() -> void:
	_battle_over = true
	_deselect_unit()
	_hud.show_result("Victory!")
	Events.battle_won.emit()
	var timer: SceneTreeTimer = get_tree().create_timer(RESULT_DELAY)
	await timer.timeout
	Events.screen_transition_requested.emit("title")


func _on_battle_lost() -> void:
	_battle_over = true
	_deselect_unit()
	_hud.show_result("Defeat...")
	Events.battle_lost.emit()
	var timer: SceneTreeTimer = get_tree().create_timer(RESULT_DELAY)
	await timer.timeout
	Events.screen_transition_requested.emit("title")


# --- Tile rendering ---

func _spawn_tiles() -> void:
	var grid_size: Vector2i = _level.grid_size
	var hw: float = Grid.TILE_W / 2.0
	var hh: float = Grid.TILE_H / 2.0

	var sorted_coords: Array[Vector2i] = []
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			sorted_coords.append(Vector2i(x, y))
	sorted_coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Grid.tile_to_world(a).y < Grid.tile_to_world(b).y
	)

	for coord: Vector2i in sorted_coords:
			var world_pos: Vector2 = Grid.tile_to_world(coord)
			var elev: int = Grid.get_elevation(coord)
			var lift: float = elev * TILE_ELEV_HEIGHT

			var tile_root: Node2D = Node2D.new()
			tile_root.position = world_pos

			if elev > 0:
				_add_block_sides(tile_root, hw, hh, 0.0, lift, TILE_SIDE_COLOR_RIGHT, TILE_SIDE_COLOR_LEFT)

			var is_cover: bool = Grid.is_cover_tile(coord)
			var is_crag: bool = Grid.is_solid_obstacle(coord)
			var extra_height: float = 0.0
			var extra_fill: Color = TILE_FILL_COLOR
			var extra_sr: Color = TILE_SIDE_COLOR_RIGHT
			var extra_sl: Color = TILE_SIDE_COLOR_LEFT

			if is_crag:
				extra_height = RUIN_HEIGHT
				extra_fill = RUIN_FILL_COLOR
				extra_sr = RUIN_SIDE_RIGHT
				extra_sl = RUIN_SIDE_LEFT
			elif is_cover:
				extra_height = COVER_HEIGHT
				extra_fill = COVER_FILL_COLOR
				extra_sr = COVER_SIDE_RIGHT
				extra_sl = COVER_SIDE_LEFT

			var total_lift: float = lift + extra_height

			if extra_height > 0.0:
				_add_block_sides(tile_root, hw, hh, lift, total_lift, extra_sr, extra_sl)

			var top_points: PackedVector2Array = PackedVector2Array([
				Vector2(0.0, -hh - total_lift),
				Vector2(hw, -total_lift),
				Vector2(0.0, hh - total_lift),
				Vector2(-hw, -total_lift),
			])
			var fill: Polygon2D = Polygon2D.new()
			fill.polygon = top_points
			if is_crag:
				fill.color = RUIN_FILL_COLOR
			elif is_cover:
				fill.color = COVER_FILL_COLOR
			else:
				var tint: float = elev * 0.06
				fill.color = TILE_FILL_COLOR + Color(tint, tint, tint, 0.0)
			tile_root.add_child(fill)

			if is_cover:
				if (coord.x + coord.y) % 2 == 0:
					_add_boulder(tile_root, total_lift)
					_add_tile_label(tile_root, "Rock", -total_lift - 14.0)
				else:
					_add_tree(tile_root, total_lift)
					_add_tile_label(tile_root, "Tree", -total_lift - 30.0)
			elif is_crag:
				_add_ruin_detail(tile_root, total_lift)
				_add_tile_label(tile_root, "Ruins", -total_lift - 12.0)

			var border_points: PackedVector2Array = top_points.duplicate()
			border_points.append(top_points[0])
			var border: Line2D = Line2D.new()
			border.points = border_points
			border.width = 1.0
			border.default_color = TILE_BORDER_COLOR
			tile_root.add_child(border)

			_tile_layer.add_child(tile_root)


func _add_block_sides(parent: Node2D, hw: float, hh: float, base_lift: float, top_lift: float, right_color: Color, left_color: Color) -> void:
	var top_r: Vector2 = Vector2(hw, -top_lift)
	var top_b: Vector2 = Vector2(0.0, hh - top_lift)
	var top_l: Vector2 = Vector2(-hw, -top_lift)
	var top_t: Vector2 = Vector2(0.0, -hh - top_lift)
	var bot_r: Vector2 = Vector2(hw, -base_lift)
	var bot_b: Vector2 = Vector2(0.0, hh - base_lift)
	var bot_l: Vector2 = Vector2(-hw, -base_lift)
	var bot_t: Vector2 = Vector2(0.0, -hh - base_lift)

	var se: Polygon2D = Polygon2D.new()
	se.polygon = PackedVector2Array([top_r, top_b, bot_b, bot_r])
	se.color = right_color
	var sw: Polygon2D = Polygon2D.new()
	sw.polygon = PackedVector2Array([top_l, top_b, bot_b, bot_l])
	sw.color = left_color
	var ne: Polygon2D = Polygon2D.new()
	ne.polygon = PackedVector2Array([top_t, top_r, bot_r, bot_t])
	ne.color = left_color
	var nw: Polygon2D = Polygon2D.new()
	nw.polygon = PackedVector2Array([top_t, top_l, bot_l, bot_t])
	nw.color = right_color

	parent.add_child(nw); parent.add_child(ne)
	parent.add_child(sw); parent.add_child(se)


func _add_tile_label(parent: Node2D, text: String, y_offset: float) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.offset_left = -20
	label.offset_right = 20
	label.offset_top = y_offset - 10
	label.offset_bottom = y_offset
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(1.0, 1.0, 1.0, 0.6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


func _add_boulder(parent: Node2D, lift: float) -> void:
	var cy: float = -lift - 1.0
	var hw: float = Grid.TILE_W / 2.0 * 0.55
	var hh: float = Grid.TILE_H / 2.0 * 0.55
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 12:
		var a: float = float(i) / 12.0 * TAU
		pts.append(Vector2(cos(a) * hw, sin(a) * hh + cy))
	var circle: Polygon2D = Polygon2D.new()
	circle.polygon = pts
	circle.color = Color(0.55, 0.48, 0.38)
	parent.add_child(circle)
	var inner: PackedVector2Array = PackedVector2Array()
	for i: int in 12:
		var a: float = float(i) / 12.0 * TAU
		inner.append(Vector2(cos(a) * hw * 0.55, sin(a) * hh * 0.55 + cy - 1.5))
	var highlight: Polygon2D = Polygon2D.new()
	highlight.polygon = inner
	highlight.color = Color(0.65, 0.58, 0.48)
	parent.add_child(highlight)


func _add_tree(parent: Node2D, lift: float) -> void:
	var by: float = -lift
	# Trunk
	var trunk: Polygon2D = Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(-2.0, by), Vector2(-2.0, by - 12.0),
		Vector2(2.0, by - 12.0), Vector2(2.0, by),
	])
	trunk.color = Color(0.35, 0.22, 0.12)
	parent.add_child(trunk)
	# Canopy — bottom layer (dark)
	var canopy_b: Polygon2D = Polygon2D.new()
	var cb_pts: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var a: float = float(i) / 10.0 * TAU
		cb_pts.append(Vector2(cos(a) * 14.0, sin(a) * 8.0 + by - 14.0))
	canopy_b.polygon = cb_pts
	canopy_b.color = Color(0.18, 0.35, 0.15)
	parent.add_child(canopy_b)
	# Canopy — top layer (bright)
	var canopy_t: Polygon2D = Polygon2D.new()
	var ct_pts: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var a: float = float(i) / 10.0 * TAU
		ct_pts.append(Vector2(cos(a) * 10.0, sin(a) * 6.0 + by - 18.0))
	canopy_t.polygon = ct_pts
	canopy_t.color = Color(0.28, 0.50, 0.22)
	parent.add_child(canopy_t)
	# Highlight
	var highlight: Polygon2D = Polygon2D.new()
	var h_pts: PackedVector2Array = PackedVector2Array()
	for i: int in 8:
		var a: float = float(i) / 8.0 * TAU
		h_pts.append(Vector2(cos(a) * 5.0 - 1.0, sin(a) * 3.0 + by - 20.0))
	highlight.polygon = h_pts
	highlight.color = Color(0.35, 0.58, 0.28)
	parent.add_child(highlight)


func _add_ruin_detail(parent: Node2D, lift: float) -> void:
	var cy: float = -lift
	# Window opening on the right-facing wall
	var window: Polygon2D = Polygon2D.new()
	window.polygon = PackedVector2Array([
		Vector2(6.0, cy + 6.0), Vector2(12.0, cy + 3.0),
		Vector2(12.0, cy + 9.0), Vector2(6.0, cy + 12.0),
	])
	window.color = Color(0.18, 0.17, 0.15)
	parent.add_child(window)
	# Window sill
	var sill: Line2D = Line2D.new()
	sill.points = PackedVector2Array([Vector2(5.0, cy + 12.5), Vector2(13.0, cy + 9.5)])
	sill.width = 1.5
	sill.default_color = Color(0.50, 0.47, 0.42)
	parent.add_child(sill)
	# Broken top edge
	var edge: Line2D = Line2D.new()
	edge.points = PackedVector2Array([
		Vector2(-10.0, cy - 1.0), Vector2(-6.0, cy - 3.0),
		Vector2(-2.0, cy - 1.5), Vector2(4.0, cy - 3.5),
		Vector2(8.0, cy - 2.0),
	])
	edge.width = 1.5
	edge.default_color = Color(0.50, 0.47, 0.42)
	parent.add_child(edge)


func _spawn_tile_colliders() -> void:
	var grid_size: Vector2i = _level.grid_size
	var hw: float = Grid.TILE_W / 2.0 * 0.95
	var hh: float = Grid.TILE_H / 2.0 * 0.95

	for y: int in grid_size.y:
		for x: int in grid_size.x:
			var coord: Vector2i = Vector2i(x, y)
			var world_pos: Vector2 = Grid.tile_to_world(coord)
			var lift: float = Grid.get_elevation(coord) * TILE_ELEV_HEIGHT
			var collision_points: PackedVector2Array = PackedVector2Array([
				Vector2(0.0, -hh - lift),
				Vector2(hw, -lift),
				Vector2(0.0, hh - lift),
				Vector2(-hw, -lift),
			])

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


# --- Unit spawning ---

func _spawn_squad() -> void:
	for i: int in RunState.squad_ids.size():
		if i >= _level.player_spawns.size():
			break
		var data: UnitData = Database.get_unit_data(RunState.squad_ids[i])
		if data:
			var unit: Unit = _spawn_unit(_level.player_spawns[i], data)
			if unit:
				_player_units.append(unit)


func _spawn_enemies() -> void:
	for i: int in _level.enemy_spawns.size():
		var enemy_id: String = _level.enemy_ids[i] if i < _level.enemy_ids.size() else "enemy_rifleman"
		var data: UnitData = Database.get_unit_data(enemy_id)
		if data == null:
			continue
		var unit: Unit = _spawn_unit(_level.enemy_spawns[i], data)
		if unit:
			_enemy_units.append(unit)


func _find_nearest_walkable(tile: Vector2i) -> Vector2i:
	if Grid.get_tile_info(tile)["is_walkable"] as bool and not _unit_at_tile.has(tile):
		return tile
	for radius: int in range(1, 6):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var candidate: Vector2i = tile + Vector2i(dx, dy)
				if Grid.is_in_bounds(candidate) and Grid.get_tile_info(candidate)["is_walkable"] as bool and not _unit_at_tile.has(candidate):
					return candidate
	push_error("BattleScene: no walkable tile near %s" % str(tile))
	return tile


func _spawn_unit(tile: Vector2i, data: UnitData) -> Unit:
	tile = _find_nearest_walkable(tile)
	var unit: Unit = UNIT_SCENE.instantiate() as Unit
	_entity_layer.add_child(unit)
	unit.setup(tile, data)
	unit.unit_died.connect(_on_unit_died)
	if data.is_enemy:
		var brain: AIBrain = AIBrain.new()
		brain.name = "AIBrain"
		unit.add_child(brain)
	_register_unit(unit, tile)
	return unit


# --- Unit tile tracking ---

func _register_unit(unit: Unit, tile: Vector2i) -> void:
	_unit_at_tile[tile] = unit
	Grid.set_tile_solid(tile, true)


func _unregister_unit(unit: Unit) -> void:
	_unit_at_tile.erase(unit.current_tile)
	Grid.set_tile_solid(unit.current_tile, false)


func _on_unit_died(unit: Unit) -> void:
	_unregister_unit(unit)
	if _selected_unit == unit:
		_deselect_unit()
	_check_battle_end()


func _check_battle_end() -> void:
	if _battle_over:
		return
	var enemies_alive: bool = _enemy_units.any(func(u: Unit) -> bool: return u.is_alive())
	if not enemies_alive:
		_turn_machine.transition_to(TURN_WON)
		return
	var players_alive: bool = _player_units.any(func(u: Unit) -> bool: return u.is_alive())
	if not players_alive:
		_turn_machine.transition_to(TURN_LOST)


# --- Pathfinding helpers ---

func _compute_reachable(unit: Unit) -> Array[Vector2i]:
	Grid.set_tile_solid(unit.current_tile, false)
	var result: Array[Vector2i] = Grid.reachable_tiles(unit.current_tile, unit.action_points)
	Grid.set_tile_solid(unit.current_tile, true)
	return result


func _compute_path(unit: Unit, target: Vector2i) -> Array[Vector2i]:
	Grid.set_tile_solid(unit.current_tile, false)
	var result: Array[Vector2i] = Grid.path(unit.current_tile, target)
	Grid.set_tile_solid(unit.current_tile, true)
	return result


# --- Input handling ---

func _on_tile_hovered(coord: Vector2i) -> void:
	if not _can_accept_input():
		return
	_hovered_tile = coord
	_update_hover_info(coord)
	if _input_state == InputState.GRENADE_TARGETING:
		_show_grenade_aoe_hover(coord)
		return
	if _input_state == InputState.OVERWATCH_TARGETING:
		_show_overwatch_cone_hover(coord)
		return
	if _input_state != InputState.UNIT_SELECTED:
		return
	if _try_show_attack_hover(coord):
		return
	_grid_overlay.clear_targeting_line()
	_hud.hide_attack_preview()
	_show_move_hover(coord)


func _update_hover_info(coord: Vector2i) -> void:
	if _unit_at_tile.has(coord):
		var hovered_unit: Unit = _unit_at_tile[coord] as Unit
		if hovered_unit.is_alive() and hovered_unit != _selected_unit:
			_hud.show_hover_info(hovered_unit.unit_data.unit_label, hovered_unit.health.current_hp, hovered_unit.health.max_hp)
			return
	_hud.hide_hover_info()


func _try_show_attack_hover(coord: Vector2i) -> bool:
	if not _attack_range_cache.has(coord) or not _unit_at_tile.has(coord):
		return false
	var target: Unit = _unit_at_tile[coord] as Unit
	if not target.is_enemy or not target.is_alive() or not _selected_unit.can_attack():
		return false
	var weapon: WeaponData = _selected_unit.attacker.weapon
	var ctx: Dictionary = Grid.get_combat_context(_selected_unit.current_tile, target.current_tile)
	var elev_diff: int = ctx["elev_diff"] as int
	var in_cover: bool = ctx["in_cover"] as bool
	var computed_dmg: int = CombatCalc.compute_damage(weapon.damage, elev_diff, in_cover)
	var modifier_text: String = CombatCalc.get_modifier_text(elev_diff, in_cover)
	_grid_overlay.show_targeting_line(_selected_unit.current_tile, coord)
	_hud.show_attack_preview(
		weapon.weapon_name, computed_dmg,
		target.health.current_hp, target.health.max_hp,
		weapon.ap_cost, modifier_text,
	)
	_grid_overlay.clear_path_preview()
	_hud.hide_move_preview()
	return true


func _show_move_hover(coord: Vector2i) -> void:
	if _reachable_cache.has(coord) and _selected_unit.can_move():
		var tile_path: Array[Vector2i] = _compute_path(_selected_unit, coord)
		var max_steps: int = _selected_unit.action_points + 1
		if tile_path.size() > max_steps:
			tile_path.resize(max_steps)
		if tile_path.size() < 2:
			return
		_grid_overlay.show_path_preview(tile_path)
		var dest: Vector2i = tile_path[tile_path.size() - 1]
		var move_cost: int = (tile_path.size() - 1) * _selected_unit.unit_data.move_cost
		var ap_after_move: int = _selected_unit.action_points - move_cost
		var targets_from_dest: int = _count_targets_from_tile(dest, ap_after_move)
		_hud.show_move_preview(move_cost, targets_from_dest)
		_update_target_pips_from_tile(dest, ap_after_move)
		var shields: Array[Dictionary] = Grid.get_cover_at(dest)
		var shield_data: Array[Dictionary] = []
		for s: Dictionary in shields:
			shield_data.append({"tile": dest, "direction": s["direction"], "full": s["full"]})
		_grid_overlay.show_cover_shields(shield_data)
	else:
		_grid_overlay.clear_path_preview()
		_hud.hide_move_preview()
		_update_target_pips(_attack_range_cache)


func _on_tile_unhovered(coord: Vector2i) -> void:
	if _hovered_tile == coord:
		_hovered_tile = Vector2i(-1, -1)
		_hud.hide_hover_info()
		if _input_state == InputState.UNIT_SELECTED:
			_grid_overlay.clear_path_preview()
			_grid_overlay.clear_targeting_line()
			_hud.hide_attack_preview()
			_hud.hide_move_preview()
			_update_target_pips(_attack_range_cache)


func _count_targets_from_tile(tile: Vector2i, _remaining_ap: int) -> int:
	if _selected_unit == null or _selected_unit.attacker.weapon == null:
		return 0
	var weapon_range: int = _selected_unit.attacker.get_range()
	var count: int = 0
	for enemy: Unit in _enemy_units:
		if not enemy.is_alive():
			continue
		var dx: int = absi(enemy.current_tile.x - tile.x)
		var dy: int = absi(enemy.current_tile.y - tile.y)
		if maxi(dx, dy) <= weapon_range and Grid.has_line_of_sight(tile, enemy.current_tile):
			count += 1
	return count


func _on_tile_input(viewport: Node, event: InputEvent, _shape_idx: int, coord: Vector2i) -> void:
	if not _can_accept_input():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_tile_click(coord)


func _handle_tile_click(coord: Vector2i) -> void:
	match _input_state:
		InputState.IDLE:
			if _unit_at_tile.has(coord):
				var clicked_unit: Unit = _unit_at_tile[coord] as Unit
				if not clicked_unit.is_enemy and clicked_unit.is_alive():
					_select_unit(clicked_unit)
		InputState.UNIT_SELECTED:
			if _unit_at_tile.has(coord):
				var clicked_unit: Unit = _unit_at_tile[coord] as Unit
				if clicked_unit == _selected_unit:
					_deselect_unit()
				elif clicked_unit.is_enemy and clicked_unit.is_alive():
					if _attack_range_cache.has(coord) and _selected_unit.can_attack():
						_execute_attack(clicked_unit)
				elif not clicked_unit.is_enemy and clicked_unit.is_alive():
					_deselect_unit()
					_select_unit(clicked_unit)
			elif _reachable_cache.has(coord) and _selected_unit.can_move():
				_execute_move(coord)
			else:
				_deselect_unit()
		InputState.GRENADE_TARGETING:
			_handle_grenade_click(coord)
		InputState.OVERWATCH_TARGETING:
			_handle_overwatch_click(coord)


# --- Selection ---

func _select_unit(unit: Unit) -> void:
	if not unit.is_alive():
		return
	_selected_unit = unit
	_input_state = InputState.UNIT_SELECTED
	_grid_overlay.show_selection(unit.current_tile)
	if unit.can_move():
		_reachable_cache = _compute_reachable(unit)
		_grid_overlay.show_move_range(_reachable_cache)
	else:
		_reachable_cache.clear()
	_attack_range_cache.clear()
	if unit.attacker.weapon != null:
		var all_in_range: Array[Vector2i] = Grid.tiles_in_range(unit.current_tile, unit.attacker.get_range())
		for tile: Vector2i in all_in_range:
			if _unit_at_tile.has(tile):
				var target: Unit = _unit_at_tile[tile] as Unit
				if target.is_enemy and target.is_alive() and Grid.has_line_of_sight(unit.current_tile, tile):
					_attack_range_cache.append(tile)
		_grid_overlay.show_attack_range(all_in_range, _attack_range_cache)
		_update_target_pips(_attack_range_cache)
	else:
		_clear_target_pips()
	var weapon_name: String = unit.attacker.weapon.weapon_name if unit.attacker.weapon else ""
	var weapon_range: int = unit.attacker.get_range()
	_hud.show_unit_stats(
		unit.unit_data.unit_label, unit.health.current_hp, unit.health.max_hp,
		unit.action_points, unit.unit_data.max_ap,
		weapon_name, weapon_range,
	)


func _deselect_unit() -> void:
	_selected_unit = null
	_input_state = InputState.IDLE
	_reachable_cache.clear()
	_attack_range_cache.clear()
	_grid_overlay.clear_all()
	_clear_target_pips()
	_hud.hide_unit_stats()
	_hud.hide_attack_preview()
	_hud.hide_move_preview()
	_hud.hide_hover_info()


# --- Actions ---

func _execute_move(target: Vector2i) -> void:
	var unit: Unit = _selected_unit
	var tile_path: Array[Vector2i] = _compute_path(unit, target)
	var max_steps: int = unit.action_points + 1
	if tile_path.size() > max_steps:
		tile_path.resize(max_steps)
	if tile_path.size() < 2:
		return

	_grid_overlay.clear_all()
	_input_state = InputState.IDLE
	_selected_unit = null
	_action_in_progress = true

	var step_callback: Callable = _on_unit_tile_stepped.bind(unit)
	unit.mover.tile_stepped.connect(step_callback)
	unit.state_machine.transition_to(Unit.STATE_MOVING, {
		"tile_path": tile_path,
		"move_cost": unit.unit_data.move_cost,
	})
	await unit.mover.walk_finished
	unit.mover.tile_stepped.disconnect(step_callback)

	_action_in_progress = false
	_update_exhausted_visuals()
	_update_end_turn_count()
	if unit.is_alive() and (unit.can_move() or unit.can_attack()):
		_select_unit(unit)


func _execute_attack(target: Unit) -> void:
	var unit: Unit = _selected_unit
	_grid_overlay.clear_all()
	_input_state = InputState.IDLE
	_selected_unit = null
	_action_in_progress = true

	var ctx: Dictionary = Grid.get_combat_context(unit.current_tile, target.current_tile)

	unit.attack_resolved.connect(_on_attack_resolved.bind(unit), CONNECT_ONE_SHOT)
	unit.state_machine.transition_to(Unit.STATE_ATTACKING, {
		"target": target,
		"weapon": unit.attacker.weapon,
		"minigame_layer": _minigame_layer,
		"elev_diff": ctx["elev_diff"] as int,
		"in_cover": ctx["in_cover"] as bool,
	})


func _on_attack_resolved(target: Unit, hit: bool, damage_dealt: int, attacker_unit: Unit) -> void:
	_spawn_floating_text(target, hit, damage_dealt)
	if hit and target.is_alive():
		_flash_unit(target)

	_action_in_progress = false
	_update_exhausted_visuals()
	_update_end_turn_count()
	if attacker_unit.is_alive() and not _battle_over:
		if attacker_unit.can_move() or attacker_unit.can_attack():
			_select_unit(attacker_unit)


func _spawn_floating_text(target: Unit, hit: bool, damage_dealt: int) -> void:
	var label: FloatingText = FloatingText.new()
	if hit and damage_dealt > 0:
		label.text = str(damage_dealt)
		label.modulate = Color.YELLOW
	elif hit:
		label.text = "HIT"
		label.modulate = Color.YELLOW
	else:
		label.text = "MISS"
		label.modulate = Color.GRAY
	label.position = target.position + Vector2(-16, -50)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entity_layer.add_child(label)


func _flash_unit(unit: Unit) -> void:
	var original: Color = unit.modulate
	unit.modulate = Color.WHITE
	var tween: Tween = create_tween()
	tween.tween_property(unit, "modulate", original, 0.1)


func _update_target_pips(target_tiles: Array[Vector2i]) -> void:
	_clear_target_pips()
	var actionable: bool = _selected_unit != null and _selected_unit.can_attack()
	for tile: Vector2i in target_tiles:
		if _unit_at_tile.has(tile):
			var target: Unit = _unit_at_tile[tile] as Unit
			if target.is_enemy and target.is_alive():
				target.show_target_pip(true, actionable)


func _update_target_pips_from_tile(tile: Vector2i, ap_remaining: int) -> void:
	if _selected_unit == null or _selected_unit.attacker.weapon == null:
		_clear_target_pips()
		return
	_clear_target_pips()
	var weapon_range: int = _selected_unit.attacker.get_range()
	var can_afford: bool = ap_remaining >= _selected_unit.attacker.weapon.ap_cost
	for enemy: Unit in _enemy_units:
		if not enemy.is_alive():
			continue
		var dx: int = absi(enemy.current_tile.x - tile.x)
		var dy: int = absi(enemy.current_tile.y - tile.y)
		if maxi(dx, dy) <= weapon_range and Grid.has_line_of_sight(tile, enemy.current_tile):
			enemy.show_target_pip(true, can_afford)


func _clear_target_pips() -> void:
	for enemy: Unit in _enemy_units:
		enemy.show_target_pip(false)


# --- Grenade ---

const GRENADE_MIN_RANGE: int = 2

func _enter_grenade_targeting() -> void:
	_input_state = InputState.GRENADE_TARGETING
	_grid_overlay.clear_all()
	var throw_range: int = _selected_unit.attacker.get_secondary_range()
	var range_tiles: Array[Vector2i] = Grid.tiles_in_range(_selected_unit.current_tile, throw_range)
	var valid_tiles: Array[Vector2i] = []
	for tile: Vector2i in range_tiles:
		var dist: int = maxi(absi(tile.x - _selected_unit.current_tile.x), absi(tile.y - _selected_unit.current_tile.y))
		if dist >= GRENADE_MIN_RANGE and Grid.has_line_of_sight(_selected_unit.current_tile, tile):
			valid_tiles.append(tile)
	_grid_overlay.show_grenade_range(valid_tiles)
	_grid_overlay.show_selection(_selected_unit.current_tile)


func _exit_grenade_targeting() -> void:
	_grid_overlay.clear_grenade()
	_select_unit(_selected_unit)


func _show_grenade_aoe_hover(coord: Vector2i) -> void:
	if _selected_unit == null:
		return
	var throw_range: int = _selected_unit.attacker.get_secondary_range()
	var dist: int = maxi(absi(coord.x - _selected_unit.current_tile.x), absi(coord.y - _selected_unit.current_tile.y))
	if dist <= throw_range and dist >= GRENADE_MIN_RANGE and Grid.has_line_of_sight(_selected_unit.current_tile, coord):
		var aoe: Array[Vector2i] = Grid.tiles_in_diamond_aoe(coord, _selected_unit.attacker.secondary_weapon.aoe_radius)
		_grid_overlay.show_grenade_aoe(aoe)
	else:
		_grid_overlay.show_grenade_aoe([])


func _handle_grenade_click(coord: Vector2i) -> void:
	if _selected_unit == null:
		return
	var throw_range: int = _selected_unit.attacker.get_secondary_range()
	var dist: int = maxi(absi(coord.x - _selected_unit.current_tile.x), absi(coord.y - _selected_unit.current_tile.y))
	if dist > throw_range or dist < GRENADE_MIN_RANGE:
		return
	if not Grid.has_line_of_sight(_selected_unit.current_tile, coord):
		return
	_execute_grenade(coord)


func _execute_grenade(target_tile: Vector2i) -> void:
	var unit: Unit = _selected_unit
	var weapon: WeaponData = unit.attacker.secondary_weapon
	_grid_overlay.clear_all()
	_input_state = InputState.IDLE
	_selected_unit = null
	_action_in_progress = true

	var grenading_state: UnitGrenading = unit.state_machine.get_node(NodePath(Unit.STATE_GRENADING)) as UnitGrenading
	grenading_state.grenade_resolved.connect(_on_grenade_resolved.bind(unit), CONNECT_ONE_SHOT)
	unit.state_machine.transition_to(Unit.STATE_GRENADING, {
		"target_tile": target_tile,
		"weapon": weapon,
	})


func _on_grenade_resolved(aoe_tiles: Array[Vector2i], damage: int, thrower: Unit) -> void:
	var dead_units: Array[Unit] = []
	for tile: Vector2i in aoe_tiles:
		if _unit_at_tile.has(tile):
			var target: Unit = _unit_at_tile[tile] as Unit
			if target.is_alive():
				target.health.take_damage(damage)
				var dmg_label: FloatingText = FloatingText.new()
				dmg_label.text = str(damage)
				dmg_label.modulate = Color.ORANGE
				dmg_label.position = target.position + Vector2(-16, -50)
				dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_entity_layer.add_child(dmg_label)
				_flash_unit(target)
				if not target.is_alive():
					dead_units.append(target)
	for dead: Unit in dead_units:
		_unregister_unit(dead)
	if not dead_units.is_empty():
		_check_battle_end()

	_action_in_progress = false
	_update_exhausted_visuals()
	_update_end_turn_count()
	_clear_target_pips()
	if thrower.is_alive() and not _battle_over:
		if thrower.can_move() or thrower.can_attack() or thrower.can_grenade():
			_select_unit(thrower)


# --- Overwatch ---

func _enter_overwatch_targeting() -> void:
	_input_state = InputState.OVERWATCH_TARGETING
	_grid_overlay.clear_all()
	var weapon_range: int = _selected_unit.attacker.get_range()
	var range_tiles: Array[Vector2i] = Grid.tiles_in_range(_selected_unit.current_tile, weapon_range)
	_grid_overlay.show_overwatch_range(range_tiles)
	_grid_overlay.show_selection(_selected_unit.current_tile)


func _exit_overwatch_targeting() -> void:
	_grid_overlay.clear_overwatch()
	_select_unit(_selected_unit)


func _show_overwatch_cone_hover(coord: Vector2i) -> void:
	if _selected_unit == null:
		return
	var weapon_range: int = _selected_unit.attacker.get_range()
	var dx: int = absi(coord.x - _selected_unit.current_tile.x)
	var dy: int = absi(coord.y - _selected_unit.current_tile.y)
	if maxi(dx, dy) <= weapon_range and coord != _selected_unit.current_tile:
		var cone: Array[Vector2i] = Grid.tiles_in_cone(_selected_unit.current_tile, coord, weapon_range)
		_grid_overlay.show_overwatch_cone(cone)
	else:
		_grid_overlay.show_overwatch_cone([])


func _handle_overwatch_click(coord: Vector2i) -> void:
	if _selected_unit == null:
		return
	var weapon_range: int = _selected_unit.attacker.get_range()
	if maxi(absi(coord.x - _selected_unit.current_tile.x), absi(coord.y - _selected_unit.current_tile.y)) > weapon_range:
		return
	if coord == _selected_unit.current_tile:
		return
	var cone: Array[Vector2i] = Grid.tiles_in_cone(_selected_unit.current_tile, coord, weapon_range)
	if cone.is_empty():
		return
	_execute_overwatch(cone)


func _execute_overwatch(cone_tiles: Array[Vector2i]) -> void:
	var unit: Unit = _selected_unit
	_grid_overlay.clear_all()
	_input_state = InputState.IDLE
	_selected_unit = null

	unit.state_machine.transition_to(Unit.STATE_OVERWATCH, {
		"cone_tiles": cone_tiles,
		"ap_cost": unit.attacker.weapon.ap_cost,
	})
	_update_exhausted_visuals()
	_update_end_turn_count()


func get_overwatching_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for unit: Unit in _player_units:
		if unit.is_alive() and unit.is_overwatching():
			result.append(unit)
	return result


func execute_overwatch_fire(watcher: Unit, target: Unit) -> void:
	var ow_state: UnitOverwatch = watcher.state_machine.get_node(NodePath(Unit.STATE_OVERWATCH)) as UnitOverwatch
	if ow_state == null or not ow_state.is_watching():
		return
	var result: Dictionary = ow_state.fire_at(target)
	var hit: bool = result.get("hit", false) as bool
	var damage: int = result.get("damage", 0) as int
	_spawn_floating_text(target, hit, damage)
	if hit and target.is_alive():
		_flash_unit(target)


# --- AI execution ---

func get_living_enemies() -> Array[Unit]:
	var result: Array[Unit] = []
	for unit: Unit in _enemy_units:
		if unit.is_alive():
			result.append(unit)
	return result


func get_living_players() -> Array[Unit]:
	var result: Array[Unit] = []
	for unit: Unit in _player_units:
		if unit.is_alive():
			result.append(unit)
	return result


func get_unit_at_tile() -> Dictionary:
	return _unit_at_tile


var _overwatch_pending_watcher: Unit = null
var _overwatch_pending_target: Unit = null


func execute_ai_move(unit: Unit, target_tile: Vector2i) -> void:
	Grid.set_tile_solid(unit.current_tile, false)
	var tile_path: Array[Vector2i] = Grid.path(unit.current_tile, target_tile)
	Grid.set_tile_solid(unit.current_tile, true)
	if tile_path.size() < 2:
		return
	var max_steps: int = unit.action_points + 1
	if tile_path.size() > max_steps:
		tile_path.resize(max_steps)

	_overwatch_pending_watcher = null
	_overwatch_pending_target = null
	var step_callback: Callable = _on_ai_tile_stepped.bind(unit)
	unit.mover.tile_stepped.connect(step_callback)
	unit.state_machine.transition_to(Unit.STATE_MOVING, {
		"tile_path": tile_path,
		"move_cost": unit.unit_data.move_cost,
	})
	await unit.mover.walk_finished
	unit.mover.tile_stepped.disconnect(step_callback)

	if _overwatch_pending_watcher and _overwatch_pending_target:
		execute_overwatch_fire(_overwatch_pending_watcher, _overwatch_pending_target)
		await get_tree().create_timer(0.4).timeout
		_overwatch_pending_watcher = null
		_overwatch_pending_target = null


func _on_ai_tile_stepped(old_tile: Vector2i, new_tile: Vector2i, unit: Unit) -> void:
	_unit_at_tile.erase(old_tile)
	Grid.set_tile_solid(old_tile, false)
	_unit_at_tile[new_tile] = unit
	Grid.set_tile_solid(new_tile, true)
	if _overwatch_pending_watcher != null:
		return
	for watcher: Unit in get_overwatching_units():
		if watcher.overwatch_cone.has(new_tile):
			_overwatch_pending_watcher = watcher
			_overwatch_pending_target = unit
			unit.mover.interrupt()
			break


func execute_ai_attack(unit: Unit, target: Unit) -> void:
	if not unit.is_alive() or not target.is_alive():
		return
	var ctx: Dictionary = Grid.get_combat_context(unit.current_tile, target.current_tile)
	var elev_diff: int = ctx["elev_diff"] as int
	var in_cover: bool = ctx["in_cover"] as bool
	var hit: bool = CombatCalc.roll_hit(CombatCalc.BASE_ENEMY_HIT_CHANCE, in_cover)
	var damage_dealt: int = 0
	if hit:
		damage_dealt = CombatCalc.compute_damage(unit.attacker.weapon.damage, elev_diff, in_cover)
		target.health.take_damage(damage_dealt)
	unit.spend_ap(unit.attacker.weapon.ap_cost)
	_spawn_floating_text(target, hit, damage_dealt)
	if hit and target.is_alive():
		_flash_unit(target)
	await get_tree().create_timer(0.4).timeout


func _on_unit_tile_stepped(old_tile: Vector2i, new_tile: Vector2i, unit: Unit) -> void:
	_unit_at_tile.erase(old_tile)
	Grid.set_tile_solid(old_tile, false)
	_unit_at_tile[new_tile] = unit
	Grid.set_tile_solid(new_tile, true)


# --- UX helpers ---

func _rotate_view(direction: int) -> void:
	if _action_in_progress:
		return
	Grid.rotate_view(direction)
	_rebuild_visuals()


func _rebuild_visuals() -> void:
	for child: Node in _tile_layer.get_children():
		child.queue_free()
	for child: Node in _tile_pick_layer.get_children():
		child.queue_free()
	_spawn_tiles()
	_spawn_tile_colliders()
	var center_tile: Vector2i = _level.grid_size / 2
	_camera.position = Grid.tile_to_world(center_tile)
	for unit: Unit in _player_units:
		if unit.is_alive():
			unit.position = Grid.tile_to_world_elevated(unit.current_tile)
	for unit: Unit in _enemy_units:
		if unit.is_alive():
			unit.position = Grid.tile_to_world_elevated(unit.current_tile)
	_grid_overlay.queue_redraw()
	if _selected_unit:
		var prev: Unit = _selected_unit
		_deselect_unit()
		_select_unit(prev)


func _cycle_to_next_unit() -> void:
	var available: Array[Unit] = []
	for unit: Unit in _player_units:
		if unit.is_alive() and (unit.can_move() or unit.can_attack()):
			available.append(unit)
	if available.is_empty():
		return
	var start_index: int = 0
	if _selected_unit and available.has(_selected_unit):
		start_index = available.find(_selected_unit) + 1
		if start_index >= available.size():
			start_index = 0
	_deselect_unit()
	_select_unit(available[start_index])


func _update_exhausted_visuals() -> void:
	for unit: Unit in _player_units:
		if not unit.is_alive():
			continue
		var has_ap: bool = unit.can_move() or unit.can_attack()
		unit.set_exhausted(not has_ap)


func _update_end_turn_count() -> void:
	var count: int = 0
	for unit: Unit in _player_units:
		if unit.is_alive() and (unit.can_move() or unit.can_attack()):
			count += 1
	_hud.update_end_turn_label(count)
