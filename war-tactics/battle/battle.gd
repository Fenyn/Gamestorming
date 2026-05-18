class_name BattleScene
extends Node2D

enum InputState { IDLE, UNIT_SELECTED }

const TILE_FILL_COLOR: Color = Color(0.35, 0.45, 0.30)
const TILE_BORDER_COLOR: Color = Color(0.15, 0.20, 0.12)
const UNIT_SCENE: PackedScene = preload("res://battle/unit/unit.tscn")
const GRID_SIZE: Vector2i = Vector2i(12, 12)
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


func _ready() -> void:
	Grid.setup(GRID_SIZE)
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
			elif key.keycode == KEY_ESCAPE and _can_accept_input():
				if _input_state == InputState.UNIT_SELECTED:
					_deselect_unit()
	if not _can_accept_input():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _input_state == InputState.UNIT_SELECTED:
				_deselect_unit()


func _can_accept_input() -> bool:
	return not _action_in_progress and not _battle_over and _is_player_turn()


func _is_player_turn() -> bool:
	return _turn_machine.current_state is TurnPlayer


# --- Turn system ---

func _connect_turn_signals() -> void:
	var player_turn: TurnPlayer = _turn_machine.get_node("PlayerTurn") as TurnPlayer
	var enemy_turn: TurnEnemy = _turn_machine.get_node("EnemyTurn") as TurnEnemy
	var won: TurnWon = _turn_machine.get_node("Won") as TurnWon
	var lost: TurnLost = _turn_machine.get_node("Lost") as TurnLost

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
			unit.refresh_ap()
	_update_exhausted_visuals()
	_hud.set_player_turn()
	_hud.set_turn_count(_turn_count)
	_update_end_turn_count()


func _on_enemy_turn_started() -> void:
	_deselect_unit()
	_hud.set_enemy_turn()


func _on_enemy_turn_finished() -> void:
	_turn_machine.transition_to("PlayerTurn")


func _on_end_turn() -> void:
	if not _is_player_turn() or _action_in_progress:
		return
	_deselect_unit()
	_turn_machine.transition_to("EnemyTurn")


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


# --- Unit spawning ---

func _spawn_squad() -> void:
	var spawn_positions: Array[Vector2i] = [
		Vector2i(2, 5), Vector2i(2, 6), Vector2i(2, 7),
	]
	for i: int in RunState.squad_ids.size():
		if i >= spawn_positions.size():
			break
		var data: UnitData = Database.get_unit_data(RunState.squad_ids[i])
		if data:
			var unit: Unit = _spawn_unit(spawn_positions[i], data)
			_player_units.append(unit)


func _spawn_enemies() -> void:
	var spawn_positions: Array[Vector2i] = [
		Vector2i(8, 5), Vector2i(9, 6), Vector2i(8, 7),
	]
	var dummy_data: UnitData = Database.get_unit_data("dummy")
	if dummy_data == null:
		return
	for pos: Vector2i in spawn_positions:
		var unit: Unit = _spawn_unit(pos, dummy_data)
		_enemy_units.append(unit)


func _spawn_unit(tile: Vector2i, data: UnitData) -> Unit:
	var unit: Unit = UNIT_SCENE.instantiate() as Unit
	_entity_layer.add_child(unit)
	unit.setup(tile, data)
	unit.unit_died.connect(_on_unit_died)
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
		_turn_machine.transition_to("Won")
		return
	var players_alive: bool = _player_units.any(func(u: Unit) -> bool: return u.is_alive())
	if not players_alive:
		_turn_machine.transition_to("Lost")


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

	if _unit_at_tile.has(coord):
		var hovered_unit: Unit = _unit_at_tile[coord] as Unit
		if hovered_unit.is_alive() and hovered_unit != _selected_unit:
			_hud.show_hover_info(hovered_unit.unit_data.unit_label, hovered_unit.health.current_hp, hovered_unit.health.max_hp)
		else:
			_hud.hide_hover_info()
	else:
		_hud.hide_hover_info()

	if _input_state != InputState.UNIT_SELECTED:
		return

	if _attack_range_cache.has(coord) and _unit_at_tile.has(coord):
		var target: Unit = _unit_at_tile[coord] as Unit
		if target.is_enemy and target.is_alive() and _selected_unit.can_attack():
			var weapon: WeaponData = _selected_unit.attacker.weapon
			_grid_overlay.show_targeting_line(_selected_unit.current_tile, coord)
			_hud.show_attack_preview(
				weapon.weapon_name, weapon.damage,
				target.health.current_hp, target.health.max_hp,
				weapon.ap_cost,
			)
			_grid_overlay.clear_path_preview()
			_hud.hide_move_preview()
			return

	_grid_overlay.clear_targeting_line()
	_hud.hide_attack_preview()

	if _reachable_cache.has(coord) and _selected_unit.can_move():
		var tile_path: Array[Vector2i] = _compute_path(_selected_unit, coord)
		var max_steps: int = _selected_unit.action_points + 1
		if tile_path.size() > max_steps:
			tile_path.resize(max_steps)
		_grid_overlay.show_path_preview(tile_path)
		var dest: Vector2i = tile_path[tile_path.size() - 1]
		var move_cost: int = (tile_path.size() - 1) * _selected_unit.unit_data.move_cost
		var ap_after_move: int = _selected_unit.action_points - move_cost
		var targets_from_dest: int = _count_targets_from_tile(dest, ap_after_move)
		_hud.show_move_preview(move_cost, targets_from_dest)
		_update_target_pips_from_tile(dest, ap_after_move)
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
		if maxi(dx, dy) <= weapon_range:
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
				if target.is_enemy and target.is_alive():
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
	unit.state_machine.transition_to("Moving", {
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

	var attacking_state: UnitAttacking = unit.state_machine.get_node("Attacking") as UnitAttacking
	attacking_state.attack_resolved.connect(_on_attack_resolved.bind(unit), CONNECT_ONE_SHOT)
	unit.state_machine.transition_to("Attacking", {
		"target": target,
		"weapon": unit.attacker.weapon,
		"minigame_layer": _minigame_layer,
	})


func _on_attack_resolved(target: Unit, hit: bool, attacker_unit: Unit) -> void:
	_spawn_floating_text(target, hit, attacker_unit)
	if hit and target.is_alive():
		_flash_unit(target)

	_action_in_progress = false
	_update_exhausted_visuals()
	_update_end_turn_count()
	if attacker_unit.is_alive() and not _battle_over:
		if attacker_unit.can_move() or attacker_unit.can_attack():
			_select_unit(attacker_unit)


func _spawn_floating_text(target: Unit, hit: bool, attacker_unit: Unit) -> void:
	var label: FloatingText = FloatingText.new()
	if hit and attacker_unit.attacker.weapon:
		label.text = str(attacker_unit.attacker.weapon.damage)
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
		if maxi(dx, dy) <= weapon_range:
			enemy.show_target_pip(true, can_afford)


func _clear_target_pips() -> void:
	for enemy: Unit in _enemy_units:
		enemy.show_target_pip(false)


func _on_unit_tile_stepped(old_tile: Vector2i, new_tile: Vector2i, unit: Unit) -> void:
	_unit_at_tile.erase(old_tile)
	Grid.set_tile_solid(old_tile, false)
	_unit_at_tile[new_tile] = unit
	Grid.set_tile_solid(new_tile, true)


# --- UX helpers ---

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
