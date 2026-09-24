class_name AdventureAchievements
extends RefCounted
## Achievements from data/adventure/achievements.json: steps tracked in the background from duel
## results, listed in the journal. A completed achievement fires an event of its own, so one
## achievement can be a step of another.

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


## Advances every achievement by `events`, in order. Completing one records it in `unlocks` and
## queues its own event. Returns the achievements completed, in the order they completed; their
## rewards are the caller's to grant (AdventureProgress.grant).
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
			if unlocks.is_complete(id):
				continue
			if not _advance(unlocks, a, event):
				continue
			if unlocks.steps_done(id).size() >= (a.get("steps", []) as Array).size():
				unlocks.completed.append(id)
				done_now.append(a)
				queue.append({"event": "achievement", "id": id})
	return done_now


## Marks the step `event` finishes, if any. An ordered achievement only takes its next step; an
## unordered one takes the first unfinished step that matches. True when a step was marked.
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


## The journal's rows, in data order: {id, character, title, hint, state, done, total}. `state` is
## "complete", "open" (public, or hidden with a step done) or "unknown" (hidden, no step yet).
## Secret achievements appear only once complete.
static func journal(unlocks: AdventureUnlocks) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in all():
		var id: String = str(a.get("id", ""))
		var visibility: String = str(a.get("visibility", "public"))
		var done: int = unlocks.steps_done(id).size()
		var complete: bool = unlocks.is_complete(id)
		var state: String = "complete" if complete else "open"
		if not complete:
			if visibility == "secret":
				continue
			if visibility == "hidden" and done == 0:
				state = "unknown"
		out.append({
			"id": id,
			"character": str(a.get("character", "")),
			"title": str(a.get("title", id)) if state != "unknown" else "???",
			"hint": str(a.get("hint", "")) if state != "unknown" else "",
			"state": state,
			"done": done,
			"total": (a.get("steps", []) as Array).size(),
		})
	return out
