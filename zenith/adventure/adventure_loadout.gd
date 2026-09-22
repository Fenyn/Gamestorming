class_name AdventureLoadout
extends RefCounted
## Building a starter into the deck a run begins from: swapping collection cards in, filling the
## extra deck slots bought with Motes, and adding the Aspect cards whose tiers were unlocked.
##
## The collection is a library. A swap copies from it and never empties it, so the same card can go
## into every run and into two different starters at once. What it does limit is how many copies
## one deck may take: a loadout may put in at most as many copies of a card as the collection
## holds. The starter's own printed cards are the starter's, not the library's, so they never count
## against that.
##
## DeckValidator is the only authority on legality here. Nothing in this file restates a
## construction rule; a refused swap hands back the validator's own words.

## What `base_deck` records on the deck it hands out, so everything below can tell the starter's
## own cards from the ones the loadout added without resolving the starter file again. `_copy`
## carries them onto every trial deck.
const META_STARTER: String = "loadout_starter_id"
const META_BASE_COUNTS: String = "loadout_base_counts"
const META_BASE_SIZE: String = "loadout_base_size"
const META_BASE_ASPECTS: String = "loadout_base_aspects"
const META_KEYS: Array[String] = [META_STARTER, META_BASE_COUNTS, META_BASE_SIZE, META_BASE_ASPECTS]


## The printed starter, untouched, as a run would begin from it, tagged with what it printed so a
## later swap or add knows which copies came out of the collection.
static func base_deck(starter_id: String) -> DeckList:
	var deck: DeckList = DeckList.resolve(starter_id)
	if deck == null:
		return null
	deck.set_meta(META_STARTER, starter_id)
	deck.set_meta(META_BASE_COUNTS, _counts_of(deck))
	deck.set_meta(META_BASE_SIZE, deck.cards.size())
	deck.set_meta(META_BASE_ASPECTS, deck.duelist_ids.size())
	return deck


## The starter this deck was built from, or "" for a deck that did not come through `base_deck`.
static func starter_of(deck: DeckList) -> String:
	return str(deck.get_meta(META_STARTER, "")) if deck != null else ""


## Copies of every id the deck holds, Life Deck and Duelist stack together: a personality can be an
## Ally and a rung at once, and both copies come out of the same collection row.
static func _counts_of(deck: DeckList) -> Dictionary:
	var out: Dictionary = {}
	for id in deck.cards:
		out[id] = int(out.get(id, 0)) + 1
	for id in deck.duelist_ids:
		out[id] = int(out.get(id, 0)) + 1
	return out


## What the starter printed. A deck with no record is taken as all starter, which leaves the copy
## rule silent rather than guessing against a deck this file did not assemble.
static func _base_counts(deck: DeckList) -> Dictionary:
	var recorded: Variant = deck.get_meta(META_BASE_COUNTS, null)
	return recorded if recorded is Dictionary else _counts_of(deck)


## Copies of `id` this deck took out of the collection: what it holds beyond what the starter
## printed.
static func from_collection(deck: DeckList, id: String) -> int:
	var held: Dictionary = _counts_of(deck)
	return maxi(0, int(held.get(id, 0)) - int(_base_counts(deck).get(id, 0)))


## How many Life Deck cards this starter may run: its own printed size plus the slots bought for it.
static func size_cap(deck: DeckList, upgrades: AdventureUpgrades = null) -> int:
	if deck == null:
		return 0
	var base: int = int(deck.get_meta(META_BASE_SIZE, deck.cards.size()))
	var starter_id: String = starter_of(deck)
	if upgrades == null or starter_id == "":
		return base
	return base + upgrades.slots(starter_id)


## Empty Life Deck slots left: what a starter may still add. A starter may begin with them empty.
static func room_left(deck: DeckList, upgrades: AdventureUpgrades = null) -> int:
	return maxi(0, size_cap(deck, upgrades) - deck.cards.size()) if deck != null else 0


## The highest Aspect this starter's stack may reach before a run begins: its own printed height,
## or higher when a tier was bought.
static func aspect_cap(deck: DeckList, upgrades: AdventureUpgrades = null) -> int:
	if deck == null:
		return 0
	var base: int = int(deck.get_meta(META_BASE_ASPECTS, deck.duelist_ids.size()))
	var starter_id: String = starter_of(deck)
	if upgrades == null or starter_id == "":
		return base
	return upgrades.aspect_tier(starter_id, base)


## Distinct Life Deck card ids that can be traded away, sorted. Everything in the deck qualifies:
## whether the deck still works without it is the validator's answer, not this list's.
static func swappable_out(deck: DeckList) -> Array[String]:
	var out: Array[String] = []
	for id in deck.cards:
		if not out.has(id):
			out.append(id)
	out.sort()
	return out


## Collection cards that could legally take `slot`'s place in the Life Deck, sorted. Each one is
## tried as a whole deck and kept only when the validator has nothing to say about the result.
static func swappable_in(deck: DeckList, library: CardLibrary, collection: AdventureCollection,
		slot: String) -> Array[String]:
	var out: Array[String] = []
	if collection == null:
		return out
	for id in collection.all_ids():
		if id == slot:
			continue
		var result: Dictionary = swap(deck, slot, id, library, collection)
		if (result["problems"] as Array[String]).is_empty():
			out.append(id)
	return out


## One out, one in. Returns {"deck": DeckList or null, "problems": Array[String]}: the swapped deck
## when it is legal, and the problems when it is not. The deck passed in is never changed.
static func swap(deck: DeckList, out_id: String, in_id: String, library: CardLibrary,
		collection: AdventureCollection = null) -> Dictionary:
	var problems: Array[String] = []
	if deck == null:
		problems.append("No deck to swap in")
		return {"deck": null, "problems": problems}
	if not deck.cards.has(out_id):
		problems.append("'%s' is not in the deck" % out_id)
		return {"deck": null, "problems": problems}
	var trial: DeckList = _copy(deck)
	trial.cards.erase(out_id)
	trial.cards.append(in_id)
	return _finish(trial, in_id, library, collection, problems)


## Collection personality cards that could stand on rung `tier` of the Duelist, sorted.
static func swappable_rungs(deck: DeckList, library: CardLibrary,
		collection: AdventureCollection, tier: int) -> Array[String]:
	var out: Array[String] = []
	if collection == null:
		return out
	for id in collection.all_ids():
		var def: CardDef = library.defs.get(id)
		if def == null or not def.is_personality():
			continue
		var result: Dictionary = swap_rung(deck, tier, id, library, collection)
		if (result["problems"] as Array[String]).is_empty():
			out.append(id)
	return out


## Trades the Duelist's rung at `tier` (1-based, the Aspect number) for another card. A card of the
## wrong character or the wrong tier is refused by the validator, which is where the stack rules
## live: a stack is one character, one card per Aspect, from Aspect 1 with no gaps.
static func swap_rung(deck: DeckList, tier: int, in_id: String, library: CardLibrary,
		collection: AdventureCollection = null) -> Dictionary:
	var problems: Array[String] = []
	if deck == null:
		problems.append("No deck to swap in")
		return {"deck": null, "problems": problems}
	var index: int = tier - 1
	if index < 0 or index >= deck.duelist_ids.size():
		problems.append("The Duelist has no tier %d" % tier)
		return {"deck": null, "problems": problems}
	var trial: DeckList = _copy(deck)
	var stack: Array[String] = trial.duelist_ids.duplicate()
	stack[index] = in_id
	trial.set_duelist(stack)
	return _finish(trial, in_id, library, collection, problems)


# --- Adding, once slots and tiers have been bought --------------------------

## Collection cards that could legally fill an empty Life Deck slot, sorted. Empty when the deck is
## already at its cap.
static func swappable_add(deck: DeckList, library: CardLibrary, collection: AdventureCollection,
		upgrades: AdventureUpgrades = null) -> Array[String]:
	var out: Array[String] = []
	if collection == null or room_left(deck, upgrades) <= 0:
		return out
	for id in collection.all_ids():
		var result: Dictionary = add_card(deck, id, library, collection, upgrades)
		if (result["problems"] as Array[String]).is_empty():
			out.append(id)
	return out


## Puts one more card into the Life Deck, filling a bought slot. Refused when the deck is at its
## size cap, when the collection does not hold another copy to give, or when the validator objects.
static func add_card(deck: DeckList, in_id: String, library: CardLibrary,
		collection: AdventureCollection = null, upgrades: AdventureUpgrades = null) -> Dictionary:
	var problems: Array[String] = []
	if deck == null:
		problems.append("No deck to add to")
		return {"deck": null, "problems": problems}
	if room_left(deck, upgrades) <= 0:
		problems.append("The deck is full at %d cards; buy a deck slot to add another"
			% size_cap(deck, upgrades))
		return {"deck": null, "problems": problems}
	var trial: DeckList = _copy(deck)
	trial.cards.append(in_id)
	return _finish(trial, in_id, library, collection, problems)


## Collection Aspect cards that could be added on top of the Duelist stack, sorted. Empty when no
## tier above the stack has been unlocked.
static func swappable_aspect(deck: DeckList, library: CardLibrary,
		collection: AdventureCollection, upgrades: AdventureUpgrades = null) -> Array[String]:
	var out: Array[String] = []
	if collection == null or deck == null:
		return out
	if deck.duelist_ids.size() + 1 > aspect_cap(deck, upgrades):
		return out
	for id in collection.all_ids():
		var def: CardDef = library.defs.get(id)
		if def == null or not def.is_personality():
			continue
		var result: Dictionary = add_aspect(deck, id, library, collection, upgrades)
		if (result["problems"] as Array[String]).is_empty():
			out.append(id)
	return out


## Puts one more Aspect card on top of the Duelist stack. Only the next tier can be added, and only
## once that tier has been unlocked for this starter; the stack stays consecutive from Aspect 1,
## which is the validator's rule and not restated here.
static func add_aspect(deck: DeckList, in_id: String, library: CardLibrary,
		collection: AdventureCollection = null, upgrades: AdventureUpgrades = null) -> Dictionary:
	var problems: Array[String] = []
	if deck == null:
		problems.append("No deck to add to")
		return {"deck": null, "problems": problems}
	var next_tier: int = deck.duelist_ids.size() + 1
	if next_tier > aspect_cap(deck, upgrades):
		problems.append("Aspect %d is not unlocked for this starter" % next_tier)
		return {"deck": null, "problems": problems}
	var trial: DeckList = _copy(deck)
	var stack: Array[String] = trial.duelist_ids.duplicate()
	stack.append(in_id)
	trial.set_duelist(stack)
	return _finish(trial, in_id, library, collection, problems)


# --- Shared checks ----------------------------------------------------------

## The three questions every put-a-card-in path asks, in the same order: does the library know the
## card, does the collection hold enough copies for what the deck would then take, and does
## DeckValidator have anything to say about the result.
static func _finish(trial: DeckList, in_id: String, library: CardLibrary,
		collection: AdventureCollection, problems: Array[String]) -> Dictionary:
	if not library.defs.has(in_id):
		problems.append("Unknown card '%s'" % in_id)
		return {"deck": null, "problems": problems}
	if collection != null:
		var owned: int = collection.copies(in_id)
		var taken: int = from_collection(trial, in_id)
		if owned <= 0:
			problems.append("'%s' is not in the collection" % in_id)
			return {"deck": null, "problems": problems}
		if taken > owned:
			var def: CardDef = library.defs.get(in_id)
			var title: String = def.title if def != null and def.title != "" else in_id
			problems.append("You own %d %s of %s; the deck already takes that many from the collection"
				% [owned, "copy" if owned == 1 else "copies", title])
			return {"deck": null, "problems": problems}
	problems.append_array(DeckValidator.validate(trial, library))
	return {"deck": trial if problems.is_empty() else null, "problems": problems}


## Starts the run from an assembled deck. `starter_cards` records what was assembled, so the
## run-end settlement charges for what the run added and not for a card swapped in beforehand.
static func begin_from(starter_id: String, deck: DeckList, run_seed: int) -> AdventureRun:
	if deck == null:
		return AdventureRun.begin(starter_id, run_seed)
	return AdventureRun.begin_with(starter_id, run_seed, deck.cards, deck.duelist_ids)


## A working copy of a deck, so a refused swap leaves the deck the screen is showing alone. The
## starter record travels with it, since a trial deck is still the same starter.
static func _copy(deck: DeckList) -> DeckList:
	var out: DeckList = DeckList.new()
	out.name = deck.name
	out.set_duelist(deck.duelist_ids)
	out.style = deck.style
	out.alignment = deck.alignment
	out.mastery_id = deck.mastery_id
	out.relic_id = deck.relic_id
	out.reserve = deck.reserve.duplicate()
	out.archetype = deck.archetype
	out.subthemes = deck.subthemes.duplicate()
	out.difficulty = deck.difficulty
	out.ai_profile = deck.ai_profile
	out.tagline = deck.tagline
	out.blurb = deck.blurb
	out.cards = deck.cards.duplicate()
	out.mode = deck.mode
	for key in META_KEYS:
		if deck.has_meta(key):
			out.set_meta(key, deck.get_meta(key))
	return out
