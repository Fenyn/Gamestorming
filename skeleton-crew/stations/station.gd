class_name Station
extends Node3D

signal occupied(peer_id: int)
signal vacated()

@export var station_id: String = ""
@export var station_type: InputContext.Mode = InputContext.Mode.TERMINAL

var _occupant_id: int = 0

@onready var _station_camera: Camera3D = $StationCamera
@onready var _stand_position: Marker3D = $StandPosition


func _ready() -> void:
	add_to_group(&"stations")


func is_occupied() -> bool:
	return _occupant_id != 0


func get_occupant() -> int:
	return _occupant_id


func get_station_camera() -> Camera3D:
	return _station_camera


func get_stand_position() -> Vector3:
	return _stand_position.global_position


@rpc("any_peer", "reliable")
func request_occupy(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _occupant_id != 0:
		return
	_occupant_id = peer_id
	_confirm_occupy.rpc(peer_id)


@rpc("authority", "call_local", "reliable")
func _confirm_occupy(peer_id: int) -> void:
	_occupant_id = peer_id
	EventBus.station_occupied.emit(station_id, peer_id)
	occupied.emit(peer_id)

	if peer_id == multiplayer.get_unique_id():
		var player: Player = _find_player(peer_id)
		if player:
			player.enter_station(self, _station_camera, station_type)
			player.global_position = get_stand_position()


@rpc("any_peer", "reliable")
func request_vacate(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _occupant_id != peer_id:
		return
	_occupant_id = 0
	_confirm_vacate.rpc(peer_id)


@rpc("authority", "call_local", "reliable")
func _confirm_vacate(peer_id: int) -> void:
	_occupant_id = 0
	EventBus.station_vacated.emit(station_id)
	vacated.emit()

	if peer_id == multiplayer.get_unique_id():
		var player: Player = _find_player(peer_id)
		if player:
			player.exit_station()


func force_vacate() -> void:
	if _occupant_id == 0:
		return
	var old_occupant: int = _occupant_id
	_occupant_id = 0
	EventBus.station_vacated.emit(station_id)
	vacated.emit()


func _find_player(peer_id: int) -> Player:
	var players_node: Node = get_tree().get_first_node_in_group(&"players_container")
	if not players_node:
		var root: Node = get_tree().current_scene
		players_node = root.get_node_or_null("Players")
	if players_node:
		var player_node: Node = players_node.get_node_or_null(str(peer_id))
		if player_node is Player:
			return player_node as Player
	return null
