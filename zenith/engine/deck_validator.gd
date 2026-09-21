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


## Where an Ally may sit. A tier 1 card is always legal (house rule 2026-09-20: a personality that
## never climbs cannot outgrow any Duelist, and the gap would otherwise ban every following from a
## shallow deck, which the adventure starters need). Anything above it must sit at least two
## Aspects below the Duelist's highest.
static func ally_aspect_allowed(aspect: int, duelist_aspects: int) -> bool:
	return aspect <= 1 or aspect <= duelist_aspects - 2


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
	var ally_aspects: Dictionary = {}   # character -> {aspect: true} among the Life Deck personalities
	for id in deck.cards:
		var pdef: CardDef = library.defs.get(id)
		if pdef != null and pdef.type == CardDef.Type.PERSONALITY:
			if not ally_aspects.has(pdef.character):
				ally_aspects[pdef.character] = {}
			(ally_aspects[pdef.character] as Dictionary)[pdef.aspect] = true
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
		# A personality in the Life Deck is an Ally. There is no Ally card type: the deck names
		# one personality as its Duelist and every other one it runs fights as an Ally.
		if def.type == CardDef.Type.PERSONALITY:
			if def.character == duelist.character:
				problems.append("Ally '%s' is the same character as the Duelist" % id)
			if def.alignment_only != "" and def.alignment_only != deck.alignment:
				problems.append("Ally '%s' does not match alignment %s" % [id, deck.alignment])
			if not ally_aspect_allowed(def.aspect, deck.aspects):
				problems.append("Ally '%s' must be at least 2 aspects below the Duelist's highest" % id)
			# An Ally climbs by overlaying its next Aspect off the top of the Life Deck's own
			# copy, so a higher Aspect is dead weight without every Aspect under it. This is the
			# printed game's behaviour and what DuelEngine._can_place already enforces in play.
			if def.aspect > 1 and not (ally_aspects[def.character] as Dictionary).has(def.aspect - 1):
				problems.append("Ally '%s' needs Aspect %d of %s in the deck too"
					% [id, def.aspect - 1, def.character])
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
