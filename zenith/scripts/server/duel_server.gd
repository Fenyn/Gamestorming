extends Node
## The duel server: no table, no seat of its own. Players connect out to it; one opens a room
## and gets a share code, the other joins with the code, or Find a duel pairs two from its queue.
## Both pick and lock in on their own select screens, and the server deals and runs that room's
## duel behind a DuelHost with both seats remote, each decision on a clock (`DuelClock`). A seat
## whose connection drops is kept for its player to rejoin. Many rooms at once, one process. Run
## headless:
##   godot --headless --path zenith -- --server --port=7777 [--room-idle=600] [--data-dir=user://] [--keep-days=90]
##     [--host-name=eidolarch] [--no-dtls]
## `Net` owns the rooms, the queues and the wire; this script owns the rules per room, the match
## records, the DTLS certificate, and opens the ranked ratings and the leaver record for `Net`.

const DEFAULT_PORT: int = 7777
const PRUNE_EVERY_MSEC: int = 24 * 60 * 60 * 1000
## Duels running or about to be dealt from the queue, at most. At the cap the queue holds pairs
## back. A guess until the first week of journals says what the box carries.
const MAX_LIVE_DUELS: int = 100
## The certificate's common name unless `--host-name=` gives one. Clients check it against the host
## they dial, so the box runs with its public address here.
const DEFAULT_HOST_NAME: String = "eidolarch"
const CERT_FILE: String = "dtls.crt"
const CERT_KEY_FILE: String = "dtls.key"
## The name the pair was made for, since a certificate's name cannot be read back from a script.
const CERT_NAME_FILE: String = "dtls.name"
const CERT_KEY_BITS: int = 2048

var hosts: Dictionary = {}   # room code -> DuelHost
var port: int = DEFAULT_PORT
## Signs and files every finished game under `--data-dir`, kept `--keep-days`.
var match_log: MatchLog = MatchLog.new()
var _next_prune: int = 0


func _ready() -> void:
	set_process(false)
	Net.max_live_duels = MAX_LIVE_DUELS
	var data_dir: String = MatchLog.DEFAULT_DIR
	var keep_days: int = MatchLog.DEFAULT_KEEP_DAYS
	var host_name: String = DEFAULT_HOST_NAME
	var dtls: bool = true
	for arg in DevArgs.user_args():
		if arg.begins_with("--port="):
			port = int(arg.get_slice("=", 1))
		elif arg.begins_with("--room-idle="):
			Net.room_idle_seconds = maxf(1.0, float(arg.get_slice("=", 1)))
		elif arg.begins_with("--data-dir="):
			data_dir = arg.substr("--data-dir=".length())
		elif arg.begins_with("--keep-days="):
			keep_days = int(arg.get_slice("=", 1))
		elif arg.begins_with("--host-name="):
			host_name = arg.substr("--host-name=".length()).strip_edges()
		elif arg == "--no-dtls":
			dtls = false
	var trouble: String = match_log.open(data_dir, keep_days)
	if trouble != "":
		push_error("match records: " + trouble)
		get_tree().quit(1)
		return
	var ratings: RatingsStore = RatingsStore.new()
	var conduct: Conduct = Conduct.new()
	trouble = ratings.open(data_dir)
	if trouble == "":
		trouble = conduct.open(data_dir)
	if trouble != "":
		push_error("ranked: %s; move it aside to start fresh, or rebuild the ratings from the records" % trouble)
		get_tree().quit(1)
		return
	Net.ratings = ratings
	Net.conduct = conduct
	var tls: TLSOptions = null
	if dtls:
		var opened: Array = open_certificate(data_dir, host_name)
		tls = opened[0]
		if tls == null:
			push_error("DTLS certificate: " + str(opened[1]))
			get_tree().quit(1)
			return
	var problem: String = await Net.serve(port, tls)
	if problem != "":
		push_error(problem)
		get_tree().quit(1)
		return
	print("duel server listening on port %d, online protocol %d, catalog %s" % [port, Net.PROTOCOL, Net.catalog_fingerprint().left(12)])
	if dtls:
		print("DTLS on, certificate %s for %s" % [ProjectSettings.globalize_path(data_dir.path_join(CERT_FILE)), host_name])
	else:
		print("DTLS off (--no-dtls): identities and tokens travel in the clear")
	print("match records in %s, kept %d days" % [data_dir, match_log.keep_days])
	print("ranked ratings in %s (%d identities), leaves in %s" % [ratings.path, ratings.entries.size(), conduct.path])
	_prune()
	set_process(true)
	Net.room_started.connect(_on_room_started)
	Net.room_command.connect(_on_room_command)
	Net.room_ended.connect(_on_room_ended)
	Net.room_closed.connect(_on_room_closed)
	Net.room_prompt_shown.connect(_on_room_prompt_shown)
	Net.room_seat_away.connect(_on_room_seat_away)
	Net.room_rejoined.connect(_on_room_rejoined)
	$ClockTick.timeout.connect(func() -> void: tick_rooms(Time.get_ticks_msec()))
	$ClockTick.start()


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _next_prune:
		_prune()


func _prune() -> void:
	_next_prune = Time.get_ticks_msec() + PRUNE_EVERY_MSEC
	var removed: int = match_log.prune(int(Time.get_unix_time_from_system()))
	if removed > 0:
		print("match records: %d day files past %d days deleted" % [removed, match_log.keep_days])


## The server's DTLS key and self-signed certificate in `dir`, made on the first start with
## `host_name` as the common name, as [TLSOptions, ""] or [null, why not]. A later start under
## another name, or with one of the files missing or unreadable, refuses rather than make a new pair
## every shipped client would turn away. Only the certificate is meant to leave `dir`.
static func open_certificate(dir: String, host_name: String) -> Array:
	var cert_path: String = dir.path_join(CERT_FILE)
	var key_path: String = dir.path_join(CERT_KEY_FILE)
	var name_path: String = dir.path_join(CERT_NAME_FILE)
	var files: Array[String] = [CERT_FILE, CERT_KEY_FILE, CERT_NAME_FILE]
	if host_name == "" or host_name.contains(",") or host_name.contains("="):
		return [null, "--host-name must be a plain host name or address"]
	var present: int = 0
	for file in files:
		if FileAccess.file_exists(dir.path_join(file)):
			present += 1
	if present == 0:
		var crypto: Crypto = Crypto.new()
		var key: CryptoKey = crypto.generate_rsa(CERT_KEY_BITS)
		var made: X509Certificate = crypto.generate_self_signed_certificate(key, "CN=" + host_name, "20140101000000", "20491231235959")
		if key.save(key_path) != OK or made.save(cert_path) != OK:
			return [null, "cannot write the DTLS key and certificate in %s" % dir]
		var name_file: FileAccess = FileAccess.open(name_path, FileAccess.WRITE)
		if name_file == null or not name_file.store_line(host_name):
			return [null, "cannot write %s" % name_path]
		name_file.close()
		print("DTLS: made a new key and certificate for %s" % host_name)
	elif present < files.size():
		return [null, "%s holds only some of %s; restore the others, or delete all three to make a new pair (every client then needs the new certificate)" % [dir, ", ".join(files)]]
	var made_for: String = FileAccess.get_file_as_string(name_path).strip_edges()
	if made_for != host_name:
		return [null, "the certificate in %s was made for %s, not %s. Start with --host-name=%s, or delete %s to make a new pair (every client then needs the new certificate)" % [dir, made_for, host_name, made_for, ", ".join(files)]]
	var key: CryptoKey = CryptoKey.new()
	var cert: X509Certificate = X509Certificate.new()
	if key.load(key_path) != OK or key.is_public_only() or cert.load(cert_path) != OK:
		return [null, "%s or %s cannot be read" % [key_path, cert_path]]
	return [TLSOptions.server(key, cert), ""]


## Both seats locked and saw the matchup: deal from the room's picks. A rematch, and each later game
## of a ranked match, deals here again. A seat away from a ranked match between games starts the
## game away, its clock running; with both away, both clocks wait.
func _on_room_started(code: String) -> void:
	var began: int = Time.get_ticks_usec()
	var host: DuelHost = _open_duel(code)
	if host == null:
		return
	host.start()
	if host.away[0] and host.away[1]:
		host.pause_clocks(Time.get_ticks_msec())
	print("room %s: %s vs %s, seed %d, dealt in %d ms (%d duels live)" % [code, host.record.seats[0]["name"],
		host.record.seats[1]["name"], host.seed_value(), roundi((Time.get_ticks_usec() - began) / 1000.0), hosts.size()])


## The room's duel and its record, set up but not dealt; null for a room that cannot be dealt.
## Decks are shared, read-only objects; the players' names go to the engine beside them.
func _open_duel(code: String) -> DuelHost:
	var room: DuelRoom = Net.rooms.get(code)
	if room == null:
		return null
	var decks: Array[DeckList] = []
	for pick in room.lobby:
		var deck: DeckList = Net.pick_deck(pick)
		if deck == null:
			return null
		decks.append(deck)
	var referee: Referee = Referee.new()
	var names: Array[String] = seat_names([room.shown_name(0), room.shown_name(1)], decks)
	referee.setup(decks, Session.library, Session.strike_table, room.seed_value, names)
	# The loser of a ranked match's last game opens the next, whatever the rules would pick.
	if room.ranked and room.game > 1 and room.last_loser >= 0:
		referee.engine.set_first_player(room.last_loser)
	var host: DuelHost = DuelHost.new()
	host.setup(referee, [0, 1])
	host.send = Net.send_room_update.bind(code)
	host.reject = Net.reject_room_command.bind(code)
	var mode: String = "ranked" if room.ranked else ("casual" if room.kind == "queue" else "code")
	host.record = MatchRecord.begin(referee, decks, mode, "server")
	if room.ranked:
		host.record.match_id = room.match_id
		host.record.game = room.game
	for seat in range(2):
		host.record.seats[seat]["identity"] = room.seat_identity[seat]
		host.away[seat] = room.away_since[seat] > 0
		host.record.disconnects[seat] = 1 if host.away[seat] else 0
	host.record.protocol = Net.PROTOCOL
	host.record.catalog = Net.catalog_fingerprint()
	host.record.color_seed = room.color_seed
	host.on_result = _game_result.bind(code)
	host.use_clock = true
	host.clock_out = Net.send_room_clock.bind(code)
	host.timed_out = Net.end_room_duel.bind(code)
	hosts[code] = host
	return host


## Every live duel's clocks, from the `ClockTick` timer. A duel lost on the clock ends inside this
## loop through `Net.end_room_duel`, which drops its host.
func tick_rooms(now_msec: int) -> void:
	for code: String in hosts.keys():
		var host: DuelHost = hosts.get(code, null)
		if host != null:
			host.tick(now_msec)


func _on_room_prompt_shown(code: String, seat: int, kind: String) -> void:
	var host: DuelHost = hosts.get(code, null)
	if host != null:
		host.prompt_shown(seat, kind, Time.get_ticks_msec())


## A seat's connection dropped mid-duel. Its clock runs on unless both seats are now away.
func _on_room_seat_away(code: String, seat: int, both: bool) -> void:
	var host: DuelHost = hosts.get(code, null)
	if host == null:
		return
	host.away[seat] = true
	if host.record != null:
		host.record.disconnects[seat] += 1
	if both:
		host.pause_clocks(Time.get_ticks_msec())


## An away seat is back: its client gets the catch-up update and the clocks. After a double drop
## both clocks go on.
func _on_room_rejoined(code: String, seat: int, both: bool) -> void:
	var host: DuelHost = hosts.get(code, null)
	if host == null:
		return
	var now: int = Time.get_ticks_msec()
	host.away[seat] = false
	if host.record != null:
		host.record.reconnects[seat] += 1
	if both:
		host.resume_clocks(now)
	host.catch_up(seat, now)


## The names the rules use, as `Session.seat_names()` gives them on a client: a seat still on its
## stock name takes its duelist's, and a mirror match keeps the stock names so the seats read apart.
func seat_names(typed: Array[String], decks: Array[DeckList]) -> Array[String]:
	var names: Array[String] = [typed[0], typed[1]]
	var duelists: Array[String] = [Session.duelist_name(decks[0]), Session.duelist_name(decks[1])]
	if duelists[0] == duelists[1]:
		return names
	for seat in range(2):
		if duelists[seat] != "" and Session.is_stock_name(names[seat], seat):
			names[seat] = duelists[seat]
	return names


## Every game's result, as the host fills it and before either player hears it. In a ranked room
## the game is counted into its match first (`Net.settle_game`, which also applies the rating once
## the match is decided), and the deciding game's record carries the match result and both
## ratings. Then the record is signed and filed.
func _game_result(record: MatchRecord, code: String) -> void:
	var room: DuelRoom = Net.rooms.get(code, null)
	if room != null and room.ranked:
		Net.settle_game(room, int(record.result["winner"]), str(record.result["reason"]))
		if not room.match_result.is_empty():
			record.match_result = room.match_result.duplicate(true)
			for seat in range(mini(2, room.rating_change.size())):
				record.seats[seat]["rating"] = (room.rating_change[seat] as Dictionary).duplicate(true)
	match_log.write(record)


## A seat's choice. When it ends the duel, the host has already written the record inside
## `apply`, before the update carrying the result went out; the copies follow that update.
func _on_room_command(code: String, seat: int, cmd: Dictionary) -> void:
	var host: DuelHost = hosts.get(code, null)
	if host == null:
		return
	host.apply(seat, cmd)
	if host.is_over():
		var state: GameState = host.referee.engine.state
		print("room %s: over, seat %d wins" % [code, state.winner + 1])
		hosts.erase(code)
		Net.room_duel_over(code, state.winner, state.win_reason)
		_deliver(code, host.record)


## A concession, a seat that did not come back in time, a clock that ran out, or both seats away
## too long. `Net` emits this before it tells either player, so the record is written first; the
## copies go out after that message, at the end of the frame. A ranked match left between games
## ends on its next game, set up but never dealt, whose record says so.
func _on_room_ended(code: String, winner_seat: int, reason: String) -> void:
	var host: DuelHost = hosts.get(code, null)
	if host == null:
		var room: DuelRoom = Net.rooms.get(code, null)
		if room == null or not room.ranked or room.leaving < 0:
			return
		host = _open_duel(code)
		if host == null:
			return
	hosts.erase(code)
	host.end(winner_seat, reason)
	print("room %s: over, %s (%s)" % [code, "no winner" if winner_seat < 0 else "seat %d wins" % (winner_seat + 1), reason])
	_deliver.call_deferred(code, host.record)


func _deliver(code: String, record: MatchRecord) -> void:
	if record != null and record.has_result():
		Net.send_record(code, record.line(), record.game)


func _on_room_closed(code: String) -> void:
	hosts.erase(code)
