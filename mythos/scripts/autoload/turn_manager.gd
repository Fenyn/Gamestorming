extends Node

enum Phase { DRAW, CITY_EFFECTS, SPELL_TRACK, BATTLE, PLAY }

const PHASE_NAMES: Array[String] = [
	"Draw", "City Effects", "Spell Track", "Battle", "Play"
]

const PHASE_LINGER: float = 0.5

var current_phase: Phase = Phase.DRAW
var active_player: int = 0
var round_number: int = 1
var _advancing: bool = false
var _turn_transition: TurnTransition

func start_game() -> void:
	_find_turn_transition()
	active_player = GameState.current_turn_player
	GameState.draw_opening_hand(0, 5)
	GameState.draw_opening_hand(1, 6)
	EventBus.game_started.emit()
	_start_turn()

func advance_phase() -> void:
	if _advancing:
		return
	if current_phase == Phase.PLAY:
		if NetworkManager.is_online and NetworkManager.is_local_turn():
			NetworkManager.send_action("end_turn", [])
		_end_turn()

func get_phase_name() -> String:
	return PHASE_NAMES[current_phase]

func is_interactive_phase() -> bool:
	return current_phase == Phase.PLAY

func get_round() -> int:
	return round_number

func _find_turn_transition() -> void:
	_turn_transition = get_tree().get_first_node_in_group("turn_transition") as TurnTransition

func _start_turn() -> void:
	active_player = GameState.current_turn_player
	EventBus.turn_started.emit(active_player)
	_run_automatic_phases()

func _run_automatic_phases() -> void:
	_advancing = true

	current_phase = Phase.DRAW
	EventBus.phase_changed.emit(current_phase)
	_execute_draw_phase()

	await get_tree().create_timer(PHASE_LINGER).timeout
	if not GameState.game_active:
		_advancing = false
		return

	current_phase = Phase.CITY_EFFECTS
	EventBus.phase_changed.emit(current_phase)
	_execute_city_effects()

	await get_tree().create_timer(PHASE_LINGER).timeout
	if not GameState.game_active:
		_advancing = false
		return

	current_phase = Phase.SPELL_TRACK
	EventBus.phase_changed.emit(current_phase)
	_execute_spell_track()

	await get_tree().create_timer(PHASE_LINGER).timeout
	if not GameState.game_active:
		_advancing = false
		return

	current_phase = Phase.BATTLE
	EventBus.phase_changed.emit(current_phase)
	_execute_battle()

	await get_tree().create_timer(PHASE_LINGER).timeout
	if not GameState.game_active:
		_advancing = false
		return

	current_phase = Phase.PLAY
	EventBus.phase_changed.emit(current_phase)
	_advancing = false

	if not _player_has_any_action():
		_advancing = true
		await get_tree().create_timer(PHASE_LINGER).timeout
		_advancing = false
		_end_turn()

func _execute_draw_phase() -> void:
	GameState.draw_card(active_player)

func _execute_city_effects() -> void:
	var player: PlayerState = GameState.get_active_player()
	var total: int = round_number
	for i: int in range(25):
		var building: BuildingInstance = player.city_grid[i]
		if building == null or building.data.resource_generation <= 0:
			continue
		if building.data.is_hq:
			continue
		total += building.data.resource_generation
		if building.data.id == "mead_hall":
			total += _count_adjacent_mead_halls(player, building.grid_pos)
	if total > 0:
		GameState.add_resources(active_player, total)
	_apply_palisade_bonuses(player)

func _count_adjacent_mead_halls(player: PlayerState, pos: Vector2i) -> int:
	var count: int = 0
	var neighbors: Array[Vector2i] = [
		Vector2i(pos.x - 1, pos.y), Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x, pos.y - 1), Vector2i(pos.x, pos.y + 1)
	]
	for n: Vector2i in neighbors:
		if n.x < 0 or n.x >= 5 or n.y < 0 or n.y >= 5:
			continue
		var adj: BuildingInstance = player.get_grid_cell(n)
		if adj != null and adj.data.id == "mead_hall":
			count += 1
	return count

func _apply_palisade_bonuses(player: PlayerState) -> void:
	for i: int in range(25):
		var building: BuildingInstance = player.city_grid[i]
		if building == null:
			continue
		building.max_health = building.data.health
	for i: int in range(25):
		var building: BuildingInstance = player.city_grid[i]
		if building == null or building.data.id != "palisade_wall":
			continue
		var pos: Vector2i = building.grid_pos
		var neighbors: Array[Vector2i] = [
			Vector2i(pos.x - 1, pos.y), Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x, pos.y - 1), Vector2i(pos.x, pos.y + 1)
		]
		for n: Vector2i in neighbors:
			if n.x < 0 or n.x >= 5 or n.y < 0 or n.y >= 5:
				continue
			var adj: BuildingInstance = player.get_grid_cell(n)
			if adj != null:
				adj.max_health += 5
				if adj.current_health > adj.max_health:
					adj.current_health = adj.max_health

func _execute_spell_track() -> void:
	SpellManager.advance_spells(active_player)

func _execute_battle() -> void:
	CombatManager.resolve_battle(active_player)
	await CombatManager.battle_finished

func _end_turn() -> void:
	if not GameState.game_active:
		return
	_clear_summoning_sickness()
	EventBus.turn_ended.emit(active_player)
	GameState.switch_turn()

	if GameState.current_turn_player == 0:
		round_number += 1

	if not NetworkManager.is_online and _turn_transition != null:
		_turn_transition.show_transition(GameState.current_turn_player)
		await _turn_transition.continue_pressed

	if NetworkManager.is_online:
		NetworkManager.send_checksum(GameState.turn_number, GameState.compute_state_hash())

	if not GameState.game_active:
		return
	_start_turn()

func _clear_summoning_sickness() -> void:
	var player: PlayerState = GameState.get_active_player()
	for i: int in range(5):
		var unit: UnitInstance = player.get_lane_unit(i)
		if unit != null:
			unit.summoning_sickness = false
			unit.has_attacked = false

func _player_has_any_action() -> bool:
	var player: PlayerState = GameState.get_player(active_player)
	var has_empty_lane: bool = false
	for i: int in range(5):
		if player.get_lane_unit(i) == null:
			has_empty_lane = true
			break
	var has_empty_grid: bool = false
	for i: int in range(25):
		if player.city_grid[i] == null:
			has_empty_grid = true
			break
	for card: CardData in player.hand:
		if player.resources < card.cost:
			continue
		if card.card_type == CardData.CardType.UNIT and has_empty_lane:
			return true
		if card.card_type == CardData.CardType.BUILDING and has_empty_grid:
			return true
	for spell: SpellData in CardDatabase.get_all_spells():
		if player.resources >= spell.cost:
			return true
	return false
