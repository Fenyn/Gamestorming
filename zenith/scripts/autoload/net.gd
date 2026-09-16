extends Node
## Net: online duel over ENet, one client hosting. The host runs the only rules engine, behind a
## Referee. The joiner never holds the game state: it sends its choices up as Commands and gets
## back its own SeatUpdate (log lines, its masked view, its prompt). Seat 0 is the host, seat 1
## the joiner. The seed stays on the host.

signal lobby_changed
signal connected            # the joiner reached the host, or the host got its peer
signal connection_failed(reason: String)
signal peer_left
signal command_received(cmd: Dictionary)      # host: the joiner asks to apply this
signal update_received(update: Dictionary)    # joiner: the host's answer for seat 1
signal command_rejected(reason: String)

const DEFAULT_PORT: int = 7777
const HOST_ID: int = 1

var mode: String = ""          # "" offline, "host", "client"
var local_player: int = 0
## Per seat: {"name": String, "deck": int (index into Session.decks, -1 none), "deck_name": String}
var lobby: Array[Dictionary] = []
var peer_id: int = 0            # the other side's multiplayer id, 0 until connected
var _pending_updates: Array[Dictionary] = []   # updates that arrived before the duel scene listened


func _ready() -> void:
	reset_lobby()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func active() -> bool:
	return mode != ""


func is_host() -> bool:
	return mode == "host"


func remote_player() -> int:
	return 1 - local_player


func reset_lobby() -> void:
	lobby = [
		{"name": "Player 1", "deck": -1, "deck_name": ""},
		{"name": "Player 2", "deck": -1, "deck_name": ""},
	]


# --- Connection -----------------------------------------------------------

func host(port: int = DEFAULT_PORT) -> String:
	leave()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, 1)
	if err != OK:
		return "Could not open port %d (%s)." % [port, error_string(err)]
	multiplayer.multiplayer_peer = peer
	mode = "host"
	local_player = 0
	reset_lobby()
	lobby[0]["name"] = Session.player_names[0]
	return ""


## `address` may carry a port as host:port.
func join(address: String) -> String:
	leave()
	var target: String = address.strip_edges()
	var port: int = DEFAULT_PORT
	if target.contains(":") and not target.begins_with("["):
		port = int(target.get_slice(":", 1))
		target = target.get_slice(":", 0)
	if target == "":
		target = "127.0.0.1"
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(target, port)
	if err != OK:
		return "Could not connect to %s:%d (%s)." % [target, port, error_string(err)]
	multiplayer.multiplayer_peer = peer
	mode = "client"
	local_player = 1
	reset_lobby()
	return ""


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = ""
	local_player = 0
	peer_id = 0
	_pending_updates.clear()
	reset_lobby()


func _on_peer_connected(id: int) -> void:
	if not is_host():
		return
	if peer_id != 0 and id != peer_id:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	peer_id = id
	_rpc_lobby.rpc_id(id, lobby)
	connected.emit()


func _on_connected_to_server() -> void:
	peer_id = HOST_ID
	_rpc_lobby_pick.rpc_id(HOST_ID, 1, -1, "", Session.player_names[1])
	connected.emit()


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit("No host answered.")


func _on_peer_disconnected(id: int) -> void:
	if id == peer_id:
		peer_id = 0
		peer_left.emit()


func _on_server_disconnected() -> void:
	leave()
	peer_left.emit()


# --- Lobby ----------------------------------------------------------------

## The local seat picked a deck (index into Session.decks) or changed its name.
func set_local_pick(deck_index: int, player_name: String) -> void:
	var deck_name: String = ""
	if deck_index >= 0 and deck_index < Session.decks.size():
		deck_name = Session.decks[deck_index].name
	_apply_pick(local_player, deck_index, deck_name, player_name)
	if peer_id != 0:
		_rpc_lobby_pick.rpc_id(peer_id, local_player, deck_index, deck_name, player_name)


func _apply_pick(seat: int, deck_index: int, deck_name: String, player_name: String) -> void:
	lobby[seat] = {"name": player_name, "deck": deck_index, "deck_name": deck_name}
	lobby_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_lobby_pick(seat: int, deck_index: int, deck_name: String, player_name: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != peer_id or seat != remote_player():
		return
	_apply_pick(seat, deck_index, deck_name, player_name)


@rpc("authority", "call_remote", "reliable")
func _rpc_lobby(full: Array) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	for i in range(mini(2, full.size())):
		var entry: Dictionary = full[i]
		lobby[i] = {
			"name": str(entry.get("name", "")),
			"deck": int(entry.get("deck", -1)),
			"deck_name": str(entry.get("deck_name", "")),
		}
	lobby_changed.emit()


func lobby_ready() -> bool:
	return peer_id != 0 and int(lobby[0]["deck"]) >= 0 and int(lobby[1]["deck"]) >= 0


# --- Starting a duel ------------------------------------------------------

## Host only. Rolls the seed unless Session has one and keeps it here; the joiner never sees it.
func start_duel() -> void:
	if not is_host() or not lobby_ready():
		return
	if Session.seed_value == 0:
		Session.seed_value = randi_range(1, 2147483646)
	_rpc_start.rpc(int(lobby[0]["deck"]), int(lobby[1]["deck"]),
		str(lobby[0]["deck_name"]), str(lobby[1]["deck_name"]), str(lobby[0]["name"]), str(lobby[1]["name"]))


## Host only. A fresh seed, same seats and decks.
func rematch() -> void:
	if not is_host():
		return
	Session.seed_value = 0
	start_duel()


## Host only. Both clients return to the lobby.
func back_to_lobby() -> void:
	if is_host():
		_rpc_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_start(deck0: int, deck1: int, name0: String, name1: String, player0: String, player1: String) -> void:
	var picks: Array[int] = [deck0, deck1]
	var names: Array[String] = [name0, name1]
	for i in range(2):
		if picks[i] < 0 or picks[i] >= Session.decks.size() or Session.decks[picks[i]].name != names[i]:
			leave()
			connection_failed.emit("The host's deck list does not match this build (%s)." % names[i])
			return
		Session.chosen[i] = Session.decks[picks[i]]
	Session.player_names = [player0, player1]
	_pending_updates.clear()
	Session.go_to_duel()


@rpc("authority", "call_local", "reliable")
func _rpc_to_lobby() -> void:
	Session.go_to_select()


# --- During the duel ------------------------------------------------------

## Joiner: ask the host to apply this choice.
func send_command(cmd: Dictionary) -> void:
	if peer_id != 0 and not is_host():
		_rpc_submit.rpc_id(HOST_ID, cmd)


## Host: hand the joiner what it may see after a command.
func send_update(update: Dictionary) -> void:
	if is_host() and peer_id != 0:
		_rpc_update.rpc_id(peer_id, update)


func reject_command(reason: String) -> void:
	if is_host() and peer_id != 0:
		_rpc_reject.rpc_id(peer_id, reason)


## Joiner: updates that arrived before the duel scene was listening.
func take_pending_updates() -> Array[Dictionary]:
	var out: Array[Dictionary] = _pending_updates
	_pending_updates = []
	return out


@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit(cmd: Dictionary) -> void:
	if not is_host() or multiplayer.get_remote_sender_id() != peer_id:
		return
	command_received.emit(cmd)


@rpc("authority", "call_remote", "reliable")
func _rpc_update(update: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	if update_received.get_connections().is_empty():
		_pending_updates.append(update)
	else:
		update_received.emit(update)


@rpc("authority", "call_remote", "reliable")
func _rpc_reject(reason: String) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	command_rejected.emit(reason)
