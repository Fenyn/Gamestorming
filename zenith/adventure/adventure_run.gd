class_name AdventureRun
extends RefCounted
## One adventure run: the starter it grew from, the deck as it stands, and where it stands on the
## node map. Pure state. No Nodes and no autoloads, the same rule engine/ follows. The map itself is
## never saved: `AdventureMap.generate(starter_id, run_seed)` rolls it again.

## `stage` counts the duels won so far, which is also the 0-based index of the next duel: it keys
## the duel and offer seeds and the pick history.
var starter_id: String = ""
## Names this run in the wallet's ledger, so a payout can be traced back to the run that paid it.
var run_id: String = ""
var cards: Array[String] = []      # expanded, one entry per copy, like DeckList.cards
## The deck the run began from, as it was at `begin`: after a loadout swap that is the swapped
## list, not the printed starter. `added_cards()` is everything the run owns beyond it and
## `starter_reserve`, which is what the run-end settlement charges for.
var starter_cards: Array[String] = []
## The Reserve the run began with: the starter's own, or one granted by the character's deck
## abilities.
var starter_reserve: Array[String] = []
var starter_duelist: Array[String] = []
## The Duelist's Aspect stack as it stands, one card id per tier. Each Aspect is its own card, so
## a run grows by gaining the next tier card, not by raising a number.
var duelist_ids: Array[String] = []
## The Duelist's personality cards the player owns above the starting stack. An Aspect grant only
## ever offers one of these (design doc 8.6).
var owned_aspects: Array[String] = []
## The Relic the run holds and its Reserve: the starter's own at `begin_with`, one from the
## character's deck abilities, or one taken at the Relic node. "" and [] for none.
var relic_id: String = ""
var reserve: Array[String] = []
## Cards the run owns outside the Life Deck and the Reserve (design 4.7). A card set aside from the
## Reserve lands here; nothing in it is ever destroyed.
var library: Array[String] = []
## The offers on the Relic node the run stands on, {relic, bundle, cards}, rolled once when the node
## opens and kept until the choice is made.
var relic_offers: Array[Dictionary] = []
## Reserve cards that arrived with the Relic just taken, marked new on the Reserve screen until the
## player leaves it.
var reserve_new: Array[String] = []
## The Resonances the run holds (ResonanceData ids), in the order taken. Every duel carries them
## through `deck()`; they are not cards and count toward nothing.
var resonances: Array[String] = []
## The Resonance ids on offer at the Shrine the run stands on, or at the claim after a won Elite,
## rolled once when it opens and kept until the visit ends.
var shrine_offers: Array[String] = []
var stage: int = 0
var run_seed: int = 0
## The map node the run stands on, "" before the first step.
var node_id: String = ""
## Every node entered, in order.
var path: Array[String] = []
## The bundle ids on offer while `status` is "reward".
var pending_offer: Array[String] = []
## The Aspect card ids on offer while `status` is "aspect".
var pending_aspects: Array[String] = []
## map: choosing the next node. stage: standing on a fight, the duel still to play. forge: standing
## on a Forge whose one action is still open (AdventureForge). shop: standing in a Shop
## (AdventureShop). relic: standing on the Relic node with its offers open (AdventureRelic). reserve:
## a Relic was just taken and the Reserve holds more than it allows, so cards must be set aside
## (AdventureReserve). shrine: standing on a Shrine with its offers open (AdventureShrine). claim: a
## won Elite's Resonance offer, after its reward steps (AdventureElite).
var status: String = "map"         # map | stage | forge | shop | relic | reserve | shrine | aspect | reward | claim | settle | won | lost
## The run's own currency (design 7.6): earned by winning fights, spent only at Shops. It belongs to
## the run, so it is gone when the run ends and is never turned into Motes.
var mana: int = 0
## node id -> {"stock": Array[String], "sold": Array[int]} for every Shop the run has opened. Kept
## for the whole run, so a Shop is rolled once and remembers what it sold.
var shops: Dictionary = {}
## Which way the run ended, kept while `status` is "settle" so the run-end screen knows whether it
## is showing a win or a loss. "" until the run ends.
var outcome: String = ""
## True once the run-end settlement is closed. A settled run cannot be reopened or bought from.
var settled: bool = false
## id -> copies already bought at the run-end settlement, so a card cannot be kept twice.
var kept: Dictionary = {}
## {stage, kind, id} for every kind, plus "cards" on a bundle or relic pick.
## kind: bundle | aspect | aspect_skipped | skip | cut | copy (a Forge copy) | buy (a Shop card) |
## joined (a storyline boss's card) | relic (a Relic node offer, its Reserve set as "cards") |
## resonance (a Shrine offer)
var picks: Array[Dictionary] = []
## The duel in progress as `Referee.history`, saved after every command so a closed game comes
## back to the same position. Empty between duels.
var duel_history: Array[Dictionary] = []


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
	run.mana = AdventureEconomy.mana_start()
	var starter: DeckList = DeckList.resolve(starter_id_value)
	if starter != null and starter.relic_id != "":
		run.relic_id = starter.relic_id
		run.reserve = starter.reserve.duplicate()
		run.starter_reserve = starter.reserve.duplicate()
	return run


## A run's name in the ledger. Derived, so a save written before run ids existed gets the same one
## back on load.
static func id_for(starter: String, run_seed_value: int) -> String:
	return "%s-%d" % [starter, run_seed_value]


## Every card the run owns, one entry per copy: the Life Deck, the Reserve and the library.
func owned_cards() -> Array[String]:
	var out: Array[String] = cards.duplicate()
	out.append_array(reserve)
	out.append_array(library)
	return out


## The cards the run gained, one entry per copy: everything it owns across the Life Deck, the Reserve
## and the library beyond what it started with. This is what the run-end settlement charges for.
func added_cards() -> Array[String]:
	var left: Dictionary = {}
	for id in starter_cards + starter_reserve:
		left[id] = int(left.get(id, 0)) + 1
	var out: Array[String] = []
	for id in owned_cards():
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


## The nodes the run may step to next: act 1's first tier at the start, else whatever the node it
## stands on leads to. Empty unless the run is choosing.
func choices(map: AdventureMap) -> Array[String]:
	if status != "map" or map == null:
		return []
	return map.start_ids() if node_id == "" else map.next_of(node_id)


## Steps onto a node. A fight leaves the run waiting on its duel, and a Forge, a Shop, a Shrine or the
## Relic node waits on its visit; any other node is passed through, since none of them does anything
## yet. False, and nothing moves, when `id` is not one of the choices.
func enter(map: AdventureMap, id: String) -> bool:
	if not choices(map).has(id):
		return false
	node_id = id
	path.append(id)
	var type: String = str(map.node(id).get("type", ""))
	if AdventureMap.is_fight(type):
		status = "stage"
	elif type in ["forge", "shop", "relic", "shrine"]:
		status = type
	return true


## Takes the first choice at every step until the run stands on a fight, leaving every Forge, Shop,
## Shrine and Elite claim on the way without acting and passing the Relic node the way
## `AdventureRelic.pass_through` does. For tests, tools and dev screens; the player picks their own
## way. `library` defaults to the shipped cards. False when there is no fight left to reach.
func walk_to_next_duel(map: AdventureMap, library: CardLibrary = null) -> bool:
	var guard: int = 0
	while status in ["map", "forge", "shop", "relic", "reserve", "shrine", "claim"] and guard < 64:
		guard += 1
		AdventureForge.leave(self)
		AdventureShop.leave(self)
		AdventureShrine.leave(self)
		AdventureRelic.pass_through(self, library)
		if status != "map":
			return false
		var next: Array[String] = choices(map)
		if next.is_empty() or not enter(map, next[0]):
			return false
	return status == "stage"


## The starter reloaded with this run's Life Deck, Aspect stack, Relic and Reserve in place of the
## printed ones.
func deck() -> DeckList:
	var d: DeckList = DeckList.resolve(starter_id)
	if d == null:
		return null
	d.cards = cards.duplicate()
	d.set_duelist(duelist_ids)
	d.relic_id = relic_id
	d.reserve = reserve.duplicate()
	d.resonances = resonances.duplicate()
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


## Every owned personality card that could be the run's next Aspect: the same character, one tier
## up, and legal for the deck's alignment.
func next_tier_options(library: CardLibrary) -> Array[String]:
	var out: Array[String] = []
	if duelist_ids.is_empty():
		return out
	var top: CardDef = library.defs.get(duelist_ids[duelist_ids.size() - 1])
	if top == null or duelist_ids.size() >= DeckValidator.MAX_ASPECTS:
		return out
	var d: DeckList = deck()
	var alignment: String = d.alignment if d != null else ""
	for id in owned_aspects:
		var def: CardDef = library.defs.get(id)
		if def == null or not def.is_personality() or def.character != top.character:
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


## Seed for the stock of the Shop on node `id`. Mixed with a negative number, so it never meets a
## stage or offer seed.
func shop_seed(id: String) -> int:
	return _mix(run_seed, -1 - (id.hash() & 0x3FFFFFFF))


## Seed for the offers of the Relic node on node `id`, below every Shop seed.
func relic_seed(id: String) -> int:
	return _mix(run_seed, -0x40000001 - (id.hash() & 0x3FFFFFFF))


## Seed for the offers of the Shrine on node `id`, below every Relic seed.
func shrine_seed(id: String) -> int:
	return _mix(run_seed, -0x80000001 - (id.hash() & 0x3FFFFFFF))


## Seed for the claim after a won Elite on node `id`, below every Shrine seed.
func claim_seed(id: String) -> int:
	return _mix(run_seed, -0xC0000001 - (id.hash() & 0x3FFFFFFF))


func earn_mana(amount: int) -> void:
	mana += maxi(0, amount)


## Takes `amount` Mana. False, and nothing moves, when the run holds less.
func spend_mana(amount: int) -> bool:
	if amount < 0 or amount > mana:
		return false
	mana -= amount
	return true


## Deterministic integer mix. Always positive and never zero, so a seed is never "unseeded".
static func _mix(a: int, b: int) -> int:
	var h: int = a * 0x9E3779B1 + b * 0x85EBCA77 + 0x27D4EB2F
	h = (h ^ (h >> 33)) * 0xFF51AFD7
	h = (h ^ (h >> 29)) * 0xC2B2AE35
	h = h ^ (h >> 32)
	return (h & 0x3FFFFFFF) + 1


## An older save is not migrated: `from_dict` refuses it and the run is dropped, since a run in
## flight is not worth carrying across (user, 2026-09-23).
const SAVE_VERSION: int = 11


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"starter_id": starter_id,
		"run_id": run_id,
		"cards": cards.duplicate(),
		"duelist": duelist_ids.duplicate(),
		"owned_aspects": owned_aspects.duplicate(),
		"relic": relic_id,
		"reserve": reserve.duplicate(),
		"library": library.duplicate(),
		"relic_offers": relic_offers.duplicate(true),
		"reserve_new": reserve_new.duplicate(),
		"resonances": resonances.duplicate(),
		"shrine_offers": shrine_offers.duplicate(),
		"starter_cards": starter_cards.duplicate(),
		"starter_reserve": starter_reserve.duplicate(),
		"starter_duelist": starter_duelist.duplicate(),
		"stage": stage,
		"run_seed": run_seed,
		"node_id": node_id,
		"path": path.duplicate(),
		"pending_offer": pending_offer.duplicate(),
		"pending_aspects": pending_aspects.duplicate(),
		"status": status,
		"outcome": outcome,
		"settled": settled,
		"kept": kept.duplicate(),
		"picks": picks.duplicate(true),
		"duel_history": duel_history.duplicate(true),
		"mana": mana,
		"shops": shops.duplicate(true),
	}


## Tolerant of JSON, which hands every number back as a float. Null for a save written before
## SAVE_VERSION.
static func from_dict(d: Dictionary) -> AdventureRun:
	if int(d.get("version", 1)) < SAVE_VERSION:
		return null
	var run: AdventureRun = AdventureRun.new()
	run.starter_id = str(d.get("starter_id", ""))
	for id in d.get("cards", []):
		run.cards.append(str(id))
	for id in d.get("duelist", []):
		run.duelist_ids.append(str(id))
	for id in d.get("owned_aspects", []):
		run.owned_aspects.append(str(id))
	run.relic_id = str(d.get("relic", ""))
	for id in d.get("reserve", []):
		run.reserve.append(str(id))
	for id in d.get("library", []):
		run.library.append(str(id))
	for id in d.get("reserve_new", []):
		run.reserve_new.append(str(id))
	for id in d.get("resonances", []):
		run.resonances.append(str(id))
	for id in d.get("shrine_offers", []):
		run.shrine_offers.append(str(id))
	for entry in d.get("relic_offers", []):
		if entry is Dictionary:
			var row: Dictionary = entry
			var offer_cards: Array[String] = []
			for id in row.get("cards", []):
				offer_cards.append(str(id))
			run.relic_offers.append({"relic": str(row.get("relic", "")), "bundle": str(row.get("bundle", "")),
				"cards": offer_cards})
	run.stage = int(d.get("stage", 0))
	run.run_seed = int(d.get("run_seed", 0))
	run.node_id = str(d.get("node_id", ""))
	for id in d.get("path", []):
		run.path.append(str(id))
	for id in d.get("pending_offer", []):
		run.pending_offer.append(str(id))
	for id in d.get("pending_aspects", []):
		run.pending_aspects.append(str(id))
	run.status = str(d.get("status", "map"))
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
	for id in d.get("starter_reserve", []):
		run.starter_reserve.append(str(id))
	for id in d.get("starter_duelist", []):
		run.starter_duelist.append(str(id))
	for entry in d.get("duel_history", []):
		if entry is Dictionary:
			var command: Dictionary = _whole_numbers(entry)
			run.duel_history.append(command)
	run.mana = int(d.get("mana", AdventureEconomy.mana_start()))
	var shop_rows: Dictionary = d.get("shops", {})
	for id in shop_rows.keys():
		if not (shop_rows[id] is Dictionary):
			continue
		var row: Dictionary = shop_rows[id]
		var stock: Array[String] = []
		for card in row.get("stock", []):
			stock.append(str(card))
		var sold: Array[int] = []
		for slot in row.get("sold", []):
			sold.append(int(slot))
		run.shops[str(id)] = {"stock": stock, "sold": sold}
	return run


## A command names uids, counts and amounts, never a fraction, so every whole float JSON hands back
## goes back to an int and the replay matches the options it was taken from exactly.
static func _whole_numbers(value: Variant) -> Variant:
	if value is float and float(value) == floorf(float(value)):
		return int(value)
	if value is Dictionary:
		var fields: Dictionary = {}
		for key in (value as Dictionary).keys():
			fields[key] = _whole_numbers((value as Dictionary)[key])
		return fields
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_whole_numbers(item))
		return items
	return value
