class_name AdventureRun
extends RefCounted
## One adventure run: the starter it grew from, the deck as it stands, and where the ladder is.
## Pure state. No Nodes and no autoloads, the same rule engine/ follows.

## `stage` is the 0-based index of the stage still to fight.
var starter_id: String = ""
var cards: Array[String] = []      # expanded, one entry per copy, like DeckList.cards
## The Duelist's Aspect stack as it stands, one card id per tier. Each Aspect is its own card, so
## a run grows by gaining the next tier card, not by raising a number.
var duelist_ids: Array[String] = []
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
	run.duelist_ids = starter.duelist_ids.duplicate()
	run.run_seed = run_seed_value
	return run


## The starter reloaded with this run's Life Deck and Aspect stack in place of the printed ones.
func deck() -> DeckList:
	var d: DeckList = DeckList.resolve(starter_id)
	if d == null:
		return null
	d.cards = cards.duplicate()
	d.set_duelist(duelist_ids)
	return d


## How many Aspects the run's Duelist stands at.
func aspects() -> int:
	return duelist_ids.size()


## Every personality card that could be the run's next Aspect: the same character, one tier up,
## and legal for the deck's alignment. The later client pass offers this as a choice; `next_tier`
## picks one for now.
func next_tier_options(library: CardLibrary) -> Array[String]:
	var out: Array[String] = []
	if duelist_ids.is_empty():
		return out
	var top: CardDef = library.defs.get(duelist_ids[duelist_ids.size() - 1])
	if top == null or duelist_ids.size() >= DeckValidator.MAX_ASPECTS:
		return out
	var d: DeckList = deck()
	var alignment: String = d.alignment if d != null else ""
	for id in library.all_ids():
		var def: CardDef = library.defs[id]
		if not def.is_personality() or def.character != top.character:
			continue
		if def.aspect != top.aspect + 1:
			continue
		if def.alignment_only != "" and alignment != "" and def.alignment_only != alignment:
			continue
		out.append(id)
	out.sort()
	return out


## The Aspect a run gains, chosen deterministically: the card of the same printed line the starter
## was written with, else the first by id. The line is whichever `variant` the run's own cards
## carry, which is what tells Bram Ashmark's two roads apart.
func next_tier(library: CardLibrary) -> String:
	var options: Array[String] = next_tier_options(library)
	if options.is_empty():
		return ""
	var line: String = ""
	for id in duelist_ids:
		var def: CardDef = library.defs.get(id)
		if def != null and def.variant != "":
			line = def.variant
	if line != "":
		for id in options:
			if (library.defs[id] as CardDef).variant == line:
				return id
	return options[0]


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


## Bumped to 2 when each Aspect became its own card (2026-09-21). Version 1 stored `aspects: N`
## and read the Duelist off the starter deck; `from_dict` migrates one.
const SAVE_VERSION: int = 2
const MIGRATION_MAP: String = "res://data/migrations/personality_split.json"


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"starter_id": starter_id,
		"cards": cards.duplicate(),
		"duelist": duelist_ids.duplicate(),
		"stage": stage,
		"run_seed": run_seed,
		"pending_offer": pending_offer.duplicate(),
		"status": status,
		"picks": picks.duplicate(true),
	}


## A version 1 save held `aspects: N` and named no cards at all: the Duelist came from the starter
## deck, which then held one card for the whole ladder. The migration map records which stack each
## shipped deck named and which tier cards it split into, so N becomes the first N of that line.
static func _migrate_duelist(starter: String, aspects_count: int) -> Array[String]:
	var out: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MIGRATION_MAP))
	if not (parsed is Dictionary):
		push_error("AdventureRun: cannot read %s to migrate a version 1 save" % MIGRATION_MAP)
		return out
	var blob: Dictionary = parsed
	var old_id: String = str((blob.get("deck_duelists", {}) as Dictionary).get(starter, ""))
	var tiers: Array = (blob.get("personalities", {}) as Dictionary).get(old_id, [])
	for i in range(mini(aspects_count, tiers.size())):
		out.append(str(tiers[i]))
	if out.is_empty():
		push_error("AdventureRun: no Duelist cards for starter '%s' in the migration map" % starter)
	return out


## Tolerant of JSON, which hands every number back as a float.
static func from_dict(d: Dictionary) -> AdventureRun:
	var run: AdventureRun = AdventureRun.new()
	run.starter_id = str(d.get("starter_id", ""))
	for id in d.get("cards", []):
		run.cards.append(str(id))
	if int(d.get("version", 1)) < SAVE_VERSION or not d.has("duelist"):
		run.duelist_ids = AdventureRun._migrate_duelist(run.starter_id, int(d.get("aspects", 2)))
	else:
		for id in d.get("duelist", []):
			run.duelist_ids.append(str(id))
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
