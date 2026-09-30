class_name AdventureForge
extends RefCounted
## The Forge node. A visit allows one action, free: cut one card from the run deck, or copy one card
## already in it. The player may also leave without acting. The run stands on the node with status
## "forge" until the visit ends, then chooses its next node on the map like after any other stop.
## DeckValidator decides what is legal; this file only names why a card is refused.

const ACTION_CUT: String = "cut"
const ACTION_COPY: String = "copy"

## Short tags for a card that cannot be copied, shown on its tile.
const BLOCK_PERSONALITY: String = "Personality"
const BLOCK_SEAL: String = "Seal"
const BLOCK_MASTERY: String = "Mastery"
const BLOCK_RELIC: String = "Relic"
const BLOCK_ABSENT: String = "Not in the deck"
const BLOCK_LIMIT: String = "At its limit"
const BLOCK_FULL: String = "Deck is full"


static func is_open(run: AdventureRun) -> bool:
	return run != null and run.status == "forge"


## The smallest deck DeckValidator allows this run, counted the way `DeckList.total_cards` counts.
static func floor_size(run: AdventureRun) -> int:
	var deck: DeckList = run.deck()
	if deck != null and deck.mode != "adventure":
		return DeckValidator.MIN_CARDS
	return DeckValidator.MIN_CARDS_ADVENTURE


## The largest deck DeckValidator allows this run. Build plan 2.6's per-run size cap belongs here
## once it exists; until then the construction maximum is the only limit.
static func max_size(run: AdventureRun) -> int:
	var deck: DeckList = run.deck()
	if deck != null and deck.style == "root":
		return DeckValidator.MAX_CARDS_ROOT
	return DeckValidator.MAX_CARDS


static func deck_size(run: AdventureRun) -> int:
	var deck: DeckList = run.deck()
	return deck.total_cards() if deck != null else 0


## Why the whole Cut action is closed, as a sentence, or "" when it is open.
static func cut_block(run: AdventureRun) -> String:
	if AdventureRewards.can_cut(run):
		return ""
	return "The deck is at %d cards, the smallest it can be." % deck_size(run)


## Why the whole Copy action is closed, as a sentence, or "" when it is open.
static func copy_block(run: AdventureRun, library: CardLibrary) -> String:
	if not copy_options(run, library).is_empty():
		return ""
	if deck_size(run) >= max_size(run):
		return "The deck is at %d cards, the most it can hold." % deck_size(run)
	return "No card in the deck can take another copy."


## Every distinct card id in the deck that one more copy of would leave legal, sorted.
static func copy_options(run: AdventureRun, library: CardLibrary) -> Array[String]:
	var out: Array[String] = []
	for id in _distinct(run.cards):
		if card_copy_block(run, library, id) == "":
			out.append(id)
	return out


## Why one card cannot be copied, as a short tag, or "" when it can. Personalities, Seals and the
## deck's Mastery and Relic are never copied; anything else goes when DeckValidator accepts the deck
## with the extra copy. Adding a copy of a card a legal deck already runs can break only its size
## or that card's copy limit, so a refusal that is not the size is the limit.
static func card_copy_block(run: AdventureRun, library: CardLibrary, id: String) -> String:
	var def: CardDef = library.defs.get(id)
	if def == null:
		return BLOCK_ABSENT
	match def.type:
		CardDef.Type.PERSONALITY:
			return BLOCK_PERSONALITY
		CardDef.Type.SEAL:
			return BLOCK_SEAL
		CardDef.Type.MASTERY:
			return BLOCK_MASTERY
		CardDef.Type.RELIC:
			return BLOCK_RELIC
	if not run.cards.has(id):
		return BLOCK_ABSENT
	var trial: DeckList = run.deck()
	if trial == null:
		return BLOCK_ABSENT
	if trial.total_cards() + 1 > max_size(run):
		return BLOCK_FULL
	trial.cards.append(id)
	if not DeckValidator.validate(trial, library).is_empty():
		return BLOCK_LIMIT
	return ""


## Cuts one card and ends the visit. False, and nothing moves, when the run is not at a Forge or the
## cut is refused.
static func cut(run: AdventureRun, library: CardLibrary, id: String) -> bool:
	if not is_open(run) or not AdventureRewards.can_cut(run):
		return false
	if not AdventureRewards.apply_cut(run, library, id):
		return false
	leave(run)
	return true


## Adds one more copy of a card already in the deck and ends the visit. False, and nothing moves,
## when the run is not at a Forge or the card cannot be copied.
static func copy(run: AdventureRun, library: CardLibrary, id: String) -> bool:
	if not is_open(run) or card_copy_block(run, library, id) != "":
		return false
	run.cards.append(id)
	AdventureRewards.record(run, ACTION_COPY, id)
	leave(run)
	return true


## Ends the visit without touching the deck.
static func leave(run: AdventureRun) -> void:
	if is_open(run):
		run.status = "map"


static func _distinct(ids: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	var out: Array[String] = []
	for id in ids:
		if not seen.has(id):
			seen[id] = true
			out.append(id)
	out.sort()
	return out
