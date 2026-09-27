class_name AdventureRewards
extends RefCounted
## Builds and applies the between-stage rewards: an Aspect card choice on a grant stage, then a
## pick-one-of-three theme bundle offer. DeckValidator is the only authority on legality here;
## nothing in this file restates a construction rule.

const OFFER_SIZE: int = 3
## No offer may hold more than this many bundles of one group, so three Pyre bundles never crowd
## out everything else.
const MAX_PER_GROUP: int = 2

## When each tier opens, as a fraction of the way through the run (`AdventureMap.progress_of`):
## early from the start, mid from act 1 tier 7, late from act 2 tier 5.
const TIER_OPENS: Dictionary = {"early": 0.0, "mid": 0.25, "late": 0.5}


## Bundle ids this run could be offered at `progress` of the way through the run, sorted so the
## pool is stable for a seed.
static func eligible(run: AdventureRun, library: CardLibrary, progress: float) -> Array[String]:
	var out: Array[String] = []
	var deck: DeckList = run.deck()
	if deck == null:
		return out
	var duelist: CardDef = library.defs.get(deck.duelist_face_id())
	if duelist == null:
		return out
	var taken: Dictionary = {}
	for id in run.taken_bundles():
		taken[id] = true
	for bundle in AdventureBundles.all():
		var id: String = str(bundle.get("id", ""))
		if taken.has(id):
			continue
		if not _group_ok(bundle, deck, duelist, library):
			continue
		if not _tier_ok(str(bundle.get("tier", "")), progress):
			continue
		if not _cards_ok(bundle, deck, duelist, library):
			continue
		if not _fits(bundle, run, library):
			continue
		out.append(id)
	out.sort()
	return out


## Who may be offered this bundle at all. A school bundle needs a deck of that Style; Freestyle
## and Grounds bundles are open to every run; a signature bundle needs its character in the
## Duelist's seat; an Ally bundle needs an Ally the deck does not already field, and a follow-up
## needs that Ally already in the deck.
static func _group_ok(bundle: Dictionary, deck: DeckList, duelist: CardDef, library: CardLibrary) -> bool:
	var group: String = str(bundle.get("group", ""))
	match group:
		AdventureBundles.GROUP_FREESTYLE, AdventureBundles.GROUP_GROUNDS:
			return true
		AdventureBundles.GROUP_SIGNATURE:
			return str(bundle.get("character", "")) == duelist.character
		AdventureBundles.GROUP_ALLY:
			var requires: String = str(bundle.get("requires_character", ""))
			if requires != "":
				return _deck_has_character(deck, library, requires)
			var character: String = str(bundle.get("character", ""))
			if character == "" or character == duelist.character:
				return false
			return not _deck_has_character(deck, library, character)
		_:
			return deck.style == group


## Per-card gates that construction does not cover: the card's `only` clause, and the alignment
## a card prints for itself. DeckValidator reads `alignment_only` on personalities only, so a
## "Vigil only" Strike is filtered here instead of being offered to a Pact run.
static func _cards_ok(bundle: Dictionary, deck: DeckList, duelist: CardDef, library: CardLibrary) -> bool:
	for id in AdventureBundles.cards_of(bundle):
		var def: CardDef = library.defs.get(id)
		if def == null:
			return false
		if def.alignment_only != "" and def.alignment_only != deck.alignment:
			return false
		if not _only_ok(def.only, deck, duelist, library):
			return false
	return true


## The hard gate: every card of the bundle added together to a copy of the run deck has to leave
## DeckValidator with nothing to say. One illegal card drops the whole bundle.
static func _fits(bundle: Dictionary, run: AdventureRun, library: CardLibrary) -> bool:
	var trial: DeckList = run.deck()
	if trial == null:
		return false
	trial.cards.append_array(AdventureBundles.cards_of(bundle))
	return DeckValidator.validate(trial, library).is_empty()


## Tier gate: `early` from the start, `mid` from a quarter of the way through, `late` from half.
static func _tier_ok(tier: String, progress: float) -> bool:
	return progress >= float(TIER_OPENS.get(tier, 0.0))


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
			"energy_min", "allies_min", "when":
				# A price to use or a board state to wait for, not a restriction on who may own
				# the card, so it never keeps one out of a deck.
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


## `count` distinct bundle ids for a seed. One bundle of the run's own group is guaranteed when
## one is eligible, and no group takes more than MAX_PER_GROUP of the three slots. Everything
## else is uniform. Fewer than `count` when the pool cannot fill it; none is a valid result.
static func draw(ids: Array[String], count: int, seed_value: int, run: AdventureRun) -> Array[String]:
	var pool: Array[String] = ids.duplicate()
	if pool.is_empty() or count <= 0:
		return []
	var rng: ZenithRng = ZenithRng.new(seed_value)
	rng.shuffle(pool)
	var own: String = _own_group(run)
	var picked: Array[String] = []
	var per_group: Dictionary = {}
	# The run's own school first, so a deck always sees a way to deepen what it already is.
	if own != "":
		for id in pool:
			if _group_of(id) == own:
				picked.append(id)
				per_group[own] = 1
				break
	for id in pool:
		if picked.size() >= count:
			break
		if picked.has(id):
			continue
		var group: String = _group_of(id)
		if int(per_group.get(group, 0)) >= MAX_PER_GROUP:
			continue
		picked.append(id)
		per_group[group] = int(per_group.get(group, 0)) + 1
	return picked


static func _group_of(bundle_id: String) -> String:
	return str(AdventureBundles.by_id(bundle_id).get("group", ""))


## The group that counts as "the run's own school". A Freestyle Style has no school pool of its
## own, so the shared Freestyle bundles are its school bundles.
static func _own_group(run: AdventureRun) -> String:
	var deck: DeckList = run.deck()
	if deck == null:
		return ""
	return deck.style


## The offer after the duel just won, gated by how far through the map that duel stood.
static func offer(run: AdventureRun, library: CardLibrary, map: AdventureMap) -> Array[String]:
	var progress: float = maxf(0.0, map.progress_of(run.node_id)) if map != null else 0.0
	var ids: Array[String] = eligible(run, library, progress)
	return draw(ids, OFFER_SIZE, run.offer_seed(run.stage), run)


## Takes one offered bundle, whole. Every card is re-validated together, so a deck that changed
## since the offer was built refuses the bundle rather than adding part of it.
static func apply_bundle(run: AdventureRun, library: CardLibrary, bundle_id: String) -> bool:
	if not run.pending_offer.has(bundle_id):
		return false
	var bundle: Dictionary = AdventureBundles.by_id(bundle_id)
	if bundle.is_empty():
		return false
	var cards: Array[String] = AdventureBundles.cards_of(bundle)
	if cards.is_empty():
		return false
	var trial: DeckList = run.deck()
	if trial == null:
		return false
	trial.cards.append_array(cards)
	if not DeckValidator.validate(trial, library).is_empty():
		return false
	run.cards.append_array(cards)
	run.picks.append({"stage": run.stage, "kind": "bundle", "id": bundle_id, "cards": cards.duplicate()})
	run.pending_offer.clear()
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


## Every Aspect card the run could climb to, validated in the stack it would join.
static func aspect_options(run: AdventureRun, library: CardLibrary) -> Array[String]:
	var out: Array[String] = []
	for id in run.next_tier_options(library):
		var trial: DeckList = run.deck()
		if trial == null:
			continue
		var stack: Array[String] = run.duelist_ids.duplicate()
		stack.append(id)
		trial.set_duelist(stack)
		if DeckValidator.validate(trial, library).is_empty():
			out.append(id)
	return out


## Takes one offered Aspect card. It joins the Duelist stack, not the Life Deck.
static func apply_aspect(run: AdventureRun, library: CardLibrary, card_id: String) -> bool:
	if not run.pending_aspects.has(card_id):
		return false
	if not aspect_options(run, library).has(card_id):
		return false
	run.duelist_ids.append(card_id)
	run.picks.append({"stage": run.stage, "kind": "aspect", "id": card_id})
	run.pending_aspects.clear()
	return true


## Applies the stage result. A win that grants an Aspect stops at the Aspect choice first, so the
## bundle offer is drawn from the deck the player will actually run.
##
## Returns the Motes the win is worth. Nothing here touches the wallet or a file: the caller
## credits it and decides when to save, which is what keeps adventure/ free of IO decisions.
static func finish_stage(run: AdventureRun, map: AdventureMap, library: CardLibrary, won: bool) -> int:
	if not won:
		run.pending_offer.clear()
		run.pending_aspects.clear()
		run.status = "lost"
		return 0
	var here: Dictionary = map.node(run.node_id)
	var payout: int = AdventureEconomy.duel_payout(int(here.get("act", 1)), str(here.get("type", "")) == "boss")
	var row: Dictionary = map.duel_for(run.node_id)
	if str(row.get("grant", "")) == "aspect":
		var options: Array[String] = aspect_options(run, library)
		if not options.is_empty():
			run.pending_aspects = options
			run.status = "aspect"
			return payout
		# The Duelist is at the top of its character's ladder or at the construction maximum.
		run.picks.append({"stage": run.stage, "kind": "aspect_skipped", "id": ""})
	run.pending_aspects.clear()
	run.pending_offer = offer(run, library, map)
	run.status = "reward"
	return payout


## The whole result of the duel on the run's node, applied once: the story log's tally, on a win
## the join, XP and achievements, the Motes it pays (credited to `wallet`) and, on a loss, the
## run-end settlement. The duel is over, so its saved history goes too. Returns what a win gave, as
## `AdventureProgress.record_win` entries. A run that is not waiting on a duel is left as it is, so
## recording the same duel twice changes nothing. Nothing here saves.
static func record_duel(run: AdventureRun, map: AdventureMap, library: CardLibrary, won: bool,
		engine: DuelEngine, story_log: AdventureStoryLog, collection: AdventureCollection,
		unlocks: AdventureUnlocks, progress: AdventureProgress, wallet: AdventureWallet) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if run.status != "stage":
		return results
	var opponent_family: String = AdventureDecks.family_of(str(map.duel_for(run.node_id).get("opponent", "")))
	story_log.begin_run(run.run_id)
	story_log.record_result(AdventureDecks.character_of(AdventureDecks.family_of(run.starter_id)),
		AdventureDecks.character_of(opponent_family), won)
	if won:
		results = AdventureProgress.record_win(run, map, engine, library, collection, unlocks, progress, wallet)
	var payout: int = finish_stage(run, map, library, won)
	if payout > 0:
		wallet.earn(payout, AdventureWallet.REASON_STAGE, run.run_id, run.stage)
	if not won:
		AdventureSettlement.open(run)
	run.duel_history.clear()
	return results


## Leaves the Aspect step for the bundle offer, which is built from the deck as it now stands.
static func finish_aspect(run: AdventureRun, map: AdventureMap, library: CardLibrary) -> void:
	run.pending_aspects.clear()
	run.pending_offer = offer(run, library, map)
	run.status = "reward"


## Leaves the reward screen for the map, or ends the run when the duel just won was the final
## boss. Returns the completion bonus when the run is won and 0 otherwise; the caller credits it.
static func finish_reward(run: AdventureRun, map: AdventureMap) -> int:
	run.pending_offer.clear()
	run.stage += 1
	if run.node_id != map.final_id():
		run.status = "map"
		return 0
	run.status = "won"
	return AdventureEconomy.completion_bonus()
