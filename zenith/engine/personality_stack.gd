class_name PersonalityStack
extends RefCounted
## One character's Aspect stack: one personality card per tier, consecutive from the bottom.
##
## Each Aspect is its own card (decided 2026-09-21), so a Duelist is a list of card ids and not
## one card holding a ladder. A stack is assembled once at the boundary — when a duel is built
## from a `DeckList`, or when an Ally overlays its next tier — and the engine then asks the stack
## for "the row for Aspect n" exactly as it used to ask a CardDef.
##
## Immutable once built. `CardInstance.stack` shares one by reference across clones, so nothing
## here may be mutated after `of()` returns.

var defs: Array[CardDef] = []   # tier order, lowest first


## Null-tolerant: an unknown id is dropped and the caller's validator reports it.
static func from_ids(library: CardLibrary, ids: Array[String]) -> PersonalityStack:
	var out: Array[CardDef] = []
	for id in ids:
		var def: CardDef = library.defs.get(id)
		if def != null:
			out.append(def)
	return PersonalityStack.of(out)


static func of(cards: Array[CardDef]) -> PersonalityStack:
	var s: PersonalityStack = PersonalityStack.new()
	s.defs = cards.duplicate()
	s.defs.sort_custom(func(a: CardDef, b: CardDef) -> bool: return a.aspect < b.aspect)
	return s


## The stack a lone personality card makes on its own, which is what an Ally enters play as.
static func single(def: CardDef) -> PersonalityStack:
	return PersonalityStack.of([def] as Array[CardDef])


## This stack with one more tier on top. Used when an Ally overlays its next Aspect.
func plus(def: CardDef) -> PersonalityStack:
	var cards: Array[CardDef] = defs.duplicate()
	cards.append(def)
	return PersonalityStack.of(cards)


func is_empty() -> bool:
	return defs.is_empty()


func size() -> int:
	return defs.size()


func lowest_aspect() -> int:
	return defs[0].aspect if not defs.is_empty() else 0


func highest_aspect() -> int:
	return defs[defs.size() - 1].aspect if not defs.is_empty() else 0


## The card that is this Aspect, or null when the stack does not reach it.
func def_for(aspect: int) -> CardDef:
	for d in defs:
		if d.aspect == aspect:
			return d
	return null


## The Aspect row the engine reads for Might, Surge, Power and Constant. Empty when out of range.
func aspect_data(aspect: int) -> Dictionary:
	var d: CardDef = def_for(aspect)
	return d.aspect_data(aspect) if d != null else {}


## The announced ladder, which is public from setup: both sides need it for Most Powerful
## Personality and clients show it on the select and versus screens.
func card_ids() -> Array[String]:
	var out: Array[String] = []
	for d in defs:
		out.append(d.id)
	return out


func character() -> String:
	return defs[0].character if not defs.is_empty() else ""


func title() -> String:
	return defs[0].title if not defs.is_empty() else ""
