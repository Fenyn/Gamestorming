class_name GameController
extends Node3D

var _board: BoardController
var _pieces_container: Node3D
var _unit_pieces: Dictionary = {}
var _building_pieces: Dictionary = {}
var _spell_pieces: Array[SpellPiece] = []
var _selected_card_index: int = -1
var _selected_spell_id: String = ""
var _moving_from_lane: int = -1
var is_online: bool = false

func _ready() -> void:
	_board = $Board
	_pieces_container = $Pieces
	EventBus.card_selected.connect(_on_card_selected)
	EventBus.card_deselected.connect(_on_card_deselected)
	EventBus.spell_pool_selected.connect(_on_spell_selected)
	EventBus.spell_pool_deselected.connect(_on_spell_deselected)
	EventBus.slot_clicked.connect(_on_slot_clicked)
	EventBus.unit_summoned.connect(_on_unit_summoned)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.unit_destroyed.connect(_on_unit_destroyed)
	EventBus.building_destroyed.connect(_on_building_destroyed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.unit_attacked.connect(_on_unit_attacked)
	EventBus.combat_resolved.connect(_refresh_all_pieces)
	EventBus.unit_damaged.connect(_on_unit_damaged)
	EventBus.building_damaged.connect(_on_building_damaged)
	EventBus.unit_moved.connect(_on_unit_moved)
	EventBus.unit_selected_for_move.connect(_on_unit_selected_for_move)
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.spell_resolved.connect(_on_spell_resolved)
	EventBus.spell_advanced.connect(_on_spell_advanced)
	NetworkManager.action_received.connect(_on_action_received)
	NetworkManager.opponent_disconnected.connect(_on_opponent_disconnected)
	NetworkManager.checksum_mismatch.connect(_on_checksum_mismatch)
	add_to_group("game_controller")
	call_deferred("_auto_start_local")

var _started: bool = false

func _auto_start_local() -> void:
	if _started:
		return
	if NetworkManager.is_online and NetworkManager.pending_seed != 0:
		start_game_with_seed(NetworkManager.pending_seed, true)
		NetworkManager.pending_seed = 0
	elif not NetworkManager.is_online:
		start_game_with_seed(randi(), false)

func start_game_with_seed(seed_val: int, online: bool) -> void:
	if _started:
		return
	_started = true
	is_online = online
	GameState.setup_game(seed_val)
	if online and NetworkManager.local_player_index == 1:
		_flip_camera()
	TurnManager.start_game()

func _on_turn_started(player_index: int) -> void:
	if is_online:
		return
	_orient_camera(player_index)

func _flip_camera() -> void:
	_orient_camera(1)

func _orient_camera(player_index: int) -> void:
	var cam: CameraController = $Camera3D as CameraController
	var target_pos: Vector3
	var target_rot: Vector3
	if player_index == 0:
		target_pos = Vector3(0, 10, 11)
		target_rot = Vector3(-55, 0, 0)
	else:
		target_pos = Vector3(0, 10, -11)
		target_rot = Vector3(-55, 180, 0)
	cam.set_tween_active()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(cam, "position", target_pos, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(cam, "rotation_degrees", target_rot, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.finished.connect(cam.reset_target)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("right_click") or event.is_action_pressed("ui_cancel"):
		if _moving_from_lane >= 0:
			_moving_from_lane = -1
			_board.unhighlight_all()
		elif _selected_card_index >= 0:
			_selected_card_index = -1
			EventBus.card_deselected.emit()
		elif _selected_spell_id != "":
			_selected_spell_id = ""
			EventBus.spell_pool_deselected.emit()

func _can_act() -> bool:
	if not TurnManager.is_interactive_phase():
		return false
	if is_online and not NetworkManager.is_local_turn():
		return false
	return true

func _on_game_started() -> void:
	_spawn_initial_buildings()

func _spawn_initial_buildings() -> void:
	for i: int in range(2):
		var player: PlayerState = GameState.get_player(i)
		var hq: BuildingInstance = player.get_grid_cell(Vector2i(2, 2))
		if hq != null:
			_spawn_building_piece(hq, i)

func _on_card_selected(card_index: int) -> void:
	if not _can_act():
		return
	_selected_card_index = card_index
	_selected_spell_id = ""

func _on_card_deselected() -> void:
	_selected_card_index = -1

func _on_spell_selected(spell_id: String) -> void:
	if not _can_act():
		return
	_selected_spell_id = spell_id
	_selected_card_index = -1
	EventBus.card_deselected.emit()

func _on_spell_deselected() -> void:
	_selected_spell_id = ""

func _on_slot_clicked(slot_type: String, position: Variant) -> void:
	if not _can_act():
		return
	var active: int = GameState.current_turn_player
	if slot_type == "lane" and _moving_from_lane >= 0:
		var to_lane: int = position as int
		if GameState.validate_move(active, _moving_from_lane, to_lane):
			GameState.execute_move(active, _moving_from_lane, to_lane)
			_send_action("move_unit", [_moving_from_lane, to_lane])
		_moving_from_lane = -1
		_board.unhighlight_all()
	elif slot_type == "lane" and _selected_card_index >= 0:
		var lane: int = position as int
		if GameState.validate_summon(active, _selected_card_index, lane):
			var card_index: int = _selected_card_index
			GameState.execute_summon(active, card_index, lane)
			_send_action("summon_unit", [card_index, lane])
			_selected_card_index = -1
			EventBus.card_deselected.emit()
	elif slot_type == "grid" and _selected_card_index >= 0:
		var grid_pos: Vector2i = position as Vector2i
		if GameState.validate_build(active, _selected_card_index, grid_pos):
			var card_index: int = _selected_card_index
			GameState.execute_build(active, card_index, grid_pos)
			_send_action("place_building", [card_index, grid_pos.x, grid_pos.y])
			_selected_card_index = -1
			EventBus.card_deselected.emit()
	elif slot_type == "lane" and _selected_spell_id != "":
		var lane: int = position as int
		if GameState.validate_cast_spell(active, _selected_spell_id):
			var spell: SpellData = CardDatabase.get_card(_selected_spell_id) as SpellData
			GameState.spend_resources(active, spell.cost)
			SpellManager.cast_spell(active, spell, lane)
			_send_action("cast_spell", [_selected_spell_id, lane])
			_selected_spell_id = ""
			EventBus.spell_pool_deselected.emit()

func _send_action(action_type: String, args: Array) -> void:
	if is_online:
		NetworkManager.send_action(action_type, args)

func _on_action_received(action_type: String, args: Array) -> void:
	var opponent: int = NetworkManager.get_opponent_index()
	match action_type:
		"summon_unit":
			var card_index: int = args[0] as int
			var lane: int = args[1] as int
			if GameState.validate_summon(opponent, card_index, lane):
				GameState.execute_summon(opponent, card_index, lane)
			else:
				_handle_desync()
		"place_building":
			var card_index: int = args[0] as int
			var gx: int = args[1] as int
			var gy: int = args[2] as int
			if GameState.validate_build(opponent, card_index, Vector2i(gx, gy)):
				GameState.execute_build(opponent, card_index, Vector2i(gx, gy))
			else:
				_handle_desync()
		"cast_spell":
			var spell_id: String = args[0] as String
			var lane: int = args[1] as int
			if GameState.validate_cast_spell(opponent, spell_id):
				var spell: SpellData = CardDatabase.get_card(spell_id) as SpellData
				GameState.spend_resources(opponent, spell.cost)
				SpellManager.cast_spell(opponent, spell, lane)
			else:
				_handle_desync()
		"move_unit":
			var from_lane: int = args[0] as int
			var to_lane: int = args[1] as int
			if GameState.validate_move(opponent, from_lane, to_lane):
				GameState.execute_move(opponent, from_lane, to_lane)
			else:
				_handle_desync()
		"end_turn":
			TurnManager.advance_phase()

func _handle_desync() -> void:
	GameState.game_active = false
	EventBus.game_draw.emit()

func _on_opponent_disconnected() -> void:
	GameState.game_active = false
	EventBus.game_won.emit(NetworkManager.local_player_index)

func _on_checksum_mismatch(_turn: int) -> void:
	if GameState.game_active:
		_handle_desync()

# === Piece spawning and visuals ===

func _on_unit_summoned(player_index: int, _unit_data: UnitData, lane: int) -> void:
	var player: PlayerState = GameState.get_player(player_index)
	var instance: UnitInstance = player.get_lane_unit(lane)
	if instance != null:
		_spawn_unit_piece(instance, player_index, lane)

func _on_building_placed(player_index: int, _building_data: BuildingData, grid_pos: Vector2i) -> void:
	var player: PlayerState = GameState.get_player(player_index)
	var instance: BuildingInstance = player.get_grid_cell(grid_pos)
	if instance != null:
		_spawn_building_piece(instance, player_index)

func _on_unit_destroyed(lane: int, owner_player: int, _unit_data: UnitData) -> void:
	var key: String = str(owner_player) + "_lane_" + str(lane)
	if _unit_pieces.has(key):
		var piece: UnitPiece = _unit_pieces[key] as UnitPiece
		piece.play_death()
		_unit_pieces.erase(key)
		get_tree().create_timer(0.25).timeout.connect(piece.queue_free)

func _on_building_destroyed(grid_pos: Vector2i, owner_player: int) -> void:
	var key: String = str(owner_player) + "_grid_" + str(grid_pos.x) + "_" + str(grid_pos.y)
	if _building_pieces.has(key):
		_building_pieces[key].queue_free()
		_building_pieces.erase(key)

func _spawn_unit_piece(instance: UnitInstance, player_index: int, lane: int) -> void:
	var piece: UnitPiece = UnitPiece.new()
	_pieces_container.add_child(piece)
	piece.setup(instance)
	piece.position = _get_lane_world_pos(player_index, lane)
	_unit_pieces[str(player_index) + "_lane_" + str(lane)] = piece

func _spawn_building_piece(instance: BuildingInstance, player_index: int) -> void:
	var piece: BuildingPiece = BuildingPiece.new()
	_pieces_container.add_child(piece)
	piece.setup(instance)
	piece.position = _get_grid_world_pos(player_index, instance.grid_pos)
	_building_pieces[str(player_index) + "_grid_" + str(instance.grid_pos.x) + "_" + str(instance.grid_pos.y)] = piece

func _on_unit_selected_for_move(player_index: int, lane: int) -> void:
	if not _can_act():
		return
	_selected_card_index = -1
	_selected_spell_id = ""
	EventBus.card_deselected.emit()
	_moving_from_lane = lane
	var player: PlayerState = GameState.get_player(player_index)
	var unit: UnitInstance = player.get_lane_unit(lane)
	if unit == null:
		return
	var mobility: int = 0
	for kw: KeywordData in unit.data.keywords:
		if kw.keyword == KeywordData.Keyword.MOBILITY:
			mobility = kw.value
			break
	_board.unhighlight_all()
	for target_lane: int in range(5):
		if target_lane == lane or absi(target_lane - lane) > mobility:
			continue
		if player.get_lane_unit(target_lane) == null:
			(_board.lane_slots[player_index][target_lane] as LaneSlot).set_highlighted(true)

func _on_unit_moved(player_index: int, from_lane: int, to_lane: int) -> void:
	var from_key: String = str(player_index) + "_lane_" + str(from_lane)
	var to_key: String = str(player_index) + "_lane_" + str(to_lane)
	if _unit_pieces.has(from_key):
		var piece: UnitPiece = _unit_pieces[from_key]
		piece.position = _get_lane_world_pos(player_index, to_lane)
		_unit_pieces.erase(from_key)
		_unit_pieces[to_key] = piece

func _on_unit_attacked(lane: int, attacker_player: int) -> void:
	var key: String = str(attacker_player) + "_lane_" + str(lane)
	if _unit_pieces.has(key):
		var direction: float = -1.0 if attacker_player == 0 else 1.0
		(_unit_pieces[key] as UnitPiece).play_attack(direction)

func _on_unit_damaged(lane: int, owner_player: int, _damage: int) -> void:
	var key: String = str(owner_player) + "_lane_" + str(lane)
	if _unit_pieces.has(key):
		var piece: UnitPiece = _unit_pieces[key] as UnitPiece
		piece.play_hit()
		piece.update_display()

func _on_building_damaged(grid_pos: Vector2i, owner_player: int, _damage: int) -> void:
	var key: String = str(owner_player) + "_grid_" + str(grid_pos.x) + "_" + str(grid_pos.y)
	if _building_pieces.has(key):
		(_building_pieces[key] as BuildingPiece).update_display()

func _refresh_all_pieces() -> void:
	for piece: UnitPiece in _unit_pieces.values():
		piece.update_display()
	for piece: BuildingPiece in _building_pieces.values():
		piece.update_display()

func _on_spell_cast(player_index: int, _spell_data: SpellData, _target_lane: int) -> void:
	var track: Array = SpellManager.get_track(player_index)
	if track.is_empty():
		return
	var instance: SpellInstance = track[track.size() - 1]
	var piece: SpellPiece = SpellPiece.new()
	_pieces_container.add_child(piece)
	piece.setup(instance)
	piece.position = _get_spell_track_world_pos(player_index, instance.current_position)
	_spell_pieces.append(piece)

func _on_spell_advanced(_player_index: int, _track_pos: int) -> void:
	_refresh_spell_pieces()

func _on_spell_resolved(_player_index: int, _spell_data: SpellData) -> void:
	_refresh_spell_pieces()
	_refresh_all_pieces()

func _refresh_spell_pieces() -> void:
	var active_spells: Array[SpellInstance] = []
	for p: int in range(2):
		for spell: SpellInstance in SpellManager.get_track(p):
			active_spells.append(spell)
	var to_remove: Array[SpellPiece] = []
	for piece: SpellPiece in _spell_pieces:
		if piece.instance not in active_spells:
			to_remove.append(piece)
		else:
			piece.position = _get_spell_track_world_pos(piece.instance.owner_index, piece.instance.current_position)
			piece.update_display()
	for piece: SpellPiece in to_remove:
		_spell_pieces.erase(piece)
		piece.queue_free()

func _get_lane_world_pos(player_index: int, lane: int) -> Vector3:
	var x: float = float(lane - 2)
	var z: float = 1.5 if player_index == 0 else -1.5
	return Vector3(x, 0, z)

func _get_grid_world_pos(player_index: int, grid_pos: Vector2i) -> Vector3:
	var x: float = float(grid_pos.x - 2)
	var base_z: float = 5.0 if player_index == 0 else -5.0
	var row_offset: float = float(grid_pos.y - 2)
	var z: float = base_z + row_offset
	return Vector3(x, 0, z)

func _get_spell_track_world_pos(player_index: int, track_position: int) -> Vector3:
	var x: float = float(track_position - 3)
	var z: float = 9.0 if player_index == 0 else -9.0
	return Vector3(x, 0, z)
