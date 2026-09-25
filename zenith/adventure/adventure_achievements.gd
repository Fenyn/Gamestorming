class_name AdventureAchievements
extends RefCounted
## Achievements from data/adventure/achievements.json. A completed achievement fires an event of
## its own, so one achievement can be a step of another.

const DATA: String = "res://data/adventure/achievements.json"


static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(DATA):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not (parsed is Dictionary):
		return out
	for a in (parsed as Dictionary).get("achievements", []):
		if a is Dictionary:
			out.append(a)
	return out


## Returns the achievements completed, in order; granting their rewards is the caller's job.
static func apply(unlocks: AdventureUnlocks, events: Array[Dictionary]) -> Array[Dictionary]:
	var done_now: Array[Dictionary] = []
	var list: Array[Dictionary] = all()
	var queue: Array[Dictionary] = events.duplicate()
	var i: int = 0
	while i < queue.size():
		var event: Dictionary = queue[i]
		i += 1
		for a in list:
			var id: String = str(a.get("id", ""))
			if unlocks.is_complete(id) or not _advance(unlocks, a, event):
				continue
			if unlocks.steps_done(id).size() >= (a.get("steps", []) as Array).size():
				unlocks.completed.append(id)
				done_now.append(a)
				queue.append({"event": "achievement", "id": id})
	return done_now


## An ordered achievement only takes its next step; an unordered one takes the first unfinished
## step that matches.
static func _advance(unlocks: AdventureUnlocks, a: Dictionary, event: Dictionary) -> bool:
	var id: String = str(a.get("id", ""))
	var steps: Array = a.get("steps", [])
	var done: Array[int] = unlocks.steps_done(id)
	var ordered: bool = bool(a.get("ordered", true))
	for s in range(steps.size()):
		if done.has(s):
			continue
		if matches(steps[s] as Dictionary, event):
			done.append(s)
			unlocks.steps[id] = done
			return true
		if ordered:
			return false
	return false


static func matches(step: Dictionary, event: Dictionary) -> bool:
	if step.has("achievement"):
		return str(event.get("event", "")) == "achievement" and str(event.get("id", "")) == str(step["achievement"])
	if str(step.get("event", "")) != str(event.get("event", "")):
		return false
	for key in ["main", "starter", "node", "opponent"]:
		if step.has(key) and str(step[key]) != str(event.get(key, "")):
			return false
	if step.has("act") and int(step["act"]) != int(event.get("act", 0)):
		return false
	if step.has("act_min") and int(event.get("act", 0)) < int(step["act_min"]):
		return false
	if step.has("aspect_min") and int(event.get("aspect", 0)) < int(step["aspect_min"]):
		return false
	if step.has("blocks_max") and int(event.get("blocks", 0)) > int(step["blocks_max"]):
		return false
	if step.has("allies_all"):
		var allies: Array = event.get("allies", [])
		for who in step["allies_all"]:
			if not allies.has(str(who)):
				return false
	return true


## The journal's rows, in data order: {id, group, title, hint, reward, state, done, total, secret}.
## `state` is "complete", "progress" (a step done), "open" or "unknown" (hidden, no step yet).
## A secret achievement appears only once complete.
static func journal(unlocks: AdventureUnlocks, library: CardLibrary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in all():
		var id: String = str(a.get("id", ""))
		var visibility: String = str(a.get("visibility", "public"))
		var done: int = unlocks.steps_done(id).size()
		var state: String = "open"
		if unlocks.is_complete(id):
			state = "complete"
		elif visibility == "secret":
			continue
		elif visibility == "hidden" and done == 0:
			state = "unknown"
		elif done > 0:
			state = "progress"
		var hint: String = str(a.get("hint", ""))
		if visibility == "hidden" and done > 0 and a.has("hint_revealed"):
			hint = str(a["hint_revealed"])
		out.append({
			"id": id,
			"group": str(a.get("group", a.get("character", ""))),
			"character": str(a.get("character", "")),
			"title": str(a.get("title", id)) if state != "unknown" else "Undiscovered",
			"hint": hint if state != "unknown" else str(a.get("teaser", "")),
			"reward": AdventureProgress.reward_text(a, library) if state != "unknown" else "",
			"state": state,
			"done": done,
			"total": (a.get("steps", []) as Array).size(),
			"secret": visibility == "secret",
		})
	return out


## The ways to open `starter_id` the journal may show: [{text, hint, done, total}]. A secret
## achievement is left out; a hidden one is unnamed until its first step.
static func routes(starter_id: String, unlocks: AdventureUnlocks, progress: AdventureProgress) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in all():
		if str(a.get("starter", "")) != starter_id:
			continue
		var id: String = str(a.get("id", ""))
		var visibility: String = str(a.get("visibility", "public"))
		var done: int = unlocks.steps_done(id).size()
		if visibility == "secret":
			continue
		var named: bool = visibility == "public" or done > 0 or unlocks.is_complete(id)
		var hint: String = str(a.get("hint", "")) if visibility == "public" else str(a.get("hint_revealed", ""))
		out.append({"text": ("Achievement: %s" % str(a.get("title", id))) if named else "A hidden achievement",
			"hint": hint if named else str(a.get("teaser", "")),
			"done": done, "total": (a.get("steps", []) as Array).size()})
	var tracks: Dictionary = AdventureProgress.data().get("tracks", {})
	for character in tracks.keys():
		for level in (tracks[character] as Dictionary).keys():
			if str((tracks[character][level] as Dictionary).get("starter", "")) == starter_id:
				out.append({"text": "%s level %s" % [short_name(str(character)), str(level)], "hint": "",
					"done": mini(int(level), progress.personality_level(str(character))), "total": int(level)})
	return out


## True when every route to `starter_id` is a secret achievement, so the journal must not list it.
static func secret_only(starter_id: String) -> bool:
	var secret: bool = false
	for a in all():
		if str(a.get("starter", "")) == starter_id:
			if str(a.get("visibility", "public")) != "secret":
				return false
			secret = true
	var tracks: Dictionary = AdventureProgress.data().get("tracks", {})
	for character in tracks.keys():
		for level in (tracks[character] as Dictionary).keys():
			if str((tracks[character][level] as Dictionary).get("starter", "")) == starter_id:
				return false
	return secret


## "Sir Edric Rooke" -> "Edric".
static func short_name(character: String) -> String:
	var words: PackedStringArray = character.split(" ")
	if words.size() > 1 and (words[0] == "Sir" or words[0] == "Dame"):
		return words[1]
	return words[0]


