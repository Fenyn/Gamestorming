class_name AdventureRun
extends RefCounted
## One adventure run: the starter it grew from, the deck as it stands, and where the ladder is.
## Pure state. No Nodes and no autoloads, the same rule engine/ follows.

## `stage` is the 0-based index of the stage still to fight.
var starter_id: String = ""
var cards: Array[String] = []      # expanded, one entry per copy, like DeckList.cards
var aspects: int = 2
var stage: int = 0
var run_seed: int = 0
var pending_offer: Array[String] = []
var status: String = "stage"       # stage | reward | won | lost
var picks: Array[Dictionary] = []  # {stage, kind: pick | skip | cut, id}


static func begin(starter_id_value: String, run_seed_value: int) -> AdventureRun:
	var starter: DeckList = DeckList.resolve(starter_id_value)
	if starter == null:
		return null
	var run: AdventureRun = AdventureRun.new()
	run.starter_id = starter_id_value
	run.cards = starter.cards.duplicate()
	run.aspects = starter.aspects
	run.run_seed = run_seed_value
	return run


## The starter reloaded with this run's Life Deck and aspect count in place of the printed ones.
func deck() -> DeckList:
	var d: DeckList = DeckList.resolve(starter_id)
	if d == null:
		return null
	d.cards = cards.duplicate()
	d.aspects = aspects
	return d


## Seed for the duel at stage `n`. Distinct from offer_seed(n) for every n.
func stage_seed(n: int) -> int:
	return _mix(run_seed, n * 2 + 1)


## Seed for the reward draw after stage `n`.
func offer_seed(n: int) -> int:
	return _mix(run_seed, n * 2 + 2)


## Deterministic integer mix. Always positive and never zero, so a seed is never "unseeded".
static func _mix(a: int, b: int) -> int:
	var h: int = a * 0x9E3779B1 + b * 0x85EBCA77 + 0x27D4EB2F
	h = (h ^ (h >> 33)) * 0xFF51AFD7
	h = (h ^ (h >> 29)) * 0xC2B2AE35
	h = h ^ (h >> 32)
	return (h & 0x3FFFFFFF) + 1


func to_dict() -> Dictionary:
	return {
		"starter_id": starter_id,
		"cards": cards.duplicate(),
		"aspects": aspects,
		"stage": stage,
		"run_seed": run_seed,
		"pending_offer": pending_offer.duplicate(),
		"status": status,
		"picks": picks.duplicate(true),
	}


## Tolerant of JSON, which hands every number back as a float.
static func from_dict(d: Dictionary) -> AdventureRun:
	var run: AdventureRun = AdventureRun.new()
	run.starter_id = str(d.get("starter_id", ""))
	for id in d.get("cards", []):
		run.cards.append(str(id))
	run.aspects = int(d.get("aspects", 2))
	run.stage = int(d.get("stage", 0))
	run.run_seed = int(d.get("run_seed", 0))
	for id in d.get("pending_offer", []):
		run.pending_offer.append(str(id))
	run.status = str(d.get("status", "stage"))
	for entry in d.get("picks", []):
		if entry is Dictionary:
			var row: Dictionary = entry
			run.picks.append({
				"stage": int(row.get("stage", 0)),
				"kind": str(row.get("kind", "")),
				"id": str(row.get("id", "")),
			})
	return run
