extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")

@onready var _ship: Node3D = $PlayerShip
@onready var _players_node: Node3D = $Players


func _ready() -> void:
	EventBus.player_disconnected.connect(_on_player_disconnected)

	if multiplayer.multiplayer_peer == null:
		_setup_standalone()

	if multiplayer.is_server():
		_spawn_players()
		multiplayer.peer_connected.connect(_on_late_peer_connected)


func _setup_standalone() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	peer.create_server(NetworkManager.DEFAULT_PORT)
	multiplayer.multiplayer_peer = peer


func _spawn_players() -> void:
	var peers: Array[int] = NetworkManager.get_player_peers()
	var spawn_points: Array[Marker3D] = _get_spawn_points()

	for i: int in peers.size():
		_spawn_player(peers[i], spawn_points, i)


func _spawn_player(peer_id: int, spawn_points: Array[Marker3D], index: int) -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)

	var spawn_idx: int = mini(index, spawn_points.size() - 1)
	_players_node.add_child(player, true)
	player.global_position = spawn_points[spawn_idx].global_position


func _get_spawn_points() -> Array[Marker3D]:
	return [
		_ship.get_node("SpawnPoints/PilotSpawn") as Marker3D,
		_ship.get_node("SpawnPoints/GungineerSpawn") as Marker3D,
	]


func _on_late_peer_connected(peer_id: int) -> void:
	if not NetworkManager.is_player_peer(peer_id):
		return
	var spawn_points: Array[Marker3D] = _get_spawn_points()
	var index: int = _players_node.get_child_count()
	_spawn_player(peer_id, spawn_points, index)


func _on_player_disconnected(peer_id: int) -> void:
	var player_node: Node = _players_node.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
