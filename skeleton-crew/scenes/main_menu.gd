extends Control

@onready var _address_input: LineEdit = %AddressInput
@onready var _port_input: LineEdit = %PortInput
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _start_button: Button = %StartButton
@onready var _status_label: Label = %StatusLabel
@onready var _player_list: ItemList = %PlayerList


func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.visible = false

	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_started.connect(_on_server_started)
	EventBus.player_connected.connect(_on_player_connected)
	EventBus.player_disconnected.connect(_on_player_disconnected)


func _on_host_pressed() -> void:
	var port: int = _port_input.text.to_int() if _port_input.text.length() > 0 else NetworkManager.DEFAULT_PORT
	var err: Error = NetworkManager.host_game(port)
	if err != OK:
		_status_label.text = "Failed to host: " + error_string(err)
		return
	_status_label.text = "Hosting on port " + str(port) + "..."
	_host_button.disabled = true
	_join_button.disabled = true
	NetworkManager.register_player_local({"name": "Host", "role": "", "ready": false})


func _on_join_pressed() -> void:
	var address: String = _address_input.text if _address_input.text.length() > 0 else "localhost"
	var port: int = _port_input.text.to_int() if _port_input.text.length() > 0 else NetworkManager.DEFAULT_PORT
	var err: Error = NetworkManager.join_game(address, port)
	if err != OK:
		_status_label.text = "Failed to join: " + error_string(err)
		return
	_status_label.text = "Connecting to " + address + ":" + str(port) + "..."
	_host_button.disabled = true
	_join_button.disabled = true


func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		return
	NetworkManager.start_game.rpc()


func _on_server_started() -> void:
	_status_label.text = "Hosting. Waiting for players..."
	_start_button.visible = true


func _on_connection_succeeded() -> void:
	_status_label.text = "Connected! Waiting for host to start..."


func _on_connection_failed() -> void:
	_status_label.text = "Connection failed."
	_host_button.disabled = false
	_join_button.disabled = false


func _on_player_connected(peer_id: int, info: Dictionary) -> void:
	_refresh_player_list()


func _on_player_disconnected(peer_id: int) -> void:
	_refresh_player_list()


func _refresh_player_list() -> void:
	_player_list.clear()
	for peer_id: int in NetworkManager.get_player_peers():
		var info: Dictionary = NetworkManager.get_player_info(peer_id)
		var display_name: String = info.get("name", "Player") as String
		_player_list.add_item(display_name + " (peer " + str(peer_id) + ")")
	_status_label.text = str(NetworkManager.get_player_count()) + " player(s) connected"
