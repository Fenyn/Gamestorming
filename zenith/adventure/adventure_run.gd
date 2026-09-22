class_name AdventureRun
extends RefCounted
## One adventure run: the starter it grew from, the deck as it stands, and where the ladder is.
## Pure state. No Nodes and no autoloads, the same rule engine/ follows.

## `stage` is the 0-based index of the stage still to fight.
var starter_id: String = ""
## Names this run in the wallet's ledger, so a payout can be traced back to the run that paid it.
var run_id: String = ""
var cards: Array[String] = []      # expanded, one entry per copy, like DeckList.cards
## The deck the run began from, as it was at `begin`: after a loadout swap that is the swapped
## list, not the printed starter. `added_cards()` is everything in `cards` beyond it, which is
## what the run-end settlement charges for.
var starter_cards: Array[String] = []
var starter_duelist: Array[String] = []
## The Duelist's Aspect stack as it stands, one card id per tier. Each Aspect is its own card, so
## a run grows by gaining the next tier card, not by raising a number.
var duelist_ids: Array[String] = []
var stage: int = 0
var run_seed: int = 0
## The bundle ids on offer while `status` is "reward".
var pending_offer: Array[String] = []
## The Aspect card ids on offer while `status` is "aspect".
var pending_aspects: Array[String] = []
var status: String = "stage"       # stage | aspect | reward | settle | won | lost
## Which way the run ended, kept while `status` is "settle" so the run-end screen knows whether it
## is showing a win or a loss. "" until the run ends.
var outcome: String = ""
## True once the run-end settlement is closed. A settled run cannot be reopened or bought from.
var settled: bool = false
## id -> copies already bought at the run-end settlement, so a card cannot be kept twice.
var kept: Dictionary = {}
## {stage, kind, id} for every kind, plus "cards" on a bundle pick.
## kind: bundle | aspect | aspect_skipped | skip | cut
var picks: Array[Dictionary] = []


static func begin(starter_id_value: String, run_seed_value: int) -> AdventureRun:
	var starter: DeckList = DeckList.resolve(starter_id_value)
	if starter == null:
		return null
	return AdventureRun.begin_with(starter_id_value, run_seed_value,
		starter.cards, starter.duelist_ids)


## The same, from a deck the player assembled instead of the printed starter: a loadout swap
## begins here so `starter_cards` records what the run actually started with.
static func begin_with(starter_id_value: String, run_seed_value: int,
		cards_value: Array[String], duelist_value: Array[String]) -> AdventureRun:
	var run: AdventureRun = AdventureRun.new()
	run.starter_id = starter_id_value
	run.cards = cards_value.duplicate()
	run.duelist_ids = duelist_value.duplicate()
	run.starter_cards = cards_value.duplicate()
	run.starter_duelist = duelist_value.duplicate()
	run.run_seed = run_seed_value
	run.run_id = AdventureRun.id_for(starter_id_value, run_seed_value)
	return run


## A run's name in the ledger. Derived, so a save written before run ids existed gets the same one
## back on load.
static func id_for(starter: String, run_seed_value: int) -> String:
	return "%s-%d" % [starter, run_seed_value]


## The cards the run added to the Life Deck, one entry per copy: everything in `cards` beyond the
## list it started from. This is what the run-end settlement charges for.
func added_cards() -> Array[String]:
	var left: Dictionary = {}
	for id in starter_cards:
		left[id] = int(left.get(id, 0)) + 1
	var out: Array[String] = []
	for id in cards:
		if int(left.get(id, 0)) > 0:
			left[id] = int(left[id]) - 1
			continue
		out.append(id)
	out.sort()
	return out


## The Aspect cards the run climbed to above the stack it started with.
func added_duelist_cards() -> Array[String]:
	var out: Array[String] = []
	for id in duelist_ids:
		if not starter_duelist.has(id):
			out.append(id)
	return out


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


## Bundle ids already taken this run. A bundle is offered once.
func taken_bundles() -> Array[String]:
	var out: Array[String] = []
	for entry in picks:
		if str(entry.get("kind", "")) == "bundle":
			out.append(str(entry.get("id", "")))
	return out


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
## and read the Duelist off the starter deck; `from_dict` migrates one. Bumped to 3 when the
## reward became a theme bundle: a version 2 `pending_offer` holds card ids, not bundle ids.
## Bumped to 4 for Motes: a version 3 save carries no `run_id` and no `starter_cards`, so an
## in-flight run would have nothing to settle. Both are rebuilt on load.
const SAVE_VERSION: int = 4
const MIGRATION_MAP: String = "res://data/migrations/personality_split.json"

## Set by `from_dict` when an old save's offer was dropped and has to be drawn again. Not saved:
## AdventureSave rebuilds the offer on load and clears it.
var needs_offer_rebuild: bool = false


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"starter_id": starter_id,
		"run_id": run_id,
		"cards": cards.duplicate(),
		"duelist": duelist_ids.duplicate(),
		"starter_cards": starter_cards.duplicate(),
		"starter_duelist": starter_duelist.duplicate(),
		"stage": stage,
		"run_seed": run_seed,
		"pending_offer": pending_offer.duplicate(),
		"pending_aspects": pending_aspects.duplicate(),
		"status": status,
		"outcome": outcome,
		"settled": settled,
		"kept": kept.duplicate(),
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
	var version: int = int(d.get("version", 1))
	run.starter_id = str(d.get("starter_id", ""))
	for id in d.get("cards", []):
		run.cards.append(str(id))
	if version < 2 or not d.has("duelist"):
		run.duelist_ids = AdventureRun._migrate_duelist(run.starter_id, int(d.get("aspects", 2)))
	else:
		for id in d.get("duelist", []):
			run.duelist_ids.append(str(id))
	run.stage = int(d.get("stage", 0))
	run.run_seed = int(d.get("run_seed", 0))
	for id in d.get("pending_offer", []):
		run.pending_offer.append(str(id))
	for id in d.get("pending_aspects", []):
		run.pending_aspects.append(str(id))
	run.status = str(d.get("status", "stage"))
	run.outcome = str(d.get("outcome", ""))
	run.settled = bool(d.get("settled", false))
	var kept_rows: Dictionary = d.get("kept", {})
	for id in kept_rows.keys():
		run.kept[str(id)] = int(kept_rows[id])
	for entry in d.get("picks", []):
		if entry is Dictionary:
			var row: Dictionary = entry
			var pick: Dictionary = {
				"stage": int(row.get("stage", 0)),
				"kind": str(row.get("kind", "")),
				"id": str(row.get("id", "")),
			}
			var pick_cards: Array[String] = []
			for id in row.get("cards", []):
				pick_cards.append(str(id))
			if not pick_cards.is_empty():
				pick["cards"] = pick_cards
			run.picks.append(pick)
	run.run_id = str(d.get("run_id", ""))
	if run.run_id == "":
		run.run_id = AdventureRun.id_for(run.starter_id, run.run_seed)
	for id in d.get("starter_cards", []):
		run.starter_cards.append(str(id))
	for id in d.get("starter_duelist", []):
		run.starter_duelist.append(str(id))
	# Version 3 and older named no starting deck, so a run in flight would settle as though it had
	# added everything. The printed starter is what such a run began from: loadout swaps came in
	# with the same version that started recording this.
	if run.starter_cards.is_empty():
		var printed: DeckList = DeckList.resolve(run.starter_id)
		if printed != null:
			run.starter_cards = printed.cards.duplicate()
			if run.starter_duelist.is_empty():
				run.starter_duelist = printed.duelist_ids.duplicate()
	# A version 2 offer named single cards. The stage the run sits on has not moved, so the same
	# offer seed draws the bundle offer that stage would have made.
	if version < 3 and not run.pending_offer.is_empty():
		var stale: bool = false
		for id in run.pending_offer:
			if AdventureBundles.by_id(id).is_empty():
				stale = true
		if stale:
			run.pending_offer.clear()
			run.needs_offer_rebuild = true
	return run
