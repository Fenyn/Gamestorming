extends Node

enum ServerMode { LISTEN, DEDICATED }

const DEFAULT_PORT: int = 9876
const MAX_CLIENTS: int = 4

signal connection_succeeded()
signal connection_failed()
signal server_started()

var server_mode: ServerMode = ServerMode.LISTEN
var _players: Dictionary = {} # peer_id -> {name: String, role: String, ready: bool}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	_check_cli_args()


func _check_cli_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	if args.has("--server"):
		server_mode = ServerMode.DEDICATED
		var port: int = DEFAULT_PORT
		var port_idx: int = args.find("--port")
		if port_idx >= 0 and port_idx + 1 < args.size():
			port = args[port_idx + 1].to_int()
		host_game(port)
		get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")


func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	server_started.emit()
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func disconnect_game() -> void:
	_players.clear()
	multiplayer.multiplayer_peer = null


func get_player_peers() -> Array[int]:
	var peers: Array[int] = []
	if server_mode == ServerMode.LISTEN:
		peers.append(1)
	for peer_id: int in multiplayer.get_peers():
		peers.append(peer_id)
	return peers


func is_player_peer(peer_id: int) -> bool:
	if peer_id == 1 and server_mode == ServerMode.DEDICATED:
		return false
	return true


func get_player_info(peer_id: int) -> Dictionary:
	return _players.get(peer_id, {})


func get_player_count() -> int:
	return _players.size()


func register_player_local(info: Dictionary) -> void:
	var my_id: int = multiplayer.get_unique_id()
	_players[my_id] = info
	if multiplayer.is_server():
		_broadcast_player.rpc(my_id, info)
	else:
		_register_on_server.rpc_id(1, info)


@rpc("any_peer", "reliable")
func _register_on_server(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	_players[sender_id] = info
	EventBus.player_connected.emit(sender_id, info)
	_broadcast_player.rpc(sender_id, info)
	for peer_id: int in _players:
		if peer_id != sender_id:
			_broadcast_player.rpc_id(sender_id, peer_id, _players[peer_id])


@rpc("authority", "call_local", "reliable")
func _broadcast_player(peer_id: int, info: Dictionary) -> void:
	_players[peer_id] = info
	EventBus.player_connected.emit(peer_id, info)


@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	EventBus.game_started.emit()
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		pass


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		for station: Node in get_tree().get_nodes_in_group(&"stations"):
			if station.has_method(&"force_vacate") and station.has_method(&"get_occupant"):
				if station.get_occupant() == peer_id:
					station.force_vacate()
	_players.erase(peer_id)
	EventBus.player_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	register_player_local({"name": "Player", "role": "", "ready": false})
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()
