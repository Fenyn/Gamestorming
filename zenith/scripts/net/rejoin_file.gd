class_name RejoinFile
extends RefCounted
## The seat a client holds in a running duel on the duel server, kept on disk so a dropped
## connection or a closed game can take it back: `user://online/rejoin.json`, written at the deal,
## renewed while the server's messages arrive, deleted at the result or a concession. Fields: `server` (the
## address the duel runs on), `code`, `seat`, `token` (the seat's rejoin secret), `names` and
## `decks` (deck ids) per seat, `kind` (`DuelRoom.kind`, "code" when missing), `ranked` (the seat
## plays a ranked match, false when missing) and `expires` (Unix seconds). `--dev-scratch=<dir>` moves it to
## `<dir>/online/rejoin.json`, so two clients on one machine keep one each.

const FILE: String = "user://online/rejoin.json"
## How long past `Net.REJOIN_GRACE_MS` the file stays good: the renewal comes at most every 30 s
## (`Net.REJOIN_RENEW_MS`), ENet takes up to 10 s to notice a silent connection, and the server can
## go 20 s without a message (a ranked match between games).
const MARGIN_SECONDS: int = 60
## How long the file stays good after it was last written or renewed: the server's 90 s grace for a
## dropped seat plus MARGIN_SECONDS. By then the server has given the seat up, unless the other seat
## dropped too and the room still waits, so the title no longer offers it.
const KEEP_SECONDS: int = 90 + MARGIN_SECONDS
const TOKEN_HEX: int = 64
## Tests point this at a folder of their own.
static var path_override: String = ""

static var _hex: RegEx = RegEx.create_from_string("^[0-9a-f]{64}$")


static func path() -> String:
	if path_override != "":
		return path_override
	for arg in DevArgs.user_args():
		if arg.begins_with("--dev-scratch="):
			return arg.substr("--dev-scratch=".length()).path_join("online/rejoin.json")
	return FILE


## "" when stored, otherwise why not.
static func write(ticket: Dictionary) -> String:
	var dir: String = path().get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var made: Error = DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return error_string(made)
	var file: FileAccess = FileAccess.open(path(), FileAccess.WRITE)
	if file == null:
		return error_string(FileAccess.get_open_error())
	var stored: bool = file.store_string(JSON.stringify(ticket))
	file.close()
	return "" if stored else "the write did not complete"


## The stored ticket with every field checked, or {} when there is none or it is malformed.
static func read() -> Dictionary:
	if not FileAccess.file_exists(path()):
		return {}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path())) != OK or not (json.data is Dictionary):
		return {}
	var d: Dictionary = json.data
	var server: Variant = d.get("server")
	var code: Variant = d.get("code")
	var token: Variant = d.get("token")
	var names: Variant = d.get("names")
	var decks: Variant = d.get("decks")
	var seat: Variant = d.get("seat")
	var expires: Variant = d.get("expires")
	if not (server is String and code is String and token is String and names is Array and decks is Array):
		return {}
	if not ((seat is int or seat is float) and (expires is int or expires is float)):
		return {}
	if not DuelRoom.valid_code(code) or _hex.search(token) == null or int(seat) < 0 or int(seat) > 1:
		return {}
	if (names as Array).size() != 2 or (decks as Array).size() != 2:
		return {}
	return {"server": server, "code": code, "seat": int(seat), "token": token,
		"names": [str(names[0]), str(names[1])], "decks": [str(decks[0]), str(decks[1])],
		"kind": "queue" if str(d.get("kind", "")) == "queue" else "code", "ranked": ranked(d),
		"expires": int(expires)}


## Whether the seat `ticket` names plays a ranked match; false for a file written before the flag.
static func ranked(ticket: Dictionary) -> bool:
	var flag: Variant = ticket.get("ranked", false)
	return flag is bool and bool(flag)


static func live(ticket: Dictionary, now_unix: int) -> bool:
	return not ticket.is_empty() and int(ticket.get("expires", 0)) > now_unix


static func clear() -> void:
	if FileAccess.file_exists(path()):
		DirAccess.remove_absolute(path())


## Moves the expiry on, so a duel longer than KEEP_SECONDS keeps its file good.
static func renew(now_unix: int) -> void:
	var ticket: Dictionary = read()
	if ticket.is_empty():
		return
	ticket["expires"] = now_unix + KEEP_SECONDS
	write(ticket)
