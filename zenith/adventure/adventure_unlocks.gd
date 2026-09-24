class_name AdventureUnlocks
extends RefCounted
## Which starters the player can begin a run with, and how far each quest has got. Kept for good in
## user://adventure/unlocks.json. The starters open on a new save come from AdventureStory; quests
## open the rest (AdventureQuests).

const PATH: String = "user://adventure/unlocks.json"
const SAVE_VERSION: int = 1

## Tests point this somewhere else so nothing lands on the player's save.
static var path_override: String = ""

## Starter ids opened by quests, on top of the storylines' open list.
var starters: Array[String] = []
## quest id -> steps done.
var quest_steps: Dictionary = {}


static func path() -> String:
	return path_override if path_override != "" else PATH


func is_open(starter_id: String) -> bool:
	return starters.has(starter_id) or AdventureStory.open_starters().has(starter_id)


## The starters a run can begin with, sorted: open ones first in the storylines' order, then the
## unlocked ones by id. Only ids that have a starter file count.
func available_starters() -> Array[String]:
	var files: Array[String] = AdventureDecks.playable_starters()
	var out: Array[String] = []
	for id in AdventureStory.open_starters():
		if files.has(id) and not out.has(id):
			out.append(id)
	var extra: Array[String] = []
	for id in starters:
		if files.has(id) and not out.has(id):
			extra.append(id)
	extra.sort()
	out.append_array(extra)
	return out


## Opens a starter. False when it was already open.
func unlock(starter_id: String) -> bool:
	if is_open(starter_id):
		return false
	starters.append(starter_id)
	return true


func steps_done(quest_id: String) -> int:
	return int(quest_steps.get(quest_id, 0))


func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "starters": starters.duplicate(), "quest_steps": quest_steps.duplicate()}


static func from_dict(d: Dictionary) -> AdventureUnlocks:
	var u: AdventureUnlocks = AdventureUnlocks.new()
	for id in d.get("starters", []):
		if not u.starters.has(str(id)):
			u.starters.append(str(id))
	var steps: Dictionary = d.get("quest_steps", {})
	for id in steps.keys():
		u.quest_steps[str(id)] = maxi(0, int(steps[id]))
	return u


## The saved unlocks, or a fresh save when there is no file yet. Never null.
static func load_unlocks() -> AdventureUnlocks:
	var file: String = path()
	if not FileAccess.file_exists(file):
		return AdventureUnlocks.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not (parsed is Dictionary):
		push_error("AdventureUnlocks: %s is not a JSON object" % file)
		return AdventureUnlocks.new()
	return AdventureUnlocks.from_dict(parsed)


func save() -> bool:
	var file: String = AdventureUnlocks.path()
	var dir: String = file.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var handle: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	if handle == null:
		push_error("AdventureUnlocks: cannot write %s" % file)
		return false
	handle.store_string(JSON.stringify(to_dict(), "  "))
	handle.close()
	return true


static func clear() -> void:
	var file: String = path()
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
