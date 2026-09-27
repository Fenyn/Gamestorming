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
## leaves the duel server only inside the match record each seat gets once the game's result is
## written, never during the game.
##
## A connection starts with a greeting on the MultiplayerAPI's auth channel: the client sends
## `PROTOCOL`, `catalog_fingerprint()` and a ticket with this install's public key (`Identity`),
## and the authority refuses a mismatch with a reason before any RPC can reach it. The duel server
## then sends a nonce, the client signs it (`challenge_bytes`), and only a good signature lets the
## peer in, its identity kept for every seat it takes. The greeting does not depend on the RPC
## table, so two builds that disagree about RPCs can still tell each other why they cannot play.
##
## The duel server's ENet host runs DTLS with its own self-signed certificate, and a client
## accepts only the certificate pinned in `zenith/net/duel_server_cert`. The LAN dev path stays on
## plain ENet.
##
## A server duel survives a dropped connection. The server keeps the seat for REJOIN_GRACE_MS with
## its clock running, and the client comes back with the seat's token from its `RejoinFile`
## (`rejoin()`), gets `_rpc_resume` and one catch-up update, and plays on. A cut-off player who
## gives up instead concedes with the same token, without taking the seat back (`give_up()`).
##
## Find a duel (`find_duel()`) puts the client in the server's one queue (`MatchQueue`). The two who
## have waited longest are paired into a queue room: both land on the select screen with
## QUEUE_PICK_MS to lock in, and the server deals QUEUE_BEAT_MS after both have. A player who leaves
## before the deal sends the other back to the front of the queue.
##
## Ranked (`find_ranked()`) is a second queue that pairs on rating (`MatchQueue.rated`) into a
## best-of-3 match on the two locked decks. Between games the room waits NEXT_GAME_MS, or until both
## players are ready, and the loser of the last game opens the next. The match is rated once, when
## it is decided (`Rating`, `RatingsStore`). A player who leaves a queue duel, or dodges a ranked
## matchup, is kept out of both queues for a while (`Conduct`).

signal lobby_changed
signal connected            # this client has its seat, or the authority got a peer
## This process lost or was refused its connection. Net has already left, and `last_error` holds
## the same reason for the title screen.
signal connection_failed(reason: String)
## The other seat's player left. This process is still connected and keeps its seat.
signal peer_left
signal command_received(seat: int, cmd: Dictionary)   # host: the remote seat asks to apply this
signal update_received(update: Dictionary)            # client: the authority's answer for our seat
signal command_rejected(reason: String)
## The duel ended outside the rules: "concede" (the other seat gave up, this game or the whole
## match), "timeout" (a seat's timer and bank ran out), "left" (a seat whose connection dropped did
## not come back in time), or "abandoned" with `winner_seat` -1 (both ran out at the same moment).
## A duel the rules finish ends through its update's game_over line instead. `last_duel_ended`
## keeps it.
signal duel_ended(winner_seat: int, reason: String)
## Server room: the other seat's connection dropped mid-duel. The server keeps the seat for
## `grace_ms`, and `away_left_ms(seat)` counts it down.
signal peer_away(seat: int, grace_ms: int)
## Server room: the other seat is back in the duel.
signal peer_back(seat: int)
## Server room: a seat's decision clock (`DuelClock.state`), time left rather than a wall time.
## `phase` is "off", "run", "warn" (the timer's last 10 s) or "bank".
signal clock_changed(seat: int, left_ms: int, bank_ms: int, phase: String)
## Server room: the other seat asked for a rematch; the server deals it once this seat asks too.
signal rematch_requested(seat: int)
signal room_started(code: String)                     # server: both seats locked and saw the matchup, deal
signal room_command(code: String, seat: int, cmd: Dictionary)   # server: a seat's choice
## Server: a room's duel ended outside the rules ("concede", "left" when a seat dropped and did not
## come back, "timeout", or "abandoned" with `winner_seat` -1).
signal room_ended(code: String, winner_seat: int, reason: String)
signal room_closed(code: String)                      # server: the room is gone
signal room_prompt_shown(code: String, seat: int, kind: String)   # server: a seat's decision panel is up
## Server: a seat's connection dropped mid-duel and the room keeps it; `both` when the other seat
## is away too, so both clocks stop.
signal room_seat_away(code: String, seat: int, both: bool)
## Server: an away seat is back; `both` when both were away, so both clocks go on.
signal room_rejoined(code: String, seat: int, both: bool)
signal presence_received(state: Dictionary)           # host and client: the other player's sanitised presence
## Client in the queue: `queue_state` changed. `state` is "queued", "requeued" (the other player
## left before the deal, and this client is back in line and on the title, `queue_since` set back
## to its first join) or "picking" (paired, and the select screen is loading); `reason` is the
## server's line for the player, or "".
signal queue_changed(state: String, reason: String)
## Client, ranked: a game of the match is over and the match is not. `wins` is games won per seat,
## and the server deals the next game in `next_in_s` seconds, or sooner once both players have
## called `next_game_ready()`. `last_game_over` keeps it.
signal game_over(game: int, wins: Array, next_in_s: int)
## Client, ranked: the match is decided. `payload` holds "winner" (seat, -1 for none), "wins",
## "reason" (what ended the match: a result reason, or "concede_match" when a player conceded the
## whole match), "rated", "shown_before", "shown_after" and "provisional" (per seat), and this
## seat's own "rating_before" and "rating_after" ({"mu", "sigma"}). `last_match` keeps it.
signal match_over(payload: Dictionary)
## Client of the server: this install's ranked rating as players see it, after the greeting and
## after each match.
signal rating_known(shown: int, provisional: bool)

## Bump this whenever an RPC is added, removed or renamed, an RPC's arguments or their meaning
## change, or the room flow changes. Builds on different numbers refuse each other at the greeting.
const PROTOCOL: int = 9
const HOST_ID: int = 1      # the ENet server's multiplayer id, and always the authority
## The duel server's greeting challenge, spent on the first proof that comes back for it.
const NONCE_BYTES: int = 32
## Presence rides its own unreliable channel so it never holds up or reorders commands and updates.
const PRESENCE_CHANNEL: int = 1
## The most presence messages a relay passes on from one peer in a second; a client sends at
## most 20.
const PRESENCE_PER_SECOND: int = 40
## From pressing Host or Join to holding a seat. Also the greeting's limit on both sides.
const CONNECT_TIMEOUT_SECONDS: float = 10.0
## Server: how long a connected peer may go without a room before it is dropped.
const UNSEATED_SECONDS: float = 20.0
const NAME_MAX: int = 20
const HELLO_MAX_BYTES: int = 1024
const COMMAND_KEYS: Array[String] = ["player", "type", "card", "value"]
const COMMAND_STRING_MAX: int = 64
const COMMAND_ARRAY_MAX: int = 128
## Client: an update's unpacked size is refused above this; real ones are about 70 KB.
const UPDATE_MAX_BYTES: int = 4 * 1024 * 1024
## A match record on the wire, as UTF-8 JSON. Real ones are under 30 KB; the server does not send
## a larger one and a client refuses it.
const RECORD_MAX_BYTES: int = 1024 * 1024
const SERVER_UNREACHABLE: String = "Could not reach the duel server. It may be offline, or this computer may not be connected."
const CODE_FORMAT: String = "Share codes are five letters or digits, like K7QMR."
## Server: how long a seat whose connection dropped is kept, and how long a duel with both seats
## away waits before it ends with no winner.
const REJOIN_GRACE_MS: int = 90000
const TOKEN_BYTES: int = 32
## ENet drops a peer that has not acknowledged traffic for this long (ms). Its default is 30 s.
const PEER_TIMEOUT_LIMIT: int = 32
const PEER_TIMEOUT_MIN_MS: int = 5000
const PEER_TIMEOUT_MAX_MS: int = 10000
## Client: the rejoin file's expiry is moved on at most this often (ms) while updates arrive.
const REJOIN_RENEW_MS: int = 30000
const REJOIN_GONE: String = "That duel is no longer on the server. It may have restarted."
const REJOIN_OVER: String = "That duel has ended."
const STILL_CONNECTED: String = "The duel server still has your old connection."
const SEAT_ELSEWHERE: String = "That seat belongs to another copy of the game."
const NO_KEY: String = "The greeting did not carry this copy of the game's key. It is probably a different version from the duel server."
const BAD_PROOF: String = "The duel server could not confirm this copy of the game's key. Try again, and if it keeps happening, delete identity.key from the game's data folder."
const CERT_MISSING: String = "This copy of the game is missing the duel server's certificate, so it cannot connect safely."
const CERT_MISMATCH: String = "The duel server's certificate is not the one this copy of the game trusts. It may be a different server, or this copy may be out of date."
## Client: how long a give-up from a cut-off seat keeps trying to reach the server, and the wait
## after a "still connected" answer.
const GIVE_UP_WINDOW_MS: int = 20000
const GIVE_UP_RETRY_MS: int = 3000
## Queue room: how long both seats have to lock in from the pairing, and the matchup both see
## between the lock and the deal.
const QUEUE_PICK_MS: int = 60000
const QUEUE_BEAT_MS: int = 5000
## Server: a player still waiting after this is dropped from the queue.
const QUEUE_MAX_WAIT_MS: int = 30 * 60 * 1000
## Client: the searching title says nobody else is looking after this.
const QUEUE_NOTICE_MS: int = 90000
## Client: the longest leaver cooldown a queue refusal can carry, the top of `Conduct.LADDER_S`.
const COOLDOWN_MAX_MS: int = 60 * 60 * 1000
const QUEUE_OTHER_LEFT: String = "The other player left. Looking again."
const QUEUE_OTHER_LATE: String = "The other player did not lock in a deck. Looking again."
const QUEUE_LATE: String = "You did not lock in a deck in time."
const QUEUE_NO_OPPONENT: String = "No opponent found. Try again later."
const QUEUE_FULL: String = "The server is full. Still looking."
const QUEUE_NOBODY: String = "Nobody else is looking right now."
const QUEUE_COOLDOWN: String = "You can look for a duel again in %s."
const QUEUE_WARNED: String = "You left a match recently. Leaving another before a day has passed keeps you out of the queue for %d minutes."
const QUEUE_NEEDS_KEY: String = "Ranked play needs this copy of the game's key."
const QUEUE_MODES: Array[String] = ["casual", "ranked"]
const RANKED_BEST_OF: int = 3
## Ranked: between two games of a match, the next is dealt after this unless both are ready sooner.
const NEXT_GAME_MS: int = 20000
## Ranked: a game ending with one of these ends the match, whatever the score.
const MATCH_ENDERS: Array[String] = ["left", "timeout", "abandoned"]
const NEXT_GAME: String = "The next game of your match is being dealt."

var mode: String = ""          # "" offline, "host", "client", "server"
var local_player: int = 0      # the seat this process plays; -1 on a server or before seating
## Host and client: multiplayer id serving each seat, 0 for this process, HOST_ID on a client for
## the other seat (clients only ever talk to the authority).
var seat_peer: Array[int] = [0, 0]
## Per seat: {"name": String, "deck": int (index into Session.decks, -1 none), "deck_name": String,
## "ready": bool (the seat locked its pick on the select screen)}. A client sees the other seat's
## deck only once both seats have locked.
var lobby: Array[Dictionary] = []
var peer_id: int = 0            # host and client: the other side's multiplayer id, 0 until connected
var room_code: String = ""      # client of the server: the room this seat is in
var transport: NetTransport = null   # how the peer was made; null offline
var rooms: Dictionary = {}      # server: code -> DuelRoom
## Why the last online attempt or connection ended. The title shows it once and clears it.
var last_error: String = ""
## A line for the lobby about the other seat, "" for none: who left and whether the code still works.
var lobby_notice: String = ""
## Server: how long a room may hold a single player before it closes (`--room-idle=N` seconds).
var room_idle_seconds: float = 600.0
## Server: Find a duel's waiting line.
var queue: MatchQueue = MatchQueue.new()
## Server: the ranked waiting line, paired on mu.
var ranked_queue: MatchQueue = _rated_queue()
## Server: ranked ratings and the leaver record, opened by the server scene; null elsewhere, when
## ranked plays unrated and nobody is held out of the queue.
var ratings: RatingsStore = null
var conduct: Conduct = null
## Client, ranked: the game of the match being played or just over, and games won per seat.
var series_game: int = 0
var series_wins: Array[int] = [0, 0]
## Client, ranked between games: ticks msec at which the server deals the next game, 0 otherwise.
var next_game_at: int = 0
## Client of the server: this install's ranked rating as the server last sent it, {"shown",
## "provisional", "mu", "sigma"}; {} before it has.
var rating: Dictionary = {}
## Server: the most duels running or about to be dealt from the queue; at the cap the queue holds
## pairs back. 0 for no cap. The server scene sets it.
var max_live_duels: int = 0
## Client, Find a duel: "" outside the queue, "connecting", "queued" (waiting, on the title),
## "picking" (paired, on the select screen), "matchup" (both locked, the server deals at `deal_at`)
## or "duel".
var queue_state: String = ""
## Client: the server's last line about this client's place in the queue, "" for none.
var queue_reason: String = ""
## Client: ticks msec this client started waiting, for the searching title's count. A re-queue sets
## it back to the first join, from the wait the server counted.
var queue_since: int = 0
## Client: ticks msec at which the leaver cooldown the server last refused a queue join for ends, 0
## for none. `leave()` keeps it; the server taking a queue join clears it. `cooldown_left_ms()`
## counts it down.
var cooldown_until_msec: int = 0
## Client of the server: the last facts a scene may need after their signal has gone, for a scene
## built later. `last_match` is the last `match_over` payload. `last_game_over` is the last
## `game_over`, {"game", "wins", "next_in_s", "at_msec"} (`at_msec` the ticks it arrived at).
## `last_duel_ended` is the last `duel_ended`, {"winner", "reason"}. Only the next deal or resume
## and a new queue join clear them; `leave()` and a dropped connection keep them.
var last_match: Dictionary = {}
var last_game_over: Dictionary = {}
var last_duel_ended: Dictionary = {}
## Client in a queue room: ticks msec by which this seat must lock in, and at which the server deals.
var pick_until: int = 0
var deal_at: int = 0
var _peer_room: Dictionary = {}   # server: peer id -> code
var _unseated: Dictionary = {}    # server: peer id -> ticks msec by which it must be in a room
var _refused: Dictionary = {}     # server: peers turned away once; their further requests are ignored
var _room_request: String = ""    # client: "" opens a room, a code joins one
var _queue_request: bool = false  # client: this connection asks for the queue, not a room
var _queue_ranked: bool = false   # client: the queue asked for is the ranked one
var _room_kind: String = ""       # client: the `DuelRoom.kind` of this seat's room, "" outside one
var _ranked: bool = false         # client: this seat's room plays a ranked match
var _match_over: bool = false     # client, ranked: the server said the match is decided
var _via_server: bool = false     # client: talking to the duel server, not a hosting client
var _other_present: bool = false  # client: the other seat has a player behind it
var _pending_updates: Array[Dictionary] = []   # updates that arrived before the duel scene listened
var _hold_updates: bool = false   # client: a deal arrived, so updates wait for the new duel scene
var _in_duel: bool = false        # host and client: a started duel is on the table
var _duel_over: bool = false      # hosting client: the duel ended outside the rules
var _stage: String = ""           # client while connecting: "connecting", "greeting", "seat"
var _connect_deadline: int = 0    # client: ticks msec at which connecting gives up, 0 when not connecting
var _next_sweep: int = 0
var _catalog: String = ""
var _presence_heard: Dictionary = {}   # peer id -> [window start msec, messages in that window]
var _crypto: Crypto = Crypto.new()
var _log: bool = DevArgs.user_args().has("--dev-net-log")
## Client: the duel scene now loading continues a duel this client rejoined, not a new deal.
var resumed: bool = false
var _rejoin: Dictionary = {}          # client: the `RejoinFile` ticket this connection asks back for
var _server_address: String = ""      # client: the duel server this connection went to
var _away_until: Array[int] = [0, 0]  # client: per seat, ticks msec until the server gives up on it, 0 while here
var _renewed_at: int = 0              # client: when the rejoin file's expiry last moved
## Client: a cut-off seat's concession travels on a short connection of its own, which `leave()`
## does not touch, since the screens that ask for it leave the main connection straight away.
var _courier: SceneMultiplayer = null
var _courier_ticket: Dictionary = {}  # the seat it concedes, {} when none is on its way
var _courier_until: int = 0           # ticks msec after which it stops trying
var _courier_next: int = 0            # ticks msec of the next attempt, 0 while one is under way
var _courier_done: bool = false       # the attempt under way has its answer; dropped after this poll
var _gave_up_peers: Dictionary = {}   # server: peers whose greeting was a give-up that got its answer
var _identity: Identity = null        # this install's, loaded the first time a greeting needs it
## Server, per peer id mid-greeting: {"nonce", "public", "identity"} (plus "give_up" on a courier)
## while its proof is awaited, or false once the greeting was refused.
var _greeting: Dictionary = {}
var _peer_identity: Dictionary = {}   # server: peer id -> identity id, from a proven greeting
var _dtls: bool = false               # server: its ENet host runs DTLS
## Client of the server: a DTLS handshake of its own beside the ENet one, since ENet does not say
## why a handshake failed. Its verdict tells a certificate that is not the pinned one from a server
## out of reach.
var _cert_probe: PacketPeerDTLS = null
## Tests: when set, every message `_tell` would send goes here as (peer, method, args) instead of
## onto the wire, connected or not.
var _outbox: Callable = Callable()
## Tests: when set, every server journal line also goes here.
var _journal: Callable = Callable()


func _ready() -> void:
	reset_lobby()
	var api: SceneMultiplayer = multiplayer as SceneMultiplayer
	api.auth_callback = _on_auth
	api.auth_timeout = CONNECT_TIMEOUT_SECONDS
	api.peer_authenticating.connect(_on_peer_authenticating)
	api.peer_authentication_failed.connect(_on_authentication_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if _connect_deadline > 0 and now >= _connect_deadline:
		_fail(_timeout_reason())
	elif is_server() and now >= _next_sweep:
		_next_sweep = now + 1000
		sweep(now)
	if _cert_probe != null:
		_poll_cert_probe()
	_run_courier(now)


func active() -> bool:
	return mode != ""


func is_host() -> bool:
	return mode == "host"


func is_server() -> bool:
	return mode == "server"


## Whether the rules run in this process.
func is_authority() -> bool:
	return mode == "host" or mode == "server"


## This client plays in a room on the duel server.
func server_room() -> bool:
	return mode == "client" and _via_server and room_code != ""


## This client plays in a room Find a duel paired it into.
func queue_room() -> bool:
	return server_room() and _room_kind == "queue"


## This client plays a ranked match, in a queue room from the ranked queue.
func ranked_room() -> bool:
	return server_room() and _ranked


## Whether this process can ask for a rematch or a return to the lobby: either seat of a server
## room that is not ranked, or a hosting client. A LAN joiner leaves those to its host.
func can_rematch() -> bool:
	return is_host() or (server_room() and not _ranked)


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
	lobby = [DuelRoom.empty_pick(0), DuelRoom.empty_pick(1)]


## `--dev-net-log` prints connection stages to stdout.
func note(text: String) -> void:
	if _log:
		print("net: " + text)


## The server's journal: always printed there. Elsewhere only with `--dev-net-log`.
func _server_log(text: String) -> void:
	if _journal.is_valid():
		_journal.call(text)
	if is_server():
		print(text)
	else:
		note(text)


## Where the duel server lives, from the project setting `zenith/net/duel_server`.
static func server_address() -> String:
	var out: String = str(ProjectSettings.get_setting("zenith/net/duel_server", "127.0.0.1:7777"))
	for arg in DevArgs.user_args():
		if arg.begins_with("--dev-server="):
			out = arg.get_slice("=", 1)
	return out


## The duel server's certificate this client pins, from the project setting
## `zenith/net/duel_server_cert`; `--dev-server-cert=<path>` overrides it in a debug build. Empty
## means plain ENet, which only a server started with `--no-dtls` answers.
static func server_cert_path() -> String:
	var out: String = str(ProjectSettings.get_setting("zenith/net/duel_server_cert", ""))
	for arg in DevArgs.user_args():
		if arg.begins_with("--dev-server-cert="):
			out = arg.substr("--dev-server-cert=".length())
	return out


## The pinned certificate, or null when none is set or the file is not a certificate.
static func pinned_certificate() -> X509Certificate:
	var path: String = server_cert_path()
	if path == "" or not FileAccess.file_exists(path) \
			or not FileAccess.get_file_as_bytes(path).get_string_from_ascii().begins_with("-----BEGIN CERTIFICATE-----"):
		return null
	var cert: X509Certificate = X509Certificate.new()
	return cert if cert.load(path) == OK else null


## Client: DTLS that accepts only the pinned certificate, under the name of the host `address`
## dials. Null for plain ENet, and when the certificate cannot be read (`CERT_MISSING`).
static func server_tls(address: String) -> TLSOptions:
	var cert: X509Certificate = pinned_certificate()
	if cert == null:
		return null
	return TLSOptions.client(cert, str(LanTransport.split_address(address)[0]))


## A name as it may travel and reach a log: no BBCode brackets or control characters, at most
## `NAME_MAX` characters, and the seat's stock name when nothing is left.
static func clean_name(raw: String, seat: int) -> String:
	var out: String = ""
	for ch in raw.left(NAME_MAX * 4):
		var code: int = ch.unicode_at(0)
		if ch == "[" or ch == "]" or code < 32 or code == 127:
			continue
		out += ch
	out = out.strip_edges().left(NAME_MAX).strip_edges()
	return out if out != "" else "Player %d" % (seat + 1)


## Why `code` cannot be joined, or "" when it is worth trying: a share code, or in a debug build
## an address (the LAN dev path).
static func code_problem(code: String) -> String:
	var c: String = code.strip_edges()
	if c == "":
		return "Type the share code the host gave you."
	if LanTransport.looks_like_address(c):
		return "" if OS.is_debug_build() else CODE_FORMAT
	return "" if DuelRoom.valid_code(c.to_upper()) else CODE_FORMAT


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
		lobby[0]["name"] = clean_name(Session.player_names[0], 0)
		Session.roll_colors()   # the authority owns the seat colours and shares them
		return ""
	return await _connect_to_server("")


## Join by what the host shared: a share code goes to the duel server; an address (host:port)
## connects straight to a hosting client, for dev runs. A coroutine returning "" or a message.
## The outcome then comes through `connected` or `connection_failed`.
func join(code: String) -> String:
	var refused: String = code_problem(code)
	if refused != "":
		return refused
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
		_begin_connecting()
		return ""
	return await _connect_to_server(code.strip_edges().to_upper())


## Find a duel: wait in the duel server's queue for the next player looking. From a finished duel
## still connected (Find another duel) the request goes out on that connection and the server lets
## the old room go first; otherwise this connects afresh. A coroutine returning "" or a message.
## The server's answers arrive through `queue_changed`, a pairing also loads the select screen, and
## a drop from the queue comes through `connection_failed`. `leave()` cancels.
func find_duel() -> String:
	return await _find(false)


## Ranked: as `find_duel`, into the ranked queue, which pairs on rating into a best-of-3 match.
func find_ranked() -> String:
	return await _find(true)


func _find(ranked: bool) -> String:
	_forget_results()
	if server_room() and multiplayer.get_peers().has(HOST_ID):
		_forget_room()
		_queue_ranked = ranked
		queue_state = "queued"
		queue_reason = ""
		queue_since = Time.get_ticks_msec()
		note("asking the duel server for another %s" % ("ranked match" if ranked else "duel"))
		_rpc_queue_join.rpc_id(HOST_ID, queue_ticket(ranked))
		return ""
	leave()
	_queue_request = true
	_queue_ranked = ranked
	queue_state = "connecting"
	return await _connect_to_server("")


## Client: the last result facts go, at a new queue join and at each deal or resume.
func _forget_results() -> void:
	last_match = {}
	last_game_over = {}
	last_duel_ended = {}


## Client: this seat's room is behind it and the connection stays open.
func _forget_room() -> void:
	room_code = ""
	_room_kind = ""
	_ranked = false
	_match_over = false
	series_game = 0
	series_wins = [0, 0]
	next_game_at = 0
	local_player = -1
	seat_peer = [HOST_ID, HOST_ID]
	lobby_notice = ""
	_other_present = false
	_pending_updates.clear()
	_hold_updates = false
	_in_duel = false
	_duel_over = false
	_away_until = [0, 0]
	resumed = false
	pick_until = 0
	deal_at = 0
	reset_lobby()


func _connect_to_server(request: String, address: String = "") -> String:
	var where: String = address if address != "" else server_address()
	var tls: TLSOptions = server_tls(where)
	if tls == null and server_cert_path() != "":
		leave()
		return CERT_MISSING
	identity()
	var lan: LanTransport = LanTransport.new()
	lan.tls = tls
	transport = lan
	add_child(lan)
	var problem: String = await transport.join(where)
	if problem != "":
		leave()
		return problem
	if tls != null:
		_start_cert_probe(where, tls)
	mode = "client"
	local_player = -1
	seat_peer = [HOST_ID, HOST_ID]
	_via_server = true
	_server_address = where
	_room_request = request
	reset_lobby()
	_begin_connecting()
	return ""


func _start_cert_probe(address: String, tls: TLSOptions) -> void:
	var where: Array = LanTransport.split_address(address)
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	var probe: PacketPeerDTLS = PacketPeerDTLS.new()
	if udp.connect_to_host(str(where[0]), int(where[1])) == OK and probe.connect_to_peer(udp, str(where[0]), tls) == OK:
		_cert_probe = probe


## Client: the certificate check's verdict. A certificate that is not the pinned one fails the
## connection with CERT_MISMATCH, whatever ENet made of it. A good one lets the connection go on,
## or fails it as out of reach when ENet has already given up (stage "certificate").
func _poll_cert_probe() -> void:
	_cert_probe.poll()
	var status: PacketPeerDTLS.Status = _cert_probe.get_status()
	if status == PacketPeerDTLS.STATUS_HANDSHAKING:
		return
	_drop_cert_probe()
	if status == PacketPeerDTLS.STATUS_ERROR or status == PacketPeerDTLS.STATUS_ERROR_HOSTNAME_MISMATCH:
		_fail(CERT_MISMATCH)
	elif _stage == "certificate":
		_fail(SERVER_UNREACHABLE)
	else:
		note("the duel server's certificate is the pinned one")


func _drop_cert_probe() -> void:
	if _cert_probe != null and _cert_probe.get_status() == PacketPeerDTLS.STATUS_CONNECTED:
		_cert_probe.disconnect_from_peer()
	_cert_probe = null


## Ask the duel server for this client's seat back in the duel its `RejoinFile` names, on the
## server that runs it. The duel scene loads on `_rpc_resume`; anything else comes back through
## `connection_failed`, and a refusal deletes the file first. A coroutine returning "" or a message.
func rejoin() -> String:
	var ticket: Dictionary = RejoinFile.read()
	if not RejoinFile.live(ticket, int(Time.get_unix_time_from_system())):
		RejoinFile.clear()
		return REJOIN_OVER
	leave()
	_rejoin = ticket
	return await _connect_to_server("", str(ticket["server"]))


## Whether this client holds a seat it can ask back for: an unexpired rejoin file, for the room
## `code` when one is given.
func can_rejoin(code: String = "") -> bool:
	var ticket: Dictionary = RejoinFile.read()
	return RejoinFile.live(ticket, int(Time.get_unix_time_from_system())) and (code == "" or str(ticket["code"]) == code)


## Forget the seat in a server duel, which is over for this client. A ranked match keeps it until
## the match is decided, since its next game is dealt to the same seat.
func forget_rejoin() -> void:
	if ranked_room() and not _match_over:
		return
	RejoinFile.clear()


## Give up a server duel, conceded on the spot while the connection holds; in a ranked match that
## gives up the whole match, which ends "concede_match". Cut off, the seat's rejoin file goes at once
## and the concession travels on a connection of its own (`_send_give_up`), which a `leave()`
## straight after does not stop; the server concedes a ranked seat's whole match from it too. True
## when the concession went out on the live connection.
func give_up() -> bool:
	if ranked_room() and not _match_over:
		leave_match()
		return true
	if server_room() and _in_duel and not _duel_over:
		concede()
		return true
	var ticket: Dictionary = RejoinFile.read()
	RejoinFile.clear()
	if RejoinFile.live(ticket, int(Time.get_unix_time_from_system())):
		_send_give_up(ticket)
	return false


## Client: concede the duel `ticket` names without taking its seat back. The server hears it in the
## greeting of a short connection of its own and ends the duel as a concession. With the server out
## of reach, or no answer within GIVE_UP_WINDOW_MS, the duel ends once the seat's time runs out.
func _send_give_up(ticket: Dictionary) -> void:
	_drop_courier()
	_courier_ticket = ticket
	_courier_until = Time.get_ticks_msec() + GIVE_UP_WINDOW_MS
	_courier_next = Time.get_ticks_msec()


## Every frame: polls the give-up connection, drops it once answered or out of time, and opens the
## next attempt when one is due.
func _run_courier(now: int) -> void:
	if _courier != null:
		_courier.poll()
		if _courier_done or now >= _courier_until:
			if not _courier_done:
				note("give-up for room %s had no answer" % str(_courier_ticket.get("code", "")))
				_courier_ticket = {}
			_drop_courier()
	elif not _courier_ticket.is_empty() and _courier_next > 0 and now >= _courier_next:
		_courier_next = 0
		_courier_connect()


## The give-up connection goes over DTLS to the pinned certificate, as the duel's own did.
func _courier_connect() -> void:
	var address: String = str(_courier_ticket["server"])
	var where: Array = LanTransport.split_address(address)
	var tls: TLSOptions = server_tls(address)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var opened: bool = (tls != null or server_cert_path() == "") and peer.create_client(str(where[0]), int(where[1])) == OK
	if opened and tls != null and peer.host.dtls_client_setup(str(where[0]), tls) != OK:
		peer.close()
		opened = false
	if not opened:
		note("give-up for room %s could not connect" % str(_courier_ticket["code"]))
		_courier_ticket = {}
		return
	_courier = SceneMultiplayer.new()
	_courier_done = false
	_courier.auth_timeout = CONNECT_TIMEOUT_SECONDS
	_courier.auth_callback = _courier_auth
	_courier.peer_authenticating.connect(_on_courier_greeting)
	_courier.peer_authentication_failed.connect(func(_id: int) -> void: _courier_heard({}))
	_courier.connection_failed.connect(func() -> void: _courier_heard({}))
	_courier.multiplayer_peer = peer


func _on_courier_greeting(id: int) -> void:
	if _courier == null or _courier_ticket.is_empty():
		return
	var hello: Dictionary = _hello()
	hello["give_up"] = {"code": str(_courier_ticket["code"]), "token": str(_courier_ticket["token"])}
	_courier.send_auth(id, var_to_bytes(hello))


## The give-up connection proves this install's key like any greeting, then hears the answer.
func _courier_auth(id: int, data: PackedByteArray) -> void:
	var reply: Dictionary = _small_dict(data)
	var nonce: Variant = reply.get("nonce")
	if _courier != null and nonce is PackedByteArray and (nonce as PackedByteArray).size() == NONCE_BYTES:
		_courier.send_auth(id, var_to_bytes(proof_for(nonce)))
	else:
		_courier_heard(reply)


## Client: the server's answer to a give-up, {} for none (out of reach, no answer). A "still
## connected" answer tries again after GIVE_UP_RETRY_MS while there is time; anything else ends it.
func _courier_heard(reply: Dictionary) -> void:
	_courier_done = true
	var code: String = str(_courier_ticket.get("code", ""))
	if reply.has("gave_up"):
		note("gave up the duel in room %s" % code)
		_courier_ticket = {}
	elif reply.get("again", false) == true and Time.get_ticks_msec() + GIVE_UP_RETRY_MS < _courier_until:
		_courier_next = Time.get_ticks_msec() + GIVE_UP_RETRY_MS
	else:
		note("give-up for room %s not taken: %s" % [code, str(reply.get("refused", "no answer"))])
		_courier_ticket = {}


func _drop_courier() -> void:
	if _courier != null and _courier.multiplayer_peer != null:
		_courier.multiplayer_peer.close()
	_courier = null
	_courier_done = false


## Client: how long the server still keeps the other seat for its player, -1 while it is here.
func away_left_ms(seat: int) -> int:
	if seat < 0 or seat > 1 or _away_until[seat] == 0:
		return -1
	return maxi(0, _away_until[seat] - Time.get_ticks_msec())


## Client: how long this install is still kept out of the queues for a recent leave, as the server
## last said, 0 for not at all.
func cooldown_left_ms() -> int:
	return maxi(0, cooldown_until_msec - Time.get_ticks_msec()) if cooldown_until_msec > 0 else 0


func _begin_connecting() -> void:
	_stage = "connecting"
	_connect_deadline = Time.get_ticks_msec() + int(CONNECT_TIMEOUT_SECONDS * 1000.0)


func _timeout_reason() -> String:
	if not _via_server:
		return "No host answered at that address." if _stage == "connecting" else "The host did not answer in time."
	if _stage == "connecting" or _stage == "certificate":
		return SERVER_UNREACHABLE
	if _stage == "greeting":
		return "The duel server did not answer the greeting. It is probably running a different version of the game."
	return "The duel server did not answer in time. Try again in a moment."


## Drop the connection and tell whoever listens why.
func _fail(reason: String) -> void:
	note("failed: " + reason)
	leave()
	last_error = reason
	connection_failed.emit(reason)


## The duel server itself: no seat of its own, many rooms, DTLS under `tls` (null for plain ENet).
## Returns "" or a message.
func serve(port: int, tls: TLSOptions = null) -> String:
	leave()
	var lan: LanTransport = LanTransport.new()
	lan.port = port
	lan.max_peers = 4095
	lan.tls = tls
	transport = lan
	add_child(lan)
	var problem: String = await lan.host()
	if problem != "":
		leave()
		return problem
	mode = "server"
	_dtls = tls != null
	local_player = -1
	multiplayer.server_relay = false   # players never see or reach each other, only the server
	rooms.clear()
	_peer_room.clear()
	return ""


func join_code() -> String:
	if room_code != "":
		return room_code
	return transport.join_code if transport != null else ""


## A hosting client's line for the title while it waits for its joiner.
func hosting_text() -> String:
	return transport.hosting_text() if is_host() and transport != null else ""


## Closes any connection and forgets it. `last_error`, `cooldown_until_msec` and the last result
## facts are left for the screens: a disconnect in the same frame as a result still shows it.
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
	lobby_notice = ""
	_room_request = ""
	_via_server = false
	_other_present = false
	rooms.clear()
	queue.clear()
	ranked_queue.clear()
	_peer_room.clear()
	_unseated.clear()
	_refused.clear()
	queue_state = ""
	queue_reason = ""
	queue_since = 0
	pick_until = 0
	deal_at = 0
	_queue_request = false
	_queue_ranked = false
	_room_kind = ""
	_ranked = false
	_match_over = false
	series_game = 0
	series_wins = [0, 0]
	next_game_at = 0
	_pending_updates.clear()
	_hold_updates = false
	_in_duel = false
	_duel_over = false
	_stage = ""
	_connect_deadline = 0
	_presence_heard.clear()
	resumed = false
	_rejoin = {}
	_server_address = ""
	_away_until = [0, 0]
	_gave_up_peers.clear()
	_greeting.clear()
	_peer_identity.clear()
	_dtls = false
	_drop_cert_probe()
	reset_lobby()


# --- Greeting ---------------------------------------------------------------

## A hash of every card file, the deck files in list order and the strike table, so both sides
## agree on what a deck index and a card id mean. Line endings do not count.
func catalog_fingerprint() -> String:
	if _catalog != "":
		return _catalog
	var files: Array[String] = _json_files(Session.CARDS_DIR, true)
	files.append_array(_json_files(Session.DECKS_DIR, false))
	files.append(Session.TABLE_PATH)
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for path in files:
		ctx.update(path.to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_string(path).replace("\r", "").to_utf8_buffer())
	_catalog = ctx.finish().hex_encode()
	return _catalog


static func _json_files(dir_path: String, recurse: bool) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for entry in dir.get_files():
		if entry.ends_with(".json"):
			out.append(dir_path.path_join(entry))
	if recurse:
		for sub in dir.get_directories():
			if not sub.begins_with("."):
				out.append_array(_json_files(dir_path.path_join(sub), true))
	out.sort()
	return out


## Authority: why a peer's hello is refused on its protocol or catalog, or "" when both match.
func hello_problem(data: PackedByteArray) -> String:
	return _hello_problem(_small_dict(data))


func _hello_problem(hello: Dictionary) -> String:
	var protocol: Variant = hello.get("protocol")
	var catalog: Variant = hello.get("catalog")
	var other: String = "the duel server" if is_server() else "the host"
	if not (protocol is int and catalog is String):
		return "The greeting was not understood. This copy of the game and %s are different versions." % other
	if int(protocol) != PROTOCOL:
		return "This copy of the game speaks online version %d and %s speaks version %d. Both need the same build of the game." % [int(protocol), other, PROTOCOL]
	if str(catalog) != catalog_fingerprint():
		return "Your cards or decks differ from those on %s. Both need the same build of the game." % other
	return ""


static func _small_dict(data: PackedByteArray) -> Dictionary:
	if data.is_empty() or data.size() > HELLO_MAX_BYTES:
		return {}
	var value: Variant = bytes_to_var(data)
	if value is Dictionary:
		return value
	return {}


func _on_peer_authenticating(id: int) -> void:
	_quick_timeout(id)
	if mode == "client" and id == HOST_ID:
		# ENet's own DTLS has accepted the certificate by now, so the check has nothing left to say.
		_drop_cert_probe()
		_stage = "greeting"
		note("connected, greeting with protocol %d" % PROTOCOL)
		(multiplayer as SceneMultiplayer).send_auth(HOST_ID, var_to_bytes(_hello()))


## This install's identity, loaded or made the first time a greeting needs it.
func identity() -> Identity:
	if _identity == null:
		_identity = Identity.load_or_make()
	return _identity


## A client's first greeting message.
func _hello() -> Dictionary:
	return {"protocol": PROTOCOL, "catalog": catalog_fingerprint(), "ticket": {"kind": "key", "public": identity().public_pem()}}


## What a greeting's proof signs, in this order: the server's nonce, PROTOCOL as 4 bytes
## little-endian, and the catalog hash as its 64 ASCII characters. The last two keep a signature
## for one build from standing in for another.
func challenge_bytes(nonce: PackedByteArray) -> PackedByteArray:
	var out: PackedByteArray = nonce.duplicate()
	var protocol: PackedByteArray = PackedByteArray()
	protocol.resize(4)
	protocol.encode_u32(0, PROTOCOL)
	out.append_array(protocol)
	out.append_array(catalog_fingerprint().to_ascii_buffer())
	return out


## A client's answer to the duel server's nonce.
func proof_for(nonce: PackedByteArray) -> Dictionary:
	return {"proof": identity().sign(challenge_bytes(nonce))}


## The greeting on the auth channel. The authority answers each message with `greeting_reply`, and
## lets the peer in on {"ok"}; a refused peer is dropped when its greeting times out. A client
## answers the duel server's nonce with its proof and completes on {"ok"}, or leaves with the
## reason. It signs only for the duel server, never for a hosting client.
func _on_auth(id: int, data: PackedByteArray) -> void:
	var api: SceneMultiplayer = multiplayer as SceneMultiplayer
	if is_authority():
		var answer: Dictionary = greeting_reply(id, _small_dict(data))
		if answer.is_empty():
			return
		api.send_auth(id, var_to_bytes(answer))
		if answer.has("ok"):
			api.complete_auth(id)
		return
	if mode != "client" or id != HOST_ID:
		return
	var reply: Dictionary = _small_dict(data)
	var refused: Variant = reply.get("refused")
	var nonce: Variant = reply.get("nonce")
	if refused is String:
		_fail(str(refused).left(300))
	elif _via_server and nonce is PackedByteArray and (nonce as PackedByteArray).size() == NONCE_BYTES:
		note("proving this install's key, identity %s" % identity().short_id())
		api.send_auth(HOST_ID, var_to_bytes(proof_for(nonce)))
	elif reply.has("ok"):
		_stage = "seat"
		api.complete_auth(HOST_ID)
	else:
		_fail("The greeting was not understood. This copy of the game and the other side are different versions.")


## Authority: the answer to one message on peer `id`'s auth channel, {} for none. A hello with this
## build's protocol and catalog gets {"ok"} from a hosting client. The duel server also wants the
## key in the hello's ticket proven: it answers {"nonce"} and keeps the hello until the proof comes
## back, and the nonce is spent on that one proof, good or bad. A good proof lets the peer in with
## {"ok"} and its identity, or on a give-up connection gets the give-up's answer (`_on_give_up`),
## which never lets it in. Anything else is {"refused": reason}, and a refused or admitted peer is
## not answered again.
func greeting_reply(id: int, message: Dictionary) -> Dictionary:
	var pending: Variant = _greeting.get(id)
	if pending is bool or _peer_identity.has(id):
		return {}
	if pending is Dictionary:
		_greeting.erase(id)
		return _proof_reply(id, pending, message.get("proof"))
	var problem: String = _hello_problem(message)
	if problem != "":
		return _refuse_greeting(id, problem)
	if not is_server():
		return {} if message.has("give_up") else {"ok": PROTOCOL}
	var public: String = _ticket_key(message.get("ticket"))
	if public == "":
		return _refuse_greeting(id, NO_KEY)
	var nonce: PackedByteArray = _crypto.generate_random_bytes(NONCE_BYTES)
	var hello: Dictionary = {"nonce": nonce, "public": public, "identity": public.sha256_text()}
	if message.has("give_up"):
		hello["give_up"] = message["give_up"]
	_greeting[id] = hello
	return {"nonce": nonce}


func _proof_reply(id: int, hello: Dictionary, proof: Variant) -> Dictionary:
	var nonce: PackedByteArray = hello["nonce"]
	if not (proof is PackedByteArray) or not Identity.verify(str(hello["public"]), challenge_bytes(nonce), proof):
		return _refuse_greeting(id, BAD_PROOF)
	var who: String = str(hello["identity"])
	if hello.has("give_up"):
		_gave_up_peers[id] = true
		return _on_give_up(id, hello["give_up"], who)
	_peer_identity[id] = who
	_server_log("peer %d: identity %s%s" % [id, Identity.short(who), ", DTLS handshake done" if _dtls else ", plain ENet"])
	return {"ok": PROTOCOL}


func _refuse_greeting(id: int, problem: String) -> Dictionary:
	_greeting[id] = false
	_server_log("peer %d refused at the greeting: %s" % [id, problem])
	return {"refused": problem}


## The public key a hello's ticket carries, written out the one way `Identity` writes keys, or ""
## for a missing or malformed ticket.
static func _ticket_key(ticket: Variant) -> String:
	if not (ticket is Dictionary):
		return ""
	var kind: Variant = (ticket as Dictionary).get("kind")
	var public: Variant = (ticket as Dictionary).get("public")
	if not (kind is String and public is String) or str(kind) != "key":
		return ""
	return Identity.canonical_public(str(public))


## Client of the server: what `_rpc_queue_join` carries, this install's identity id, and "mode"
## "ranked" for the ranked queue. The server takes the identity from the greeting and refuses a
## ticket naming another.
func queue_ticket(ranked: bool = false) -> Dictionary:
	var ticket: Dictionary = {"identity": identity().id()}
	if ranked:
		ticket["mode"] = "ranked"
	return ticket


## ENet notices a peer that went silent (a closed game, a pulled cable) within PEER_TIMEOUT_MAX_MS
## instead of its default 30 s, on the server for each player and on a client for the server.
func _quick_timeout(id: int) -> void:
	var enet: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return
	var peer: ENetPacketPeer = enet.get_peer(id)
	if peer != null:
		peer.set_timeout(PEER_TIMEOUT_LIMIT, PEER_TIMEOUT_MIN_MS, PEER_TIMEOUT_MAX_MS)


func _on_authentication_failed(id: int) -> void:
	if is_authority():
		_greeting.erase(id)
		if not _gave_up_peers.erase(id):
			_server_log("peer %d dropped at the greeting" % id)
	elif mode == "client" and id == HOST_ID:
		_fail(_timeout_reason())


# --- Peers ------------------------------------------------------------------

## A peer passed the greeting. A hosting client seats it as player 2; the server tells it its
## ranked rating and gives it `UNSEATED_SECONDS` to ask for a room.
func _on_peer_connected(id: int) -> void:
	note("peer %d connected" % id)
	if is_server():
		_unseated[id] = Time.get_ticks_msec() + int(UNSEATED_SECONDS * 1000.0)
		var who: String = str(_peer_identity.get(id, ""))
		if ratings != null and who != "":
			var mine: Dictionary = ratings.get_or_new(who)
			var mu: float = float(mine["mu"])
			var sigma: float = float(mine["sigma"])
			_tell(id, &"_rpc_rating", [Rating.shown(mu, sigma), Rating.provisional(sigma), mu, sigma])
		return
	if not is_host():
		return
	if peer_id != 0:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	peer_id = id
	seat_peer[1] = id
	lobby_notice = ""
	_tell(id, &"_rpc_assign_seat", [1, ""])
	_send_joiner_lobby()
	connected.emit()


## Host: the seat a remote sender plays, -1 for a stranger.
func seat_of(id: int) -> int:
	return 1 if is_host() and id == peer_id and id != 0 else -1


func _on_connected_to_server() -> void:
	peer_id = HOST_ID
	_stage = "seat"
	if _via_server and not _rejoin.is_empty():
		note("reached the duel server, asking for our seat in room %s back" % str(_rejoin["code"]))
		_rpc_rejoin.rpc_id(HOST_ID, str(_rejoin["code"]), str(_rejoin["token"]))
	elif _via_server and _queue_request:
		note("reached the duel server, asking for the %s queue" % ("ranked" if _queue_ranked else "casual"))
		_rpc_queue_join.rpc_id(HOST_ID, queue_ticket(_queue_ranked))
	elif _via_server:
		note("reached the duel server, asking for room '%s'" % _room_request)
		_rpc_room_request.rpc_id(HOST_ID, _room_request)
	else:
		note("connected to the host, waiting for a seat")


## The authority seats this client. From the server, `code` names the room.
@rpc("authority", "call_remote", "reliable")
func _rpc_assign_seat(seat: int, code: String) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or mode != "client" or seat < 0 or seat > 1:
		return
	_connect_deadline = 0
	_stage = ""
	local_player = seat
	seat_peer = [HOST_ID, HOST_ID]
	seat_peer[seat] = 0
	room_code = code
	_room_kind = "code"
	note("seated as player %d%s" % [seat + 1, "" if code == "" else " in room " + code])
	_rpc_lobby_pick.rpc_id(HOST_ID, -1, "", clean_name(Session.player_names[seat], seat), false)
	connected.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_room_failed(reason: String) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	_fail(reason.left(300))


## ENet gave up connecting. With the certificate check still under way its verdict decides the
## reason, within the connect time.
func _on_connection_failed() -> void:
	if _cert_probe != null:
		_stage = "certificate"
		return
	_fail(SERVER_UNREACHABLE if _via_server else "No host answered at that address.")


func _on_peer_disconnected(id: int) -> void:
	note("peer %d disconnected" % id)
	_presence_heard.erase(id)
	if is_server():
		_unseated.erase(id)
		_refused.erase(id)
		_peer_identity.erase(id)
		var line: MatchQueue = _queue_holding(id)
		if line != null:
			var waited: int = line.waiting(id, Time.get_ticks_msec())
			line.leave(id)
			_server_log("queue: peer %d left, disconnected after %d s (%d waiting)" % [id, _secs(waited), line.size()])
		_seat_left_room(id)
		return
	if is_host() and id == peer_id:
		peer_id = 0
		seat_peer[1] = 0
		_note_left(1)
		peer_left.emit()


func _on_server_disconnected() -> void:
	_fail("The duel server closed the connection." if _via_server else "The host closed the connection.")


## The server tells the player still in a room that the other seat left.
@rpc("authority", "call_remote", "reliable")
func _rpc_seat_left(seat: int) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or seat < 0 or seat > 1 or seat == local_player:
		return
	_other_present = false
	_away_until[seat] = 0
	_note_left(seat)
	peer_left.emit()


## The server tells the player still in a duel that the other seat's connection dropped, and how
## long it keeps that seat.
@rpc("authority", "call_remote", "reliable")
func _rpc_seat_away(seat: Variant, grace_ms: Variant) -> void:
	_on_seat_away(multiplayer.get_remote_sender_id(), seat, grace_ms)


func _on_seat_away(sender: int, seat: Variant, grace_ms: Variant) -> void:
	if sender != HOST_ID or mode != "client" or not (seat is int and grace_ms is int):
		return
	if int(seat) < 0 or int(seat) > 1 or int(seat) == local_player:
		return
	var grace: int = clampi(grace_ms, 0, REJOIN_GRACE_MS)
	_away_until[seat] = maxi(1, Time.get_ticks_msec() + grace)
	peer_away.emit(int(seat), grace)


@rpc("authority", "call_remote", "reliable")
func _rpc_seat_back(seat: Variant) -> void:
	_on_seat_back(multiplayer.get_remote_sender_id(), seat)


func _on_seat_back(sender: int, seat: Variant) -> void:
	if sender != HOST_ID or mode != "client" or not (seat is int) or int(seat) < 0 or int(seat) > 1 or int(seat) == local_player:
		return
	_away_until[seat] = 0
	peer_back.emit(int(seat))


## The other seat emptied: the lobby forgets its pick and the notice says who left.
func _note_left(seat: int) -> void:
	var who: String = str(lobby[seat]["name"])
	lobby[seat] = DuelRoom.empty_pick(seat)
	if room_code != "":
		lobby_notice = "%s left the room. The code still works for a new player." % who
	else:
		lobby_notice = "%s left. Waiting for another player." % who


## Server and hosting client: one RPC to a peer that is still connected. A peer that already
## dropped is skipped, since a room can outlive either seat's connection by a moment.
func _tell(peer: int, method: StringName, args: Array = []) -> void:
	if peer == 0:
		return
	if _outbox.is_valid():
		_outbox.call(peer, method, args)
		return
	if not multiplayer.get_peers().has(peer):
		return
	var call_args: Array = [peer, method]
	call_args.append_array(args)
	callv(&"rpc_id", call_args)


## Server and hosting client: log an RPC that was dropped, with the room it came from.
func _refuse(room: DuelRoom, sender: int, what: String) -> void:
	_server_log("room %s: refused %s from peer %d" % [room.code if room != null else "-", what, sender])


# --- Rooms (server) -------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _rpc_room_request(code: Variant) -> void:
	_on_room_request(multiplayer.get_remote_sender_id(), code)


## Server: a peer asks for a room, "" to open one or a share code to join one. One request per
## connection; a peer that was turned away is ignored until it disconnects.
func _on_room_request(sender: int, code: Variant) -> void:
	if not is_server():
		return
	if _peer_room.has(sender) or _refused.has(sender) or _queue_holding(sender) != null:
		_refuse(_room_of(sender), sender, "a second room request")
		return
	var wanted: String = str(code).strip_edges().to_upper() if code is String else "?"
	var room: DuelRoom = null
	var problem: String = ""
	if wanted == "":
		room = _open_room()
	elif not DuelRoom.valid_code(wanted):
		problem = "That is not a share code. " + CODE_FORMAT
	elif not rooms.has(wanted) or (rooms[wanted] as DuelRoom).kind == "queue":
		problem = "No room has the code %s. Check the code, or ask the host for a new one." % wanted
	else:
		room = rooms[wanted]
		if room.phase != DuelRoom.Phase.LOBBY:
			problem = "The duel in room %s has already started." % wanted
		elif room.free_seat() < 0:
			problem = "Room %s already has two players." % wanted
	if problem != "":
		_refused[sender] = true
		_server_log("peer %d refused: %s" % [sender, problem])
		_tell(sender, &"_rpc_room_failed", [problem])
		return
	var seat: int = room.free_seat()
	room.seat_peer[seat] = sender
	room.seat_identity[seat] = str(_peer_identity.get(sender, ""))
	room.lobby[seat] = DuelRoom.empty_pick(seat)
	room.alone_since = 0 if room.filled() else maxi(1, Time.get_ticks_msec())
	_peer_room[sender] = room.code
	_unseated.erase(sender)
	_server_log("room %s: peer %d takes seat %d" % [room.code, sender, seat + 1])
	_tell(sender, &"_rpc_assign_seat", [seat, room.code])
	_send_lobby(room)
	connected.emit()


func _open_room() -> DuelRoom:
	var room: DuelRoom = DuelRoom.new()
	room.code = DuelRoom.new_code(_crypto.generate_random_bytes(DuelRoom.CODE_LENGTH))
	while rooms.has(room.code):
		room.code = DuelRoom.new_code(_crypto.generate_random_bytes(DuelRoom.CODE_LENGTH))
	room.color_seed = _color_seed()
	rooms[room.code] = room
	_server_log("room %s: opened (%d rooms)" % [room.code, rooms.size()])
	return room


@rpc("any_peer", "call_remote", "reliable")
func _rpc_rejoin(code: Variant, token: Variant) -> void:
	_on_rejoin(multiplayer.get_remote_sender_id(), code, token)


## Server: a player whose connection dropped asks for its seat back, instead of a room request,
## with the room's code and the token its seat was dealt, from the identity that took the seat. The
## seat must be away in a running duel.
## The player then gets `_rpc_resume` (after `_rpc_series` in a ranked match), the other player
## `_rpc_seat_back`, and the room's host sends the catch-up update and the clocks (`room_rejoined`).
## A seat whose old connection the server has not yet seen drop, or whose ranked match is between
## games, is refused as a failed connection, so the client tries again; every other refusal is final
## and the client forgets the duel.
func _on_rejoin(sender: int, code: Variant, token: Variant) -> void:
	if not is_server():
		return
	if _peer_room.has(sender) or _refused.has(sender) or _queue_holding(sender) != null:
		_refuse(_room_of(sender), sender, "a second room request")
		return
	var claim: Array = _claim(code, token, str(_peer_identity.get(sender, "")))
	var room: DuelRoom = claim[0]
	var seat: int = claim[1]
	var problem: String = claim[2]
	if problem != "":
		_refused[sender] = true
		if problem == STILL_CONNECTED or problem == NEXT_GAME:
			_server_log("room %s: peer %d refused a rejoin: seat %d %s" % [room.code, sender, seat + 1,
				"is still connected" if problem == STILL_CONNECTED else "is away between games"])
			_tell(sender, &"_rpc_room_failed", [problem + " Trying again."])
		else:
			_server_log("peer %d refused a rejoin: %s" % [sender, problem])
			_tell(sender, &"_rpc_rejoin_failed", [problem])
		return
	var now: int = maxi(1, Time.get_ticks_msec())
	var both: bool = room.both_away_since > 0
	if both:
		# The other seat's grace stood still while nobody was here, and runs on from now.
		room.away_since[1 - seat] += now - room.both_away_since
		room.both_away_since = 0
	room.away_since[seat] = 0
	room.seat_peer[seat] = sender
	_peer_room[sender] = room.code
	_unseated.erase(sender)
	_server_log("room %s: seat %d is back (peer %d)" % [room.code, seat + 1, sender])
	var args: Array = [seat, room.code]
	args.append_array(_deal_args(room))
	if room.ranked:
		_tell(sender, &"_rpc_series", [room.best_of, room.game, [room.wins[0], room.wins[1]]])
	_tell(sender, &"_rpc_resume", args)
	if room.away_since[1 - seat] > 0:
		_tell(sender, &"_rpc_seat_away", [1 - seat, maxi(0, REJOIN_GRACE_MS - (now - room.away_since[1 - seat]))])
	_tell(room.other_peer(seat), &"_rpc_seat_back", [seat])
	room_rejoined.emit(room.code, seat, both)


## Server: a seat cut off from its duel concedes it, on a connection that carries only this in its
## greeting and never takes a seat. The room's code and the seat's token prove the seat, which must
## be away, and `identity` (from that greeting's proof) must be the one that took it. The duel ends
## as a concession for the other seat, its record written first; a ranked seat gives up the whole
## match, between games too. The answer goes back on the greeting: {"gave_up": true}, or
## {"refused": reason}, with "again": true while the seat's old connection has not dropped yet.
func _on_give_up(sender: int, raw: Variant, identity: String = "") -> Dictionary:
	var request: Dictionary = raw if raw is Dictionary else {}
	var claim: Array = _claim(request.get("code"), request.get("token"), identity)
	var room: DuelRoom = claim[0]
	var seat: int = claim[1]
	var problem: String = claim[2]
	if problem == STILL_CONNECTED:
		_server_log("room %s: peer %d refused a give-up: seat %d is still connected" % [room.code, sender, seat + 1])
		return {"refused": problem, "again": true}
	if problem != "" and problem != NEXT_GAME:
		_server_log("peer %d refused a give-up: %s" % [sender, problem])
		return {"refused": problem}
	_server_log("room %s: seat %d gave up while away (peer %d)" % [room.code, seat + 1, sender])
	if room.ranked:
		_leave_match(room, seat)
	else:
		_end_room(room, 1 - seat, "concede")
	return {"gave_up": true}


## Server: the room and seat a rejoin or a give-up names by share code and token, as
## [room, seat, problem]. `problem` is "" when the seat is away in a running duel and `identity`
## took it, STILL_CONNECTED while its old connection has not dropped, NEXT_GAME for an away seat
## whose ranked match is between games, and otherwise the reason the player is shown.
func _claim(code: Variant, token: Variant, identity: String) -> Array:
	var wanted: String = str(code).strip_edges().to_upper() if code is String else ""
	var room: DuelRoom = rooms.get(wanted, null) if DuelRoom.valid_code(wanted) else null
	var seat: int = room.seat_of_token(str(token)) if room != null and token is String else -1
	var problem: String = ""
	if room == null:
		problem = REJOIN_GONE
	elif room.phase != DuelRoom.Phase.DUEL and room.phase != DuelRoom.Phase.BETWEEN:
		problem = REJOIN_OVER
	elif seat < 0:
		problem = "That duel has no seat for this copy of the game."
	elif room.seat_identity[seat] != identity:
		problem = SEAT_ELSEWHERE
	elif room.away_since[seat] == 0:
		problem = STILL_CONNECTED
	elif room.phase == DuelRoom.Phase.BETWEEN:
		problem = NEXT_GAME
	return [room, seat, problem]


func _room_of(id: int) -> DuelRoom:
	return rooms.get(_peer_room.get(id, ""), null)


## Server: the room a seated sender is in, or null, logged, for a peer without one.
func _sender_room(sender: int, what: String) -> DuelRoom:
	if not is_server():
		return null
	var room: DuelRoom = _room_of(sender)
	if room == null:
		_refuse(null, sender, what + (" while queued" if _queue_holding(sender) != null else ""))
	return room


## Server: a player's connection closed, or the player left a finished duel for the queue. A running
## duel, or a ranked match between games, keeps the seat for them (`_seat_away`). A queue room not
## yet dealt closes and sends the other player back to the front of the queue. Otherwise the room
## stays for whoever is still in it, and in a share-code lobby a new player can take the seat. The
## last one out closes it.
func _seat_left_room(id: int) -> void:
	var room: DuelRoom = _room_of(id)
	if room == null:
		return
	var seat: int = room.seat_of(id)
	_peer_room.erase(id)
	room.seat_peer[seat] = 0
	if room.phase == DuelRoom.Phase.DUEL or room.phase == DuelRoom.Phase.BETWEEN:
		_seat_away(room, seat)
	elif room.kind == "queue" and room.phase == DuelRoom.Phase.LOBBY:
		_abandon_pick(room, seat)
	else:
		_free_seat(room, seat)


## Server: an empty seat is given up. The other player hears it, or the room closes when nobody is
## left in it.
func _free_seat(room: DuelRoom, seat: int) -> void:
	room.lobby[seat] = DuelRoom.empty_pick(seat)
	room.seat_identity[seat] = ""
	room.deal_ready = [false, false]
	room.rematch = [false, false]
	var other: int = room.other_peer(seat)
	if other == 0:
		_close_room(room, "the last player left")
		return
	room.alone_since = maxi(1, Time.get_ticks_msec())
	_server_log("room %s: seat %d left, the room stays open" % [room.code, seat + 1])
	_tell(other, &"_rpc_seat_left", [seat])


## Server: a seat's connection dropped mid-duel. The room keeps the seat for REJOIN_GRACE_MS with its
## clock running, and tells the other player. With both seats away both clocks stop instead.
func _seat_away(room: DuelRoom, seat: int) -> void:
	var now: int = maxi(1, Time.get_ticks_msec())
	room.away_since[seat] = now
	var other: int = room.other_peer(seat)
	var both: bool = other == 0
	if both:
		room.both_away_since = now
		_server_log("room %s: seat %d lost connection, both seats are away" % [room.code, seat + 1])
	else:
		_server_log("room %s: seat %d lost connection" % [room.code, seat + 1])
		_tell(other, &"_rpc_seat_away", [seat, REJOIN_GRACE_MS])
	room_seat_away.emit(room.code, seat, both)


## Server, from `sweep`: a seat away past its grace loses, "left", and a duel both seats have been
## away from for REJOIN_GRACE_MS ends with no winner, "abandoned".
func _sweep_away(room: DuelRoom, now: int) -> void:
	if room.both_away_since > 0:
		if now - room.both_away_since >= REJOIN_GRACE_MS:
			_server_log("room %s: both seats stayed away, no winner" % room.code)
			_end_room(room, -1, "abandoned")
		return
	for seat in range(2):
		if room.away_since[seat] > 0 and now - room.away_since[seat] >= REJOIN_GRACE_MS:
			_server_log("room %s: seat %d did not come back, seat %d wins" % [room.code, seat + 1, 2 - seat])
			_end_room(room, 1 - seat, "left")
			return


## Server: the room's duel is over, so a seat still away is not coming back to it. It empties as
## if its player had left, and the room closes once nobody is in it.
func _let_away_go(room: DuelRoom) -> void:
	room.tokens = ["", ""]
	room.both_away_since = 0
	for seat in range(2):
		if room.away_since[seat] == 0:
			continue
		room.away_since[seat] = 0
		if rooms.get(room.code, null) == room:
			_free_seat(room, seat)


func _close_room(room: DuelRoom, reason: String) -> void:
	var until: int = Time.get_ticks_msec() + int(UNSEATED_SECONDS * 1000.0)
	for peer in room.seat_peer:
		if peer != 0:
			_peer_room.erase(peer)
			_unseated[peer] = until
	rooms.erase(room.code)
	_server_log("room %s: closed, %s (%d rooms)" % [room.code, reason, rooms.size()])
	room_closed.emit(room.code)


## Server, once a second: drops a peer that never took a room, ends a duel whose away seat did not
## come back in time, deals or times out a queue room's pick, deals a ranked match's next game when
## its wait is over, closes a room that has held a single player for `room_idle_seconds`, drops
## whoever has waited in a queue for QUEUE_MAX_WAIT_MS, and pairs the queues: when a duel ending made
## room under `max_live_duels`, and in the ranked queue as the rating windows widen.
func sweep(now: int) -> void:
	for id: int in _unseated.keys():
		if now >= int(_unseated[id]):
			_unseated.erase(id)
			_server_log("peer %d dropped: no room after %d seconds" % [id, int(UNSEATED_SECONDS)])
			if multiplayer.get_peers().has(id):
				multiplayer.multiplayer_peer.disconnect_peer(id)
	var idle_msec: int = int(room_idle_seconds * 1000.0)
	for code: String in rooms.keys():
		var room: DuelRoom = rooms.get(code, null)
		if room != null and room.phase == DuelRoom.Phase.DUEL:
			_sweep_away(room, now)
		elif room != null and room.kind == "queue" and room.phase == DuelRoom.Phase.LOBBY:
			_sweep_pick(room, now)
		elif room != null and room.phase == DuelRoom.Phase.BETWEEN:
			if now >= room.next_deal_msec:
				_server_log("room %s: dealing game %d" % [room.code, room.game + 1])
				_deal(room)
		elif room != null and room.alone_since > 0 and not room.filled() and now - room.alone_since >= idle_msec:
			var minutes: int = maxi(1, roundi(room_idle_seconds / 60.0))
			for peer in room.seat_peer:
				_tell(peer, &"_rpc_room_failed", ["The room closed after %d minutes without another player." % minutes])
			_close_room(room, "idle")
	var stale: Array[int] = queue.drop_stale(now, QUEUE_MAX_WAIT_MS)
	stale.append_array(ranked_queue.drop_stale(now, QUEUE_MAX_WAIT_MS))
	for peer: int in stale:
		_drop_from_queue(peer, QUEUE_NO_OPPONENT, "no opponent after %d minutes" % roundi(QUEUE_MAX_WAIT_MS / 60000.0), now)
	if queue.size() >= 2 or ranked_queue.size() >= 2:
		_pair_queue(now)


# --- Find a duel (server) ---------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _rpc_queue_join(ticket: Variant) -> void:
	_on_queue_join(multiplayer.get_remote_sender_id(), ticket)


## Server: a peer asks to be paired with the next player looking. `ticket` is a Dictionary whose
## "identity", when there, must be the one the peer proved in its greeting, and whose "mode", when
## there, is "casual" or "ranked"; keys it does not know are ignored. Taken from a peer past the
## greeting that is not waiting already and holds no room in the lobby or a duel. A player on a
## leaver cooldown is answered `dropped` with the time left, in the line and in ms. A finished
## duel's room is let go first, as if the player had left it. The peer hears `queued`, with a
## warning after a recent leave, and its queue pairs straight away.
func _on_queue_join(sender: int, ticket: Variant) -> void:
	if not is_server():
		return
	if _refused.has(sender) or _queue_holding(sender) != null or not (ticket is Dictionary):
		_refuse(_room_of(sender), sender, "a queue join while queued" if _queue_holding(sender) != null else "a queue join")
		return
	var who: String = str(_peer_identity.get(sender, ""))
	var claimed: Variant = (ticket as Dictionary).get("identity", who)
	if not (claimed is String) or str(claimed) != who:
		_refuse(_room_of(sender), sender, "a queue ticket for another identity")
		return
	var wanted: Variant = (ticket as Dictionary).get("mode", "casual")
	if not (wanted is String) or not QUEUE_MODES.has(wanted):
		_refuse(_room_of(sender), sender, "a queue ticket for an unknown mode")
		return
	var ranked: bool = wanted == "ranked"
	var room: DuelRoom = _room_of(sender)
	if room != null and room.phase != DuelRoom.Phase.OVER:
		_refuse(room, sender, "a queue join from a seated player")
		_tell(sender, &"_rpc_queue_state", ["dropped", "Finish or leave your duel first.", 0])
		return
	var now_unix: int = int(Time.get_unix_time_from_system())
	var wait_ms: int = conduct.cooldown_left_ms(who, now_unix) if conduct != null and who != "" else 0
	if (ranked and who == "") or wait_ms > 0:
		var why: String = QUEUE_NEEDS_KEY if wait_ms == 0 else QUEUE_COOLDOWN % Conduct.wait_text(wait_ms)
		_server_log("queue: peer %d refused, %s" % [sender, "no identity for ranked" if wait_ms == 0
			else "%s on a leaver cooldown, %s left" % [Identity.short(who), Conduct.wait_text(wait_ms)]])
		_tell(sender, &"_rpc_queue_state", ["dropped", why, wait_ms])
		if room == null:
			_unseated[sender] = Time.get_ticks_msec() + int(UNSEATED_SECONDS * 1000.0)
		return
	if room != null:
		_server_log("room %s: seat %d left the finished duel for the queue" % [room.code, room.seat_of(sender) + 1])
		_seat_left_room(sender)
	var now: int = Time.get_ticks_msec()
	_unseated.erase(sender)
	if ranked:
		var mu: float = _mu_of(who)
		ranked_queue.join(sender, now, mu, who)
		_server_log("queue: peer %d joined ranked, mu %.2f (%d waiting)" % [sender, mu, ranked_queue.size()])
	else:
		queue.join(sender, now, 0.0, who)
		_server_log("queue: peer %d joined (%d waiting)" % [sender, queue.size()])
	var warned: int = conduct.count(who, now_unix) if conduct != null and who != "" else 0
	var note_line: String = QUEUE_WARNED % roundi(conduct.next_cost_ms(who, now_unix) / 60000.0) if warned > 0 else ""
	_tell(sender, &"_rpc_queue_state", ["queued", note_line, 0])
	_pair_queue(now)
	_note_held()


## Server: the queue `peer` waits in, or null.
func _queue_holding(peer: int) -> MatchQueue:
	if queue.has(peer):
		return queue
	return ranked_queue if ranked_queue.has(peer) else null


static func _rated_queue() -> MatchQueue:
	var line: MatchQueue = MatchQueue.new()
	line.rated = true
	return line


## Server: an identity's ranked mu, a new player's without the ratings file.
func _mu_of(who: String) -> float:
	return float(ratings.get_or_new(who)["mu"]) if ratings != null else Rating.MU


## Server: while the live duels are under `max_live_duels`, the two who have waited longest go into
## a queue room, and in the ranked queue each pair its rating windows allow.
func _pair_queue(now: int) -> void:
	var room_for: int = -1 if max_live_duels <= 0 else maxi(0, max_live_duels - _live_duels())
	for pair: Array in queue.pair(now, room_for):
		_open_queue_room(pair, now, false)
	room_for = -1 if max_live_duels <= 0 else maxi(0, max_live_duels - _live_duels())
	for pair: Array in ranked_queue.pair(now, room_for):
		_open_queue_room(pair, now, true)


## Server, after a join or a re-queue: pairs the duel cap holds back. Everyone waiting in a queue
## of two or more hears why, with how long they have waited.
func _note_held() -> void:
	if max_live_duels <= 0 or _live_duels() < max_live_duels:
		return
	var now: int = Time.get_ticks_msec()
	for line: MatchQueue in [queue, ranked_queue]:
		if line.size() < 2:
			continue
		_server_log("queue: %d waiting%s, held back at %d live duels" % [line.size(), " for ranked" if line.rated else "", _live_duels()])
		for entry: Dictionary in line.entries:
			_tell(int(entry["peer"]), &"_rpc_queue_state", ["queued", QUEUE_FULL, maxi(0, now - int(entry["joined_msec"]))])


## Server: rooms with a duel running or a ranked match between games, and queue rooms still
## picking, which deal within a minute.
func _live_duels() -> int:
	var n: int = 0
	for room: DuelRoom in rooms.values():
		if room.phase == DuelRoom.Phase.DUEL or room.phase == DuelRoom.Phase.BETWEEN \
				or (room.kind == "queue" and room.phase == DuelRoom.Phase.LOBBY):
			n += 1
	return n


## Server: a pair from a queue gets a queue room, seats in an order from `Crypto`, and
## QUEUE_PICK_MS to lock in. Neither player learns the room's code as a share code. A pair from
## the ranked queue plays a best-of-3 match.
func _open_queue_room(pair: Array, now: int, ranked: bool) -> void:
	var room: DuelRoom = _open_room()
	room.kind = "queue"
	room.ranked = ranked
	room.best_of = RANKED_BEST_OF if ranked else 1
	var first: int = _crypto.generate_random_bytes(1)[0] & 1
	for seat in range(2):
		var entry: Dictionary = pair[seat ^ first]
		var peer: int = int(entry["peer"])
		room.seat_peer[seat] = peer
		room.seat_identity[seat] = str(_peer_identity.get(peer, ""))
		room.joined_msec[seat] = int(entry["joined_msec"])
		room.lobby[seat] = DuelRoom.empty_pick(seat)
		_peer_room[peer] = room.code
		_unseated.erase(peer)
	room.alone_since = 0
	room.pick_deadline_msec = maxi(1, now + QUEUE_PICK_MS)
	if ranked:
		var window: float = maxf(MatchQueue.window_mu(int(pair[0]["waited_ms"])), MatchQueue.window_mu(int(pair[1]["waited_ms"])))
		_server_log("queue: ranked pair peer %d (mu %.2f, waited %d s) and peer %d (mu %.2f, waited %d s) in room %s, window %s (%d waiting)" % [
			int(pair[0]["peer"]), float(pair[0]["mu"]), _secs(int(pair[0]["waited_ms"])), int(pair[1]["peer"]),
			float(pair[1]["mu"]), _secs(int(pair[1]["waited_ms"])), room.code,
			"open" if is_inf(window) else "%.1f mu" % window, ranked_queue.size()])
	else:
		_server_log("queue: paired peer %d (waited %d s) and peer %d (waited %d s) in room %s (%d waiting)" % [
			int(pair[0]["peer"]), _secs(int(pair[0]["waited_ms"])), int(pair[1]["peer"]), _secs(int(pair[1]["waited_ms"])),
			room.code, queue.size()])
	for seat in range(2):
		_tell(room.seat_peer[seat], &"_rpc_matched", [seat, roundi(QUEUE_PICK_MS / 1000.0), room.code])
	_send_lobby(room)


## Server, from `sweep`: a queue room deals once its matchup beat is over, and one whose lock-in
## time ran out closes.
func _sweep_pick(room: DuelRoom, now: int) -> void:
	if room.deal_at_msec > 0:
		if now >= room.deal_at_msec:
			room.deal_at_msec = 0
			_server_log("room %s: pick dealt" % room.code)
			_start_room(room)
	elif room.pick_deadline_msec > 0 and now >= room.pick_deadline_msec:
		_pick_timed_out(room, now)


## Server: a queue room's seat left before the deal. The room closes and the other player goes back
## to the front of its queue. Leaving a ranked matchup once both decks are shown is a dodge, which
## counts as a leave.
func _abandon_pick(room: DuelRoom, seat: int) -> void:
	_server_log("room %s: pick abandoned by seat %d in the %s" % [room.code, seat + 1, "matchup" if room.deal_at_msec > 0 else "pick"])
	if room.ranked and room.deal_at_msec > 0:
		_note_leave(room, seat, "dodged the ranked matchup")
	var other: int = room.other_peer(seat)
	var joined: int = room.joined_msec[1 - seat]
	_close_room(room, "seat %d left before the deal" % (seat + 1))
	if other != 0:
		_requeue(other, joined, QUEUE_OTHER_LEFT, room.ranked)


## Server: the lock-in time ran out. Nothing is picked for anyone: a seat that did not lock is
## dropped from the queue with the reason, and a seat that did goes back to the front of it.
func _pick_timed_out(room: DuelRoom, now: int) -> void:
	var peers: Array[int] = room.seat_peer.duplicate()
	var joined: Array[int] = room.joined_msec.duplicate()
	var locked: Array[bool] = [room.seat_locked(0), room.seat_locked(1)]
	var late: Array[String] = []
	for seat in range(2):
		if not locked[seat]:
			late.append(str(seat + 1))
	_server_log("room %s: pick timed out, seat %s did not lock in" % [room.code, " and ".join(late)])
	_close_room(room, "the lock-in time ran out")
	for seat in range(2):
		if peers[seat] != 0 and not locked[seat]:
			_drop_from_queue(peers[seat], QUEUE_LATE, "did not lock in", now)
	for seat in range(2):
		if peers[seat] != 0 and locked[seat]:
			_requeue(peers[seat], joined[seat], QUEUE_OTHER_LATE, room.ranked)


## Server: back in its queue at the place its first join earned, and paired again if someone waits.
## The player hears how long it has waited since that first join, so its count goes on from there.
func _requeue(peer: int, joined_msec: int, reason: String, ranked: bool = false) -> void:
	_unseated.erase(peer)
	_peer_room.erase(peer)
	var who: String = str(_peer_identity.get(peer, ""))
	var line: MatchQueue = ranked_queue if ranked else queue
	line.requeue(peer, joined_msec, _mu_of(who) if ranked else 0.0, who)
	_server_log("queue: peer %d requeued at the front%s (%d waiting)" % [peer, " of ranked" if ranked else "", line.size()])
	var now: int = Time.get_ticks_msec()
	_tell(peer, &"_rpc_queue_state", ["requeued", reason, maxi(0, now - joined_msec)])
	_pair_queue(now)
	_note_held()


## Server: out of the queue with a reason the player is shown. The client leaves; a connection that
## stays is dropped after UNSEATED_SECONDS like any peer without a room.
func _drop_from_queue(peer: int, reason: String, why: String, now: int) -> void:
	queue.leave(peer)
	ranked_queue.leave(peer)
	_server_log("queue: peer %d dropped, %s" % [peer, why])
	_tell(peer, &"_rpc_queue_state", ["dropped", reason, 0])
	_unseated[peer] = now + int(UNSEATED_SECONDS * 1000.0)


static func _secs(ms: int) -> int:
	return floori(ms / 1000.0)


# --- Find a duel (client) ---------------------------------------------------

## `ms` depends on `state`: for "queued" and "requeued" how long this player has waited since its
## first join, and for "dropped" how long a leaver cooldown still keeps it out, 0 for any other drop.
@rpc("authority", "call_remote", "reliable")
func _rpc_queue_state(state: Variant, reason: Variant, ms: Variant = 0) -> void:
	_on_queue_state(multiplayer.get_remote_sender_id(), state, reason, ms)


## Client: the server placed this client in the queue ("queued"), put it back at the front after the
## other player left or did not lock in ("requeued", which returns to the title with the count going
## on from the first join), or took it out ("dropped", which fails the connection with the reason, so
## the title shows it, and keeps any cooldown in `cooldown_until_msec` first).
func _on_queue_state(sender: int, state: Variant, reason: Variant, ms: Variant = 0) -> void:
	if sender != HOST_ID or mode != "client" or not _via_server or not (state is String and reason is String and ms is int):
		return
	var why: String = str(reason).left(300)
	var now: int = Time.get_ticks_msec()
	match str(state):
		"queued":
			_connect_deadline = 0
			_stage = ""
			cooldown_until_msec = 0
			if queue_state != "queued":
				queue_since = maxi(1, now - clampi(ms, 0, QUEUE_MAX_WAIT_MS))
			queue_state = "queued"
			queue_reason = why
			note("in the queue%s" % ("" if why == "" else ": " + why))
			queue_changed.emit("queued", why)
		"requeued":
			_back_in_queue(why, ms)
			queue_changed.emit("requeued", why)
			Session.go_to_title()
		"dropped":
			var wait: int = clampi(ms, 0, COOLDOWN_MAX_MS)
			if wait > 0:
				cooldown_until_msec = now + wait
			_fail(why)


## Client: the room is behind this seat and it waits in the queue again, `waited_ms` since its first
## join as the server counted it.
func _back_in_queue(why: String, waited_ms: int) -> void:
	_forget_room()
	queue_state = "queued"
	queue_reason = why
	queue_since = maxi(1, Time.get_ticks_msec() - clampi(waited_ms, 0, QUEUE_MAX_WAIT_MS))
	note("back in the queue: " + why)


@rpc("authority", "call_remote", "reliable")
func _rpc_matched(seat: Variant, pick_seconds: Variant, code: Variant) -> void:
	_on_matched(multiplayer.get_remote_sender_id(), seat, pick_seconds, code)


## Client: paired. This client plays `seat` in a queue room and has `pick_seconds` to lock in. The
## room's code is only for a rejoin and is never shown. The select screen loads as the lobby.
func _on_matched(sender: int, seat: Variant, pick_seconds: Variant, code: Variant) -> void:
	if sender != HOST_ID or mode != "client" or not _via_server or not (seat is int and pick_seconds is int and code is String):
		return
	if int(seat) < 0 or int(seat) > 1 or not DuelRoom.valid_code(code):
		return
	_connect_deadline = 0
	_stage = ""
	local_player = seat
	seat_peer = [HOST_ID, HOST_ID]
	seat_peer[seat] = 0
	room_code = code
	_room_kind = "queue"
	_ranked = _queue_ranked
	_match_over = false
	series_game = 0
	series_wins = [0, 0]
	next_game_at = 0
	_other_present = true
	lobby_notice = ""
	reset_lobby()
	queue_state = "picking"
	queue_reason = ""
	queue_since = 0
	pick_until = Time.get_ticks_msec() + clampi(pick_seconds, 1, 600) * 1000
	deal_at = 0
	note("paired as player %d, %d s to lock in" % [int(seat) + 1, int(pick_seconds)])
	queue_changed.emit("picking", "")
	Session.go_to_select()


## Server: deal a room whose seats are both locked. The seed stays here.
func _start_room(room: DuelRoom) -> void:
	if room.phase != DuelRoom.Phase.LOBBY or not room.both_locked():
		return
	for pick in room.lobby:
		if not valid_deck_pick(int(pick.get("deck", -1)), str(pick.get("deck_name", ""))):
			return
	room.away_since = [0, 0]
	room.both_away_since = 0
	_deal(room)


## Server: deal the room's next game on its locked picks, with a fresh seed: the first deal, a
## rematch, or the next game of a ranked match, which skips the pick checks and keeps any seat away
## that was away between games. A ranked match locks its picks and draws its id at the first deal,
## and keeps each seat's token for the whole match.
func _deal(room: DuelRoom) -> void:
	room.phase = DuelRoom.Phase.DUEL
	room.deal_ready = [false, false]
	room.rematch = [false, false]
	room.next_ready = [false, false]
	room.next_deal_msec = 0
	room.seed_value = _deal_seed()
	if room.ranked:
		if room.game == 0:
			room.series_locked = true
			room.match_id = _crypto.generate_random_bytes(8).hex_encode()
		room.game += 1
	for seat in range(2):
		if not room.ranked or room.tokens[seat] == "":
			room.tokens[seat] = _crypto.generate_random_bytes(TOKEN_BYTES).hex_encode()
	for seat in range(2):
		var args: Array = _deal_args(room)
		args.append(room.tokens[seat])
		if room.ranked:
			_tell(room.seat_peer[seat], &"_rpc_series", [room.best_of, room.game, [room.wins[0], room.wins[1]]])
		_tell(room.seat_peer[seat], &"_rpc_start", args)
	room_started.emit(room.code)


## What `_rpc_start` and `_rpc_resume` tell a seat about the deal: both decks by index and name,
## both seats' names as the room shows them (`DuelRoom.shown_name`), the seat colours.
static func _deal_args(room: DuelRoom) -> Array:
	return [int(room.lobby[0]["deck"]), int(room.lobby[1]["deck"]), str(room.lobby[0]["deck_name"]),
		str(room.lobby[1]["deck_name"]), room.shown_name(0), room.shown_name(1), room.color_seed]


## Server: a seed nobody can work out from what else the server sends, since every seed reaches
## both players in the match record once its game is over. From `Crypto`, like the room codes and
## seat colours. 53 bits, so no opening hand narrows it to a searchable few, and the record's JSON
## still reads it back exactly.
func _deal_seed() -> int:
	return maxi(1, _crypto.generate_random_bytes(8).decode_u64(0) & MatchRecord.JSON_INT_MAX)


## Server: the cosmetic seat-colour roll a room shares with both players. From `Crypto` like the
## codes, so what one room is sent says nothing about another room's code.
func _color_seed() -> int:
	return 1 + _crypto.generate_random_bytes(4).decode_u32(0) % 2147483646


## Server: the rules finished the room's duel, `winner` by `reason`. The room stays for a rematch or
## the lobby. A ranked match not yet decided waits for its next game instead, and both players hear
## where the match stands.
func room_duel_over(code: String, winner: int = -1, reason: String = "") -> void:
	var room: DuelRoom = rooms.get(code, null)
	if room != null and room.phase == DuelRoom.Phase.DUEL:
		settle_game(room, winner, reason)
		room.rematch = [false, false]
		if room.ranked and room.match_result.is_empty():
			_between(room)
		else:
			room.phase = DuelRoom.Phase.OVER
		_tell_series(room)
		if room.phase == DuelRoom.Phase.OVER:
			_let_away_go(room)


# --- Ranked matches (server) ------------------------------------------------

## Server, ranked: one game's result counted into its match, once per game, before either player
## hears it. The match is decided by a second win, by a game lost "left" or "timeout" or ended
## "abandoned", or by a player conceding the match (`DuelRoom.leaving`), who loses it with the
## match's reason "concede_match" while the game's stays "concede". The rating then applies once, on
## the match's winner; a match with no winner is unrated.
func settle_game(room: DuelRoom, winner: int, reason: String) -> void:
	if not room.ranked or room.settled_game == room.game:
		return
	room.settled_game = room.game
	if winner >= 0:
		room.wins[winner] += 1
		room.last_loser = 1 - winner
	_server_log("room %s: game %d to %s (%s), series %d-%d" % [room.code, room.game,
		"nobody" if winner < 0 else "seat %d" % (winner + 1), reason, room.wins[0], room.wins[1]])
	if room.leaving < 0 and not MATCH_ENDERS.has(reason) and not (winner >= 0 and room.wins[winner] * 2 > room.best_of):
		return
	var match_winner: int = 1 - room.leaving if room.leaving >= 0 else winner
	room.match_result = {"winner": match_winner, "wins": [room.wins[0], room.wins[1]],
		"reason": "concede_match" if room.leaving >= 0 else reason}
	room.rating_change = _rate_match(room, match_winner)


## Server, ranked: the rating change of a decided match, per seat {"before", "after"}, or [] when it
## is not rated: no winner, no ratings file, or the same identity in both seats.
func _rate_match(room: DuelRoom, winner: int) -> Array:
	var ids: Array[String] = [room.seat_identity[0], room.seat_identity[1]]
	var outcome: String = "match to %s, %d-%d (%s)" % ["nobody" if winner < 0 else "seat %d" % (winner + 1),
		room.wins[0], room.wins[1], str(room.match_result["reason"])]
	var change: Dictionary = {}
	if winner >= 0 and ratings != null:
		change = ratings.apply(ids[winner], ids[1 - winner], int(Time.get_unix_time_from_system()))
	if change.is_empty():
		_server_log("room %s: %s, unrated" % [room.code, outcome])
		return []
	var out: Array = [{}, {}]
	out[winner] = {"before": change["winner"]["before"], "after": change["winner"]["after"]}
	out[1 - winner] = {"before": change["loser"]["before"], "after": change["loser"]["after"]}
	var moves: PackedStringArray = PackedStringArray()
	for seat in range(2):
		var before: Dictionary = out[seat]["before"]
		var after: Dictionary = out[seat]["after"]
		moves.append("seat %d mu %.2f sigma %.2f -> %.2f %.2f, shown %d -> %d" % [seat + 1, float(before["mu"]),
			float(before["sigma"]), float(after["mu"]), float(after["sigma"]), Rating.shown(float(before["mu"]), float(before["sigma"])),
			Rating.shown(float(after["mu"]), float(after["sigma"]))])
	_server_log("room %s: %s; %s" % [room.code, outcome, "; ".join(moves)])
	if str(change.get("problem", "")) != "":
		_server_log("ratings: %s not written: %s" % [RatingsStore.FILE, str(change["problem"])])
	return out


## Server, ranked: a game is over and the match is not. The next game is dealt NEXT_GAME_MS on, or
## once both players are ready.
func _between(room: DuelRoom) -> void:
	room.phase = DuelRoom.Phase.BETWEEN
	room.next_ready = [false, false]
	room.next_deal_msec = maxi(1, Time.get_ticks_msec() + NEXT_GAME_MS)


## Server, ranked: after a game's result, both players hear where the match stands: the score and
## when the next game comes between games, or once the match is decided, its result and ratings.
func _tell_series(room: DuelRoom) -> void:
	if not room.ranked:
		return
	for seat in range(2):
		if room.phase == DuelRoom.Phase.BETWEEN:
			_tell(room.seat_peer[seat], &"_rpc_game_over", [room.game, [room.wins[0], room.wins[1]], roundi(NEXT_GAME_MS / 1000.0)])
		elif not room.match_result.is_empty():
			_tell(room.seat_peer[seat], &"_rpc_match_over", [match_payload(room, seat)])


## Server, ranked: what `_rpc_match_over` tells `seat` about its decided match. Both seats' shown
## ratings, before and after, and whether each is still provisional; mu and sigma only of its own.
## An unrated match shows the ratings as they stand.
func match_payload(room: DuelRoom, seat: int) -> Dictionary:
	var shown_before: Array[int] = [0, 0]
	var shown_after: Array[int] = [0, 0]
	var provisional: Array[bool] = [true, true]
	var own: Array[Dictionary] = [Rating.fresh(), Rating.fresh()]
	for s in range(2):
		var now_rated: Dictionary = ratings.get_or_new(room.seat_identity[s]) if ratings != null else Rating.fresh()
		var before: Dictionary = {"mu": now_rated["mu"], "sigma": now_rated["sigma"]}
		var after: Dictionary = before
		if room.rating_change.size() == 2:
			before = room.rating_change[s]["before"]
			after = room.rating_change[s]["after"]
		shown_before[s] = Rating.shown(float(before["mu"]), float(before["sigma"]))
		shown_after[s] = Rating.shown(float(after["mu"]), float(after["sigma"]))
		provisional[s] = Rating.provisional(float(after["sigma"]))
		if s == seat:
			own = [{"mu": float(before["mu"]), "sigma": float(before["sigma"])}, {"mu": float(after["mu"]), "sigma": float(after["sigma"])}]
	return {"winner": int(room.match_result["winner"]), "wins": [room.wins[0], room.wins[1]],
		"reason": str(room.match_result["reason"]), "rated": room.rating_change.size() == 2,
		"shown_before": shown_before, "shown_after": shown_after, "provisional": provisional,
		"rating_before": own[0], "rating_after": own[1]}


## Server, ranked: a seat's player gives up the whole match, a concession of the match and not a
## leave: the match ends "concede_match". During a game that game is conceded; between games the
## match ends on the next game, recorded as conceded before it was dealt.
func _leave_match(room: DuelRoom, seat: int) -> void:
	room.leaving = seat
	_server_log("room %s: seat %d left the match" % [room.code, seat + 1])
	_end_room(room, 1 - seat, "concede")


## Server: a leave, held against the seat's identity (`Conduct`), with the cooldown it earned in the
## journal.
func _note_leave(room: DuelRoom, seat: int, what: String) -> void:
	var who: String = room.seat_identity[seat]
	if conduct == null or who == "":
		_server_log("room %s: seat %d %s, a leave with nobody to hold it against" % [room.code, seat + 1, what])
		return
	var cost: int = conduct.leave(who, int(Time.get_unix_time_from_system()))
	_server_log("room %s: seat %d (%s) %s, a leave: %s" % [room.code, seat + 1, Identity.short(who), what,
		"a warning" if cost == 0 else "out of the queues for %s" % Conduct.wait_text(cost)])


## Server: each seat gets the room's lobby as it may see it.
func _send_lobby(room: DuelRoom) -> void:
	var reveal: bool = room.both_locked()
	for seat in range(2):
		_tell(room.seat_peer[seat], &"_rpc_lobby", [lobby_for(room.lobby, seat, reveal, room.kind == "queue"), room.filled(), room.color_seed])


## What one seat may see of the lobby: its own entry, and the other seat's name and lock but not
## its deck until both seats have locked. With `hide_names` (a queue room) the other seat's name is
## its stock one.
static func lobby_for(full: Array[Dictionary], seat: int, reveal: bool, hide_names: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(full.size()):
		var entry: Dictionary = full[i].duplicate()
		if i != seat and not reveal:
			entry["deck"] = -1
			entry["deck_name"] = ""
		if i != seat and hide_names:
			entry["name"] = DuelRoom.empty_pick(i)["name"]
		out.append(entry)
	return out


## Server: a room's DuelHost sends a remote seat its update through this, bound to the code.
func send_room_update(seat: int, update: Dictionary, code: String) -> void:
	var room: DuelRoom = rooms.get(code, null)
	if room != null and room.seat_peer[seat] != 0:
		_send_packed(room.seat_peer[seat], update)


## Server: each seat's copy of a finished game, in one message. Refused while that game runs, so
## the seed and the commands never reach a player before its result, and above the size cap. The
## room must be over or between ranked games, or `game` must be an earlier game of its match.
## True when it went out to whoever is still seated.
func send_record(code: String, text: String, game: int = 0) -> bool:
	var room: DuelRoom = rooms.get(code, null)
	if not is_server() or room == null or text.to_utf8_buffer().size() > RECORD_MAX_BYTES:
		return false
	if room.phase != DuelRoom.Phase.OVER and room.phase != DuelRoom.Phase.BETWEEN \
			and not (room.ranked and game > 0 and game < room.game):
		return false
	for peer in room.seat_peer:
		_tell(peer, &"_rpc_record", [text])
	return true


@rpc("authority", "call_remote", "reliable")
func _rpc_record(text: Variant) -> void:
	_on_record(multiplayer.get_remote_sender_id(), text)


## Client of the server: the server's signed copy of the game that just ended, kept in the last
## `MatchRecord.CLIENT_KEEP` lines of `online.jsonl`. Anything oversized, unparsable, not from the
## server or not signed is dropped.
func _on_record(sender: int, text: Variant) -> void:
	if sender != HOST_ID or mode != "client" or not _via_server or not (text is String):
		return
	# A record comes only once the game has a result, however it ended. A ranked match goes on.
	if not ranked_room() or _match_over:
		RejoinFile.clear()
	var body: String = text
	if body.to_utf8_buffer().size() > RECORD_MAX_BYTES:
		note("record refused: too large")
		return
	var json: JSON = JSON.new()
	if json.parse(body) != OK:
		note("record refused: not JSON")
		return
	var record: MatchRecord = MatchRecord.from_dict(json.data)
	if record == null or record.origin != "server":
		note("record refused: %s" % (MatchRecord.problem_of(json.data) if record == null else "not from the server"))
		return
	var kept: String = MatchRecord.keep_line(MatchRecord.ONLINE_FILE, record.line())
	note("record %s written" % record.id if kept == "" else "record %s failed: %s" % [record.id, kept])


func reject_room_command(seat: int, reason: String, code: String) -> void:
	var room: DuelRoom = rooms.get(code, null)
	if room != null:
		_tell(room.seat_peer[seat], &"_rpc_reject", [reason])


# --- Lobby ----------------------------------------------------------------

## The local seat picked a deck (index into Session.decks), changed its name, or locked in.
func set_local_pick(deck_index: int, player_name: String, ready: bool = false) -> void:
	if local_player < 0:
		return
	var deck_name: String = ""
	if deck_index >= 0 and deck_index < Session.decks.size():
		deck_name = Session.decks[deck_index].name
	var clean: String = clean_name(player_name, local_player)
	_apply_pick(local_player, deck_index, deck_name, clean, ready and deck_index >= 0)
	if is_host():
		_send_joiner_lobby()
	elif mode == "client":
		_rpc_lobby_pick.rpc_id(HOST_ID, deck_index, deck_name, clean, ready)


func _apply_pick(seat: int, deck_index: int, deck_name: String, player_name: String, ready: bool) -> void:
	if seat < 0 or seat >= lobby.size() or not _valid_lobby_pick(deck_index, deck_name, ready):
		return
	lobby[seat] = {"name": player_name, "deck": deck_index, "deck_name": deck_name, "ready": ready}
	lobby_changed.emit()


## Authorities validate the shared catalog before accepting readiness or indexing a deck.
func valid_deck_pick(deck_index: int, deck_name: String) -> bool:
	# A tournament-legal deck only: this is where an adventure-only (banned) card is kept out of online play.
	return deck_index >= 0 and deck_index < Session.decks.size() \
		and Session.decks[deck_index].name == deck_name \
		and Session.decks[deck_index].mode != "adventure" \
		and Session.deck_problems(Session.decks[deck_index]).is_empty()


func _valid_lobby_pick(deck_index: int, deck_name: String, ready: bool) -> bool:
	return valid_deck_pick(deck_index, deck_name) or (deck_index == -1 and deck_name == "" and not ready)


## Hosting client: the joiner's view of the lobby.
func _send_joiner_lobby() -> void:
	if is_host() and peer_id != 0:
		_tell(peer_id, &"_rpc_lobby", [lobby_for(lobby, 1, both_locked()), true, Session.color_seed])


@rpc("any_peer", "call_remote", "reliable")
func _rpc_lobby_pick(deck_index: Variant, deck_name: Variant, player_name: Variant, ready: Variant) -> void:
	_on_lobby_pick(multiplayer.get_remote_sender_id(), deck_index, deck_name, player_name, ready)


## A seat's pick, from the client that plays it; the seat is the sender's, never one it names. The
## server files it in the sender's room and sends each seat the lobby it may see; a hosting client
## takes it from its joiner.
func _on_lobby_pick(sender: int, deck_index: Variant, deck_name: Variant, player_name: Variant, ready: Variant) -> void:
	if not is_authority():
		return
	var room: DuelRoom = _room_of(sender) if is_server() else null
	var seat: int = room.seat_of(sender) if room != null else seat_of(sender)
	if seat < 0:
		_refuse(null, sender, "a pick while queued" if _queue_holding(sender) != null else "a pick from a peer without a seat")
		return
	if room != null and room.series_locked:
		_refuse(room, sender, "a pick in a locked ranked match")
		return
	if not (deck_index is int and deck_name is String and player_name is String and ready is bool):
		_refuse(room, sender, "a malformed pick")
		return
	if (room != null and room.phase != DuelRoom.Phase.LOBBY) or (room == null and _in_duel):
		_refuse(room, sender, "a pick after the deal")
		return
	var index: int = deck_index
	var deck: String = deck_name
	var locked: bool = bool(ready) and index >= 0
	if not _valid_lobby_pick(index, deck, locked):
		_refuse(room, sender, "a deck that is not in the catalog")
		_tell(sender, &"_rpc_room_failed", ["Your deck list differs from the one on %s. Both need the same build of the game." % ("the duel server" if is_server() else "the host")])
		return
	var entry: Dictionary = {"name": clean_name(str(player_name), seat), "deck": index, "deck_name": deck, "ready": locked}
	# Both decks are shown once both seats lock, so from then on neither may change its pick.
	if room != null and room.both_locked():
		if entry != room.lobby[seat]:
			_refuse(room, sender, "a pick change after both seats locked")
		return
	if room != null:
		room.lobby[seat] = entry
		if not locked:
			room.deal_ready = [false, false]
		if room.kind == "queue" and room.both_locked():
			var waited: int = QUEUE_PICK_MS - (room.pick_deadline_msec - Time.get_ticks_msec())
			room.pick_deadline_msec = 0
			room.deal_at_msec = maxi(1, Time.get_ticks_msec() + QUEUE_BEAT_MS)
			_server_log("room %s: both locked in after %d s, dealing in %d s" % [room.code, _secs(maxi(0, waited)), _secs(QUEUE_BEAT_MS)])
		_send_lobby(room)
		return
	lobby[seat] = entry
	lobby_changed.emit()
	_send_joiner_lobby()


@rpc("authority", "call_remote", "reliable")
func _rpc_lobby(full: Variant, filled: Variant, color_seed: Variant) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	_on_lobby(full, filled, color_seed)


## Client: the lobby from the authority, every entry type-checked.
func _on_lobby(full: Variant, filled: Variant, color_seed: Variant) -> void:
	if mode != "client" or not (full is Array and filled is bool and color_seed is int):
		return
	var entries: Array = full
	for i in range(mini(2, entries.size())):
		lobby[i] = _checked_pick(entries[i], i)
	if int(color_seed) != 0:
		Session.color_seed = color_seed
	_other_present = filled
	if _other_present:
		lobby_notice = ""
	if queue_room() and deal_at == 0 and both_locked():
		deal_at = Time.get_ticks_msec() + QUEUE_BEAT_MS
		queue_state = "matchup"
	lobby_changed.emit()


## One lobby entry from the wire. A malformed one reads as an empty seat, and a deck this build
## does not know as no deck.
func _checked_pick(raw: Variant, seat: int) -> Dictionary:
	var out: Dictionary = DuelRoom.empty_pick(seat)
	if not (raw is Dictionary):
		return out
	var entry: Dictionary = raw
	var player_name: Variant = entry.get("name")
	var deck: Variant = entry.get("deck")
	var deck_name: Variant = entry.get("deck_name")
	var ready: Variant = entry.get("ready")
	if not (player_name is String and deck is int and deck_name is String and ready is bool):
		return out
	out["name"] = clean_name(str(player_name), seat)
	out["ready"] = ready
	if valid_deck_pick(deck, deck_name):
		out["deck"] = deck
		out["deck_name"] = deck_name
	return out


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
		str(lobby[0]["deck_name"]), str(lobby[1]["deck_name"]), str(lobby[0]["name"]), str(lobby[1]["name"]),
		Session.color_seed, "")


## Server room: this client has had the matchup up long enough. The server deals once both
## seats have said so.
func ready_to_deal() -> void:
	if server_room() and not queue_room():
		note("matchup shown, the server may deal")
		_rpc_deal_ready.rpc_id(HOST_ID)


## Ask for a rematch. A hosting client deals one at once with a fresh seed. In a server room the
## other seat hears the request through `rematch_requested`, and the server deals, on the same
## picks with a fresh seed, once both seats have asked.
func rematch() -> void:
	if is_host():
		Session.seed_value = 0
		Session.roll_colors()   # a new battle, so new seat colours; _rpc_start carries them
		start_duel()
	elif server_room():
		_rpc_rematch.rpc_id(HOST_ID)


## Both clients return to the lobby. A hosting client sends them; in a server room either seat
## can ask once the duel is over, and the room keeps its code.
func back_to_lobby() -> void:
	if is_host():
		Session.roll_colors()
		_rpc_to_lobby.rpc(Session.color_seed)
	elif server_room():
		_rpc_back_to_lobby.rpc_id(HOST_ID)


## Give up the duel in progress. The authority ends it with the other seat as the winner, and
## both sides hear `duel_ended(winner, "concede")`. In a ranked match that loses this game only, and
## the seat's rejoin file stays for the next.
func concede() -> void:
	if mode == "client":
		_rpc_concede.rpc_id(HOST_ID)
		if not ranked_room():
			RejoinFile.clear()
	elif is_host():
		_end_hosted_duel(1 - local_player, "concede")


## Ranked, between games: this player is ready for the next game. The server deals it once both
## are, or when its wait is over.
func next_game_ready() -> void:
	if ranked_room() and not _match_over:
		note("ready for the next game")
		_rpc_next_ready.rpc_id(HOST_ID)


## Ranked: give up the whole match, during a game or between games. The other player wins it as a
## concession, which is not a leave: `match_over` says "concede_match", and during a game
## `duel_ended` says "concede" first.
func leave_match() -> void:
	if ranked_room() and not _match_over:
		_rpc_leave_match.rpc_id(HOST_ID)
		RejoinFile.clear()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_deal_ready() -> void:
	_on_deal_ready(multiplayer.get_remote_sender_id())


func _on_deal_ready(sender: int) -> void:
	var room: DuelRoom = _sender_room(sender, "a deal request")
	if room == null:
		return
	if room.phase != DuelRoom.Phase.LOBBY or not room.both_locked() or room.kind == "queue":
		_refuse(room, sender, "a deal request outside a share-code lobby with both seats locked")
		return
	room.deal_ready[room.seat_of(sender)] = true
	if room.deal_ready[0] and room.deal_ready[1]:
		_start_room(room)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_rematch() -> void:
	_on_rematch(multiplayer.get_remote_sender_id())


func _on_rematch(sender: int) -> void:
	var room: DuelRoom = _sender_room(sender, "a rematch request")
	if room == null:
		return
	if room.ranked:
		_refuse(room, sender, "a rematch request in a ranked room")
		return
	if room.phase != DuelRoom.Phase.OVER or not room.filled():
		_refuse(room, sender, "a rematch request without a finished duel for two")
		return
	var seat: int = room.seat_of(sender)
	room.rematch[seat] = true
	_tell(room.other_peer(seat), &"_rpc_rematch_requested", [seat])
	if room.rematch[0] and room.rematch[1]:
		_server_log("room %s: rematch" % room.code)
		room.phase = DuelRoom.Phase.LOBBY
		room.color_seed = _color_seed()
		_start_room(room)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_back_to_lobby() -> void:
	_on_back_to_lobby(multiplayer.get_remote_sender_id())


func _on_back_to_lobby(sender: int) -> void:
	var room: DuelRoom = _sender_room(sender, "a return to the lobby")
	if room == null:
		return
	if room.phase != DuelRoom.Phase.OVER or room.kind == "queue":
		_refuse(room, sender, "a return to the lobby outside a finished share-code duel")
		return
	room.phase = DuelRoom.Phase.LOBBY
	room.rematch = [false, false]
	room.deal_ready = [false, false]
	room.color_seed = _color_seed()
	for entry in room.lobby:
		entry["ready"] = false
	if not room.filled():
		room.alone_since = maxi(1, Time.get_ticks_msec())
	_server_log("room %s: back to the lobby" % room.code)
	for peer in room.seat_peer:
		_tell(peer, &"_rpc_to_lobby", [room.color_seed])
	_send_lobby(room)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_concede() -> void:
	_on_concede(multiplayer.get_remote_sender_id())


func _on_concede(sender: int) -> void:
	if is_host():
		if seat_of(sender) == 1:
			_end_hosted_duel(0, "concede")
		return
	var room: DuelRoom = _sender_room(sender, "a concession")
	if room == null:
		return
	if room.phase != DuelRoom.Phase.DUEL:
		_refuse(room, sender, "a concession outside a duel")
		return
	var seat: int = room.seat_of(sender)
	_server_log("room %s: seat %d conceded" % [room.code, seat + 1])
	_end_room(room, 1 - seat, "concede")


@rpc("any_peer", "call_remote", "reliable")
func _rpc_next_ready() -> void:
	_on_next_ready(multiplayer.get_remote_sender_id())


## Server, ranked between games: a seat is ready for the next game, which is dealt at once when the
## other seat is too.
func _on_next_ready(sender: int) -> void:
	var room: DuelRoom = _sender_room(sender, "a next-game request")
	if room == null:
		return
	if room.phase != DuelRoom.Phase.BETWEEN:
		_refuse(room, sender, "a next-game request outside a ranked match between games")
		return
	room.next_ready[room.seat_of(sender)] = true
	if room.next_ready[0] and room.next_ready[1]:
		_server_log("room %s: both ready, dealing game %d" % [room.code, room.game + 1])
		_deal(room)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_leave_match() -> void:
	_on_leave_match(multiplayer.get_remote_sender_id())


## Server, ranked: a seat gives up the whole match, during a game or between games.
func _on_leave_match(sender: int) -> void:
	var room: DuelRoom = _sender_room(sender, "a leave of the match")
	if room == null:
		return
	if not room.ranked or (room.phase != DuelRoom.Phase.DUEL and room.phase != DuelRoom.Phase.BETWEEN):
		_refuse(room, sender, "a leave of the match outside a ranked match")
		return
	_leave_match(room, room.seat_of(sender))


## Server: a room's duel lost on the clock (`DuelHost.timed_out`, bound to the code). It ends the way
## a concession does; the host has already written the record.
func end_room_duel(winner: int, reason: String, code: String) -> void:
	var room: DuelRoom = rooms.get(code, null)
	if not is_server() or room == null or room.phase != DuelRoom.Phase.DUEL:
		return
	if winner < 0:
		_server_log("room %s: both clocks ran out at the same moment, no winner" % room.code)
	elif reason == "left":
		_server_log("room %s: seat %d ran out of time while away" % [room.code, 2 - winner])
	else:
		_server_log("room %s: seat %d ran out of time" % [room.code, 2 - winner])
	_end_room(room, winner, reason)


## Server: the room's duel is over outside the rules. A ranked game is counted into its match first
## (and the match rated once decided), then `room_ended` goes, so the record is written before either
## player hears the result. A duel lost "left" in a queue room is a leave for the seat that left.
## A ranked match not yet decided waits for its next game; otherwise a seat still away is given up.
## A ranked match left between games ends on its next game, never dealt, and nobody hears a game
## result, only the match's.
func _end_room(room: DuelRoom, winner: int, reason: String) -> void:
	var unplayed: bool = room.phase == DuelRoom.Phase.BETWEEN
	if unplayed:
		room.game += 1
		room.seed_value = _deal_seed()
	settle_game(room, winner, reason)
	if room.ranked and room.match_result.is_empty():
		_between(room)
	else:
		room.phase = DuelRoom.Phase.OVER
	room_ended.emit(room.code, winner, reason)
	if reason == "left" and winner >= 0 and room.kind == "queue":
		_note_leave(room, 1 - winner, "left the duel")
	if not unplayed:
		for peer in room.seat_peer:
			_tell(peer, &"_rpc_duel_ended", [winner, reason])
	_tell_series(room)
	if room.phase == DuelRoom.Phase.OVER:
		_let_away_go(room)


## Hosting client: the duel ends outside the rules; the joiner's commands are dropped from here on.
func _end_hosted_duel(winner: int, reason: String) -> void:
	if not _in_duel or _duel_over:
		return
	_duel_over = true
	_tell(peer_id, &"_rpc_duel_ended", [winner, reason])
	last_duel_ended = {"winner": winner, "reason": reason}
	duel_ended.emit(winner, reason)


@rpc("authority", "call_remote", "reliable")
func _rpc_duel_ended(winner: int, reason: String) -> void:
	_on_duel_ended(multiplayer.get_remote_sender_id(), winner, reason)


## Client: the duel ended outside the rules, kept in `last_duel_ended`. A ranked match keeps its
## rejoin file for the next game.
func _on_duel_ended(sender: int, winner: int, reason: String) -> void:
	if sender != HOST_ID or winner < -1 or winner > 1:
		return
	if not ranked_room():
		RejoinFile.clear()
	last_duel_ended = {"winner": winner, "reason": reason}
	duel_ended.emit(winner, reason)


# --- Ranked matches (client) ------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _rpc_series(best_of: Variant, game: Variant, wins: Variant) -> void:
	_on_series(multiplayer.get_remote_sender_id(), best_of, game, wins)


## Client of the server: this seat's room plays a ranked match, now on game `game` with `wins` so
## far. Sent before each deal and before a rejoin's resume.
func _on_series(sender: int, best_of: Variant, game: Variant, wins: Variant) -> void:
	var score: Array[int] = _clean_wins(wins)
	if sender != HOST_ID or mode != "client" or not _via_server or not (best_of is int and game is int) or score.is_empty():
		return
	if int(game) < 1 or int(game) > MatchRecord.MAX_GAMES:
		return
	_ranked = true
	_match_over = false
	series_game = game
	series_wins = score
	next_game_at = 0
	note("ranked match, game %d of %d, %d-%d" % [int(game), int(best_of), score[0], score[1]])


@rpc("authority", "call_remote", "reliable")
func _rpc_game_over(game: Variant, wins: Variant, next_in_s: Variant) -> void:
	_on_game_over(multiplayer.get_remote_sender_id(), game, wins, next_in_s)


## Client, ranked: a game of the match is over and the match is not.
func _on_game_over(sender: int, game: Variant, wins: Variant, next_in_s: Variant) -> void:
	var score: Array[int] = _clean_wins(wins)
	if sender != HOST_ID or mode != "client" or not _via_server or not (game is int and next_in_s is int) or score.is_empty():
		return
	var wait_s: int = clampi(next_in_s, 0, 600)
	var now: int = Time.get_ticks_msec()
	_ranked = true
	series_game = clampi(game, 1, MatchRecord.MAX_GAMES)
	series_wins = score
	next_game_at = now + wait_s * 1000
	last_game_over = {"game": series_game, "wins": [score[0], score[1]], "next_in_s": wait_s, "at_msec": now}
	_renew_rejoin()
	note("game %d over, %d-%d, next game in %d s" % [series_game, score[0], score[1], wait_s])
	game_over.emit(series_game, [score[0], score[1]], wait_s)


@rpc("authority", "call_remote", "reliable")
func _rpc_match_over(payload: Variant) -> void:
	_on_match_over(multiplayer.get_remote_sender_id(), payload)


## Client, ranked: the match is decided. Every field is checked, the payload is kept in `last_match`,
## the seat's rejoin file goes, and the rating this seat now shows is kept.
func _on_match_over(sender: int, payload: Variant) -> void:
	if sender != HOST_ID or mode != "client" or not _via_server or not (payload is Dictionary):
		return
	var clean: Dictionary = clean_match_payload(payload)
	if clean.is_empty():
		note("match result refused: malformed")
		return
	_ranked = true
	_match_over = true
	series_wins = [int(clean["wins"][0]), int(clean["wins"][1])]
	next_game_at = 0
	last_match = clean
	RejoinFile.clear()
	note("match over, %d-%d (%s)%s" % [series_wins[0], series_wins[1], str(clean["reason"]), ", rated" if bool(clean["rated"]) else ", unrated"])
	match_over.emit(clean)
	if local_player >= 0 and local_player <= 1:
		var after: Dictionary = clean["rating_after"]
		_keep_rating(int(clean["shown_after"][local_player]), bool(clean["provisional"][local_player]),
			float(after["mu"]), float(after["sigma"]))


@rpc("authority", "call_remote", "reliable")
func _rpc_rating(shown: Variant, provisional: Variant, mu: Variant, sigma: Variant) -> void:
	_on_rating(multiplayer.get_remote_sender_id(), shown, provisional, mu, sigma)


## Client of the server: this install's ranked rating, sent after the greeting.
func _on_rating(sender: int, shown: Variant, provisional: Variant, mu: Variant, sigma: Variant) -> void:
	if sender != HOST_ID or mode != "client" or not _via_server:
		return
	if not (shown is int and provisional is bool and (mu is float or mu is int) and (sigma is float or sigma is int)):
		return
	if int(shown) < 0 or not is_finite(float(mu)) or not is_finite(float(sigma)) or float(sigma) <= 0.0:
		return
	_keep_rating(shown, provisional, float(mu), float(sigma))


func _keep_rating(shown: int, provisional: bool, mu: float, sigma: float) -> void:
	rating = {"shown": shown, "provisional": provisional, "mu": mu, "sigma": sigma}
	note("ranked rating %d%s" % [shown, ", provisional" if provisional else ""])
	rating_known.emit(shown, provisional)


## A match result from the wire with every field checked, in the shape `match_over` hands on, or {}.
static func clean_match_payload(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var winner: Variant = d.get("winner")
	var reason: Variant = d.get("reason")
	var rated: Variant = d.get("rated")
	var wins: Array[int] = _clean_wins(d.get("wins"))
	if not (winner is int and reason is String and rated is bool) or wins.is_empty():
		return {}
	if int(winner) < -1 or int(winner) > 1 or not MatchRecord.MATCH_REASONS.has(reason):
		return {}
	var out: Dictionary = {"winner": winner, "wins": wins, "reason": reason, "rated": rated}
	for key in ["shown_before", "shown_after"]:
		var pair: Variant = d.get(key)
		if not (pair is Array and (pair as Array).size() == 2 and (pair as Array)[0] is int and (pair as Array)[1] is int):
			return {}
		if int((pair as Array)[0]) < 0 or int((pair as Array)[1]) < 0:
			return {}
		out[key] = [int((pair as Array)[0]), int((pair as Array)[1])]
	var flags: Variant = d.get("provisional")
	if not (flags is Array and (flags as Array).size() == 2 and (flags as Array)[0] is bool and (flags as Array)[1] is bool):
		return {}
	out["provisional"] = [bool((flags as Array)[0]), bool((flags as Array)[1])]
	for key in ["rating_before", "rating_after"]:
		var own: Variant = d.get(key)
		if not (own is Dictionary):
			return {}
		var mu: Variant = (own as Dictionary).get("mu")
		var sigma: Variant = (own as Dictionary).get("sigma")
		if not ((mu is float or mu is int) and (sigma is float or sigma is int)) or not is_finite(float(mu)) \
				or not is_finite(float(sigma)) or float(sigma) <= 0.0:
			return {}
		out[key] = {"mu": float(mu), "sigma": float(sigma)}
	return out


## Games won per seat from the wire, [] unless two whole numbers from 0 to 3.
static func _clean_wins(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if not (raw is Array) or (raw as Array).size() != 2:
		return out
	for n: Variant in (raw as Array):
		if not (n is int) or int(n) < 0 or int(n) > MatchRecord.MAX_GAMES:
			out.clear()
			return out
		out.append(int(n))
	return out


@rpc("authority", "call_remote", "reliable")
func _rpc_rematch_requested(seat: int) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or seat < 0 or seat > 1:
		return
	rematch_requested.emit(seat)


## The deal. From the duel server `token` is this seat's rejoin secret, kept in the `RejoinFile`
## for as long as the duel runs; a hosting client sends none.
@rpc("authority", "call_local", "reliable")
func _rpc_start(deck0: int, deck1: int, name0: String, name1: String, player0: String, player1: String, color_seed: int = 0, token: String = "") -> void:
	resumed = false
	if not _take_deal(deck0, deck1, name0, name1, player0, player1, color_seed):
		return
	if _via_server and room_code != "" and token.length() == RejoinFile.TOKEN_HEX and token.is_valid_hex_number():
		_keep_rejoin(token)
	Session.go_to_duel()


## Client of the server: the seat this client asked back for with `rejoin()`. The duel scene loads
## as for a deal, and the server's next update catches it up.
@rpc("authority", "call_remote", "reliable")
func _rpc_resume(seat: int, code: String, deck0: int, deck1: int, name0: String, name1: String, player0: String, player1: String, color_seed: int) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or mode != "client" or _rejoin.is_empty() or seat < 0 or seat > 1:
		return
	_connect_deadline = 0
	_stage = ""
	_room_kind = str(_rejoin.get("kind", "code"))
	_rejoin = {}
	last_error = ""
	local_player = seat
	seat_peer = [HOST_ID, HOST_ID]
	seat_peer[seat] = 0
	room_code = code
	_other_present = true
	note("back in room %s as player %d" % [code, seat + 1])
	if not _take_deal(deck0, deck1, name0, name1, player0, player1, color_seed):
		return
	resumed = true
	RejoinFile.renew(int(Time.get_unix_time_from_system()))
	Session.go_to_duel()


@rpc("authority", "call_remote", "reliable")
func _rpc_rejoin_failed(reason: Variant) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or mode != "client":
		return
	_on_rejoin_failed(str(reason).left(300) if reason is String else REJOIN_OVER)


## Client: the server will not give the seat back, so the duel is over for this client.
func _on_rejoin_failed(reason: String) -> void:
	RejoinFile.clear()
	_fail(reason)


## Both decks by index checked against this build, the names and the seat colours of a deal, and
## updates held for the duel scene. The last game's result facts go, since this game has none yet.
## False, after `_fail`, when a deck does not match.
func _take_deal(deck0: int, deck1: int, name0: String, name1: String, player0: String, player1: String, color_seed: int) -> bool:
	_forget_results()
	var picks: Array[int] = [deck0, deck1]
	var names: Array[String] = [name0, name1]
	for i in range(2):
		if picks[i] < 0 or picks[i] >= Session.decks.size() or Session.decks[picks[i]].name != names[i]:
			_fail("Your deck list differs from the other side's. Both need the same build of the game.")
			return false
		Session.chosen[i] = Session.decks[picks[i]]
	Session.player_names = [clean_name(player0, 0), clean_name(player1, 1)]
	# The hosting client rolls its own in build_referee; a joiner has no seed, so it takes this.
	Session.color_seed = color_seed
	_pending_updates.clear()
	_hold_updates = true
	_in_duel = true
	_duel_over = false
	if _room_kind == "queue":
		queue_state = "duel"
		pick_until = 0
		deal_at = 0
	return true


## Client of the server: the seat this deal gave us, on disk until the duel's result.
func _keep_rejoin(token: String) -> void:
	var names: Array[String] = Session.seat_names()
	var problem: String = RejoinFile.write({"server": _server_address, "code": room_code, "seat": local_player,
		"token": token, "names": [names[0], names[1]],
		"decks": [Session.chosen[0].id, Session.chosen[1].id], "kind": _room_kind, "ranked": _ranked,
		"expires": int(Time.get_unix_time_from_system()) + RejoinFile.KEEP_SECONDS})
	_renewed_at = Time.get_ticks_msec()
	if problem != "":
		note("rejoin file not written: %s" % problem)


## Client of the server: a message from the server during the duel moves the rejoin file's expiry
## on, at most every REJOIN_RENEW_MS. Updates, clocks (at least once a second while one runs) and a
## ranked game's result all count, so a long decision by the other player never lets it lapse.
func _renew_rejoin() -> void:
	if _via_server and Time.get_ticks_msec() - _renewed_at >= REJOIN_RENEW_MS:
		_renewed_at = Time.get_ticks_msec()
		RejoinFile.renew(int(Time.get_unix_time_from_system()))


@rpc("authority", "call_local", "reliable")
func _rpc_to_lobby(color_seed: int = 0) -> void:
	if color_seed != 0:
		Session.color_seed = color_seed
	_in_duel = false
	_duel_over = false
	_hold_updates = false
	_pending_updates.clear()
	RejoinFile.clear()
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
	_tell(to, &"_rpc_update", [raw.size(), packed])


## Client: updates that arrived before the duel scene was listening. From here on they go
## straight to `update_received`.
func take_pending_updates() -> Array[Dictionary]:
	var out: Array[Dictionary] = _pending_updates
	_pending_updates = []
	_hold_updates = false
	return out


## A command from the wire in `Command.to_dict` shape with every field type-checked, or {} when
## anything is off: an unknown key, a wrong type, an over-long string or batch.
static func clean_command(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	for key in d.keys():
		if not (key is String) or not COMMAND_KEYS.has(key):
			return {}
	var player: Variant = d.get("player")
	var type: Variant = d.get("type")
	var card: Variant = d.get("card", -1)
	var value: Variant = d.get("value")
	if not (player is int and type is String and card is int):
		return {}
	if str(type).length() > COMMAND_STRING_MAX or not _plain_value(value):
		return {}
	return {"player": player, "type": type, "card": card, "value": value}


## A command value is nothing, a flag, a number, a short word, or a batch of card uids.
static func _plain_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_STRING:
			return str(value).length() <= COMMAND_STRING_MAX
		TYPE_ARRAY:
			var items: Array = value
			if items.size() > COMMAND_ARRAY_MAX:
				return false
			for item in items:
				if typeof(item) != TYPE_INT:
					return false
			return true
	return false


@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit(cmd: Variant) -> void:
	_on_submit(multiplayer.get_remote_sender_id(), cmd)


## A remote seat's choice, checked before the rules see it: a well-formed command, from a seated
## peer, during its duel, for the sender's own seat. The Referee still checks it is a pending option.
func _on_submit(sender: int, raw: Variant) -> void:
	if is_server():
		_room_submit(sender, raw)
		return
	var seat: int = seat_of(sender)
	var cmd: Dictionary = clean_command(raw)
	if seat < 0 or not _in_duel or _duel_over or cmd.is_empty() or int(cmd["player"]) != seat:
		return
	command_received.emit(seat, cmd)


func _room_submit(sender: int, raw: Variant) -> void:
	var room: DuelRoom = _sender_room(sender, "a command")
	if room == null:
		return
	if room.phase != DuelRoom.Phase.DUEL:
		_refuse(room, sender, "a command outside a duel")
		return
	var cmd: Dictionary = clean_command(raw)
	if cmd.is_empty():
		_refuse(room, sender, "a malformed command")
		return
	var seat: int = room.seat_of(sender)
	if int(cmd["player"]) != seat:
		_refuse(room, sender, "a command for the other seat")
		return
	room_command.emit(room.code, seat, cmd)


@rpc("authority", "call_remote", "reliable")
func _rpc_update(raw_size: int, packed: PackedByteArray) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID or raw_size <= 0 or raw_size > UPDATE_MAX_BYTES:
		return
	var raw: PackedByteArray = packed.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	var value: Variant = bytes_to_var(raw)
	if not (value is Dictionary):
		return
	var update: Dictionary = value
	note("update received, %d bytes" % raw.size())
	_renew_rejoin()
	if _hold_updates or update_received.get_connections().is_empty():
		_pending_updates.append(update)
	else:
		update_received.emit(update)


@rpc("authority", "call_remote", "reliable")
func _rpc_reject(reason: String) -> void:
	if multiplayer.get_remote_sender_id() != HOST_ID:
		return
	command_rejected.emit(reason)


# --- Decision clocks (server rooms) ---------------------------------------

## Client of the server: this seat's decision panel for a `kind` prompt is up, so the server starts
## its clock now rather than 10 seconds after the update went out.
func prompt_shown(kind: StringName) -> void:
	if server_room() and _in_duel:
		_rpc_prompt_shown.rpc_id(HOST_ID, String(kind))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_prompt_shown(kind: Variant) -> void:
	_on_prompt_shown(multiplayer.get_remote_sender_id(), kind)


func _on_prompt_shown(sender: int, kind: Variant) -> void:
	var room: DuelRoom = _sender_room(sender, "a prompt notice")
	if room == null:
		return
	if room.phase != DuelRoom.Phase.DUEL or not (kind is String) or str(kind).length() > COMMAND_STRING_MAX:
		_refuse(room, sender, "a prompt notice outside a duel")
		return
	room_prompt_shown.emit(room.code, room.seat_of(sender), str(kind))


## Server: a room's DuelHost sends a seat's clock to both players through this, bound to the code.
func send_room_clock(seat: int, left_ms: int, bank_ms: int, phase: String, code: String) -> void:
	var room: DuelRoom = rooms.get(code, null)
	if room == null or room.phase != DuelRoom.Phase.DUEL:
		return
	for peer in room.seat_peer:
		_tell(peer, &"_rpc_clock", [seat, left_ms, bank_ms, phase])


@rpc("authority", "call_remote", "reliable")
func _rpc_clock(seat: Variant, left_ms: Variant, bank_ms: Variant, phase: Variant) -> void:
	_on_clock(multiplayer.get_remote_sender_id(), seat, left_ms, bank_ms, phase)


## Client of the server: one seat's clock, type- and range-checked.
func _on_clock(sender: int, seat: Variant, left_ms: Variant, bank_ms: Variant, phase: Variant) -> void:
	if sender != HOST_ID or mode != "client" or not _via_server or not _in_duel:
		return
	if not (seat is int and left_ms is int and bank_ms is int and phase is String) or not DuelClock.PHASES.has(phase):
		return
	if int(seat) < 0 or int(seat) > 1 or int(left_ms) < 0 or int(bank_ms) < 0:
		return
	_renew_rejoin()
	clock_changed.emit(int(seat), mini(int(left_ms), DuelClock.RESERVE_MS), mini(int(bank_ms), DuelClock.BANK_MAX_MS), str(phase))


# --- Presence ---------------------------------------------------------------

## Host and client: tell the other player what this one is doing (`PresenceState`). The duel
## scene calls this only when something changed, at most 20 times a second.
func send_presence(state: Dictionary) -> void:
	if not _in_duel:
		return
	if mode == "client":
		_rpc_presence.rpc_id(HOST_ID, state)
	elif is_host() and peer_id != 0:
		_rpc_presence.rpc_id(peer_id, state)


## One presence message. The server relays it to the other seat of the sender's started room and
## a hosting client takes it from its joiner; both sanitise it first and neither hands it to the
## rules. A client takes it only from the authority, and sanitises it again.
@rpc("any_peer", "call_remote", "unreliable_ordered", PRESENCE_CHANNEL)
func _rpc_presence(raw: Variant) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if is_server():
		var room: DuelRoom = _room_of(sender)
		if room == null or room.phase == DuelRoom.Phase.LOBBY or room.seat_of(sender) < 0 or _presence_flooding(sender):
			return
		var relayed: Dictionary = PresenceState.sanitise(raw)
		if not relayed.is_empty():
			_tell(room.other_peer(room.seat_of(sender)), &"_rpc_presence", [relayed])
		return
	if not _in_duel:
		return
	if is_host():
		if sender != peer_id or peer_id == 0 or _presence_flooding(sender):
			return
	elif mode != "client" or sender != HOST_ID:
		return
	var clean: Dictionary = PresenceState.sanitise(raw)
	if not clean.is_empty():
		presence_received.emit(clean)


## A peer sending faster than any client would is dropped for the rest of that second. The budget
## is a count per second rather than a gap between messages, so a burst that network jitter
## bunched together still gets through.
func _presence_flooding(sender: int) -> bool:
	var now: int = Time.get_ticks_msec()
	var window: Array = _presence_heard.get(sender, [now, 0])
	if now - int(window[0]) >= 1000:
		window = [now, 0]
	window[1] = int(window[1]) + 1
	_presence_heard[sender] = window
	return int(window[1]) > PRESENCE_PER_SECOND
