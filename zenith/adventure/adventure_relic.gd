class_name AdventureRelic
extends RefCounted
## The Relic node (design 7.5). Three offers, each a Relic with a Reserve set, rolled once from the
## run seed and the node and saved with the run. Taking an offer replaces the held Relic and adds the
## set to the Reserve; a Reserve left over its new size sends the run to the Reserve screen
## (AdventureReserve) to set cards aside. A run that already holds a Relic may keep it instead.
##
## A set's key cards all have to fit the run or the set is not offered. Its fill cards are drawn one
## at a time from the legal candidates, so a fill card that would break a rule is never drawn.
## "Fit" is DeckValidator with every problem counted except an over-full Reserve, plus the card gates
## AdventureRewards reads for itself.

const KIND: String = "relic"
const STATUS_OFFERS: String = "relic"
const STATUS_TRIM: String = "reserve"
## No offer holds more than this many sets of one group, except on a Freestyle run, which has only
## the one group.
const MAX_PER_GROUP: int = 2

static var _shipped: CardLibrary = null


static func is_open(run: AdventureRun) -> bool:
	return run != null and run.status == STATUS_OFFERS


## Rolls the offers of the Relic node the run stands on, the first time only.
static func open(run: AdventureRun, library: CardLibrary) -> void:
	if not is_open(run) or not run.relic_offers.is_empty():
		return
	run.relic_offers = roll(run, library, run.node_id)


## The three offers a Relic node on node `id` would make the run as it stands: distinct Relics, and
## distinct sets. With fewer legal sets than Relics, the last offers carry no set.
static func roll(run: AdventureRun, library: CardLibrary, id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seed_value: int = run.relic_seed(id)
	var rng: ZenithRng = ZenithRng.new(seed_value)
	var relics: Array[String] = eligible_relics(run, library)
	rng.shuffle(relics)
	var count: int = mini(AdventureEconomy.relic_offer_count(), relics.size())
	var sets: Array[Dictionary] = draw_sets(run, library, seed_value, count)
	for i in range(count):
		var offer: Dictionary = {"relic": relics[i], "bundle": "", "cards": [] as Array[String]}
		if i < sets.size():
			offer["bundle"] = sets[i]["id"]
			offer["cards"] = sets[i]["cards"]
		out.append(offer)
	return out


## The Relics this run may be offered, in pool order: every pooled Relic the library knows, less a
## Relic that asks for an Ally when the run holds none.
static func eligible_relics(run: AdventureRun, library: CardLibrary) -> Array[String]:
	var out: Array[String] = []
	var allies: bool = holds_ally(run, library)
	var needs_ally: Array[String] = AdventureEconomy.relic_needs_ally()
	for id in AdventureEconomy.relic_pool():
		var def: CardDef = library.defs.get(id)
		if def == null or def.type != CardDef.Type.RELIC:
			continue
		if needs_ally.has(id) and not allies:
			continue
		out.append(id)
	return out


## True when the Life Deck or the Reserve holds a personality card, which is an Ally there.
static func holds_ally(run: AdventureRun, library: CardLibrary) -> bool:
	for pile: Array[String] in [run.cards, run.reserve]:
		for id in pile:
			var def: CardDef = library.defs.get(id)
			if def != null and def.type == CardDef.Type.PERSONALITY:
				return true
	return false


## Up to `count` resolved sets, {id, cards}, for the seed: one of the run's own school first when one
## resolves, then the rest in seeded order with no more than MAX_PER_GROUP of one group. A Freestyle
## run draws from the Freestyle sets alone and has no group cap.
static func draw_sets(run: AdventureRun, library: CardLibrary, seed_value: int, count: int) -> Array[Dictionary]:
	var deck: DeckList = run.deck()
	var out: Array[Dictionary] = []
	if deck == null or count <= 0:
		return out
	var ids: Array[String] = []
	for bundle in AdventureReserveBundles.all():
		var group: String = str(bundle.get("group", ""))
		if group == deck.style or group == AdventureBundles.GROUP_FREESTYLE:
			ids.append(str(bundle.get("id", "")))
	var rng: ZenithRng = ZenithRng.new(seed_value)
	rng.shuffle(ids)
	var freestyle_run: bool = deck.style == AdventureBundles.GROUP_FREESTYLE
	var resolved: Dictionary = {}
	for id in ids:
		var cards: Array[String] = resolve(run, library, AdventureReserveBundles.by_id(id), set_seed(seed_value, id))
		if not cards.is_empty():
			resolved[id] = cards
	var order: Array[String] = []
	for id in ids:
		if resolved.has(id) and _group(id) == deck.style and not freestyle_run:
			order.append(id)
			break
	var per_group: Dictionary = {}
	for id in order:
		per_group[_group(id)] = 1
	for id in ids:
		if order.size() >= count:
			break
		if not resolved.has(id) or order.has(id):
			continue
		var group: String = _group(id)
		if not freestyle_run and int(per_group.get(group, 0)) >= MAX_PER_GROUP:
			continue
		order.append(id)
		per_group[group] = int(per_group.get(group, 0)) + 1
	for id in order:
		out.append({"id": id, "cards": resolved[id]})
	return out


## The seed one set's fill draw uses, so a set resolves the same whichever sets were drawn before it.
static func set_seed(seed_value: int, bundle_id: String) -> int:
	return AdventureRun._mix(seed_value, bundle_id.hash() & 0x3FFFFFFF)


## A set's cards for this run, sorted so copies sit together: every key card, then fill drawn from
## the candidates that still fit, up to the set's size. Empty when a key card does not fit, which
## leaves the set out. Short of the size when the fill candidates run dry.
static func resolve(run: AdventureRun, library: CardLibrary, bundle: Dictionary, seed_value: int) -> Array[String]:
	var out: Array[String] = []
	var trial: DeckList = run.deck()
	if trial == null or bundle.is_empty():
		return out
	var duelist: CardDef = library.defs.get(trial.duelist_face_id())
	if duelist == null:
		return out
	if trial.relic_id == "":
		# Any Relic stands in: the Reserve's size is the one problem not counted here.
		var pool: Array[String] = AdventureEconomy.relic_pool()
		trial.relic_id = pool[0] if not pool.is_empty() else ""
	var base: Array[String] = trial.reserve.duplicate()
	var before: Array[String] = AdventureReserve.problems(trial, library)
	for id in AdventureReserveBundles.key_cards(bundle):
		if not _fits(trial, base, out, id, before, duelist, library):
			return [] as Array[String]
		out.append(id)
	var rng: ZenithRng = ZenithRng.new(seed_value)
	var candidates: Array[String] = AdventureReserveBundles.fill_pool(bundle)
	for slot in range(int(bundle.get("fill_count", 0))):
		var legal: Array[String] = []
		for id in candidates:
			if _fits(trial, base, out, id, before, duelist, library):
				legal.append(id)
		if legal.is_empty():
			break
		out.append(legal[rng.randi_range(0, legal.size() - 1)])
	trial.reserve = base
	out.sort()
	return out


## Takes offer `index`: its Relic replaces the held one, its set joins the Reserve, and the pick is
## recorded. A Reserve now over the Relic's size sends the run to set cards aside; otherwise the
## visit is over. False, and nothing moves, when the run is not on a Relic node or the offer no
## longer fits the run.
static func take(run: AdventureRun, library: CardLibrary, index: int) -> bool:
	if not is_open(run) or index < 0 or index >= run.relic_offers.size():
		return false
	var offer: Dictionary = run.relic_offers[index]
	var relic: String = str(offer.get("relic", ""))
	var cards: Array[String] = []
	for id in offer.get("cards", []):
		cards.append(str(id))
	var before: DeckList = run.deck()
	var after: DeckList = run.deck()
	if before == null or library.defs.get(relic) == null:
		return false
	after.relic_id = relic
	after.reserve.append_array(cards)
	if before.relic_id == "":
		before.relic_id = relic
	if AdventureReserve.adds_problem(before, after, library):
		return false
	run.relic_id = relic
	run.reserve.append_array(cards)
	run.picks.append({"stage": run.stage, "kind": KIND, "id": relic, "cards": cards.duplicate()})
	run.relic_offers.clear()
	run.reserve_new.clear()
	run.status = "map"
	if AdventureReserve.excess(run, library) > 0:
		run.status = STATUS_TRIM
		run.reserve_new = cards.duplicate()
	return true


## Keeps the held Relic and Reserve and ends the visit. False when the run holds no Relic, since a
## run without one has to take an offer.
static func keep(run: AdventureRun) -> bool:
	if not is_open(run) or run.relic_id == "":
		return false
	run.relic_offers.clear()
	run.status = "map"
	return true


## Passes a Relic node without the player: keeps the held Relic, else takes the first offer, then
## sets the last Reserve cards aside until the Reserve fits. For tests, tools and dev screens only.
## `library` defaults to the shipped cards.
static func pass_through(run: AdventureRun, library: CardLibrary = null) -> void:
	if run == null or (run.status != STATUS_OFFERS and run.status != STATUS_TRIM):
		return
	var cards: CardLibrary = library if library != null else shipped_library()
	if run.status == STATUS_OFFERS:
		open(run, cards)
		if not keep(run) and not take(run, cards, 0):
			run.relic_offers.clear()
			run.status = "map"
	if run.status == STATUS_TRIM:
		AdventureReserve.trim_last(run, cards)
		AdventureReserve.finish(run, cards)
		run.status = "map"


## The shipped cards, loaded once, for a walk that was not handed a library.
static func shipped_library() -> CardLibrary:
	if _shipped == null:
		_shipped = CardLibrary.new()
		_shipped.load_dir("res://data/cards")
	return _shipped


static func _fits(trial: DeckList, base: Array[String], taken: Array[String], id: String,
		before: Array[String], duelist: CardDef, library: CardLibrary) -> bool:
	var def: CardDef = library.defs.get(id)
	if def == null or not AdventureRewards.card_gates_ok(def, trial, duelist, library):
		return false
	trial.reserve = base.duplicate()
	trial.reserve.append_array(taken)
	trial.reserve.append(id)
	for problem in AdventureReserve.problems(trial, library):
		if not before.has(problem):
			return false
	return true


static func _group(bundle_id: String) -> String:
	return str(AdventureReserveBundles.by_id(bundle_id).get("group", ""))
