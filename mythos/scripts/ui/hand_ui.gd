class_name HandUI
extends HBoxContainer

var _panels: Array[CardPanel] = []
var _selected_index: int = -1

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	EventBus.card_selected.connect(_on_card_selected)
	EventBus.card_deselected.connect(_on_card_deselected)
	EventBus.unit_summoned.connect(_on_card_played)
	EventBus.building_placed.connect(_on_card_played)
	EventBus.card_drawn.connect(_on_card_drawn)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.resources_changed.connect(_on_resources_changed)

func _get_display_player() -> int:
	if NetworkManager.is_online:
		return NetworkManager.local_player_index
	return GameState.current_turn_player

func refresh(player_index: int) -> void:
	var display: int = _get_display_player()
	if NetworkManager.is_online and player_index != display:
		return
	_clear_panels()
	var player: PlayerState = GameState.get_player(display)
	for i: int in range(player.hand.size()):
		var panel: CardPanel = CardPanel.new()
		add_child(panel)
		panel.setup(player.hand[i], i)
		_panels.append(panel)
	_update_playability()

func _clear_panels() -> void:
	for panel: CardPanel in _panels:
		panel.queue_free()
	_panels.clear()
	_selected_index = -1

func _update_playability() -> void:
	var player_index: int = GameState.current_turn_player
	var player: PlayerState = GameState.get_player(player_index)
	var is_play_phase: bool = TurnManager.is_interactive_phase()
	var has_empty_lane: bool = false
	var has_empty_grid: bool = false
	for i: int in range(5):
		if player.get_lane_unit(i) == null:
			has_empty_lane = true
			break
	for i: int in range(25):
		if player.city_grid[i] == null:
			has_empty_grid = true
			break
	for panel: CardPanel in _panels:
		if not is_play_phase:
			panel.set_playable(false)
			continue
		var card: CardData = panel.card_data
		var can_afford: bool = player.resources >= card.cost
		var has_slot: bool = true
		if card.card_type == CardData.CardType.UNIT:
			has_slot = has_empty_lane
		elif card.card_type == CardData.CardType.BUILDING:
			has_slot = has_empty_grid
		panel.set_playable(can_afford and has_slot)

func _on_card_selected(card_index: int) -> void:
	_selected_index = card_index
	for panel: CardPanel in _panels:
		panel.set_selected(panel.card_index == card_index)

func _on_card_deselected() -> void:
	_selected_index = -1
	for panel: CardPanel in _panels:
		panel.set_selected(false)

func _on_card_played(_player_index: int, _data: Variant, _pos: Variant) -> void:
	refresh(_get_display_player())

func _on_card_drawn(player_index: int, _card: CardData) -> void:
	if player_index == _get_display_player():
		refresh(player_index)

func _on_turn_started(_player_index: int) -> void:
	refresh(_get_display_player())

func _on_phase_changed(_phase: int) -> void:
	_update_playability()

func _on_resources_changed(player_index: int, _amount: int) -> void:
	if player_index == GameState.current_turn_player:
		_update_playability()
