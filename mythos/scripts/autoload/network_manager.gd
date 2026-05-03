extends Node

signal connection_established()
signal connection_failed()
signal seed_exchange_complete(combined_seed: int)
signal opponent_disconnected()
signal action_received(action_type: String, args: Array)
signal checksum_mismatch(turn: int)

var is_online: bool = false
var local_player_index: int = 0
var local_seed: int = 0
var remote_seed: int = 0
var combined_seed: int = 0
var _seeds_received: int = 0
var pending_seed: int = 0

func get_opponent_index() -> int:
	return 1 - local_player_index

func is_local_turn() -> bool:
	if not is_online:
		return true
	return GameState.current_turn_player == local_player_index

func host_game(port: int = 7000) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	local_player_index = 0
	is_online = true
	return OK

func join_game(address: String, port: int = 7000) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	local_player_index = 1
	is_online = true
	return OK

func disconnect_game() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_online = false

func start_seed_exchange() -> void:
	local_seed = randi()
	_seeds_received = 0
	_receive_seed.rpc(local_seed)

func send_action(action_type: String, args: Array) -> void:
	if not is_online:
		return
	_receive_action.rpc(action_type, args)

func send_checksum(turn: int, hash_val: int) -> void:
	if not is_online:
		return
	_receive_checksum.rpc(turn, hash_val)

@rpc("any_peer", "reliable")
func _receive_seed(seed_value: int) -> void:
	remote_seed = seed_value
	_seeds_received += 1
	if _seeds_received >= 1:
		combined_seed = hash(str(mini(local_seed, remote_seed)) + str(maxi(local_seed, remote_seed)))
		pending_seed = combined_seed
		seed_exchange_complete.emit(combined_seed)

@rpc("any_peer", "reliable")
func _receive_action(action_type: String, args: Array) -> void:
	action_received.emit(action_type, args)

@rpc("any_peer", "reliable")
func _receive_checksum(turn: int, hash_val: int) -> void:
	var local_hash: int = GameState.compute_state_hash()
	if local_hash != hash_val:
		checksum_mismatch.emit(turn)

func _on_peer_connected(_id: int) -> void:
	EventBus.player_connected.emit(_id)

func _on_peer_disconnected(_id: int) -> void:
	if is_online:
		opponent_disconnected.emit()

func _on_connected() -> void:
	connection_established.emit()

func _on_connection_failed() -> void:
	connection_failed.emit()
