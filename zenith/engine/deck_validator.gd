class_name DeckValidator
extends RefCounted
## Deck construction rules. Returns a list of problems; empty means legal.

const MIN_CARDS: int = 50
const MAX_CARDS: int = 85
const MAX_CARDS_ROOT: int = 90
const MIN_TIERS: int = 3
const MAX_TIERS: int = 5
const SIGNATURE_LIMIT: int = 4


static func validate(deck: DeckList, library: CardLibrary) -> Array[String]:
	var problems: Array[String] = []
	var fighter: CardDef = library.defs.get(deck.fighter_id)
	if fighter == null or fighter.type != CardDef.Type.FIGHTER:
		problems.append("Fighter '%s' not found" % deck.fighter_id)
		return problems
	if deck.tiers < MIN_TIERS or deck.tiers > MAX_TIERS:
		problems.append("Fighter must run %d to %d tiers" % [MIN_TIERS, MAX_TIERS])
	if deck.tiers > fighter.highest_tier():
		problems.append("Fighter only has %d tiers" % fighter.highest_tier())
	var max_cards: int = MAX_CARDS_ROOT if deck.focus == "root" else MAX_CARDS
	var total: int = deck.total_cards()
	if total < MIN_CARDS or total > max_cards:
		problems.append("Deck has %d cards, needs %d to %d" % [total, MIN_CARDS, max_cards])

	var counts: Dictionary = {}
	var token_sets: Dictionary = {}
	var styled_seen: bool = false
	for id in deck.cards:
		var def: CardDef = library.defs.get(id)
		if def == null:
			problems.append("Unknown card '%s'" % id)
			continue
		counts[id] = int(counts.get(id, 0)) + 1
		if def.type == CardDef.Type.FIGHTER or def.type == CardDef.Type.MASTERY or def.type == CardDef.Type.MASTER:
			problems.append("'%s' cannot be in the Life Deck" % id)
		if def.guild != "":
			styled_seen = true
			if deck.focus != "" and deck.focus != def.guild:
				problems.append("'%s' is %s, deck Focus is %s" % [id, def.guild, deck.focus])
		if def.type == CardDef.Type.TOKEN:
			token_sets[def.token_set] = true
		if def.type == CardDef.Type.ALLY:
			if def.character == fighter.character:
				problems.append("Ally '%s' is the same character as the Fighter" % id)
			if def.alignment_only != "" and def.alignment_only != deck.alignment:
				problems.append("Ally '%s' does not match alignment %s" % [id, deck.alignment])
			if def.lowest_tier() > deck.tiers - 2:
				problems.append("Ally '%s' must be at least 2 tiers below the Fighter's highest" % id)
	for id in counts.keys():
		var def: CardDef = library.defs[id]
		var limit: int = def.limit_per_deck
		if def.type == CardDef.Type.TOKEN or def.type == CardDef.Type.ALLY:
			limit = 1
		elif def.character != "" and def.character == fighter.character:
			limit = maxi(limit, SIGNATURE_LIMIT)
		if int(counts[id]) > limit:
			problems.append("'%s' x%d exceeds limit %d" % [id, counts[id], limit])
	if token_sets.size() > 1:
		problems.append("Only one Token set per deck")
	if deck.focus != "" and deck.focus != "freestyle" and not styled_seen:
		problems.append("Focus %s needs at least one %s card" % [deck.focus, deck.focus])
	if deck.focus == "freestyle" and styled_seen:
		problems.append("Freestyle Focus allows no guild cards")
	if deck.focus != "" and deck.mastery_id == "":
		problems.append("A Focus needs a Mastery")
	if deck.mastery_id != "":
		var mastery: CardDef = library.defs.get(deck.mastery_id)
		var wanted_guild: String = "" if deck.focus == "freestyle" else deck.focus
		if mastery == null or mastery.type != CardDef.Type.MASTERY:
			problems.append("Mastery '%s' not found" % deck.mastery_id)
		elif deck.focus == "":
			problems.append("Mastery requires a Focus")
		elif mastery.guild != wanted_guild:
			problems.append("Mastery guild '%s' does not match Focus %s" % [mastery.guild, deck.focus])
	if deck.master_id != "":
		var master: CardDef = library.defs.get(deck.master_id)
		if master == null or master.type != CardDef.Type.MASTER:
			problems.append("Master '%s' not found" % deck.master_id)
		elif deck.armory.size() > master.armory_size:
			problems.append("Armory holds %d cards, Master allows %d" % [deck.armory.size(), master.armory_size])
	elif not deck.armory.is_empty():
		problems.append("An Armory needs a Master")
	# Armory cards obey the same copy limits, counted together with the Life Deck.
	for id in deck.armory:
		var def: CardDef = library.defs.get(id)
		if def == null:
			problems.append("Unknown Armory card '%s'" % id)
			continue
		if def.guild != "" and deck.focus != "" and deck.focus != def.guild:
			problems.append("Armory card '%s' is %s, deck Focus is %s" % [id, def.guild, deck.focus])
		var combined: int = int(counts.get(id, 0)) + deck.armory.count(id)
		var limit: int = def.limit_per_deck
		if def.type == CardDef.Type.TOKEN or def.type == CardDef.Type.ALLY:
			limit = 1
		elif def.character != "" and def.character == fighter.character:
			limit = maxi(limit, SIGNATURE_LIMIT)
		if combined > limit:
			problems.append("'%s' x%d across deck and Armory exceeds limit %d" % [id, combined, limit])
	return problems
