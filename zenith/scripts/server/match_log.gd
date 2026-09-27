class_name MatchLog
extends RefCounted
## The duel server's match records. Everything lives under one data directory (`--data-dir`,
## default user://): `secret.key`, 32 random bytes made on first start, and `matches/`, one
## `YYYY-MM-DD.jsonl` per UTC day with one line per finished game. Every record is signed with
## HMAC-SHA256 under that key before it is written or sent, so a record a player hands back later
## can be checked against what this server wrote. The key never leaves this object: it is not
## logged, sent, or put in a record. File modes are the install script's job (a 0700 directory
## and a 0077 umask for the service), since the engine sets none.

const DEFAULT_DIR: String = "user://"
const DEFAULT_KEEP_DAYS: int = 90
const KEY_FILE: String = "secret.key"
const KEY_BYTES: int = 32
const MATCHES_DIR: String = "matches"
const DAY_SECONDS: int = 86400

static var _day_file: RegEx = RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}\\.jsonl$")

var data_dir: String = DEFAULT_DIR
var keep_days: int = DEFAULT_KEEP_DAYS
var _key: PackedByteArray = PackedByteArray()
var _crypto: Crypto = Crypto.new()


## Loads the signing key from the data directory, or makes and stores one on first start. "" when
## ready, otherwise why not; the server does not start without it.
func open(dir: String, days: int = DEFAULT_KEEP_DAYS) -> String:
	data_dir = dir
	keep_days = maxi(1, days)
	_key = PackedByteArray()
	var matches: String = matches_dir()
	if not DirAccess.dir_exists_absolute(matches):
		var made: Error = DirAccess.make_dir_recursive_absolute(matches)
		if made != OK:
			return "cannot create %s: %s" % [matches, error_string(made)]
	var key_path: String = data_dir.path_join(KEY_FILE)
	if FileAccess.file_exists(key_path):
		var stored: PackedByteArray = FileAccess.get_file_as_bytes(key_path)
		if stored.size() != KEY_BYTES:
			return "%s is not a %d-byte key" % [key_path, KEY_BYTES]
		_key = stored
		return ""
	var fresh: PackedByteArray = _crypto.generate_random_bytes(KEY_BYTES)
	var file: FileAccess = FileAccess.open(key_path, FileAccess.WRITE)
	if file == null:
		return "cannot write %s: %s" % [key_path, error_string(FileAccess.get_open_error())]
	var written: bool = file.store_buffer(fresh)
	file.close()
	if not written:
		return "cannot write %s" % key_path
	_key = fresh
	return ""


func matches_dir() -> String:
	return data_dir.path_join(MATCHES_DIR)


## Signs `record`, then appends it to today's file: open, append, flush, close each time, so a
## crash loses at most the line being written. The journal gets "record <id> written" or
## "record <id> failed: <reason>" and nothing else about it. A failed write never holds up the
## result; the signed record still goes to the players.
func write(record: MatchRecord) -> bool:
	if _key.is_empty():
		print("record %s failed: no signing key" % record.id)
		return false
	sign_record(record)
	var problem: String = _append(record.line(), int(Time.get_unix_time_from_system()))
	if problem != "":
		print("record %s failed: %s" % [record.id, problem])
		return false
	print("record %s written" % record.id)
	return true


func sign_record(record: MatchRecord) -> void:
	record.sig = _digest(record.to_dict()).hex_encode()


## Whether `record` carries this server's signature over exactly its current content.
func verify(record: MatchRecord) -> bool:
	if _key.is_empty() or record.sig.length() != KEY_BYTES * 2:
		return false
	return _crypto.constant_time_compare(_digest(record.to_dict()), record.sig.hex_decode())


func _digest(d: Dictionary) -> PackedByteArray:
	return _crypto.hmac_digest(HashingContext.HASH_SHA256, _key, MatchRecord.canonical(d).to_utf8_buffer())


## The day file a record written at `unix` belongs in.
func day_path(unix: int) -> String:
	return matches_dir().path_join(Time.get_date_string_from_unix_time(unix) + ".jsonl")


func _append(text: String, unix: int) -> String:
	var dir: String = matches_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var made: Error = DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return error_string(made)
	var path: String = day_path(unix)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) \
		else FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return error_string(FileAccess.get_open_error())
	file.seek_end()
	var stored: bool = file.store_string(text + "\n")
	file.flush()
	file.close()
	return "" if stored else "the write did not complete"


## Deletes the day files older than `keep_days` days before `unix`. Returns how many went.
func prune(unix: int) -> int:
	var cutoff: String = Time.get_date_string_from_unix_time(unix - keep_days * DAY_SECONDS)
	var dir: DirAccess = DirAccess.open(matches_dir())
	if dir == null:
		return 0
	var removed: int = 0
	for file_name in dir.get_files():
		if _day_file.search(file_name) != null and file_name.get_basename() < cutoff and dir.remove(file_name) == OK:
			removed += 1
	return removed
