extends Node
## Net: an online duel over one MultiplayerPeer, made by a `NetTransport`. One process is the
## authority: it runs the only rules engine behind a `DuelHost`, hands each remote seat its own
## `SeatUpdate` (log lines, masked view, prompt) and takes their choices back as Commands.
##
## Every online duel is refereed on the duel server (mode "server"): both players connect out
## to it, one opens a room and gets a share code, the other joins with the code, and the server
## runs that room's duel with both seats remote. A hosting client (mode "host": seat 0 local,
## seat 1 over the wire) is the same authority code on a plain ENet port, kept for LAN dev runs.
## Clients (mode "client") hold no game state and learn their seat from the authority. The seed
## never leaves the authority.

signal lobby_changed
signal connected            # this client has its seat, or the authority got a peer
signal connection_failed(reason: String)
signal peer_left
signal command_received(seat: int, cmd: Dictionary)   # host: the remote seat asks to apply this
signal update_received(update: Dictionary)            # client: the authority's answer for our seat
signal command_rejected(reason: String)
signal room_started(code: String)                     # server: both seats locked, deal
signal room_command(code: String, seat: int, cmd: Dictionary)   # server: a seat's choice
signal room_closed(code: String)                      # server: a player left

const HOST_ID: int = 1      # the ENet server's multiplayer id, and always the authority

var mode: String = ""          # "" offline, "host", "client", "server"
var local_player: int = 0      # the seat this process plays; -1 on a server or before seating
## Host and client: multiplayer id serving each seat, 0 for this process, HOST_ID on a client for
## the other seat (clients only ever talk to the authority).
var seat_peer: Array[int] = [0, 0]
## Per seat: {"name": String, "deck": int (index into Session.decks, -1 none), "deck_name": String,
## "ready": bool (the seat locked its pick on the select screen)}
var lobby: Array[Dictionary] = []
var peer_id: int = 0            # host and client: the other side's multiplayer id, 0 until connected
var room_code: String = ""      # client of the server: the room this seat is in
var transport: NetTransport = null   # how the peer was made; null offline
var rooms: Dictionary = {}      # server: code -> DuelRoom
var _peer_room: Dictionary = {}   # server: peer id -> code
var _room_request: String = ""    # client: "" opens a room, a code joins one
var _via_server: bool = false     # client: talking to the duel server, not a hosting client
var _other_present: bool = false  # client: the other seat has a player behind it
var _pending_updates: Array[Dictionary] = []   # updates that arrived before the duel scene listened
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _log: bool = OS.get_cmdline_user_args().has("--dev-net-log")


func _ready() -> void:
	_rng.randomize()
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


func is_server() -> bool:
	return mode == "server"


## Whether the rules run in this process.
func is_authority() -> bool:
	return mode == "host" or mode == "server"


func remote_player() -> int:
	return 1 - local_player


## Seats served over the wire from a hosting client: [1]; none elsewhere (the server's are per room).
func remote_seats() -> Array[int]:
	var out: Array[int] = []
	if is_host():
		out.append(1)
	return out


## Both seats have a process behind them.
func seats_filled() -> bool:
	if mode == "client":
		return _other_present
	if is_host():
		return peer_id != 0
	return false


func reset_lobby() -> void:
	lobby = [
		{"name": "Player 1", "deck": -1, "deck_name": "", "ready": false},
		{"name": "Player 2", "deck": -1, "deck_name": "", "ready": false},
	]


## `--dev-net-log` prints connection stages to stdout.
func note(text: String) -> void:
	if _log:
		print("net: " + text)


## Where the duel server lives, from the project setting `zenith/net/duel_server`.
static func server_address() -> String:
	var out: String = str(ProjectSettings.get_setting("zenith/net/duel_server", "127.0.0.1:7777"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-server="):
			out = arg.get_slice("=", 1)
	return out


# --- Connection -----------------------------------------------------------

## Open a duel. `"server"` (the default) connects to the duel server and asks for a room; the
## share code arrives with `connected` and is in `join_code()`. `"lan"` hosts on a plain ENet
## port with the rules in this process, for dev runs. A coroutine; returns "" or a message.
func host(kind: String = "server") -> String:
	leave()
	if kind == "lan":
		transport = LanTransport.new()
		add_child(transport)
		var problem: String = await transport.host()
		if problem != "":
			leave()
			return problem
		mode = "host"
		local_player = 0
		seat_peer = [0, 0]
		reset_lobby()
		lobby[0]["name"] = Session.player_names[0]
		return ""
	return await _connect_to_server("")


## Join by what the host shared: a share code goes to the duel server; an address (host:port)
## connects straight to a hosting client, for dev runs. A coroutine. The outcome then comes
## through `connected` or `connection_failed`.
func join(code: String) -> String:
	leave()
	if LanTransport.looks_like_address(code):
		transport = LanTransport.new()
		add_child(transport)
		var problem: String = await transport.join(code)
		if problem != "":
			leave()
			return problem
		mode = "client"
		local_player = -1
		seat_peer = [HOST_ID, HOST_ID]
		reset_lobby()
		return ""
	return await _connect_to_server(code.strip_edges().to_upper())


func _connect_to_server(request: String) -> String:
	transport = LanTransport.new()
	add_child(transport)
	var problem: String = await transport.join(server_address())
	if problem != "":
		leave()
		return problem
	mode = "client"
	local_player = -1
	seat_peer = [HOST_ID, HOST_ID]
	_via_server = true
	_room_request = request
	reset_lobby()
	return ""


## The duel server itself: no seat of its own, many rooms. Returns "" or a message.
func serve(port: int) -> String:
	leave()
	var lan: LanTransport = LanTransport.new()
	lan.port = port
	lan.max_peers = 4095
	transport = lan
	add_child(lan)
	var problem: String = await lan.host()
	if problem != "":
		leave()
		return problem
	mode = "server"
	local_player = -1
	multiplayer.server_relay = false   # players never see or reach each other, only the server
	rooms.clear()
	_peer_room.clear()
	return ""


func join_code() -> String:
	if room_code != "":
		return room_code
	return transport.join_code if transport != null else ""


func hosting_text() -> String:
	if room_code != "":
		return "Share code  %s  with the other player." % room_code
	return transport.hosting_text() if transport != null else ""


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if transport != null:
		transport.close()
		transport.queue_free()
		transport = null
	mode = ""
	local_player = 0
	seat_peer = [0, 0]
	peer_id = 0
	room_code = ""
	_room_request = ""
	_via_server = false
	_other_present = false
	rooms.clear()
	_peer_room.clear()
	_pending_updates.clear()
	reset_lobby()


## A peer arrived. A hosting client seats it as player 2; the server waits for its room request.
func _on_peer_connected(id: int) -> void:
	note("peer %d connected" % id)
	if not is_host():
		return
	if peer_id != 0:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	peer_id = id
	seat_peer[1] = id
	_rpc_assign_seat.rpc_id(id, 1, "")
	_rpc_lobby.rpc_id(id, lobby, true)
	connected.emit()


## Host: the seat a remote sender plays, -1 for a stranger.
func seat_of(id: int) -> int:
	return 1 if is_host() and id == peer_id and id != 0 else -1


func _on_connected_to_server() -> void:
	peer_id = HOST_ID
	if _via_server:
		note("reached the duel server, asking for room '%s'" % _room_request)
		_rpc_room_request.rpc_id(HOST_ID, _room_request)
	else:
		note("connected to the host, waiting for a seat")


## The authority seats this client. From the server, `code` names the room.
@rpc("authority", "call_remote", "reliable")
func _rpc_assign_seat(seat: int, code: String) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or mode != "client":
		return
	local_player = seat
	seat_peer = [HOST_ID, HOST_ID]
	seat_peer[seat] = 0
	room_code = code
	note("seated as player %d%s" % [seat + 1, "" if code == "" else " in room " + code])
	_rpc_lobby_pick.rpc_id(HOST_ID, seat, -1, "", Session.player_names[seat], false)
	connected.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_room_failed(reason: String) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	leave()
	connection_failed.emit(reason)


func _on_connection_failed() -> void:
	note("connection failed")
	var reason: String = "The duel server did not answer." if _via_server else "No host answered."
	leave()
	connection_failed.emit(reason)


func _on_peer_disconnected(id: int) -> void:
	note("peer %d disconnected" % id)
	if is_server():
		_close_room_of(id)
		return
	if is_host() and id == peer_id:
		peer_id = 0
		seat_peer[1] = 0
		peer_left.emit()


func _on_server_disconnected() -> void:
	note("the authority disconnected")
	leave()
	peer_left.emit()


## Server: the other player in a room is told when one leaves, then the room goes.
@rpc("authority", "call_remote", "reliable")
func _rpc_seat_left(_seat: int) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	_other_present = false
	peer_left.emit()


# --- Rooms (server) -------------------------------------------------------

## A client asks for a room: "" opens a new one, a code joins an existing one.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_room_request(code: String) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	if not is_server() or _peer_room.has(id):
		return
	var room: DuelRoom = null
	if code == "":
		room = DuelRoom.new()
		room.code = DuelRoom.new_code(_rng)
		while rooms.has(room.code):
			room.code = DuelRoom.new_code(_rng)
		rooms[room.code] = room
	elif rooms.has(code):
		room = rooms[code]
	if room == null:
		_rpc_room_failed.rpc_id(id, "No duel with code %s is waiting." % code)
		return
	var seat: int = room.free_seat()
	if seat < 0 or room.started:
		_rpc_room_failed.rpc_id(id, "The duel with code %s is full." % code)
		return
	room.seat_peer[seat] = id
	_peer_room[id] = room.code
	note("room %s: peer %d takes seat %d" % [room.code, id, seat])
	_rpc_assign_seat.rpc_id(id, seat, room.code)
	for peer in room.seat_peer:
		if peer != 0:
			_rpc_lobby.rpc_id(peer, room.lobby, room.filled())
	connected.emit()


func _room_of(id: int) -> DuelRoom:
	return rooms.get(_peer_room.get(id, ""), null)


func _close_room_of(id: int) -> void:
	var room: DuelRoom = _room_of(id)
	if room == null:
		return
	var seat: int = room.seat_of(id)
	var other: int = room.other_peer(seat)
	if other != 0:
		_rpc_seat_left.rpc_id(other, seat)
		_peer_room.erase(other)
	_peer_room.erase(id)
	rooms.erase(room.code)
	note("room %s closed" % room.code)
	room_closed.emit(room.code)


## Server: deal a room whose seats are both locked. The seed stays here.
func _start_room(room: DuelRoom) -> void:
	if room.started or not room.both_locked():
		return
	for pick in room.lobby:
		if not valid_deck_pick(int(pick.get("deck", -1)), str(pick.get("deck_name", ""))):
			return
	room.started = true
	room.seed_value = _rng.randi_range(1, 2147483646)
	for peer in room.seat_peer:
		_rpc_start.rpc_id(peer, int(room.lobby[0]["deck"]), int(room.lobby[1]["deck"]),
			str(room.lobby[0]["deck_name"]), str(room.lobby[1]["deck_name"]),
			str(room.lobby[0]["name"]), str(room.lobby[1]["name"]))
	room_started.emit(room.code)


## Server: a room's DuelHost sends a remote seat its update through this, bound to the code.
func send_room_update(seat: int, update: Dictionary, code: String) -> void:
	var room: DuelRoom = rooms.get(code, null)
	if room != null and room.seat_peer[seat] != 0:
		_send_packed(room.seat_peer[seat], update)


func reject_room_command(seat: int, reason: String, code: String) -> void:
	var room: DuelRoom = rooms.get(code, null)
	if room != null and room.seat_peer[seat] != 0:
		_rpc_reject.rpc_id(room.seat_peer[seat], reason)


# --- Lobby ----------------------------------------------------------------

## The local seat picked a deck (index into Session.decks), changed its name, or locked in.
func set_local_pick(deck_index: int, player_name: String, ready: bool = false) -> void:
	if local_player < 0:
		return
	var deck_name: String = ""
	if deck_index >= 0 and deck_index < Session.decks.size():
		deck_name = Session.decks[deck_index].name
	_apply_pick(local_player, deck_index, deck_name, player_name, ready and deck_index >= 0)
	if is_host():
		if peer_id != 0:
			_rpc_lobby_pick.rpc_id(peer_id, local_player, deck_index, deck_name, player_name, ready)
	elif mode == "client":
		_rpc_lobby_pick.rpc_id(HOST_ID, local_player, deck_index, deck_name, player_name, ready)


func _apply_pick(seat: int, deck_index: int, deck_name: String, player_name: String, ready: bool) -> void:
	if seat < 0 or seat >= lobby.size() or not _valid_lobby_pick(deck_index, deck_name, ready):
		return
	lobby[seat] = {"name": player_name, "deck": deck_index, "deck_name": deck_name, "ready": ready}
	lobby_changed.emit()


## Authorities validate the shared catalog before accepting readiness or indexing a deck.
func valid_deck_pick(deck_index: int, deck_name: String) -> bool:
	return deck_index >= 0 and deck_index < Session.decks.size() \
		and Session.decks[deck_index].name == deck_name


func _valid_lobby_pick(deck_index: int, deck_name: String, ready: bool) -> bool:
	return valid_deck_pick(deck_index, deck_name) or (deck_index == -1 and deck_name == "" and not ready)


## A seat's pick. A hosting client takes it from its joiner, a client takes the other seat's
## from the authority, and the server files it in the sender's room, passes the room's lobby to
## the other player, and deals once both seats are locked.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_lobby_pick(seat: int, deck_index: int, deck_name: String, player_name: String, ready: bool) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if seat < 0 or seat > 1:
		return
	if is_server():
		var room: DuelRoom = _room_of(sender)
		if room == null or room.seat_of(sender) != seat or room.started:
			return
		if not _valid_lobby_pick(deck_index, deck_name, ready):
			_rpc_room_failed.rpc_id(sender, "The selected deck does not match the server's catalog (%s)." % deck_name)
			return
		room.lobby[seat] = {"name": player_name, "deck": deck_index, "deck_name": deck_name, "ready": ready and deck_index >= 0}
		var other: int = room.other_peer(seat)
		if other != 0:
			_rpc_lobby.rpc_id(other, room.lobby, true)
		if room.both_locked():
			_start_room(room)
		return
	if seat == local_player:
		return
	if is_host() and sender != peer_id:
		return
	if mode == "client" and sender != HOST_ID:
		return
	if not _valid_lobby_pick(deck_index, deck_name, ready):
		var reason: String = "The other side's deck list does not match this build (%s)." % deck_name
		if is_host():
			_rpc_room_failed.rpc_id(sender, reason)
		elif mode == "client":
			leave()
			connection_failed.emit(reason)
		return
	_apply_pick(seat, deck_index, deck_name, player_name, ready)


@rpc("authority", "call_remote", "reliable")
func _rpc_lobby(full: Array, filled: bool) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	for i in range(mini(2, full.size())):
		var entry: Dictionary = full[i]
		lobby[i] = {
			"name": str(entry.get("name", "")),
			"deck": int(entry.get("deck", -1)),
			"deck_name": str(entry.get("deck_name", "")),
			"ready": bool(entry.get("ready", false)),
		}
	_other_present = filled
	lobby_changed.emit()


func lobby_ready() -> bool:
	return seats_filled() and valid_deck_pick(int(lobby[0]["deck"]), str(lobby[0]["deck_name"])) \
		and valid_deck_pick(int(lobby[1]["deck"]), str(lobby[1]["deck_name"]))


## Both seats locked their picks, so both clients move to the versus screen.
func both_locked() -> bool:
	return lobby_ready() and bool(lobby[0]["ready"]) and bool(lobby[1]["ready"])


# --- Starting a duel ------------------------------------------------------

## Hosting client only. Rolls the seed unless Session has one and keeps it here; the joiner
## never sees it. On the server, rooms deal themselves once both seats lock.
func start_duel() -> void:
	if not is_host() or not both_locked():
		return
	if Session.seed_value == 0:
		Session.seed_value = randi_range(1, 2147483646)
	_rpc_start.rpc(int(lobby[0]["deck"]), int(lobby[1]["deck"]),
		str(lobby[0]["deck_name"]), str(lobby[1]["deck_name"]), str(lobby[0]["name"]), str(lobby[1]["name"]))


## Hosting client only. A fresh seed, same seats and decks.
func rematch() -> void:
	if not is_host():
		return
	Session.seed_value = 0
	start_duel()


## Hosting client only. Both clients return to the lobby.
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
			connection_failed.emit("The other side's deck list does not match this build (%s)." % names[i])
			return
		Session.chosen[i] = Session.decks[picks[i]]
	Session.player_names = [player0, player1]
	_pending_updates.clear()
	Session.go_to_duel()


@rpc("authority", "call_local", "reliable")
func _rpc_to_lobby() -> void:
	Session.go_to_select()


# --- During the duel ------------------------------------------------------

## Client: ask the authority to apply this choice.
func send_command(cmd: Dictionary) -> void:
	if mode == "client":
		_rpc_submit.rpc_id(HOST_ID, cmd)


## Hosting client: hand the joiner what it may see after a command.
func send_update(seat: int, update: Dictionary) -> void:
	if is_host() and seat == 1 and peer_id != 0:
		_send_packed(peer_id, update)


func reject_command(seat: int, reason: String) -> void:
	if is_host() and seat == 1 and peer_id != 0:
		_rpc_reject.rpc_id(peer_id, reason)


## Updates carry a whole masked view, tens of kilobytes uncompressed, so they travel zstd-packed.
func _send_packed(to: int, update: Dictionary) -> void:
	var raw: PackedByteArray = var_to_bytes(update)
	var packed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_ZSTD)
	note("update for peer %d: %d bytes, %d packed" % [to, raw.size(), packed.size()])
	_rpc_update.rpc_id(to, raw.size(), packed)


## Client: updates that arrived before the duel scene was listening.
func take_pending_updates() -> Array[Dictionary]:
	var out: Array[Dictionary] = _pending_updates
	_pending_updates = []
	return out


@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit(cmd: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if is_server():
		var room: DuelRoom = _room_of(sender)
		if room != null and room.started:
			room_command.emit(room.code, room.seat_of(sender), cmd)
		return
	var seat: int = seat_of(sender)
	if seat >= 0:
		command_received.emit(seat, cmd)


@rpc("authority", "call_remote", "reliable")
func _rpc_update(raw_size: int, packed: PackedByteArray) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	var raw: PackedByteArray = packed.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	var value: Variant = bytes_to_var(raw)
	if not (value is Dictionary):
		return
	var update: Dictionary = value
	note("update received, %d bytes" % raw.size())
	if update_received.get_connections().is_empty():
		_pending_updates.append(update)
	else:
		update_received.emit(update)


@rpc("authority", "call_remote", "reliable")
func _rpc_reject(reason: String) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	command_rejected.emit(reason)
