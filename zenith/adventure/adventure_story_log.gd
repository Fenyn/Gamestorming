class_name AdventureStoryLog
extends RefCounted
## What the lead-ins remember, saved in user://adventure/story_log.json: how often each main has
## fought each character and how the last duel went (across runs), and for the current run who
## was beaten and which lead-in lines were shown.

const PATH: String = "user://adventure/story_log.json"
const SAVE_VERSION: int = 1

static var path_override: String = ""

## "main|opponent" -> {met, won, lost, last}. `last` is "won" or "lost", from the main's side.
var pairs: Dictionary = {}
## The run the per-run lists belong to. A new run id clears them.
var run_id: String = ""
var beaten: Array[String] = []
var shown: Array[String] = []
## The lead-in shown on a node, so a restarted duel shows the same one: {node, lead_in}.
var current: Dictionary = {}


static func path() -> String:
	return path_override if path_override != "" else PATH


static func pair_key(main: String, opponent: String) -> String:
	return "%s|%s" % [main, opponent]


func met(main: String, opponent: String) -> int:
	return int((pairs.get(pair_key(main, opponent), {}) as Dictionary).get("met", 0))


func last(main: String, opponent: String) -> String:
	return str((pairs.get(pair_key(main, opponent), {}) as Dictionary).get("last", ""))


## Starts the per-run lists over when the run changed.
func begin_run(id: String) -> void:
	if id == run_id:
		return
	run_id = id
	beaten.clear()
	shown.clear()
	current = {}


func mark_shown(keys: Array) -> void:
	for k in keys:
		if not shown.has(str(k)):
			shown.append(str(k))


func record_result(main: String, opponent: String, won: bool) -> void:
	if main == "" or opponent == "":
		return
	var key: String = pair_key(main, opponent)
	var row: Dictionary = pairs.get(key, {"met": 0, "won": 0, "lost": 0, "last": ""})
	row["met"] = int(row.get("met", 0)) + 1
	row["won" if won else "lost"] = int(row.get("won" if won else "lost", 0)) + 1
	row["last"] = "won" if won else "lost"
	pairs[key] = row
	if won and not beaten.has(opponent):
		beaten.append(opponent)
	current = {}


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"pairs": pairs.duplicate(true),
		"run_id": run_id,
		"beaten": beaten.duplicate(),
		"shown": shown.duplicate(),
		"current": current.duplicate(true),
	}


static func from_dict(d: Dictionary) -> AdventureStoryLog:
	var out: AdventureStoryLog = AdventureStoryLog.new()
	var saved: Dictionary = d.get("pairs", {})
	for key in saved.keys():
		var row: Dictionary = saved[key]
		out.pairs[str(key)] = {
			"met": int(row.get("met", 0)), "won": int(row.get("won", 0)),
			"lost": int(row.get("lost", 0)), "last": str(row.get("last", "")),
		}
	out.run_id = str(d.get("run_id", ""))
	for who in d.get("beaten", []):
		out.beaten.append(str(who))
	for k in d.get("shown", []):
		out.shown.append(str(k))
	var cur: Variant = d.get("current", {})
	out.current = cur if cur is Dictionary else {}
	return out


## The saved log, or an empty one when there is no file yet. Never null.
static func load_log() -> AdventureStoryLog:
	var file: String = path()
	if not FileAccess.file_exists(file):
		return AdventureStoryLog.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not (parsed is Dictionary):
		push_error("AdventureStoryLog: %s is not a JSON object" % file)
		return AdventureStoryLog.new()
	return AdventureStoryLog.from_dict(parsed)


func save() -> bool:
	var file: String = AdventureStoryLog.path()
	var dir: String = file.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var handle: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	if handle == null:
		push_error("AdventureStoryLog: cannot write %s" % file)
		return false
	handle.store_string(JSON.stringify(to_dict(), "  "))
	handle.close()
	return true
