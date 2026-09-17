class_name DeckValidator
extends RefCounted
## Deck construction rules. Returns a list of problems; empty means legal.

const MIN_CARDS: int = 50
const MAX_CARDS: int = 85
const MAX_CARDS_ROOT: int = 90
const MIN_ASPECTS: int = 3
const MAX_ASPECTS: int = 5
const SIGNATURE_LIMIT: int = 4


static func validate(deck: DeckList, library: CardLibrary) -> Array[String]:
	var problems: Array[String] = []
	var duelist: CardDef = library.defs.get(deck.duelist_id)
	if duelist == null or duelist.type != CardDef.Type.DUELIST:
		problems.append("Duelist '%s' not found" % deck.duelist_id)
		return problems
	if deck.aspects < MIN_ASPECTS or deck.aspects > MAX_ASPECTS:
		problems.append("Duelist must run %d to %d aspects" % [MIN_ASPECTS, MAX_ASPECTS])
	if deck.aspects > duelist.highest_aspect():
		problems.append("Duelist only has %d aspects" % duelist.highest_aspect())
	# A deck may go unlabelled, but a label has to be one the game knows how to show.
	if deck.archetype != "" and not Archetype.known(deck.archetype):
		problems.append("Unknown archetype '%s'" % deck.archetype)
	for s in deck.subthemes:
		if not Archetype.SUBTHEMES.has(s):
			problems.append("Unknown subtheme '%s'" % s)
	if deck.difficulty != "" and not Archetype.DIFFICULTIES.has(deck.difficulty):
		problems.append("Unknown difficulty '%s'" % deck.difficulty)
	var max_cards: int = MAX_CARDS_ROOT if deck.style == "root" else MAX_CARDS
	var total: int = deck.total_cards()
	if total < MIN_CARDS or total > max_cards:
		problems.append("Deck has %d cards, needs %d to %d" % [total, MIN_CARDS, max_cards])

	var counts: Dictionary = {}
	var seal_sets: Dictionary = {}
	var styled_seen: bool = false
	for id in deck.cards:
		var def: CardDef = library.defs.get(id)
		if def == null:
			problems.append("Unknown card '%s'" % id)
			continue
		counts[id] = int(counts.get(id, 0)) + 1
		if def.type == CardDef.Type.DUELIST or def.type == CardDef.Type.MASTERY or def.type == CardDef.Type.RELIC:
			problems.append("'%s' cannot be in the Life Deck" % id)
		if def.school != "":
			styled_seen = true
			if deck.style != def.school:
				problems.append("'%s' is %s, deck Style is %s" % [id, def.school, deck.style])
		if def.type == CardDef.Type.SEAL:
			seal_sets[def.seal_set] = true
		if def.type == CardDef.Type.ALLY:
			if def.character == duelist.character:
				problems.append("Ally '%s' is the same character as the Duelist" % id)
			if def.alignment_only != "" and def.alignment_only != deck.alignment:
				problems.append("Ally '%s' does not match alignment %s" % [id, deck.alignment])
			if def.lowest_aspect() > deck.aspects - 2:
				problems.append("Ally '%s' must be at least 2 aspects below the Duelist's highest" % id)
	for id in counts.keys():
		var def: CardDef = library.defs[id]
		var limit: int = def.limit_per_deck
		if def.type == CardDef.Type.SEAL or def.type == CardDef.Type.ALLY:
			limit = 1
		elif def.character != "" and def.character == duelist.character:
			limit = maxi(limit, SIGNATURE_LIMIT)
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
		if def.type == CardDef.Type.SEAL or def.type == CardDef.Type.ALLY:
			limit = 1
		elif def.character != "" and def.character == duelist.character:
			limit = maxi(limit, SIGNATURE_LIMIT)
		if combined > limit:
			problems.append("'%s' x%d across deck and Reserve exceeds limit %d" % [id, combined, limit])
	return problems
