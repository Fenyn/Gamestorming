class_name Conduct
extends RefCounted
## The leaver ladder on the duel server, by identity id: `conduct.json` in its data directory holds
## each identity's leaves as Unix seconds and nothing else. A leave is a duel lost "left" in a queue
## room (away past the grace, or the clock ran out while away) or leaving a ranked matchup after the
## reveal. The first leave is a warning; each one after it keeps the identity out of both queues for
## longer, counted from that leave. A day without a leave clears the count.

const FILE: String = "conduct.json"
## Seconds out of the queue for the first, second, ... leave in a row; the last step repeats.
const LADDER_S: Array[int] = [0, 120, 300, 900, 1800, 3600]
const CLEAR_AFTER_S: int = 86400
const ID_MAX: int = 128
const LEAVES_MAX: int = 64

var path: String = ""
var leaves: Dictionary = {}   # identity id -> Array[int], Unix seconds, oldest first


## Loads the file from `dir`, or starts empty. "" when ready, otherwise why not.
func open(dir: String) -> String:
	path = dir.path_join(FILE)
	leaves.clear()
	if not FileAccess.file_exists(path):
		return ""
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return "%s is not a conduct file" % path
	for key: Variant in (json.data as Dictionary).keys():
		var raw: Variant = (json.data as Dictionary)[key]
		if not (key is String) or str(key) == "" or str(key).length() > ID_MAX or not (raw is Array):
			return "%s has a malformed entry" % path
		var times: Array[int] = []
		for t: Variant in (raw as Array):
			if not (t is float or t is int) or float(t) < 0.0:
				return "%s has a malformed entry" % path
			times.append(int(t))
		leaves[str(key)] = times
	return ""


## Counts a leave at `now` and saves. Returns the time out of the queue it earned, in ms; 0 is the
## warning.
func leave(id: String, now: int) -> int:
	var run: Array[int] = _run(id, now)
	run.append(now)
	if run.size() > LEAVES_MAX:
		run = run.slice(run.size() - LEAVES_MAX)
	leaves[id] = run
	var problem: String = save(now)
	if problem != "":
		print("conduct: %s not written: %s" % [FILE, problem])
	return _step_s(run.size()) * 1000


## How long `id` still has to wait before it may queue, in ms, 0 when it may.
func cooldown_left_ms(id: String, now: int) -> int:
	var run: Array[int] = _run(id, now)
	if run.is_empty():
		return 0
	return maxi(0, run[run.size() - 1] + _step_s(run.size()) - now) * 1000


## Leaves in `id`'s current run, 0 once a day has passed without one.
func count(id: String, now: int) -> int:
	return _run(id, now).size()


## What one more leave now would cost, in ms.
func next_cost_ms(id: String, now: int) -> int:
	return _step_s(count(id, now) + 1) * 1000


## "4:59": a wait as the player reads it, rounded up to the second.
static func wait_text(ms: int) -> String:
	var s: int = ceili(maxi(0, ms) / 1000.0)
	return "%d:%02d" % [floori(s / 60.0), s % 60]


## "" when written, otherwise why not. Runs a day old are left out.
func save(now: int) -> String:
	if path == "":
		return ""
	var kept: Dictionary = {}
	for id: String in leaves.keys():
		if not _run(id, now).is_empty():
			kept[id] = leaves[id]
	leaves = kept
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return error_string(FileAccess.get_open_error())
	var stored: bool = file.store_string(JSON.stringify(leaves, "", true) + "\n")
	file.close()
	if not stored:
		return "the write did not complete"
	var moved: Error = DirAccess.rename_absolute(temp, path)
	return "" if moved == OK else error_string(moved)


func _run(id: String, now: int) -> Array[int]:
	var out: Array[int] = []
	var stored: Array = leaves.get(id, [])
	if stored.is_empty() or now - int(stored[stored.size() - 1]) >= CLEAR_AFTER_S:
		return out
	for t: Variant in stored:
		out.append(int(t))
	return out


static func _step_s(leaves_in_run: int) -> int:
	return LADDER_S[clampi(leaves_in_run, 1, LADDER_S.size()) - 1]
