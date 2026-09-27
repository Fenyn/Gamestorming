extends SceneTree
## Queue tests use the production inbox with an explicit animation gate, so packets
## arrive during an awaited replay without depending on frame or wall-clock timing.

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _packet(id: int, seat: int) -> Dictionary:
	return {"lines": [{"type": "command", "player": seat, "id": id}]}

func _run() -> void:
	var table: Node3D = load("res://tests/fixtures/network_inbox_probe.gd").new()
	var hud: Node = table.hud
	table.authority = false
	table.viewer = 0
	table.busy = false
	table._awaiting_answer = true
	table._on_net_update(_packet(1, 1))
	table._on_net_update(_packet(2, 0))
	_check(table.played == [1], "A queued answer must not replay concurrently with the opponent animation")
	table.release_animation.emit()
	_check(table.played == [1, 2], "Our queued answer must begin immediately after the opponent animation")
	_check(not table._awaiting_answer, "Our answer must clear sending state without requiring another packet")
	table.release_animation.emit()
	_check(table._inbox.is_empty() and not table._draining_inbox and not table.busy, "The response queue must finish and release its guard")
	_check(table.presented == 1, "The answered choice must present the next prompt exactly once")
	table.authority = true
	table.played.clear()
	table._on_net_command(1, {"id": 3})
	table._on_net_command(1, {"id": 4})
	table.release_animation.emit()
	_check(table.played == [3, 4], "Authority commands arriving during replay must also drain continuously")
	table.release_animation.emit()
	_check(not table._draining_inbox and table._inbox.is_empty(), "Reentrant prompt drains must leave no stuck guard")
	table.free()
	hud.free()
	var net: Node = root.get_node("Net")
	var session: Node = root.get_node("Session")
	net.mode = "host"
	net.peer_id = 42
	net.reset_lobby()
	var valid_name: String = session.decks[0].name
	net._apply_pick(0, 0, valid_name, "Host", true)
	for bad_pick in [[session.decks.size(), valid_name], [-2, valid_name], [0, "Wrong build"]]:
		net._apply_pick(1, int(bad_pick[0]), str(bad_pick[1]), "Remote", true)
		_check(not net.both_locked(), "Invalid remote deck picks must never make the LAN lobby ready")
	net._apply_pick(1, -1, "", "Remote", false)
	_check(not net.lobby[1]["ready"], "An unselected name-only lobby update remains valid and unlocked")
	net._apply_pick(1, 0, valid_name, "Remote", true)
	_check(net.both_locked(), "Matching catalog entries must still allow both seats to lock")
	var room: DuelRoom = DuelRoom.new()
	room.code = "TEST"
	room.seat_peer = [41, 42]
	room.lobby = net.lobby.duplicate(true)
	var server: Node = load("res://scripts/server/duel_server.gd").new()
	net.rooms[room.code] = room
	for bad_pick in [[session.decks.size(), valid_name], [0, "Wrong build"]]:
		room.lobby[1]["deck"] = int(bad_pick[0])
		room.lobby[1]["deck_name"] = str(bad_pick[1])
		net._start_room(room)
		_check(room.phase == DuelRoom.Phase.LOBBY and room.seed_value == 0, "Server must reject invalid locked catalogs before dealing or announcing start")
		server._on_room_started(room.code)
		_check(server.hosts.is_empty(), "Server scene must reject an invalid room before indexing Session.decks")
	net.lobby[1]["deck"] = session.decks.size()
	_check(not net.both_locked(), "LAN start readiness must revalidate even a previously locked lobby")
	server.free()
	net.rooms.erase(room.code)
	net.mode = ""
	net.peer_id = 0
	net.reset_lobby()
	# No test may touch a player's own rejoin file or identity.
	RejoinFile.path_override = REJOIN_CLIENT_DIR.path_join("rejoin.json")
	Identity.path_override = REJOIN_CLIENT_DIR.path_join("identity.key")
	_room_tests(net, session)
	_wire_tests(net, session)
	_record_tests(net, session)
	_clock_tests(net, session)
	await _isolation_tests(net, session)
	_rejoin_tests(net, session)
	_rejoin_client_tests(net, session)
	_give_up_tests(net, session)
	await _queue_tests(net, session)
	_identity_tests(net, session)
	await _ranked_tests(net, session)
	_ranked_client_tests(net)
	await _presentation_tests(net, session)
	net.leave()
	_remove_tree(REJOIN_CLIENT_DIR)
	RejoinFile.path_override = ""
	Identity.path_override = ""
	print("Network regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


## The server's room table driven through the same handlers the RPCs call, with made-up peer ids.
## Nothing is connected, so nothing goes out; the checks read the room state.
func _room_tests(net: Node, session: Node) -> void:
	net.mode = "server"
	var commands: Array = []
	var ended: Array = []
	var on_command: Callable = func(code: String, seat: int, cmd: Dictionary) -> void: commands.append([code, seat, cmd])
	var on_ended: Callable = func(code: String, winner: int, reason: String) -> void: ended.append([code, winner, reason])
	net.room_command.connect(on_command)
	net.room_ended.connect(on_ended)
	net._on_room_request(41, "")
	_check(net.rooms.size() == 1, "A room request without a code opens a room")
	var code: String = net.rooms.keys()[0]
	var room: DuelRoom = net.rooms[code]
	_check(room.seat_peer == [41, 0] and room.alone_since > 0, "The opener takes seat 1 and the room counts as waiting")
	net._on_room_request(42, code.to_lower())
	_check(room.seat_peer == [41, 42] and room.alone_since == 0, "A joiner takes seat 2 with the code in any case")
	net._on_room_request(43, code)
	net._on_room_request(44, "ZZZZZ")
	net._on_room_request(45, 12345)
	net._on_room_request(46, "A".repeat(4000))
	_check(net.rooms.size() == 1 and room.seat_of(43) < 0, "A full room, a wrong code and malformed codes are refused")
	_check(net._refused.has(43) and net._refused.has(44) and net._refused.has(45) and net._refused.has(46), "Refused peers are marked")
	net._on_room_request(44, "")
	_check(net.rooms.size() == 1, "A refused peer cannot ask again on the same connection")
	net._on_room_request(41, "")
	_check(net.rooms.size() == 1, "A seated peer cannot open a second room")

	var pass_0: Dictionary = {"player": 0, "type": "pass", "card": -1, "value": null}
	net._on_submit(41, pass_0)
	_check(commands.is_empty(), "A command before the deal is refused")
	net._on_deal_ready(41)
	_check(room.phase == DuelRoom.Phase.LOBBY and not room.deal_ready[0], "A deal request before both seats lock in is refused")
	var deck0: String = session.decks[0].name
	var deck1: String = session.decks[1].name
	net._on_lobby_pick(41, 0, deck0, "[b]Host[/b]", true)
	net._on_lobby_pick(42, 1, deck1, "Joiner", true)
	_check(room.lobby[0]["name"] == "bHost/b" and room.lobby[1]["name"] == "Joiner", "Names are cleaned on the server")
	_check(room.both_locked(), "Two valid locked picks lock the room")
	net._on_lobby_pick(42, 2, session.decks[2].name, "Joiner", true)
	net._on_lobby_pick(42, 1, deck1, "Joiner", false)
	net._on_lobby_pick(41, 0, deck0, "Renamed", true)
	_check(room.both_locked() and room.lobby[1]["deck"] == 1 and room.lobby[0]["name"] == "bHost/b",
		"Once both seats have locked and seen each other's deck, no pick, unlock or rename is taken")
	for bad in [["0", deck0, "Host", true], [0, 5, "Host", true], [0, deck0, 7, true], [0, deck0, "Host", "yes"], [null, null, null, null]]:
		net._on_lobby_pick(41, bad[0], bad[1], bad[2], bad[3])
	_check(room.lobby[0]["deck"] == 0 and room.lobby[0]["name"] == "bHost/b" and room.lobby[0]["ready"], "Malformed picks are dropped")
	net._on_lobby_pick(99, 2, session.decks[2].name, "Stranger", true)
	_check(room.lobby[0]["deck"] == 0 and room.lobby[1]["deck"] == 1, "A pick from a peer without a seat is dropped")
	net._on_deal_ready(41)
	_check(room.phase == DuelRoom.Phase.LOBBY and room.deal_ready[0], "One seat shown the matchup does not deal")
	net._on_deal_ready(42)
	_check(room.phase == DuelRoom.Phase.DUEL and room.seed_value != 0, "Both seats shown the matchup deals")
	net._on_lobby_pick(42, 2, session.decks[2].name, "Joiner", true)
	_check(room.lobby[1]["deck"] == 1, "A pick after the deal is refused")
	net._on_deal_ready(41)
	_check(room.phase == DuelRoom.Phase.DUEL, "A deal request during the duel is refused")

	net._on_submit(41, {"player": 1, "type": "pass", "card": -1, "value": null})
	net._on_submit(99, pass_0)
	for bad in [pass_0.merged({"extra": 1}), {"player": "0", "type": "pass", "card": -1, "value": null},
			{"player": 0, "type": 3, "card": -1, "value": null}, {"player": 0, "type": "pass", "card": 1.5, "value": null},
			{"player": 0, "type": "pass", "card": -1, "value": {"nested": true}}, {"player": 0, "type": "pass", "card": -1, "value": [1, "2"]},
			{"player": 0, "type": "pass", "card": -1, "value": range(500)}, {"player": 0, "type": "x".repeat(100), "card": -1, "value": null},
			"pass", [0, "pass"], null]:
		net._on_submit(41, bad)
	_check(commands.is_empty(), "Wrong-seat, stranger and malformed commands never reach the room")
	net._on_submit(41, pass_0)
	net._on_submit(42, {"player": 1, "type": "reserve_in", "card": -1, "value": [3, 4]})
	_check(commands.size() == 2 and commands[0][1] == 0 and commands[1][1] == 1 and commands[1][2]["value"] == [3, 4], "Well-formed commands for the sender's own seat reach the room")

	net._on_rematch(41)
	net._on_back_to_lobby(41)
	_check(room.phase == DuelRoom.Phase.DUEL and room.rematch == [false, false], "Rematch and lobby requests during the duel are refused")
	net.room_duel_over(code)
	_check(room.phase == DuelRoom.Phase.OVER, "The rules finishing the duel leave the room open")
	var first_seed: int = room.seed_value
	net._on_rematch(41)
	net._on_rematch(41)
	_check(room.phase == DuelRoom.Phase.OVER and room.rematch == [true, false], "One seat asking twice does not deal a rematch")
	net._on_rematch(42)
	_check(room.phase == DuelRoom.Phase.DUEL and room.rematch == [false, false] and room.lobby[0]["deck"] == 0, "Both seats asking deals the rematch on the same picks")
	_check(room.seed_value != first_seed, "A rematch rolls a fresh seed")

	net._on_concede(41)
	_check(room.phase == DuelRoom.Phase.OVER and ended.size() == 1 and ended[0] == [code, 1, "concede"], "A concession ends the duel for the other seat")
	net._on_concede(42)
	_check(ended.size() == 1, "A concession after the duel is over is refused")
	net._on_submit(42, {"player": 1, "type": "pass", "card": -1, "value": null})
	_check(commands.size() == 2, "Commands after the duel are refused")
	net._on_back_to_lobby(42)
	_check(room.phase == DuelRoom.Phase.LOBBY and not room.lobby[0]["ready"] and not room.lobby[1]["ready"] and room.lobby[1]["deck"] == 1, "Back to the lobby keeps the room and picks, unlocked")
	_check(net.rooms.has(code) and room.seat_peer == [41, 42], "Both seats stay in the room")

	net._on_peer_disconnected(42)
	_check(net.rooms.has(code) and room.seat_peer == [41, 0] and not net._peer_room.has(42), "A joiner leaving the lobby keeps the room open")
	_check(room.alone_since > 0 and room.lobby[1]["deck"] == -1, "The empty seat forgets its pick and the idle clock starts")
	net._on_room_request(47, code)
	_check(room.seat_peer == [41, 47], "A new joiner takes the empty seat")
	net._on_lobby_pick(41, 0, deck0, "Host", true)
	net._on_lobby_pick(47, 1, deck1, "Second", true)
	net._on_deal_ready(41)
	net._on_deal_ready(47)
	net._on_peer_disconnected(47)
	_check(room.phase == DuelRoom.Phase.DUEL and ended.size() == 1 and room.away_since[1] > 0, "A seat dropping mid-duel is kept for its player")
	net.sweep(room.away_since[1] + net.REJOIN_GRACE_MS)
	_check(room.phase == DuelRoom.Phase.OVER and ended.size() == 2 and ended[1] == [code, 0, "left"], "and past its grace the other seat wins")
	_check(net.rooms.has(code) and room.seat_peer == [41, 0] and room.away_since == [0, 0], "The room outlives a finished duel until both leave")

	var idle_msec: int = int(net.room_idle_seconds * 1000.0)
	net.sweep(room.alone_since + idle_msec - 1)
	_check(net.rooms.has(code), "A waiting room stays open until the idle time")
	net.sweep(room.alone_since + idle_msec)
	_check(not net.rooms.has(code) and not net._peer_room.has(41), "A player alone past the idle time loses the room")
	net._on_peer_connected(48)
	_check(net._unseated.has(48), "A new peer has to ask for a room")
	net.sweep(int(net._unseated[48]))
	_check(not net._unseated.has(48) and not net._unseated.has(41), "A peer that never takes a room is dropped")

	net._on_room_request(49, "")
	var last: DuelRoom = net._room_of(49)
	net._on_peer_disconnected(49)
	_check(last != null and not net.rooms.has(last.code), "The last player out closes the room")
	net.room_command.disconnect(on_command)
	net.room_ended.disconnect(on_ended)
	net.leave()


func _wire_tests(net: Node, session: Node) -> void:
	net.mode = "server"
	var fingerprint: String = net.catalog_fingerprint()
	_check(fingerprint.length() == 64 and fingerprint == net.catalog_fingerprint(), "The catalog fingerprint is a stable SHA-256")
	_check(net.hello_problem(var_to_bytes({"protocol": net.PROTOCOL, "catalog": fingerprint})) == "", "A matching greeting is let in")
	_check(net.hello_problem(var_to_bytes({"protocol": net.PROTOCOL + 1, "catalog": fingerprint})).contains("version"), "A protocol mismatch is refused with the versions")
	_check(net.hello_problem(var_to_bytes({"protocol": net.PROTOCOL, "catalog": "0".repeat(64)})) != "", "A catalog mismatch is refused")
	_check(net.hello_problem(var_to_bytes({"protocol": str(net.PROTOCOL), "catalog": fingerprint})) != "", "A greeting with wrong types is refused")
	_check(net.hello_problem(PackedByteArray()) != "" and net.hello_problem(var_to_bytes("x".repeat(2000))) != "", "An empty or oversized greeting is refused")

	_check(net.clean_name("[b]Evil[/b]", 0) == "bEvil/b", "BBCode brackets are stripped from names")
	_check(net.clean_name("x".repeat(80), 1).length() == net.NAME_MAX, "Names are capped")
	_check(net.clean_name(" \t\n[] ", 1) == "Player 2", "A name with nothing left falls back to the stock name")
	_check(net.clean_name("Ro\u0007ok", 0) == "Rook", "Control characters are stripped from names")

	_check(net.code_problem("") != "" and net.code_problem("K7QMR") == "" and net.code_problem("k7qmr") == "", "Share codes are checked before connecting")
	_check(net.code_problem("K0QMR") != "" and net.code_problem("TOOLONG") != "", "Codes outside the alphabet or length are refused")

	var full: Array[Dictionary] = [
		{"name": "A", "deck": 0, "deck_name": session.decks[0].name, "ready": true},
		{"name": "B", "deck": 1, "deck_name": session.decks[1].name, "ready": false},
	]
	var for_seat_0: Array[Dictionary] = net.lobby_for(full, 0, false)
	_check(for_seat_0[0]["deck"] == 0 and for_seat_0[1]["deck"] == -1 and for_seat_0[1]["deck_name"] == "" and for_seat_0[1]["name"] == "B", "Each seat sees its own pick and only the other's name and lock")
	_check(net.lobby_for(full, 0, true)[1]["deck"] == 1, "Both picks show once both have locked")
	_check(full[1]["deck"] == 1, "The server's own lobby is not changed by what it sends")

	net.mode = "client"
	net.local_player = 0
	net._on_lobby([{"name": 5, "deck": 0, "deck_name": session.decks[0].name, "ready": true}, "junk"], true, 0)
	_check(net.lobby[0]["name"] == "Player 1" and net.lobby[0]["deck"] == -1 and net.lobby[1]["name"] == "Player 2", "Malformed lobby entries read as empty seats")
	net._on_lobby([{"name": "[i]B[/i]", "deck": 99, "deck_name": "Nope", "ready": true}], true, 0)
	_check(net.lobby[0]["name"] == "iB/i" and net.lobby[0]["deck"] == -1 and net.lobby[0]["ready"], "An unknown deck reads as none, the lock and cleaned name stay")
	net._on_lobby("junk", "yes", 0)
	_check(net.lobby[0]["name"] == "iB/i", "A malformed lobby message is dropped whole")
	net.leave()


const RECORD_DIR: String = "user://test_match_records_net"


## Match records on the duel server, driven through the handlers the RPCs call: a key made on first
## start, the record on disk before either player hears the result, no seed or command list in any
## update, the copy sent only once the room is over, and a client keeping only a signed server
## copy. Then an offline duel through Session writes an unsigned one where the override points.
func _record_tests(net: Node, session: Node) -> void:
	_remove_tree(RECORD_DIR)
	var server_dir: String = RECORD_DIR.path_join("server")
	var log: MatchLog = MatchLog.new()
	_check(log.open(server_dir) == "", "The match log opens a fresh data directory")
	var key: PackedByteArray = FileAccess.get_file_as_bytes(server_dir.path_join(MatchLog.KEY_FILE))
	_check(key.size() == MatchLog.KEY_BYTES, "and makes a 32-byte key there")
	var reopened: MatchLog = MatchLog.new()
	_check(reopened.open(server_dir) == "", "A second start loads that key")

	net.mode = "server"
	var server: Node = load("res://scripts/server/duel_server.gd").new()
	server.match_log = log
	net.room_command.connect(server._on_room_command)
	net.room_ended.connect(server._on_room_ended)
	net._on_room_request(61, "")
	var room: DuelRoom = net._room_of(61)
	var code: String = room.code
	net._on_room_request(62, code)
	net._on_lobby_pick(61, 0, session.decks[0].name, "Ada", true)
	net._on_lobby_pick(62, 1, session.decks[1].name, "Bryn", true)
	# Dealt by hand rather than through _start_room, so the seed is one the checks can look for.
	room.phase = DuelRoom.Phase.DUEL
	room.seed_value = 1987654321
	var host: DuelHost = server._open_duel(code)
	var day: String = log.day_path(int(Time.get_unix_time_from_system()))
	var at_result: Array[int] = []
	var leaks: Array[String] = []
	host.send = func(_seat: int, update: Dictionary) -> void:
		var text: String = JSON.stringify(update)
		for secret in [str(room.seed_value), "\"seed\"", "\"commands\"", "\"history\""]:
			if text.contains(secret):
				leaks.append(secret)
		if text.contains("\"game_over\""):
			at_result.append(_line_count(day))
	host.start()
	var sent_mid_duel: bool = true
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = 3
	for step in range(3000):
		if host.is_over():
			break
		if step == 5:
			sent_mid_duel = net.send_record(code, host.record.line())
		var p: Prompt = host.referee.engine.prompt
		net._on_submit(room.seat_peer[p.player], p.options[picker.randi_range(0, p.options.size() - 1)].to_dict())
	_check(host.is_over(), "The server's duel ran to a rules finish")
	_check(not sent_mid_duel, "The record cannot be sent while the room is in a duel")
	_check(at_result.size() == 2 and at_result[0] == 1 and at_result[1] == 1,
		"The record is on disk before the update carrying the result goes to either seat: %s" % str(at_result))
	_check(leaks.is_empty(), "No update carries the seed or a command list: %s" % str(leaks))
	_check(room.phase == DuelRoom.Phase.OVER and not server.hosts.has(code), "The room is over and its duel gone")
	var lines: PackedStringArray = FileAccess.get_file_as_string(day).split("\n", false)
	_check(lines.size() == 1, "One line in the day file")
	var server_line: String = lines[0] if lines.size() == 1 else ""
	var written: MatchRecord = MatchRecord.from_dict(JSON.parse_string(server_line)) if server_line != "" else null
	_check(written != null and written.origin == "server" and written.mode == "code" and written.sig.length() == 64,
		"It is a signed server record")
	if written != null:
		_check(written.seed_value == room.seed_value and int(written.result["winner"]) == host.referee.engine.state.winner,
			"with the duel's seed and winner")
		_check(str(written.seats[0]["name"]) == "Ada" and str(written.seats[1]["deck"]) == session.decks[1].id,
			"and each seat's name and deck id")
		_check(log.verify(written) and reopened.verify(written), "Its signature checks under the key, made or loaded")
		var tampered: MatchRecord = MatchRecord.from_dict(JSON.parse_string(server_line))
		tampered.commands[0]["card"] = int(tampered.commands[0]["card"]) + 1
		_check(not log.verify(tampered), "Changing one command breaks the signature")
		_check(not server_line.contains(key.hex_encode()), "The key is not in the record")
		var rebuilt: Referee = written.setup_referee(session.library, session.strike_table)
		_check(rebuilt != null and rebuilt.replay(written.commands) == ""
			and JSON.stringify(rebuilt.view_for(1).to_dict()) == JSON.stringify(host.referee.view_for(1).to_dict()),
			"The server's record replays to the same table")
	_check(net.send_record(code, server_line), "Once the room is over the record goes out")
	_check(not net.send_record(code, "x".repeat(net.RECORD_MAX_BYTES + 1)), "An oversized record does not")

	var at_concede: Array[int] = []
	var observer: Callable = func(_code: String, _winner: int, _reason: String) -> void: at_concede.append(_line_count(day))
	net.room_ended.connect(observer)
	room.phase = DuelRoom.Phase.DUEL
	room.seed_value = 1234567891
	var second: DuelHost = server._open_duel(code)
	second.send = func(_seat: int, _update: Dictionary) -> void: pass
	second.start()
	for step in range(6):
		var p: Prompt = second.referee.engine.prompt
		net._on_submit(room.seat_peer[p.player], p.options[0].to_dict())
	net._on_concede(62)
	_check(at_concede.size() == 1 and at_concede[0] == 2, "A concession's record is on disk before Net tells either player: %s" % str(at_concede))
	_check(str(second.record.result.get("reason", "")) == "concede" and int(second.record.result.get("winner", -1)) == 0,
		"as a win for the other seat")
	net._on_concede(61)
	second.end(1, "left")
	_check(_line_count(day) == 2 and str(second.record.result["reason"]) == "concede", "The first result written stands")
	net.room_ended.disconnect(observer)
	net.room_command.disconnect(server._on_room_command)
	net.room_ended.disconnect(server._on_room_ended)
	server.free.call_deferred()
	net.leave()

	MatchRecord.dir_override = RECORD_DIR.path_join("client")
	var online: String = MatchRecord.client_dir().path_join(MatchRecord.ONLINE_FILE)
	net.mode = "client"
	net._via_server = true
	net._on_record(net.HOST_ID, server_line)
	_check(_line_count(online) == 1, "A client keeps the server's copy")
	var unsigned: MatchRecord = MatchRecord.from_dict(JSON.parse_string(server_line))
	if unsigned != null:
		unsigned.origin = "client"
		unsigned.sig = ""
		net._on_record(net.HOST_ID, unsigned.line())
	for bad: Variant in ["x".repeat(net.RECORD_MAX_BYTES + 1), "{", 12345]:
		net._on_record(net.HOST_ID, bad)
	net._on_record(77, server_line)
	_check(_line_count(online) == 1, "and nothing oversized, unparsable, unsigned or from another peer")
	var kept: MatchRecord = MatchRecord.from_dict(JSON.parse_string(FileAccess.get_file_as_string(online).split("\n", false)[0]))
	_check(kept != null and log.verify(kept), "The kept copy still carries a signature the server accepts")
	net.leave()

	MatchRecord.dir_override = RECORD_DIR.path_join("offline")
	var local: String = MatchRecord.client_dir().path_join(MatchRecord.LOCAL_FILE)
	session.leave_adventure()
	session.chosen[0] = session.decks[2]
	session.chosen[1] = session.decks[3]
	var hotseat: DuelHost = DuelHost.new()
	hotseat.setup(session.build_referee(), [])
	session.keep_record(hotseat)
	hotseat.start()
	_play_random(hotseat, 11, 3000)
	_check(hotseat.is_over() and _line_count(local) == 1, "An offline duel through Session writes its record when the rules end it")
	var offline: MatchRecord = MatchRecord.from_dict(JSON.parse_string(FileAccess.get_file_as_string(local).split("\n", false)[0])) \
		if _line_count(local) == 1 else null
	_check(offline != null and offline.origin == "client" and offline.sig == "" and offline.mode == "hotseat",
		"unsigned, from the client, as a hotseat duel")
	var conceded: DuelHost = DuelHost.new()
	conceded.setup(session.build_referee(), [])
	session.keep_record(conceded)
	conceded.start()
	_play_random(conceded, 12, 6)
	var conceding: int = maxi(0, conceded.deciding())
	session._record_concession()
	_check(_line_count(local) == 2 and str(conceded.record.result.get("reason", "")) == "concede"
		and int(conceded.record.result.get("winner", -1)) == 1 - conceding, "A hotseat concession is a win for the other seat")
	session.leave_adventure()
	MatchRecord.dir_override = ""
	_remove_tree(RECORD_DIR)


const CLOCK_DIR: String = "user://test_match_records_clock"


## Decision clocks in a server room, through the handlers the RPCs and the server's timer call,
## with the time passed in: a panel reported open starts its seat's clock and the grace starts the
## other's, an answer stops only the answering seat's clock, and a seat whose timer and bank are
## gone loses with "timeout", its record on disk before Net tells either player. Both clocks
## running out at the same moment ends with no winner.
func _clock_tests(net: Node, session: Node) -> void:
	_remove_tree(CLOCK_DIR)
	var log: MatchLog = MatchLog.new()
	_check(log.open(CLOCK_DIR) == "", "The clock tests' match log opens")
	net.mode = "server"
	var seeds: Array[int] = []
	for i in range(20):
		seeds.append(net._deal_seed())
	var wide: bool = false
	var in_range: bool = true
	for s in seeds:
		wide = wide or s > 0x7FFFFFFF
		in_range = in_range and s >= 1 and s <= MatchRecord.JSON_INT_MAX
	_check(in_range and wide, "Deal seeds use 53 bits and stay JSON-safe: %s" % str(seeds.slice(0, 3)))

	var server: Node = load("res://scripts/server/duel_server.gd").new()
	server.match_log = log
	net.room_command.connect(server._on_room_command)
	net.room_ended.connect(server._on_room_ended)
	net.room_prompt_shown.connect(server._on_room_prompt_shown)
	var day: String = log.day_path(int(Time.get_unix_time_from_system()))
	var ended: Array = []
	var on_ended: Callable = func(code: String, winner: int, reason: String) -> void: ended.append([code, winner, reason, _line_count(day)])
	net.room_ended.connect(on_ended)

	var room: DuelRoom = _clock_room(net, session, 71, 72)
	room.seed_value = MatchRecord.JSON_INT_MAX - 12345
	var host: DuelHost = server._open_duel(room.code)
	var sent: Array = []
	host.clock_out = func(seat: int, left_ms: int, bank_ms: int, phase: String) -> void: sent.append([seat, left_ms, bank_ms, phase])
	host.start()
	var now: int = Time.get_ticks_msec()
	_check(host.clock != null and host.referee.prompt_kind_for(0) == &"reserve" and host.referee.prompt_kind_for(1) == &"reserve",
		"A server duel runs a clock and opens on both Reserve swaps")
	_check(host.clock.state(0, now)["phase"] == DuelClock.OFF and host.clock.state(1, now)["phase"] == DuelClock.OFF and sent.is_empty(),
		"No clock counts before a panel is up or its grace is over")
	net._on_prompt_shown(72, "defense")
	net._on_prompt_shown(72, 5)
	_check(host.clock.state(1, now)["phase"] == DuelClock.OFF, "A notice for another kind of decision, or a malformed one, starts nothing")
	net._on_prompt_shown(71, "reserve")
	var shown: Dictionary = host.clock.state(0, Time.get_ticks_msec())
	_check(shown["phase"] == DuelClock.RUN and int(shown["left_ms"]) > DuelClock.RESERVE_MS - 1000,
		"Seat 1's panel reported open starts its 60 s Reserve clock")
	_check(sent.size() == 1 and sent[0][0] == 0 and sent[0][2] == DuelClock.BANK_START_MS and sent[0][3] == DuelClock.RUN,
		"and both players hear it, with the full bank: %s" % str(sent))
	server.tick_rooms(now + DuelClock.SHOW_GRACE_MS)
	var graced: Dictionary = host.clock.state(1, now + DuelClock.SHOW_GRACE_MS)
	_check(graced["phase"] == DuelClock.RUN and int(graced["left_ms"]) > DuelClock.RESERVE_MS - 1000,
		"Seat 2's clock starts once its 10 s grace is over, panel or not")
	var seat_1_out: int = host.clock.out_at(1)
	net._on_submit(71, {"player": 0, "type": "reserve_done", "card": -1, "value": null})
	var answered: int = Time.get_ticks_msec()
	_check(host.clock.state(0, answered)["phase"] == DuelClock.OFF and host.clock.bank_left(0, answered) == DuelClock.BANK_START_MS,
		"An answer in time stops that seat's clock and leaves its bank whole")
	_check(host.clock.out_at(1) == seat_1_out and host.referee.prompt_kind_for(1) == &"reserve",
		"The other seat's Reserve clock runs on untouched")
	server.tick_rooms(seat_1_out - 1)
	_check(ended.is_empty() and server.hosts.has(room.code), "One millisecond short of timer and bank, the duel goes on")
	var bank_sent: bool = false
	for message in sent:
		bank_sent = bank_sent or (message[0] == 1 and message[3] == DuelClock.BANK)
	_check(bank_sent, "Seat 2 going onto its bank went out to the players")
	server.tick_rooms(seat_1_out)
	_check(ended.size() == 1 and ended[0][0] == room.code and ended[0][1] == 0 and ended[0][2] == "timeout",
		"A stalled seat loses with reason timeout: %s" % str(ended))
	_check(ended.size() == 1 and ended[0][3] == 1, "Its record is on disk before Net tells either player")
	_check(room.phase == DuelRoom.Phase.OVER and not server.hosts.has(room.code), "The room is over and its duel gone")
	var lines: PackedStringArray = FileAccess.get_file_as_string(day).split("\n", false)
	var written: MatchRecord = MatchRecord.from_dict(JSON.parse_string(lines[0])) if lines.size() == 1 else null
	_check(written != null and str(written.result["reason"]) == "timeout" and int(written.result["winner"]) == 0,
		"The record reads as a timeout win for seat 1")
	_check(written != null and written.seed_value == room.seed_value, "and carries its 53-bit seed intact")

	var tie_room: DuelRoom = _clock_room(net, session, 73, 74)
	var tie: DuelHost = server._open_duel(tie_room.code)
	tie.start()
	server.tick_rooms(Time.get_ticks_msec() + DuelClock.SHOW_GRACE_MS + DuelClock.RESERVE_MS + DuelClock.BANK_START_MS + 1)
	_check(ended.size() == 2 and ended[1][0] == tie_room.code and ended[1][1] == -1 and ended[1][2] == "abandoned",
		"Both clocks out at the same moment end the duel with no winner: %s" % str(ended))
	_check(ended.size() == 2 and ended[1][3] == 2 and tie.record.has_result() and int(tie.record.result["winner"]) == -1,
		"recorded before either player hears it")

	net.room_ended.disconnect(on_ended)
	net.room_command.disconnect(server._on_room_command)
	net.room_ended.disconnect(server._on_room_ended)
	net.room_prompt_shown.disconnect(server._on_room_prompt_shown)
	server.free.call_deferred()
	net.leave()

	net.mode = "client"
	net._via_server = true
	net._in_duel = true
	var heard: Array = []
	var on_clock: Callable = func(seat: int, left_ms: int, bank_ms: int, phase: String) -> void: heard.append([seat, left_ms, bank_ms, phase])
	net.clock_changed.connect(on_clock)
	net._on_clock(net.HOST_ID, 1, 25000, 60000, "run")
	for bad in [[77, 1, 25000, 60000, "run"], [net.HOST_ID, 2, 25000, 60000, "run"], [net.HOST_ID, 1, -5, 60000, "run"],
			[net.HOST_ID, 1, 25000, 60000, "sprint"], [net.HOST_ID, "1", 25000, 60000, "run"], [net.HOST_ID, 1, 2.5, 60000, "run"]]:
		net._on_clock(bad[0], bad[1], bad[2], bad[3], bad[4])
	_check(heard == [[1, 25000, 60000, "run"]], "A client takes a clock only from the server, and only well-formed: %s" % str(heard))
	net.clock_changed.disconnect(on_clock)
	net.leave()
	_remove_tree(CLOCK_DIR)


## A code room with both seats locked, dealt by hand so the checks own the seed. Decks 0 and 2
## both carry a Reserve, so the duel opens on a swap for each seat.
func _clock_room(net: Node, session: Node, peer_a: int, peer_b: int) -> DuelRoom:
	net._on_room_request(peer_a, "")
	var room: DuelRoom = net._room_of(peer_a)
	net._on_room_request(peer_b, room.code)
	net._on_lobby_pick(peer_a, 0, session.decks[0].name, "Ada", true)
	net._on_lobby_pick(peer_b, 2, session.decks[2].name, "Bryn", true)
	room.phase = DuelRoom.Phase.DUEL
	room.seed_value = 777
	return room


const ROOMS_DIR: String = "user://test_match_records_rooms"
const REJOIN_DIR: String = "user://test_match_records_rejoin"
const REJOIN_CLIENT_DIR: String = "user://test_rejoin_client"


## Two rooms at once on one server, four peers, through the handlers the RPCs and the server's timer
## call. After every step each peer holds only messages for its own room and seat
## (`_read_inboxes`), a command reaches only its sender's room, and ending one room by concession,
## on the clock or with both players gone leaves the other running with its clocks as they were.
## The day file then holds one record per game, each with its own id, seed and names.
func _isolation_tests(net: Node, session: Node) -> void:
	_remove_tree(ROOMS_DIR)
	var log: MatchLog = MatchLog.new()
	_check(log.open(ROOMS_DIR) == "", "The two-room tests' match log opens")
	net.mode = "server"
	var server: Node = load("res://scripts/server/duel_server.gd").new()
	server.match_log = log
	_link_server(net, server, true)
	var inbox: Dictionary = {}
	net._outbox = func(peer: int, method: StringName, args: Array) -> void:
		if not inbox.has(peer):
			inbox[peer] = []
		(inbox[peer] as Array).append([String(method), args])
	var reached: Array = []
	var on_command: Callable = func(code: String, seat: int, _cmd: Dictionary) -> void: reached.append([code, seat])
	net.room_command.connect(on_command)
	var ended: Array = []
	var on_ended: Callable = func(code: String, winner: int, reason: String) -> void: ended.append([code, winner, reason])
	net.room_ended.connect(on_ended)
	var tokens: Array[String] = []
	var problems: Array[String] = []
	var games: Array = []

	var a: DuelRoom = _dealt_room(net, session, 81, 82, [0, 2], ["Ada", "Bryn"])
	var b: DuelRoom = _dealt_room(net, session, 83, 84, [3, 5], ["Cato", "Dara"])
	var who: Dictionary = {81: [a, 0], 82: [a, 1], 83: [b, 0], 84: [b, 1]}
	games.append([a.seed_value, "Ada", "Bryn"])
	games.append([b.seed_value, "Cato", "Dara"])
	var first_tokens: Array[String] = a.tokens.duplicate()
	_check(a.code != b.code and a.phase == DuelRoom.Phase.DUEL and b.phase == DuelRoom.Phase.DUEL and server.hosts.size() == 2,
		"Two rooms deal side by side")
	var got: Dictionary = _read_inboxes(server, inbox, who, tokens, problems)
	var dealt: bool = tokens.size() == 4
	for peer: int in who.keys():
		dealt = dealt and _count(got, peer, "_rpc_start") == 1 and _count(got, peer, "_rpc_update") == 1
	_check(dealt and problems.is_empty(), "Each peer gets one deal carrying its own seat's token and one update of its own seat: %s" % str(problems))

	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = 17
	var first_bad: String = ""
	var steps: int = 0
	for step in range(30):
		var room: DuelRoom = a if step % 2 == 0 else b
		var other: DuelRoom = b if room == a else a
		var host: DuelHost = server.hosts.get(room.code)
		var other_host: DuelHost = server.hosts.get(other.code)
		if host == null or other_host == null or host.is_over():
			break
		var other_history: int = other_host.referee.history.size()
		var p: Prompt = host.referee.engine.prompt
		var before: int = reached.size()
		net._on_submit(room.seat_peer[p.player], p.options[picker.randi_range(0, p.options.size() - 1)].to_dict())
		got = _read_inboxes(server, inbox, who, tokens, problems)
		var ok: bool = problems.is_empty() and reached.size() == before + 1 and reached[before] == [room.code, p.player] \
			and other_host.referee.history.size() == other_history
		for peer: int in who.keys():
			ok = ok and (_quiet(got, [peer]) if who[peer][0] == other else _count(got, peer, "_rpc_update") == 1)
		if not ok and first_bad == "":
			first_bad = "step %d in room %s: %s" % [step, room.code, str(problems)]
		steps += 1
	_check(steps == 30 and first_bad == "",
		"Thirty commands alternate between the rooms; each reaches its own room's host, and only that room's two peers get an update, each of its own seat: %s" % first_bad)

	var b_host: DuelHost = server.hosts[b.code]
	var b_history: int = b_host.referee.history.size()
	var forged: Dictionary = b_host.referee.engine.prompt.options[0].to_dict()
	var before_forged: int = reached.size()
	for seat in range(2):
		forged["player"] = seat
		net._on_submit(81, forged.duplicate())
	var only_a: bool = true
	for entry: Array in reached.slice(before_forged):
		only_a = only_a and entry[0] == a.code
	got = _read_inboxes(server, inbox, who, tokens, problems)
	_check(b_host.referee.history.size() == b_history and only_a and reached.size() <= before_forged + 1,
		"A command room 1's peer copies from room 2's decision never reaches room 2's host")
	_check(problems.is_empty() and _quiet(got, [83, 84]), "and room 2's peers hear nothing of it: %s" % str(problems))

	var marks: Array = _clock_marks(b_host)
	net._on_concede(82)
	got = _read_inboxes(server, inbox, who, tokens, problems)
	_check(_last(ended) == [a.code, 0, "concede"] and a.phase == DuelRoom.Phase.OVER and b.phase == DuelRoom.Phase.DUEL
		and server.hosts.has(b.code) and not server.hosts.has(a.code), "Room 1 is conceded and room 2 plays on")
	_check(problems.is_empty() and _count(got, 81, "_rpc_duel_ended") == 1 and _count(got, 82, "_rpc_duel_ended") == 1
		and _quiet(got, [83, 84]) and _clock_marks(b_host) == marks,
		"Only room 1's players hear the result, and room 2's clocks stand as they were: %s" % str(problems))
	await process_frame
	got = _read_inboxes(server, inbox, who, tokens, problems)
	_check(problems.is_empty() and _count(got, 81, "_rpc_record") == 1 and _count(got, 82, "_rpc_record") == 1 and _quiet(got, [83, 84]),
		"Each of room 1's players gets room 1's record and room 2's players get none: %s" % str(problems))

	net._on_rematch(81)
	net._on_rematch(82)
	games.append([a.seed_value, "Ada", "Bryn"])
	got = _read_inboxes(server, inbox, who, tokens, problems)
	_check(a.phase == DuelRoom.Phase.DUEL and a.tokens[0] != "" and a.tokens[1] != "" and not a.tokens.has(first_tokens[0])
		and not a.tokens.has(first_tokens[1]), "A rematch deals each seat a new token")
	_check(problems.is_empty() and _count(got, 81, "_rpc_start") == 1 and _count(got, 82, "_rpc_start") == 1 and _quiet(got, [83, 84]),
		"and only room 1's players hear of it: %s" % str(problems))

	net._on_submit(81, {"player": 0, "type": "reserve_done", "card": -1, "value": null})
	_read_inboxes(server, inbox, who, tokens, problems)
	var start_at: int = Time.get_ticks_msec() + DuelClock.SHOW_GRACE_MS
	server.tick_rooms(start_at)
	got = _read_inboxes(server, inbox, who, tokens, problems, start_at)
	_check(problems.is_empty() and _count(got, 81, "_rpc_clock") > 0 and _count(got, 83, "_rpc_clock") > 0,
		"Every clock a peer hears on a tick is its own room's, as that room's host has it: %s" % str(problems))
	var hosts: Array[DuelHost] = [server.hosts[a.code], server.hosts[b.code]]
	var rooms: Array[DuelRoom] = [a, b]
	var outs: Array[int] = [_first_out(hosts[0]), _first_out(hosts[1])]
	var first: int = mini(outs[0], outs[1])
	server.tick_rooms(first - 1)
	_read_inboxes(server, inbox, who, tokens, problems, first - 1)
	var standing: Array = [_clock_marks(hosts[0]), _clock_marks(hosts[1])]
	var ended_before: int = ended.size()
	_check(outs[0] > 0 and outs[1] > 0 and a.phase == DuelRoom.Phase.DUEL and b.phase == DuelRoom.Phase.DUEL,
		"Both rooms run a clock, and one millisecond before the first runs out both play on")
	server.tick_rooms(first)
	got = _read_inboxes(server, inbox, who, tokens, problems, first)
	var expired: Array = []
	var untouched: bool = true
	for i in range(2):
		if outs[i] == first:
			expired.append(_timeout_of(rooms[i].code, hosts[i], first))
		else:
			untouched = untouched and rooms[i].phase == DuelRoom.Phase.DUEL and server.hosts.has(rooms[i].code) \
				and _clock_marks(hosts[i]) == standing[i]
	_check(ended.slice(ended_before) == expired and not expired.is_empty(),
		"The tick ends only the room whose clock ran out: %s" % str(ended.slice(ended_before)))
	_check(untouched and problems.is_empty(), "and the other room plays on with its clocks as they were: %s" % str(problems))
	await process_frame
	_read_inboxes(server, inbox, who, tokens, problems)
	for i in range(2):
		if rooms[i].phase == DuelRoom.Phase.OVER:
			net._on_rematch(rooms[i].seat_peer[0])
			net._on_rematch(rooms[i].seat_peer[1])
			games.append([rooms[i].seed_value, str(rooms[i].lobby[0]["name"]), str(rooms[i].lobby[1]["name"])])
	_read_inboxes(server, inbox, who, tokens, problems)
	_check(a.phase == DuelRoom.Phase.DUEL and b.phase == DuelRoom.Phase.DUEL and problems.is_empty(),
		"The timed-out room deals again for its own players: %s" % str(problems))

	b_host = server.hosts[b.code]
	marks = _clock_marks(b_host)
	b_history = b_host.referee.history.size()
	net._on_peer_disconnected(81)
	net._on_peer_disconnected(82)
	got = _read_inboxes(server, inbox, who, tokens, problems)
	_check(a.both_away_since > 0 and b.away_since == [0, 0] and b.both_away_since == 0 and _quiet(got, [83, 84]),
		"Both of room 1's players gone: room 1 waits for them and room 2's players hear nothing")
	var closing: String = a.code
	net.sweep(a.both_away_since + net.REJOIN_GRACE_MS)
	got = _read_inboxes(server, inbox, who, tokens, problems)
	_check(_last(ended) == [closing, -1, "abandoned"] and not net.rooms.has(closing) and not server.hosts.has(closing),
		"After the window room 1 ends with no winner and closes")
	_check(b.phase == DuelRoom.Phase.DUEL and server.hosts.has(b.code) and _clock_marks(b_host) == marks
		and b_host.referee.history.size() == b_history and _quiet(got, [83, 84]) and problems.is_empty(),
		"Room 2 plays on with its clocks as they were: %s" % str(problems))

	net._on_concede(83)
	await process_frame
	got = _read_inboxes(server, inbox, who, tokens, problems)
	_check(_last(ended) == [b.code, 1, "concede"] and _count(got, 84, "_rpc_record") == 1 and problems.is_empty(),
		"Room 2 ends on its own and its player gets its own record: %s" % str(problems))
	var day: String = log.day_path(int(Time.get_unix_time_from_system()))
	var text: String = FileAccess.get_file_as_string(day)
	var lines: PackedStringArray = text.split("\n", false)
	var ids: Dictionary = {}
	var matched: int = 0
	for line in lines:
		var record: MatchRecord = MatchRecord.from_dict(JSON.parse_string(line))
		if record == null:
			continue
		ids[record.id] = true
		for game: Array in games:
			if record.seed_value == int(game[0]) and str(record.seats[0]["name"]) == game[1] and str(record.seats[1]["name"]) == game[2]:
				matched += 1
	_check(lines.size() == games.size() and ids.size() == games.size() and matched == games.size(),
		"The day file holds one record per game (%d of %d), each with its own id and the seed and names of its own room" % [matched, games.size()])
	var leaked: bool = false
	for token in tokens:
		leaked = leaked or text.contains(token)
	_check(tokens.size() >= 8 and not leaked, "No rejoin token is in a record")

	net._outbox = Callable()
	net.room_command.disconnect(on_command)
	net.room_ended.disconnect(on_ended)
	_link_server(net, server, false)
	server.free.call_deferred()
	net.leave()
	_remove_tree(ROOMS_DIR)


## Reconnects on the server, through the handlers the RPCs, the sweep and the clock timer call. A
## seat whose connection drops is kept with its clock running and loses "left" when that clock or
## its grace runs out. With both seats away both clocks stop and the duel ends "abandoned" after
## the window, unless one comes back first, when both clocks go on. A good token re-seats the peer
## with `_rpc_resume` and a catch-up of its own view and prompt; a wrong token, a wrong room, a
## finished duel, a seat still connected and a restarted server are refused. Tokens reach nothing
## but their own seat's deal, and the record counts each seat's drops and returns.
func _rejoin_tests(net: Node, session: Node) -> void:
	_remove_tree(REJOIN_DIR)
	var log: MatchLog = MatchLog.new()
	_check(log.open(REJOIN_DIR) == "", "The rejoin tests' match log opens")
	net.mode = "server"
	var server: Node = load("res://scripts/server/duel_server.gd").new()
	server.match_log = log
	_link_server(net, server, true)
	var inbox: Dictionary = {}
	net._outbox = func(peer: int, method: StringName, args: Array) -> void:
		if not inbox.has(peer):
			inbox[peer] = []
		(inbox[peer] as Array).append([String(method), args])
	var journal: Array[String] = []
	net._journal = func(line: String) -> void: journal.append(line)
	var ended: Array = []
	var on_ended: Callable = func(code: String, winner: int, reason: String) -> void: ended.append([code, winner, reason])
	net.room_ended.connect(on_ended)
	var day: String = log.day_path(int(Time.get_unix_time_from_system()))
	var tokens: Array[String] = []
	var problems: Array[String] = []
	var who: Dictionary = {}
	var reserve_done: Dictionary = {"player": 0, "type": "reserve_done", "card": -1, "value": null}

	var room: DuelRoom = _dealt_room(net, session, 91, 92, [0, 2], ["Ada", "Bryn"])
	who[91] = [room, 0]
	who[92] = [room, 1]
	var host: DuelHost = server.hosts[room.code]
	_read_inboxes(server, inbox, who, tokens, problems)
	net._on_submit(91, reserve_done)
	server.tick_rooms(Time.get_ticks_msec() + DuelClock.SHOW_GRACE_MS)
	var out: int = host.clock.out_at(1)
	_read_inboxes(server, inbox, who, tokens, problems)
	net._on_peer_disconnected(92)
	var got: Dictionary = _read_inboxes(server, inbox, who, tokens, problems)
	_check(room.phase == DuelRoom.Phase.DUEL and room.seat_peer == [91, 0] and room.away_since[1] > 0 and host.away == [false, true]
		and server.hosts.has(room.code), "A seat whose connection drops mid-duel is marked away and kept")
	_check(host.record.disconnects == [0, 1] and out > 0 and host.clock.out_at(1) == out, "The drop is counted and the seat's clock runs on untouched")
	_check(got.get(91, []) == [["_rpc_seat_away", [1, net.REJOIN_GRACE_MS]]], "The other player hears it with the grace: %s" % str(got.get(91, [])))
	server.tick_rooms(out - 1)
	_read_inboxes(server, inbox, who, tokens, problems)
	_check(room.phase == DuelRoom.Phase.DUEL and ended.is_empty(), "One millisecond short of its clock, the away seat is still in the duel")
	server.tick_rooms(out)
	got = _read_inboxes(server, inbox, who, tokens, problems)
	var record: MatchRecord = _last_record(day)
	_check(_last(ended) == [room.code, 0, "left"] and room.phase == DuelRoom.Phase.OVER, "Its clock running out while it is away loses with reason left")
	_check(record != null and str(record.result["reason"]) == "left" and int(record.result["winner"]) == 0
		and record.disconnects == [0, 1] and record.reconnects == [0, 0], "The record says left and counts the drop")
	_check(room.seat_peer == [91, 0] and room.away_since == [0, 0] and room.tokens == ["", ""]
		and _methods(got, 91) == ["_rpc_duel_ended", "_rpc_seat_left"],
		"The duel over, the away seat is given up and the other player hears that after the result: %s" % str(_methods(got, 91)))

	var second: DuelRoom = _dealt_room(net, session, 101, 102, [0, 2], ["Cato", "Dara"])
	who[101] = [second, 0]
	who[102] = [second, 1]
	_read_inboxes(server, inbox, who, tokens, problems)
	net._on_peer_disconnected(102)
	net.sweep(second.away_since[1] + net.REJOIN_GRACE_MS - 1)
	_check(second.phase == DuelRoom.Phase.DUEL and ended.size() == 1, "A seat away one millisecond short of its grace is still kept")
	net.sweep(second.away_since[1] + net.REJOIN_GRACE_MS)
	record = _last_record(day)
	_check(_last(ended) == [second.code, 0, "left"] and record != null and str(record.result["reason"]) == "left",
		"At 90 s away it loses with reason left, time still on its clock")

	var third: DuelRoom = _dealt_room(net, session, 111, 112, [0, 2], ["Eda", "Fenn"])
	who[111] = [third, 0]
	who[112] = [third, 1]
	var third_host: DuelHost = server.hosts[third.code]
	_read_inboxes(server, inbox, who, tokens, problems)
	server.tick_rooms(Time.get_ticks_msec() + DuelClock.SHOW_GRACE_MS)
	_read_inboxes(server, inbox, who, tokens, problems)
	var running: bool = third_host.clock.out_at(0) > 0 and third_host.clock.out_at(1) > 0
	net._on_peer_disconnected(111)
	net._on_peer_disconnected(112)
	var probe: int = Time.get_ticks_msec() + 1000
	_check(running and third.both_away_since > 0 and third_host.clock.state(0, probe)["phase"] == DuelClock.OFF
		and third_host.clock.state(1, probe)["phase"] == DuelClock.OFF, "With both seats away both running clocks stop")
	_check(third_host.record.disconnects == [1, 1] and third_host.away == [true, true], "Each drop is counted")
	var both_since: int = third.both_away_since
	net.sweep(both_since + net.REJOIN_GRACE_MS - 1)
	_check(third.phase == DuelRoom.Phase.DUEL and net.rooms.has(third.code), "Short of 90 s with nobody back, the duel waits")
	var closing: String = third.code
	net.sweep(both_since + net.REJOIN_GRACE_MS)
	record = _last_record(day)
	_check(_last(ended) == [closing, -1, "abandoned"] and not net.rooms.has(closing) and not server.hosts.has(closing),
		"After 90 s with nobody back it ends with no winner and the room closes")
	_check(record != null and str(record.result["reason"]) == "abandoned" and int(record.result["winner"]) == -1 and record.disconnects == [1, 1],
		"The record says abandoned")

	var fourth: DuelRoom = _dealt_room(net, session, 121, 122, [0, 2], ["Gale", "Hale"])
	who[121] = [fourth, 0]
	who[122] = [fourth, 1]
	var fourth_host: DuelHost = server.hosts[fourth.code]
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = 23
	for step in range(14):
		var p: Prompt = fourth_host.referee.engine.prompt
		net._on_submit(fourth.seat_peer[p.player], p.options[picker.randi_range(0, p.options.size() - 1)].to_dict())
	server.tick_rooms(Time.get_ticks_msec() + DuelClock.SHOW_GRACE_MS)
	_read_inboxes(server, inbox, who, tokens, problems)
	var owing: int = fourth_host.referee.engine.prompt.player
	var seat_tokens: Array[String] = fourth.tokens.duplicate()
	net._on_peer_disconnected(121)
	net._on_peer_disconnected(122)
	var paused: Dictionary = fourth_host._paused[owing]
	var paused_total: int = int(paused.get("left_ms", 0)) + int(paused.get("bank_ms", 0))
	var away_1: int = fourth.away_since[1]
	net._on_rejoin(131, fourth.code, "0".repeat(64))
	net._on_rejoin(132, "ZZZZZ", seat_tokens[0])
	net._on_rejoin(133, second.code, seat_tokens[0])
	net._on_rejoin(134, 12345, null)
	got = _read_inboxes(server, inbox, who, tokens, problems)
	_check(got.get(131, []) == [["_rpc_rejoin_failed", ["That duel has no seat for this copy of the game."]]]
		and got.get(132, []) == [["_rpc_rejoin_failed", [net.REJOIN_GONE]]] and got.get(133, []) == [["_rpc_rejoin_failed", [net.REJOIN_OVER]]]
		and got.get(134, []) == [["_rpc_rejoin_failed", [net.REJOIN_GONE]]], "A wrong token, a wrong room, a finished duel and a malformed request are refused with a reason")
	_check(fourth.seat_peer == [0, 0] and net._refused.has(131) and net._refused.has(134), "and nobody was seated")
	var before_rejoin: int = Time.get_ticks_msec()
	net._on_rejoin(141, fourth.code.to_lower(), seat_tokens[0])
	var after_rejoin: int = Time.get_ticks_msec()
	who[141] = [fourth, 0]
	got = _read_inboxes(server, inbox, who, tokens, problems)
	_check(fourth.seat_peer == [141, 0] and fourth.away_since[0] == 0 and fourth.both_away_since == 0 and fourth.away_since[1] >= away_1
		and fourth_host.away == [false, true], "The first one back with its seat's token takes that seat again, and the other seat's grace runs on from here")
	_check(fourth_host.record.disconnects == [1, 1] and fourth_host.record.reconnects == [1, 0], "The return is counted")
	var methods: Array = _methods(got, 141)
	_check(methods.size() >= 3 and methods[0] == "_rpc_resume" and methods[1] == "_rpc_seat_away" and methods[2] == "_rpc_update",
		"It gets the resume, word that the other seat is still away, then one update: %s" % str(methods))
	var caught: Dictionary = _unpack((got[141][2] as Array)[1]) if methods.size() >= 3 else {}
	var animated: int = 0
	for line: Dictionary in caught.get("lines", []):
		if line.has("data"):
			animated += 1
	var prompt_now: PromptView = fourth_host.prompt_for(0)
	_check(not caught.is_empty() and JSON.stringify(caught["view"]) == JSON.stringify(fourth_host.view_for(0).to_dict())
		and JSON.stringify(caught["prompt"]) == JSON.stringify(prompt_now.to_dict() if prompt_now != null else {}),
		"The catch-up is the seat's own view and prompt as the table stands")
	_check(animated == 0 and not (caught.get("lines", []) as Array).is_empty(), "with this turn's lines and nothing to animate")
	var resumed_out: int = fourth_host.clock.out_at(owing)
	_check(paused_total > 0 and resumed_out > 0 and resumed_out - after_rejoin <= paused_total and paused_total <= resumed_out - before_rejoin,
		"Both clocks go on from where they stopped: %d left at the pause, %d after" % [paused_total, resumed_out - after_rejoin])
	net._on_rejoin(142, fourth.code, seat_tokens[0])
	got = _read_inboxes(server, inbox, who, tokens, problems)
	_check(_methods(got, 142) == ["_rpc_room_failed"] and fourth.seat_peer[0] == 141,
		"A token for a seat that is connected again is refused as a failed connection, so that client can try again")
	net._on_rejoin(143, fourth.code, seat_tokens[1])
	who[143] = [fourth, 1]
	got = _read_inboxes(server, inbox, who, tokens, problems)
	_check(fourth.seat_peer == [141, 143] and fourth.away_since == [0, 0] and fourth_host.away == [false, false]
		and fourth_host.record.reconnects == [1, 1], "The second one back takes its own seat")
	_check(_methods(got, 141).has("_rpc_seat_back") and not _methods(got, 143).is_empty() and _methods(got, 143)[0] == "_rpc_resume",
		"and the first one hears it")
	var next: Prompt = fourth_host.referee.engine.prompt
	var history: int = fourth_host.referee.history.size()
	net._on_submit(fourth.seat_peer[next.player], next.options[0].to_dict())
	_check(fourth_host.referee.history.size() == history + 1, "A rejoined seat's command reaches its duel")
	net._on_concede(143)
	record = _last_record(day)
	_check(_last(ended) == [fourth.code, 0, "concede"] and record != null and record.disconnects == [1, 1] and record.reconnects == [1, 1],
		"The record counts one drop and one return for each seat")
	_read_inboxes(server, inbox, who, tokens, problems)
	_check(problems.is_empty(), "Every message went to its own room and seat, and no token reached anything but its seat's deal: %s" % str(problems))
	var leaked: Array[String] = []
	var records_text: String = FileAccess.get_file_as_string(day)
	for token in tokens:
		if records_text.contains(token):
			leaked.append("a record")
		for line in journal:
			if line.contains(token):
				leaked.append(line)
	_check(tokens.size() == 8 and not journal.is_empty() and leaked.is_empty(), "No token is in a record or a journal line: %s" % str(leaked))

	net.leave()
	net.mode = "server"
	net._on_rejoin(151, fourth.code, seat_tokens[0])
	_check(inbox.get(151, []) == [["_rpc_rejoin_failed", [net.REJOIN_GONE]]], "After a restart the server refuses a rejoin: the duel is no longer there")

	net._outbox = Callable()
	net._journal = Callable()
	net.room_ended.disconnect(on_ended)
	_link_server(net, server, false)
	server.free.call_deferred()
	net.leave()
	_remove_tree(REJOIN_DIR)


## The client's side: the deal leaves a rejoin file naming the server, the room, the seat and its
## token, good until its expiry; word of the other seat away and back counts down here; a refused
## rejoin deletes the file and fails with the server's reason; a malformed file reads as none.
func _rejoin_client_tests(net: Node, session: Node) -> void:
	net.leave()
	RejoinFile.clear()
	net.mode = "client"
	net._via_server = true
	net._server_address = "203.0.113.5:7777"
	net.room_code = "K7QMR"
	net.local_player = 1
	session.chosen[0] = session.decks[0]
	session.chosen[1] = session.decks[2]
	session.player_names[0] = "Ada"
	session.player_names[1] = "Bryn"
	var token: String = "ab".repeat(32)
	net._keep_rejoin(token)
	var ticket: Dictionary = RejoinFile.read()
	var now: int = int(Time.get_unix_time_from_system())
	_check(not ticket.is_empty() and ticket["server"] == "203.0.113.5:7777" and ticket["code"] == "K7QMR" and ticket["seat"] == 1
		and ticket["token"] == token, "The deal leaves a rejoin file with the server, the room, the seat and its token")
	_check(ticket.get("decks", []) == [session.decks[0].id, session.decks[2].id] and ticket.get("names", []) == ["Ada", "Bryn"],
		"and both decks and names")
	_check(ticket.get("ranked", true) == false and not RejoinFile.ranked(ticket), "A seat outside a ranked match is written unranked")
	net._ranked = true
	net._keep_rejoin(token)
	var ranked_ticket: Dictionary = RejoinFile.read()
	RejoinFile.renew(int(Time.get_unix_time_from_system()))
	_check(RejoinFile.ranked(ranked_ticket) and RejoinFile.ranked(RejoinFile.read()),
		"A ranked seat is written ranked, so the title knows after a relaunch, and a renewal keeps it")
	var legacy: Dictionary = ranked_ticket.duplicate()
	legacy.erase("ranked")
	RejoinFile.write(legacy)
	var legacy_read: Dictionary = RejoinFile.read()
	RejoinFile.write(ranked_ticket.merged({"ranked": "yes"}, true))
	_check(not legacy_read.is_empty() and not RejoinFile.ranked(legacy_read) and not RejoinFile.ranked(RejoinFile.read()),
		"A file from before the flag, or with a malformed one, reads as unranked")
	net._ranked = false
	net._keep_rejoin(token)
	ticket = RejoinFile.read()
	now = int(Time.get_unix_time_from_system())
	_check(RejoinFile.live(ticket, now) and not RejoinFile.live(ticket, int(ticket.get("expires", 0))) and net.can_rejoin("K7QMR")
		and not net.can_rejoin("ZZZZZ"), "It is good until its expiry, for its own room")
	_check(RejoinFile.KEEP_SECONDS == 150 and RejoinFile.KEEP_SECONDS * 1000 == net.REJOIN_GRACE_MS + RejoinFile.MARGIN_SECONDS * 1000,
		"It lasts 2:30 from its last renewal: the server's 90 s grace for a dropped seat and a minute's margin")
	var expires: int = int(ticket.get("expires", 0))
	_check(expires - now >= RejoinFile.KEEP_SECONDS - 1 and expires - now <= RejoinFile.KEEP_SECONDS
		and RejoinFile.live(ticket, now + net.REJOIN_GRACE_MS / 1000) and not RejoinFile.live(ticket, now + RejoinFile.KEEP_SECONDS),
		"so it is still good once the server's grace is over and gone 2:30 on, and the title stops offering the seat: %d" % (expires - now))
	RejoinFile.renew(now + 1000)
	_check(int(RejoinFile.read().get("expires", 0)) == now + 1000 + RejoinFile.KEEP_SECONDS, "Renewing moves the expiry on")
	net._in_duel = true
	var stale: Dictionary = RejoinFile.read()
	stale["expires"] = now + 5
	RejoinFile.write(stale)
	net._renewed_at = Time.get_ticks_msec() - net.REJOIN_RENEW_MS
	net._on_clock(net.HOST_ID, 1, 20000, 60000, "run")
	var renewed: int = int(RejoinFile.read().get("expires", 0))
	_check(renewed >= now + RejoinFile.KEEP_SECONDS, "A clock from the server renews it too, so a long decision by the other player never lets it lapse")
	RejoinFile.write(stale)
	net._on_clock(net.HOST_ID, 1, 19000, 60000, "run")
	_check(int(RejoinFile.read().get("expires", 0)) == now + 5, "but no more often than every 30 seconds")
	net._in_duel = false
	var saw: Array = []
	var on_away: Callable = func(seat: int, grace: int) -> void: saw.append(["away", seat, grace])
	var on_back: Callable = func(seat: int) -> void: saw.append(["back", seat])
	net.peer_away.connect(on_away)
	net.peer_back.connect(on_back)
	net._on_seat_away(net.HOST_ID, 0, 72000)
	var left: int = net.away_left_ms(0)
	net._on_seat_away(77, 0, 5000)
	net._on_seat_away(net.HOST_ID, 1, 5000)
	net._on_seat_away(net.HOST_ID, "0", 5000)
	_check(saw == [["away", 0, 72000]] and left > 71000 and left <= 72000 and net.away_left_ms(1) == -1,
		"Word of the other seat away counts its grace down, taken only from the server: %s" % str(saw))
	net._on_seat_back(net.HOST_ID, 0)
	_check(_last(saw) == ["back", 0] and net.away_left_ms(0) == -1, "and stops when it is back")
	var failed: Array[String] = []
	var on_failed: Callable = func(reason: String) -> void: failed.append(reason)
	net.connection_failed.connect(on_failed)
	net._on_rejoin_failed(net.REJOIN_GONE)
	_check(not FileAccess.file_exists(RejoinFile.path()) and failed == [net.REJOIN_GONE] and net.last_error == net.REJOIN_GONE
		and not net.can_rejoin(), "A refused rejoin deletes the file and fails with the server's reason")
	net.connection_failed.disconnect(on_failed)
	net.peer_away.disconnect(on_away)
	net.peer_back.disconnect(on_back)
	var good: Dictionary = {"server": "x", "code": "K7QMR", "seat": 0, "token": token, "names": ["a", "b"], "decks": ["a", "b"], "expires": now + 60}
	var malformed: Array = ["{", "[]", JSON.stringify(good.merged({"seat": 3}, true)), JSON.stringify(good.merged({"token": "short"}, true)),
		JSON.stringify(good.merged({"code": "K0QMR"}, true)), JSON.stringify(good.merged({"names": ["a"]}, true))]
	var none: bool = true
	for text: String in malformed:
		var file: FileAccess = FileAccess.open(RejoinFile.path(), FileAccess.WRITE)
		file.store_string(text)
		file.close()
		none = none and RejoinFile.read().is_empty()
	RejoinFile.write(good)
	_check(none and not RejoinFile.read().is_empty(), "A malformed rejoin file reads as none, and a good one reads")
	RejoinFile.clear()
	net.last_error = ""
	net.leave()


const GIVE_UP_DIR: String = "user://test_match_records_give_up"


## A cut-off seat's Give up, on the server through the handler its greeting reaches: with the room's
## code and its token, an away seat concedes at once and the other player hears the result, the
## record written first with reason concede. A seat the server still counts as connected is asked
## to try again; a wrong token, a wrong room, a malformed request and a finished duel are refused
## with a reason. With both seats away the giver-up still loses. On the client, Give up while cut off
## deletes the rejoin file at once and sends the concession on a connection `leave()` does not stop;
## a "try again" answer retries and any other ends it.
func _give_up_tests(net: Node, session: Node) -> void:
	_remove_tree(GIVE_UP_DIR)
	var log: MatchLog = MatchLog.new()
	_check(log.open(GIVE_UP_DIR) == "", "The give-up tests' match log opens")
	net.mode = "server"
	var server: Node = load("res://scripts/server/duel_server.gd").new()
	server.match_log = log
	_link_server(net, server, true)
	var inbox: Dictionary = {}
	net._outbox = func(peer: int, method: StringName, args: Array) -> void:
		if not inbox.has(peer):
			inbox[peer] = []
		(inbox[peer] as Array).append([String(method), args])
	var journal: Array[String] = []
	net._journal = func(line: String) -> void: journal.append(line)
	var day: String = log.day_path(int(Time.get_unix_time_from_system()))
	var ended: Array = []
	var on_ended: Callable = func(code: String, winner: int, reason: String) -> void: ended.append([code, winner, reason, _line_count(day)])
	net.room_ended.connect(on_ended)

	var room: DuelRoom = _dealt_room(net, session, 161, 162, [0, 2], ["Ada", "Bryn"])
	var host: DuelHost = server.hosts[room.code]
	var tokens: Array[String] = room.tokens.duplicate()
	inbox.clear()
	var answer: Dictionary = net._on_give_up(170, {"code": room.code, "token": tokens[1]})
	_check(answer == {"refused": net.STILL_CONNECTED, "again": true} and room.phase == DuelRoom.Phase.DUEL,
		"A give-up for a seat the server still counts as connected is asked to try again: %s" % str(answer))
	net._on_peer_disconnected(162)
	var refusals: Array = [net._on_give_up(171, {"code": room.code, "token": "0".repeat(64)}),
		net._on_give_up(172, {"code": "ZZZZZ", "token": tokens[1]}), net._on_give_up(173, "junk"),
		net._on_give_up(174, {"code": 5, "token": null})]
	_check(refusals == [{"refused": "That duel has no seat for this copy of the game."}, {"refused": net.REJOIN_GONE},
		{"refused": net.REJOIN_GONE}, {"refused": net.REJOIN_GONE}] and room.phase == DuelRoom.Phase.DUEL and ended.is_empty(),
		"A wrong token, a wrong room and malformed requests are refused with a reason: %s" % str(refusals))
	inbox.clear()
	answer = net._on_give_up(175, {"code": room.code.to_lower(), "token": tokens[1]})
	var record: MatchRecord = _last_record(day)
	_check(answer == {"gave_up": true} and _last(ended) == [room.code, 0, "concede", 1],
		"An away seat's give-up with its token ends the duel at once as a concession, its record on disk before anyone hears it")
	_check(record != null and str(record.result["reason"]) == "concede" and int(record.result["winner"]) == 0
		and record.disconnects == [0, 1] and record.reconnects == [0, 0], "The record says concede, a win for the other seat, and counts the drop")
	_check(room.phase == DuelRoom.Phase.OVER and not server.hosts.has(room.code) and room.seat_peer == [161, 0] and room.tokens == ["", ""]
		and _methods(inbox, 161) == ["_rpc_duel_ended", "_rpc_seat_left"] and (inbox[161] as Array)[0][1] == [0, "concede"],
		"The other player hears the concession, then that the seat is empty: %s" % str(inbox.get(161, [])))
	_check(not inbox.has(175) and room.seat_of(175) < 0, "The giver-up's connection is never seated or sent anything")
	answer = net._on_give_up(176, {"code": room.code, "token": tokens[1]})
	_check(answer == {"refused": net.REJOIN_OVER}, "A give-up for a finished duel is refused: %s" % str(answer))

	var both: DuelRoom = _dealt_room(net, session, 181, 182, [0, 2], ["Cato", "Dara"])
	var both_tokens: Array[String] = both.tokens.duplicate()
	var closing: String = both.code
	net._on_peer_disconnected(181)
	net._on_peer_disconnected(182)
	answer = net._on_give_up(183, {"code": closing, "token": both_tokens[0]})
	record = _last_record(day)
	_check(answer == {"gave_up": true} and _last(ended) == [closing, 1, "concede", 2] and not net.rooms.has(closing),
		"With both seats away the giver-up loses at once and the room closes")
	_check(record != null and str(record.result["reason"]) == "concede" and int(record.result["winner"]) == 1 and record.disconnects == [1, 1],
		"and the record says so")
	var leaked: Array[String] = []
	var records_text: String = FileAccess.get_file_as_string(day)
	for token in tokens + both_tokens:
		if records_text.contains(token):
			leaked.append("a record")
		for line in journal:
			if line.contains(token):
				leaked.append(line)
	_check(leaked.is_empty() and not journal.is_empty(), "No token is in a record or a journal line: %s" % str(leaked))
	net._outbox = Callable()
	net._journal = Callable()
	net.room_ended.disconnect(on_ended)
	_link_server(net, server, false)
	server.free.call_deferred()
	net.leave()
	_remove_tree(GIVE_UP_DIR)

	var now: int = int(Time.get_unix_time_from_system())
	var ticket: Dictionary = {"server": "127.0.0.1:9", "code": "K7QMR", "seat": 1, "token": "cd".repeat(32),
		"names": ["Ada", "Bryn"], "decks": ["a", "b"], "expires": now + 60}
	net.give_up()
	_check(net._courier_ticket.is_empty(), "Give up without a rejoin file sends nothing")
	RejoinFile.write(ticket)
	_check(not net.give_up() and not FileAccess.file_exists(RejoinFile.path()) and str(net._courier_ticket.get("code", "")) == "K7QMR"
		and str(net._courier_ticket.get("token", "")) == ticket["token"] and net._courier_next > 0,
		"Give up while cut off deletes the rejoin file at once and sends the concession for that seat")
	net.leave()
	_check(not net._courier_ticket.is_empty(), "Leaving the connection straight after does not stop it")
	net._courier_heard({"refused": net.STILL_CONNECTED, "again": true})
	_check(not net._courier_ticket.is_empty() and net._courier_next > Time.get_ticks_msec(), "A try-again answer tries again shortly")
	net._courier_heard({"gave_up": true})
	_check(net._courier_ticket.is_empty(), "A concession taken ends it")
	net._send_give_up(ticket)
	net._courier_heard({"refused": net.REJOIN_OVER})
	_check(net._courier_ticket.is_empty(), "A refusal ends it")
	net._send_give_up(ticket)
	net._courier_heard({})
	_check(net._courier_ticket.is_empty(), "No answer (the server out of reach) ends it, the file already gone")
	net._drop_courier()


const QUEUE_DIR: String = "user://test_match_records_queue"


## Find a duel on the server, through the handlers the RPCs, the sweep and a dropped connection
## call, with made-up peer ids. A queued peer can do nothing but wait; two waiting pair into a queue
## room nobody can join by code; a picking peer cannot send commands; once both lock, picks are
## final and the server deals once, QUEUE_BEAT_MS later; the typed names never reach the other
## seat; the record says casual. A leave in the pick or the matchup, and a lock-in time run out,
## send the player still there back to the front of the queue, and a peer that did not lock in, or
## waited QUEUE_MAX_WAIT_MS, is dropped with a reason.
func _queue_tests(net: Node, session: Node) -> void:
	_remove_tree(QUEUE_DIR)
	var log: MatchLog = MatchLog.new()
	_check(log.open(QUEUE_DIR) == "", "The queue tests' match log opens")
	net.mode = "server"
	var server: Node = load("res://scripts/server/duel_server.gd").new()
	server.match_log = log
	_link_server(net, server, true)
	var inbox: Dictionary = {}
	var everything: Array = []
	net._outbox = func(peer: int, method: StringName, args: Array) -> void:
		if not inbox.has(peer):
			inbox[peer] = []
		(inbox[peer] as Array).append([String(method), args])
		everything.append([peer, String(method), args])
	var journal: Array[String] = []
	net._journal = func(line: String) -> void: journal.append(line)
	var commands: Array = []
	var on_command: Callable = func(code: String, seat: int, _cmd: Dictionary) -> void: commands.append([code, seat])
	net.room_command.connect(on_command)
	var day: String = log.day_path(int(Time.get_unix_time_from_system()))
	var deck_a: String = session.decks[3].name
	var deck_b: String = session.decks[5].name

	net._on_queue_join(201, {"rating": 1500})
	_check(net.queue.has(201) and net.rooms.is_empty() and inbox.get(201, []) == [["_rpc_queue_state", ["queued", "", 0]]],
		"A peer joins the queue, a ticket key it does not know ignored, and hears it is queued: %s" % str(inbox.get(201, [])))
	inbox.clear()
	net._on_queue_join(201, {})
	net._on_lobby_pick(201, 3, deck_a, "Ada", true)
	net._on_submit(201, {"player": 0, "type": "pass", "card": -1, "value": null})
	net._on_deal_ready(201)
	net._on_room_request(201, "")
	_check(net.queue.size() == 1 and net.rooms.is_empty() and commands.is_empty() and _quiet(inbox, [201]),
		"A queued peer's second join, pick, command, deal request and room request are all refused")
	_check(_journal_has(journal, "refused a pick while queued from peer 201") and _journal_has(journal, "refused a command while queued from peer 201"),
		"and the journal says so")

	net._on_queue_join(202, {})
	var room: DuelRoom = net._room_of(201)
	_check(room != null and room == net._room_of(202) and room.kind == "queue" and net.queue.size() == 0,
		"The next peer to join pairs with the one waiting, into a queue room")
	var seat_a: int = room.seat_of(201) if room != null else -1
	var seat_b: int = 1 - seat_a
	_check(seat_a >= 0 and room.joined_msec[seat_a] > 0 and room.pick_deadline_msec > 0 and room.deal_at_msec == 0,
		"with each seat's join time and a lock-in deadline")
	_check(_first_args(inbox, 201, "_rpc_matched") == [seat_a, 60, room.code] and _first_args(inbox, 202, "_rpc_matched") == [seat_b, 60, room.code],
		"Each hears its seat and 60 seconds to lock in")
	_check(_journal_has(journal, "queue: paired peer 201"), "The journal has the pairing")
	net._on_room_request(203, room.code)
	_check(room.seat_of(203) < 0 and _methods(inbox, 203) == ["_rpc_room_failed"] and str(inbox[203][0][1][0]).begins_with("No room has the code"),
		"A share code naming a queue room is refused as no such room")
	net._on_lobby_pick(201, 3, deck_a, "Ada Secret", false)
	net._on_lobby_pick(202, 5, deck_b, "Bryn Secret", false)
	net._on_submit(201, {"player": seat_a, "type": "pass", "card": -1, "value": null})
	_check(commands.is_empty() and _journal_has(journal, "room %s: refused a command outside a duel from peer 201" % room.code),
		"A picking peer's command is refused")
	inbox.clear()
	net._on_queue_join(202, {})
	_check(net._room_of(202) == room and not net.queue.has(202) and _first_args(inbox, 202, "_rpc_queue_state") == ["dropped", "Finish or leave your duel first.", 0],
		"A peer still picking cannot join the queue again")
	net._on_lobby_pick(201, 3, deck_a, "Ada Secret", true)
	var locked_at: int = Time.get_ticks_msec()
	net._on_lobby_pick(202, 5, deck_b, "Bryn Secret", true)
	_check(room.both_locked() and room.phase == DuelRoom.Phase.LOBBY and room.pick_deadline_msec == 0
		and room.deal_at_msec >= locked_at + net.QUEUE_BEAT_MS and room.deal_at_msec <= Time.get_ticks_msec() + net.QUEUE_BEAT_MS,
		"Both locked in: the deal waits 5 seconds")
	net._on_lobby_pick(202, 5, deck_b, "Bryn Secret", false)
	net._on_lobby_pick(202, 4, session.decks[4].name, "Bryn Secret", true)
	_check(room.seat_locked(seat_b) and int(room.lobby[seat_b]["deck"]) == 5, "Once both have locked, an unlock or a new pick is refused")
	net._on_deal_ready(201)
	net._on_deal_ready(202)
	net._on_back_to_lobby(201)
	_check(room.phase == DuelRoom.Phase.LOBBY and not server.hosts.has(room.code), "A client's deal request does not deal a queue room")
	var deal_at: int = room.deal_at_msec
	net.sweep(deal_at - 1)
	_check(room.phase == DuelRoom.Phase.LOBBY and _count(inbox, 201, "_rpc_start") == 0, "One millisecond short of the beat nothing is dealt")
	net.sweep(deal_at)
	net.sweep(deal_at + 1000)
	net.sweep(deal_at + 2000)
	_check(room.phase == DuelRoom.Phase.DUEL and server.hosts.has(room.code) and _count(inbox, 201, "_rpc_start") == 1
		and _count(inbox, 202, "_rpc_start") == 1, "At the beat the server deals, once")
	var start: Array = _first_args(inbox, 201, "_rpc_start")
	_check(start.size() == 8 and start[4] == "Player 1" and start[5] == "Player 2", "The deal names the seats by their stock names: %s" % str(start.slice(0, 7)))
	net._on_concede(202)
	var record: MatchRecord = _last_record(day)
	_check(record != null and record.mode == "casual" and str(record.result["reason"]) == "concede", "A queue duel's record says casual")
	var duelists: Array[String] = [session.duelist_name(session.decks[int(room.lobby[0]["deck"])]), session.duelist_name(session.decks[int(room.lobby[1]["deck"])])]
	_check(record != null and [str(record.seats[0]["name"]), str(record.seats[1]["name"])] == duelists,
		"and names the seats by their duelists: %s" % (str(record.seats) if record != null else "no record"))
	net._on_back_to_lobby(201)
	_check(room.phase == DuelRoom.Phase.OVER, "A finished queue duel has no way back to the lobby")
	net._on_rematch(201)
	net._on_rematch(202)
	_check(room.phase == DuelRoom.Phase.DUEL and _count(inbox, 201, "_rpc_start") == 2, "Both asking deals a rematch in the queue room")
	net._on_concede(201)
	await process_frame
	var leaks: Array[String] = []
	for sent: Array in everything:
		var peer: int = sent[0]
		var body: String = JSON.stringify(_unpack(sent[2])) if sent[1] == "_rpc_update" else str(sent[2])
		if (peer == 201 and body.contains("Bryn Secret")) or (peer == 202 and body.contains("Ada Secret")):
			leaks.append("%d %s" % [peer, sent[1]])
	_check(leaks.is_empty() and not FileAccess.get_file_as_string(day).contains("Secret"),
		"No message, update or record ever carries the other player's typed name: %s" % str(leaks))

	inbox.clear()
	net._on_queue_join(201, {})
	_check(net.queue.has(201) and room.seat_of(201) < 0 and net.rooms.has(room.code) and _methods(inbox, 202) == ["_rpc_seat_left"],
		"Find another duel from a finished duel lets the old room go first, and the player still there hears it: %s" % str(_methods(inbox, 202)))
	net._on_queue_join(211, {})
	var second: DuelRoom = net._room_of(211)
	_check(second != null and second == net._room_of(201) and second != room, "and pairs again on the same connection")
	var seat_211: int = second.seat_of(211) if second != null else -1
	if second != null and seat_211 >= 0:
		second.joined_msec[1 - seat_211] = Time.get_ticks_msec() - 42000
	inbox.clear()
	net._on_peer_disconnected(211)
	_check(second != null and not net.rooms.has(second.code) and net.queue.has(201) and net._room_of(201) == null and not net._unseated.has(201),
		"A leave during the pick closes the room and puts the other player back in the queue")
	var requeued: Array = _first_args(inbox, 201, "_rpc_queue_state")
	_check(_methods(inbox, 201) == ["_rpc_queue_state"] and requeued.slice(0, 2) == ["requeued", net.QUEUE_OTHER_LEFT],
		"who hears why: %s" % str(inbox.get(201, [])))
	_check(requeued.size() == 3 and int(requeued[2]) >= 42000 and int(requeued[2]) < 43000,
		"and how long it has waited since its first join, so its count goes on from there: %s" % str(requeued))
	_check(second != null and _journal_has(journal, "room %s: pick abandoned by seat %d in the pick" % [second.code, seat_211 + 1]),
		"and the journal has the seat and the stage it was abandoned in")

	net._on_queue_join(212, {})
	var third: DuelRoom = net._room_of(212)
	var seat_212: int = third.seat_of(212) if third != null else 0
	net._on_lobby_pick(212, 3, deck_a, "Cato", true)
	net._on_lobby_pick(201, 5, deck_b, "Ada", true)
	var third_deal: int = third.deal_at_msec if third != null else 0
	inbox.clear()
	net._on_peer_disconnected(201)
	net.sweep(third_deal)
	_check(third != null and not net.rooms.has(third.code) and not server.hosts.has(third.code) and net.queue.has(212) and third_deal > 0,
		"A leave in the matchup beat closes the room before the deal and puts the other player back in the queue")
	_check(_methods(inbox, 212) == ["_rpc_queue_state"] and _first_args(inbox, 212, "_rpc_queue_state").slice(0, 2) == ["requeued", net.QUEUE_OTHER_LEFT]
		and _journal_has(journal, "in the matchup"), "who hears why, and the journal says it was the matchup: %s" % str(inbox.get(212, [])))
	_check(third != null and net.queue.size() == 1 and int(net.queue.entries[0]["joined_msec"]) == third.joined_msec[seat_212],
		"It waits from its first join")

	net.max_live_duels = 1
	net._on_queue_join(221, {})
	var fourth: DuelRoom = net._room_of(221)
	var seat_221: int = fourth.seat_of(221) if fourth != null else -1
	net._on_lobby_pick(212, 3, deck_a, "Cato", true)
	net._on_lobby_pick(221, 5, deck_b, "Dara", false)
	inbox.clear()
	net._on_queue_join(231, {})
	net._on_queue_join(232, {})
	_check(fourth != null and fourth == net._room_of(212) and net.queue.size() == 2 and net._room_of(231) == null,
		"At the duel cap two more waiting are held back")
	_check(_first_args(inbox, 232, "_rpc_queue_state") == ["queued", "", 0] and _state_args(inbox, 232, "queued", net.QUEUE_FULL).size() == 3,
		"and hear the server is full: %s" % str(inbox.get(232, [])))
	var held: Array = _state_args(inbox, 231, "queued", net.QUEUE_FULL)
	_check(held.size() == 3 and int(held[2]) >= 0 and int(held[2]) < 1000, "with how long each has waited: %s" % str(held))
	inbox.clear()
	net.sweep(fourth.pick_deadline_msec - 1 if fourth != null else 0)
	_check(fourth != null and net.rooms.has(fourth.code), "One millisecond short of the lock-in time the pick goes on")
	net.sweep(fourth.pick_deadline_msec if fourth != null else 0)
	_check(fourth != null and not net.rooms.has(fourth.code) and inbox.get(221, []) == [["_rpc_queue_state", ["dropped", net.QUEUE_LATE, 0]]]
		and not net.queue.has(221), "At the lock-in time the seat that did not lock is dropped with the reason, nothing picked for it")
	var fifth: DuelRoom = net._room_of(212)
	_check(_first_args(inbox, 212, "_rpc_queue_state").slice(0, 2) == ["requeued", net.QUEUE_OTHER_LATE] and fifth != null and fifth == net._room_of(231)
		and net._room_of(232) == null and net.queue.size() == 1 and net.queue.has(232),
		"and the seat that locked goes back to the front, ahead of the two held, and pairs with the older: %s" % str(inbox.get(212, [])))
	_check(fourth != null and _journal_has(journal, "room %s: pick timed out, seat %d did not lock in" % [fourth.code, seat_221 + 1]),
		"The journal says the pick timed out and which seat did not lock in")

	inbox.clear()
	var later: int = Time.get_ticks_msec() + net.QUEUE_MAX_WAIT_MS
	net.sweep(later)
	_check(inbox.get(232, []) == [["_rpc_queue_state", ["dropped", net.QUEUE_NO_OPPONENT, 0]]] and net.queue.size() == 0,
		"A player waiting 30 minutes is dropped with the reason: %s" % str(inbox.get(232, [])))
	_check(fifth != null and not net.rooms.has(fifth.code) and _first_args(inbox, 212, "_rpc_queue_state") == ["dropped", net.QUEUE_LATE, 0]
		and _first_args(inbox, 231, "_rpc_queue_state") == ["dropped", net.QUEUE_LATE, 0], "and a pick where neither locks in drops both")

	net.max_live_duels = 0
	net._outbox = Callable()
	net._journal = Callable()
	net.room_command.disconnect(on_command)
	_link_server(net, server, false)
	server.free.call_deferred()
	net.leave()
	_remove_tree(QUEUE_DIR)


const IDENTITY_DIR: String = "user://test_match_records_identity"


## Identities on the duel server, through `greeting_reply` as the auth channel calls it and the
## handlers the RPCs call, with made-up peer ids. A hello without a key, or with a malformed one, is
## refused. A proof by another key, over the bare nonce, or malformed is refused; each nonce is spent
## on the first proof that comes back, and a proof replayed on another connection meets a new nonce.
## A good proof lets the peer in with its identity, which the seat it takes and the match record
## carry. A rejoin or a give-up with the right token from another identity is refused, and from the
## identity that took the seat goes through. The queue ticket carries the client's identity, one
## naming another is refused, and a queue room seats each player's identity.
func _identity_tests(net: Node, session: Node) -> void:
	_remove_tree(IDENTITY_DIR)
	var log: MatchLog = MatchLog.new()
	_check(log.open(IDENTITY_DIR) == "", "The identity tests' match log opens")
	net.mode = "server"
	var server: Node = load("res://scripts/server/duel_server.gd").new()
	server.match_log = log
	_link_server(net, server, true)
	var inbox: Dictionary = {}
	net._outbox = func(peer: int, method: StringName, args: Array) -> void:
		if not inbox.has(peer):
			inbox[peer] = []
		(inbox[peer] as Array).append([String(method), args])
	var journal: Array[String] = []
	net._journal = func(line: String) -> void: journal.append(line)
	var day: String = log.day_path(int(Time.get_unix_time_from_system()))
	var ada: Identity = Identity.generate()
	var bryn: Identity = Identity.generate()
	var cato: Identity = Identity.generate()
	var hello: Dictionary = {"protocol": net.PROTOCOL, "catalog": net.catalog_fingerprint()}

	var bare: Dictionary = net.greeting_reply(301, hello)
	_check(bare.get("refused", "") == net.NO_KEY and not net._peer_identity.has(301), "A hello without a key is refused with a reason: %s" % str(bare))
	_check(net.greeting_reply(301, _hello_of(hello, ada)).is_empty() and not net._peer_identity.has(301),
		"and that connection gets no second try")
	var odd: Dictionary = net.greeting_reply(302, hello.merged({"ticket": {"kind": "key", "public": "-----BEGIN PUBLIC KEY-----\nAAAA\n-----END PUBLIC KEY-----\n"}}))
	var other_kind: Dictionary = net.greeting_reply(303, hello.merged({"ticket": {"kind": "steam", "public": ada.public_pem()}}))
	_check(odd.get("refused", "") == net.NO_KEY and other_kind.get("refused", "") == net.NO_KEY, "A malformed key or a ticket of another kind is refused")

	var challenge: Dictionary = net.greeting_reply(304, _hello_of(hello, ada))
	var nonce: PackedByteArray = challenge.get("nonce", PackedByteArray())
	_check(nonce.size() == net.NONCE_BYTES and not net._peer_identity.has(304), "A hello with a key gets a nonce and is not let in yet")
	var forged: Dictionary = net.greeting_reply(304, {"proof": bryn.sign(net.challenge_bytes(nonce))})
	_check(forged.get("refused", "") == net.BAD_PROOF and not net._peer_identity.has(304), "A proof signed by another key is refused with a reason")
	_check(net.greeting_reply(304, {"proof": ada.sign(net.challenge_bytes(nonce))}).is_empty() and not net._peer_identity.has(304),
		"and its nonce is spent: the right proof after it lets nothing in")
	var bare_nonce: PackedByteArray = net.greeting_reply(305, _hello_of(hello, ada)).get("nonce", PackedByteArray())
	_check(net.greeting_reply(305, {"proof": ada.sign(bare_nonce)}).get("refused", "") == net.BAD_PROOF,
		"A signature over the nonce alone, without the protocol and the catalog, is refused")
	net.greeting_reply(306, _hello_of(hello, ada))
	_check(net.greeting_reply(306, {"proof": "signed"}).get("refused", "") == net.BAD_PROOF, "A malformed proof is refused")

	var ada_nonce: PackedByteArray = net.greeting_reply(311, _hello_of(hello, ada)).get("nonce", PackedByteArray())
	var ada_proof: Dictionary = {"proof": ada.sign(net.challenge_bytes(ada_nonce))}
	_check(net.greeting_reply(311, ada_proof) == {"ok": net.PROTOCOL} and net._peer_identity.get(311, "") == ada.id(),
		"A good proof lets the peer in with its identity")
	_check(_journal_has(journal, "peer 311: identity %s" % Identity.short(ada.id())) and not _journal_has(journal, ada.id()),
		"and the journal names it by its short id only")
	_check(net.greeting_reply(311, ada_proof).is_empty(), "An admitted peer's further greeting gets no answer")
	var replay_nonce: PackedByteArray = net.greeting_reply(312, _hello_of(hello, ada)).get("nonce", PackedByteArray())
	_check(replay_nonce.size() == net.NONCE_BYTES and replay_nonce != ada_nonce and net.greeting_reply(312, ada_proof).get("refused", "") == net.BAD_PROOF
		and not net._peer_identity.has(312), "A proof replayed on another connection meets a new nonce and is refused")
	var own_nonce: PackedByteArray = net.greeting_reply(314, net._hello()).get("nonce", PackedByteArray())
	_check(net.greeting_reply(314, net.proof_for(own_nonce)).has("ok") and net._peer_identity.get(314, "") == net.identity().id(),
		"This client's own hello and proof pass the server's greeting")
	_check(_admit(net, 313, bryn, hello), "A second player is let in")

	var room: DuelRoom = _dealt_room(net, session, 311, 313, [0, 2], ["Ada", "Bryn"])
	var host: DuelHost = server.hosts.get(room.code)
	_check(room.seat_identity == [ada.id(), bryn.id()], "Each seat carries the identity of the peer that took it")
	_check(host != null and str(host.record.seats[0]["identity"]) == ada.id() and str(host.record.seats[1]["identity"]) == bryn.id(),
		"and so does the duel's record")
	var tokens: Array[String] = room.tokens.duplicate()
	net._on_peer_disconnected(313)
	_check(not net._peer_identity.has(313) and room.seat_identity[1] == bryn.id() and room.away_since[1] > 0,
		"A dropped player's identity stays with its away seat")
	_check(_admit(net, 321, cato, hello), "A third player is let in")
	inbox.clear()
	net._on_rejoin(321, room.code, tokens[1])
	_check(room.seat_peer[1] == 0 and inbox.get(321, []) == [["_rpc_rejoin_failed", [net.SEAT_ELSEWHERE]]],
		"A rejoin with the right token from another identity is refused: %s" % str(inbox.get(321, [])))
	var courier: Dictionary = net.greeting_reply(322, _hello_of(hello, cato).merged({"give_up": {"code": room.code, "token": tokens[1]}}))
	var answer: Dictionary = net.greeting_reply(322, {"proof": cato.sign(net.challenge_bytes(courier.get("nonce", PackedByteArray())))})
	_check(answer == {"refused": net.SEAT_ELSEWHERE} and room.phase == DuelRoom.Phase.DUEL and not net._peer_identity.has(322),
		"A give-up with the right token from another identity is refused, and its connection is never let in: %s" % str(answer))
	_check(_admit(net, 323, bryn, hello), "The seat's own player connects again")
	net._on_rejoin(323, room.code, tokens[1])
	_check(room.seat_peer[1] == 323 and room.away_since[1] == 0, "and takes its seat back")
	net._on_peer_disconnected(323)
	courier = net.greeting_reply(324, _hello_of(hello, bryn).merged({"give_up": {"code": room.code, "token": tokens[1]}}))
	answer = net.greeting_reply(324, {"proof": bryn.sign(net.challenge_bytes(courier.get("nonce", PackedByteArray())))})
	_check(answer == {"gave_up": true} and room.phase == DuelRoom.Phase.OVER and not net._peer_identity.has(324),
		"and, cut off again, gives it up from a connection of its own: %s" % str(answer))
	var record: MatchRecord = _last_record(day)
	_check(record != null and str(record.seats[0]["identity"]) == ada.id() and str(record.seats[1]["identity"]) == bryn.id()
		and str(record.result["reason"]) == "concede", "The record on disk carries both identities")
	_check(record != null and log.verify(record), "under the server's signature")

	_check(net.queue_ticket() == {"identity": net.identity().id()}, "The client's queue ticket carries its identity")
	_check(_admit(net, 331, ada, hello) and _admit(net, 332, bryn, hello) and _admit(net, 333, cato, hello), "Three players connect for the queue")
	net._on_queue_join(333, {"identity": ada.id()})
	_check(not net.queue.has(333) and _journal_has(journal, "refused a queue ticket for another identity from peer 333"),
		"A queue ticket naming another identity is refused")
	net._on_queue_join(331, {"identity": ada.id()})
	net._on_queue_join(332, {"identity": bryn.id()})
	var paired: DuelRoom = net._room_of(331)
	_check(paired != null and paired == net._room_of(332) and paired.seat_identity[paired.seat_of(331)] == ada.id()
		and paired.seat_identity[paired.seat_of(332)] == bryn.id(), "A queue room seats each player's identity")

	net._outbox = Callable()
	net._journal = Callable()
	_link_server(net, server, false)
	server.free.call_deferred()
	net.leave()
	_remove_tree(IDENTITY_DIR)


static func _hello_of(hello: Dictionary, who: Identity) -> Dictionary:
	return hello.merged({"ticket": {"kind": "key", "public": who.public_pem()}})


## Peer `peer` greets as `who` and proves its key; true once it is let in.
static func _admit(net: Node, peer: int, who: Identity, hello: Dictionary) -> bool:
	var nonce: PackedByteArray = net.greeting_reply(peer, _hello_of(hello, who)).get("nonce", PackedByteArray())
	return net.greeting_reply(peer, {"proof": who.sign(net.challenge_bytes(nonce))}).has("ok")


static func _journal_has(journal: Array[String], text: String) -> bool:
	for line in journal:
		if line.contains(text):
			return true
	return false


## The arguments of the first `method` message to `peer`, [] for none.
static func _first_args(got: Dictionary, peer: int, method: String) -> Array:
	for message: Array in got.get(peer, []):
		if message[0] == method:
			return message[1]
	return []


## The arguments of the first `_rpc_queue_state(state, reason, ms)` to `peer` with that state and
## reason, [] for none.
static func _state_args(got: Dictionary, peer: int, state: String, reason: String) -> Array:
	for message: Array in got.get(peer, []):
		var args: Array = message[1]
		if message[0] == "_rpc_queue_state" and args.size() >= 2 and args[0] == state and args[1] == reason:
			return args
	return []


## A code room dealt through the lobby handlers, `_start_room` and the server's `room_started`
## handler, as two clients would deal it.
func _dealt_room(net: Node, session: Node, peer_a: int, peer_b: int, decks: Array, names: Array) -> DuelRoom:
	net._on_room_request(peer_a, "")
	var room: DuelRoom = net._room_of(peer_a)
	net._on_room_request(peer_b, room.code)
	net._on_lobby_pick(peer_a, int(decks[0]), session.decks[int(decks[0])].name, str(names[0]), true)
	net._on_lobby_pick(peer_b, int(decks[1]), session.decks[int(decks[1])].name, str(names[1]), true)
	net._on_deal_ready(peer_a)
	net._on_deal_ready(peer_b)
	return room


## The server scene's handlers on Net's room signals, as its `_ready` connects them, or off again.
func _link_server(net: Node, server: Node, on: bool) -> void:
	var links: Array = [[net.room_started, server._on_room_started], [net.room_command, server._on_room_command],
		[net.room_ended, server._on_room_ended], [net.room_closed, server._on_room_closed],
		[net.room_prompt_shown, server._on_room_prompt_shown], [net.room_seat_away, server._on_room_seat_away],
		[net.room_rejoined, server._on_room_rejoined]]
	for link: Array in links:
		var sig: Signal = link[0]
		var handler: Callable = link[1]
		if on:
			sig.connect(handler)
		elif sig.is_connected(handler):
			sig.disconnect(handler)


## What each peer was sent since the last look, taken out of `inbox`. Each message is checked
## against the room and seat the peer holds in `who` (peer -> [DuelRoom, seat]); a peer holding no
## seat may only be refused. Tokens dealt to the rooms in `who` are gathered into `tokens`, and no
## message but a seat's own deal may carry one. A peer's last update must show its room's table as
## it stands, and clocks must equal their room's host at `clock_at` when one is given. Anything
## else lands in `problems`.
func _read_inboxes(server: Node, inbox: Dictionary, who: Dictionary, tokens: Array[String], problems: Array[String],
		clock_at: int = -1) -> Dictionary:
	for entry: Array in who.values():
		for token: String in (entry[0] as DuelRoom).tokens:
			if token != "" and not tokens.has(token):
				tokens.append(token)
	var out: Dictionary = {}
	for peer: int in inbox.keys():
		var messages: Array = (inbox[peer] as Array).duplicate()
		(inbox[peer] as Array).clear()
		out[peer] = messages
		var last: Dictionary = {}
		for message: Array in messages:
			var method: String = message[0]
			var args: Array = message[1]
			var problem: String = ""
			if not who.has(peer):
				problem = "" if method in ["_rpc_rejoin_failed", "_rpc_room_failed"] else "no seat, but %s" % method
			else:
				var room: DuelRoom = who[peer][0]
				problem = _foreign(method, args, room, int(who[peer][1]), server.hosts.get(room.code, null), clock_at)
			var scanned: String = str(args.slice(0, 7)) if method == "_rpc_start" else str(args)
			for token in tokens:
				if scanned.contains(token):
					problem = "a token in %s" % method
			if problem != "":
				problems.append("peer %d: %s" % [peer, problem])
			if method == "_rpc_update":
				last = _unpack(args)
		if who.has(peer) and not last.is_empty():
			var host: DuelHost = server.hosts.get((who[peer][0] as DuelRoom).code, null)
			if host != null and JSON.stringify(last["view"]) != JSON.stringify(host.view_for(int(who[peer][1])).to_dict()):
				problems.append("peer %d: its last update is not its room's table" % peer)
	return out


## Why a message sent to seat `seat` of `room` is not that seat's own, or "".
func _foreign(method: String, args: Array, room: DuelRoom, seat: int, host: DuelHost, clock_at: int) -> String:
	match method:
		"_rpc_assign_seat":
			return "" if args == [seat, room.code] else "a seat elsewhere: %s" % str(args)
		"_rpc_lobby":
			return "" if args.size() == 3 and (args[0] as Array).size() == 2 else "a malformed lobby"
		"_rpc_start":
			return "" if args.size() == 8 and str(args[7]) == room.tokens[seat] and str(args[4]) == str(room.lobby[0]["name"]) \
				and str(args[5]) == str(room.lobby[1]["name"]) else "a deal that is not its own"
		"_rpc_resume":
			return "" if args.size() == 9 and int(args[0]) == seat and str(args[1]) == room.code else "a resume elsewhere"
		"_rpc_update":
			var update: Dictionary = _unpack(args)
			return "" if not update.is_empty() and int((update["view"] as Dictionary).get("seat", -1)) == seat else "another seat's update"
		"_rpc_clock":
			if int(args[0]) < 0 or int(args[0]) > 1:
				return "a clock for no seat"
			if clock_at < 0 or host == null:
				return ""
			var state: Dictionary = host.clock.state(int(args[0]), clock_at)
			return "" if [int(args[1]), int(args[2]), str(args[3])] == [int(state["left_ms"]), int(state["bank_ms"]), str(state["phase"])] \
				else "a clock %s where its room's host has %s" % [str(args), str(state)]
		"_rpc_duel_ended":
			return "" if room.phase == DuelRoom.Phase.OVER else "a result while its room still plays"
		"_rpc_record":
			var record: MatchRecord = MatchRecord.from_dict(JSON.parse_string(str(args[0])))
			return "" if record != null and record.seed_value == room.seed_value \
				and str(record.seats[seat]["name"]) == str(room.lobby[seat]["name"]) else "another room's record"
		"_rpc_seat_away", "_rpc_seat_back", "_rpc_seat_left", "_rpc_rematch_requested":
			return "" if int(args[0]) == 1 - seat else "news of its own seat"
		"_rpc_reject", "_rpc_to_lobby", "_rpc_rejoin_failed", "_rpc_room_failed":
			return ""
	return "unexpected %s" % method


static func _unpack(args: Array) -> Dictionary:
	if args.size() != 2 or not (args[0] is int) or not (args[1] is PackedByteArray):
		return {}
	var packed: PackedByteArray = args[1]
	var value: Variant = bytes_to_var(packed.decompress(int(args[0]), FileAccess.COMPRESSION_ZSTD))
	return value if value is Dictionary else {}


static func _count(got: Dictionary, peer: int, method: String) -> int:
	var n: int = 0
	for message: Array in got.get(peer, []):
		if message[0] == method:
			n += 1
	return n


static func _quiet(got: Dictionary, peers: Array) -> bool:
	for peer in peers:
		if not (got.get(peer, []) as Array).is_empty():
			return false
	return true


static func _methods(got: Dictionary, peer: int) -> Array:
	var out: Array = []
	for message: Array in got.get(peer, []):
		out.append(message[0])
	return out


static func _last(items: Array) -> Variant:
	return items[items.size() - 1] if not items.is_empty() else null


## A host's clocks as they stand: when each seat runs out, and each bank.
static func _clock_marks(host: DuelHost) -> Array:
	return [host.clock.out_at(0), host.clock.out_at(1), host.clock.bank_left(0, 0), host.clock.bank_left(1, 0)]


## When the host's first running clock runs out, -1 when none runs.
static func _first_out(host: DuelHost) -> int:
	var first: int = -1
	for seat in range(2):
		var at: int = host.clock.out_at(seat)
		if at >= 0 and (first < 0 or at < first):
			first = at
	return first


## What `room_ended` says for a room whose clocks run out at `at`: the other seat wins "timeout",
## or nobody when both seats run out then.
static func _timeout_of(code: String, host: DuelHost, at: int) -> Array:
	if host.clock.out_at(0) == at and host.clock.out_at(1) == at:
		return [code, -1, "abandoned"]
	return [code, 0 if host.clock.out_at(1) == at else 1, "timeout"]


func _last_record(path: String) -> MatchRecord:
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n", false)
	return MatchRecord.from_dict(JSON.parse_string(lines[lines.size() - 1])) if not lines.is_empty() else null


func _play_random(host: DuelHost, seed_value: int, limit: int) -> void:
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = seed_value
	for step in range(limit):
		if host.is_over():
			return
		var p: Prompt = host.referee.engine.prompt
		host.apply(p.player, p.options[picker.randi_range(0, p.options.size() - 1)].to_dict())


func _line_count(path: String) -> int:
	return FileAccess.get_file_as_string(path).split("\n", false).size() if FileAccess.file_exists(path) else 0


func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for file_name in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


const RANKED_DIR: String = "user://test_match_records_ranked"


## Ranked play on the duel server, through the handlers the RPCs, the sweep and a dropped connection
## call, with made-up peer ids and identities. A join on a leaver cooldown is dropped with the time
## left. Two players pair only inside their rating window, and anyone after 90 seconds. A match is
## best of 3 on locked picks: a game that does not decide it puts the room between games, the next
## is dealt when both are ready or after 20 seconds, and the loser of the last game opens. 2-0 and
## 2-1 end the match with one rating change, in the deciding record; "left" and "timeout" end it at
## once; Leave match loses it as a concession, between games too. Rematch and the lobby are refused.
## A dodge after the reveal is a leave, leaving before the lock-in is not, and an away seat keeps its
## token into the next game.
func _ranked_tests(net: Node, session: Node) -> void:
	_remove_tree(RANKED_DIR)
	var log: MatchLog = MatchLog.new()
	var ratings: RatingsStore = RatingsStore.new()
	var conduct: Conduct = Conduct.new()
	_check(log.open(RANKED_DIR) == "" and ratings.open(RANKED_DIR) == "" and conduct.open(RANKED_DIR) == "",
		"The ranked tests' records, ratings and leaves open")
	net.mode = "server"
	net.ratings = ratings
	net.conduct = conduct
	var server: Node = load("res://scripts/server/duel_server.gd").new()
	server.match_log = log
	_link_server(net, server, true)
	var inbox: Dictionary = {}
	net._outbox = func(peer: int, method: StringName, args: Array) -> void:
		if not inbox.has(peer):
			inbox[peer] = []
		(inbox[peer] as Array).append([String(method), args])
	var journal: Array[String] = []
	net._journal = func(line: String) -> void: journal.append(line)
	var day: String = log.day_path(int(Time.get_unix_time_from_system()))
	var now_unix: int = int(Time.get_unix_time_from_system())

	net._peer_identity[401] = _ranked_id(401)
	conduct.leave(_ranked_id(401), now_unix - 10)
	conduct.leave(_ranked_id(401), now_unix - 5)
	net._on_queue_join(401, {"mode": "ranked"})
	var answer: Array = _first_args(inbox, 401, "_rpc_queue_state")
	_check(not net.ranked_queue.has(401) and answer.size() == 3 and str(answer[0]) == "dropped"
		and str(answer[1]).begins_with("You can look for a duel again in 1:5"),
		"A ranked join on a leaver cooldown is dropped with the time left: %s" % str(answer))
	_check(answer.size() == 3 and answer[2] is int and int(answer[2]) > 110000 and int(answer[2]) <= 115000
		and str(answer[1]) == net.QUEUE_COOLDOWN % Conduct.wait_text(int(answer[2])),
		"and the time left in ms, which the line reads out, for the title to count down: %s" % str(answer))
	inbox.clear()
	net._on_queue_join(401, {})
	var casual_answer: Array = _first_args(inbox, 401, "_rpc_queue_state")
	_check(not net.queue.has(401) and casual_answer.size() == 3 and casual_answer[0] == "dropped" and int(casual_answer[2]) > 110000,
		"and so is a casual one: %s" % str(casual_answer))
	_check(_journal_has(journal, "%s on a leaver cooldown" % Identity.short(_ranked_id(401))), "The journal names the cooldown by the short id")
	net._peer_identity[402] = _ranked_id(402)
	net._on_queue_join(402, {"mode": "league"})
	_check(not net.queue.has(402) and not net.ranked_queue.has(402) and _journal_has(journal, "refused a queue ticket for an unknown mode from peer 402"),
		"A ticket naming an unknown mode is refused")
	net._peer_identity[403] = _ranked_id(403)
	conduct.leave(_ranked_id(403), now_unix - 100)
	net._on_queue_join(403, {})
	_check(net.queue.has(403) and _first_args(inbox, 403, "_rpc_queue_state") == ["queued", net.QUEUE_WARNED % 2, 0],
		"After one leave a player may queue, with a warning: %s" % str(_first_args(inbox, 403, "_rpc_queue_state")))
	net._on_peer_disconnected(403)

	for peer in [411, 412, 413, 414]:
		net._peer_identity[peer] = _ranked_id(peer)
	ratings.entries[_ranked_id(412)] = {"mu": 34.0, "sigma": 3.0, "games": 10, "wins": 5, "last_played": 0}
	ratings.entries[_ranked_id(414)] = {"mu": 60.0, "sigma": 3.0, "games": 10, "wins": 9, "last_played": 0}
	net._on_queue_join(411, {"mode": "ranked"})
	net._on_queue_join(412, {"mode": "ranked"})
	var joined: int = int(net.ranked_queue.entries[0]["joined_msec"])
	_check(net._room_of(411) == null and net.ranked_queue.size() == 2, "Two ranked players 9 mu apart do not pair at once")
	net.sweep(joined + 59000)
	_check(net._room_of(411) == null, "nor at 59 seconds")
	net.sweep(joined + 60000)
	var window_room: DuelRoom = net._room_of(411)
	_check(window_room != null and window_room == net._room_of(412) and window_room.ranked and window_room.best_of == 3 and window_room.kind == "queue",
		"At a minute the widened window pairs them into a ranked queue room")
	_check(_journal_has(journal, "queue: ranked pair peer 411 (mu 25.00") and _journal_has(journal, "(mu 34.00") and _journal_has(journal, "window 9.0 mu"),
		"and the journal has both mu and the window")
	net._on_peer_disconnected(411)
	net._on_peer_disconnected(412)
	_check(conduct.count(_ranked_id(411), now_unix) == 0, "Leaving a ranked pick before the lock-in is not a leave")
	net._on_queue_join(413, {"mode": "ranked"})
	net._on_queue_join(414, {"mode": "ranked"})
	joined = int(net.ranked_queue.entries[0]["joined_msec"])
	net.sweep(joined + 89000)
	_check(net._room_of(413) == null, "35 mu apart nobody pairs short of 90 seconds")
	net.sweep(joined + 90000)
	_check(net._room_of(413) != null and net._room_of(413) == net._room_of(414) and _journal_has(journal, "window open"),
		"and after 90 seconds anyone pairs")
	net._on_peer_disconnected(413)
	net._on_peer_disconnected(414)

	var room: DuelRoom = _ranked_room(net, session, 421, 422)
	var lost: int = room.seat_of(421) if room != null else 0
	var won: int = 1 - lost
	_check(room != null and room.phase == DuelRoom.Phase.DUEL and room.game == 1 and room.series_locked and room.match_id.length() == 16,
		"A ranked pair that locks in is dealt game 1 with its picks locked for the match")
	if room == null:
		return
	var methods: Array = _methods(inbox, 421)
	_check(methods.find("_rpc_series") >= 0 and methods.find("_rpc_series") < methods.find("_rpc_start")
		and _first_args(inbox, 421, "_rpc_series") == [3, 1, [0, 0]], "Each seat hears the series before the deal: %s" % str(_first_args(inbox, 421, "_rpc_series")))
	var tokens: Array[String] = room.tokens.duplicate()
	net._on_lobby_pick(421, 4, session.decks[4].name, "Ada", true)
	_check(int(room.lobby[lost]["deck"]) == 3 and _journal_has(journal, "refused a pick in a locked ranked match from peer 421"),
		"A pick is refused while the match is locked")
	inbox.clear()
	net._on_concede(421)
	_check(room.phase == DuelRoom.Phase.BETWEEN and room.wins[won] == 1 and room.next_deal_msec > Time.get_ticks_msec(),
		"Losing game 1 puts the room between games")
	_check(_methods(inbox, 422) == ["_rpc_duel_ended", "_rpc_game_over"] and str(_first_args(inbox, 422, "_rpc_game_over")) == str([1, room.wins, 20]),
		"and both hear the result, then the series score and the wait: %s" % str(inbox.get(422, [])))
	var first_game: MatchRecord = _last_record(day)
	_check(first_game != null and first_game.mode == "ranked" and first_game.match_id == room.match_id and first_game.game == 1
		and first_game.match_result.is_empty(), "Game 1's record is ranked, with the match id, game 1 and no match result")
	net._on_rematch(421)
	net._on_back_to_lobby(422)
	net._on_concede(422)
	_check(room.phase == DuelRoom.Phase.BETWEEN and _journal_has(journal, "refused a rematch request in a ranked room from peer 421")
		and _journal_has(journal, "refused a return to the lobby outside a finished share-code duel from peer 422"),
		"Rematch, back to the lobby and a concession are refused between games")
	net._on_next_ready(421)
	net.sweep(room.next_deal_msec - 1)
	_check(room.phase == DuelRoom.Phase.BETWEEN, "One ready seat and a millisecond short of the wait deal nothing")
	net._on_next_ready(422)
	var second: DuelHost = server.hosts.get(room.code, null)
	_check(room.phase == DuelRoom.Phase.DUEL and room.game == 2 and second != null, "Both ready deals game 2 at once")
	_check(second != null and second.record.first == {"seat": lost, "reason": "forced"} and second.referee.engine.state.active == lost,
		"The loser of game 1 opens game 2, forced: %s" % (str(second.record.first) if second != null else ""))
	_check(room.tokens == tokens, "Each seat keeps its rejoin token for the whole match")
	inbox.clear()
	net._on_concede(421)
	_check(room.phase == DuelRoom.Phase.OVER and _match_is(room.match_result, won, room.wins, "concede") and room.wins[won] == 2,
		"A second loss ends the match 2-0: %s" % str(room.match_result))
	var payload: Dictionary = _first_args(inbox, 422, "_rpc_match_over")[0] if not _first_args(inbox, 422, "_rpc_match_over").is_empty() else {}
	_check(_methods(inbox, 422) == ["_rpc_duel_ended", "_rpc_match_over"] and int(payload.get("winner", -2)) == won and bool(payload.get("rated", false)),
		"Both hear the game, then the match: %s" % str(inbox.get(422, [])))
	_check(str(payload.get("shown_before", [])) == "[0, 0]" and int(payload["shown_after"][won]) == 138 and int(payload["shown_after"][lost]) == 0
		and str(payload.get("provisional", [])) == "[true, true]", "with both shown ratings before and after: %s" % str(payload))
	_check(float(payload["rating_after"]["mu"]) > Rating.MU and not net.clean_match_payload(payload).is_empty(),
		"the winner's own mu and sigma, in a shape the client takes")
	var winner_id: String = _ranked_id(422)
	_check(int(ratings.entries[winner_id]["games"]) == 1 and int(ratings.entries[_ranked_id(421)]["games"]) == 1
		and float(ratings.entries[winner_id]["mu"]) > Rating.MU, "The rating applied once, to both")
	var on_disk: RatingsStore = RatingsStore.new()
	_check(on_disk.open(RANKED_DIR) == "" and on_disk.entries.has(winner_id), "and is in ratings.json")
	var deciding: MatchRecord = _last_record(day)
	_check(deciding != null and deciding.game == 2 and deciding.match_id == room.match_id
		and _match_is(deciding.match_result, won, room.wins, "concede"), "The deciding record carries the match")
	_check(deciding != null and deciding.seats[won].has("rating") and float(deciding.seats[won]["rating"]["after"]["mu"]) > Rating.MU
		and float(deciding.seats[lost]["rating"]["before"]["mu"]) == Rating.MU and log.verify(deciding),
		"and both ratings, under the server's signature")
	_check(_journal_has(journal, "game 1 to seat %d (concede), series" % (won + 1)) and _journal_has(journal, "shown 0 -> 138")
		and not _journal_has(journal, winner_id), "The journal has each game, the match and both rating changes, no identity in full")
	await process_frame
	var delivered: Array = []
	for message: Array in inbox.get(422, []):
		if message[0] == "_rpc_record":
			delivered.append(MatchRecord.from_dict(JSON.parse_string(str(message[1][0]))).game)
	_check(_count(inbox, 421, "_rpc_record") == 2 and delivered == [1, 2],
		"Both games' records go to both, game 1's though game 2 was dealt in the same frame: %s" % str(delivered))

	var three: DuelRoom = _ranked_room(net, session, 431, 432)
	var three_code: String = three.code if three != null else ""
	net._on_concede(three.seat_peer[1] if three != null else 0)
	var sweep_at: int = three.next_deal_msec if three != null else 0
	net.sweep(sweep_at - 1)
	_check(three != null and three.phase == DuelRoom.Phase.BETWEEN, "Without both ready, the room waits")
	net.sweep(sweep_at)
	var opened: DuelHost = server.hosts.get(three_code, null)
	_check(three != null and three.phase == DuelRoom.Phase.DUEL and three.game == 2 and opened != null and opened.referee.engine.state.active == 1,
		"and the sweep deals game 2 after 20 seconds, the loser opening")
	net._on_concede(three.seat_peer[0] if three != null else 0)
	net._on_next_ready(three.seat_peer[0] if three != null else 0)
	net._on_next_ready(three.seat_peer[1] if three != null else 0)
	var decider: DuelHost = server.hosts.get(three_code, null)
	_check(three != null and three.game == 3 and decider != null and decider.referee.engine.state.active == 0,
		"At 1-1 game 3 is dealt, game 2's loser opening")
	var picker: RandomNumberGenerator = RandomNumberGenerator.new()
	picker.seed = 5
	for step in range(3000):
		if decider == null or not server.hosts.has(three_code):
			break
		var p: Prompt = decider.referee.engine.prompt
		net._on_submit(three.seat_peer[p.player], p.options[picker.randi_range(0, p.options.size() - 1)].to_dict())
	_check(three != null and three.phase == DuelRoom.Phase.OVER and three.wins[0] + three.wins[1] == 3 and maxi(three.wins[0], three.wins[1]) == 2,
		"The rules finishing game 3 end the match 2-1: %s" % (str(three.wins) if three != null else ""))
	var third: MatchRecord = _last_record(day)
	_check(third != null and third.game == 3 and str(third.match_result.get("wins", [])) == str(three.wins)
		and ["survival", "seal", "ascension"].has(str(third.match_result.get("reason", ""))), "whose record carries the match")
	_check(_count(inbox, three.seat_peer[0] if three != null else 0, "_rpc_match_over") == 1, "and both hear it")

	var left_room: DuelRoom = _ranked_room(net, session, 441, 442)
	var gone: int = left_room.seat_of(441) if left_room != null else 0
	net._on_peer_disconnected(441)
	net.sweep((left_room.away_since[gone] if left_room != null else 0) + net.REJOIN_GRACE_MS)
	_check(left_room != null and left_room.phase == DuelRoom.Phase.OVER and str(left_room.match_result.get("reason", "")) == "left"
		and int(left_room.match_result["winner"]) == 1 - gone and left_room.rating_change.size() == 2,
		"A seat that does not come back in game 1 loses the match, rated")
	_check(conduct.count(_ranked_id(441), int(Time.get_unix_time_from_system())) == 1 and _journal_has(journal, "left the duel, a leave: a warning"),
		"and it is a leave, a warning the first time")

	var timed: DuelRoom = _ranked_room(net, session, 451, 452)
	var slow: int = timed.seat_of(451) if timed != null else 0
	net.end_room_duel(1 - slow, "timeout", timed.code if timed != null else "")
	_check(timed != null and timed.phase == DuelRoom.Phase.OVER and str(timed.match_result.get("reason", "")) == "timeout"
		and timed.wins[1 - slow] == 1 and conduct.count(_ranked_id(451), int(Time.get_unix_time_from_system())) == 0,
		"A clock run out in game 1 ends the match, and is not a leave")

	var quit: DuelRoom = _ranked_room(net, session, 461, 462)
	var quitter: int = quit.seat_of(461) if quit != null else 0
	inbox.clear()
	net._on_leave_match(461)
	_check(quit != null and quit.phase == DuelRoom.Phase.OVER and _match_is(quit.match_result, 1 - quitter, quit.wins, "concede_match")
		and _methods(inbox, 462) == ["_rpc_duel_ended", "_rpc_match_over"], "Concede match in a game loses the game and the match as a concession")
	_check(_first_args(inbox, 462, "_rpc_duel_ended") == [1 - quitter, "concede"] and _payload_reason(inbox, 462) == "concede_match"
		and _payload_reason(inbox, 461) == "concede_match", "The game ends \"concede\" and both hear the match end \"concede_match\"")
	var conceded: MatchRecord = _last_record(day)
	_check(conceded != null and conceded.match_id == (quit.match_id if quit != null else "") and str(conceded.result["reason"]) == "concede"
		and _match_is(conceded.match_result, 1 - quitter, quit.wins if quit != null else [], "concede_match"),
		"Its record says the game was conceded and the match conceded as a whole")
	_check(conduct.count(_ranked_id(461), int(Time.get_unix_time_from_system())) == 0, "which is not a leave")
	net._on_leave_match(462)
	_check(_journal_has(journal, "refused a leave of the match outside a ranked match from peer 462"), "A finished match cannot be left again")

	var paused: DuelRoom = _ranked_room(net, session, 471, 472)
	var ahead: int = paused.seat_of(471) if paused != null else 0
	net._on_concede(472)
	inbox.clear()
	net._on_leave_match(471)
	_check(paused != null and paused.phase == DuelRoom.Phase.OVER and str(paused.wins) == "[1, 1]" and int(paused.match_result["winner"]) == 1 - ahead,
		"Leave match between games loses the match even ahead, on the game that would have come next")
	_check(_methods(inbox, 472) == ["_rpc_match_over"] and _payload_reason(inbox, 472) == "concede_match",
		"and only the match result goes out, conceded as a match: %s" % str(_methods(inbox, 472)))
	var unplayed: MatchRecord = _last_record(day)
	_check(unplayed != null and unplayed.game == 2 and unplayed.commands.is_empty() and str(unplayed.result["reason"]) == "concede"
		and int(unplayed.match_result.get("winner", -2)) == 1 - ahead and str(unplayed.match_result.get("reason", "")) == "concede_match",
		"Its record is game 2, never dealt, conceded, with the match conceded as a whole")
	await process_frame
	_check(_count(inbox, 472, "_rpc_record") == 2, "and goes out after game 1's")

	# Cut off, Concede match on the reconnect card or the title's rejoin row goes out on a give-up
	# connection of its own, and the server concedes the whole match from it, not only the game.
	var cut: DuelRoom = _ranked_room(net, session, 501, 502)
	var cut_seat: int = cut.seat_of(501) if cut != null else 0
	var cut_token: String = cut.tokens[cut_seat] if cut != null else ""
	var giver: Identity = Identity.generate()
	if cut != null:
		cut.seat_identity[cut_seat] = giver.id()
	net._on_peer_disconnected(501)
	inbox.clear()
	var hello: Dictionary = {"protocol": net.PROTOCOL, "catalog": net.catalog_fingerprint(),
		"give_up": {"code": cut.code if cut != null else "", "token": cut_token}}
	var nonce: PackedByteArray = net.greeting_reply(503, _hello_of(hello, giver)).get("nonce", PackedByteArray())
	var gave: Dictionary = net.greeting_reply(503, {"proof": giver.sign(net.challenge_bytes(nonce))})
	_check(gave == {"gave_up": true} and cut != null and cut.phase == DuelRoom.Phase.OVER and cut.wins[1 - cut_seat] == 1
		and _match_is(cut.match_result, 1 - cut_seat, cut.wins, "concede_match"),
		"A ranked seat that gives up while cut off loses the whole match in game 1, not only the game: %s" % (str(cut.match_result) if cut != null else ""))
	_check(_first_args(inbox, 502, "_rpc_duel_ended") == [1 - cut_seat, "concede"] and _payload_reason(inbox, 502) == "concede_match",
		"The other player hears the game conceded, then the match conceded: %s" % str(inbox.get(502, [])))
	var cut_record: MatchRecord = _last_record(day)
	_check(cut_record != null and cut_record.match_id == (cut.match_id if cut != null else "") and str(cut_record.result["reason"]) == "concede"
		and str(cut_record.match_result.get("reason", "")) == "concede_match" and log.verify(cut_record),
		"and its record says the same, under the server's signature")
	_check(conduct.count(giver.id(), int(Time.get_unix_time_from_system())) == 0, "Conceding the match is not a leave")

	var cut_between: DuelRoom = _ranked_room(net, session, 511, 512)
	var behind: int = cut_between.seat_of(511) if cut_between != null else 0
	net._on_concede(511)
	net._on_peer_disconnected(511)
	inbox.clear()
	var gave_between: Dictionary = net._on_give_up(513, {"code": cut_between.code if cut_between != null else "",
		"token": cut_between.tokens[behind] if cut_between != null else ""}, _ranked_id(511))
	_check(gave_between == {"gave_up": true} and cut_between != null and cut_between.phase == DuelRoom.Phase.OVER
		and _match_is(cut_between.match_result, 1 - behind, [2, 0] if behind == 1 else [0, 2], "concede_match"),
		"Given up while cut off between games, the match ends on the undealt next game: %s" % (str(cut_between.match_result) if cut_between != null else ""))
	var cut_between_record: MatchRecord = _last_record(day)
	_check(_methods(inbox, 512) == ["_rpc_match_over", "_rpc_seat_left"] and _payload_reason(inbox, 512) == "concede_match"
		and cut_between_record != null and str(cut_between_record.match_result.get("reason", "")) == "concede_match",
		"and the other player hears the match conceded, no game result, as its record says: %s" % str(_methods(inbox, 512)))
	await process_frame

	var dodged: DuelRoom = _ranked_room(net, session, 481, 482, false)
	_check(dodged != null and dodged.deal_at_msec > 0 and dodged.phase == DuelRoom.Phase.LOBBY, "Both locked in, the matchup is shown")
	net._on_peer_disconnected(481)
	_check(net.ranked_queue.has(482) and conduct.count(_ranked_id(481), int(Time.get_unix_time_from_system())) == 1
		and _journal_has(journal, "dodged the ranked matchup, a leave"), "Leaving the ranked matchup is a dodge and a leave; the other goes back to the ranked queue")
	net._on_peer_disconnected(482)

	var away: DuelRoom = _ranked_room(net, session, 491, 492)
	var dropped: int = away.seat_of(491) if away != null else 0
	var token: String = away.tokens[dropped] if away != null else ""
	net._on_concede(492)
	net._on_peer_disconnected(491)
	_check(away != null and away.phase == DuelRoom.Phase.BETWEEN and away.away_since[dropped] > 0 and away.seat_identity[dropped] == _ranked_id(491),
		"A seat that drops between games is kept, away")
	net._peer_identity[493] = _ranked_id(491)
	inbox.clear()
	net._on_rejoin(493, away.code if away != null else "", token)
	_check(_first_args(inbox, 493, "_rpc_room_failed") == [net.NEXT_GAME + " Trying again."], "A rejoin between games is asked to try again")
	net.sweep(away.next_deal_msec if away != null else 0)
	var next_host: DuelHost = server.hosts.get(away.code if away != null else "", null)
	_check(away != null and away.phase == DuelRoom.Phase.DUEL and next_host != null and next_host.away[dropped] and not next_host.away[1 - dropped],
		"The next game is dealt with that seat away, its clock running")
	net._peer_identity[494] = _ranked_id(491)
	net._on_rejoin(494, away.code if away != null else "", token)
	_check(away != null and away.seat_peer[dropped] == 494 and _methods(inbox, 494).slice(0, 2) == ["_rpc_series", "_rpc_resume"],
		"and the same token takes the seat back in it: %s" % str(_methods(inbox, 494)))
	var away_code: String = away.code if away != null else ""
	_check(net.send_record(away_code, "{}", 1) and not net.send_record(away_code, "{}", 2) and not net.send_record(away_code, "{}"),
		"While game 2 runs, game 1's record may go out and game 2's may not")
	net._on_leave_match(494)

	inbox.clear()
	net._peer_identity[495] = _ranked_id(495)
	net._on_peer_connected(495)
	net._peer_identity[496] = winner_id
	net._on_peer_connected(496)
	var fresh: Array = _first_args(inbox, 495, "_rpc_rating")
	_check(fresh.size() == 4 and fresh[0] == 0 and fresh[1] == true and is_equal_approx(float(fresh[2]), Rating.MU),
		"After the greeting a new player hears its rating: %s" % str(fresh))
	_check(_first_args(inbox, 496, "_rpc_rating").slice(0, 2) == [138, true], "and a player who won a match hears 138, provisional")

	for id in [_ranked_id(421), _ranked_id(441), winner_id]:
		_check(not _journal_has(journal, id), "No journal line carries a full identity")
	net._outbox = Callable()
	net._journal = Callable()
	net.ratings = null
	net.conduct = null
	_link_server(net, server, false)
	server.free.call_deferred()
	net.leave()
	_remove_tree(RANKED_DIR)


static func _ranked_id(peer: int) -> String:
	return ("ranked test peer %d" % peer).sha256_text()


static func _match_is(result: Dictionary, winner: int, wins: Array, reason: String) -> bool:
	return int(result.get("winner", -2)) == winner and str(result.get("wins", [])) == str(wins) and str(result.get("reason", "")) == reason


## The "reason" of the first match result sent to `peer`, "" for none.
static func _payload_reason(got: Dictionary, peer: int) -> String:
	var args: Array = _first_args(got, peer, "_rpc_match_over")
	if args.is_empty() or not (args[0] is Dictionary):
		return ""
	return str((args[0] as Dictionary).get("reason", ""))


## Two fresh identities join the ranked queue, pair, lock in decks 3 and 5, and with `deal` are
## dealt game 1 at the end of the matchup.
func _ranked_room(net: Node, session: Node, peer_a: int, peer_b: int, deal: bool = true) -> DuelRoom:
	for peer in [peer_a, peer_b]:
		net._peer_identity[peer] = _ranked_id(peer)
		net._on_queue_join(peer, {"identity": _ranked_id(peer), "mode": "ranked"})
	var room: DuelRoom = net._room_of(peer_a)
	if room == null or room != net._room_of(peer_b):
		return null
	net._on_lobby_pick(peer_a, 3, session.decks[3].name, "Ada", true)
	net._on_lobby_pick(peer_b, 5, session.decks[5].name, "Bryn", true)
	if deal:
		net.sweep(room.deal_at_msec)
	return room


## A client in a ranked room takes the series, the between-games result, the match result and its
## rating only from the server and only well-formed, and offers no rematch.
func _ranked_client_tests(net: Node) -> void:
	net.mode = "client"
	net._via_server = true
	net.room_code = "ABCDE"
	net.local_player = 1
	var heard: Array = []
	var on_game: Callable = func(game: int, wins: Array, next_in_s: int) -> void: heard.append(["game", game, wins, next_in_s])
	var on_match: Callable = func(payload: Dictionary) -> void: heard.append(["match", payload])
	var on_rating: Callable = func(shown: int, provisional: bool) -> void: heard.append(["rating", shown, provisional])
	net.game_over.connect(on_game)
	net.match_over.connect(on_match)
	net.rating_known.connect(on_rating)
	_check(not net.ranked_room() and net.can_rematch(), "A plain server room is not ranked")
	net._on_series(77, 3, 1, [0, 0])
	net._on_series(net.HOST_ID, 3, 1, [0, 5])
	_check(not net.ranked_room(), "A series from another peer, or with a malformed score, is dropped")
	net._on_series(net.HOST_ID, 3, 1, [0, 0])
	_check(net.ranked_room() and not net.can_rematch() and net.series_game == 1, "The series makes the room ranked, with no rematch")
	net._on_game_over(net.HOST_ID, 1, [1, 0], 20)
	net._on_game_over(net.HOST_ID, 1, "1-0", 20)
	_check(heard == [["game", 1, [1, 0], 20]] and str(net.series_wins) == "[1, 0]" and net.next_game_at > Time.get_ticks_msec(),
		"A game result between games is heard once, well-formed: %s" % str(heard))
	heard.clear()
	var payload: Dictionary = {"winner": 1, "wins": [1, 2], "reason": "concede", "rated": true, "shown_before": [0, 0],
		"shown_after": [0, 138], "provisional": [true, true], "rating_before": {"mu": 25.0, "sigma": 8.33},
		"rating_after": {"mu": 27.6, "sigma": 8.07}}
	for bad: Variant in [payload.merged({"winner": 3}, true), payload.merged({"reason": "vibes"}, true),
			payload.merged({"shown_after": [0, -1]}, true), payload.merged({"rating_after": {"mu": 27.6}}, true), "match"]:
		net._on_match_over(net.HOST_ID, bad)
	_check(heard.is_empty(), "A malformed match result is dropped")
	net._on_match_over(net.HOST_ID, payload)
	_check(heard.size() == 2 and heard[0][0] == "match" and heard[1] == ["rating", 138, true] and int(net.rating["shown"]) == 138,
		"The match result is heard, and this seat's new rating with it: %s" % str(heard))
	heard.clear()
	net._on_match_over(net.HOST_ID, payload.merged({"reason": "concede_match"}, true))
	_check(heard.size() == 2 and str((heard[0][1] as Dictionary).get("reason", "")) == "concede_match",
		"A match conceded as a whole comes with its own reason: %s" % str(heard))
	heard.clear()
	net._on_rating(net.HOST_ID, 200, false, 30.1, 5.5)
	net._on_rating(77, 900, false, 40.0, 2.0)
	net._on_rating(net.HOST_ID, -1, false, 30.1, 5.5)
	_check(heard == [["rating", 200, false]] and is_equal_approx(float(net.rating["mu"]), 30.1), "The rating after the greeting is taken only from the server")
	net.game_over.disconnect(on_game)
	net.match_over.disconnect(on_match)
	net.rating_known.disconnect(on_rating)
	net.leave()


## What the screens read from Net once a signal has gone: the last game result, duel ending and
## match result, kept through a dropped connection and cleared by the next deal or a leave; the
## leaver cooldown as a count down; the wait since the first join, kept across a re-queue; and Find
## a duel always the casual queue.
func _presentation_tests(net: Node, session: Node) -> void:
	var payload: Dictionary = {"winner": 1, "wins": [0, 1], "reason": "concede_match", "rated": true, "shown_before": [0, 0],
		"shown_after": [0, 138], "provisional": [true, true], "rating_before": {"mu": 25.0, "sigma": 8.33},
		"rating_after": {"mu": 27.6, "sigma": 8.07}}
	_client_in_ranked_room(net)
	net._on_duel_ended(77, 0, "concede")
	net._on_duel_ended(net.HOST_ID, 1, "concede")
	net._on_game_over(net.HOST_ID, 1, [0, 1], 20)
	var heard_at: int = Time.get_ticks_msec()
	_check(net.last_duel_ended == {"winner": 1, "reason": "concede"}, "Net keeps the last duel ending, from the server only: %s" % str(net.last_duel_ended))
	var over: Dictionary = net.last_game_over
	_check(over.get("game", 0) == 1 and str(over.get("wins", [])) == "[0, 1]" and over.get("next_in_s", 0) == 20
		and absi(int(over.get("at_msec", 0)) - heard_at) < 1000, "and the last game result, with the ticks it came at: %s" % str(over))
	net._on_match_over(net.HOST_ID, payload)
	_check(net.last_match == net.clean_match_payload(payload) and str(net.last_match.get("reason", "")) == "concede_match",
		"and the last match result: %s" % str(net.last_match))
	var failed: Array[String] = []
	var on_failed: Callable = func(reason: String) -> void: failed.append(reason)
	net.connection_failed.connect(on_failed)
	net._fail("The duel server closed the connection.")
	_check(net.mode == "" and not net.last_match.is_empty() and not net.last_game_over.is_empty() and not net.last_duel_ended.is_empty(),
		"A dropped connection keeps them for the scene still showing the duel")
	_client_in_ranked_room(net)
	net._on_match_over(net.HOST_ID, payload)
	net.leave()
	_check(net.last_match == net.clean_match_payload(payload) and not net.last_game_over.is_empty() and not net.last_duel_ended.is_empty(),
		"and so does leaving, so a disconnect in the same frame as the result still shows it")
	_client_in_ranked_room(net)
	net._on_duel_ended(net.HOST_ID, 0, "concede")
	net._on_game_over(net.HOST_ID, 1, [1, 0], 20)
	net._on_match_over(net.HOST_ID, payload)
	_check(net._take_deal(0, 2, session.decks[0].name, session.decks[2].name, "Ada", "Bryn", 7)
		and net.last_match.is_empty() and net.last_game_over.is_empty() and net.last_duel_ended.is_empty(), "and so does the next deal")
	net.leave()

	net.cooldown_until_msec = 0
	var line: String = net.QUEUE_COOLDOWN % Conduct.wait_text(299000)
	failed.clear()
	_client_in_queue(net)
	net._on_queue_state(net.HOST_ID, "dropped", line, 299000)
	var left: int = net.cooldown_left_ms()
	_check(failed == [line] and net.mode == "" and left > 298000 and left <= 299000,
		"A queue refusal for a leaver cooldown fails with its line and keeps the time left to count down: %d" % left)
	net.leave()
	_check(net.cooldown_left_ms() > 298000, "Leaving keeps the cooldown")
	_client_in_queue(net)
	net._on_queue_state(net.HOST_ID, "dropped", net.QUEUE_LATE, 0)
	_check(failed.size() == 2 and net.cooldown_left_ms() > 298000, "A drop that carries no cooldown leaves it as it was")
	_client_in_queue(net)
	net._on_queue_state(net.HOST_ID, "dropped", line, "299000")
	_check(failed.size() == 2 and net.mode == "client", "A refusal whose time is not a whole number is dropped")
	net._on_queue_state(net.HOST_ID, "queued", "", 0)
	_check(net.cooldown_until_msec == 0 and net.cooldown_left_ms() == 0 and net.queue_state == "queued", "The server taking a queue join clears it")
	net.connection_failed.disconnect(on_failed)
	net.leave()

	var waited: int = maxi(1, int(Time.get_ticks_msec() / 2.0))
	_client_in_queue(net)
	net._on_queue_state(net.HOST_ID, "queued", "", waited)
	var since: int = Time.get_ticks_msec() - net.queue_since
	_check(net.queue_state == "queued" and since >= waited and since < waited + 1000, "The first queued answer counts from the wait the server gives: %d" % since)
	var first_since: int = net.queue_since
	net._on_queue_state(net.HOST_ID, "queued", net.QUEUE_FULL, 1)
	_check(net.queue_since == first_since and net.queue_reason == net.QUEUE_FULL, "and a later one while waiting leaves the count alone")
	net.room_code = "ABCDE"
	net._room_kind = "queue"
	net.queue_state = "picking"
	net.queue_since = 0
	net._back_in_queue(net.QUEUE_OTHER_LEFT, waited)
	since = Time.get_ticks_msec() - net.queue_since
	_check(net.queue_state == "queued" and net.room_code == "" and net.queue_reason == net.QUEUE_OTHER_LEFT and since >= waited and since < waited + 1000,
		"A re-queue sets the count back to the first join: %d" % since)
	net.leave()

	var address: Variant = ProjectSettings.get_setting("zenith/net/duel_server", "")
	var cert: Variant = ProjectSettings.get_setting("zenith/net/duel_server_cert", "")
	ProjectSettings.set_setting("zenith/net/duel_server", "127.0.0.1:9")
	ProjectSettings.set_setting("zenith/net/duel_server_cert", "")
	_client_in_ranked_room(net)
	net._on_duel_ended(net.HOST_ID, 0, "concede")
	net._on_game_over(net.HOST_ID, 1, [1, 0], 20)
	net._on_match_over(net.HOST_ID, payload)
	net.leave()
	var problem: String = await net.find_duel()
	_check(problem == "" and net.queue_state == "connecting" and net._queue_request and not net._queue_ranked,
		"Find a duel asks for the casual queue, --dev-ranked or not (this run: %s)" % str(DevArgs.user_args().has("--dev-ranked")))
	_check(net.last_match.is_empty() and net.last_game_over.is_empty() and net.last_duel_ended.is_empty(),
		"A new queue join forgets the last results")
	net.leave()
	problem = await net.find_ranked()
	_check(problem == "" and net._queue_request and net._queue_ranked, "and Ranked match for the ranked one")
	net.leave()
	ProjectSettings.set_setting("zenith/net/duel_server", address)
	ProjectSettings.set_setting("zenith/net/duel_server_cert", cert)


## Net as a client of the server seated in a ranked room.
static func _client_in_ranked_room(net: Node) -> void:
	net.leave()
	net.mode = "client"
	net._via_server = true
	net.room_code = "ABCDE"
	net.local_player = 1
	net._on_series(net.HOST_ID, 3, 1, [0, 0])


## Net as a client of the server waiting for its queue's answer.
static func _client_in_queue(net: Node) -> void:
	net.mode = "client"
	net._via_server = true
	net.queue_state = "connecting"
