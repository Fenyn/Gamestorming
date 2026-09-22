class_name AdventureLoadout
extends RefCounted
## Swapping collection cards into a starter before a run. The starter keeps its size: a swap is
## one card out and one card in, and a Duelist rung is traded for another card of the same
## character at the same tier.
##
## The collection is a library. A swap copies from it and never empties it, so the same card can
## go into every run, and owning one copy is enough to field as many as the deck limit allows.
##
## DeckValidator is the only authority on legality here. Nothing in this file restates a
## construction rule; a refused swap hands back the validator's own words.

## The printed starter, untouched, as a run would begin from it.
static func base_deck(starter_id: String) -> DeckList:
	return DeckList.resolve(starter_id)


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
## when it is legal, and the validator's problems when it is not. The deck passed in is never
## changed.
static func swap(deck: DeckList, out_id: String, in_id: String, library: CardLibrary,
		collection: AdventureCollection = null) -> Dictionary:
	var problems: Array[String] = []
	if deck == null:
		problems.append("No deck to swap in")
		return {"deck": null, "problems": problems}
	if not deck.cards.has(out_id):
		problems.append("'%s' is not in the deck" % out_id)
		return {"deck": null, "problems": problems}
	if not library.defs.has(in_id):
		problems.append("Unknown card '%s'" % in_id)
		return {"deck": null, "problems": problems}
	if collection != null and collection.copies(in_id) <= 0:
		problems.append("'%s' is not in the collection" % in_id)
		return {"deck": null, "problems": problems}
	var trial: DeckList = _copy(deck)
	trial.cards.erase(out_id)
	trial.cards.append(in_id)
	problems.append_array(DeckValidator.validate(trial, library))
	return {"deck": trial if problems.is_empty() else null, "problems": problems}


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
		var result: Dictionary = swap_rung(deck, tier, id, library)
		if (result["problems"] as Array[String]).is_empty():
			out.append(id)
	return out


## Trades the Duelist's rung at `tier` (1-based, the Aspect number) for another card. A card of
## the wrong character or the wrong tier is refused by the validator, which is where the stack
## rules live: a stack is one character, one card per Aspect, from Aspect 1 with no gaps.
static func swap_rung(deck: DeckList, tier: int, in_id: String, library: CardLibrary,
		collection: AdventureCollection = null) -> Dictionary:
	var problems: Array[String] = []
	if deck == null:
		problems.append("No deck to swap in")
		return {"deck": null, "problems": problems}
	var index: int = tier - 1
	if index < 0 or index >= deck.duelist_ids.size():
		problems.append("The Duelist has no rung %d" % tier)
		return {"deck": null, "problems": problems}
	if not library.defs.has(in_id):
		problems.append("Unknown card '%s'" % in_id)
		return {"deck": null, "problems": problems}
	if collection != null and collection.copies(in_id) <= 0:
		problems.append("'%s' is not in the collection" % in_id)
		return {"deck": null, "problems": problems}
	var trial: DeckList = _copy(deck)
	var stack: Array[String] = trial.duelist_ids.duplicate()
	stack[index] = in_id
	trial.set_duelist(stack)
	problems.append_array(DeckValidator.validate(trial, library))
	return {"deck": trial if problems.is_empty() else null, "problems": problems}


## Starts the run from an assembled deck. `starter_cards` records what was assembled, so the
## run-end settlement charges for what the run added and not for a card swapped in beforehand.
static func begin_from(starter_id: String, deck: DeckList, run_seed: int) -> AdventureRun:
	if deck == null:
		return AdventureRun.begin(starter_id, run_seed)
	return AdventureRun.begin_with(starter_id, run_seed, deck.cards, deck.duelist_ids)


## A working copy of a deck, so a refused swap leaves the deck the screen is showing alone.
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
	return out
