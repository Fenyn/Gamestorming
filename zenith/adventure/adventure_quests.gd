class_name AdventureQuests
extends RefCounted
## Quests from data/adventure/quests.json. A duel result becomes events; each event advances any
## quest whose next step it matches, and a quest's last step opens its starter.

const DATA: String = "res://data/adventure/quests.json"


static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(DATA):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not (parsed is Dictionary):
		return out
	for q in (parsed as Dictionary).get("quests", []):
		if q is Dictionary:
			out.append(q)
	return out


## The events a won duel on the node the run stands on fires. A lost duel fires none.
static func events_for_win(run: AdventureRun, map: AdventureMap) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var here: Dictionary = map.node(run.node_id)
	if str(here.get("type", "")) == "boss":
		out.append({"event": "boss_won", "starter": run.starter_id, "act": int(here.get("act", 0))})
	if run.node_id == map.final_id():
		out.append({"event": "run_won", "starter": run.starter_id})
	return out


## Advances quests by `events` in order. Returns the starters this opened.
static func apply(unlocks: AdventureUnlocks, events: Array[Dictionary]) -> Array[String]:
	var opened: Array[String] = []
	var quests: Array[Dictionary] = all()
	for event in events:
		for q in quests:
			var id: String = str(q.get("id", ""))
			var steps: Array = q.get("steps", [])
			var done: int = unlocks.steps_done(id)
			if done >= steps.size() or not _matches(steps[done] as Dictionary, event):
				continue
			done += 1
			unlocks.quest_steps[id] = done
			if done == steps.size():
				var starter: String = str(q.get("unlock", ""))
				if starter != "" and unlocks.unlock(starter):
					opened.append(starter)
	return opened


static func _matches(step: Dictionary, event: Dictionary) -> bool:
	if str(step.get("event", "")) != str(event.get("event", "")):
		return false
	if step.has("starter") and str(step["starter"]) != str(event.get("starter", "")):
		return false
	if step.has("act") and int(step["act"]) != int(event.get("act", 0)):
		return false
	return true
