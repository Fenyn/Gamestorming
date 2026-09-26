extends Node
## The duel server: no table, no seat of its own. Players connect out to it; one opens a room
## and gets a share code, the other joins with the code, both pick and lock in on their own
## select screens, and the server deals and runs that room's duel behind a DuelHost with both
## seats remote. Many rooms at once, one process. Run headless:
##   godot --headless --path zenith -- --server --port=7777
## `Net` owns the rooms and the wire; this script owns the rules per room.

const DEFAULT_PORT: int = 7777

var hosts: Dictionary = {}   # room code -> DuelHost
var port: int = DEFAULT_PORT


func _ready() -> void:
	for arg in DevArgs.user_args():
		if arg.begins_with("--port="):
			port = int(arg.get_slice("=", 1))
	var problem: String = await Net.serve(port)
	if problem != "":
		push_error(problem)
		get_tree().quit(1)
		return
	print("duel server listening on port %d" % port)
	Net.room_started.connect(_on_room_started)
	Net.room_command.connect(_on_room_command)
	Net.room_closed.connect(_on_room_closed)


## Both seats locked: deal from the room's picks. Decks are shared, read-only objects; the
## players' names go to the engine beside them.
func _on_room_started(code: String) -> void:
	var room: DuelRoom = Net.rooms.get(code)
	if room == null:
		return
	for pick in room.lobby:
		if not Net.valid_deck_pick(int(pick.get("deck", -1)), str(pick.get("deck_name", ""))):
			return
	var referee: Referee = Referee.new()
	var decks: Array[DeckList] = [Session.decks[int(room.lobby[0]["deck"])], Session.decks[int(room.lobby[1]["deck"])]]
	var names: Array[String] = [str(room.lobby[0]["name"]), str(room.lobby[1]["name"])]
	referee.setup(decks, Session.library, Session.strike_table, room.seed_value, names)
	var host: DuelHost = DuelHost.new()
	host.setup(referee, [0, 1])
	host.send = Net.send_room_update.bind(code)
	host.reject = Net.reject_room_command.bind(code)
	hosts[code] = host
	host.start()
	print("room %s: %s vs %s, seed %d (%d rooms live)" % [code, names[0], names[1], room.seed_value, hosts.size()])


func _on_room_command(code: String, seat: int, cmd: Dictionary) -> void:
	var host: DuelHost = hosts.get(code, null)
	if host == null:
		return
	host.apply(seat, cmd)
	if host.is_over():
		print("room %s: over, winner seat %d" % [code, host.referee.engine.state.winner])
		# The players keep their tables until they leave; leaving closes the room.
		hosts.erase(code)


func _on_room_closed(code: String) -> void:
	if hosts.erase(code):
		print("room %s: abandoned" % code)
