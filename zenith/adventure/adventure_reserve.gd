class_name AdventureReserve
extends RefCounted
## The Reserve and the run library (design 4.7): moving cards between the Life Deck, the Reserve and
## the library. A Reserve card may go to the library, and a library card to the Reserve while the
## Reserve is under its Relic's size. The Life Deck only ever swaps one card for one, since its size
## changes only at a node. Any move that would give DeckValidator a new problem is refused; the one
## problem allowed to stand is an over-full Reserve, which the player clears by setting cards aside.
## Nothing here saves.

const LIFE: String = "life"
const RESERVE: String = "reserve"
const LIBRARY: String = "library"

## Why a move or swap is refused, as a sentence for the screen.
const BLOCK_CLOSED: String = "Your deck is dealt for the duel in progress."
const BLOCK_ABSENT: String = "That card is not there any more."
const BLOCK_SAME: String = "Both cards are in the same pile."
const BLOCK_LIFE_SIZE: String = "Your Life Deck changes size only at a node. Swap a card for another instead."
const BLOCK_NO_RELIC: String = "You hold no Relic, so you have no Reserve."
const BLOCK_FULL: String = "Your Reserve is full. Set a card aside first, or swap one."
const BLOCK_RESERVE_ONLY: String = "That card may sit only in the Reserve."
const BLOCK_RULE: String = "That would break a deck rule."


## True while the Reserve screen may change the run: on the map, standing on a fight whose duel has
## not been dealt, or setting cards aside after a Relic.
static func is_editable(run: AdventureRun) -> bool:
	if run == null or not run.duel_history.is_empty():
		return false
	return run.status == "map" or run.status == "stage" or run.status == AdventureRelic.STATUS_TRIM


## How many cards the held Relic lets the Reserve hold; 0 without a Relic.
static func capacity(run: AdventureRun, library: CardLibrary) -> int:
	var relic: CardDef = library.defs.get(run.relic_id) if run.relic_id != "" else null
	return relic.reserve_size if relic != null else 0


## Cards the Reserve holds past its Relic's size.
static func excess(run: AdventureRun, library: CardLibrary) -> int:
	return maxi(0, run.reserve.size() - capacity(run, library))


## DeckValidator's problems with the over-full Reserve left out.
static func problems(deck: DeckList, library: CardLibrary) -> Array[String]:
	var out: Array[String] = []
	for problem in DeckValidator.validate(deck, library):
		if not problem.begins_with(DeckValidator.RESERVE_SIZE_PREFIX):
			out.append(problem)
	return out


## True when `after` has a problem `before` did not, the over-full Reserve aside.
static func adds_problem(before: DeckList, after: DeckList, library: CardLibrary) -> bool:
	var had: Array[String] = problems(before, library)
	for problem in problems(after, library):
		if not had.has(problem):
			return true
	return false


static func pile(run: AdventureRun, name: String) -> Array[String]:
	match name:
		LIFE:
			return run.cards
		RESERVE:
			return run.reserve
		LIBRARY:
			return run.library
	return []


## Why one card cannot move from pile `from` to pile `to` on its own, or "" when it can. Only the
## Reserve and the library trade single cards.
static func move_block(run: AdventureRun, library: CardLibrary, from: String, id: String, to: String) -> String:
	if not is_editable(run):
		return BLOCK_CLOSED
	if from == to:
		return BLOCK_SAME
	if from == LIFE or to == LIFE:
		return BLOCK_LIFE_SIZE
	if not pile(run, from).has(id):
		return BLOCK_ABSENT
	if to == RESERVE:
		if run.relic_id == "":
			return BLOCK_NO_RELIC
		if run.reserve.size() >= capacity(run, library):
			return BLOCK_FULL
	return _trial_block(run, library, from, id, to, "")


## Moves one card between the Reserve and the library. False, and nothing moves, when refused.
static func move(run: AdventureRun, library: CardLibrary, from: String, id: String, to: String) -> bool:
	if move_block(run, library, from, id, to) != "":
		return false
	pile(run, from).erase(id)
	pile(run, to).append(id)
	return true


## Why card `id_a` in pile `a` cannot trade places with card `id_b` in pile `b`, or "" when it can.
static func swap_block(run: AdventureRun, library: CardLibrary, a: String, id_a: String, b: String, id_b: String) -> String:
	if not is_editable(run):
		return BLOCK_CLOSED
	if a == b:
		return BLOCK_SAME
	if not pile(run, a).has(id_a) or not pile(run, b).has(id_b):
		return BLOCK_ABSENT
	if (a == RESERVE or b == RESERVE) and run.relic_id == "":
		return BLOCK_NO_RELIC
	return _trial_block(run, library, a, id_a, b, id_b)


## Trades two cards between piles, one for one. False, and nothing moves, when refused.
static func swap(run: AdventureRun, library: CardLibrary, a: String, id_a: String, b: String, id_b: String) -> bool:
	if swap_block(run, library, a, id_a, b, id_b) != "":
		return false
	pile(run, a).erase(id_a)
	pile(run, b).erase(id_b)
	pile(run, a).append(id_b)
	pile(run, b).append(id_a)
	return true


## Why the player cannot leave the Reserve screen yet, or "" when the deck passes DeckValidator whole.
static func done_block(run: AdventureRun, library: CardLibrary) -> String:
	var deck: DeckList = run.deck()
	if deck == null:
		return BLOCK_RULE
	var over: int = excess(run, library)
	if over > 0:
		return "Set aside %d more Reserve %s to leave." % [over, "card" if over == 1 else "cards"]
	if not DeckValidator.validate(deck, library).is_empty():
		return "Your deck breaks a rule, so it cannot leave yet."
	return ""


## Leaves the Reserve screen: a run setting cards aside goes back to the map, and nothing is new any
## more. False, and nothing changes, while `done_block` has a reason.
static func finish(run: AdventureRun, library: CardLibrary) -> bool:
	if done_block(run, library) != "":
		return false
	run.reserve_new.clear()
	if run.status == AdventureRelic.STATUS_TRIM:
		run.status = "map"
	return true


## Sets the last Reserve cards aside until the Reserve fits its Relic. For tests and tools only: the
## player picks what to set aside.
static func trim_last(run: AdventureRun, library: CardLibrary) -> void:
	while excess(run, library) > 0:
		run.library.append(run.reserve.pop_back())


## The deck as it would stand after the move, checked against the deck as it stands. Only a card
## that enters the Life Deck can be Reserve only there, so that refusal gets its own sentence.
static func _trial_block(run: AdventureRun, library: CardLibrary, a: String, id_a: String, b: String, id_b: String) -> String:
	var before: DeckList = run.deck()
	var after: DeckList = run.deck()
	if before == null or after == null:
		return BLOCK_RULE
	var piles: Dictionary = {LIFE: after.cards, RESERVE: after.reserve, LIBRARY: run.library.duplicate()}
	(piles[a] as Array[String]).erase(id_a)
	(piles[b] as Array[String]).append(id_a)
	if id_b != "":
		(piles[b] as Array[String]).erase(id_b)
		(piles[a] as Array[String]).append(id_b)
	if not adds_problem(before, after, library):
		return ""
	var into_life: String = id_a if b == LIFE else (id_b if a == LIFE else "")
	var def: CardDef = library.defs.get(into_life)
	if def != null and bool(def.raw.get("reserve_only", false)):
		return BLOCK_RESERVE_ONLY
	return BLOCK_RULE
