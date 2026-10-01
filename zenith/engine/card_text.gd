class_name CardText
extends RefCounted
## Human-readable text for cards, prompts, and the log. Pure functions over engine data.

const SCHOOL_NAMES: Dictionary = {
	"": "Freestyle", "pyre": "Pyre", "tide": "Tide", "storm": "Storm",
	"shade": "Shade", "steel": "Steel", "root": "Root",
}
## Display word per `CardDef.card_group()`. Signature is a group beside the schools, not one of
## them, so it gets its own word wherever a school word is printed on a card.
const GROUP_NAMES: Dictionary = {
	"freestyle": "Freestyle", "signature": "Signature", "pyre": "Pyre", "tide": "Tide",
	"storm": "Storm", "shade": "Shade", "steel": "Steel", "root": "Root",
	"personality": "Personality", "relic": "Relic", "seal": "Seal", "grounds": "Grounds",
}
const TYPE_LABELS: Dictionary = {
	CardDef.Type.PERSONALITY: "Personality", CardDef.Type.STRIKE: "Strike",
	CardDef.Type.ART: "Art", CardDef.Type.COMBAT: "Combat", CardDef.Type.NON_COMBAT: "Non-Combat",
	CardDef.Type.DRILL: "Drill", CardDef.Type.SEAL: "Seal", CardDef.Type.GROUNDS: "Grounds",
	CardDef.Type.MASTERY: "Mastery", CardDef.Type.RELIC: "Relic",
}
const FORBID_TEXT: Dictionary = {
	"strike_attacks": "perform Strikes", "art_attacks": "perform Arts", "combat_cards": "use Combat cards",
	"strike_attack_cards": "perform Strikes from cards", "art_attack_cards": "perform Arts from cards",
	"strike_cards": "use Strike cards", "art_cards": "use Art cards", "powers": "use Powers",
	"mastery": "use a Mastery", "drills": "use Drills", "non_combats": "use Non-Combat cards",
	"end_combat": "use cards that end Combat", "stop_all": "use cards that stop all attacks",
	"seals": "place Seals", "non_attack_actions": "do anything but attack or pass in their attack phase",
	"skip_combat": "skip declaring Combat", "allies": "place Allies",
	"lower_aspect": "use cards that lower your Aspect",
	"relic": "use a Relic",
	"lower_own_aspect": "use cards that lower your own Aspect",
}
const FLOAT_TEXT: Dictionary = {
	"no_prevent": "damage from your attacks cannot be prevented",
	"prevent_all": "all damage from attacks against you is prevented",
	"make_focused": "your attacks are Focused",
	"after_use_bottom": "your school attacks go to the bottom of your Life Deck after use",
	"damage_removes": "wounds from your attacks are removed from the game",
	"no_gain": "your opponent's duelist and Allies cannot gain Energy",
	"no_ally_control": "your opponent's Allies cannot take control or take damage",
	"no_ally_takeover": "your opponent's Allies cannot take control of Combat",
	"life_for_art_costs": "you may take a wound instead of paying costs for any Arts this personality performs",
	"keep_hand": "you keep your hand through the Discard step",
	"endurance_boost": "your next Endurance prevents all remaining damage",
	"no_endurance": "your opponent cannot use Endurance",
	"stop_next": "the next attack against you is stopped",
	"prevent_art_life": "Arts against you deal no wounds",
	"prevent_strike_damage": "Strikes against you deal no damage",
	"fervor_hits_secondary": "your Hit lines that Attune or Disrupt happen whether or not the attack succeeds",
}


## Keywords: regex over the generated wording, colour role, hover tooltip. Longer phrases first.
const KEYWORDS: Array[Dictionary] = [
	{"key": "Remove from the game after use", "pattern": "\\bRemove from the game after use\\b", "role": "removed",
		"tip": "After this card is used it is set aside for the rest of the duel. It does not go to the discard pile and nothing can bring it back."},
	{"key": "from the game", "pattern": "\\b(?:removes?|removed|Remove)\\b[^.]*?\\bfrom the game\\b", "role": "removed",
		"tip": "A card removed from the game is set aside for the rest of the duel. It is not in the discard pile and cannot be recovered or shuffled back."},
	{"key": "Remain", "pattern": "\\bRemain \\d+\\b", "role": "focus",
		"tip": "Remain N: after it resolves, the card stays on the table and can be performed N more times this Combat. It leaves at the end of Combat."},
	{"key": "Hit", "pattern": "\\bHit[:,]", "role": "attack",
		"tip": "Hit: happens only if the attack is successful, meaning it was not stopped and dealt its damage."},
	{"key": "Cannot be stopped", "pattern": "\\b[Cc]annot be stopped(?: by \\w+ cards)?", "role": "attack",
		"tip": "No defense can stop this attack. It still does damage the normal way, so Endurance and prevention still apply unless the card says otherwise."},
	{"key": "cannot be prevented", "pattern": "\\b[Dd]amage(?: from [^.]*?)? cannot be prevented", "role": "attack",
		"tip": "Endurance, prevention effects, and any 'no damage' effect do nothing against this damage."},
	{"key": "Defense Shield", "pattern": "\\bDefense Shield\\b", "role": "defense",
		"tip": "A standing defense on a duelist or Drill: it stops the first unstopped attack of the named kind each Combat without spending a card. Unless a card says otherwise, a Focused attack sets it off but is not stopped by it."},
	{"key": "Strike Table", "pattern": "\\bStrike Table\\b", "role": "might",
		"tip": "The table that turns both duelists' Might into a Strike's base damage. The gap between Might bands sets how much Energy a plain Strike takes."},
	{"key": "Seal", "pattern": "\\bSeals?\\b", "role": "seal",
		"tip": "A mark carved into the gate, seven to a set, one set for each Eidolon. Carving all seven of one set opens the gate and wins the duel. A captured Seal changes hands."},
	{"key": "Non-Combat", "pattern": "\\bNon-Combat(?: cards?| step)?\\b", "role": "non_combat",
		"tip": "A card placed during your Non-Combat step that stays in play until something discards it. Drills are Non-Combat cards."},
	{"key": "Combat card", "pattern": "\\bCombat cards?\\b", "role": "combat",
		"tip": "A hand card played during Combat that is neither an attack nor a plain defense. Some cards can cancel a Combat card as it is played."},
	{"key": "Signature", "pattern": "\\bSignature cards?\\b", "role": "plain",
		"tip": "A card with a personality's name in its title. A deck may run four copies of one named for its own duelist, and searches for Signature cards find these. Only an \"X only\" line limits who may use it."},
	{"key": "Life Deck", "pattern": "\\bLife Deck\\b", "role": "zone",
		"tip": "Your draw pile and your duelist's health. Every wound discards its top card. Running out of cards loses the duel."},
	{"key": "discard pile", "pattern": "\\bdiscard pile\\b", "role": "zone",
		"tip": "Where used cards and wounds go. Cards here can be recovered by effects; cards removed from the game cannot."},
	{"key": "in control", "pattern": "\\b(?:in control|takes? control|take control of Combat)\\b", "role": "ally",
		"tip": "The personality fighting for you this Combat. Your duelist has control unless an Ally steps in, which an Ally may do while your duelist is at Energy 0 or 1."},
	{"key": "Vigil only", "pattern": "\\b(?:Vigil|Pact) only\\b", "role": "plain",
		"tip": "Only a duelist sworn to that side may include and use this card."},
	{"key": "Limit", "pattern": "\\bLimit \\d+ per deck\\b", "role": "plain",
		"tip": "The most copies of this card a deck may hold, Life Deck and Reserve together."},
	{"key": "Endurance", "pattern": "\\bEndurance(?: \\d+| X)?\\b", "role": "defense",
		"tip": "When this card is discarded as a wound, it soaks that many further wounds from the same attack."},
	{"key": "Empower", "pattern": "\\bEmpower(?:ed)?(?: \\d+)?\\b", "role": "focus",
		"tip": "You may perform this attack Empowered: it deals that many extra wounds, but the text printed after Empower is lost for that attack."},
	{"key": "Focused", "pattern": "\\bFocused\\b", "role": "attack",
		"tip": "A Focused attack pierces \"Stops any attack\", any stop-all that covers every attack, and any effect that prevents the damage of every attack. A stop aimed at Strikes only or Arts only still stops it, as does one that says it can stop a Focused attack."},
	{"key": "Constant", "pattern": "\\bConstant:", "role": "plain",
		"tip": "Always in effect while this personality is in control of Combat, unless it says otherwise. It needs no action. Anything that forbids Powers turns it off too."},
	{"key": "Power", "pattern": "\\bPowers?\\b", "role": "plain",
		"tip": "The personality's own action, usable once per Combat unless it says otherwise. It follows the same rules as a card of its kind."},
	{"key": "Energy", "pattern": "\\bEnergy\\b", "role": "energy",
		"tip": "A duelist's stamina, 0 to 10. Strikes deal their damage to Energy first and Arts cost Energy to perform. At 0 the duelist is spent: damage becomes wounds and an Ally may step in."},
	{"key": "Might", "pattern": "\\bMight\\b", "role": "might",
		"tip": "How hard a duelist hits at their current Energy. The Strike Table compares both duelists' Might to set a Strike's base damage."},
	{"key": "Surge", "pattern": "\\bSurge(?: Rate)?\\b", "role": "energy",
		"tip": "In the Power Up step each turn, your duelist gains Energy equal to their Surge Rate plus 1."},
	{"key": "Fervor", "pattern": "\\bFervor\\b", "role": "fervor",
		"tip": "The heat of the duel. When it reaches the mark, 5 unless a card says otherwise, the duelist ascends one Aspect, Energy refills, and Fervor starts again at 0."},
	{"key": "Ascension", "pattern": "\\bAscension\\b", "role": "ascension",
		"tip": "The climb through a duelist's Aspects as they attune to the site. Ascending refills Energy and discards your Drills. Filling Fervor at the top Aspect wins by Ascension."},
	{"key": "aspect", "pattern": "\\b[Aa]spects? \\d\\b|\\bAspects?\\b", "role": "ascension",
		"tip": "One of a duelist's forms, each with its own title. Every duel starts at the first Aspect."},
	{"key": "wounds", "pattern": "\\bwounds?\\b", "role": "attack",
		"tip": "Damage to the Life Deck. Each wound discards the top card of the Life Deck; a duelist with no cards left yields."},
	{"key": "Strike", "pattern": "\\bStrikes?\\b", "role": "strike",
		"tip": "A physical attack. Its base damage comes from the Strike Table and hits Energy first; anything past 0 Energy becomes wounds."},
	{"key": "Art", "pattern": "\\bArts?\\b", "role": "art",
		"tip": "A woven technique. Costs 2 Energy to perform unless the card says otherwise, and its damage is dealt as wounds."},
	{"key": "Drill", "pattern": "\\bDrills?\\b", "role": "drill",
		"tip": "Training kept in play as a Non-Combat card. All of your Drills are discarded whenever your duelist gains or loses an Aspect."},
	{"key": "Ally", "pattern": "\\bAll(?:y|ies)\\b", "role": "ally",
		"tip": "A companion in play. An Ally can take control of Combat when your duelist is spent, take a wound in the duelist's place, and use its own Power."},
	{"key": "Grounds", "pattern": "\\bGrounds(?: cards?)?\\b", "role": "grounds",
		"tip": "The place of power this duel is over. Only one Grounds card is in play at a time; placing one replaces the last and skips Combat that turn."},
	{"key": "Reserve", "pattern": "\\bReserve\\b", "role": "relic",
		"tip": "Your Relic's side deck. At setup you may swap cards from it into your Life Deck, one for one, before the shuffle."},
	{"key": "Mastery", "pattern": "\\bMaster(?:y|ies)\\b", "role": "mastery",
		"tip": "Your school's standing bonus, in play from the first turn. Every deck carries one, and its school is the deck's Style."},
	{"key": "Bond", "pattern": "\\bBond(?:ing|ed)?(?: card)?\\b", "role": "plain",
		"tip": "Two named Allies fold under one Bond card and fight as one at full Energy. A life card goes under it at the start of each of your turns; at five the Bond ends and both Allies return."},
	{"key": "repeat the attack it stopped", "pattern": "\\brepeat the attack it stopped\\b", "role": "defense",
		"tip": "The copy is performed in your next attack phase. If that phase is skipped, the copy is lost. If the stopped card stays on the table to be used again, you may repeat it once more this Combat."},
	{"key": "Stops", "pattern": "\\b[Ss]tops?\\b|\\bstopped\\b", "role": "defense",
		"tip": "A stopped attack deals no damage and none of its 'if successful' text happens. Its other effects still resolve."},
	{"key": "Attune", "pattern": "\\bAttune \\d+\\b", "role": "fervor",
		"tip": "Attune N: raise your Fervor N."},
	{"key": "Disrupt", "pattern": "\\bDisrupt \\d+\\b", "role": "fervor",
		"tip": "Disrupt N: lower your opponent's Fervor N."},
]


## 4500000 -> "4.5M", 850000 -> "850k".
static func short_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 1000:
		return "%dk" % int(n / 1000)
	return str(n)


## What to call a personality card: the character's name, and nothing else. Each Aspect is its own
## card now (2026-09-21), so the card face already prints the Aspect title as the subtitle and the
## line word (`variant`) would only be a third name in the same breath. Bram Ashmark's shared
## tier 1 carries no variant at all, so folding the line into the name made one rung of a stack
## read differently from its neighbours. The line is shown where it tells two cards apart instead:
## `rung_label` in a stack view, and `personality_line` in the deck detail.
static func personality_name(def: CardDef) -> String:
	if def == null:
		return ""
	return def.title


## The line a personality card was written for ("the Glut"), or "" when the card belongs to no one
## line. Only a view that lists several cards of one character prints it.
static func personality_line(def: CardDef) -> String:
	return def.variant if def != null else ""


## The title printed on one Aspect card ("Starved"), falling back to its number. `def` is the card
## for that Aspect; `stack_aspect_name` finds it when all you hold is the stack.
static func aspect_name(aspect: int, def: CardDef = null) -> String:
	if def != null and def.aspect_title != "":
		return def.aspect_title
	return "Aspect %d" % aspect


static func stack_aspect_name(aspect: int, stack: PersonalityStack) -> String:
	return aspect_name(aspect, stack.def_for(aspect) if stack != null else null)


## True when a stack climbs through more than one of a character's printed lines, which is the one
## case where a rung has to say where it came from. A card two lines share carries no variant, so
## it never makes a stack read as mixed on its own.
static func stack_mixes_lines(stack: PersonalityStack) -> bool:
	if stack == null:
		return false
	var seen: Array[String] = []
	for d in stack.defs:
		if d.variant != "" and not seen.has(d.variant):
			seen.append(d.variant)
	return seen.size() > 1


## One rung of a stack, for a ladder chip or a deck-detail row: "1 · Starved". With `show_line`
## the printed line follows where the card names one, "2 · Leeching · the Hollow", which is what
## tells two cards of one character at one tier apart. A one-line stack passes false and stays
## quiet, and so does the tier a character's lines share.
static func rung_label(def: CardDef, show_line: bool = false) -> String:
	if def == null:
		return ""
	var label: String = "%d · %s" % [def.aspect, aspect_name(def.aspect, def)]
	if show_line and def.variant != "":
		label += " · %s" % def.variant
	return label


## Every rung of a stack, lowest first, each labelled by `rung_label`. The line word appears on
## all of them or on none, so one call decides it for the whole ladder.
static func stack_rungs(stack: PersonalityStack) -> Array[String]:
	var out: Array[String] = []
	if stack == null:
		return out
	var show_line: bool = stack_mixes_lines(stack)
	for d in stack.defs:
		out.append(rung_label(d, show_line))
	return out


## Which of a prompt's options need a side marker, as card uid -> " · yours" / " · theirs".
## Both players may field a personality of one title since 2026-09-21, so two options in one row
## can read the same. Only options that share a label are marked, and only where the option
## carries an owner, which `OptionView` fills in for cards on the table and leaves at -1 for a
## card in a hand, a Life Deck or a Reserve. `viewer` is the seat reading the row.
static func option_side_marks(p: PromptView, viewer: int) -> Dictionary:
	var seats_by_label: Dictionary = {}
	for opt in p.options:
		if opt.card < 0 or opt.owner < 0:
			continue
		var seats: Array = seats_by_label.get(opt.label, [])
		if not seats.has(opt.owner):
			seats.append(opt.owner)
		seats_by_label[opt.label] = seats
	var out: Dictionary = {}
	for opt in p.options:
		if opt.card < 0 or opt.owner < 0:
			continue
		if (seats_by_label[opt.label] as Array).size() < 2:
			continue
		out[opt.card] = " · yours" if opt.owner == viewer else " · theirs"
	return out


## Short HUD wording for a standing forbid, keyed by the engine's forbid `what` word.
const RESTRICTION_NAMES: Dictionary = {
	"strike_attacks": "No Strike attacks", "art_attacks": "No Art attacks", "strike_cards": "No Strike cards",
	"strike_attack_cards": "No Strike cards to attack", "art_attack_cards": "No Art cards to attack",
	"art_cards": "No Art cards", "combat_cards": "No Combat cards", "non_combats": "No Non-Combats",
	"drills": "No Drills", "seals": "No Seals", "mastery": "Mastery silenced", "powers": "Powers silenced",
	"stop_all": "Cannot stop every attack", "end_combat": "Cannot end Combat",
	"non_attack_actions": "Attacks only", "skip_combat": "Must declare Combat", "allies": "No Allies",
}


static func restriction_name(what: String) -> String:
	return str(RESTRICTION_NAMES.get(what, what.capitalize()))


static func school_name(school: String) -> String:
	return str(SCHOOL_NAMES.get(school, school.capitalize()))


## The word for a card group id: "Pyre", "Freestyle", "Signature".
static func group_name(group: String) -> String:
	return str(GROUP_NAMES.get(group, school_name(group)))


## The group word for a card: "Signature" where the school word would otherwise say "Freestyle".
static func card_group_name(def: CardDef) -> String:
	return group_name(def.card_group())


## The group word plus, for a Signature card, whose it is: "Signature · Bram Ashmark". A handful
## of Signature cards also carry a school. The class wins, so the line still leads with Signature,
## and the school follows as a secondary mark, since it is what makes the card Steel-only in deck
## construction: "Signature · Halden Quarr · Steel".
static func card_group_line(def: CardDef) -> String:
	if not def.is_signature():
		return card_group_name(def)
	var line: String = "Signature · %s" % def.character
	return line if def.school == "" else "%s · %s" % [line, school_name(def.school)]


static func type_label(def: CardDef) -> String:
	return str(TYPE_LABELS.get(def.type, "Card"))


static func type_line(def: CardDef) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(card_group_line(def))
	parts.append(type_label(def))
	if def.bloodline != "":
		# The reference game left this in a rulebook table and never printed it on the card, which
		# is exactly why nobody could see it. It goes on the type line here.
		parts.append(bloodline_name(def.bloodline))
	if def.alignment_only != "":
		parts.append(def.alignment_only.capitalize() + "s only")
	return " · ".join(parts)


static func bloodline_name(bloodline: String) -> String:
	return bloodline.capitalize()


## A keyword a personality carries, as a card says it: "Construct", "Marked".
static func keyword_name(tag: String) -> String:
	return tag.capitalize()


## A side, as a card names it: "a Vigil duelist", "a Pact duelist".
static func alignment_name(alignment: String) -> String:
	return "a %s duelist" % alignment.capitalize()


## The side of Combat a card asks about, in the printed words: the player who declared Combat
## enters it as the attacker, the other as the defender, whichever way the data spells it.
static func role_name(role: String) -> String:
	if role == "active" or role == "attacker":
		return "attacker"
	if role == "opposing" or role == "defender":
		return "defender"
	return role


## Who a card's "X only" gate lets play it, without the trailing "only". An `any_of` gate lists
## each way in, because a card that names a side and two personalities allows all three.
static func gate_text(gate: Dictionary) -> String:
	if gate.has("any_of"):
		var ways: PackedStringArray = PackedStringArray()
		for sub in gate["any_of"]:
			var one: String = gate_text(sub)
			if one != "":
				ways.append(one)
		if ways.is_empty():
			return ""
		if ways.size() == 1:
			return ways[0]
		return "%s and %s" % [", ".join(ways.slice(0, ways.size() - 1)), ways[ways.size() - 1]]
	if gate.has("alignment"):
		return str(gate["alignment"]).capitalize() + "s"
	if gate.has("character"):
		return str(gate["character"])
	if gate.has("duelist_character"):
		return str(gate["duelist_character"])
	if gate.has("bloodline"):
		return bloodline_name(str(gate["bloodline"]))
	if gate.has("tag"):
		return keyword_name(str(gate["tag"]))
	return ""


## card_type -> [singular, plural].
const CARD_TYPE_WORDS: Dictionary = {
	"card": ["card", "cards"], "ally": ["Ally", "Allies"], "drill": ["Drill", "Drills"],
	"non_combat_any": ["Non-Combat card, Drill, or Seal", "Non-Combat cards, Drills, or Seals"],
	"non_combat_or_drill": ["Non-Combat card or Drill", "Non-Combat cards or Drills"],
	"non_combat": ["Non-Combat card", "Non-Combat cards"], "non_combat_only": ["Non-Combat card", "Non-Combat cards"],
	"non_combat_card": ["Non-Combat card", "Non-Combat cards"],
	# A printed band always reads "X card"; the bare "Strike" and "Art" are kept for the attack
	# itself ("Stops a Strike"). A Strike card need not perform a Strike, and a block is one too.
	"combat": ["Combat card", "Combat cards"], "strike": ["Strike card", "Strike cards"], "art": ["Art card", "Art cards"],
	"attack": ["attack card", "attack cards"], "hand_combat": ["Strike, Art, or Combat card", "Strike, Art, or Combat cards"],
	"strike_or_art": ["Strike or Art card", "Strike or Art cards"],
	"seal": ["Seal", "Seals"], "grounds": ["Grounds card", "Grounds cards"],
	"drill_or_ally": ["Drill or Ally", "Drills or Allies"], "non_combat_or_ally": ["Non-Combat card or Ally", "Non-Combat cards or Allies"],
	"non_combat_ally_or_grounds": ["Non-Combat card, Ally, or Grounds", "Non-Combat cards, Allies, or Grounds"],
	"freestyle_drill": ["Freestyle Drill", "Freestyle Drills"], "duelist": ["Duelist", "Duelists"], "mastery": ["Mastery", "Masteries"],
	"attached": ["attached card", "attached cards"],
	"attached_to_duelist": ["card attached to your duelist", "cards attached to your duelist"],
}


static func _who(e: Dictionary) -> String:
	match str(e.get("who", "self")):
		"opponent":
			return "your opponent"
		"attacker":
			return "the attacker"
		"defender":
			return "the defender"
		_:
			return "you"


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


## Mid-sentence case; keyword labels keep their capital.
static func _lc(s: String) -> String:
	if s.begins_with("Remain ") or s.begins_with("Hit") or s.begins_with("Attune ") or s.begins_with("Disrupt "):
		return s
	return s.substr(0, 1).to_lower() + s.substr(1)


static func _a(word: String) -> String:
	return ("an " if word.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + word


static func _plural(n: int, one: String, many: String) -> String:
	if n == 1:
		return _a(one)
	return "%d %s" % [n, many]


static func _conditional(when: Dictionary, body: String) -> String:
	if when.is_empty():
		return body
	return "If %s, %s" % [cond_text(when), _lc(body)]


## True when effect `e` pays from exactly the resource that condition `key` asks you to hold,
## so "if you have a card in hand, you may discard a card" says the same thing twice.
static func _spends(e: Dictionary, key: String, v: Variant) -> bool:
	var op: String = str(e.get("op", ""))
	var raw: Variant = e.get("amount", 1)
	var n: int = absi(int(raw)) if not (raw is String) else 0
	if str(e.get("who", "self")) != "self" or bool(e.get("all", false)) or n < 1:
		return false
	match key:
		"hand_min":
			return op == "discard_hand" and int(v) <= n
		"hand_school_min":
			var f: Variant = e.get("filter", "")
			var held: Dictionary = v if v is Dictionary else {}
			return op == "discard_hand" and f is Dictionary and str((f as Dictionary).get("school", "")) == str(held.get("school", "")) \
				and int(held.get("count", 1)) <= n
		"discard_min":
			var from_pile: bool = op in ["remove_discard", "draw_discard", "recover"] or (op == "search" and str(e.get("source", "")) == "discard")
			return from_pile and int(v) <= n
		"discard_has_type":
			return op == "recover" and str(e.get("card_type", "")) == str(v)
		"own_non_combats_min":
			return op == "discard_in_play" and str(e.get("card_type", "")).begins_with("non_combat") and int(v) <= n
		"reserve_min":
			return op == "remove_reserve" and int(v) <= n
		"energy_min", "duelist_energy_min":
			return op == "energy" and int(raw) < 0 and int(v) <= n
		"drill_school_in_play":
			return op == "discard_in_play" and str(e.get("card_type", "")) == "drill" and str(e.get("school", "")) == str(v)
		"allies_min":
			return op == "discard_in_play" and str(e.get("card_type", "")) == "ally" and int(v) <= n
	return false


## True when every part of a gate is a cost one of the card's effects already states.
static func _paid_by_cost(effects: Array, gate: Dictionary) -> bool:
	if gate.is_empty():
		return false
	for k in gate.keys():
		var paid: bool = false
		for e in effects:
			if _spends(e, str(k), gate[k]):
				paid = true
		if not paid:
			return false
	return true


## The condition as the card prints it: an optional cost does not also say you hold what it spends.
## The engine still checks the full condition, so the prompt never offers an empty choice.
static func _text_when(e: Dictionary) -> Dictionary:
	var when: Dictionary = e.get("when", {})
	if when.is_empty() or not bool(e.get("may", false)):
		return when
	var kept: Dictionary = {}
	for k in when.keys():
		if not _spends(e, str(k), when[k]):
			kept[k] = when[k]
	return kept


const ATTACK_WHEN_KEYS: Array[String] = ["source_school", "attack_kind", "attack_focused", "attack_only_tag"]
const ATTACK_TRIGGERS: Array[String] = ["on_attack", "on_success", "on_stopped", "on_damaged"]


## "Pyre attack that is not Focused", "Storm Art", "Marked-only attack": the attack a trigger
## waits for, built from its condition so the condition does not repeat "the attack is".
static func _attack_noun(when: Dictionary, plural: bool) -> String:
	var kind: String = str(when.get("attack_kind", ""))
	var noun: String = "Strike" if kind == "strike" else ("Art" if kind == "art" else "attack")
	var words: PackedStringArray = PackedStringArray()
	if when.has("attack_focused") and bool(when["attack_focused"]):
		words.append("Focused")
	if when.has("attack_only_tag"):
		words.append("%s-only" % keyword_name(str(when["attack_only_tag"])))
	if when.has("source_school"):
		words.append(school_name(str(when["source_school"])))
	words.append(noun + ("s" if plural else ""))
	var s: String = " ".join(words)
	if when.has("attack_focused") and not bool(when["attack_focused"]):
		s += " that are not Focused" if plural else " that is not Focused"
	return s


## [head, when] with the attack the trigger waits for folded into the head: "After a successful
## Storm Art" instead of "After a successful attack, if the attack is Storm and the attack is an Art".
static func _head_and_when(e: Dictionary) -> Array:
	var head: String = _trigger_head(e)
	var when: Dictionary = _text_when(e)
	var trigger: String = str(e.get("trigger", "secondary"))
	if not (trigger in ATTACK_TRIGGERS):
		return [head, when]
	var about: Dictionary = {}
	var rest: Dictionary = {}
	for k in when.keys():
		if str(k) in ATTACK_WHEN_KEYS:
			about[k] = when[k]
		else:
			rest[k] = when[k]
	if about.is_empty():
		return [head, when]
	match trigger:
		"on_attack":
			head = "When you perform " + _a(_attack_noun(about, false))
		"on_success":
			head = "After a successful " + _attack_noun(about, false)
		"on_stopped":
			head = "When your opponent stops one of your " + _attack_noun(about, true)
		"on_damaged":
			head = "When you take damage from " + _a(_attack_noun(about, false))
	return [head, rest]


## [prefix, keep_case] for an effect from its trigger head and condition.
static func _lead(head: String, when: Dictionary) -> Array:
	if head == "" and bool(when.get("first_power_use", false)):
		var rest: Dictionary = when.duplicate()
		rest.erase("first_power_use")
		return ["The first time you perform it each Combat, %s" % ("" if rest.is_empty() else "if %s, " % cond_text(rest)), false]
	var cond: String = "" if when.is_empty() else cond_text(when)
	if head == "":
		if cond != "":
			return ["If %s, " % cond, false]
		return ["", true]
	if head == "Hit":
		if cond != "":
			return ["Hit: If %s, " % cond, false]
		return ["Hit: ", true]
	var prefix: String = head
	if cond != "":
		prefix += (" and " if head == "If stopped" else ", if ") + cond
	return [prefix + ", ", false]


static func type_words(card_type: String, plural: bool) -> String:
	var key: String = card_type if card_type != "" else "card"
	var words: Array = CARD_TYPE_WORDS.get(key, [key.replace("_", " "), key.replace("_", " ") + "s"])
	return str(words[1 if plural else 0])


## The plural for a sweep: "all Drills and Allies", where a pick reads "Drills or Allies".
static func _all_words(card_type: String) -> String:
	return type_words(card_type, true).replace(", or ", ", and ").replace(" or ", " and ")


## "one of your opponent's Drills", "up to 2 of your opponent's Allies", "all of your opponent's
## Non-Combat cards": cards you pick from the other side of the table.
static func _theirs(e: Dictionary, card_type: String) -> String:
	var n: int = int(e.get("amount", 1))
	var plural: String = type_words(card_type, true)
	var swept: String = _all_words(card_type)
	if e.has("school"):
		plural = "%s %s" % [school_name(str(e["school"])), plural]
		swept = "%s %s" % [school_name(str(e["school"])), swept]
	if bool(e.get("all", false)):
		return "all of your opponent's %s" % swept
	if bool(e.get("up_to", false)) and n > 1:
		return "up to %d of your opponent's %s" % [n, plural]
	if n > 1:
		return "%d of your opponent's %s" % [n, plural]
	return "one of your opponent's %s" % plural


static func _count_of(e: Dictionary, card_type: String) -> String:
	var n: int = int(e.get("amount", 1))
	if bool(e.get("all", false)):
		return "all " + _all_words(card_type)
	if bool(e.get("up_to", false)):
		return "up to %s" % _plural(n, type_words(card_type, false), type_words(card_type, true)).trim_prefix("a ").trim_prefix("an ")
	return _plural(n, type_words(card_type, false), type_words(card_type, true))


## Rules text generated from the definition when the card has none of its own.
static func rules_text(def: CardDef) -> String:
	if def.text != "":
		return def.text
	var lines: PackedStringArray = PackedStringArray()
	if not def.only.is_empty():
		var gate: String = gate_text(def.only)
		if gate != "":
			lines.append("%s only." % gate)
		# A price to use, not a restriction on who may: worded as the cost it is.
		if def.only.has("energy_min"):
			lines.append("Your duelist must have %d Energy to use this." % int(def.only["energy_min"]))
		if def.only.has("duelist_pays"):
			lines.append("Your duelist pays %d Energy to use this card." % int(def.only["duelist_pays"]))
		# A gate on the state of the duel rather than on who is holding the card. A gate that only
		# says you hold what the card's own cost spends is left to the cost line.
		if def.only.has("when") and not _paid_by_cost(def.effects, def.only["when"]):
			lines.append("Use this card only if %s." % cond_text(def.only["when"]))
		if def.only.has("allies_min") and not _paid_by_cost(def.effects, {"allies_min": def.only["allies_min"]}):
			lines.append("You must have %s in play to use this card." % _plural(int(def.only["allies_min"]), "Ally", "Allies"))
	if bool(def.raw.get("reserve_only", false)):
		lines.append("Reserve only.")
	if str(def.raw.get("endurance_from", "")) == "fervor":
		lines.append("Endurance X. X = your Fervor.")
	elif def.endurance > 0 and def.endurance_when.is_empty():
		lines.append("Endurance %d." % def.endurance)
	elif not def.endurance_when.is_empty():
		lines.append("Endurance X. X = %d if %s, otherwise %d." % [int(def.endurance_when.get("then", 0)), cond_text(def.endurance_when.get("value_if", {})), int(def.endurance_when.get("else", 0))])
	if def.raw.has("deck_loss_guard"):
		lines.append("(When a card effect other than damage would take cards off the top of your Life Deck, you may discard this card from your hand to take %d fewer, to a minimum of 0.)" % int((def.raw["deck_loss_guard"] as Dictionary).get("amount", 0)))
	if def.counter == "combat":
		lines.append("Use when needed. Stops the effects of any Combat card.")
	elif bool(def.raw.get(DuelEngine.USE_WHEN_NEEDED, false)):
		lines.append("Use when needed.")
	elif def.counter == "any":
		lines.append("You may use this at any time. Stop the effect of any card other than a Seal%s. This card does not affect personalities." % (
			" and remove that card from the game" if bool(def.raw.get("counter_removes", false)) else ""))
	if str(def.raw.get("use_at", "")) == "end_of_combat":
		lines.append("Use at the end of Combat.")
	if str(def.raw.get("use_at", "")) == "ascension_win":
		lines.append("Use this card when your opponent would win by Ascension.")
	if str(def.raw.get("use_at", "")) == "successful_attack":
		lines.append("Use this card after an attack against you succeeds.")
	if str(def.raw.get("use_at", "")) == "entering_combat":
		lines.append("Use when entering Combat.")
	if str(def.raw.get("place_at", "")) == "after_damage":
		lines.append("Whenever you take damage from an attack, you may put this card into play from your hand.")
	if str(def.raw.get("use_at", "")) == "after_damage":
		var counted: String = "damage"
		match str(def.raw.get("use_after_damage", "either")):
			"stages":
				counted = "Energy damage"
			"life":
				counted = "wounds"
		lines.append("Use immediately after you take %s from an attack." % counted)
	if str(def.raw.get("use_at", "")) == "performing_attack":
		lines.append("Use when performing an attack.")
	if str(def.raw.get("use_at", "")) == "own_successful_attack":
		var after_kind: String = str(def.raw.get("use_after_kind", ""))
		lines.append("Use this card immediately after %s you perform succeeds." % [
			"an attack" if after_kind == "" else _a(after_kind.capitalize())])
	if bool(def.raw.get("banned", false)):
		lines.append("Adventure only: banned from tournament and online decks.")
	if str(def.raw.get("duelist_bloodline", "")) != "":
		lines.append("%s duelists only." % bloodline_name(str(def.raw["duelist_bloodline"])))
	var stop_with_variant: bool = false
	if def.is_attack():
		lines.append(attack_text(def.attack))
		for v in def.attack.get("variants", []):
			if not bool(v.get("after_empower", false)) and not bool(v.get("on_empower", false)):
				var variant_line: String = _conditional(v.get("when", {}), variant_text(v))
				# A stop that needs the same personality in control joins that personality's line.
				if def.is_defense() and not (v.get("when", {}) as Dictionary).is_empty() and JSON.stringify(v.get("when", {})) == JSON.stringify(def.defense.get("when", {})) \
						and int(def.defense.get("cost_hand", 0)) == 0 and str(def.defense.get("stops", "")) in ["strike", "art", "any"]:
					var what_stopped: String = {"strike": "a Strike", "art": "an Art", "any": "any attack"}[str(def.defense["stops"])]
					variant_line = "%s, and this card can stop %s instead." % [variant_line.trim_suffix("."), what_stopped]
					stop_with_variant = true
				lines.append(variant_line)
	if def.is_defense() and not stop_with_variant:
		var stop_line: String = defense_text(def.defense)
		if str(def.raw.get("use_at", "")) == "successful_attack":
			stop_line = stop_line.replace("Stops any attack.", "Stops that attack.")
		lines.append(stop_line)
	# Empower drops every line printed after it, so a line it keeps is printed before it.
	var kept_by_empower: Array = []
	var dropped_by_empower: Array = []
	var shown: Array = []
	for e in def.effects:
		# A stop-all the defense line already states is not said twice.
		if def.is_defense() and str(e.get("op", "")) == "stop_all" and str(e.get("kind", "any")) == str(def.defense.get("stop_all", "")) \
				and not e.has("when") and str(e.get("trigger", "secondary")) == "secondary":
			continue
		shown.append(e)
		if bool(e.get("after_empower", false)):
			dropped_by_empower.append(e)
		else:
			kept_by_empower.append(e)
	var effect_lines: PackedStringArray = effects_text(shown)
	if def.empower > 0 and not dropped_by_empower.is_empty() and not kept_by_empower.is_empty():
		for t in effects_text(kept_by_empower):
			lines.append(t)
		effect_lines = effects_text(dropped_by_empower)
	if def.empower > 0:
		lines.append("Empower %d." % def.empower)
		var on_empower: PackedStringArray = PackedStringArray()
		for v in def.attack.get("variants", []):
			if bool(v.get("after_empower", false)):
				lines.append(_conditional(v.get("when", {}), variant_text(v)))
			elif bool(v.get("on_empower", false)) and v.has("focused") and not bool(v["focused"]):
				on_empower.append("it is not Focused")
		if int(def.raw.get("empower_remain", 0)) > 0:
			on_empower.append("stays on the table to be used %d more times this Combat without its Empower" % int(def.raw["empower_remain"]))
		if not on_empower.is_empty():
			# Both only happen on an Empowered use, so the line says so rather than reading as always.
			var empowered_line: String = _join_and(on_empower)
			lines.append("If you Empower it, %s." % (empowered_line if empowered_line.begins_with("it ") else "it " + empowered_line))
	# A card with its own timing already said when it is used, so drop the default "Use in Combat".
	if str(def.raw.get("use_at", "")) != "" or bool(def.raw.get(DuelEngine.USE_WHEN_NEEDED, false)):
		for i in range(effect_lines.size()):
			effect_lines[i] = effect_lines[i].trim_prefix("%s: " % str(COLON_TRIGGERS["use"]))
	if def.type == CardDef.Type.RELIC and int(def.raw.get("uses_per_game", 0)) > 0 and not effect_lines.is_empty():
		var uses: int = int(def.raw["uses_per_game"])
		var often: String = "Once" if uses == 1 else ("Twice" if uses == 2 else "%d times" % uses)
		var step: String = str(def.raw.get("relic_step", "non_combat"))
		var when_used: String = "during Combat" if step == "combat" else ("at any time" if step == "any" else "during your Non-Combat step")
		effect_lines[0] = "%s per game, %s: %s" % [often, when_used, effect_lines[0]]
	# A Mastery, Drill or Grounds leads with its standing bonus, as the printed ones do.
	var standing_first: bool = def.type in [CardDef.Type.MASTERY, CardDef.Type.DRILL, CardDef.Type.GROUNDS]
	var cost_folded: bool = false
	var mod_lines: PackedStringArray = PackedStringArray()
	for m in def.modifiers:
		var md: Dictionary = m
		if str(md.get("scope", "")) == "cost" and str(md.get("kind", "any")) == "any" and not md.has("school") and not md.has("when") \
				and int(md.get("min", 0)) == 1 and int(def.raw.get("card_cost_less", 0)) == -int(md.get("stages", 0)):
			cost_folded = true
			continue
		var rolled: Dictionary = _rolled_up(md, def.modifiers)
		if bool(rolled.get("instead", false)) and md.has("when") and not md.has("school"):
			var base_at: int = -1
			for k in range(mod_lines.size()):
				if mod_lines[k] == modifier_text(_base_of(md, def.modifiers)):
					base_at = k
			if base_at >= 0:
				mod_lines[base_at] = "%s, or %s if %s." % [mod_lines[base_at].trim_suffix("."), _modifier_amount(rolled), _cond_after_or(rolled)]
				continue
		mod_lines.append(modifier_text(rolled))
	if cost_folded:
		mod_lines.append("The Energy costs of your attacks and other cards are %d less, to a minimum of 1." % int(def.raw["card_cost_less"]))
	var standing: PackedStringArray = PackedStringArray()
	if standing_first:
		standing.append_array(mod_lines)
		if def.opponent_aspect_threshold > 0:
			standing.append(_threshold_line(def))
		if bool(def.raw.get("protect_drills", false)):
			standing.append(PROTECT_DRILLS_LINE)
		if str(def.raw.get("stop_focused_school", "")) != "":
			standing.append(_stop_focused_line(def))
		lines.append_array(standing)
	for t in effect_lines:
		var said: bool = false
		for l in lines:
			if l.contains(t):
				said = true
		if said:
			continue
		# A timed effect on a card that sits attached happens while it is attached.
		if not def.attachment.is_empty() and t.begins_with("At the start of"):
			t = "While attached, " + _lc(t)
		lines.append(t)
	if not standing_first:
		lines.append_array(mod_lines)
	if def.shield != "":
		lines.append("Defense Shield: stops the first unstopped %s each Combat." % ("attack" if def.shield == "any" else def.shield.capitalize()))
	for rule in def.forbid:
		var who: String = str(rule.get("who", "all"))
		var subject: String = "Neither player may" if who == "all" else ("You may not" if who == "owner" else "Your opponent may not")
		lines.append("%s %s." % [subject, str(FORBID_TEXT.get(str(rule.get("what", "")), str(rule.get("what", ""))))])
	if not def.attachment.is_empty():
		var host: String = "the personality in control"
		# What the card calls its host once it is attached: "that duelist", "that card".
		var that_host: String = "that personality"
		match str(def.attachment.get("target", "in_control")):
			"opponent_duelist":
				host = "your opponent's duelist"
				that_host = "that duelist"
			"opponent_in_control":
				host = "the personality your opponent has in control"
			"in_control":
				host = "the personality in control"
			"opponent_non_combat":
				host = "one of your opponent's Non-Combat cards"
				that_host = "that card"
			_:
				host = "your duelist"
				that_host = "your duelist"
		var parts: PackedStringArray = PackedStringArray()
		for m in def.attachment.get("modifiers", []):
			parts.append(modifier_text(m))
		for m in def.attachment.get("host_modifiers", []):
			# The rider speaks for the personality it rides on, which is not the card's owner.
			parts.append(modifier_text(m).replace("Your attacks", "%s's attacks" % _cap(that_host)))
		if bool(def.attachment.get("waive_costs", false)):
			parts.append("Your duelist does not pay costs that other cards add. A card's own cost is still paid.")
		parts.append_array(effects_text(def.attachment.get("effects", [])))
		if bool(def.attachment.get("damage_removes", false)):
			if not parts.is_empty() and parts[parts.size() - 1].begins_with("Your ") and not parts[parts.size() - 1].trim_suffix(".").contains(". "):
				parts[parts.size() - 1] = parts[parts.size() - 1].trim_suffix(".") + " and their wounds are removed from the game."
			else:
				parts.append("Wounds from those attacks are removed from the game.")
		var attaches: bool = false
		for e in def.effects:
			if str(e.get("op", "")) == "attach":
				attaches = true
		if bool(def.attachment.get("no_prevent", false)):
			# Only while the host fights: "While that duelist is in control of Combat, ...".
			lines.append("While %s is in control of Combat, damage from your attacks cannot be prevented." % that_host)
		if bool(def.attachment.get("disables_host", false)):
			lines.append("That card cannot be used while this is attached.")
		for t in def.attachment.get("grants_tags", []):
			parts.append("They count as %s while this is attached." % keyword_name(str(t)))
		var lent_line: String = str(def.attachment.get("grants_bloodline", ""))
		if lent_line != "":
			parts.append("They count as %s while this is attached." % bloodline_name(lent_line))
		var named_host: String = ""
		for e in def.effects:
			if str(e.get("op", "")) == "attach" and str(e.get("to", "")) == "named":
				named_host = str(e.get("character", ""))
		var chosen_host: bool = false
		for e in def.effects:
			if str(e.get("op", "")) == "attach" and str(e.get("to", "")) == "choose":
				chosen_host = true
		if named_host != "" or chosen_host:
			# The host is whoever it landed on, so the line speaks of the attached personality
			# rather than naming a seat on the table. Only a modifier reads as something the host
			# owns ("your Arts do +2 wounds"); a timed effect is just a thing that happens.
			var joined: String = " ".join(parts)
			if joined.begins_with("Your "):
				lines.append("While attached, the attached personality's %s" % _lc(joined).trim_prefix("your "))
			else:
				lines.append("While attached, %s" % _lc(joined))
		elif not parts.is_empty() and attaches:
			# The attach line already named the host.
			lines.append("While attached, %s" % _lc(" ".join(parts)))
		elif not parts.is_empty():
			lines.append("While attached to %s, %s" % [host, _lc(" ".join(parts))])
		var limit_attached: int = int(def.attachment.get("limit_attached", 0))
		if limit_attached > 0 and named_host != "":
			lines.append("%s may have only %d \"%s\" attached." % [named_host, limit_attached, def.title])
		elif limit_attached > 0:
			lines.append("You may have only %d attached." % limit_attached)
		if str(def.attachment.get("duration", "")) == "combat":
			lines.append("Discard this card at the end of Combat.")
		if bool(def.attachment.get("discard_at_full", false)):
			lines.append("Discard this card when %s is at full Energy." % that_host)
	if def.remain >= 99:
		lines.append("Stays on the table to be used any number of times this Combat.")
	elif def.remain > 0:
		# When only an Ally may take the extra uses, the card keeps the printed sentence instead of
		# the Remain shorthand, which reads as the duelist's.
		var by: String = ""
		if def.raw.has("remain_by_tag"):
			by = "a %s Ally" % keyword_name(str(def.raw["remain_by_tag"]))
		elif str(def.raw.get("remain_by", "")) == "ally":
			by = "an Ally"
		if by == "":
			lines.append("Remain %d." % def.remain)
		else:
			lines.append("This card stays on the table to be used %d more %s by %s." % [def.remain, "time" if def.remain == 1 else "times", by])
	if not def.remain_when.is_empty():
		var extra: Variant = def.remain_when.get("remain", 1)
		var how_many: String = "Remain X, where X is your duelist's Aspect." if extra is String and str(extra) == "aspect" else "Remain %d." % int(extra)
		lines.append(_conditional(def.remain_when.get("when", {}), how_many))
	if def.type == CardDef.Type.RELIC:
		var flags: PackedStringArray = PackedStringArray()
		if def.reserve_size > 0:
			flags.append("Reserve %d." % def.reserve_size)
		if bool(def.relic_flags.get("no_ascension_win", false)):
			flags.append("You cannot win by Ascension.")
		if bool(def.relic_flags.get("fervor_shield", false)):
			flags.append("Your opponent cannot lower your Fervor.")
		if bool(def.relic_flags.get("aspect_shield", false)):
			flags.append("Your opponent cannot lower your Aspect.")
		for i in range(flags.size()):
			lines.insert(i, flags[i])
	if def.opponent_aspect_threshold > 0 and not standing_first:
		lines.append(_threshold_line(def))
	if bool(def.raw.get("protect_from_removal", false)):
		lines.append("While you control this, cards of yours in play that your opponent would remove from the game are discarded instead.")
	var burn: Dictionary = def.raw.get("defense_burn", {})
	if not burn.is_empty():
		var burn_school: String = str(burn.get("school", ""))
		lines.append("Instead of defending, you may remove any number of %s cards in your discard pile from the game. Prevent %d wounds from the attack for each one removed." % [
			school_name(burn_school) if burn_school != "" else "your", int(burn.get("prevent_per", 2))])
	if bool(def.raw.get("protect_drills", false)) and not standing_first:
		lines.append(PROTECT_DRILLS_LINE)
	if int(def.raw.get("card_cost_less", 0)) > 0 and not cost_folded:
		lines.append("The Energy costs of cards you use are %d less, to a minimum of 1." % int(def.raw["card_cost_less"]))
	if int(def.raw.get("surge_bonus", 0)) != 0 and def.raw.has("surge_bonus_bloodline"):
		lines.append("If your duelist is %s, their Surge Rate is %+d while this is in play." % [
			bloodline_name(str(def.raw["surge_bonus_bloodline"])), int(def.raw["surge_bonus"])])
	elif int(def.raw.get("surge_bonus", 0)) != 0:
		lines.append("Your duelist's Surge Rate is %+d while this is in play." % int(def.raw["surge_bonus"]))
	if bool(def.raw.get("shields_stop_focused", false)):
		lines.append("Your Defense Shields can stop Focused attacks.")
	if str(def.raw.get("discard_only_school", "")) != "":
		lines.append("When one of your non-%s cards would go to your discard pile, remove it from the game instead." % school_name(str(def.raw["discard_only_school"])))
	if str(def.raw.get("stop_focused_school", "")) != "" and not standing_first:
		lines.append(_stop_focused_line(def))
	if bool(def.raw.get("allies_undiscardable", false)):
		lines.append("Your Allies in play cannot be discarded.")
	if bool(def.raw.get("mill_on_empty_fervor", false)):
		lines.append("When you lower your opponent's Fervor while it is 0, they take a wound for each point lowered.")
	if bool(def.raw.get("opponent_one_non_combat", false)):
		lines.append("Your opponent may place only 1 Non-Combat card in play during their turn.")
	if int(def.raw.get("opponent_power_up_less", 0)) > 0:
		lines.append("Your opponent's personalities gain %d less Energy in the Power Up step, to a minimum of 0." % int(def.raw["opponent_power_up_less"]))
	if bool(def.raw.get("no_ascension_win", false)):
		lines.append("You cannot win by Ascension.")
	var grant: Dictionary = def.raw.get("grant_attack_lines", {})
	if not grant.is_empty() and grant.has("otherwise"):
		lines.append("Your attacks gain \"%s\"" % " ".join(effects_text(grant.get("otherwise", []))))
	if not grant.is_empty():
		var granted: PackedStringArray = effects_text(grant.get("effects", []))
		var granted_kind: String = str(grant.get("kind", ""))
		lines.append("Your %s%s gain \"%s\"%s" % [(school_name(str(grant["school"])) + " ") if str(grant.get("school", "")) != "" else "",
			"attacks" if granted_kind == "" else granted_kind.capitalize() + "s", " ".join(granted),
			" instead." if grant.has("otherwise") else ""])
	var rejuv: Dictionary = def.raw.get("recover_bonus", {})
	if not rejuv.is_empty():
		lines.append("In the Recover step, if the card you put back into your Life Deck is %s card, %s" % [
			_a(school_name(str(rejuv.get("school", "")))), _lc(_and_sentences(effects_text(rejuv.get("effects", []))))])
	var boost: Dictionary = def.raw.get("discard_boost", {})
	if not boost.is_empty():
		var boost_parts: PackedStringArray = PackedStringArray()
		if int(boost.get("stages", 0)) > 0:
			boost_parts.append("do +%d Energy" % int(boost["stages"]))
		if int(boost.get("life", 0)) > 0:
			boost_parts.append("do +%d wounds" % int(boost["life"]))
		for t in effects_text(boost.get("effects", [])):
			boost_parts.append(_lc(t).trim_suffix("."))
		var boost_kind: String = str(boost.get("kind", ""))
		lines.insert(0, "(When you perform %s, you may discard this card from your hand to have that attack %s.)" % [
			("an attack" if boost_kind == "" else _a(boost_kind.capitalize())), " and ".join(boost_parts)])
	if bool(def.raw.get("drill_lock_exempt", false)):
		lines.append("This Drill ignores the one-school limit on Drills.")
	if bool(def.raw.get("fervor_lock", false)):
		lines.append("Your Fervor cannot be lowered.")
	if def.raw.has("keeps_drills_on_advance"):
		lines.append("When your duelist advances an Aspect, your other Drills are not discarded.")
		var keeps_self: Dictionary = (def.raw["keeps_drills_on_advance"] as Dictionary).get("self_when", {})
		if not keeps_self.is_empty():
			lines.append(_conditional(keeps_self, "this Drill is not discarded either."))
	if str(def.raw.get("blocks_to_bottom", "")) != "":
		lines.append("After you stop an attack with %s card that does not remove itself from the game, place that card on the bottom of your Life Deck." % _a(school_name(str(def.raw.get("blocks_to_bottom", "")))))
	var art_boost: Dictionary = def.raw.get("art_boost", {})
	if not art_boost.is_empty():
		var more: String = "+%d %s" % [int(art_boost.get("life", 1)), "wound" if int(art_boost.get("life", 1)) == 1 else "wounds"]
		var cheaper: String = "cost %d less Energy to perform, to a minimum of 1" % -int(art_boost.get("cost", -1))
		lines.append("Arts your duelist performs do %s or %s, your choice. Your %s Arts do both instead." % [more, cheaper, school_name(str(art_boost.get("school", "")))])
	if bool(def.raw.get("once_per_turn", false)):
		lines.append("Once per turn.")
	if bool(def.raw.get("once_per_combat", false)):
		lines.append("Once per Combat.")
	if str(def.raw.get("promote_if_successful", "")) != "":
		lines.append("Hit lines on your \"%s\" attacks happen whether or not the attack succeeds." % str(def.raw["promote_if_successful"]))
	if bool(def.raw.get("discard_if_other_non_combats", false)):
		lines.append("Discard this Drill if you have any other Non-Combat card in play.")
	if str(def.raw.get("unused_return", "")) == "shuffle":
		lines.append("If used only once this Combat, shuffle it into your Life Deck at the end of Combat.")
	if not (def.raw.get("bond_of", []) as Array).is_empty():
		var names: PackedStringArray = PackedStringArray()
		for nm in def.raw["bond_of"]:
			names.append(str(nm))
		lines.append("Bond of %s. Enters play only through a Bonding card, at full Energy, with both under it. At the start of each of your turns a life card goes under it; at %d the Bond ends and both return at 3 Energy." % [" and ".join(names), int(def.raw.get("bond_timer_max", 5))])
	if bool(def.raw.get("protect_seals", false)):
		lines.append("Your Seals cannot be captured.")
	if int(def.raw.get("hand_keep", 0)) > 0:
		lines.append("You may now keep up to %d cards in your hand at the end of each turn." % int(def.raw["hand_keep"]))
	if def.raw.has("fervor_gain_cap"):
		lines.append("A card or effect that would raise a duelist's Fervor by more than %d raises it by %d. Each card raises a duelist's Fervor only once each turn." % [int(def.raw["fervor_gain_cap"]), int(def.raw["fervor_gain_cap"])])
	if str(def.raw.get("discard_if_seal", "")) != "":
		lines.append("If %s is in play, discard this card after use instead." % str(def.raw.get("discard_if_seal_title", "that Seal")))
	if int(def.raw.get("discard_if_seal_number", 0)) > 0:
		lines.append("If a Seal %d of any set is in play, discard this card after use instead." % int(def.raw["discard_if_seal_number"]))
	if bool(def.raw.get("double_costs", false)):
		lines.append("All Energy and wound costs are doubled.")
	for kind in ["strike", "art"]:
		var kind_tax: int = int(def.raw.get("%s_cost_delta" % kind, 0))
		if kind_tax > 0 and def.type == CardDef.Type.GROUNDS:
			lines.append("%ss cost %d more Energy to perform." % [("Strike" if kind == "strike" else "Art"), kind_tax])
	if def.start_in_play:
		if str(def.raw.get("start_in_play", "")) == "may":
			lines.append("Before the first turn begins, you may search your Life Deck for this card and place it into play.")
		else:
			lines.append("Begins the game in play.")
	if def.type == CardDef.Type.SEAL and lines.is_empty():
		lines.append("One of the seven %s Seals." % def.seal_set.capitalize())
	if def.type == CardDef.Type.GROUNDS and lines.is_empty():
		lines.append("Placing Grounds skips Combat this turn.")
	if def.bottom_after_use:
		lines.append("Place at the bottom of your Life Deck after use.")
	if def.raw.has("bottom_after_use_when"):
		lines.append(_conditional(def.raw["bottom_after_use_when"], "place this card at the bottom of your Life Deck after use."))
	if bool(def.raw.get("discard_after_use", false)):
		lines.append("Discard after use.")
	if def.remove_after_use:
		lines.append("Remove from the game after use.")
		if def.raw.has("discard_instead_when"):
			lines.append(_conditional(def.raw["discard_instead_when"], "discard it after use instead."))
	if def.limit_per_deck != 3:
		lines.append("Limit %d per deck." % def.limit_per_deck)
	if bool(def.raw.get("unique_in_play", false)):
		lines.append("You may have only 1 in play.")
	for i in range(lines.size() - 1, 0, -1):
		# "Use against an Art. It is not stopped, but it deals at most 1 wound."
		var capped: String = "That attack deals at most "
		if lines[i - 1].ends_with(" It is not stopped.") and lines[i].begins_with(capped):
			lines[i - 1] = "%s, but it deals at most %s" % [lines[i - 1].trim_suffix("."), lines[i].substr(capped.length())]
			lines.remove_at(i)
	return "\n".join(lines)


const PROTECT_DRILLS_LINE: String = "Your Drills cannot be discarded, even when your Aspect changes."


static func _threshold_line(def: CardDef) -> String:
	return "Your opponent needs %d Fervor to advance an Aspect." % def.opponent_aspect_threshold


static func _stop_focused_line(def: CardDef) -> String:
	return "Your non-Drill %s cards that can stop attacks can also stop Focused attacks." % school_name(str(def.raw["stop_focused_school"]))


## The plain modifier a narrower one stacks on: same scope and kind, no school, no condition.
static func _base_of(m: Dictionary, all: Array) -> Dictionary:
	for other in all:
		var o: Dictionary = other
		if not o.has("school") and not o.has("when") and str(o.get("scope", "own")) == str(m.get("scope", "own")) and str(o.get("kind", "any")) == str(m.get("kind", "any")):
			return o
	return {}


## The rolled-up total of a narrower modifier, for "..., or +2 wounds if ...".
static func _modifier_amount(m: Dictionary) -> String:
	if str(m.get("scope", "own")) == "opponent_cost":
		return "%d more" % int(m.get("stages", 0))
	var parts: PackedStringArray = PackedStringArray()
	if int(m.get("stages", 0)) != 0:
		parts.append("%+d Energy" % int(m["stages"]))
	if int(m.get("life", 0)) != 0:
		parts.append("%+d %s" % [int(m["life"]), "wound" if absi(int(m["life"])) == 1 else "wounds"])
	return " and ".join(parts)


## A modifier's condition after "or ... if": "performed by a Construct personality", "their deck is Root".
static func _cond_after_or(m: Dictionary) -> String:
	var said: String = cond_text(m.get("when", {})).trim_prefix("the attack is ")
	if str(m.get("scope", "own")) == "opponent_cost":
		said = said.replace("your opponent's ", "their ")
	return said


## "A, B and C", for a list a card reads out in full.
static func _and_join(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "" if names.is_empty() else names[0]
	var head: PackedStringArray = names.slice(0, names.size() - 1)
	return "%s and %s" % [", ".join(head), names[names.size() - 1]]


## What a card that looks at one card is looking for, shared by `draw_check` and the branching
## form of `remove_discard`.
static func _check_name(e: Dictionary) -> String:
	match str(e.get("check", "school")):
		"attack":
			return "a Strike card or an Art card"
		"signature":
			return "one of your duelist's Signature cards"
		"named":
			return "a Signature card"
		"title_contains":
			return "a \"%s\" card" % str(e.get("title_contains", ""))
		_:
			return "a %s card" % school_name(str(e.get("school", "")))


static func _times_word(n: int) -> String:
	match n:
		2: return "double"
		3: return "triple"
		_: return "%d times" % n


static func attack_text(a: Dictionary) -> String:
	var kind: String = str(a.get("kind", "strike"))
	var s: String = ("Focused " if bool(a.get("focused", false)) else "") + ("Strike" if kind == "strike" else "Art")
	if a.has("printed_stages") or a.has("printed_life"):
		var parts: PackedStringArray = PackedStringArray()
		if int(a.get("printed_stages", 0)) > 0:
			parts.append("%d Energy" % int(a["printed_stages"]))
		if int(a.get("printed_life", 0)) > 0:
			parts.append(_plural(int(a["printed_life"]), "wound", "wounds"))
		s += " dealing " + " and ".join(parts)
	else:
		var mods: PackedStringArray = PackedStringArray()
		if int(a.get("stages", 0)) != 0:
			mods.append("%+d Energy" % int(a["stages"]))
		if int(a.get("life", 0)) != 0:
			mods.append("%+d %s" % [int(a["life"]), "wound" if absi(int(a["life"])) == 1 else "wounds"])
		if not mods.is_empty():
			s += " doing " + " and ".join(mods)
	var trade: Dictionary = a.get("damage_trade", {})
	if not trade.is_empty():
		var each: int = maxi(1, int(trade.get("per", 1)))
		s += ". You may reduce the wounds this attack deals by any amount, to a minimum of 0, and remove one of your opponent's %s in play for every %s given up" % [
			type_words(str(trade.get("card_type", "drill")), true),
			("wound" if each == 1 else "%d wounds" % each)]
	if bool(a.get("stages_from_table", false)):
		s += ", plus the Strike Table result in Energy"
	if int(a.get("life_per_ally", 0)) > 0 and a.has("ally_tag"):
		s += ", plus %d wounds for each %s Ally in play" % [int(a["life_per_ally"]), keyword_name(str(a["ally_tag"]))]
	elif int(a.get("life_per_ally", 0)) > 0:
		s += ", plus %d wounds for each Ally you have in play" % int(a["life_per_ally"])
	if bool(a.get("life_from_surge", false)):
		s += ", plus wounds equal to your Surge Rate"
	if int(a.get("life_per_fervor", 0)) > 0:
		s += ", plus wounds equal to your Fervor" if int(a["life_per_fervor"]) == 1 else ", plus %d wounds for each Fervor you have" % int(a["life_per_fervor"])
	if a.has("life_per_set_seal"):
		s += ", plus 1 wound for each %s Seal in play" % str(a["life_per_set_seal"]).capitalize()
	if str(a.get("life_per_tag", "")) != "":
		s += ", plus 1 wound for each %s personality in play" % str(a["life_per_tag"]).capitalize()
	if int(a.get("life_per_opponent_seal", 0)) > 0:
		s += ", plus %d wounds for each Seal your opponent controls" % int(a["life_per_opponent_seal"])
	if int(a.get("multiply", 1)) > 1:
		s += " doing %s the Base Damage" % _times_word(int(a["multiply"]))
	s += "."
	var table_times: Dictionary = a.get("table_multiply", {})
	if not table_times.is_empty():
		var times: String = _times_word(maxi(1, int(table_times.get("by", 2))))
		s += " %s the Strike Table result." % (("If the personality performing this has higher Might than the one defending, " + times) if bool(table_times.get("higher_might", false)) else _cap(times))
	if a.has("cost_stages") or int(a.get("cost_hand", 0)) > 0:
		var costs: PackedStringArray = PackedStringArray()
		if a.has("cost_stages"):
			costs.append("no Energy" if int(a["cost_stages"]) == 0 else "%d Energy" % int(a["cost_stages"]))
		if int(a.get("cost_hand", 0)) > 0:
			costs.append(_plural(int(a["cost_hand"]), "card from your hand", "cards from your hand"))
		s += " Costs %s to perform." % " and ".join(costs)
	if int(a.get("cost_life", 0)) > 0:
		s += " Take %s to perform it." % _plural(int(a["cost_life"]), "wound", "wounds")
	if a.has("pay_stages"):
		var pay: Dictionary = a["pay_stages"]
		var per: int = int(pay.get("per", 2))
		s += " You may pay any amount of %s. It does %s for each %s paid." % [
			("your duelist's Energy" if str(pay.get("from", "")) == "duelist" else "Energy"), _bonus_words(pay),
			("Energy" if per == 1 else str(per))]
	if a.has("pay_life"):
		s += " You may take a wound to have it do %s." % _bonus_words(a["pay_life"])
	if a.has("pay_hand"):
		var phand: Dictionary = a["pay_hand"]
		var hand_adds: PackedStringArray = PackedStringArray()
		if int(phand.get("life", 0)) != 0:
			hand_adds.append(_plural(int(phand["life"]), "wound", "wounds"))
		if int(phand.get("stages", 0)) != 0:
			hand_adds.append("%d Energy of damage" % int(phand["stages"]))
		s += " You may discard a card from your hand as you perform it to add %s." % " and ".join(hand_adds)
	if bool(a.get("damage_removes", false)):
		s += " Wounds from it are removed from the game instead of discarded."
	if bool(a.get("unstoppable", false)):
		s += " Cannot be stopped."
	if bool(a.get("no_prevent", false)):
		s += " Damage cannot be prevented."
	if a.has("no_stop_by") and str(a.get("no_prevent_by", "")) == str(a["no_stop_by"]):
		s += " Cannot be stopped or prevented by %s cards." % str(a["no_stop_by"]).capitalize()
	elif a.has("no_stop_by"):
		s += " Cannot be stopped by %s cards." % str(a["no_stop_by"]).capitalize()
	if a.has("no_prevent_by") and str(a["no_prevent_by"]) != str(a.get("no_stop_by", "")):
		s += " Cannot be prevented by %s cards." % str(a["no_prevent_by"]).capitalize()
	if bool(a.get("only_first_attack", false)):
		s += " Must be your first attack this Combat."
	if bool(a.get("only_first_card", false)):
		s += " Must be the first card you use this Combat."
	if int(a.get("stops_needed", 1)) > 1:
		s += " Takes %d stops to stop." % int(a["stops_needed"])
	return s


## "+3 wounds", "+3 Energy", "+1 Energy and +2 wounds" for an attack's bonus damage.
static func _bonus_words(d: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if int(d.get("stages", 0)) != 0:
		parts.append("%+d Energy" % int(d["stages"]))
	if int(d.get("life", 0)) != 0:
		parts.append("%+d %s" % [int(d["life"]), "wound" if absi(int(d["life"])) == 1 else "wounds"])
	return " and ".join(parts)


## What an attack gains under a condition, as a sentence about the attack: "it does +4 wounds and
## is Focused", "it is Focused, you gain 2 Energy, and ...".
static func variant_text(v: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var bonus: String = _bonus_words(v)
	if int(v.get("life_per_opponent_seal", 0)) > 0:
		var per_seal: String = "+%d wounds for each Seal your opponent controls" % int(v["life_per_opponent_seal"])
		bonus = per_seal if bonus == "" else "%s and %s" % [bonus, per_seal]
	# "This attack also does 3 Energy of damage": printed damage the attack gains outright.
	var also: PackedStringArray = PackedStringArray()
	if int(v.get("printed_stages", 0)) > 0:
		also.append("%d Energy" % int(v["printed_stages"]))
	if int(v.get("printed_life", 0)) > 0:
		also.append(_plural(int(v["printed_life"]), "wound", "wounds"))
	var it_parts: PackedStringArray = PackedStringArray()
	if bonus != "":
		it_parts.append("does " + bonus)
	if not also.is_empty():
		it_parts.append("also deals " + " and ".join(also))
	if bool(v.get("focused", false)):
		it_parts.append("is Focused")
	if not it_parts.is_empty():
		parts.append("it " + _join_and(it_parts))
	if bool(v.get("no_prevent", false)):
		parts.append("its damage cannot be prevented")
	var about_it: bool = not parts.is_empty()
	for t in effects_text(v.get("effects", [])):
		var clause: String = _lc(t).trim_suffix(".")
		# After "it does ...", an instruction needs its subject: "and you gain 2 Energy".
		if about_it and clause.get_slice(" ", 0).capitalize() in IMPERATIVE_VERBS:
			clause = "you " + clause
		if not parts.is_empty() and clause.begins_with(_lc(REMAINDER)) and not clause.substr(REMAINDER.length()).contains(","):
			clause = "%s for the remainder of Combat" % clause.substr(REMAINDER.length())
		parts.append(clause)
	return _join_and(parts) + "."


static func defense_text(d: Dictionary) -> String:
	var s: String = ""
	var cost_hand: int = int(d.get("cost_hand", 0))
	# A block that is paid for reads as the payment first, because that is the decision.
	var paid_card: String = "a card"
	var cost_filter: Variant = d.get("cost_hand_filter", "")
	if cost_filter is Dictionary and str((cost_filter as Dictionary).get("attack_kind", "")) != "":
		paid_card = "a card that can perform %s" % _a(str(cost_filter["attack_kind"]).capitalize())
	var pay: String = "" if cost_hand == 0 else "Discard %s from your hand to stop" % (paid_card if cost_hand == 1 else "%d cards" % cost_hand)
	var cost_life: int = int(d.get("cost_life", 0))
	if pay == "" and cost_life > 0:
		pay = "Take %s to stop" % _plural(cost_life, "wound", "wounds")
	var stops: String = str(d.get("stops", ""))
	var stop_all: String = str(d.get("stop_all", ""))
	var when: Dictionary = d.get("when", {})
	var aimed: bool = when.size() == 1 and when.has("defender_character") and pay == ""
	match stops:
		"strike":
			s = "Stops a Strike." if pay == "" else "%s a Strike." % pay
		"art":
			s = "Stops an Art." if pay == "" else "%s an Art." % pay
		"none":
			if str(when.get("attack_kind", "")) != "":
				# A block that only answers one kind and stops nothing: read it as what it is used on.
				return "Use against %s. It is not stopped." % _a(str(when["attack_kind"]).capitalize())
			s = "Use during your attack phase or against an attack. Stops nothing."
		_:
			s = "Stops any attack." if pay == "" else "%s any attack." % pay
	var merged_all: bool = false
	if aimed:
		# "Stops a Strike performed against Sir Edric Rooke or Emrys Rooke."
		var names: PackedStringArray = PackedStringArray()
		for nm in (when["defender_character"] if when["defender_character"] is Array else [when["defender_character"]]):
			names.append(str(nm))
		s = "%s performed against %s." % [s.trim_suffix("."), " or ".join(names)]
	elif d.has("when"):
		s = _conditional(when, s)
	elif pay == "" and stop_all != "" and (stop_all == stops or stop_all == "stopped" or (stop_all == "any" and stops == "any")):
		# "Stops an Art and every Art performed against you for the remainder of Combat."
		var every: String = "every attack" if stops == "any" else "every " + stops.capitalize()
		if stop_all == "stopped":
			every = "every attack of that kind"
		s = "%s and %s performed against you for the remainder of Combat." % [s.trim_suffix("."), every]
		merged_all = true
	if not merged_all:
		if stop_all == "stopped":
			s += " Stops all attacks of that kind performed against you for the remainder of Combat."
		elif stop_all != "":
			s += " Stops all %s performed against you for the remainder of Combat." % ("attacks" if stop_all == "any" else stop_all.capitalize() + "s")
	if str(d.get("stop_focused", "")) == "discard_hand":
		s += " You may discard a card from your hand to let this stop a Focused attack."
	elif d.has("stop_focused"):
		s += " Can stop a Focused attack."
	if int(d.get("cost_stages", 0)) > 0:
		s += " Costs %d Energy to use." % int(d["cost_stages"])
	if cost_life > 0 and cost_hand > 0:
		s += " Take %s to use it." % _plural(cost_life, "wound", "wounds")
	if d.has("copy_attack"):
		s += " In your next attack phase, you may repeat the attack it stopped, with its modifiers."
	return s


## A personality keyword as a card prints it: "a Construct personality".
static func _tag_name(tag: String) -> String:
	return "a %s personality" % tag.capitalize()


static func cond_text(when: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for k in when.keys():
		var v: Variant = when[k]
		match str(k):
			"character":
				parts.append("%s is in control" % _or_names(v))
			"duelist_character":
				if v is Array:
					var names: PackedStringArray = PackedStringArray()
					for nm in v:
						names.append(str(nm))
					parts.append("your duelist is %s" % " or ".join(names))
				else:
					parts.append("%s is your duelist" % str(v))
			"performed_by":
				if str(v) != "ally" and when.has("duelist_tag"):
					# "If your duelist performs it and is a Construct personality".
					parts.append("your duelist performs it and is %s" % _tag_name(str(when["duelist_tag"])))
				else:
					parts.append("performed by an Ally" if str(v) == "ally" else "performed by your duelist")
			"defender_alignment":
				parts.append("performed against %s" % alignment_name(str(v)))
			"aspect_min":
				parts.append("your duelist is Aspect %d or higher" % int(v))
			"own_mastery_school":
				parts.append("your Mastery is %s" % (school_name(str(v)) if str(v) != "" else "Freestyle"))
			"reserve_min":
				parts.append("you have %d or more cards in your Reserve" % int(v))
			"opponent_fervor":
				parts.append("your opponent's Fervor is %d" % int(v))
			"opponent_fervor_max":
				parts.append("your opponent's Fervor is %d or lower" % int(v))
			"fervor_min":
				parts.append("your Fervor is %d or higher" % int(v))
			"allies_min":
				parts.append("you have an Ally in play" if int(v) <= 1 else "you have %d or more Allies in play" % int(v))
			"allies_tag_min":
				var kin_tag: String = keyword_name(str((v as Dictionary).get("tag", "")))
				var kin_n: int = int((v as Dictionary).get("count", 1))
				parts.append("you have a %s Ally in play" % kin_tag if kin_n <= 1 else "you have %d or more %s Allies in play" % [kin_n, kin_tag])
			"seals_min":
				parts.append("you hold a Seal" if int(v) <= 1 else "you hold %d or more Seals" % int(v))
			"opponent_seals_min":
				parts.append("your opponent holds a Seal" if int(v) <= 1 else "your opponent holds %d or more Seals" % int(v))
			"ally_present":
				parts.append("%s is in play" % str(v))
			"character_in_play":
				parts.append("%s is in play" % str(v))
			"first_power_use":
				parts.append("this is the first time you perform this attack this Combat")
			"opponent_non_combats_min":
				parts.append("your opponent has %d or more Non-Combat cards in play" % int(v))
			"discard_top_school":
				parts.append("the top card of your discard pile is %s" % school_name(str(v)))
			"discard_top_school_not":
				parts.append("the top card of your discard pile is not %s" % school_name(str(v)))
			"discard_bottom_school":
				parts.append("the bottom card of your discard pile is %s" % school_name(str(v)))
			"opponent_discard_top_not_attack":
				parts.append("the top card of your opponent's discard pile is not %s card" % ("a Strike" if str(v) == "strike" else "an Art"))
			"discard_top2_school":
				parts.append("the top two cards of your discard pile are %s" % school_name(str(v)))
			"higher_might":
				# The engine compares the personalities in control, which is the printed reading.
				parts.append("the personality performing this %s higher Might than the one defending" % ("has" if bool(v) else "does not have"))
			"duelist_higher_might":
				parts.append("your duelist %s higher Might than your opponent's duelist" % ("has" if bool(v) else "does not have"))
			"opponent_style":
				parts.append("your opponent's deck is %s" % school_name(str(v)))
			"opponent_used_combat_card":
				parts.append("your opponent used a Combat card this Combat")
			"first_attack":
				parts.append("this is your first attack this Combat")
			"role":
				parts.append("entering Combat as the %s" % role_name(str(v)))
			"discard_min":
				parts.append("your discard pile has a card" if int(v) <= 1 else "your discard pile has %d or more cards" % int(v))
			"own_non_combats_min":
				parts.append("you have a Non-Combat card in play")
			"discard_has_type":
				parts.append("your discard pile has %s" % _a(type_words(str(v), false)))
			"drill_school_in_play":
				parts.append("you have %s Drill in play" % _a(school_name(str(v))))
			"energy_min":
				parts.append("your duelist has %d or more Energy" % int(v))
			"duelist_energy_min":
				parts.append("your duelist has %d or more Energy" % int(v))
			"attack_only_tag":
				parts.append("the attack is %s only" % keyword_name(str(v)))
			"hand_min":
				parts.append("you have a card in hand" if int(v) <= 1 else "you have %d or more cards in hand" % int(v))
			"hand_school_min":
				var held: Dictionary = v
				parts.append("%d or more cards in your hand are %s cards" % [int(held.get("count", 1)), school_name(str(held.get("school", "")))])
			"took_wounds_min":
				parts.append("you have taken %d or more wounds from a single attack this Combat" % int(v))
			"defender_tag":
				parts.append("performed against %s" % _tag_name(str(v)))
			"stopped_last_phase":
				parts.append("you stopped an attack in their last attack phase" if bool(v) else "you stopped no attack in their last attack phase")
			"attack_focused":
				parts.append("the attack is Focused" if bool(v) else "the attack is not Focused")
			"source_school":
				parts.append("the attack is %s" % school_name(str(v)))
			"attack_kind":
				parts.append("the attack is %s" % ("a Strike" if str(v) == "strike" else "an Art"))
			"opponent_seals_min":
				parts.append("your opponent has a Seal in play")
			"ally_min":
				parts.append("you have %s in play" % _plural(int(v), "Ally", "Allies"))
			"allies_present":
				# A list of names, not a count: "if Dame Alder Rooke and Emrys Rooke are in play".
				var present: PackedStringArray = PackedStringArray()
				for nm in (v as Array):
					present.append(str(nm))
				parts.append("%s %s in play" % [_and_join(present), "is" if present.size() == 1 else "are"])
			"defender_character":
				var aimed: PackedStringArray = PackedStringArray()
				for nm in (v if v is Array else [v]):
					aimed.append(str(nm))
				parts.append("the attack is against %s" % " or ".join(aimed))
			"performer_tag":
				parts.append("the attack is performed by %s" % _tag_name(str(v)))
			"in_control_tag":
				parts.append("%s is in control" % _tag_name(str(v)))
			"duelist_tag":
				if not (when.has("performed_by") and str(when["performed_by"]) != "ally"):
					parts.append("your duelist is %s" % _tag_name(str(v)))
			"card_in_play":
				# A list is "either of these", which is how a card naming two Seals reads.
				if v is Array:
					var names: PackedStringArray = PackedStringArray()
					for title in (v as Array):
						names.append(str(title))
					parts.append("%s is in play" % " or ".join(names))
				else:
					parts.append("%s is in play" % str(v))
			_:
				parts.append("%s is %s" % [str(k).replace("_", " "), str(v)])
	return " and ".join(parts)


static func _effect_body(e: Dictionary) -> String:
	var who: String = _who(e)
	var opp: bool = who == "your opponent"
	# A Combat card either player can use reads by Combat role instead of by owner, so it needs
	# third-person phrasing: "the attacker draws 2, the defender gains 5 Energy".
	var role: bool = who == "the attacker" or who == "the defender"
	var owner: String = "their" if role else ("your opponent's" if opp else "your")
	var amount: Variant = e.get("amount", e.get("n", 0))
	var n: int = int(amount) if not (amount is String) else 0
	var body: String = ""
	match str(e.get("op", "")):
		"fervor" when bool(e.get("choose_side", false)):
			# The side is the user's to pick, so neither is named.
			body = "%s your or your opponent's Fervor %d." % [("Raise" if n >= 0 else "Lower"), absi(n)]
		"fervor":
			# Raising your own Fervor is Attune, lowering the rival's is Disrupt; the rarer two
			# directions keep the long form.
			var verb: String = "%s %s Fervor" % [("Raise" if n >= 0 else "Lower"), owner]
			if owner == "your" and n > 0:
				verb = "Attune"
			elif opp and n < 0:
				verb = "Disrupt"
			body = "%s %d." % [verb, absi(n)]
			var instead: Dictionary = e.get("instead", {})
			if not instead.is_empty():
				body = "%s %d, or %d instead if %s." % [verb, absi(n), absi(int(instead.get("amount", n))), cond_text(instead.get("when", {}))]
		"set_fervor":
			body = "Set %s Fervor to %d." % [owner, n]
		"set_fervor_both":
			body = "Set both players' Fervor to %d." % n
		"fervor_needed":
			body = "%s the Fervor %s duelist needs to advance an Aspect by %d." % [("Raise" if n >= 0 else "Lower"), owner, absi(n)]
		"set_fervor_needed":
			body = "%s duelist needs %d Fervor to advance an Aspect." % [_cap(owner), n]
		"energy":
			if amount is String:
				var target: String = str(e.get("target", ""))
				var whose: String = owner
				var whom: String = ""
				match target:
					"duelist":
						whose = "your duelist's"
					"last_searched":
						whose = "its"
					"all":
						whom = "your duelist and each of your Allies"
					"allies":
						whom = "each of your Allies"
					"choose":
						whom = "one of your personalities"
					"any":
						whose = "any one personality's"
				body = ("Raise %s Energy to full." % whose) if whom == "" else ("Raise %s to full Energy." % whom)
				if bool(e.get("next_art_free", false)):
					body += " The next Art that personality performs this Combat costs no Energy to perform."
			elif str(e.get("target", "")) == "allies" and not opp:
				body = "Each of your Allies %s %d Energy." % [("gains" if n >= 0 else "loses"), absi(n)]
			elif str(e.get("target", "")) == "all" and not opp:
				body = "Your duelist and each of your Allies %s %d Energy." % [("gain" if n >= 0 else "lose"), absi(n)]
			elif role:
				body = "%s %s %d Energy." % [_cap(who), ("gains" if n >= 0 else "loses"), absi(n)]
			elif opp:
				var whom: String = "Your opponent's duelist" if str(e.get("target", "")) == "duelist" else "Your opponent"
				body = "%s %s %d Energy." % [whom, ("gains" if n >= 0 else "loses"), absi(n)]
			else:
				body = "%s %d Energy." % [("Gain" if n >= 0 else "Lose"), absi(n)]
		"set_energy":
			if str(e.get("amount", "")) == "match_attacker":
				body = "If %s personality in control has more Energy than the one performing this attack, lower it to match." % owner
			elif str(e.get("target", "duelist")) == "all":
				body = "Set all of %s personalities to %d Energy." % [owner, n]
			elif str(e.get("target", "duelist")) == "duelist" and not role:
				body = "Set %s duelist's Energy to %d." % [owner, n]
			else:
				body = "Set %s Energy to %d." % [owner, n]
		"draw" when bool(e.get("up_to", false)) and n > 1:
			body = ("Your opponent may draw up to %d cards." if opp else "You may draw up to %d cards.") % n
		"draw" when str(e.get("from", "top")) == "bottom":
			body = "Draw the bottom %s of your Life Deck." % ("card" if n == 1 else "%d cards" % n)
		"draw":
			body = ("Your opponent draws %s." if opp else "Draw %s.") % _plural(n, "card", "cards")
		"shuffle_source":
			body = "Shuffle this card into your Life Deck."
		"cap_attack":
			body = "That attack deals at most %d %s." % [n, "wound" if n == 1 else "wounds"]
		"remove_reserve":
			body = "Remove %s in your Reserve from the game." % _plural(n, "card", "cards")
		"show_checked":
			body = "Show it to your opponent."
		"exile_source":
			body = "Remove this card from the game."
		"choose_one":
			var halves: PackedStringArray = PackedStringArray()
			var ends: PackedStringArray = PackedStringArray()
			var counts: Array[int] = []
			for o in e.get("choices", []):
				halves.append(_lc(" ".join(effects_text((o as Dictionary).get("effects", [])))).trim_suffix("."))
				var only: Array = (o as Dictionary).get("effects", [])
				if only.size() == 1:
					var one: Dictionary = only[0]
					if str(one.get("op", "")) == "shuffle_discard" and not one.has("school") and not one.has("character"):
						ends.append(str(one.get("from", "top")))
						counts.append(int(one.get("amount", 1)))
			if ends.size() == 2 and halves.size() == 2 and counts[0] == counts[1]:
				# "the top or bottom 3 cards": two ends of one pile read as one choice.
				body = "Shuffle the %s %d or the %s %d cards of your discard pile into your Life Deck." % [ends[0], counts[0], ends[1], counts[1]]
			else:
				body = "Choose one: %s." % " or ".join(halves)
		"sift_discard":
			body = "Choose up to %d cards in your discard pile. Remove %d of them from the game and shuffle the rest into your Life Deck." % [n, int(e.get("remove", 2))]
		"silence_drill":
			body = "Choose one of your opponent's Drills in play. Your opponent cannot use its power for the rest of the game."
		"copy_drill":
			body = "Choose a Drill in play that does nothing when entering Combat. For the remainder of Combat, a copy of it works for you: its modifiers, Defense Shield and powers. Using this does not end your attack phase."
		"cycle_hand":
			body = ("Your opponent shuffles their hand into their Life Deck and draws that many cards." if opp
				else "Shuffle your hand into your Life Deck and draw that many cards.")
		"reveal_pick":
			var picks_self: String = ""
			if e.has("self_picks_when"):
				picks_self = ", or you choose if %s" % cond_text(e["self_picks_when"])
			body = "Show the top %d cards of your Life Deck to both players. Your opponent chooses 1 of them to go into your hand%s. Put the others back on top in any order." % [n, picks_self]
		"draw_until":
			body = "Draw until you have %d cards in hand." % n
		"draw_discard":
			if bool(e.get("up_to", false)) and n > 1:
				body = "Draw up to %d cards from the %s of %s discard pile." % [n, str(e.get("from", "bottom")), owner]
			elif role:
				body = "%s draws the %s %s of %s discard pile." % [_cap(who), str(e.get("from", "bottom")), ("card" if n == 1 else "%d cards" % n), owner]
			else:
				body = "Draw the %s %s of your discard pile." % [str(e.get("from", "bottom")), ("card" if n == 1 else "%d cards" % n)]
			if e.has("if_school"):
				var after: PackedStringArray = PackedStringArray()
				for t in e.get("effects", []):
					var tt: String = effect_text(t)
					if tt != "":
						after.append(_lc(tt))
				body += " If it is %s card, %s" % [_a(school_name(str(e["if_school"]))), " ".join(after)]
		"discard_life" when bool(e.get("remove", false)):
			# Off the top and out of the duel: the cards are lost the same way, they simply never
			# reach the discard pile, so a recovery card cannot go looking for them.
			body = "Remove the top %s of %s Life Deck from the game." % [
				_plural(n, "card", "cards").trim_prefix("a ").trim_prefix("an "),
				("your opponent's" if opp else "your")]
		"discard_life" when str(amount) == "owner_surge":
			body = "Your opponent takes X wounds, X = your duelist's Surge Rate." if opp else "Take X wounds, X = your duelist's Surge Rate."
		"discard_life" when str(amount) == "per_ally":
			body = "Take a wound for each Ally you have in play." if not opp else "Your opponent takes a wound for each Ally they have in play."
		"discard_life" when str(amount) == "twice_fervor":
			body = "Your opponent takes 2 wounds for each point of their Fervor." if opp else "Take 2 wounds for each point of your Fervor."
		"discard_life" when str(amount) == "five_minus_fervor":
			body = ("Your opponent takes X wounds, X = 5 minus their Fervor." if opp else "Take X wounds, X = 5 minus your Fervor.")
		"discard_life":
			body = ("Your opponent takes %s." if opp else "Take %s.") % _plural(n, "wound", "wounds")
		"discard_hand" when str(e.get("to", "")) == "deck_shuffle" and bool(e.get("random", true)):
			body = "Shuffle a card at random from your opponent's hand into their Life Deck." if opp \
				else "Shuffle a card at random from your hand into your Life Deck."
		"discard_hand":
			var how: String = " at random" if bool(e.get("random", true)) else ""
			if e.has("down_to"):
				body = "%s until %s %s or fewer cards in hand." % [
					("Your opponent discards" if opp else "Discard"), ("they have" if opp else "you have"),
					_plural(int(e["down_to"]), "card", "cards").split(" ")[0]]
			elif bool(e.get("all", false)):
				var band: String = str(e.get("filter", ""))
				var looked: String = "Look at your opponent's hand and discard every " if bool(e.get("reveal", false)) and opp else ""
				if band == "non_combat":
					body = ("%sNon-Combat card in it." % looked) if looked != "" else \
						("Your opponent discards every Non-Combat card in hand." if opp else "Discard every Non-Combat card in your hand.")
				else:
					body = "Your opponent discards their whole hand." if opp else "Discard your whole hand."
			elif str(e.get("to", "")) == "removed":
				var kept: String = " that is not a Seal" if str(e.get("filter", "")) == "non_seal" else ""
				if opp:
					body = "Your opponent chooses %s in their hand%s and removes %s from the game." % [_plural(n, "card", "cards"), kept, "it" if n == 1 else "them"]
				else:
					body = "Remove %s in your hand%s from the game." % [_plural(n, "card", "cards"), kept]
				if bool(e.get("reveal_if_none", false)) and opp:
					body += " If they hold only Seals, they show you their hand."
			elif str(e.get("to", "")) == "deck":
				body = "Look at your opponent's hand and shuffle a card of your choice into their Life Deck."
			elif str(e.get("chooser", "")) == "owner":
				# A dictionary filter names the band the choice is limited to.
				var band_of: String = ""
				if e.get("filter", "") is Dictionary:
					band_of = " " + type_words(str((e["filter"] as Dictionary).get("card_type", "card")), n != 1)
				body = "Look at your opponent's hand and choose %s%s. They discard %s." % [
					_plural(n, "card", "cards") if band_of == "" else ("%d" % n if n != 1 else "a"),
					band_of, "it" if n == 1 else "them"]
			elif opp:
				body = "Your opponent discards %s from hand%s." % [_plural(n, "card", "cards"), how]
			elif str(e.get("filter", "")) == "signature":
				body = "Discard %s of your duelist's Signature cards from your hand%s." % [("one" if n == 1 else str(n)), how]
			elif e.get("filter", "") is Dictionary and str((e["filter"] as Dictionary).get("school", "")) != "":
				var discard_school: String = school_name(str((e["filter"] as Dictionary)["school"]))
				body = "Discard %s from your hand%s." % [_plural(n, discard_school + " card", discard_school + " cards"), how]
			else:
				body = "Discard %s from your hand%s." % [_plural(n, "card", "cards"), how]
		"reveal_hand" when bool(e.get("look", false)) and opp:
			body = "Look at your opponent's hand."
		"reveal_hand":
			body = "Your opponent shows you their hand." if opp else "Show your hand to your opponent."
		"remove_hand":
			body = ("Your opponent removes %s in hand from the game." if opp else "Remove %s in your hand from the game.") % _plural(n, "card", "cards")
		"search":
			body = search_text(e)
		"discard_in_play" when str(e.get("card_type", "")) == "attached_to_duelist":
			body = "Discard every card attached to %s duelist." % ("your opponent's" if opp else "your")
		"discard_in_play" when str(e.get("to", "")) == "deck_bottom":
			# Not a discard either: the cards go under their owner's Life Deck, in the order chosen.
			var sunk: String = str(e.get("card_type", "non_combat"))
			if str(e.get("who", "")) == "any":
				return "Place %s in play at the bottom of its owner's Life Deck." % _count_of(e, sunk)
			var how_many: String = "all"
			if bool(e.get("at_least_one", false)) and n == 2:
				how_many = "1 or 2"
			elif bool(e.get("at_least_one", false)):
				how_many = "1 to %d" % n
			elif not bool(e.get("all", false)):
				how_many = ("up to %d" % n) if bool(e.get("up_to", false)) else str(n)
			body = "Place %s of %s %s in play at the bottom of %s Life Deck." % [
				how_many, ("your opponent's" if opp else "your"), (_all_words(sunk) if how_many == "all" else type_words(sunk, true)), ("their" if opp else "your")]
		"discard_in_play" when str(e.get("to", "")) == "deck_shuffle":
			# Not a discard at all: the cards go back into their owner's Life Deck.
			var shuffled: String = str(e.get("card_type", "non_combat"))
			if str(e.get("owned_by", "")) == "opponent":
				body = "Shuffle every %s your opponent owns in play into their Life Deck, whoever controls it." % type_words(shuffled, false)
			elif str(e.get("who", "")) == "any":
				# Either side's, so it names neither and the owner it goes back to follows the card.
				body = "Shuffle %s in play into its owner's Life Deck." % _count_of(e, shuffled)
			else:
				body = "Shuffle %s %s in play into %s Life Deck." % [("all of your opponent's" if opp else "all of your"), _all_words(shuffled), ("their" if opp else "your")]
		"discard_in_play":
			var card_type: String = str(e.get("card_type", "non_combat"))
			var remove: bool = bool(e.get("remove", false))
			if str(e.get("who", "")) == "any":
				# Either side's, so it names neither.
				var reach: String = " and in both Life Decks" if bool(e.get("life_decks", false)) else ""
				body = "%s %s in play%s%s." % [("Remove" if remove else "Discard"), _count_of(e, card_type), reach, (" from the game" if remove else "")]
			elif opp and (bool(e.get("choose", false)) or bool(e.get("all", false))):
				# You pick, or there is nothing to pick: the line is yours to carry out.
				body = "%s %s in play%s." % [("Remove" if remove else "Discard"), _theirs(e, card_type), (" from the game" if remove else "")]
			elif opp:
				body = "Your opponent %s %s in play%s." % [("removes" if remove else "discards"), _count_of(e, card_type), (" from the game" if remove else "")]
			else:
				var plural: String = type_words(card_type, true)
				if e.has("school"):
					plural = "%s %s" % [school_name(str(e["school"])), plural]
				var mine: String = "one of your %s" % plural
				if bool(e.get("all", false)):
					mine = "all of your %s%s" % [(school_name(str(e["school"])) + " ") if e.has("school") else "", _all_words(card_type)]
				elif bool(e.get("up_to", false)):
					mine = "up to %d of your %s" % [n, plural]
				elif n > 1:
					mine = "%d of your %s" % [n, plural]
				body = "%s %s in play%s." % [("Remove" if remove else "Discard"), mine, (" from the game" if remove else "")]
		"remove_discard":
			var how_many: String = "all of"
			var any_of: bool = amount is String and str(amount) == "any"
			var pile_end: String = str(e.get("from", "top"))
			if any_of:
				# "Choose any cards in your discard pile and remove them": no cap, and none is a
				# legal answer, so the count is not named at all.
				how_many = "any cards in"
			elif not bool(e.get("all", false)):
				if bool(e.get("choose", false)):
					how_many = "up to %d cards in" % n if bool(e.get("up_to", false)) else ("a card in" if n == 1 else "%d cards in" % n)
				else:
					how_many = "the %s card of" % pile_end if n == 1 else "the %s %d cards of" % [pile_end, n]
			var whole: bool = bool(e.get("all", false)) and not any_of
			if bool(e.get("choose_player", false)):
				var share: String = "their whole discard pile" if whole else "%s their discard pile" % how_many
				body = "Choose a player and remove %s from the game." % share
			elif whole:
				body = "Remove %s whole discard pile from the game." % owner
			elif n == 1 and pile_end == "top" and not bool(e.get("choose", false)) and ((e.get("when", {}) as Dictionary).has("discard_top_school") \
					or (e.get("when", {}) as Dictionary).has("discard_top_school_not")):
				# The condition already named the card: "if the top card of your discard pile is
				# Steel, you may remove it from the game".
				body = "Remove it from the game."
			else:
				body = "Remove %s %s discard pile from the game." % [how_many, owner]
			# "...to Attune 1, or Attune 2 if it is a Pyre card": the card that burns picks the
			# branch, so both read off the same removal.
			if e.has("effects") and e.has("else_effects"):
				var hit_line: String = " ".join(PackedStringArray(_texts(e.get("effects", []))))
				var miss_line: String = " ".join(PackedStringArray(_texts(e.get("else_effects", []))))
				var either: String = "%s if it is %s." % [_or_instead(miss_line, hit_line), _check_name(e)]
				var to_do: String = _infinitive(either)
				if to_do != "":
					body = body.trim_suffix(".") + " to " + to_do
				else:
					body += (" If you do, %s" % _lc(either)) if bool(e.get("may", false)) else " " + either
			elif e.has("effects"):
				var hit: String = " ".join(PackedStringArray(_texts(e.get("effects", []))))
				body += " If it is %s, %s" % [_check_name(e), _lc(hit)]
		"shuffle_discard" when str(e.get("from", "top")) == "top_and_bottom":
			body = "Shuffle the top and bottom cards of your discard pile into your Life Deck."
		"shuffle_discard":
			var kind: String = str(e.get("school", ""))
			var noun_one: String = "card" if kind == "" else "%s card" % school_name(kind)
			var noun_many: String = "cards" if kind == "" else "%s cards" % school_name(kind)
			if str(e.get("character", "")) != "":
				noun_one = "%s Signature card" % str(e["character"])
				noun_many = "%s Signature cards" % str(e["character"])
			var pile: String = "your discard pile" if str(e.get("from", "top")) == "top" else "the bottom of your discard pile"
			# "The bottom 2 cards of your discard pile", as `recover` says it, when no kind narrows them.
			var bottom_run: String = ""
			if str(e.get("from", "top")) == "bottom" and kind == "" and str(e.get("character", "")) == "" and not bool(e.get("all", false)):
				bottom_run = "the bottom %s of your discard pile" % ("card" if n == 1 else "%d cards" % n)
			if bool(e.get("no_shuffle", false)):
				if bottom_run != "":
					return "Place %s at the bottom of your Life Deck." % bottom_run
				var taken: String = _plural(int(e.get("amount", 1)), noun_one, noun_many)
				return "Place %s from %s at the bottom of your Life Deck." % [taken, pile]
			var each: String = ""
			if str(e.get("per_bloodline", "")) != "":
				each = " for each %s personality you have in play" % bloodline_name(str(e["per_bloodline"]))
			elif bool(e.get("per_personality", false)):
				each = " for each personality you have in play"
			if bool(e.get("all", false)):
				body = "Shuffle every %s from %s into your Life Deck%s." % [noun_one, pile, each]
			elif kind == "" and str(e.get("from", "top")) == "top" and each == "":
				body = "Shuffle the top %s of your discard pile into your Life Deck." % ("card" if n == 1 else "%d cards" % n)
			elif bottom_run != "" and each == "":
				body = "Shuffle %s into your Life Deck." % bottom_run
			else:
				body = "Shuffle %s from %s into your Life Deck%s." % [_plural(n, noun_one, noun_many), pile, each]
			if e.has("effects"):
				body += " If it is %s, %s" % [_check_name(e.get("if", {})), _lc(" ".join(PackedStringArray(_texts(e.get("effects", [])))))]
		"recover":
			var moved: String = "%s %s" % [str(e.get("from", "top")), ("card" if n == 1 else "%d cards" % n)]
			if e.has("card_type"):
				body = "Place the top %s in your discard pile at the bottom of your Life Deck." % type_words(str(e["card_type"]), false)
			elif role:
				body = "%s places the %s of their discard pile at the bottom of their Life Deck." % [_cap(who), moved]
			else:
				body = "Place the %s of your discard pile at the bottom of your Life Deck." % moved
		"discard_grounds":
			body = "Discard the Grounds in play."
		"end_combat":
			body = "End Combat."
		"pass_next_phase":
			body = "Your opponent must pass during their next attack phase." if opp else "You must pass during your next attack phase."
		"skip_next_attack_phase":
			body = "Your opponent skips their next attack phase." if opp else "Skip your next attack phase."
		"cannot_declare_combat":
			body = "%s cannot declare Combat this turn." % _cap(who)
		"stop_all":
			# The float sits on its owner and is read when they are the defender, so it stops the
			# attacks aimed at them and not their own.
			var kind: String = str(e.get("kind", "any"))
			var stopped_kind: String = "attacks" if kind == "any" else kind.capitalize() + "s"
			if kind == "stopped":
				body = "Stop all of your opponent's attacks of the same kind for the remainder of Combat."
			else:
				body = "Stop all %s performed against you for the remainder of Combat." % stopped_kind
		"float":
			var what: String = str(e.get("what", ""))
			var params: Dictionary = e.get("params", {})
			if what == "modifier":
				var mspan: String = "For the rest of the game" if str(e.get("duration", "combat")) == "game" else "For the remainder of Combat"
				var mtext: String = modifier_text(params)
				if bool(params.get("per_endurance_since", false)):
					# "X = the times you have used Endurance since you played this card".
					mtext = mtext.replace("+1 Energy", "+X Energy").trim_suffix(".") + ", X = the times you have used Endurance since this card was played."
				# "All of your OTHER attacks": the attack that puts the effect out is not one of them.
				if bool(e.get("exclude_source", false)) and mtext.begins_with("Your "):
					mtext = "Your other " + mtext.substr(5)
				# "All energy attacks this personality performs": pinned to the one who performed it.
				if bool(e.get("this_personality", false)) and mtext.begins_with("Your "):
					var rest: String = mtext.substr(5).trim_suffix(".")
					var sp: int = rest.find(" ")
					mtext = "All %s this personality performs %s." % [rest.substr(0, sp), rest.substr(sp + 1)]
				body = mtext if bool(params.get("once", false)) else "%s, %s" % [mspan, _lc(mtext)]
			elif what == "make_focused" and bool(params.get("empower_only", false)):
				body = "For the remainder of Combat, your %sattacks that have Empower are Focused." % (
					(school_name(str(params["school"])) + " ") if params.has("school") else "")
			elif what == "make_focused" and params.has("school"):
				body = "For the remainder of Combat, your other %s attacks are Focused." % school_name(str(params["school"]))
			elif what == "no_shields":
				body = "For the remainder of Combat, your opponent cannot use Defense Shields."
			elif what == "ally_powers_any_stage":
				body = "For the remainder of Combat, the Allies you have in play now may use their Powers at any Energy while your duelist keeps control of Combat."
			elif what == "on_hand_play":
				body = "For the remainder of Combat, whenever you play a card from your hand, %s" % _lc(" ".join(PackedStringArray(_texts(params.get("effects", [])))))
			elif what == "power_second_use":
				body = "This Power may be used a second time this Combat."
			elif what == "keep_drills":
				body = "For the remainder of Combat, you do not discard your Drills in play when your duelist advances or loses an Aspect."
			elif what == "at_combat_end":
				body = "At the end of Combat, %s" % _lc(" ".join(PackedStringArray(_texts(params.get("effects", [])))))
			elif what == "no_fervor_gain":
				if str(e.get("duration", "")) == "turn":
					body = "%s cannot gain Fervor for the remainder of the turn." % ("Your opponent" if opp else "You")
				else:
					body = "%s cannot gain Fervor until the beginning of %s next turn." % [("Your opponent" if opp else "You"), ("their" if opp else "your")]
			elif what == "discard_named":
				body = "For the remainder of Combat, the bottom %d cards of your discard pile are %s Signature cards while in your discard pile." % [
					int(params.get("count", 0)), str(params.get("character", ""))]
			elif what == "table_base_fervor":
				body = "For the remainder of Combat, your Strikes that use the Strike Table have a Base Damage of X. X = 4 minus your opponent's Fervor."
			elif what == "surge_zero":
				body = "Until the end of their next turn, your opponent's duelist's Surge Rate is 0 and cannot be changed by other effects."
			elif what == "endurance_energy":
				body = "For the remainder of Combat, whenever you use Endurance, your duelist gains %d Energy." % maxi(1, int(params.get("energy", 1)))
			elif what == "empower_keeps_text":
				body = "For the remainder of Combat, when you use Empower you still use all of the card's text after Empower."
			elif what == "prevent_first_attack":
				var shield_parts: PackedStringArray = PackedStringArray()
				if int(params.get("stages", 0)) > 0:
					shield_parts.append("%d Energy" % int(params["stages"]))
				if int(params.get("life", 0)) > 0:
					shield_parts.append(_plural(int(params["life"]), "wound", "wounds"))
				body = "Prevent %s of damage from the first attack against you this Combat." % " and ".join(shield_parts)
			elif what == "phase_drain":
				body = "For the remainder of Combat, %s duelist loses %d Energy at the beginning of each of their attack phases." % [
					("your opponent's" if opp else "your"), maxi(1, int(params.get("energy", 1)))]
			elif what == "counts_as_title":
				var lent_school: String = str(params.get("school", ""))
				body = "For the remainder of Combat, the %s attacks you perform from your hand count as having \"%s\" in the title." % [
					school_name(lent_school) if lent_school != "" else "", str(params.get("title", ""))]
			elif what == "reserve_ransom":
				body = "For the remainder of Combat, during your attack phase you may remove %s from your Reserve from the game to remove one of your opponent's %s in play." % [
					_plural(maxi(1, int(params.get("cost", 2))), "card", "cards"),
					type_words(str(params.get("card_type", "drill")), true)]
			elif what == "stop_next":
				var only_kind: String = str(params.get("kind", e.get("kind", "any")))
				var stop_span: String = "during your opponent's next attack phase" if str(e.get("duration", "")) == "next_attack_phase" else "this Combat"
				body = "Stop the next %s performed against you %s." % [
					("attack" if only_kind == "any" else only_kind.capitalize()), stop_span]
			elif what == "after_use_bottom":
				body = "For the remainder of Combat, %s cards you attack with go to the bottom of your Life Deck after use instead of being discarded or removed from the game." % school_name(str(params.get("school", "")))
			elif what == "prevent_strike_damage" and str(e.get("duration", "")) == "next_attack_phase":
				body = "Prevent all damage from Strikes during your opponent's next attack phase."
			elif what == "no_endurance" and params.has("school"):
				body = "For the remainder of Combat, your opponent cannot use Endurance against your %s attacks." % school_name(str(params["school"]))
			elif what == "energy_on_hit":
				body = "For the remainder of Combat, your attacks gain \"Hit: your duelist gains %d Energy.\"" % maxi(1, int(params.get("energy", 2)))
			else:
				var span: String = "For the remainder of Combat" if str(e.get("duration", "combat")) == "combat" else ("Until the end of your next turn" if str(e.get("duration", "")) == "next_turn_end" else "For the rest of the turn")
				body = "%s, %s." % [span, str(FLOAT_TEXT.get(what, what))]
		"forbid":
			var subject: String = "Your opponent may not" if opp else "You may not"
			var forbid_span: String = str(e.get("duration", "combat"))
			var span: String = " for the remainder of Combat" if forbid_span == "combat" else (" during their next attack phase" if forbid_span == "next_attack_phase" else " this turn")
			var whats: PackedStringArray = PackedStringArray()
			for w in e.get("whats", [e.get("what", "")]):
				whats.append(str(FORBID_TEXT.get(str(w), str(w))))
			body = "%s %s%s." % [subject, _or_list(whats), span]
		"lose_aspect":
			body = "Your opponent loses one Aspect." if opp else "Lose one Aspect."
		"advance_aspect":
			body = "Your opponent advances one Aspect." if opp else "Advance one Aspect."
		"set_aspect":
			var t: Variant = e.get("aspect", 1)
			if t is String:
				body = "Move your duelist to the Aspect equal to your Fervor."
			else:
				body = "Set %s duelist to Aspect %d." % [("your opponent's" if who == "your opponent" else "your"), int(t)]
		"no_ascension_win":
			body = "%s cannot win by Ascension for the rest of the game." % _cap(who)
		"attach":
			match str(e.get("to", "in_control")):
				"opponent_duelist":
					body = "Attach this card to your opponent's duelist."
				"opponent_in_control":
					body = "Attach this card to the personality your opponent has in control."
				"opponent_non_combat":
					body = "Attach this card to one of your opponent's Non-Combat cards in play."
				"in_control":
					body = "Attach this card to the personality in control."
				"choose":
					body = "Attach this card to one of your personalities."
				"character":
					body = "Attach this card to that personality."
				"named":
					body = "Attach this card to your %s." % str(e.get("character", ""))
				_:
					body = "Attach this card to your duelist."
		"capture_seal":
			body = "Capture a Seal."
		"name_card" when not (e.get("strip", {}) as Dictionary).is_empty():
			var kind_named: String = str((e.get("filter", {}) as Dictionary).get("attack_kind", ""))
			var what_named: String = "a card" if kind_named == "" else "a card that can perform %s" % _a(kind_named.capitalize())
			if str((e.get("filter", {}) as Dictionary).get("card_type", "")) == "hand_combat":
				what_named = "a Strike, Art or Combat card"
			elif bool((e.get("filter", {}) as Dictionary).get("non_seal", false)):
				what_named = "a card that is not a Seal"
			var one_copy: bool = int((e["strip"] as Dictionary).get("amount", 0)) == 1
			var gone: String = ("remove %s from the game" if str((e["strip"] as Dictionary).get("to", "discard")) == "removed" else "discard %s") % ("it" if one_copy else "them")
			var copies: String = "1 copy of it" if one_copy else "every copy of it"
			if str(e.get("pool", "")) == "library":
				# The opponent does the searching, so the namer is shown nothing.
				body = "Name %s. Your opponent searches their Life Deck for %s and must %s." % [what_named, copies, gone]
			else:
				body = "Name %s. Search your opponent's Life Deck for %s and %s. Shuffle their Life Deck." % [what_named, copies, gone]
		"name_card":
			body = "Name a card. Neither player may play or use it while this is in play, and a copy already in play stops working."
		"next_attack_tax":
			body = "Your opponent pays %d more Energy for their next attack this Combat." % n
		"choose_stop_all_kind":
			body = "Choose Strikes or Arts: all attacks of that kind performed against you are stopped for the remainder of Combat."
		"choose_card_type":
			# One line per choice, each the inner effect read with that card type.
			var choices: PackedStringArray = PackedStringArray()
			for t in e.get("choices", []):
				var inner: Dictionary = (e.get("effect", {}) as Dictionary).duplicate(true)
				inner["card_type"] = str(t)
				choices.append(_lc(effect_text(inner).rstrip(".")))
			var verb: String = choices[0].get_slice(" ", 0) if not choices.is_empty() else ""
			var one_verb: bool = verb != "" and verb.to_lower() != "your"
			for c in choices:
				if c.get_slice(" ", 0) != verb:
					one_verb = false
			if one_verb and choices.size() == 2:
				# "Discard all of your opponent's Allies in play or all of their Drills in play".
				var second: String = choices[1].substr(verb.length() + 1).replace("your opponent's", "their")
				body = "%s or %s." % [_cap(choices[0]), second]
			else:
				body = "Choose one: %s." % " or ".join(choices)
		"recur_source":
			var cost: Dictionary = e.get("cost", {})
			var what: String = "Signature card" if str(cost.get("signature_of", "")) == "duelist" else "card"
			body = "remove a %s from your discard pile to shuffle this card into your Life Deck." % what
		"draw_check":
			var lead: String = "Discard the top card of your Life Deck." if bool(e.get("discard", false)) else "Draw a card."
			if str(e.get("from", "top")) == "bottom":
				lead = "Draw the bottom card of your Life Deck."
			if bool(e.get("reveal", false)):
				lead = lead.trim_suffix(".") + " and show it to your opponent."
			var matched: Array = e.get("effects", [])
			var miss: String = " ".join(PackedStringArray(_texts(e.get("else_effects", []))))
			# A "you may" whose decline does what a miss does needs no "If you do not" of its own:
			# the closing "Otherwise" covers both.
			if matched.size() == 1 and (matched[0] as Dictionary).has("otherwise") and miss != "" \
					and " ".join(PackedStringArray(_texts((matched[0] as Dictionary)["otherwise"]))) == miss:
				var lone: Dictionary = (matched[0] as Dictionary).duplicate()
				lone.erase("otherwise")
				matched = [lone]
			var hit: String = ""
			var check: String = _check_name(e)
			# "If that card is a named card, show it to your opponent and draw another card."
			if not matched.is_empty() and str((matched[0] as Dictionary).get("op", "")) == "show_checked" and not bool((matched[0] as Dictionary).get("may", false)):
				hit = " ".join(PackedStringArray(_texts(matched.slice(1))))
				body = "%s If it is %s, show it to your opponent and %s" % [lead, check, _lc(hit)]
			elif matched.size() == 1 and not ((matched[0] as Dictionary).get("when", {}) as Dictionary).is_empty():
				# One check, one more condition: "If it is X and Y, ..." rather than two "if"s.
				var also: Dictionary = matched[0]
				hit = effect_text(also)
				body = "%s If it is %s and %s, %s" % [lead, check, cond_text(also["when"]), _lc(_effect_body(also))]
			else:
				hit = " ".join(PackedStringArray(_texts(matched)))
				body = "%s If it is %s, %s" % [lead, check, _lc(hit)]
			if lead.begins_with("Draw"):
				body = body.replace(", draw a card.", ", draw another card.").replace(" and draw a card.", " and draw another card.")
			if e.has("else_effects"):
				body += " " + _otherwise(hit, miss)
		"pay_energy":
			body = "Your duelist loses any amount of Energy." if str(e.get("payer", "")) == "duelist" else "Lose any amount of Energy."
		"pay_cost":
			body = "You may pay %d Energy." % n
		"attack_bonus":
			body = "This attack does +%s." % damage_amount(int(e.get("stages", 0)), int(e.get("life", 0)))
		"look_at":
			var pick: Dictionary = e.get("pick", {})
			var what: String = type_words(str(pick.get("card_type", "card")), false)
			if pick.has("title_contains"):
				what = "\"%s\" card" % str(pick["title_contains"])
			if pick.has("tag"):
				what = "%s %s" % [keyword_name(str(pick["tag"])), what]
			var dest_zone: String = "play" if str(e.get("to", "hand")) == "play" else "your hand"
			var seen_deck: String = "your opponent's Life Deck" if str(e.get("whose", "self")) == "opponent" else "your Life Deck"
			var seen: String = "the %s %d cards of %s" % [str(e.get("from", "top")), n, seen_deck]
			if str(e.get("to", "hand")) == "removed":
				# "Remove 1 of them from the game": the pick is mandatory unless nothing there is legal.
				# Seals are never a legal pick, so the wording says so rather than leaving it to the
				# player to find out when the option is missing.
				var one: String = "1 of them that is not a Seal" if pick.is_empty() else "%s among them" % _a(what)
				body = "Look at %s and %s %s from the game." % [seen,
					("remove" if bool(e.get("must", false)) else "you may remove"), one]
			elif bool(e.get("all_matches", false)):
				body = "Look at %s and put every %s among them into %s." % [seen, what, dest_zone]
			else:
				body = "Look at %s. You may put %s from among them into %s." % [seen, _a(what), dest_zone]
			if bool(e.get("rearrange", false)) and not e.has("pick"):
				body = "Look at %s and put them back in any order." % seen
			elif bool(e.get("rearrange", false)):
				# Across the table the end matters, because the owner is not the one setting it, and
				# so does a `rest` that sends the cards to the other end from where they were seen.
				var rest_end: String = str(e.get("rest", e.get("from", "top")))
				var at_end: String = "top" if rest_end == "top" else "the bottom"
				if str(e.get("whose", "self")) == "opponent":
					body += " Put the rest back on %s in any order." % at_end
				elif rest_end != str(e.get("from", "top")):
					body += " Put the rest on %s of your Life Deck in any order." % at_end
				else:
					body += " Put the rest back in any order."
			# "...and put them all on top or all on the bottom" replaces the "back where they were".
			if str(e.get("place", "")) == "choose":
				body = body.replace("put them back in any order", "put them all on top or all on the bottom, in any order")
				body = body.replace("Put the rest back in any order", "Put the rest all on top or all on the bottom, in any order")
			if e.has("play_if") and (e["play_if"] as Dictionary).has("title_contains"):
				var play_title: String = str((e["play_if"] as Dictionary)["title_contains"])
				if body.ends_with(" into your hand."):
					body = body.trim_suffix(".") + ", or a \"%s\" card into play." % play_title
				else:
					body += " A \"%s\" card may go into play instead." % play_title
			if bool(e.get("shuffle_after", false)):
				body += " Shuffle the rest back."
		"choose_forbid_type":
			body = "Choose Strike, Art, or Combat cards. Your opponent cannot use that type for the remainder of Combat"
			if int(e.get("unless_energy_min", 0)) > 0:
				body += " unless their duelist has %d or more Energy" % int(e["unless_energy_min"])
			body += "."
		"return_removed":
			var gone: String = "Allies" if str(e.get("card_type", "")) == "ally" else "cards"
			if e.has("tag"):
				gone = "%s %s" % [keyword_name(str(e["tag"])), gone]
			if str(e.get("character", "")) != "":
				gone = "%s Signature cards" % str(e["character"])
			if bool(e.get("choose", false)) and e.has("max"):
				body = "Choose up to %d of your %s that are removed from the game and shuffle them into your Life Deck." % [int(e["max"]), gone]
			elif bool(e.get("choose", false)):
				body = "Shuffle any of your %s that are removed from the game into your Life Deck." % gone
			else:
				body = "Shuffle your removed %s into your Life Deck." % gone
		"focus_attack":
			body = "This attack is Focused."
		"end_turn":
			body = "The turn ends."
		"force_declare":
			body = "Your opponent must declare Combat this turn."
		"bond":
			body = "Bond the two named Allies: they leave play under their Bond card, which fights as one Ally at full Energy."
		"forbid_both":
			var whats: PackedStringArray = PackedStringArray()
			for w in e.get("whats", []):
				whats.append(str(FORBID_TEXT.get(str(w), str(w))))
			var span: String = " for the remainder of Combat" if str(e.get("duration", "combat")) == "combat" else " this turn"
			body = "Neither player may %s%s." % [_or_list(whats), span]
		"discard_in_play_both":
			var card_type: String = str(e.get("card_type", "non_combat"))
			body = ("Remove all %s in play from the game." if bool(e.get("remove", false)) else "Discard all %s in play.") % _all_words(card_type)
		"spend_source", "finish_source", "after_action", "after_attack", "mark_used":
			return ""
		_:
			body = str(e.get("op", "?"))
	if str(e.get("op", "")) == "energy" and e.has("bank_gain"):
		body += " Your next attack does +X Energy, X = the Energy this gained you, to a maximum of +%d." % int((e["bank_gain"] as Dictionary).get("cap", 0))
	if bool(e.get("may", false)) and str(e.get("asks", "")) == "opponent" and body.begins_with("Your opponent ") \
			and not e.has("then") and (e.get("otherwise", []) as Array).size() == 1:
		# The opponent picks between two outcomes: "Your opponent either discards a card from hand
		# or loses 4 Energy, their choice." / "Unless your opponent discards a card from hand, ..."
		var instead: String = effect_text((e["otherwise"] as Array)[0])
		if instead != "" and not instead.trim_suffix(".").contains(". "):
			var picked: String = body.substr(14).trim_suffix(".")
			if instead.begins_with("Your opponent ") and not instead.begins_with("Your opponent's"):
				return "Your opponent either %s or %s, their choice." % [picked, instead.substr(14).trim_suffix(".")]
			return "Unless your opponent %s, %s" % [picked, _lc(instead)]
	if bool(e.get("may", false)):
		if str(e.get("asks", "")) == "opponent" and body.begins_with("Your opponent "):
			# The choice is theirs, so the line reads as theirs rather than as something you do.
			var theirs: String = body.substr(14)
			var their_verb: String = theirs.get_slice(" ", 0)
			body = "Your opponent may %s%s" % [str(OPPONENT_VERBS.get(their_verb, their_verb)), _base_verbs(theirs.substr(their_verb.length()))]
		elif body.begins_with("Your opponent "):
			var rest: String = body.substr(14)
			var verb: String = rest.get_slice(" ", 0)
			body = "You may have your opponent %s%s" % [str(OPPONENT_VERBS.get(verb, verb)), _base_verbs(rest.substr(verb.length()))]
		elif body.begins_with("You "):
			body = "You may " + body.substr(4)
		else:
			body = "You may " + _lc(body)
	if e.has("then"):
		var follow: PackedStringArray = PackedStringArray()
		for tt in _then_texts(e["then"]):
			if tt != "":
				follow.append(tt)
		if not follow.is_empty():
			var join: String = str(e.get("then_as", ""))
			var op_name: String = str(e.get("op", ""))
			if op_name == "discard_hand" and str(e.get("who", "self")) == "self":
				# The engine reads the top of the discard pile, which is the card just discarded.
				for k in range(follow.size()):
					follow[k] = follow[k].replace("if the top card of your discard pile is ", "if the card you discarded is ")
					if str(e.get("filter", "")) == "signature":
						# "discard one of your duelist's Signature cards ... to search for another".
						follow[k] = follow[k].replace("for one of your duelist's Signature cards", "for another")
			var to_do: PackedStringArray = PackedStringArray()
			if join == "" and _is_cost(e):
				for tt in follow:
					var inf: String = _infinitive(tt)
					if inf == "" or (follow.size() > 1 and tt.trim_suffix(".").contains(". ")):
						to_do.clear()
						break
					to_do.append(inf.trim_suffix("."))
			if join != "":
				# "and" instead of "If you do" for a card whose halves both happen on one yes.
				if body.ends_with("."):
					body = body.substr(0, body.length() - 1)
				body += " %s %s" % [join, _lc(" ".join(follow))]
			elif op_name == "pay_energy":
				body += " For each Energy lost, %s" % _lc(" ".join(follow))
			elif follow.size() == 1 and str(((e["then"] as Array)[0] as Dictionary).get("op", "")) == "exile_source" and bool(e.get("may", false)) and body.begins_with("You may "):
				# "You may remove this card from the game to look at ...": the removal is the price.
				body = "You may remove this card from the game to " + body.substr(8)
			elif not to_do.is_empty():
				# "You may discard a card from your hand to make it Focused": the first half is the price.
				body = "%s to %s." % [body.trim_suffix("."), _join_and(to_do)]
			elif _is_cost(e) and not bool(e.get("may", false)) and op_name != "pay_cost":
				# A cost that is always paid needs no "If you do".
				body += " " + _and_sentences(follow)
			else:
				body += " If you do, " + _lc(_and_sentences(follow))
	if e.has("otherwise"):
		var other: PackedStringArray = PackedStringArray()
		for t in e["otherwise"]:
			var tt: String = effect_text(t)
			if tt != "":
				other.append(_lc(tt) if other.is_empty() else tt)
		var plain_pair: bool = other.size() == 1 and bool(e.get("may", false)) and str(e.get("asks", "")) != "opponent" and not e.has("then") \
			and body.begins_with("You may ") and not body.contains(",") and not body.trim_suffix(".").contains(". ") \
			and not other[0].contains(",") and not other[0].trim_suffix(".").contains(". ")
		if plain_pair:
			# "Attune 2 or Disrupt 2.": a choice between two plain results.
			body = "%s or %s" % [_cap(body.substr(8).trim_suffix(".")), other[0]]
		elif not other.is_empty():
			body += (" If they do not, " if str(e.get("asks", "")) == "opponent" else " If you do not, ") + " ".join(other)
	return body


const OPPONENT_VERBS: Dictionary = {
	"discards": "discard", "removes": "remove", "loses": "lose", "gains": "gain", "takes": "take",
	"draws": "draw", "skips": "skip", "pays": "pay", "must": "", "shuffles": "shuffle",
}

## First words of a line that is already an instruction, so it can follow "to".
const IMPERATIVE_VERBS: Array[String] = [
	"Attune", "Disrupt", "Gain", "Lose", "Draw", "Search", "Discard", "Remove", "Shuffle", "Place",
	"Choose", "Raise", "Lower", "Look", "Capture", "Stop", "Set", "Take", "Put", "Show", "Attach",
	"Prevent", "Name", "Advance", "End", "Skip", "Move",
]

## The ops that spend something of yours, which a card reads as a price: "X to Y".
const COST_OPS: Array[String] = [
	"discard_hand", "discard_in_play", "remove_discard", "remove_reserve", "pay_cost", "lose_aspect",
	"show_checked", "exile_source", "discard_life", "recover",
]


static func _is_cost(e: Dictionary) -> bool:
	var op: String = str(e.get("op", ""))
	if str(e.get("who", "self")) != "self":
		return false
	if op == "energy":
		var raw: Variant = e.get("amount", 0)
		return not (raw is String) and int(raw) < 0
	return op in COST_OPS


## "and draws that many cards" after a verb already turned into "draw": every verb in the line
## follows the first one.
static func _base_verbs(rest: String) -> String:
	var out: String = rest
	for k in OPPONENT_VERBS.keys():
		if str(OPPONENT_VERBS[k]) != "":
			out = out.replace(" and %s " % str(k), " and %s " % str(OPPONENT_VERBS[k]))
	return out


## A line as the second half of "X to Y", or "" when it does not read as one. Only its first
## sentence changes; any sentence after it follows as it was.
static func _infinitive(s: String) -> String:
	var text: String = s.strip_edges()
	var cut: int = text.find(". ")
	var first: String = text if cut < 0 else text.substr(0, cut + 1)
	var rest: String = "" if cut < 0 else text.substr(cut + 1)
	var word: String = first.get_slice(" ", 0)
	var out: String = ""
	if word in IMPERATIVE_VERBS:
		out = _lc(first)
	elif first == "This attack is Focused.":
		out = "make it Focused."
	elif first.begins_with("This attack does "):
		out = "have this attack do " + first.substr(17)
	elif first.begins_with(REMAINDER + "your ") and not first.substr(REMAINDER.length()).contains(","):
		out = "have %s for the remainder of Combat." % first.substr(REMAINDER.length()).trim_suffix(".")
	else:
		for subject in ["Your opponent's duelist ", "Your opponent "]:
			if first.begins_with(subject):
				var tail: String = first.substr(subject.length())
				var v: String = tail.get_slice(" ", 0)
				if str(OPPONENT_VERBS.get(v, "")) != "":
					out = "make %s%s%s" % [_lc(subject), str(OPPONENT_VERBS[v]), _base_verbs(tail.substr(v.length()))]
				break
	if out == "":
		return ""
	return out + rest


## Sentences that happen together, as one: "Attune 1 and gain 6 Energy." A list holding a
## longer instruction keeps its sentences as they are.
static func _and_sentences(parts: PackedStringArray) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	var clauses: PackedStringArray = PackedStringArray()
	for k in range(parts.size()):
		var clause: String = parts[k].strip_edges().trim_suffix(".")
		if clause.contains(". "):
			return " ".join(parts)
		if k > 0:
			clause = _lc(clause)
			# "and your Strikes do +2 Energy for the remainder of Combat": the span goes last.
			if clause.begins_with(_lc(REMAINDER)) and not clause.substr(REMAINDER.length()).contains(","):
				clause = "%s for the remainder of Combat" % clause.substr(REMAINDER.length())
		clauses.append(clause)
	return _join_and(clauses) + "."


## "Attune 1, or Attune 2" / "your Strikes do +1 Energy, or +3 Energy": the usual result, then
## the better one. Three or more shared opening words are said once.
static func _or_instead(miss: String, hit: String) -> String:
	var a: PackedStringArray = miss.trim_suffix(".").split(" ")
	var b: PackedStringArray = hit.trim_suffix(".").split(" ")
	var same: int = 0
	while same < mini(a.size(), b.size()) - 1 and a[same] == b[same]:
		same += 1
	var better: String = " ".join(b.slice(same)) if same >= 3 else _lc(hit.trim_suffix("."))
	return "%s, or %s" % [miss.trim_suffix("."), better]

## Label-style triggers; their condition sits inside the instruction.
const COLON_TRIGGERS: Dictionary = {"use": "Use in Combat", "relic_use": "", "opponent_declare": "Use during your opponent's Declare step"}


static func _trigger_head(e: Dictionary) -> String:
	match str(e.get("trigger", "secondary")):
		"before_damage":
			return "Hit, instead of dealing damage"
		"if_successful":
			return "Hit"
		"if_stopped":
			return "If stopped"
		"on_place":
			return "When placed"
		"turn_start":
			if str(e.get("on_turn", "")) == "opponent":
				return "At the start of your opponent's turn"
			if bool(e.get("each_turn", false)):
				return "At the start of each turn"
			return "At the start of your turn"
		"on_attack":
			return "When you perform an attack"
		"on_success":
			return "After a successful attack"
		"on_stopped":
			return "When your opponent stops your attack"
		"on_stop":
			return "Whenever you stop an attack"
		"on_damaged":
			return "When you take damage from an attack"
		"rejuvenation":
			return "During your Recover step"
		"discard_step":
			return "At the beginning of each Discard step"
		"on_wound":
			var head: String = "If this card is discarded from your Life Deck"
			if str(e.get("at", "")) == "fight_back":
				head += ", at the start of the next fight-back phase this turn"
			elif str(e.get("at", "")) == "turn_end":
				head += ", at the end of the turn"
			return head
		"entering_combat":
			var head: String = "When entering Combat"
			if str(e.get("role", "")) != "":
				head += " as the %s" % role_name(str(e["role"]))
			return head
		_:
			return ""


static func effect_text(e: Dictionary) -> String:
	var body: String = _effect_body(e)
	if body == "":
		return ""
	var head_when: Array = _head_and_when(e)
	var when: Dictionary = head_when[1]
	var trigger: String = str(e.get("trigger", "secondary"))
	if COLON_TRIGGERS.has(trigger):
		var label: String = str(COLON_TRIGGERS[trigger])
		var inner: String = _conditional(when, body)
		return inner if label == "" else "%s: %s" % [label, inner]
	var lead: Array = _lead(str(head_when[0]), when)
	return str(lead[0]) + (body if bool(lead[1]) else _lc(body))


## What an optional effect does once its owner says yes, for the prompt that asks. The trigger
## and condition have already been met by then, so only the instruction remains, minus the "may".
## The two sides of a "you may" named as actions rather than as a yes and a no, so the choice reads
## "Draw from your discard pile" against "Leave it" instead of "Yes, do it" against "No, skip it".
## A card that says "otherwise" makes the decline an action of its own, and that is what it says.
static func may_action(e: Dictionary) -> String:
	var opp: bool = str(e.get("who", "self")) == "opponent"
	var n: int = int(e.get("amount", 1))
	match str(e.get("op", "")):
		"draw_discard":
			return "Draw from your discard pile" if str(e.get("from", "top")) != "bottom" else "Draw the bottom of your discard pile"
		"discard_hand":
			return "Make them discard" if opp else "Discard from your hand"
		"discard_life":
			return "Take %s" % _plural(n, "wound", "wounds")
		"fervor":
			if opp:
				return "Disrupt %d" % absi(n) if n < 0 else "Raise their Fervor %d" % n
			return "Attune %d" % n if n > 0 else "Lower your Fervor %d" % absi(n)
		"energy":
			return "Take the Energy"
		"lose_aspect":
			return "Lose an Aspect"
		"return_removed":
			return "Take it back from the removed pile"
		"recur_source":
			return "Pay to keep this card"
		"search":
			return "Search for it"
		"choose_card_type":
			return "Do it instead of the damage"
		"discard_in_play":
			if not opp:
				return "Discard one"
			return "Discard one of theirs" if bool(e.get("choose", false)) else "Make them discard one"
	var text: String = may_text(e)
	return text if text != "" else "Do it"


static func may_decline(e: Dictionary) -> String:
	if e.has("otherwise") and e["otherwise"] is Array:
		var lines: PackedStringArray = PackedStringArray()
		for t in e["otherwise"]:
			if t is Dictionary:
				lines.append(may_action(t))
		if not lines.is_empty():
			return " ".join(lines)
	return "Leave it"


static func may_text(e: Dictionary) -> String:
	var plain: Dictionary = e.duplicate(true)
	for key in ["may", "trigger", "when", "at"]:
		plain.erase(key)
	var text: String = ""
	if str(plain.get("op", "")) == "" and plain.has("then"):
		var lines: PackedStringArray = PackedStringArray()
		for t in plain["then"]:
			var tt: String = effect_text(t)
			if tt != "":
				lines.append(tt)
		text = " ".join(lines)
	else:
		text = effect_text(plain)
	if bool(e.get("skip_damage", false)):
		text += " The attack then deals no damage."
	return text.strip_edges()


## Effects as lines; same trigger and condition fold into one sentence.
static func effects_text(effects: Array) -> PackedStringArray:
	var merged: Array[Dictionary] = _merge_pairs(effects)
	var lines: PackedStringArray = PackedStringArray()
	var i: int = 0
	while i < merged.size():
		var e: Dictionary = merged[i]
		var key: String = _group_key(e)
		var group: Array[Dictionary] = [e]
		var j: int = i + 1
		while key != "" and j < merged.size() and _group_key(merged[j]) == key:
			group.append(merged[j])
			j += 1
		i = j
		if group.size() == 1:
			var s: String = effect_text(e)
			if s != "" and not lines.has(s):
				lines.append(s)
			continue
		var trigger: String = str(e.get("trigger", "secondary"))
		if COLON_TRIGGERS.has(trigger):
			var inners: PackedStringArray = PackedStringArray()
			for g in group:
				var body: String = _effect_body(g)
				if body != "":
					inners.append(_conditional(_text_when(g), body))
			var label: String = str(COLON_TRIGGERS[trigger])
			lines.append(" ".join(inners) if label == "" else "%s: %s" % [label, " ".join(inners)])
			continue
		var bodies: PackedStringArray = PackedStringArray()
		var simple: bool = true
		for g in group:
			var body: String = _effect_body(g)
			if body == "":
				continue
			if body.contains(". "):
				simple = false
			bodies.append(body)
		var head_when: Array = _head_and_when(e)
		var lead: Array = _lead(str(head_when[0]), head_when[1])
		var prefix: String = str(lead[0])
		var keep_case: bool = bool(lead[1])
		if simple:
			var clauses: PackedStringArray = PackedStringArray()
			var stacked: bool = false
			for k in range(bodies.size()):
				var clause: String = bodies[k].trim_suffix(".")
				clause = clause if keep_case and k == 0 else _lc(clause)
				# "your opponent loses one Aspect and cannot gain Fervor": one subject, said once.
				if k > 0 and clause.begins_with("your opponent ") and clauses[k - 1].to_lower().begins_with("your opponent "):
					clause = clause.substr(14)
				# "and your attacks do +2 wounds for the remainder of Combat": the span goes last.
				if k > 0 and clause.begins_with(_lc(REMAINDER)) and not clause.substr(REMAINDER.length()).contains(","):
					clause = "%s for the remainder of Combat" % clause.substr(REMAINDER.length())
				if clause.contains(" and "):
					stacked = true
				clauses.append(clause)
			# A clause that already has an "and" would stack another, so the steps read in order.
			lines.append("%s%s." % [prefix, ", then ".join(clauses) if stacked else _join_and(clauses)])
		else:
			var rest: PackedStringArray = PackedStringArray()
			for k in range(1, bodies.size()):
				rest.append(bodies[k])
			lines.append("%s%s %s" % [prefix, (bodies[0] if keep_case else _lc(bodies[0])), " ".join(rest)])
	return _fold_lines(lines)


const REMAINDER: String = "For the remainder of Combat, "


## Two standing effects with the same span read as one sentence, and a second conditional Hit
## line follows the first instead of repeating "Hit:".
static func _fold_lines(lines: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for line in lines:
		var last: String = out[out.size() - 1] if not out.is_empty() else ""
		if last.begins_with(REMAINDER) and line.begins_with(REMAINDER) and not last.trim_suffix(".").contains(". ") and not line.trim_suffix(".").contains(". "):
			var a: String = last.substr(REMAINDER.length()).trim_suffix(".")
			var b: String = line.substr(REMAINDER.length()).trim_suffix(".")
			var a_words: PackedStringArray = a.split(" ")
			var b_words: PackedStringArray = b.split(" ")
			if a_words.size() > 2 and b_words.size() > 2 and a_words[0] == b_words[0] and a_words[1] == b_words[1]:
				b = " ".join(b_words.slice(2))
			out[out.size() - 1] = "%s%s%s%s." % [REMAINDER, a, (", and " if a.contains(",") else " and "), b]
			continue
		if last.begins_with("Hit: ") and line.begins_with("Hit: If "):
			out.append("Then, if " + line.substr(8))
			continue
		# "When entering Combat as the attacker, or as the defender if X, ...": one effect, two ways in.
		var as_attacker: String = "When entering Combat as the attacker, "
		var as_defender: String = "When entering Combat as the defender, if "
		if last.begins_with(as_attacker) and line.begins_with(as_defender):
			var did: String = last.substr(as_attacker.length())
			if line.ends_with(", " + did):
				var cond: String = line.substr(as_defender.length(), line.length() - as_defender.length() - did.length() - 2)
				out[out.size() - 1] = "When entering Combat as the attacker, or as the defender if %s, %s" % [cond, did]
				continue
		out.append(line)
	return out


## Forbidden things joined by "or", the shared opening said once: "use cards that end Combat or
## stop all attacks", "use a Mastery or a Relic".
static func _or_list(items: PackedStringArray) -> String:
	if items.size() <= 1:
		return "".join(items)
	var first: PackedStringArray = items[0].split(" ")
	var shared: int = first.size() - 1
	for k in range(1, items.size()):
		var other: PackedStringArray = items[k].split(" ")
		var same: int = 0
		while same < mini(shared, other.size() - 1) and first[same] == other[same]:
			same += 1
		shared = same
	# An article stays with its noun.
	while shared > 0 and first[shared - 1] in ["a", "an", "the"]:
		shared -= 1
	var out: PackedStringArray = PackedStringArray([items[0]])
	for k in range(1, items.size()):
		out.append(" ".join(items[k].split(" ").slice(shared)))
	return " or ".join(out)


static func _join_and(parts: PackedStringArray) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	if parts.size() == 2:
		return "%s and %s" % [parts[0], parts[1]]
	var head: PackedStringArray = parts.slice(0, parts.size() - 1)
	return "%s, and %s" % [", ".join(head), parts[parts.size() - 1]]


## "" keeps a plain unconditional line on its own.
static func _group_key(e: Dictionary) -> String:
	var trigger: String = str(e.get("trigger", "secondary"))
	if COLON_TRIGGERS.has(trigger):
		return trigger
	if _trigger_head(e) == "" and not e.has("when"):
		return ""
	return "%s|%s|%s|%s" % [trigger, JSON.stringify(e.get("when", {})), str(e.get("role", "")), str(e.get("at", ""))]


## Self-and-opponent forbids or board clears become one "both" effect; forbids on one player fold.
static func _merge_pairs(effects: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var used: Dictionary = {}
	for i in range(effects.size()):
		if used.has(i):
			continue
		var e: Dictionary = effects[i]
		var op: String = str(e.get("op", ""))
		if op == "forbid" or op == "set_fervor" or (op == "discard_in_play" and bool(e.get("all", false))):
			for j in range(i + 1, effects.size()):
				if used.has(j):
					continue
				var f: Dictionary = effects[j]
				# "Your opponent may not lower your Aspect" and "you may not lower your own" are one
				# rule for both players about the same Aspect.
				var own_aspect: bool = op == "forbid" and [str(e.get("what", "")), str(f.get("what", ""))] in [["lower_aspect", "lower_own_aspect"], ["lower_own_aspect", "lower_aspect"]] \
					and _who(e if str(e.get("what", "")) == "lower_aspect" else f) == "your opponent"
				var same_what: bool = str(e.get("what", "")) == str(f.get("what", "")) or own_aspect
				if _same_frame(e, f) and str(f.get("op", "")) == op and _who(e) != _who(f) and same_what and str(e.get("card_type", "")) == str(f.get("card_type", "")) and bool(e.get("remove", false)) == bool(f.get("remove", false)) and str(e.get("duration", "combat")) == str(f.get("duration", "combat")) and int(e.get("amount", 0)) == int(f.get("amount", 0)):
					used[j] = true
					var both: Dictionary = e.duplicate()
					both["op"] = op + "_both"
					both["whats"] = ["lower_aspect" if own_aspect else e.get("what", "")]
					e = both
					break
		if op == "forbid" and str(e.get("op", "")) == "forbid":
			var whats: Array = [e.get("what", "")]
			for j in range(i + 1, effects.size()):
				if used.has(j):
					continue
				var f: Dictionary = effects[j]
				if _same_frame(e, f) and str(f.get("op", "")) == "forbid" and _who(e) == _who(f) and str(e.get("duration", "combat")) == str(f.get("duration", "combat")):
					used[j] = true
					whats.append(f.get("what", ""))
			if whats.size() > 1:
				var joined: Dictionary = e.duplicate()
				joined["whats"] = whats
				e = joined
		elif str(e.get("op", "")) == "forbid_both":
			var whats: Array = e["whats"]
			for j in range(i + 1, effects.size()):
				if used.has(j):
					continue
				var f: Dictionary = effects[j]
				if _same_frame(e, f) and str(f.get("op", "")) == "forbid" and str(e.get("duration", "combat")) == str(f.get("duration", "combat")):
					for k in range(j + 1, effects.size()):
						var g: Dictionary = effects[k]
						if not used.has(k) and _same_frame(e, g) and str(g.get("op", "")) == "forbid" and _who(g) != _who(f) and str(g.get("what", "")) == str(f.get("what", "")):
							used[j] = true
							used[k] = true
							whats.append(f.get("what", ""))
							break
		out.append(e)
	return out


static func _same_frame(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("trigger", "")) == str(b.get("trigger", "")) and JSON.stringify(a.get("when", {})) == JSON.stringify(b.get("when", {})) and bool(a.get("after_empower", false)) == bool(b.get("after_empower", false))


## "Otherwise, ..." after a branch. When the two branches open with the same five or more words
## ("for the remainder of Combat, your Strikes do +3 Energy" / "...+1 Energy"), only the part
## that differs is repeated: "Otherwise, +1 Energy."
static func _otherwise(hit: String, miss: String) -> String:
	var a: PackedStringArray = hit.split(" ")
	var b: PackedStringArray = miss.split(" ")
	var same: int = 0
	while same < mini(a.size(), b.size()) - 1 and a[same] == b[same]:
		same += 1
	if same >= 5:
		return "Otherwise, %s" % " ".join(b.slice(same))
	return "Otherwise, %s" % _lc(miss)


## A "then" list as sentences. Two discards that differ only in being at random, split on a
## condition and its opposite, read as one: "your opponent discards a card from hand, at random
## if the top card of your discard pile is Shade."
static func _then_texts(effects: Array) -> Array[String]:
	var out: Array[String] = []
	var skip: Dictionary = {}
	for i in range(effects.size()):
		if skip.has(i):
			continue
		var e: Dictionary = effects[i]
		if i + 1 < effects.size():
			var at_random: Dictionary = _random_split(e, effects[i + 1])
			if not at_random.is_empty():
				skip[i + 1] = true
				out.append(effect_text(at_random["plain"]).trim_suffix(".") + ", at random if %s." % cond_text(at_random["when"]))
				continue
		out.append(effect_text(e))
	return out


## {plain, when} when `a` and `b` are the same discard, one at random under a school check and the
## other not at random under its opposite; empty otherwise.
static func _random_split(a: Dictionary, b: Dictionary) -> Dictionary:
	if str(a.get("op", "")) != "discard_hand" or str(b.get("op", "")) != "discard_hand":
		return {}
	var ra: Dictionary = a.duplicate()
	var rb: Dictionary = b.duplicate()
	var wa: Dictionary = ra.get("when", {})
	var wb: Dictionary = rb.get("when", {})
	for w in [[wa, wb], [wb, wa]]:
		var yes: Dictionary = w[0]
		var no: Dictionary = w[1]
		if yes.size() == 1 and no.size() == 1 and yes.has("discard_top_school") and str(no.get("discard_top_school_not", "")) == str(yes["discard_top_school"]):
			var random_side: Dictionary = ra if yes == wa else rb
			var plain_side: Dictionary = rb if yes == wa else ra
			if not bool(random_side.get("random", false)) or bool(plain_side.get("random", false)):
				return {}
			for d in [ra, rb]:
				d.erase("when")
				d["random"] = false
			if ra != rb:
				return {}
			return {"plain": plain_side, "when": yes}
	return {}


static func _texts(effects: Array) -> Array[String]:
	var out: Array[String] = []
	for e in effects:
		out.append(effect_text(e))
	return out


static func search_text(e: Dictionary) -> String:
	var body: String = _search_text_body(e)
	if bool(e.get("show", false)):
		var one: bool = int(e.get("amount", 1)) == 1
		if body.contains(" and put "):
			body = body.replace(" and put ", ", show %s to your opponent and put " % ("it" if one else "them"))
		else:
			body += " Show %s to your opponent." % ("it" if one else "them")
	var if_all: Dictionary = e.get("if_all", {})
	if not if_all.is_empty():
		body += " If they are all %s, %s" % [type_words(str(if_all.get("card_type", "card")), true),
			_lc(" ".join(effects_text(if_all.get("effects", []))))]
	return body


## "Caedan Vale or Tavin Vale" from a list, or the one name as it is.
static func _or_names(v: Variant) -> String:
	if v is Array:
		var names: PackedStringArray = PackedStringArray()
		for n in v:
			names.append(str(n))
		return " or ".join(names)
	return str(v)


static func _search_text_body(e: Dictionary) -> String:
	var source: String = str(e.get("source", "deck"))
	var from: String = "your Life Deck"
	match source:
		"discard":
			from = "your discard pile"
		"either":
			from = "your Life Deck or discard pile"
		"reserve":
			from = "your Reserve"
	if str(e.get("whose", "self")) == "opponent":
		from = "your opponent's Life Deck"
	var card_type: String = str(e.get("card_type", "card"))
	var qual: PackedStringArray = PackedStringArray()
	if str(e.get("school", "*")) != "*":
		qual.append(school_name(str(e["school"])))
	if e.has("school_in"):
		var names: PackedStringArray = PackedStringArray()
		for s in e["school_in"]:
			names.append(school_name(str(s)) if str(s) != "" else "Freestyle")
		qual.append(" or ".join(names))
	if bool(e.get("different", false)):
		qual.append("different")
	if e.has("school_not"):
		qual.append("non-%s" % school_name(str(e["school_not"])))
	if str(e.get("title_contains", "")) != "":
		qual.append("\"%s\"" % str(e["title_contains"]))
	if str(e.get("tag", "")) != "":
		qual.append(str(e["tag"]).capitalize())
	var duelists_own: bool = str(e.get("signature_of", "")) == "duelist"
	if duelists_own:
		qual.append("Signature")
	if str(e.get("character", "")) != "":
		qual.append("%s Signature" % _or_names(e["character"]))
	if e.has("alignment_only"):
		qual.append("\"%ss only\"" % str(e["alignment_only"]).capitalize())
	if e.has("aspect"):
		qual.append("Aspect %d" % int(e["aspect"]))
	var n: int = int(e.get("amount", 1))
	var noun: String = (" ".join(qual) + " " if not qual.is_empty() else "") + type_words(card_type, n != 1)
	# A search of the Life Deck always allows taking nothing, so asking for several is "up to". A
	# `must` pick from another pile takes the full number when there are that many.
	var must: bool = bool(e.get("must", false)) and source != "deck" and source != "either"
	var what: String = _a(noun) if n == 1 else ("%d %s" if must else "up to %d %s") % [n, noun]
	if duelists_own:
		# Only your duelist's own Signature cards count, so the line names whose they are.
		var theirs: String = (" ".join(qual) + " ") + type_words(card_type, true)
		what = ("one of your duelist's %s" % theirs) if n == 1 else (("%d of your duelist's %s" if must else "up to %d of your duelist's %s") % [n, theirs])
	if e.has("has_effect"):
		var spec: Dictionary = e["has_effect"]
		if str(spec.get("op", "")) == "discard_hand" and str(spec.get("who", "")) == "opponent":
			what += " that makes your opponent discard from hand"
		else:
			what += " with a \"%s\" effect" % str(spec.get("op", "")).replace("_", " ")
	if bool(e.get("adds_damage", false)):
		what += " that adds damage to your attacks"
	if str(e.get("exclude_title", "")) != "":
		what += " other than \"%s\"" % str(e["exclude_title"])
	if str(e.get("attack_kind", "")) != "":
		what += " that can perform %s" % _a(str(e["attack_kind"]).capitalize())
		if e.has("max_base_life"):
			what += " with a Base Damage of %d wounds or fewer" % int(e["max_base_life"])
	var dest: String = "your hand"
	if str(e.get("to", "hand")) == "play":
		var at: Variant = e.get("stages")
		if at is String and str(at) == "max":
			dest = "play at full Energy"
		else:
			dest = "play" + (" at Energy %d" % int(at) if e.has("stages") else "")
	# "Choose a card from your discard pile for each Marble Seal in play": the count rides on the pick.
	var each: String = ""
	if e.has("amount_per_set_seal"):
		what = _a(type_words(card_type, false))
		each = " for each %s Seal in play" % str(e["amount_per_set_seal"]).capitalize()
	if str(e.get("amount_from", "")) == "fervor":
		what = _a(type_words(card_type, false))
		each = " for each point of your Fervor"
		n = 2
	var tail: String = ""
	var plural_pick: bool = n != 1 or e.has("amount_per_set_seal")
	from += each
	if source == "hand":
		return "Place %s from your hand into play." % what
	if str(e.get("to", "hand")) == "deck_bottom":
		return "Choose %s from %s and place %s on the bottom of your Life Deck.%s" % [what, from, ("them" if plural_pick else "it"), tail]
	if str(e.get("to", "hand")) == "deck_shuffle":
		return "Choose %s from %s and shuffle %s into your Life Deck.%s" % [what, from, ("them" if plural_pick else "it"), tail]
	if str(e.get("to", "hand")) == "deck_top":
		return "Choose %s from %s and place %s on top of your Life Deck.%s" % [what, from, ("them" if plural_pick else "it"), tail]
	if str(e.get("to", "hand")) == "attack":
		return "Search %s for %s and perform it during this attack phase." % [from, what]
	if str(e.get("to", "hand")) == "removed":
		return "Search %s for %s and remove %s from the game." % [from, what, ("it" if n == 1 else "them")]
	if str(e.get("to", "hand")) == "discard":
		return "Search %s for %s and discard %s." % [from, what, ("it" if n == 1 else "them")]
	if must:
		return "Choose %s from %s and put %s into %s." % [what, from, ("it" if n == 1 else "them"), dest]
	return"Search %s for %s and put %s into %s." % [from, what, ("it" if n == 1 else "them"), dest]


## A school modifier that sits beside a matching one for every attack stacks with it in play, so
## the card reads it as the total and says "instead" rather than printing two separate bonuses the
## player has to add up. Anything without that pairing comes back untouched.
static func _rolled_up(m: Dictionary, all: Array) -> Dictionary:
	# A `when` narrows a modifier the same way a school does, so it rolls up the same way: the
	# Drill that pays +1 to anyone and +1 more to a keyword prints as "+2 instead", as its card does.
	if not m.has("school") and not m.has("when"):
		return m
	var rolled: Dictionary = m.duplicate(true)
	var stacked: bool = false
	for other in all:
		var o: Dictionary = other
		if o.has("school") or o.has("when") or str(o.get("scope", "own")) != str(m.get("scope", "own")) or str(o.get("kind", "any")) != str(m.get("kind", "any")):
			continue
		rolled["stages"] = int(rolled.get("stages", 0)) + int(o.get("stages", 0))
		rolled["life"] = int(rolled.get("life", 0)) + int(o.get("life", 0))
		stacked = true
	if stacked:
		rolled["instead"] = true
	return rolled


static func modifier_text(m: Dictionary) -> String:
	var kind: String = str(m.get("kind", "any"))
	var scope: String = str(m.get("scope", "own"))
	var what: String = "attacks" if kind == "any" else kind.capitalize() + "s"
	if m.has("school"):
		what = school_name(str(m["school"])) + " " + what
	if m.has("title_contains"):
		what = "\"%s\" %s" % [str(m["title_contains"]), what]
	if m.has("tag"):
		what = "%s %s" % [keyword_name(str(m["tag"])), what]
	if m.has("only_tag"):
		what = "%s-only %s" % [keyword_name(str(m["only_tag"])), what]
	if bool(m.get("duelist_named", false)):
		what = "%s with your duelist's Signature cards" % what
	var parts: PackedStringArray = PackedStringArray()
	if int(m.get("stages", 0)) != 0:
		parts.append("%+d Energy" % int(m["stages"]))
	if int(m.get("life", 0)) != 0:
		parts.append("%+d %s" % [int(m["life"]), "wound" if absi(int(m["life"])) == 1 else "wounds"])
	var amount: String = " and ".join(parts)
	if bool(m.get("per_ally", false)) and m.has("ally_tag"):
		amount += " for each %s Ally in play" % keyword_name(str(m["ally_tag"]))
	elif bool(m.get("per_ally", false)):
		amount += " for each Ally you have in play"
	if bool(m.get("per_personality", false)):
		amount += " for each personality you have in play"
	if str(m.get("per_bloodline", "")) != "":
		amount += " for each %s personality you have in play" % bloodline_name(str(m["per_bloodline"]))
	if bool(m.get("per_fervor", false)):
		amount = amount.replace("+1 ", "+X ") + ", X = your Fervor"
	if bool(m.get("life_per_performer_surge", false)):
		amount = "+X wounds, X = the Surge of the personality performing the attack"
	var s: String = ""
	if m.has("cap_stages") or m.has("cap_life"):
		# "A maximum of 3 power stages of damage": a ceiling on what lands, not a reduction.
		var caps: PackedStringArray = PackedStringArray()
		if m.has("cap_stages"):
			caps.append("%d Energy" % int(m["cap_stages"]))
		if m.has("cap_life"):
			caps.append("%d %s" % [int(m["cap_life"]), "wound" if int(m["cap_life"]) == 1 else "wounds"])
		s = "%s against you deal at most %s." % [_cap(what), " and ".join(caps)]
		if m.has("when"):
			s = _conditional(m["when"], s)
		return s
	if scope == "opponent_cost":
		# A tax on the other side: "your opponent's attacks cost an additional +1".
		s = "Your opponent's %s cost %d more Energy to perform%s." % [what, int(m.get("stages", 0)), (" instead" if bool(m.get("instead", false)) else "")]
		if m.has("when"):
			s = _conditional(m["when"], s)
		return s
	if scope == "cost":
		# A price, not damage: `set` fixes it, `stages` shifts it with an optional floor.
		if m.has("only_cost"):
			s = "Your %s that cost %d Energy to perform cost %d instead." % [what, int(m["only_cost"]), int(m.get("set", m["only_cost"]))]
		elif m.has("set"):
			s = "Your %s cost no Energy to perform." % what if int(m["set"]) == 0 else "Your %s cost %d Energy to perform." % [what, int(m["set"])]
		else:
			var shift: int = int(m.get("stages", 0))
			s = "Your %s cost %d %s Energy to perform" % [what, absi(shift), ("less" if shift < 0 else "more")]
			if m.has("min"):
				s += ", to a minimum of %d" % int(m["min"])
			s += "."
		if m.has("when"):
			s = _conditional(m["when"], s)
		return s
	if bool(m.get("once", false)):
		# A card used "when performing an attack" boosts the attack it rides on, not a later one.
		s = ("That attack does %s." if bool(m.get("this_attack", false)) else "Your next attack does %s.") % amount
	elif scope == "own" and (m.get("when", {}) as Dictionary).size() == 1 and str((m.get("when", {}) as Dictionary).get("performed_by", "")) == "ally":
		# "Attacks your Allies perform do +2 Energy."
		return "%s your Allies perform do %s." % [_cap(what), amount]
	elif scope == "own":
		s = "Your %s do %s%s." % [what, amount, (" instead" if bool(m.get("instead", false)) else "")]
	else:
		s = "%s against you do %s." % [_cap(what), amount.replace("+", "-")]
	if m.has("when"):
		s = _conditional(m["when"], s)
	return s


## Power, constants, Defense Shield of one aspect.
## A personality card is one Aspect, so `aspect` only says which number to print; the numbers
## always come from this card's own row.
static func aspect_text(def: CardDef, aspect: int = 0) -> PackedStringArray:
	var t: int = def.aspect if def.aspect > 0 else aspect
	var td: Dictionary = def.aspect_data(t)
	var lines: PackedStringArray = PackedStringArray()
	var pw: Dictionary = td.get("power", {})
	var power: PackedStringArray = PackedStringArray()
	if pw.has("attack"):
		power.append(attack_text(pw["attack"]))
		for v in pw["attack"].get("variants", []):
			power.append(_conditional(v.get("when", {}), variant_text(v)))
	if pw.has("defense"):
		power.append(defense_text(pw["defense"]))
	power.append_array(effects_text(pw.get("effects", [])))
	var uses: int = int(pw.get("uses", 1))
	if uses >= 99:
		power.append("May be used any number of times per Combat.")
	elif uses > 1:
		power.append("May be used %s per Combat." % ("twice" if uses == 2 else "%d times" % uses))
	var extra: Dictionary = pw.get("extra_use", {})
	if not extra.is_empty():
		var cost_filter: String = str(extra.get("filter", ""))
		var paid: String = "a card"
		if cost_filter.begins_with("tag:"):
			paid = "%s card" % keyword_name(cost_filter.substr(4))
		power.append("You may discard %s from your hand to use this Power %s this Combat." % [
			_a(paid), ("a second time" if int(extra.get("uses", 1)) == 1 else "%d more times" % int(extra.get("uses", 1)))])
	if bool(pw.get("no_control_needed", false)) and not power.is_empty():
		# The one thing a player cannot work out from the table: an Ally who answers from the side.
		power.append("This personality does not have to be in control to use this Power.")
	if not power.is_empty():
		lines.append("Power: " + " ".join(power))
	# An Aspect that prints two Powers offers one or the other, so the second gets its own line.
	var alt: Dictionary = td.get("power_alt", {})
	if not alt.is_empty():
		var alt_lines: PackedStringArray = PackedStringArray()
		if alt.has("attack"):
			alt_lines.append(attack_text(alt["attack"]))
		if alt.has("defense"):
			alt_lines.append(defense_text(alt["defense"]))
		alt_lines.append_array(effects_text(alt.get("effects", [])))
		if not alt_lines.is_empty():
			lines.append("Power, instead: " + " ".join(alt_lines))
	var constant: PackedStringArray = constant_text(td.get("constant", {}))
	if not constant.is_empty():
		lines.append("Constant: " + " ".join(constant))
	if str(td.get("shield", "")) != "":
		var shield: String = str(td["shield"])
		lines.append("Defense Shield: stops the first unstopped %s each Combat." % ("attack" if shield == "any" else shield.capitalize()))
	return lines


static func constant_text(c: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if bool(c.get("first_styled_unstoppable", false)):
		lines.append("Your first attack each Combat with a school card cannot be stopped.")
	if bool(c.get("attacks_focused", false)) and c.has("attacks_focused_tag"):
		lines.append("Attacks performed by %s personalities are Focused." % keyword_name(str(c["attacks_focused_tag"])))
	elif bool(c.get("attacks_focused", false)):
		lines.append("All of your attacks are Focused.")
	var focus_tag: String = str(c.get("focus_tag", ""))
	if focus_tag != "":
		var fk: String = str(c.get("focus_tag_kind", "any"))
		lines.append("All %s %s you perform are Focused." % [
			keyword_name(focus_tag), ("attacks" if fk == "any" else fk.capitalize() + "s")])
	var table_self: int = int(c.get("strike_table_self", 0))
	var table_against: int = int(c.get("strike_table_against", 0))
	if table_self != 0 or table_against != 0:
		var halves: PackedStringArray = PackedStringArray()
		if table_self != 0:
			halves.append("%+d when this personality performs it" % table_self)
		if table_against != 0:
			halves.append("%+d when it is performed against this personality" % -table_against)
		lines.append("Strike Table Base Damage is %s." % " and ".join(halves))
	if bool(c.get("damage_removes", false)):
		lines.append("Wounds from your attacks are removed from the game.")
	var guard: Variant = c.get("protect_allies", false)
	if guard is String and str(guard) != "":
		lines.append("Your %s Allies cannot be discarded or removed from the game." % bloodline_name(str(guard)))
	elif bool(guard):
		lines.append("Your Allies cannot be discarded or removed from the game.")
	if bool(c.get("ally_control_any_stage", false)) and c.has("ally_control_tag"):
		lines.append("Your %s Allies may take control of Combat at any Energy." % keyword_name(str(c["ally_control_tag"])))
	elif bool(c.get("ally_control_any_stage", false)):
		lines.append("Your Allies may take control of Combat at any Energy.")
	var blind: String = str(c.get("no_modifiers_against", ""))
	if blind != "":
		lines.append("No modifiers are added to %s performed against this personality." % ("attacks" if blind == "any" else ("Strikes" if blind == "strike" else "Arts")))
	var energy_mult: int = int(c.get("energy_gain_multiplier", 1))
	if energy_mult > 1:
		lines.append("Energy this duelist gains from a card effect is %s." % ("doubled" if energy_mult == 2 else "multiplied by %d" % energy_mult))
	var fervor_bonus: int = int(c.get("fervor_gain_bonus", 0))
	if fervor_bonus > 0:
		lines.append("When you gain Fervor, increase that amount by %d." % fervor_bonus)
	for m in c.get("modifiers", []):
		lines.append(modifier_text(m))
	if bool(c.get("allies_share", false)):
		lines.append("If this personality is your duelist, your Allies may use this Constant too.")
	for what in c.get("forbid_opponent", []):
		lines.append("Your opponent may not %s." % str(FORBID_TEXT.get(str(what), str(what))))
	for trigger in ["turn_start", "entering_combat", "on_attack"]:
		var timed: Array = []
		for e in c.get(trigger, []):
			var t: Dictionary = e.duplicate()
			t["trigger"] = trigger
			timed.append(t)
		lines.append_array(effects_text(timed))
	return lines


## Short label for a command in a prompt, for buttons and the log.
static func command_label(cmd: Command, engine: DuelEngine) -> String:
	var name: String = ""
	if cmd.card >= 0:
		var c: CardInstance = engine.card(cmd.card)
		if c != null:
			name = c.def.title
	match cmd.type:
		&"reserve_in":
			return "Bring in %s" % name
		&"reserve_done":
			return "Finish Reserve swap"
		&"place":
			return "Place %s" % name
		&"shuffle_back":
			return "Show %s and shuffle it back" % name
		&"relic":
			return "Use %s" % name
		&"done":
			return "Done placing"
		&"declare":
			return "Declare Combat"
		&"skip":
			return "Skip Combat"
		&"attack":
			if cmd.value != null and str(cmd.value) == "empower":
				return "Attack with %s, Empowered" % name
			return "Attack with %s" % name
		&"use":
			if cmd.value != null and str(cmd.value) == "place":
				return "Put %s into play" % name
			return "Use %s" % name
		&"power":
			return "Use %s's Power" % name
		&"copied_attack":
			return "Repeat the attack you stopped"
		&"final_strike":
			return "Final Strike, discarding %s" % name
		&"pass":
			return "Pass"
		&"counter":
			return "Counter with %s" % name
		&"decline":
			if engine != null and engine.prompt != null and str(engine.prompt.context.get("window", "")) != "":
				return "Use nothing"
			return "Let it resolve"
		&"defend":
			if cmd.value != null and str(cmd.value) == DuelEngine.TRY_STOP:
				return "Play %s for its other effects. The attack still lands." % name
			return "Defend with %s" % name
		&"power_defend":
			if cmd.value != null and str(cmd.value) == DuelEngine.TRY_STOP:
				return "Use %s's Power for its other effects. The attack still lands." % name
			return "Defend with %s's Power" % name
		&"no_defense":
			return "Take it"
		&"order_up":
			var titles: Array = engine.prompt.context.get("order", []) if engine != null and engine.prompt != null else []
			var at: int = int(cmd.value) if cmd.value != null else 0
			if at < 1 or at >= titles.size():
				return "Move it one place earlier."
			return "Move %s before %s." % [str(titles[at]), str(titles[at - 1])]
		&"order_confirm":
			var titles: Array = engine.prompt.context.get("order", []) if engine != null and engine.prompt != null else []
			if titles.is_empty():
				return "Resolve in this order."
			return "Resolve in this order: %s." % ", then ".join(PackedStringArray(titles))
		&"control":
			return "%s takes control" % name
		&"target":
			return "%s takes the damage" % name
		&"endure":
			return "Spend %s" % name if name != "" else "Use Endurance"
		&"no_endure":
			return "Take the wounds"
		&"capture":
			return "Capture %s" % name
		&"lower_fervor":
			return "Disrupt 1"
		&"no_critical":
			return "Take nothing"
		&"deal_damage":
			return "Deal the damage"
		&"keep":
			return "Keep %s" % name
		&"discard_all":
			return "Discard everything"
		&"recover":
			return "Recover top discard"
		&"no_recover":
			return "Skip recovery"
		&"pay":
			return "Pay %d Energy" % int(cmd.value)
		&"pay_life":
			return "Take a wound" if int(cmd.value) > 0 else "Pay nothing"
		&"pay_hand":
			return "Discard a card from hand" if int(cmd.value) > 0 else "Keep your hand"
		&"discard_choice":
			return "Discard %s" % name
		&"pick_in_play":
			return "Choose %s" % name
		&"pick_none":
			if engine.prompt != null and str(engine.prompt.context.get("purpose", "")) == "look_hand":
				return "Done looking"
			if engine.prompt != null and bool(engine.prompt.context.get("search", false)):
				return "Done looking" if int(engine.prompt.context.get("amount", 1)) <= 0 else "Take nothing"
			if engine.prompt != null and str(engine.prompt.context.get("purpose", "")) == "deck_loss_guard":
				return "Keep the card and lose them all"
			if engine.prompt != null and str(engine.prompt.context.get("purpose", "")) == "name_card":
				return "Name nothing"
			if engine.prompt != null and str(engine.prompt.context.get("purpose", "")) == "shuffle_back":
				return "Keep it in hand"
			return "Choose none"
		&"name_card":
			return "Name %s" % str(cmd.value)
		&"pick_option":
			var ctx: Dictionary = engine.prompt.context if engine != null and engine.prompt != null else {}
			if str(ctx.get("purpose", "")) == "deck_loss_guard":
				return "Discard it and lose %d fewer" % int(ctx.get("reduce", 0))
			if str(ctx.get("purpose", "")) == "choose_side":
				return "Yourself" if str(cmd.value) == "self" else "Your opponent"
			if str(ctx.get("purpose", "")) == "play_or_hand":
				return "Put it into play" if str(cmd.value) == "play" else "Put it into your hand"
			if str(ctx.get("purpose", "")) == "look_place":
				return "All on top" if str(cmd.value) == "top" else "All on the bottom"
			if str(ctx.get("purpose", "")) == "life_for_cost":
				return "Pay %d Energy" % int(ctx.get("stages", 0)) if str(cmd.value) == "energy" else "Take a wound instead"
			if str(ctx.get("purpose", "")) == "choose_one":
				return str((ctx.get("labels", []) as Array)[int(str(cmd.value))])
			if str(ctx.get("purpose", "")) == "shuffle_back":
				return "Show %s and shuffle it back" % name
			if str(ctx.get("purpose", "")) == "wild_might":
				return "Count your Might as higher." if str(cmd.value) == "higher" else "Count your Might as not higher."
			if name != "":
				return name
			if str(ctx.get("purpose", "")) == "draw_count":
				return "Draw %s" % str(cmd.value)
			match str(cmd.value):
				"yes":
					return str(ctx.get("yes_label", "Do it"))
				"no":
					return str(ctx.get("no_label", "Leave it"))
				_:
					return str(cmd.value).replace("_", " ").capitalize()
		_:
			return str(cmd.type)


static func prompt_title(p: Prompt) -> String:
	match p.kind:
		&"reserve":
			return "Reserve: bring cards into your Life Deck?"
		&"non_combat":
			return "Non-Combat step: place cards"
		&"declare":
			return "Declare Combat?"
		&"attack_action":
			return "Fight back" if bool(p.context.get("fight_back", false)) else "Your attack phase"
		&"respond":
			if str(p.context.get("mode", "")) == "declare":
				return "Your opponent's Declare step: respond?"
			var countered: String = str(p.context.get("card_title", ""))
			var named: String = countered if countered != "" else "the card"
			if not bool(p.context.get("can_counter", true)):
				return "%s is about to resolve" % named
			return "Counter %s?" % named
		&"defense":
			if bool(p.context.get("unstoppable", false)):
				return "The %s cannot be stopped. Play a card for its other effects?" % str(p.context.get("kind", "attack")).capitalize()
			return "Defend against the %s?" % str(p.context.get("kind", "attack")).capitalize()
		&"control":
			if str(p.context.get("role", "")) == "attacker":
				return "Who attacks? Your Duelist is spent"
			return "Who takes control of Combat?"
		&"redirect":
			return "Who takes the damage?"
		&"endurance":
			return "Endurance"
		&"critical":
			var wounds: int = int(p.context.get("life_dealt", 0))
			return "Critical damage (%d wounds): choose one" % wounds if wounds > 0 else "Critical damage: choose one"
		&"capture_instead":
			return "%s: capture a Seal instead of dealing damage?" % str(p.context.get("card_title", "Ally"))
		&"keep":
			return "Discard step: keep one card"
		&"recover":
			return "Recover a card from your discard?"
		&"pay":
			var payer: String = str(p.context.get("card_title", ""))
			if bool(p.context.get("life_cost", false)):
				return "%s: take a wound?" % payer if payer != "" else "Take a wound?"
			if bool(p.context.get("hand_cost", false)):
				return "%s: discard a card for more damage?" % payer if payer != "" else "Discard a card for more damage?"
			return "%s: pay Energy?" % payer if payer != "" else "Pay extra Energy?"
		&"discard_choice":
			var n: int = int(p.context.get("amount", 1))
			return "Choose %d cards to discard" % n if n > 1 else "Choose a card to discard"
		&"pick_in_play":
			var n: int = int(p.context.get("amount", 1))
			if n > 1:
				return "Choose up to %d cards in play" % n if bool(p.context.get("up_to", false)) else "Choose %d cards in play" % n
			return "Choose a card in play"
		&"pick_discard":
			var many: int = int(p.context.get("amount", 1))
			var whose: String = "their" if int(p.context.get("target", p.player)) != p.player else "your"
			if many > 1:
				return "Remove up to %d cards from %s discard pile" % [many, whose] if bool(p.context.get("up_to", false)) else "Remove %d cards from %s discard pile" % [many, whose]
			return "Remove a card from %s discard pile" % whose
		&"name_card":
			return "Name a card"
		&"order":
			match str(p.context.get("purpose", "")):
				"if_successful":
					return "Your attack landed. In what order do your effects resolve?"
				"shields":
					return "In what order are your Defense Shields spent?"
				"entering_combat":
					return "Entering Combat. In what order do your effects resolve?"
			return "Your effects happen at the same time. In what order do they resolve?"
		&"follow_up":
			match str(p.context.get("window", "")):
				DuelEngine.USE_WHEN_NEEDED:
					match str(p.context.get("point", "")):
						"before_declare":
							return "Before Combat is declared: use a card when needed?"
						"before_combat":
							return "Combat is about to begin: use a card when needed?"
						"after_secondary":
							return "The attack is declared: use a card before the defense?"
						"after_defense":
							return "The defense is in: use a card before the Shields?"
						"before_damage":
							return "The attack is through: use a card before damage?"
						"after_damage":
							return "The damage is dealt: use a card before its effects?"
					return "Use a card when needed?"
				"entering_combat":
					return "Entering Combat: use a card?"
				"performing_attack":
					return "Your attack connected: use a card with it?"
				"attack_boost":
					return "Discard a card from your hand to power up this attack?"
				"after_damage":
					var took: int = int(p.context.get("life", 0))
					return "You took %s: use a card?" % _plural(took, "wound", "wounds") if took > 0 else "You took the hit: use a card?"
			return "Use a card now that the attack is through?"
		&"pick_option":
			if bool(p.context.get("may", false)):
				var title: String = str(p.context.get("card_title", ""))
				return "%s: use the optional effect?" % title if title != "" else "Use the optional effect?"
			if bool(p.context.get("search", false)):
				var n: int = int(p.context.get("amount", 1))
				var where: String = "into play" if str(p.context.get("to", "hand")) == "play" else "into your hand"
				if n <= 0:
					return "Search: nothing in your Life Deck matches"
				return "Search: take up to %d cards %s" % [n, where] if n > 1 else "Search: take a card %s" % where
			if bool(p.context.get("rearrange", false)):
				return "Put back on the %s next" % ("top" if str(p.context.get("from", "top")) == "top" else "bottom")
			var asker: String = str(p.context.get("card_title", ""))
			match str(p.context.get("purpose", "")):
				"forbid_type":
					return "%s: forbid which card type?" % asker if asker != "" else "Forbid which card type?"
				"stop_kind":
					return "%s: stop which kind of attack?" % asker if asker != "" else "Stop which kind of attack?"
				"look_at":
					if str(p.context.get("to", "hand")) == "removed":
						return "%s: remove which card from the game?" % asker if asker != "" else "Remove which card from the game?"
					var dest: String = "into play" if str(p.context.get("to", "hand")) == "play" else "into your hand"
					return "%s: take a card %s" % [asker, dest] if asker != "" else "Take a card %s" % dest
				"look_place":
					return "%s: put them all on top or all on the bottom?" % asker if asker != "" else "Put them all on top or all on the bottom?"
				"capture":
					return "%s: capture which Seal?" % asker if asker != "" else "Capture which Seal?"
				"shuffle_back":
					return "You drew a Drill you cannot place. Shuffle it back into your Life Deck?"
				"copy_drill":
					return "%s: copy which Drill?" % asker if asker != "" else "Copy which Drill?"
				"wild_might":
					return "%s compares Might against Wild Might. Which way does it go?" % asker if asker != "" else "Wild Might: which way does the comparison go?"
			return "Choose"
		_:
			return str(p.kind)


## What an attack came to, once it is over: "Bram's Strike lands for 3 stages and 2 wounds."
## or "Bram's Strike is stopped by Tide Parry." Kept in the log because the attack in the air
## is gone from the view by the next prompt.
static func attack_end_line(engine: DuelEngine, d: Dictionary, seat: int = -1) -> String:
	var pname: String = _pname(engine, int(d.get("player", -1)))
	var kind: String = "Art" if str(d.get("kind", "strike")) == "art" else "Strike"
	var what: String = "%s's %s" % [pname, kind]
	if bool(d.get("is_final", false)):
		what = "%s's Final Strike" % pname
	elif bool(d.get("is_power", false)):
		what = "%s's Power" % pname
	elif int(d.get("source", -1)) >= 0:
		what = "%s's %s" % [pname, _cname(engine, int(d.get("source", -1)), seat, int(d.get("player", -1)))]
	if bool(d.get("stopped", false)):
		var by: Dictionary = d.get("stopped_by", {})
		match str(by.get("how", "")):
			"card":
				return "%s is stopped by %s." % [what, _cname(engine, int(by.get("card", -1)))]
			"power":
				return "%s is stopped by %s's Power." % [what, _cname(engine, int(by.get("card", -1)))]
			"shield":
				return "%s is stopped by a Defense Shield." % what
			"floating":
				return "%s is stopped by a standing defense." % what
		return "%s is stopped." % what
	var dealt: String = damage_amount(int(d.get("stages_dealt", 0)), int(d.get("life_dealt", 0)))
	var line: String = "%s lands for %s." % [what, dealt] if dealt != "" else "%s lands for nothing." % what
	if int(d.get("endurance_prevented", 0)) > 0:
		line += " Endurance prevented %d." % int(d["endurance_prevented"])
	return line


## One line per engine event for the log. Empty string means do not log. `reveal_all` words it for
## a replay's full-information view: every card is named, the ones drawn and recovered included.
static func event_line(ev: GameEvent, engine: DuelEngine, seat: int = -1, reveal_all: bool = false) -> String:
	var d: Dictionary = ev.data
	if reveal_all:
		seat = -1
	var actor: int = int(d.get("player", -1))
	var pname: String = _pname(engine, int(d.get("player", -1)))
	match ev.type:
		&"turn_start":
			return "— Turn %d: %s —" % [int(d.get("turn", 0)), pname]
		&"dev":
			return "Dev: %s runs %s on %s." % [pname, str(d.get("op", "")), ("the rival" if str(d.get("who", "self")) == "opponent" else "themselves")]
		&"draw":
			if reveal_all:
				return "%s draws %s." % [pname, _cname(engine, int(d.get("card", -1)))]
			return "%s draws." % pname
		&"card_placed":
			return "%s places %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"drill_shuffled_back":
			return "%s shows %s and shuffles it back into the Life Deck." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"rearranged":
			return "%s puts %d cards back in a chosen order." % [pname, int(d.get("count", 0))]
		&"power_up":
			return "%s powers up %d to Energy %d." % [pname, int(d.get("gain", 0)), int(d.get("energy", 0))]
		&"turn_end":
			return "%s ends their turn." % pname
		&"combat_declared":
			return "%s declares Combat!" % pname
		&"entering_combat":
			return "%s prepares as the %s." % [pname, role_name(str(d.get("role", "active")))]
		&"recover_step":
			if not bool(d.get("eligible", false)):
				return "%s has nothing to recover." % pname
			return ""   # the `recover` line says what came back
		&"window_skipped":
			# A window that opened on nothing. The ones that open on every card played stay out of
			# the log the way a countered defense does; the client still gets the beat.
			match str(d.get("window", "")):
				"after_damage":
					return "%s has no answer to the damage." % pname
				"late_stop":
					return "%s cannot stop it now." % pname
				_:
					return ""
		&"combat_skipped":
			if not bool(d.get("forced", false)):
				return "%s skips Combat." % pname
			if str(d.get("reason", "")) == "grounds":
				return "%s placed Grounds this turn, so Combat is skipped." % pname
			return "%s cannot declare Combat, so it is skipped." % pname
		&"pass":
			return "%s passes." % pname
		&"attack_declared":
			var kind: String = str(d.get("kind", "strike"))
			if bool(d.get("is_final", false)):
				return "%s makes a Final Strike." % pname
			if bool(d.get("is_power", false)):
				return "%s uses a Power: %s." % [pname, kind.capitalize()]
			var src: String = _cname(engine, int(d.get("source", -1)))
			if int(d.get("source", -1)) < 0:
				src = "a copied attack"
			return "%s attacks with %s%s." % [pname, src, (" (Empowered)" if bool(d.get("empowered", false)) else "")]
		&"card_used":
			return "%s uses %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"power_used":
			return "%s uses %s's Power." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"relic_used":
			return "%s calls on %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"resonance":
			return ResonanceData.log_line(str(d.get("id", "")), str(d.get("what", "")), pname, int(d.get("amount", 0)))
		&"boss_power":
			return "%s holds a boss power: %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"boss_power_used":
			return "%s spends the boss power %s (%d left)." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor), int(d.get("left", 0))]
		&"cost_paid":
			return "%s pays %d Energy." % [pname, int(d.get("stages", 0))]
		&"countered":
			return "%s counters %s with %s." % [pname, _cname(engine, int(d.get("target", -1))), _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"order_chosen":
			var titles: Array = d.get("order", [])
			if bool(d.get("kept", true)) or titles.is_empty():
				return "%s keeps the usual order." % pname
			var what: String = "spends the Shields" if bool(d.get("shields", false)) else "resolves the effects"
			return "%s %s in this order: %s." % [pname, what, ", then ".join(PackedStringArray(titles))]
		&"wild_might_chosen":
			return "%s counts their Might as %s." % [pname, "higher" if bool(d.get("higher", true)) else "not higher"]
		&"defense_played":
			if bool(d.get("tried", false)):
				return "%s tries to stop it with %s for its other effects. The attack is not stopped." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
			return "%s defends with %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"defense_power":
			if bool(d.get("tried", false)):
				return "%s tries to stop it with a Power for its other effects. The attack is not stopped." % pname
			return "%s defends with a Power." % pname
		&"no_defense":
			if not bool(d.get("auto", false)):
				return "%s does not defend." % pname
			match str(d.get("reason", "")):
				"none":
					return "%s has no defense." % pname
				"final_strike":
					return "%s cannot defend after a Final Strike." % pname
				"unstoppable":
					return "%s cannot stop it." % pname
			return ""   # a standing stop or a countered defense already has its own line
		&"capture_instead":
			return "%s's Ally forgoes the damage to capture %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"combat_begin":
			return "Combat: %s attacks first." % _pname(engine, engine.state.attacker)
		&"attack_end":
			return attack_end_line(engine, d, seat)
		&"shield":
			return "%s's Defense Shield activates." % pname
		&"floating_stop":
			return "%s's standing defense stops the attack." % pname
		&"attack_stopped":
			return "The attack is stopped."
		&"attack_successful":
			return "The attack lands."
		&"base_damage":
			return base_damage_line(d)
		&"modified_damage":
			return modified_damage_line(d)
		&"damage_stages":
			var s: String = "%s loses %d Energy" % [pname, int(d.get("stages", 0))]
			if int(d.get("overflow", 0)) > 0:
				s += " and takes %d wounds from the overflow" % int(d["overflow"])
			return s + "."
		&"life_card_flipped":
			return "%s takes a wound: %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"endurance_used":
			return "%s uses %s's Endurance and prevents %d." % [
				pname, _cname(engine, int(d.get("card", -1)), seat, actor), int(d.get("prevented", 0))]
		&"endurance_declined":
			return "%s keeps %s and takes the remaining %d." % [
				pname, _cname(engine, int(d.get("card", -1)), seat, actor), int(d.get("remaining", 0))]
		&"seal_bypassed":
			if reveal_all:
				return "%s surfaces and returns to the deck." % _cname(engine, int(d.get("card", -1)))
			return "A Seal surfaces and returns to the deck."
		&"seal_captured":
			return "%s captures %s!" % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"critical_fervor":
			return "Critical damage: %s shames the rival." % pname
		&"fervor_changed":
			if int(d.get("from", 0)) == int(d.get("to", 0)):
				return ""
			var by: String = _cname(engine, int(d.get("source", -1)))
			var lead: String = "%s: " % by if by != "a card" else ""
			var word: String = fervor_word(d)
			var span: String = "Fervor %d → %d" % [int(d.get("from", 0)), int(d.get("to", 0))]
			if word.begins_with("Attune"):
				return "%s%s Attunes %s (%s)." % [lead, pname, word.get_slice(" ", 1), span]
			if word.begins_with("Disrupt"):
				return "%s%s is Disrupted %s (%s)." % [lead, pname, word.get_slice(" ", 1), span]
			return "%s%s's %s." % [lead, pname, span]
		&"draw_check":
			var by: String = _cname(engine, int(d.get("source", -1)))
			var want: String = ""
			match str(d.get("check", "school")):
				"named":
					want = "a named card"
				"signature":
					want = "a Signature card"
				"title_contains":
					want = "the card asked for"
				_:
					want = "%s" % school_name(str(d.get("school", "")))
			var matched: bool = bool(d.get("matched", false))
			var how: String = "discarded" if bool(d.get("discard", false)) else "drawn"
			if _sees(engine, int(d.get("card", -1)), seat, actor):
				return "%s: the %s card is %s, %s%s." % [by, how, _cname(engine, int(d.get("card", -1))), ("" if matched else "not "), want]
			# The other seat learns the outcome, never the card.
			return "%s: the %s card is %s%s%s." % [by, how, ("" if matched else "not "), want, ("; the effect follows" if matched else "")]
		&"energy_changed":
			if bool(d.get("script", false)):
				return "%s's Energy is set to %d." % [_cname(engine, int(d.get("card", -1)), seat, actor), int(d.get("to", 0))]
			var by: String = _cname(engine, int(d.get("source", -1)))
			return "%s: %s's Energy %d → %d." % [by if by != "a card" else "Effect", _cname(engine, int(d.get("card", -1)), seat, actor), int(d.get("from", 0)), int(d.get("to", 0))]
		&"gain_blocked":
			return "%s cannot gain Energy right now, so the %d it would gain is lost." % [
				_cname(engine, int(d.get("card", -1)), seat, actor), int(d.get("amount", 0))]
		&"trigger_fired":
			return "%s triggers %s." % [_cname(engine, int(d.get("card", -1)), seat, actor), trigger_phrase(str(d.get("trigger", "")))]
		&"flag_set":
			return _flag_line(engine, d)
		&"floating":
			return _floating_line(engine, d)
		&"card_moved":
			if str(d.get("to", "")) == "removed":
				return "%s is removed from the game." % _cname(engine, int(d.get("card", -1)), seat, actor)
			return ""
		&"attack_phase_skipped":
			return "%s's attack phase is skipped." % pname
		&"life_card_lost":
			# Wounds outside an attack's own damage: Art costs, effects, Energy overflow.
			return "%s takes a wound: %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"look_at":
			return "%s looks at the %s %d cards of their Life Deck." % [pname, str(d.get("from", "top")), int(d.get("count", 0))]
		&"declined_counter":
			return "%s lets it stand." % pname
		&"bonded":
			return "%s's Allies bond under %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"unbonded":
			return "%s's bond ends; the Allies stand apart again." % pname
		&"bond_tick":
			return "%s places a life card under %s (%d)." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor), int(d.get("count", 0))]
		&"fervor_shielded":
			return "%s's Relic shields their Fervor." % pname
		&"drill_copied":
			return "%s copies %s for the rest of Combat." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"fervor_capped":
			return "%s already raised %s's Fervor this turn, and %s allows it once." % [_cname(engine, int(d.get("card", -1)), seat, actor), pname, _cname(engine, int(d.get("grounds", -1)))]
		&"fervor_needed_changed":
			return "%s now needs %d Fervor to advance an Aspect." % [pname, int(d.get("to", 0))]
		&"aspect_up":
			return "%s ascends: %s!" % [pname, stack_aspect_name(int(d.get("aspect", 1)), _duelist_stack(engine, actor))]
		&"aspect_down":
			return "%s falls back: %s." % [pname, stack_aspect_name(int(d.get("aspect", 1)), _duelist_stack(engine, actor))]
		&"fervor_peak":
			return "%s is already at their last Aspect and recovers full Energy." % pname
		&"no_ascension_win":
			return "%s can no longer win by Ascension." % pname
		&"combat_end":
			return "Combat ends."
		&"discard_step":
			return "%s discards %d." % [pname, int(d.get("discarded", 0))]
		&"hand_discarded":
			return "%s discards %s from hand." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"hand_revealed":
			return "%s shows their hand (%d cards)." % [pname, (d.get("cards", []) as Array).size()]
		&"cards_revealed":
			# Named in full: the point of the beat is that every player now knows them.
			var shown: PackedStringArray = PackedStringArray()
			for uid in d.get("cards", []):
				var sc: CardInstance = engine.card(int(uid))
				if sc != null:
					shown.append(sc.def.title)
			return "%s shows %s." % [pname, _and_join(shown)]
		&"stripped":
			var stripped: int = int(d.get("count", 0))
			if stripped == 0:
				return "%s has no copies of \"%s\"." % [pname, str(d.get("name", ""))]
			return "%s loses %d copies of \"%s\"." % [pname, stripped, str(d.get("name", ""))] if stripped > 1 \
				else "%s loses a copy of \"%s\"." % [pname, str(d.get("name", ""))]
		&"recover":
			if reveal_all:
				return "%s returns %s to the Life Deck." % [pname, _cname(engine, int(d.get("card", -1)))]
			return "%s returns a card to the Life Deck." % pname
		&"final_strike":
			return "%s commits to a Final Strike." % pname
		&"control":
			return "%s takes control of Combat." % _cname(engine, int(d.get("card", -1)), seat, actor)
		&"redirect":
			return "%s takes the damage." % _cname(engine, int(d.get("card", -1)), seat, actor)
		&"double_power":
			return "Double Power: the stronger duelist starts at Energy %d; the weaker starts at full Energy." % int(d.get("energy", 2))
		&"setup":
			var opener: String = _pname(engine, int(d.get("first", -1)))
			match str(d.get("reason", "")):
				"double_power":
					return "%s opens the duel (Double Power)." % opener
				"forced":
					return "%s opens the duel (set by the match)." % opener
			return "%s opens the duel." % opener
		&"reserve_swap":
			return "%s brings %s in from the Reserve." % [pname, _cname(engine, int(d.get("in", -1)), seat, actor)]
		&"guest_ally":
			return "%s fights beside %s." % [_cname(engine, int(d.get("card", -1)), seat, actor), pname]
		&"search":
			return "%s searches out %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"deck_shuffled":
			return "%s shuffles their Life Deck." % pname
		&"in_play_discarded":
			return "%s loses %s from play." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"attached":
			return "%s attaches %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"remain":
			return "%s keeps %s on the table to use again." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"card_named":
			return "%s names %s." % [pname, str(d.get("name", ""))]
		&"seal_victory_pending":
			return "%s has carved all seven Seals. The gate opens at the start of their next turn." % pname
		&"point_scored":
			return "%s scores a point by %s (%d/%d)." % [pname, "emptying the rival's Life Deck" if str(d.get("reason", "")) == "survival" else "Ascension", int(d.get("points", 0)), int(d.get("to_win", 1))]
		&"second_wind":
			return "%s shuffles %d discarded cards into a new Life Deck." % [pname, int(d.get("cards", 0))]
		&"script_dealt":
			var dealt: int = (d.get("cards", []) as Array).size()
			return "%s card%s placed on the %s of %s's Life Deck." % [str(dealt), " is" if dealt == 1 else "s are", str(d.get("at", "top")), pname]
		&"script_swap":
			return "%s takes the other side of the table." % str(d.get("name", pname))
		&"game_over":
			var reason: String = str(d.get("reason", ""))
			var w: String = _pname(engine, int(d.get("winner", -1)))
			match reason:
				"session_ended":
					return "The session is over, with no winner."
				"ascension":
					return "%s ascends fully and the site answers. %s is Eidolarch!" % [w, w]
				"seal":
					return "The seventh Seal is carved and the gate opens. %s is Eidolarch!" % w
				_:
					return "The rival's mind gives out. %s is Eidolarch!" % w
		_:
			return ""


## Why a card is sitting in its response window, for the pending queue. `mode` is the one
## `GameState.pending_play` carries.
static func pending_mode_phrase(mode: String) -> String:
	match mode:
		"defend":
			return "defense awaiting a counter"
		"declare":
			return "answering the Declare step"
		"ascension":
			return "answering the Ascension"
		_:
			return "awaiting a counter"


## When a card's effect fires, for the "<card> triggers ..." log line.
static func trigger_phrase(trigger: String) -> String:
	match trigger:
		"turn_start":
			return "at the start of the turn"
		"on_place":
			return "on being placed"
		"entering_combat":
			return "when entering Combat"
		"on_attack":
			return "on the attack"
		"before_damage":
			return "before damage"
		"if_successful":
			return "on the hit"
		"on_success":
			return "after the successful attack"
		"if_stopped", "on_stopped":
			return "because the attack was stopped"
		"on_wound":
			return "on being discarded from the Life Deck"
		_:
			return "now"


static func _flag_line(engine: DuelEngine, d: Dictionary) -> String:
	var pname: String = _pname(engine, int(d.get("player", -1)))
	var by: String = _cname(engine, int(d.get("source", -1)))
	var lead: String = "%s: " % by if by != "a card" else ""
	match str(d.get("flag", "")):
		"pass_next_phase":
			return "%s%s must pass in their next attack phase." % [lead, pname]
		"skip_next_attack_phase":
			return "%s%s will skip their next attack phase." % [lead, pname]
		"cannot_declare_combat":
			return "%s%s cannot declare Combat this turn." % [lead, pname]
		"must_declare_combat":
			return "%s%s must declare Combat this turn." % [lead, pname]
		"end_combat":
			return "%s%s ends Combat." % [lead, pname]
		"end_turn":
			return "%s%s ends the turn." % [lead, pname]
		_:
			return ""


static func duration_phrase(duration: String) -> String:
	match duration:
		"combat":
			return " for the rest of Combat"
		"turn":
			return " this turn"
		"next_turn_end":
			return " until the end of their next turn"
		"next_attack_phase":
			return " during their next attack phase"
		"game":
			return " for the rest of the game"
		_:
			return ""


## A standing effect coming into force: forbids, stops, gains blocked, and the rest.
static func _floating_line(engine: DuelEngine, d: Dictionary) -> String:
	var pname: String = _pname(engine, int(d.get("player", -1)))
	var span: String = duration_phrase(str(d.get("duration", "")))
	var by: String = _cname(engine, int(d.get("source", -1)))
	var lead: String = "%s: " % by if by != "a card" else ""
	match str(d.get("op", "")):
		"forbid":
			var what: String = str(d.get("what", ""))
			var said: String = str(FORBID_TEXT.get(what, what.replace("_", " ")))
			if what == "lower_aspect":
				said = "use cards that lower their opponent's Aspect"
			return "%s%s may not %s%s." % [lead, pname, said, span]
		"stop_all":
			var kind: String = str(d.get("kind", "any"))
			return "%s%s will stop every %s%s." % [lead, pname, ("attack" if kind == "any" else kind.capitalize()), span]
		"no_gain":
			return "%s%s cannot gain Energy%s." % [lead, pname, span]
		"keep_hand":
			return "%s%s keeps their whole hand%s." % [lead, pname, span]
		"prevent_all":
			return "%s%s prevents all damage%s." % [lead, pname, span]
		"no_prevent":
			return "%s%s's damage cannot be prevented%s." % [lead, pname, span]
		"no_endurance":
			return "%s%s cannot use Endurance%s." % [lead, pname, span]
		"no_ally_control", "no_ally_takeover":
			return "%s%s's Allies cannot take control%s." % [lead, pname, span]
		"damage_removes":
			return "%s%s's wounds remove cards from the game%s." % [lead, pname, span]
		"next_attack_tax":
			return "%s%s's next attack costs %d more Energy." % [lead, pname, int(d.get("stages", 0))]
		"prevent_strike_damage":
			return "%s%s prevents all Strike damage%s." % [lead, pname, span]
		"energy_on_hit":
			return "%s%s's attacks now gain Energy when they land%s." % [lead, pname, span]
		"modifier", "stopped_last", "prevent_art_life", "copied_attack":
			return ""
		_:
			return "%s%s: %s in effect%s." % [lead, pname, str(d.get("op", "")).replace("_", " "), span]


## Strike Table bands are lettered A upward, as on the printed table.
static func band_letter(band: int) -> String:
	return char(65 + clampi(band, 0, 25))


static func might_band(might: int, band: int) -> String:
	return "%s (%s)" % [short_number(might), band_letter(band)]


## "4 Energy, 1 wound" with the right plurals; `none` when both are 0.
static func damage_amount(stages: int, life: int, none: String = "no damage") -> String:
	var parts: PackedStringArray = PackedStringArray()
	if stages != 0:
		parts.append("%d Energy" % stages)
	if life != 0:
		parts.append("%d wound%s" % [life, "" if absi(life) == 1 else "s"])
	return ", ".join(parts) if not parts.is_empty() else none


## Table wording for a damage total: "7 Energy", "4 wounds", "3 Energy, 2 wounds", "nothing".
static func short_damage(stages: int, life: int) -> String:
	return damage_amount(stages, life, "nothing")


## The Strike Table part of a card's base damage for a known matchup, doubled where the card
## doubles its table result; -1 for a card whose base does not come from the table.
static func strike_table_base(def: CardDef, table: StrikeTable, attacker_might: int, defender_might: int,
		attacker_bands: int = 0) -> int:
	var a: Dictionary = def.attack
	if a.is_empty() or table == null or attacker_might < 0 or defender_might < 0:
		return -1
	if str(a.get("kind", "strike")) != "strike" or a.has("printed_stages") or a.has("printed_life"):
		return -1
	var base: int = table.base_damage(attacker_might, defender_might, attacker_bands)
	var times: Dictionary = a.get("table_multiply", {})
	if not times.is_empty() and (not bool(times.get("higher_might", false)) or attacker_might > defender_might):
		base *= maxi(1, int(times.get("by", 2)))
	return base


## The base attack as a face badge: {kind, num, word}. A plain Strike reads "Table Energy", a
## modified one "+3 Energy", a printed one "7 Energy"; an Art reads "4 wounds" from its base or
## printed number. A card with both Energy and wound lines shows the Energy and notes the wounds.
## `table_base` is the Strike Table result for the matchup the card is shown in (see
## `strike_table_base`); when known, a table Strike reads that number with its modifier added.
static func attack_badge(def: CardDef, table_base: int = -1) -> Dictionary:
	var a: Dictionary = def.attack
	if a.is_empty():
		return {}
	var kind: String = str(a.get("kind", "strike"))
	var out: Dictionary = {"kind": ("Focused " if bool(a.get("focused", false)) else "") + ("Strike" if kind == "strike" else "Art"), "num": "", "word": "", "extra": ""}
	if a.has("printed_stages") or a.has("printed_life"):
		if int(a.get("printed_stages", 0)) > 0:
			out["num"] = str(int(a["printed_stages"]))
			out["word"] = "Energy"
			if int(a.get("printed_life", 0)) > 0:
				out["extra"] = "+%d wounds" % int(a["printed_life"])
		else:
			out["num"] = str(int(a.get("printed_life", 0)))
			out["word"] = "wounds"
	elif kind == "strike":
		if table_base >= 0:
			out["num"] = str(maxi(0, table_base + int(a.get("stages", 0))))
		else:
			out["num"] = "%+d" % int(a["stages"]) if int(a.get("stages", 0)) != 0 else "Table"
		out["word"] = "Energy"
		if int(a.get("life", 0)) != 0:
			out["extra"] = "%+d wounds" % int(a["life"])
	else:
		out["num"] = str(DuelEngine.ART_BASE_LIFE + int(a.get("life", 0)))
		out["word"] = "wounds"
		if int(a.get("stages", 0)) != 0:
			out["extra"] = "%+d Energy" % int(a["stages"])
	return out


## Each step of a damage breakdown as a short phrase: the base ("Table 4 (F vs C)", "Art base
## 4", "Printed 7 stages", "Wild 2"), then each add with its card, then any standing rule.
static func breakdown_steps(d: Dictionary) -> PackedStringArray:
	var steps: PackedStringArray = PackedStringArray()
	if d.is_empty():
		return steps
	var base_stages: int = int(d.get("base_stages", 0))
	var base_life: int = int(d.get("base_life", 0))
	if bool(d.get("wild", false)):
		steps.append("Wild %d" % (base_stages + base_life))
	elif bool(d.get("printed", false)):
		steps.append("Printed %s" % damage_amount(base_stages, base_life))
	elif str(d.get("kind", "strike")) == "art":
		steps.append("Art base %d" % (base_stages + base_life))
	else:
		steps.append("Table %d (%s vs %s)" % [int(d.get("table", 0)), band_letter(int(d.get("attacker_band", 0))), band_letter(int(d.get("defender_band", 0)))])
	for add in d.get("adds", []):
		steps.append("%s %s" % [add_text(add), str(add.get("source", ""))])
	if bool(d.get("no_reduce", false)):
		steps.append("cannot be reduced")
	if bool(d.get("prevented", false)):
		steps.append("all prevented")
	return steps


## Step 9 of the battle sequence as one log line: where the base number came from.
static func base_damage_line(d: Dictionary) -> String:
	var stages: int = int(d.get("stages", 0))
	var life: int = int(d.get("life", 0))
	if bool(d.get("wild", false)):
		return "Base damage: a wild personality is in control, so %s." % damage_amount(stages, life)
	if bool(d.get("printed", false)):
		return "Base damage: printed %s." % damage_amount(stages, life)
	if str(d.get("kind", "strike")) == "art":
		return "Base damage: Arts deal %s." % damage_amount(stages, life)
	return "Strike Table: Might %s vs %s gives %s." % [
		might_band(int(d.get("attacker_might", 0)), int(d.get("attacker_band", 0))),
		might_band(int(d.get("defender_might", 0)), int(d.get("defender_band", 0))),
		damage_amount(stages, life),
	]


## Step 10: each addition with its card, then the total. Empty when nothing changed the base.
static func modified_damage_line(d: Dictionary) -> String:
	var adds: Array = d.get("adds", [])
	if adds.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for add in adds:
		parts.append("%s (%s)" % [add_text(add), str(add.get("source", ""))])
	return "Modifiers: %s. Total %s." % [", ".join(parts), damage_amount(int(d.get("stages", 0)), int(d.get("life", 0)))]


## One breakdown entry without its source: "+2 Energy", "x2", "cap 3 Energy".
static func add_text(add: Dictionary) -> String:
	if add.has("multiply"):
		return "x%d" % int(add["multiply"])
	if add.has("cap_stages"):
		return "cap %d Energy" % int(add["cap_stages"])
	if add.has("cap_life"):
		return "cap %d wounds" % int(add["cap_life"])
	return signed_damage(int(add.get("stages", 0)), int(add.get("life", 0)))


## "+2 Energy", "-1 wound", "+1 Energy +1 wound"; for breakdown lines.
static func signed_damage(stages: int, life: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if stages != 0:
		parts.append("%+d Energy" % stages)
	if life != 0:
		parts.append("%+d wound%s" % [life, "" if absi(life) == 1 else "s"])
	return " ".join(parts)


static func _duelist_stack(engine: DuelEngine, i: int) -> PersonalityStack:
	if i < 0 or i >= engine.state.players.size() or engine.state.players[i].duelist == null:
		return null
	return engine.state.players[i].duelist.stack


static func _pname(engine: DuelEngine, i: int) -> String:
	if i < 0 or i >= engine.state.players.size():
		return "?"
	return engine.state.players[i].name


## A card's title for a log line. With a `seat`, the title shows only if that seat may see the card
## where it sits now or is the `actor` whose own play it was; otherwise "a card". Seat -1 sees all.
## The keyword a Fervor change is, from a fervor_changed event's data: a gain is "Attune N", a
## loss the rival caused is "Disrupt N". Anything else ("" returned) is told as the bare number.
static func fervor_word(d: Dictionary) -> String:
	var delta: int = int(d.get("to", 0)) - int(d.get("from", 0))
	var owner: int = int(d.get("source_owner", -1))
	if delta > 0:
		return "Attune %d" % delta
	if delta < 0 and owner >= 0 and owner != int(d.get("player", -1)):
		return "Disrupt %d" % -delta
	return ""


static func _cname(engine: DuelEngine, uid: int, seat: int = -1, actor: int = -1) -> String:
	var c: CardInstance = engine.card(uid)
	if c == null:
		return "a card"
	if seat >= 0 and seat != actor and not SeatCard.visible_to(c, seat):
		return "a card"
	return c.def.title + _owner_suffix(engine, c)


## " (Bram's)" after a personality's title when the other side has a personality of that title in
## play too. Every Ally rule is per player now, so both duelists may be the same character and a
## bare title stops saying whose it is. Only cards in play are looked at, which both players can
## already see, so the line says nothing new about a hidden card.
static func _owner_suffix(engine: DuelEngine, c: CardInstance) -> String:
	if not c.def.is_personality() or not _public(c):
		return ""
	for i in range(engine.state.players.size()):
		if i == c.owner:
			continue
		var p: PlayerState = engine.state.players[i]
		var theirs: Array[CardInstance] = p.allies()
		if p.duelist != null:
			theirs.append(p.duelist)
		for o in theirs:
			if o.def.title == c.def.title:
				return " (%s's)" % _pname(engine, c.owner)
	return ""


## A card both seats may see where it stands: on the table, not in a hand, Life Deck or Reserve.
static func _public(c: CardInstance) -> bool:
	return SeatCard.visible_to(c, 0) and SeatCard.visible_to(c, 1)


static func _sees(engine: DuelEngine, uid: int, seat: int, actor: int) -> bool:
	var c: CardInstance = engine.card(uid)
	return c != null and (seat < 0 or seat == actor or SeatCard.visible_to(c, seat))
