extends Control

var _ip_input: LineEdit
var _port_input: LineEdit
var _status_label: Label
var _host_btn: Button
var _join_btn: Button
var _local_btn: Button
var _waiting: bool = false

func _ready() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -200
	vbox.offset_right = 200
	vbox.offset_top = -180
	vbox.offset_bottom = 180
	add_child(vbox)

	var title: Label = Label.new()
	title.text = "MYTHOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	_add_spacer(vbox, 20)

	_local_btn = Button.new()
	_local_btn.text = "Local Game (Hot-Seat)"
	_local_btn.custom_minimum_size = Vector2(300, 50)
	_local_btn.pressed.connect(_on_local_pressed)
	vbox.add_child(_local_btn)

	_add_spacer(vbox, 15)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	_add_spacer(vbox, 10)

	var online_label: Label = Label.new()
	online_label.text = "Online Play"
	online_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	online_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(online_label)

	_add_spacer(vbox, 10)

	var ip_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(ip_row)
	var ip_label: Label = Label.new()
	ip_label.text = "IP: "
	ip_row.add_child(ip_label)
	_ip_input = LineEdit.new()
	_ip_input.text = "127.0.0.1"
	_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(_ip_input)

	var port_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(port_row)
	var port_label: Label = Label.new()
	port_label.text = "Port: "
	port_row.add_child(port_label)
	_port_input = LineEdit.new()
	_port_input.text = "7000"
	_port_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_row.add_child(_port_input)

	_add_spacer(vbox, 10)

	var btn_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(btn_row)

	_host_btn = Button.new()
	_host_btn.text = "Host Game"
	_host_btn.custom_minimum_size = Vector2(140, 45)
	_host_btn.pressed.connect(_on_host_pressed)
	btn_row.add_child(_host_btn)

	var btn_spacer: Control = Control.new()
	btn_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(btn_spacer)

	_join_btn = Button.new()
	_join_btn.text = "Join Game"
	_join_btn.custom_minimum_size = Vector2(140, 45)
	_join_btn.pressed.connect(_on_join_pressed)
	btn_row.add_child(_join_btn)

	_add_spacer(vbox, 10)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
	vbox.add_child(_status_label)

func _add_spacer(parent: Control, height: int) -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)

func _on_local_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_host_pressed() -> void:
	if _waiting:
		return
	var port: int = _port_input.text.to_int()
	var err: Error = NetworkManager.host_game(port)
	if err != OK:
		_status_label.text = "Failed to host on port " + str(port)
		return
	_status_label.text = "Hosting on port " + str(port) + "... waiting for opponent"
	_host_btn.disabled = true
	_join_btn.disabled = true
	_local_btn.disabled = true
	_waiting = true
	EventBus.player_connected.connect(_on_opponent_joined, CONNECT_ONE_SHOT)

func _on_join_pressed() -> void:
	if _waiting:
		return
	var address: String = _ip_input.text
	var port: int = _port_input.text.to_int()
	var err: Error = NetworkManager.join_game(address, port)
	if err != OK:
		_status_label.text = "Failed to connect to " + address + ":" + str(port)
		return
	_status_label.text = "Connecting to " + address + ":" + str(port) + "..."
	_host_btn.disabled = true
	_join_btn.disabled = true
	_local_btn.disabled = true
	_waiting = true
	NetworkManager.connection_established.connect(_on_connected_to_host, CONNECT_ONE_SHOT)
	NetworkManager.connection_failed.connect(_on_connect_failed, CONNECT_ONE_SHOT)

func _on_opponent_joined(_id: int) -> void:
	_status_label.text = "Opponent connected! Starting..."
	NetworkManager.seed_exchange_complete.connect(_on_seed_ready, CONNECT_ONE_SHOT)
	NetworkManager.start_seed_exchange()

func _on_connected_to_host() -> void:
	_status_label.text = "Connected! Exchanging seeds..."
	NetworkManager.seed_exchange_complete.connect(_on_seed_ready, CONNECT_ONE_SHOT)
	NetworkManager.start_seed_exchange()

func _on_connect_failed() -> void:
	_status_label.text = "Connection failed."
	_host_btn.disabled = false
	_join_btn.disabled = false
	_local_btn.disabled = false
	_waiting = false

func _on_seed_ready(_combined_seed: int) -> void:
	_status_label.text = "Starting game..."
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scenes/game.tscn")
