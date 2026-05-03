extends Control

var _label: Label
var _restart_btn: Button

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	EventBus.game_won.connect(_on_game_won)
	EventBus.game_draw.connect(_on_game_draw)

func _build_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.3
	panel.anchor_right = 0.7
	panel.anchor_top = 0.3
	panel.anchor_bottom = 0.7
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(_label)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	_restart_btn = Button.new()
	_restart_btn.text = "Return to Menu"
	_restart_btn.custom_minimum_size = Vector2(200, 40)
	_restart_btn.pressed.connect(_on_restart)
	vbox.add_child(_restart_btn)

func _on_game_won(winner_index: int) -> void:
	if NetworkManager.is_online:
		if winner_index == NetworkManager.local_player_index:
			_label.text = "Victory!"
		else:
			_label.text = "Defeat"
	else:
		_label.text = "Player " + str(winner_index + 1) + " Wins!"
	visible = true

func _on_game_draw() -> void:
	_label.text = "Draw — Desync Detected"
	visible = true

func _on_restart() -> void:
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
