class_name GameHUD
extends Control

var _phase_label: Label
var _player_label: Label
var _resources_label: Label
var _turn_label: Label
var _p1_hq_label: Label
var _p2_hq_label: Label
var _end_phase_btn: Button

func _ready() -> void:
	_build_ui()
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.building_damaged.connect(_on_building_damaged)
	EventBus.combat_resolved.connect(_update_hq_display)

func _build_ui() -> void:
	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.anchor_right = 1.0
	top_bar.offset_bottom = 40
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)

	_turn_label = Label.new()
	_turn_label.text = "Turn 1"
	_turn_label.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(_turn_label)

	var spacer1: Control = Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer1)

	_p1_hq_label = Label.new()
	_p1_hq_label.text = "P1 HQ: 50"
	_p1_hq_label.add_theme_font_size_override("font_size", 16)
	_p1_hq_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	top_bar.add_child(_p1_hq_label)

	var spacer1b: Control = Control.new()
	spacer1b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer1b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer1b)

	_player_label = Label.new()
	_player_label.text = "Player 1's Turn"
	_player_label.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(_player_label)

	var spacer2: Control = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer2)

	_p2_hq_label = Label.new()
	_p2_hq_label.text = "P2 HQ: 50"
	_p2_hq_label.add_theme_font_size_override("font_size", 16)
	_p2_hq_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	top_bar.add_child(_p2_hq_label)

	var spacer2b: Control = Control.new()
	spacer2b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer2b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer2b)

	_phase_label = Label.new()
	_phase_label.text = "Phase: Play"
	_phase_label.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(_phase_label)

	var spacer3: Control = Control.new()
	spacer3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer3)

	_resources_label = Label.new()
	_resources_label.text = "Resources: 0"
	_resources_label.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(_resources_label)

	_end_phase_btn = Button.new()
	_end_phase_btn.text = "End Turn"
	_end_phase_btn.custom_minimum_size = Vector2(200, 50)
	_end_phase_btn.anchor_left = 1.0
	_end_phase_btn.anchor_right = 1.0
	_end_phase_btn.anchor_top = 1.0
	_end_phase_btn.anchor_bottom = 1.0
	_end_phase_btn.offset_left = -220
	_end_phase_btn.offset_right = -10
	_end_phase_btn.offset_top = -240
	_end_phase_btn.offset_bottom = -190
	_end_phase_btn.pressed.connect(_on_end_phase_pressed)
	add_child(_end_phase_btn)

func _on_phase_changed(phase: int) -> void:
	_phase_label.text = "Phase: " + TurnManager.PHASE_NAMES[phase]
	var show_btn: bool = phase == TurnManager.Phase.PLAY
	if NetworkManager.is_online and not NetworkManager.is_local_turn():
		show_btn = false
	_end_phase_btn.visible = show_btn

func _on_turn_started(player_index: int) -> void:
	if NetworkManager.is_online:
		if player_index == NetworkManager.local_player_index:
			_player_label.text = "Your Turn"
		else:
			_player_label.text = "Opponent's Turn"
	else:
		_player_label.text = "Player " + str(player_index + 1) + "'s Turn"
	_turn_label.text = "Turn " + str(GameState.turn_number + 1)
	var display_player: int = NetworkManager.local_player_index if NetworkManager.is_online else player_index
	_update_resources(display_player)
	_update_hq_display()

func _on_resources_changed(player_index: int, _amount: int) -> void:
	if player_index == GameState.current_turn_player:
		_update_resources(player_index)

func _update_resources(player_index: int) -> void:
	var player: PlayerState = GameState.get_player(player_index)
	_resources_label.text = "Resources: " + str(player.resources) + " (+" + str(TurnManager.get_round()) + "/turn)"

func _update_hq_display() -> void:
	for i: int in range(2):
		var hq: BuildingInstance = GameState.get_player(i).get_grid_cell(Vector2i(2, 2))
		var hp: int = hq.current_health if hq != null else 0
		var label: Label = _p1_hq_label if i == 0 else _p2_hq_label
		label.text = "P" + str(i + 1) + " HQ: " + str(hp)
		if hq != null and hq.current_health < hq.max_health:
			label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif i == 0:
			label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		else:
			label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))

func _on_building_damaged(_grid_pos: Vector2i, _owner: int, _damage: int) -> void:
	_update_hq_display()

func _on_end_phase_pressed() -> void:
	TurnManager.advance_phase()
