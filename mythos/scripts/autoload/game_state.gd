extends Node

var players: Array[PlayerState] = []
var current_turn_player: int = 0
var turn_number: int = 0
var game_active: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	reset()

func reset() -> void:
	players.clear()
	players.append(PlayerState.new(0))
	players.append(PlayerState.new(1))
	current_turn_player = 0
	turn_number = 0
	game_active = false

func get_active_player() -> PlayerState:
	return players[current_turn_player]

func get_inactive_player() -> PlayerState:
	return players[1 - current_turn_player]

func get_player(index: int) -> PlayerState:
	return players[index]

func is_active_player(index: int) -> bool:
	return current_turn_player == index

func switch_turn() -> void:
	current_turn_player = 1 - current_turn_player
	turn_number += 1

func setup_game(seed_value: int) -> void:
	rng.seed = seed_value
	for player: PlayerState in players:
		var deck: Array[CardData] = CardDatabase.create_nordic_starter_deck()
		_shuffle_deck(deck)
		player.deck = deck
		_place_hq(player)
	game_active = true

func _shuffle_deck(deck: Array[CardData]) -> void:
	for i: int in range(deck.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: CardData = deck[i]
		deck[i] = deck[j]
		deck[j] = temp

func _place_hq(player: PlayerState) -> void:
	var hq: BuildingData = CardDatabase.get_card("grand_lodge") as BuildingData
	if hq == null:
		return
	var instance: BuildingInstance = BuildingInstance.new()
	instance.data = hq
	instance.current_health = hq.health
	instance.max_health = hq.health
	instance.grid_pos = Vector2i(2, 2)
	instance.owner_index = player.player_index
	player.set_grid_cell(Vector2i(2, 2), instance)

func draw_card(player_index: int) -> CardData:
	var player: PlayerState = players[player_index]
	if player.deck.is_empty():
		return null
	var card: CardData = player.deck.pop_front()
	player.hand.append(card)
	EventBus.card_drawn.emit(player_index, card)
	return card

func draw_opening_hand(player_index: int, count: int) -> void:
	for i: int in range(count):
		draw_card(player_index)

func can_afford(player_index: int, cost: int) -> bool:
	return players[player_index].resources >= cost

func spend_resources(player_index: int, amount: int) -> void:
	players[player_index].resources -= amount
	EventBus.resources_changed.emit(player_index, players[player_index].resources)

func add_resources(player_index: int, amount: int) -> void:
	players[player_index].resources += amount
	EventBus.resources_changed.emit(player_index, players[player_index].resources)

func validate_summon(player_index: int, card_index: int, lane: int) -> bool:
	if not is_active_player(player_index):
		return false
	var player: PlayerState = players[player_index]
	if card_index < 0 or card_index >= player.hand.size():
		return false
	var card: CardData = player.hand[card_index]
	if card.card_type != CardData.CardType.UNIT:
		return false
	if not can_afford(player_index, card.cost):
		return false
	if lane < 0 or lane >= 5:
		return false
	if player.get_lane_unit(lane) != null:
		return false
	return true

func validate_build(player_index: int, card_index: int, grid_pos: Vector2i) -> bool:
	if not is_active_player(player_index):
		return false
	var player: PlayerState = players[player_index]
	if card_index < 0 or card_index >= player.hand.size():
		return false
	var card: CardData = player.hand[card_index]
	if card.card_type != CardData.CardType.BUILDING:
		return false
	if not can_afford(player_index, card.cost):
		return false
	if grid_pos.x < 0 or grid_pos.x >= 5 or grid_pos.y < 0 or grid_pos.y >= 5:
		return false
	if player.get_grid_cell(grid_pos) != null:
		return false
	return true

func validate_cast_spell(player_index: int, spell_id: String) -> bool:
	if not is_active_player(player_index):
		return false
	var spell: SpellData = CardDatabase.get_card(spell_id) as SpellData
	if spell == null:
		return false
	if not can_afford(player_index, spell.cost):
		return false
	return true

func execute_summon(player_index: int, card_index: int, lane: int) -> UnitInstance:
	var player: PlayerState = players[player_index]
	var card: UnitData = player.hand[card_index] as UnitData
	spend_resources(player_index, card.cost)
	player.hand.remove_at(card_index)

	var instance: UnitInstance = UnitInstance.new()
	instance.data = card
	instance.current_health = card.health
	instance.current_attack = card.attack
	instance.lane_index = lane
	instance.owner_index = player_index

	var has_haste: bool = false
	for kw: KeywordData in card.keywords:
		if kw.keyword == KeywordData.Keyword.HASTE:
			has_haste = true
			break
	instance.summoning_sickness = not has_haste

	player.set_lane_unit(lane, instance)
	EventBus.unit_summoned.emit(player_index, card, lane)
	return instance

func execute_build(player_index: int, card_index: int, grid_pos: Vector2i) -> BuildingInstance:
	var player: PlayerState = players[player_index]
	var card: BuildingData = player.hand[card_index] as BuildingData
	spend_resources(player_index, card.cost)
	player.hand.remove_at(card_index)

	var instance: BuildingInstance = BuildingInstance.new()
	instance.data = card
	instance.current_health = card.health
	instance.max_health = card.health
	instance.grid_pos = grid_pos
	instance.owner_index = player_index

	player.set_grid_cell(grid_pos, instance)
	EventBus.building_placed.emit(player_index, card, grid_pos)
	return instance

func validate_move(player_index: int, from_lane: int, to_lane: int) -> bool:
	if not is_active_player(player_index):
		return false
	var player: PlayerState = players[player_index]
	var unit: UnitInstance = player.get_lane_unit(from_lane)
	if unit == null:
		return false
	if player.get_lane_unit(to_lane) != null:
		return false
	var mobility: int = 0
	for kw: KeywordData in unit.data.keywords:
		if kw.keyword == KeywordData.Keyword.MOBILITY:
			mobility = kw.value
			break
	if mobility <= 0:
		return false
	if absi(to_lane - from_lane) > mobility:
		return false
	return true

func execute_move(player_index: int, from_lane: int, to_lane: int) -> void:
	var player: PlayerState = players[player_index]
	var unit: UnitInstance = player.get_lane_unit(from_lane)
	player.set_lane_unit(from_lane, null)
	unit.lane_index = to_lane
	player.set_lane_unit(to_lane, unit)
	EventBus.unit_moved.emit(player_index, from_lane, to_lane)

func compute_state_hash() -> int:
	var hash_val: int = 0
	hash_val ^= turn_number * 31
	hash_val ^= current_turn_player * 17
	for i: int in range(2):
		var p: PlayerState = players[i]
		hash_val ^= p.resources * (i + 1) * 7
		hash_val ^= p.hand.size() * (i + 1) * 13
		hash_val ^= p.deck.size() * (i + 1) * 19
	return hash_val
