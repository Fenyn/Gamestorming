class_name DeckValidator
extends RefCounted
## Deck construction rules. Returns a list of problems; empty means legal.

const MIN_CARDS: int = 50
## Adventure starters are deliberately below tournament legality; a run grows into it.
const MIN_CARDS_ADVENTURE: int = 30
const MIN_ASPECTS_ADVENTURE: int = 1
const MAX_CARDS: int = 85
const MAX_CARDS_ROOT: int = 90
const MIN_ASPECTS: int = 3
const MAX_ASPECTS: int = 5
const SIGNATURE_LIMIT: int = 4
## What a card allows when it prints no limit of its own; see CardDef.limit_per_deck.
const DEFAULT_LIMIT: int = 3
## The highest Aspect a personality card may be to sit in the Life Deck as an Ally.
const MAX_ALLY_ASPECT: int = 3


## Where an Ally may sit. A personality card of Aspect 1, 2 or 3 may be in the Life Deck of any
## deck, whatever height its Duelist runs (2026-09-21, following the later rulings revision; it
## replaced an older rule that asked for a two-Aspect gap under the Duelist's highest, and with it
## the 2026-09-20 house exemption for Aspect 1, which this covers). The Aspects an Ally runs need
## not be consecutive and need not include Aspect 1: that is a Duelist rule only.
static func ally_aspect_allowed(aspect: int) -> bool:
	return aspect <= MAX_ALLY_ASPECT


## Every Ally rule that reads one card. A personality in the Life Deck is an Ally; there is no
## Ally card type, the deck names one personality as its Duelist and every other one it runs
## fights as an Ally. One copy of each personality card, and two different cards of one character
## at one Aspect are not copies of each other, so a deck may run both.
##
## This is where "an Ally may not share your Duelist's character" is enforced, and the only place:
## the engine does not check it again in play, because a personality can only reach your side of
## the table out of your own Life Deck or Reserve, both of which pass through here. The Reserve is
## checked for the same reason, since a Reserve swap puts those cards in the Life Deck at setup.
static func ally_problems(def: CardDef, deck: DeckList, duelist: CardDef) -> Array[String]:
	var out: Array[String] = []
	if def.character == duelist.character:
		out.append("Ally '%s' is the same character as the Duelist" % def.id)
	if def.alignment_only != "" and def.alignment_only != deck.alignment:
		out.append("Ally '%s' does not match alignment %s" % [def.id, deck.alignment])
	if not ally_aspect_allowed(def.aspect):
		out.append("Ally '%s' is Aspect %d; an Ally may be Aspect 1 to %d"
			% [def.id, def.aspect, MAX_ALLY_ASPECT])
	return out


static func validate(deck: DeckList, library: CardLibrary) -> Array[String]:
	var problems: Array[String] = []
	if deck.duelist_ids.is_empty():
		problems.append("Deck names no Duelist cards")
		return problems
	# The Duelist is a stack: one personality card per Aspect, consecutive from Aspect 1, all of
	# them the same character. Cards from different printed lines of that character mix freely.
	var stack_defs: Array[CardDef] = []
	for id in deck.duelist_ids:
		var d: CardDef = library.defs.get(id)
		if d == null or d.type != CardDef.Type.PERSONALITY:
			problems.append("Duelist card '%s' not found" % id)
			continue
		stack_defs.append(d)
	if stack_defs.size() != deck.duelist_ids.size():
		return problems
	var duelist: CardDef = stack_defs[0]
	var seen_aspects: Dictionary = {}
	for d in stack_defs:
		if d.character != duelist.character:
			problems.append("Duelist card '%s' is %s, not %s" % [d.id, d.character, duelist.character])
		if seen_aspects.has(d.aspect):
			problems.append("Duelist has two cards at Aspect %d" % d.aspect)
		seen_aspects[d.aspect] = true
		if d.alignment_only != "" and d.alignment_only != deck.alignment:
			problems.append("Duelist card '%s' does not match alignment %s" % [d.id, deck.alignment])
	for n in range(1, stack_defs.size() + 1):
		if not seen_aspects.has(n):
			problems.append("Duelist is missing Aspect %d; a stack runs from Aspect 1 with no gaps" % n)
	var adventure: bool = deck.mode == "adventure"
	var min_aspects: int = MIN_ASPECTS_ADVENTURE if adventure else MIN_ASPECTS
	if deck.aspects < min_aspects or deck.aspects > MAX_ASPECTS:
		problems.append("Duelist must run %d to %d aspects" % [min_aspects, MAX_ASPECTS])
	# A deck may go unlabelled, but a label has to be one the game knows how to show.
	if deck.archetype != "" and not Archetype.known(deck.archetype):
		problems.append("Unknown archetype '%s'" % deck.archetype)
	for s in deck.subthemes:
		if not Archetype.SUBTHEMES.has(s):
			problems.append("Unknown subtheme '%s'" % s)
	if deck.difficulty != "" and not Archetype.DIFFICULTIES.has(deck.difficulty):
		problems.append("Unknown difficulty '%s'" % deck.difficulty)
	var max_cards: int = MAX_CARDS_ROOT if deck.style == "root" else MAX_CARDS
	var min_cards: int = MIN_CARDS_ADVENTURE if adventure else MIN_CARDS
	var total: int = deck.total_cards()
	if total < min_cards or total > max_cards:
		problems.append("Deck has %d cards, needs %d to %d" % [total, min_cards, max_cards])

	var counts: Dictionary = {}
	var seal_sets: Dictionary = {}
	var styled_seen: bool = false
	for id in deck.cards:
		var def: CardDef = library.defs.get(id)
		if def == null:
			problems.append("Unknown card '%s'" % id)
			continue
		counts[id] = int(counts.get(id, 0)) + 1
		if def.type == CardDef.Type.MASTERY or def.type == CardDef.Type.RELIC:
			problems.append("'%s' cannot be in the Life Deck" % id)
		if def.school != "":
			styled_seen = true
			if deck.style != def.school:
				problems.append("'%s' is %s, deck Style is %s" % [id, def.school, deck.style])
		if def.type == CardDef.Type.SEAL:
			seal_sets[def.seal_set] = true
		# "Sensei Deck only": legal in the Reserve and nowhere else.
		if bool(def.raw.get("reserve_only", false)):
			problems.append("'%s' is Reserve only and cannot be in the Life Deck" % id)
		if def.type == CardDef.Type.PERSONALITY:
			problems.append_array(ally_problems(def, deck, duelist))
	for id in counts.keys():
		var def: CardDef = library.defs[id]
		var limit: int = def.limit_per_deck
		if def.type == CardDef.Type.SEAL or def.type == CardDef.Type.PERSONALITY:
			limit = 1
		elif def.character != "" and def.character == duelist.character and limit >= DEFAULT_LIMIT:
			# A card naming your Main Personality allows a fourth copy, unless the card prints a
			# limit of its own. A printed limit is the tighter rule and wins.
			limit = SIGNATURE_LIMIT
		if int(counts[id]) > limit:
			problems.append("'%s' x%d exceeds limit %d" % [id, counts[id], limit])
	if seal_sets.size() > 1:
		problems.append("Only one Seal set per deck")
	# Every deck follows one Style: its Mastery's school ("freestyle" for a schoolless Mastery).
	if deck.style == "freestyle" and styled_seen:
		problems.append("A Freestyle Style allows no school cards")
	if deck.mastery_id == "":
		problems.append("Every deck needs a Mastery")
	else:
		var mastery: CardDef = library.defs.get(deck.mastery_id)
		var wanted_school: String = "" if deck.style == "freestyle" else deck.style
		if mastery == null or mastery.type != CardDef.Type.MASTERY:
			problems.append("Mastery '%s' not found" % deck.mastery_id)
		elif deck.style == "":
			problems.append("Deck Style must be set to the Mastery's school")
		elif mastery.school != wanted_school:
			problems.append("Mastery school '%s' does not match Style %s" % [mastery.school, deck.style])
	if deck.relic_id != "":
		var relic: CardDef = library.defs.get(deck.relic_id)
		if relic == null or relic.type != CardDef.Type.RELIC:
			problems.append("Relic '%s' not found" % deck.relic_id)
		elif deck.reserve.size() > relic.reserve_size:
			problems.append("Reserve holds %d cards, Relic allows %d" % [deck.reserve.size(), relic.reserve_size])
	elif not deck.reserve.is_empty():
		problems.append("A Reserve needs a Relic")
	# Reserve cards obey the same copy limits, counted together with the Life Deck.
	for id in deck.reserve:
		var def: CardDef = library.defs.get(id)
		if def == null:
			problems.append("Unknown Reserve card '%s'" % id)
			continue
		if def.school != "" and deck.style != def.school:
			problems.append("Reserve card '%s' is %s, deck Style is %s" % [id, def.school, deck.style])
		# A Reserve swap puts these cards in the Life Deck before the first turn, so a personality
		# in the Reserve is an Ally and obeys the Ally rules like any other.
		if def.type == CardDef.Type.PERSONALITY:
			for p in ally_problems(def, deck, duelist):
				problems.append("Reserve: %s" % p)
		var combined: int = int(counts.get(id, 0)) + deck.reserve.count(id)
		var limit: int = def.limit_per_deck
		if def.type == CardDef.Type.SEAL or def.type == CardDef.Type.PERSONALITY:
			limit = 1
		elif def.character != "" and def.character == duelist.character and limit >= DEFAULT_LIMIT:
			# A card naming your Main Personality allows a fourth copy, unless the card prints a
			# limit of its own. A printed limit is the tighter rule and wins.
			limit = SIGNATURE_LIMIT
		if combined > limit:
			problems.append("'%s' x%d across deck and Reserve exceeds limit %d" % [id, combined, limit])
	return problems
