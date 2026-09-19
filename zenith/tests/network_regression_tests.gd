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
		_check(not room.started and room.seed_value == 0, "Server must reject invalid locked catalogs before dealing or announcing start")
		server._on_room_started(room.code)
		_check(server.hosts.is_empty(), "Server scene must reject an invalid room before indexing Session.decks")
	net.lobby[1]["deck"] = session.decks.size()
	_check(not net.both_locked(), "LAN start readiness must revalidate even a previously locked lobby")
	server.free()
	net.rooms.erase(room.code)
	net.mode = ""
	net.peer_id = 0
	net.reset_lobby()
	print("Network regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
