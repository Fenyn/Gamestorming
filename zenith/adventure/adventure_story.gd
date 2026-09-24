class_name AdventureStory
extends RefCounted
## The story runs in data/adventure/storylines.json: which starters are open on a new save, each
## storyline's act bosses and what beating them gives, and who an Encounter node can bring in.
## A starter with no storyline plays with random act bosses and no guests.

const DATA: String = "res://data/adventure/storylines.json"


static func read_data() -> Dictionary:
	if not FileAccess.file_exists(DATA):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return parsed if parsed is Dictionary else {}


static func open_starters() -> Array[String]:
	var out: Array[String] = []
	for id in read_data().get("open", []):
		out.append(str(id))
	return out


static func storyline(starter_id: String) -> Dictionary:
	return (read_data().get("starters", {}) as Dictionary).get(starter_id, {})


## The act's set boss, {} when the act's boss is drawn at random: {family, on_win}.
static func boss_for(starter_id: String, act: int) -> Dictionary:
	return (storyline(starter_id).get("bosses", {}) as Dictionary).get(str(act), {})


static func guests_for(starter_id: String) -> Array[String]:
	var out: Array[String] = []
	for id in storyline(starter_id).get("guests", []):
		out.append(str(id))
	return out


## Applies what beating a set act boss gives, before the reward screen draws its offer. Returns the
## personality card that joined the run deck, "" when nothing did. A join the deck cannot legally
## hold is skipped.
static func apply_boss_win(run: AdventureRun, map: AdventureMap, library: CardLibrary) -> String:
	var here: Dictionary = map.node(run.node_id)
	if str(here.get("type", "")) != "boss":
		return ""
	var boss: Dictionary = boss_for(run.starter_id, int(here.get("act", 0)))
	var joins: String = str((boss.get("on_win", {}) as Dictionary).get("joins", ""))
	if joins == "" or not library.has(joins) or run.cards.has(joins):
		return ""
	var trial: DeckList = run.deck()
	if trial == null:
		return ""
	trial.cards.append(joins)
	var problems: Array[String] = DeckValidator.validate(trial, library)
	if not problems.is_empty():
		push_warning("AdventureStory: %s cannot join %s: %s" % [joins, run.starter_id, "; ".join(problems)])
		return ""
	run.cards.append(joins)
	run.picks.append({"stage": run.stage, "kind": "joined", "id": joins})
	return joins
