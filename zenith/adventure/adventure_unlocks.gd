class_name AdventureUnlocks
extends RefCounted
## What the player has opened for good, apart from cards: the starters a run can begin with, each
## achievement's finished steps, and the deck abilities each character has earned. Kept in
## user://adventure/unlocks.json. The starters open on a new save come from AdventureStory.

const PATH: String = "user://adventure/unlocks.json"
const SAVE_VERSION: int = 2

const ABILITY_RELIC: String = "start_relic"
const ABILITY_RESERVE: String = "start_reserve"

## Tests point this somewhere else so nothing lands on the player's save.
static var path_override: String = ""

## Starter ids opened on top of the storylines' open list.
var starters: Array[String] = []
## achievement id -> the indices of its finished steps.
var steps: Dictionary = {}
## Achievement ids completed, in the order they completed.
var completed: Array[String] = []
## character -> abilities earned, for every starter of that character.
var abilities: Dictionary = {}


static func path() -> String:
	return path_override if path_override != "" else PATH


func is_open(starter_id: String) -> bool:
	return starters.has(starter_id) or AdventureStory.open_starters().has(starter_id)


## The starters a run can begin with: open ones first in the storylines' order, then the unlocked
## ones by id. Only ids that have a starter file count.
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


func steps_done(achievement_id: String) -> Array[int]:
	var out: Array[int] = []
	for i in steps.get(achievement_id, []):
		out.append(int(i))
	return out


func is_complete(achievement_id: String) -> bool:
	return completed.has(achievement_id)


func has_ability(character: String, ability: String) -> bool:
	return (abilities.get(character, []) as Array).has(ability)


## Grants an ability. False when the character already had it.
func grant_ability(character: String, ability: String) -> bool:
	var held: Array = abilities.get(character, [])
	if held.has(ability):
		return false
	held.append(ability)
	abilities[character] = held
	return true


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"starters": starters.duplicate(),
		"steps": steps.duplicate(true),
		"completed": completed.duplicate(),
		"abilities": abilities.duplicate(true),
	}


static func from_dict(d: Dictionary) -> AdventureUnlocks:
	var u: AdventureUnlocks = AdventureUnlocks.new()
	for id in d.get("starters", []):
		if not u.starters.has(str(id)):
			u.starters.append(str(id))
	var saved_steps: Dictionary = d.get("steps", {})
	for id in saved_steps.keys():
		var done: Array = []
		for i in saved_steps[id]:
			done.append(int(i))
		u.steps[str(id)] = done
	for id in d.get("completed", []):
		u.completed.append(str(id))
	var saved_abilities: Dictionary = d.get("abilities", {})
	for character in saved_abilities.keys():
		var held: Array = []
		for a in saved_abilities[character]:
			held.append(str(a))
		u.abilities[str(character)] = held
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
