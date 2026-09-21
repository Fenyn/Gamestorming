class_name AdventureRewards
extends RefCounted
## Builds and applies the pick-one-of-three offer between stages. DeckValidator is the only
## authority on legality here; nothing in this file restates a construction rule.

const CORE_PATH: String = "res://data/adventure/freestyle_core.json"
const OFFER_SIZE: int = 3

## Card types a run may be offered. Grounds, Seals, personalities, Masteries and Relics are not
## rewards in this slice.
const OFFER_TYPES: Array[CardDef.Type] = [
	CardDef.Type.STRIKE,
	CardDef.Type.ART,
	CardDef.Type.COMBAT,
	CardDef.Type.NON_COMBAT,
	CardDef.Type.DRILL,
]

static var _core_cache: Dictionary = {}


## The Freestyle cards any run may be offered regardless of its Style.
static func core_ids() -> Dictionary:
	if not _core_cache.is_empty():
		return _core_cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CORE_PATH))
	if not (parsed is Dictionary):
		push_error("Freestyle core list %s is not a JSON object" % CORE_PATH)
		return _core_cache
	var blob: Dictionary = parsed
	for id in blob.get("cards", []):
		_core_cache[str(id)] = true
	return _core_cache


## Every card this run could legally be offered, sorted so the pool is stable for a seed.
static func candidates(run: AdventureRun, library: CardLibrary) -> Array[String]:
	var out: Array[String] = []
	var deck: DeckList = run.deck()
	if deck == null:
		return out
	var duelist: CardDef = library.defs.get(deck.duelist_face_id())
	if duelist == null:
		return out
	var core: Dictionary = core_ids()
	var trial: DeckList = run.deck()
	for id in library.all_ids():
		var def: CardDef = library.defs[id]
		if not OFFER_TYPES.has(def.type):
			continue
		if not _source_ok(def, deck, duelist, core):
			continue
		if not _only_ok(def.only, deck, duelist, library):
			continue
		trial.cards.append(id)
		var problems: Array[String] = DeckValidator.validate(trial, library)
		trial.cards.resize(trial.cards.size() - 1)
		if problems.is_empty():
			out.append(id)
	out.sort()
	return out


## Where a card may come from: the deck's Style, the Freestyle core list, or the run duelist's own
## signature cards. Any other card naming a character belongs to someone else's run.
static func _source_ok(def: CardDef, deck: DeckList, duelist: CardDef, core: Dictionary) -> bool:
	if def.character != "":
		return def.character == duelist.character
	if def.school != "" and def.school == deck.style:
		return true
	return core.has(def.id)


## The card's `only` gate read against a deck rather than a table. An unknown key means the gate
## cannot be judged, so the card stays out.
static func _only_ok(gate: Dictionary, deck: DeckList, duelist: CardDef, library: CardLibrary) -> bool:
	if gate.is_empty():
		return true
	for key in gate.keys():
		var value: Variant = gate[key]
		match str(key):
			"any_of":
				var any_passed: bool = false
				for sub in value:
					if sub is Dictionary and _only_ok(sub, deck, duelist, library):
						any_passed = true
						break
				if not any_passed:
					return false
			"alignment":
				if deck.alignment != str(value):
					return false
			"character":
				# The gated personality must be someone the deck can put in control.
				if duelist.character != str(value) and not _deck_has_character(deck, library, str(value)):
					return false
			"duelist_character":
				# A list reads "X or Y", the way a card naming two personalities does.
				if value is Array:
					if not (value as Array).has(duelist.character):
						return false
				elif duelist.character != str(value):
					return false
			"tag":
				if not (duelist.raw.get("tags", []) as Array).has(str(value)):
					return false
			"bloodline":
				if duelist.bloodline != str(value):
					return false
			"energy_min":
				# A price to use, not a restriction on who may, so it never keeps a card out.
				pass
			_:
				return false
	return true


static func _deck_has_character(deck: DeckList, library: CardLibrary, character: String) -> bool:
	for id in deck.cards:
		var def: CardDef = library.defs.get(id)
		if def != null and def.type == CardDef.Type.PERSONALITY and def.character == character:
			return true
	return false


## `count` distinct ids drawn uniformly, fewer when the pool is short.
static func draw(ids: Array[String], count: int, seed_value: int) -> Array[String]:
	var pool: Array[String] = ids.duplicate()
	if pool.is_empty() or count <= 0:
		return []
	var rng: ZenithRng = ZenithRng.new(seed_value)
	rng.shuffle(pool)
	if pool.size() > count:
		pool.resize(count)
	return pool


static func offer(run: AdventureRun, library: CardLibrary) -> Array[String]:
	return draw(candidates(run, library), OFFER_SIZE, run.offer_seed(run.stage))


static func apply_pick(run: AdventureRun, library: CardLibrary, id: String) -> bool:
	if not run.pending_offer.has(id):
		return false
	var trial: DeckList = run.deck()
	if trial == null:
		return false
	trial.cards.append(id)
	if not DeckValidator.validate(trial, library).is_empty():
		return false
	run.cards.append(id)
	_record(run, "pick", id)
	return true


## False when the deck is already at the floor DeckValidator holds an adventure deck to.
static func can_cut(run: AdventureRun) -> bool:
	if run.cards.is_empty():
		return false
	var deck: DeckList = run.deck()
	if deck == null:
		return false
	var floor_size: int = DeckValidator.MIN_CARDS_ADVENTURE if deck.mode == "adventure" else DeckValidator.MIN_CARDS
	return deck.total_cards() - 1 >= floor_size


static func apply_cut(run: AdventureRun, library: CardLibrary, id: String) -> bool:
	if not run.cards.has(id):
		return false
	var trial: DeckList = run.deck()
	if trial == null:
		return false
	trial.cards.erase(id)
	if not DeckValidator.validate(trial, library).is_empty():
		return false
	run.cards.erase(id)
	_record(run, "cut", id)
	return true


static func apply_skip(run: AdventureRun) -> void:
	_record(run, "skip", "")


static func _record(run: AdventureRun, kind: String, id: String) -> void:
	run.picks.append({"stage": run.stage, "kind": kind, "id": id})
	run.pending_offer.clear()


## Applies the stage result. A win takes the stage's grant first, so the offer is drawn from the
## deck the player will actually run.
static func finish_stage(run: AdventureRun, ladder: AdventureLadder, library: CardLibrary, won: bool) -> void:
	if not won:
		run.pending_offer.clear()
		run.status = "lost"
		return
	var row: Dictionary = ladder.stage(run.stage)
	if str(row.get("grant", "")) == "aspect":
		_grant_aspect(run, library)
	run.pending_offer = offer(run, library)
	run.status = "reward"


## The run gains the next Aspect card of its Duelist's line. It stops when the character has no
## card at that tier or when the construction maximum is reached; `AdventureRun.next_tier_options`
## is what the later client pass offers as a choice.
static func _grant_aspect(run: AdventureRun, library: CardLibrary) -> void:
	var next: String = run.next_tier(library)
	if next != "":
		run.duelist_ids.append(next)


## Leaves the reward screen for the next stage, or ends the run when the ladder is spent.
static func finish_reward(run: AdventureRun, ladder: AdventureLadder) -> void:
	run.pending_offer.clear()
	run.stage += 1
	run.status = "won" if run.stage >= ladder.size() else "stage"
