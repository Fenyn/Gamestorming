class_name CardText
extends RefCounted
## Human-readable text for cards, prompts, and the log. Pure functions over engine data.

const SCHOOL_NAMES: Dictionary = {
	"": "Freestyle", "pyre": "Pyre", "tide": "Tide", "storm": "Storm",
	"shade": "Shade", "steel": "Steel", "root": "Root",
}
const TYPE_LABELS: Dictionary = {
	CardDef.Type.DUELIST: "Duelist", CardDef.Type.ALLY: "Ally", CardDef.Type.STRIKE: "Strike",
	CardDef.Type.ART: "Art", CardDef.Type.COMBAT: "Combat", CardDef.Type.NON_COMBAT: "Non-Combat",
	CardDef.Type.DRILL: "Drill", CardDef.Type.SEAL: "Seal", CardDef.Type.GROUNDS: "Grounds",
	CardDef.Type.MASTERY: "Mastery", CardDef.Type.RELIC: "Relic",
}
const FORBID_TEXT: Dictionary = {
	"strike_attacks": "perform Strikes", "art_attacks": "perform Arts", "combat_cards": "use Combat cards",
	"strike_cards": "use Strike cards", "art_cards": "use Art cards", "powers": "use Powers",
	"mastery": "use a Mastery", "drills": "use Drills", "non_combats": "use Non-Combat cards",
	"end_combat": "use cards that end Combat", "stop_all": "use cards that stop all attacks",
	"seals": "place Seals", "non_attack_actions": "do anything but attack or pass in their attack phase",
	"skip_combat": "skip declaring Combat",
}
const FLOAT_TEXT: Dictionary = {
	"no_prevent": "damage from your attacks cannot be prevented",
	"prevent_all": "all damage from attacks against you is prevented",
	"make_focused": "your attacks are Focused",
	"after_use_bottom": "your school attacks go to the bottom of your Life Deck after use",
	"damage_removes": "wounds from your attacks are removed from the game",
	"no_gain": "your opponent's duelist and Allies cannot gain Energy",
	"no_ally_control": "your opponent's Allies cannot take control or take damage",
	"keep_hand": "you keep your hand through the Discard step",
	"endurance_boost": "your next Endurance prevents all remaining damage",
	"no_endurance": "your opponent cannot use Endurance",
	"stop_next": "the next attack against you is stopped",
	"prevent_art_life": "Arts against you deal no wounds",
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
		"tip": "A standing defense on a duelist or Drill: it stops the first unstopped attack of the named kind each Combat without spending a card."},
	{"key": "Strike Table", "pattern": "\\bStrike Table\\b", "role": "might",
		"tip": "The table that turns both duelists' Might into a Strike's base damage. The gap between Might bands sets how much Energy a plain Strike takes."},
	{"key": "Seal", "pattern": "\\bSeals?\\b", "role": "seal",
		"tip": "A mark carved into the gate, seven to a set, one set for each Eidolon. Carving all seven of one set opens the gate and wins the duel. A captured Seal changes hands."},
	{"key": "Non-Combat", "pattern": "\\bNon-Combat(?: cards?| step)?\\b", "role": "non_combat",
		"tip": "A card placed during your Non-Combat step that stays in play until something discards it. Drills are Non-Combat cards."},
	{"key": "Combat card", "pattern": "\\bCombat cards?\\b", "role": "combat",
		"tip": "A hand card played during Combat that is neither an attack nor a plain defense. Some cards can cancel a Combat card as it is played."},
	{"key": "Signature", "pattern": "\\bSignature cards?\\b", "role": "plain",
		"tip": "A card named for a duelist or their following. Only that duelist may use it, and searches for Signature cards find these."},
	{"key": "Life Deck", "pattern": "\\bLife Deck\\b", "role": "zone",
		"tip": "Your draw pile and your duelist's health. Every wound discards its top card. Running out of cards loses the duel."},
	{"key": "discard pile", "pattern": "\\bdiscard pile\\b", "role": "zone",
		"tip": "Where used cards and wounds go. Cards here can be recovered by effects; cards removed from the game cannot."},
	{"key": "in control", "pattern": "\\b(?:in control|takes? control|take control of Combat)\\b", "role": "ally",
		"tip": "The personality fighting for you this Combat. Your duelist has control unless an Ally steps in, which an Ally may do once your duelist is out of Energy."},
	{"key": "Vigil only", "pattern": "\\b(?:Vigil|Pact) only\\b", "role": "plain",
		"tip": "Only a duelist sworn to that side may include and use this card."},
	{"key": "Limit", "pattern": "\\bLimit \\d+ per deck\\b", "role": "plain",
		"tip": "The most copies of this card a deck may hold, Life Deck and Reserve together."},
	{"key": "Endurance", "pattern": "\\bEndurance(?: \\d+| X)?\\b", "role": "defense",
		"tip": "When this card is discarded as a wound, it soaks that many further wounds from the same attack."},
	{"key": "Empower", "pattern": "\\bEmpower(?:ed)?(?: \\d+)?\\b", "role": "focus",
		"tip": "You may perform this attack Empowered: it deals that many extra wounds, but every other effect on the card is lost."},
	{"key": "Focused", "pattern": "\\bFocused\\b", "role": "attack",
		"tip": "A Focused attack gets past defenses that stop all attacks. Only a defense that says it can stop a Focused attack, or a stop-all that names Focused, can stop it."},
	{"key": "Constant", "pattern": "\\bConstant:", "role": "plain",
		"tip": "Always in effect while this is your duelist's aspect. It needs no action and cannot be forbidden like a Power."},
	{"key": "Power", "pattern": "\\bPowers?\\b", "role": "plain",
		"tip": "The personality's own action, usable once per Combat unless it says otherwise. It follows the same rules as a card of its kind."},
	{"key": "Energy", "pattern": "\\bEnergy\\b", "role": "energy",
		"tip": "A duelist's stamina, 0 to 10. Strikes deal their damage to Energy first and Arts cost Energy to perform. At 0 the duelist is spent: damage becomes wounds and an Ally may step in."},
	{"key": "Might", "pattern": "\\bMight\\b", "role": "might",
		"tip": "How hard a duelist hits at their current Energy. The Strike Table compares both duelists' Might to set a Strike's base damage."},
	{"key": "Surge", "pattern": "\\bSurge(?: Rate)?\\b", "role": "energy",
		"tip": "The Energy a personality regains during the Recover step each turn."},
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
		"tip": "Training kept in play as a Non-Combat card. All of your Drills are discarded when you rise an Aspect."},
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
	{"key": "Stops", "pattern": "\\b[Ss]tops?\\b|\\bstopped\\b", "role": "defense",
		"tip": "A stopped attack deals no damage and none of its 'if successful' text happens. Its other effects still resolve."},
]


## 4500000 -> "4.5M", 850000 -> "850k".
static func short_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 1000:
		return "%dk" % int(n / 1000)
	return str(n)


## An Aspect's own title ("Unquenchable") when the duelist's card gives one, else "Aspect N".
static func aspect_name(aspect: int, def: CardDef = null) -> String:
	if def != null:
		var title: String = str(def.aspect_data(aspect).get("title", ""))
		if title != "":
			return title
	return "Aspect %d" % aspect


## Short HUD wording for a standing forbid, keyed by the engine's forbid `what` word.
const RESTRICTION_NAMES: Dictionary = {
	"strike_attacks": "No Strike attacks", "art_attacks": "No Art attacks", "strike_cards": "No Strike cards",
	"art_cards": "No Art cards", "combat_cards": "No Combat cards", "non_combats": "No Non-Combats",
	"drills": "No Drills", "seals": "No Seals", "mastery": "Mastery silenced", "powers": "Powers silenced",
	"stop_all": "Cannot stop every attack", "end_combat": "Cannot end Combat",
	"non_attack_actions": "Attacks only", "skip_combat": "Must declare Combat",
}


static func restriction_name(what: String) -> String:
	return str(RESTRICTION_NAMES.get(what, what.capitalize()))


static func school_name(school: String) -> String:
	return str(SCHOOL_NAMES.get(school, school.capitalize()))


static func type_label(def: CardDef) -> String:
	return str(TYPE_LABELS.get(def.type, "Card"))


static func type_line(def: CardDef) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(school_name(def.school))
	parts.append(type_label(def))
	if def.alignment_only != "":
		parts.append(def.alignment_only.capitalize() + "s only")
	return " · ".join(parts)


## card_type -> [singular, plural].
const CARD_TYPE_WORDS: Dictionary = {
	"card": ["card", "cards"], "ally": ["Ally", "Allies"], "drill": ["Drill", "Drills"],
	"non_combat_any": ["Non-Combat card, Drill, or Seal", "Non-Combat cards, Drills, or Seals"],
	"non_combat": ["Non-Combat card", "Non-Combat cards"], "non_combat_only": ["Non-Combat card", "Non-Combat cards"],
	"combat": ["Combat card", "Combat cards"], "strike": ["Strike", "Strikes"], "art": ["Art", "Arts"],
	"attack": ["attack card", "attack cards"], "hand_combat": ["Strike, Art, or Combat card", "Strike, Art, or Combat cards"],
	"strike_or_art": ["Strike or Art card", "Strike or Art cards"],
	"seal": ["Seal", "Seals"], "grounds": ["Grounds card", "Grounds cards"],
	"drill_or_ally": ["Drill or Ally", "Drills and Allies"], "non_combat_or_ally": ["Non-Combat card or Ally", "Non-Combat cards and Allies"],
	"freestyle_drill": ["Freestyle Drill", "Freestyle Drills"], "duelist": ["Duelist", "Duelists"], "mastery": ["Mastery", "Masteries"],
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
	if s.begins_with("Remain ") or s.begins_with("Hit"):
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


## [prefix, keep_case] for an effect from its trigger head and condition.
static func _lead(head: String, when: Dictionary) -> Array:
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


static func _count_of(e: Dictionary, card_type: String) -> String:
	var n: int = int(e.get("amount", 1))
	if bool(e.get("all", false)):
		return "all " + type_words(card_type, true)
	if bool(e.get("up_to", false)):
		return "up to %s" % _plural(n, type_words(card_type, false), type_words(card_type, true)).trim_prefix("a ").trim_prefix("an ")
	return _plural(n, type_words(card_type, false), type_words(card_type, true))


## Rules text generated from the definition when the card has none of its own.
static func rules_text(def: CardDef) -> String:
	if def.text != "":
		return def.text
	var lines: PackedStringArray = PackedStringArray()
	if not def.only.is_empty():
		if def.only.has("character"):
			lines.append("%s only." % str(def.only["character"]))
		elif def.only.has("duelist_character"):
			lines.append("%s only." % str(def.only["duelist_character"]))
	if def.endurance > 0 and def.endurance_when.is_empty():
		lines.append("Endurance %d." % def.endurance)
	elif not def.endurance_when.is_empty():
		lines.append("Endurance X. X = %d if %s, otherwise %d." % [int(def.endurance_when.get("then", 0)), cond_text(def.endurance_when.get("value_if", {})), int(def.endurance_when.get("else", 0))])
	if def.counter == "combat":
		lines.append("Use when needed. Stops the effects of any Combat card.")
	if str(def.raw.get("use_at", "")) == "end_of_combat":
		lines.append("Use at the end of Combat.")
	if def.is_attack():
		lines.append(attack_text(def.attack))
		for v in def.attack.get("variants", []):
			lines.append(_conditional(v.get("when", {}), variant_text(v)))
	if def.is_defense():
		lines.append(defense_text(def.defense))
	if def.empower > 0:
		lines.append("Empower %d." % def.empower)
	var effect_lines: PackedStringArray = effects_text(def.effects)
	if def.type == CardDef.Type.RELIC and int(def.raw.get("uses_per_game", 0)) > 0 and not effect_lines.is_empty():
		var uses: int = int(def.raw["uses_per_game"])
		var often: String = "Once" if uses == 1 else ("Twice" if uses == 2 else "%d times" % uses)
		effect_lines[0] = "%s per game, during your Non-Combat step: %s" % [often, effect_lines[0]]
	for t in effect_lines:
		var said: bool = false
		for l in lines:
			if l.contains(t):
				said = true
		if not said:
			lines.append(t)
	for m in def.modifiers:
		lines.append(modifier_text(_rolled_up(m, def.modifiers)))
	if def.shield != "":
		lines.append("Defense Shield: stops the first unstopped %s each Combat." % ("attack" if def.shield == "any" else def.shield.capitalize()))
	for rule in def.forbid:
		var who: String = str(rule.get("who", "all"))
		var subject: String = "Neither player may" if who == "all" else ("You may not" if who == "owner" else "Your opponent may not")
		lines.append("%s %s." % [subject, str(FORBID_TEXT.get(str(rule.get("what", "")), str(rule.get("what", ""))))])
	if not def.attachment.is_empty():
		var host: String = "the personality in control" if str(def.attachment.get("target", "in_control")) == "in_control" else "your duelist"
		var parts: PackedStringArray = PackedStringArray()
		for m in def.attachment.get("modifiers", []):
			parts.append(modifier_text(m))
		parts.append_array(effects_text(def.attachment.get("effects", [])))
		if bool(def.attachment.get("damage_removes", false)):
			parts.append("Wounds from those attacks are removed from the game.")
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
			# rather than naming a seat on the table.
			lines.append("While attached, the attached personality's %s" % _lc(" ".join(parts)).trim_prefix("your "))
		else:
			lines.append("While attached to %s: %s" % [host, " ".join(parts)])
		var limit_attached: int = int(def.attachment.get("limit_attached", 0))
		if limit_attached > 0 and named_host != "":
			lines.append("%s may have only %d attached." % [named_host, limit_attached])
		elif limit_attached > 0:
			lines.append("Limit %d attached." % limit_attached)
	if def.remain > 0:
		lines.append("Remain %d.%s" % [def.remain, (" The extra uses are an Ally's." if str(def.raw.get("remain_by", "")) == "ally" else "")])
	if not def.remain_when.is_empty():
		lines.append(_conditional(def.remain_when.get("when", {}), "Remain %d." % int(def.remain_when.get("remain", 1))))
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
	if def.opponent_aspect_threshold > 0:
		lines.append("Your opponent needs %d Fervor to rise an aspect." % def.opponent_aspect_threshold)
	if bool(def.raw.get("protect_drills", false)):
		lines.append("Your Drills cannot be discarded for any reason, an aspect change included.")
	if str(def.raw.get("blocks_to_bottom", "")) != "":
		lines.append("After you stop an attack with %s card that does not remove itself from the game, place it on the bottom of your Life Deck." % _a(school_name(str(def.raw.get("blocks_to_bottom", "")))))
	if int(def.raw.get("art_cost_delta", 0)) != 0:
		lines.append("Your Arts cost %d less Energy, to a minimum of 1." % -int(def.raw.get("art_cost_delta", 0)))
	if bool(def.raw.get("once_per_combat", false)):
		lines.append("Once per Combat.")
	if str(def.raw.get("promote_if_successful", "")) != "":
		lines.append("\"If successful\" lines on your \"%s\" attacks resolve as secondary effects." % str(def.raw["promote_if_successful"]))
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
	if def.raw.has("fervor_gain_cap"):
		lines.append("A card or effect that would raise a duelist's Fervor by more than %d raises it by %d." % [int(def.raw["fervor_gain_cap"]), int(def.raw["fervor_gain_cap"])])
	if str(def.raw.get("discard_if_seal", "")) != "":
		lines.append("If %s is in play, discard this card after use instead." % str(def.raw.get("discard_if_seal_title", "that Seal")))
	if bool(def.raw.get("double_costs", false)):
		lines.append("All Energy and life card costs are doubled.")
	if def.start_in_play:
		if str(def.raw.get("start_in_play", "")) == "may":
			lines.append("Before the first turn begins, you may search your Life Deck for this card and place it into play.")
		else:
			lines.append("Begins the game in play.")
	if def.type == CardDef.Type.SEAL and def.effects.is_empty():
		lines.append("One of the seven %s Seals." % def.seal_set.capitalize())
	if def.type == CardDef.Type.GROUNDS and lines.is_empty():
		lines.append("Placing Grounds skips Combat this turn.")
	if def.bottom_after_use:
		lines.append("Place at the bottom of your Life Deck after use.")
	if def.remove_after_use:
		lines.append("Remove from the game after use.")
	if def.limit_per_deck != 3:
		lines.append("Limit %d per deck." % def.limit_per_deck)
	return "\n".join(lines)


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
	if bool(a.get("stages_from_table", false)):
		s += ", plus the Strike Table result in Energy"
	if int(a.get("life_per_ally", 0)) > 0:
		s += ", plus %d wounds for each Ally you have in play" % int(a["life_per_ally"])
	if bool(a.get("life_from_surge", false)):
		s += ", plus wounds equal to your Surge Rate"
	if a.has("life_per_set_seal"):
		s += ", plus 1 wound for each %s Seal in play" % str(a["life_per_set_seal"]).capitalize()
	s += "."
	if a.has("cost_stages") or int(a.get("cost_life", 0)) > 0 or int(a.get("cost_hand", 0)) > 0:
		var costs: PackedStringArray = PackedStringArray()
		if a.has("cost_stages"):
			costs.append("%d Energy" % int(a["cost_stages"]))
		if int(a.get("cost_life", 0)) > 0:
			costs.append("%d life cards" % int(a["cost_life"]))
		if int(a.get("cost_hand", 0)) > 0:
			costs.append(_plural(int(a["cost_hand"]), "card from your hand", "cards from your hand"))
		s += " Costs %s to perform." % " and ".join(costs)
	if a.has("pay_stages"):
		s += " You may pay any amount of Energy; each %d paid adds %d wound." % [int(a["pay_stages"].get("per", 2)), int(a["pay_stages"].get("life", 1))]
	if bool(a.get("unstoppable", false)):
		s += " Cannot be stopped."
	if bool(a.get("no_prevent", false)):
		s += " Damage cannot be prevented."
	if a.has("no_stop_by"):
		s += " Cannot be stopped by %s cards." % str(a["no_stop_by"]).capitalize()
	if bool(a.get("only_first_attack", false)):
		s += " Must be your first attack this Combat."
	if int(a.get("stops_needed", 1)) > 1:
		s += " Takes %d stops to stop." % int(a["stops_needed"])
	if int(a.get("life_per_opponent_seal", 0)) > 0:
		s += " +%d wounds for each Seal your opponent controls." % int(a["life_per_opponent_seal"])
	return s


static func variant_text(v: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if int(v.get("stages", 0)) != 0:
		parts.append("%+d Energy" % int(v["stages"]))
	if int(v.get("life", 0)) != 0:
		parts.append("%+d %s" % [int(v["life"]), "wound" if absi(int(v["life"])) == 1 else "wounds"])
	if int(v.get("life_per_opponent_seal", 0)) > 0:
		parts.append("+%d wounds for each Seal your opponent controls" % int(v["life_per_opponent_seal"]))
	if bool(v.get("focused", false)):
		parts.append("Focused")
	if bool(v.get("no_prevent", false)):
		parts.append("damage cannot be prevented")
	for e in v.get("effects", []):
		parts.append(_lc(effect_text(e)).trim_suffix("."))
	return _join_and(parts) + "."


static func defense_text(d: Dictionary) -> String:
	var s: String = ""
	match str(d.get("stops", "")):
		"strike":
			s = "Stops a Strike."
		"art":
			s = "Stops an Art."
		"none":
			s = "Use during your attack phase or against an attack. Stops nothing."
		_:
			s = "Stops a Strike or an Art."
	if d.has("when"):
		s = _conditional(d["when"], s)
	if d.has("stop_all"):
		s += " Stops all %s for the remainder of Combat." % ("attacks" if str(d["stop_all"]) == "any" else str(d["stop_all"]).capitalize() + "s")
	if str(d.get("stop_focused", "")) == "discard_hand":
		s += " You may discard a card from your hand to stop a Focused attack."
	elif d.has("stop_focused"):
		s += " Can stop a Focused attack."
	if int(d.get("cost_stages", 0)) > 0:
		s += " Costs %d Energy to use." % int(d["cost_stages"])
	if int(d.get("cost_life", 0)) > 0:
		s += " Costs %d life cards to use." % int(d["cost_life"])
	if d.has("copy_attack"):
		s += " In your next attack phase you may repeat the attack it stopped."
	return s


static func cond_text(when: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for k in when.keys():
		var v: Variant = when[k]
		match str(k):
			"character":
				parts.append("%s is in control" % str(v))
			"duelist_character":
				parts.append("%s is your duelist" % str(v))
			"performed_by":
				parts.append("performed by an Ally" if str(v) == "ally" else "performed by your duelist")
			"aspect_min":
				parts.append("your duelist is aspect %d or higher" % int(v))
			"opponent_fervor":
				parts.append("your opponent's Fervor is %d" % int(v))
			"allies_min":
				parts.append("you have an Ally in play" if int(v) <= 1 else "you have %d or more Allies in play" % int(v))
			"ally_present":
				parts.append("%s is in play" % str(v))
			"opponent_non_combats_min":
				parts.append("your opponent has %d or more Non-Combat cards in play" % int(v))
			"discard_top_school":
				parts.append("the top card of your discard pile is %s" % school_name(str(v)))
			"discard_top_school_not":
				parts.append("the top card of your discard pile is not %s" % school_name(str(v)))
			"discard_top2_school":
				parts.append("the top two cards of your discard pile are %s" % school_name(str(v)))
			"higher_might":
				parts.append("your duelist's Might is higher" if bool(v) else "your duelist's Might is not higher")
			"opponent_used_combat_card":
				parts.append("your opponent used a Combat card this Combat")
			"first_attack":
				parts.append("this is your first attack this Combat")
			"role":
				parts.append("entering Combat as the %s player" % str(v))
			"discard_min":
				parts.append("your discard pile has a card")
			"energy_min":
				parts.append("your duelist has %d or more Energy" % int(v))
			"hand_min":
				parts.append("you have a card in hand" if int(v) <= 1 else "you have %d or more cards in hand" % int(v))
			"stopped_last_phase":
				parts.append("your previous attack was stopped" if bool(v) else "your previous attack was not stopped")
			"attack_focused":
				parts.append("the attack is Focused" if bool(v) else "the attack is not Focused")
			"source_school":
				parts.append("the attack is %s" % school_name(str(v)))
			"attack_kind":
				parts.append("the attack is %s" % ("a Strike" if str(v) == "strike" else "an Art"))
			"opponent_seals_min":
				parts.append("your opponent has a Seal in play")
			"ally_min", "allies_present":
				parts.append("you have %s in play" % _plural(int(v), "Ally", "Allies"))
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
		"fervor":
			body = "%s %s Fervor %d." % [("Raise" if n >= 0 else "Lower"), owner, absi(n)]
		"set_fervor":
			body = "Set %s Fervor to %d." % [owner, n]
		"fervor_needed":
			body = "%s the Fervor %s duelist needs to rise an aspect by %d." % [("Raise" if n >= 0 else "Lower"), owner, absi(n)]
		"set_fervor_needed":
			body = "%s duelist needs %d Fervor to rise an aspect." % [_cap(owner), n]
		"energy":
			if amount is String:
				var target: String = str(e.get("target", ""))
				var whose: String = owner
				match target:
					"duelist":
						whose = "your duelist's"
					"last_searched":
						whose = "its"
					"all":
						whose = "your duelist's and every Ally's"
					"choose":
						whose = "one of your personalities'"
				body = "Raise %s Energy to full." % whose
			elif role:
				body = "%s %s %d Energy." % [_cap(who), ("gains" if n >= 0 else "loses"), absi(n)]
			elif opp:
				var whom: String = "Your opponent's duelist" if str(e.get("target", "")) == "duelist" else "Your opponent"
				body = "%s %s %d Energy." % [whom, ("gains" if n >= 0 else "loses"), absi(n)]
			else:
				body = "%s %d Energy." % [("Gain" if n >= 0 else "Lose"), absi(n)]
		"set_energy":
			body = "Set %s Energy to %d." % [owner, n]
		"draw":
			body = ("Your opponent draws %s." if opp else "Draw %s.") % _plural(n, "card", "cards")
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
				body += " If that card is %s card, %s" % [_a(school_name(str(e["if_school"]))), " ".join(after)]
		"discard_life":
			body = ("Your opponent takes %s." if opp else "Take %s.") % _plural(n, "wound", "wounds")
		"discard_hand":
			var how: String = " at random" if bool(e.get("random", true)) else ""
			if str(e.get("to", "")) == "deck":
				body = "Look at your opponent's hand and shuffle a card of your choice into their Life Deck."
			elif str(e.get("chooser", "")) == "owner":
				body = "Look at your opponent's hand and choose %s. They discard %s." % [_plural(n, "card", "cards"), "it" if n == 1 else "them"]
			elif opp:
				body = "Your opponent discards %s from hand%s." % [_plural(n, "card", "cards"), how]
			elif str(e.get("filter", "")) == "signature":
				body = "Discard %s from your hand%s." % [_plural(n, "Signature card", "Signature cards"), how]
			else:
				body = "Discard %s from your hand%s." % [_plural(n, "card", "cards"), how]
		"remove_hand":
			body = ("Your opponent removes %s in hand from the game." if opp else "Remove %s in your hand from the game.") % _plural(n, "card", "cards")
		"search":
			body = search_text(e)
		"discard_in_play":
			var card_type: String = str(e.get("card_type", "non_combat"))
			var remove: bool = bool(e.get("remove", false))
			if str(e.get("who", "")) == "any":
				# Either side's, so it names neither.
				body = "%s %s in play%s." % [("Remove" if remove else "Discard"), _count_of(e, card_type), (" from the game" if remove else "")]
			elif opp:
				var choice: String = " of your choice" if bool(e.get("choose", false)) else ""
				var count: String = _count_of(e, card_type)
				body = "Your opponent %s %s in play%s%s." % [("removes" if remove else "discards"), count, choice, (" from the game" if remove else "")]
			else:
				var plural: String = type_words(card_type, true)
				var mine: String = "one of your %s" % plural
				if bool(e.get("all", false)):
					mine = "all of your %s" % plural
				elif bool(e.get("up_to", false)):
					mine = "up to %d of your %s" % [n, plural]
				elif n > 1:
					mine = "%d of your %s" % [n, plural]
				body = "%s %s in play%s." % [("Remove" if remove else "Discard"), mine, (" from the game" if remove else "")]
		"remove_discard":
			var how_many: String = "all of"
			if not bool(e.get("all", false)):
				if bool(e.get("choose", false)):
					how_many = "up to %d cards of" % n if bool(e.get("up_to", false)) else ("a card of" if n == 1 else "%d cards of" % n)
				else:
					how_many = "the top card of" if n == 1 else "the top %d cards of" % n
			if bool(e.get("choose_player", false)):
				var share: String = "their whole discard pile" if bool(e.get("all", false)) else "%s their discard pile" % how_many
				body = "Choose a player and remove %s from the game." % share
			else:
				body = "Remove %s %s discard pile from the game." % [how_many, owner]
		"shuffle_discard" when str(e.get("from", "top")) == "top_and_bottom":
			body = "Shuffle the top and bottom cards of your discard pile into your Life Deck."
		"shuffle_discard":
			var kind: String = str(e.get("school", ""))
			var noun_one: String = "card" if kind == "" else "%s card" % school_name(kind)
			var noun_many: String = "cards" if kind == "" else "%s cards" % school_name(kind)
			var pile: String = "your discard pile" if str(e.get("from", "top")) == "top" else "the bottom of your discard pile"
			body ="Shuffle %s from %s into your Life Deck%s." % [("every %s" % noun_one if bool(e.get("all", false)) else _plural(n, noun_one, noun_many)), pile, (" for each personality you have in play" if bool(e.get("per_personality", false)) else "")]
		"recover":
			body = "Place the %s %s of your discard pile at the bottom of your Life Deck." % [str(e.get("from", "top")), ("card" if n == 1 else "%d cards" % n)]
		"end_combat":
			body = "End Combat."
		"skip_next_attack_phase":
			body = "Your opponent skips their next attack phase." if opp else "Skip your next attack phase."
		"cannot_declare_combat":
			body = "%s cannot declare Combat this turn." % _cap(who)
		"stop_all":
			var kind: String = str(e.get("kind", "any"))
			body = "Stops all %s for the remainder of Combat." % ("attacks" if kind == "any" else kind.capitalize() + "s")
		"float":
			var what: String = str(e.get("what", ""))
			var params: Dictionary = e.get("params", {})
			if what == "modifier":
				body = modifier_text(params) if bool(params.get("once", false)) else "For the remainder of Combat, %s" % _lc(modifier_text(params))
			elif what == "make_focused" and params.has("school"):
				body = "For the remainder of Combat, your other %s attacks are Focused." % school_name(str(params["school"]))
			elif what == "after_use_bottom":
				body = "For the remainder of Combat, %s attacks you use go to the bottom of your Life Deck instead." % school_name(str(params.get("school", "")))
			else:
				var span: String = "For the remainder of Combat" if str(e.get("duration", "combat")) == "combat" else ("Until the end of your next turn" if str(e.get("duration", "")) == "next_turn_end" else "For the rest of the turn")
				body = "%s, %s." % [span, str(FLOAT_TEXT.get(what, what))]
		"forbid":
			var subject: String = "Your opponent may not" if opp else "You may not"
			var span: String = " for the remainder of Combat" if str(e.get("duration", "combat")) == "combat" else " this turn"
			var whats: PackedStringArray = PackedStringArray()
			for w in e.get("whats", [e.get("what", "")]):
				whats.append(str(FORBID_TEXT.get(str(w), str(w))))
			body = "%s %s%s." % [subject, " or ".join(whats), span]
		"lose_aspect":
			body = "Your opponent loses one Aspect." if opp else "Lose one Aspect."
		"advance_aspect":
			body = "Your opponent advances one Aspect." if opp else "Advance one Aspect."
		"set_aspect":
			var t: Variant = e.get("aspect", 1)
			if t is String:
				body = "Move your duelist to the aspect equal to your Fervor."
			else:
				body = "Set %s duelist to aspect %d." % [("your opponent's" if who == "your opponent" else "your"), int(t)]
		"no_ascension_win":
			body = "%s cannot win by Ascension for the rest of the game." % _cap(who)
		"attach":
			match str(e.get("to", "in_control")):
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
		"name_card":
			body = "Name a card. Neither player may play or use it while this is in play."
		"next_attack_tax":
			body = "Your opponent pays %d more Energy for their next attack this Combat." % n
		"choose_stop_all_kind":
			body = "Choose Strikes or Arts: all attacks of that kind are stopped for the remainder of Combat, yours included."
		"choose_card_type":
			# One line per choice, each the inner effect read with that card type.
			var choices: PackedStringArray = PackedStringArray()
			for t in e.get("choices", []):
				var inner: Dictionary = (e.get("effect", {}) as Dictionary).duplicate(true)
				inner["card_type"] = str(t)
				choices.append(_lc(effect_text(inner).rstrip(".")))
			body = "Choose one: %s." % " or ".join(choices)
		"recur_source":
			var cost: Dictionary = e.get("cost", {})
			var what: String = "Signature card" if str(cost.get("signature_of", "")) == "duelist" else "card"
			body = "remove a %s from your discard pile to shuffle this card into your Life Deck." % what
		"draw_check":
			var check: String = str(e.get("check", ""))
			var kind: String = "a %s card" % school_name(str(e.get("school", "")))
			if check == "signature":
				kind = "one of your duelist's Signature cards"
			elif check == "named":
				kind = "a Signature card"
			var lead: String = "Discard the top card of your Life Deck." if bool(e.get("discard", false)) else "Draw a card."
			body = "%s If it is %s, %s" % [lead, kind, _lc(" ".join(PackedStringArray(_texts(e.get("effects", [])))))]
			if e.has("else_effects"):
				body += " Otherwise, %s" % _lc(" ".join(PackedStringArray(_texts(e.get("else_effects", [])))))
		"pay_energy":
			body = "Lose any amount of Energy."
		"look_at":
			var pick: Dictionary = e.get("pick", {})
			var what: String = type_words(str(pick.get("card_type", "card")), false)
			if pick.has("title_contains"):
				what = "\"%s\" card" % str(pick["title_contains"])
			body = "Look at the %s %d cards of your Life Deck. You may put %s from among them into %s." % [str(e.get("from", "top")), n, _a(what), ("play" if str(e.get("to", "hand")) == "play" else "your hand")]
			if bool(e.get("rearrange", false)) and not e.has("pick"):
				body = "Look at the %s %d cards of your Life Deck and put them back in any order." % [str(e.get("from", "top")), n]
			elif bool(e.get("rearrange", false)):
				body += " Put the rest back in any order."
			if e.has("play_if") and e["play_if"].has("title_contains"):
				body += " A \"%s\" card may go into play instead." % str(e["play_if"]["title_contains"])
			if bool(e.get("shuffle_after", false)):
				body += " Shuffle the rest back."
		"choose_forbid_type":
			body = "Choose Strike, Art, or Combat cards. Your opponent cannot use that type for the remainder of Combat"
			if int(e.get("unless_energy_min", 0)) > 0:
				body += " unless their duelist has %d or more Energy" % int(e["unless_energy_min"])
			body += "."
		"return_removed":
			body = "Shuffle your removed %s into your Life Deck." % ("Allies" if str(e.get("card_type", "")) == "ally" else "cards")
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
			body = "Neither player may %s%s." % [" or ".join(whats), span]
		"discard_in_play_both":
			var card_type: String = str(e.get("card_type", "non_combat"))
			body = "All %s in play are %s." % [type_words(card_type, true), ("removed from the game" if bool(e.get("remove", false)) else "discarded")]
		"spend_source", "finish_source", "after_action", "after_attack":
			return ""
		_:
			body = str(e.get("op", "?"))
	if bool(e.get("may", false)):
		if str(e.get("asks", "")) == "opponent" and body.begins_with("Your opponent "):
			# The choice is theirs, so the line reads as theirs rather than as something you do.
			var theirs: String = body.substr(14)
			var their_verb: String = theirs.get_slice(" ", 0)
			body = "Your opponent may %s%s" % [str(OPPONENT_VERBS.get(their_verb, their_verb)), theirs.substr(their_verb.length())]
		elif body.begins_with("Your opponent "):
			var rest: String = body.substr(14)
			var verb: String = rest.get_slice(" ", 0)
			body = "You may have your opponent %s%s" % [str(OPPONENT_VERBS.get(verb, verb)), rest.substr(verb.length())]
		elif body.begins_with("You "):
			body = "You may " + body.substr(4)
		else:
			body = "You may " + _lc(body)
	if e.has("then"):
		var follow: PackedStringArray = PackedStringArray()
		for t in e["then"]:
			var tt: String = effect_text(t)
			if tt != "":
				follow.append(_lc(tt))
		if not follow.is_empty():
			body += (" For each Energy lost, " if str(e.get("op", "")) == "pay_energy" else " If you do, ") + " ".join(follow)
	if e.has("otherwise"):
		var other: PackedStringArray = PackedStringArray()
		for t in e["otherwise"]:
			var tt: String = effect_text(t)
			if tt != "":
				other.append(_lc(tt))
		if not other.is_empty():
			body += (" If they do not, " if str(e.get("asks", "")) == "opponent" else " If you do not, ") + " ".join(other)
	return body


const OPPONENT_VERBS: Dictionary = {
	"discards": "discard", "removes": "remove", "loses": "lose", "gains": "gain", "takes": "take",
	"draws": "draw", "skips": "skip", "pays": "pay", "must": "",
}

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
			return "At the start of your turn"
		"on_attack":
			return "When you perform an attack"
		"on_success":
			return "After a successful attack"
		"on_wound":
			var head: String = "If this card is discarded from your Life Deck"
			if str(e.get("at", "")) == "fight_back":
				head += ", at the start of the next fight-back phase this turn"
			return head
		"entering_combat":
			var head: String = "When entering Combat"
			if str(e.get("role", "")) != "":
				head += " as the %s player" % str(e["role"])
			return head
		_:
			return ""


static func effect_text(e: Dictionary) -> String:
	var body: String = _effect_body(e)
	if body == "":
		return ""
	var when: Dictionary = e.get("when", {})
	var trigger: String = str(e.get("trigger", "secondary"))
	if COLON_TRIGGERS.has(trigger):
		var label: String = str(COLON_TRIGGERS[trigger])
		var inner: String = _conditional(when, body)
		return inner if label == "" else "%s: %s" % [label, inner]
	var lead: Array = _lead(_trigger_head(e), when)
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
				return "Lower their Fervor %d" % absi(n)
			return "Raise your Fervor %d" % n if n > 0 else "Lower your Fervor %d" % absi(n)
		"energy":
			return "Take the Energy"
		"lose_aspect":
			return "Drop an aspect"
		"return_removed":
			return "Take it back from the removed pile"
		"recur_source":
			return "Pay to keep this card"
		"search":
			return "Search for it"
		"choose_card_type":
			return "Do it instead of the damage"
		"discard_in_play":
			return "Discard one" if not opp else "Make them discard one"
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
					inners.append(_conditional(g.get("when", {}), body))
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
		var lead: Array = _lead(_trigger_head(e), e.get("when", {}))
		var prefix: String = str(lead[0])
		var keep_case: bool = bool(lead[1])
		if simple:
			var clauses: PackedStringArray = PackedStringArray()
			for k in range(bodies.size()):
				var clause: String = bodies[k].trim_suffix(".")
				clauses.append(clause if keep_case and k == 0 else _lc(clause))
			lines.append("%s%s." % [prefix, _join_and(clauses)])
		else:
			var rest: PackedStringArray = PackedStringArray()
			for k in range(1, bodies.size()):
				rest.append(bodies[k])
			lines.append("%s%s %s" % [prefix, (bodies[0] if keep_case else _lc(bodies[0])), " ".join(rest)])
	return lines


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
		if op == "forbid" or (op == "discard_in_play" and bool(e.get("all", false))):
			for j in range(i + 1, effects.size()):
				if used.has(j):
					continue
				var f: Dictionary = effects[j]
				if _same_frame(e, f) and str(f.get("op", "")) == op and _who(e) != _who(f) and str(e.get("what", "")) == str(f.get("what", "")) and str(e.get("card_type", "")) == str(f.get("card_type", "")) and bool(e.get("remove", false)) == bool(f.get("remove", false)) and str(e.get("duration", "combat")) == str(f.get("duration", "combat")):
					used[j] = true
					var both: Dictionary = e.duplicate()
					both["op"] = op + "_both"
					both["whats"] = [e.get("what", "")]
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


static func _texts(effects: Array) -> Array[String]:
	var out: Array[String] = []
	for e in effects:
		out.append(effect_text(e))
	return out


static func search_text(e: Dictionary) -> String:
	var source: String = str(e.get("source", "deck"))
	var from: String = "your Life Deck"
	match source:
		"discard":
			from = "your discard pile"
		"either":
			from = "your Life Deck or discard pile"
		"reserve":
			from = "your Reserve"
	var card_type: String = str(e.get("card_type", "card"))
	var qual: PackedStringArray = PackedStringArray()
	if str(e.get("school", "*")) != "*":
		qual.append(school_name(str(e["school"])))
	if str(e.get("title_contains", "")) != "":
		qual.append("\"%s\"" % str(e["title_contains"]))
	if str(e.get("tag", "")) != "":
		qual.append(str(e["tag"]).capitalize())
	if str(e.get("signature_of", "")) == "duelist":
		qual.append("Signature")
	if e.has("aspect"):
		qual.append("aspect %d" % int(e["aspect"]))
	var n: int = int(e.get("amount", 1))
	var noun: String = (" ".join(qual) + " " if not qual.is_empty() else "") + type_words(card_type, n != 1)
	# A search of the Life Deck always allows taking nothing, so asking for several is "up to".
	var what: String = _a(noun) if n == 1 else "up to %d %s" % [n, noun]
	if e.has("has_effect"):
		var spec: Dictionary = e["has_effect"]
		if str(spec.get("op", "")) == "discard_hand" and str(spec.get("who", "")) == "opponent":
			what += " that makes your opponent discard from hand"
		else:
			what += " with a \"%s\" effect" % str(spec.get("op", "")).replace("_", " ")
	if str(e.get("exclude_title", "")) != "":
		what += " other than \"%s\"" % str(e["exclude_title"])
	var dest: String = "your hand"
	if str(e.get("to", "hand")) == "play":
		dest = "play" + (" at Energy %d" % int(e["stages"]) if e.has("stages") else "")
	if e.has("amount_per_set_seal"):
		what = "X cards"
	var tail: String = " X = the number of %s Seals in play." % str(e["amount_per_set_seal"]).capitalize() if e.has("amount_per_set_seal") else ""
	var plural_pick: bool = n != 1 or e.has("amount_per_set_seal")
	if source == "hand":
		return "Place %s from your hand into play." % what
	if str(e.get("to", "hand")) == "deck_bottom":
		return "Choose %s from %s and place %s on the bottom of your Life Deck.%s" % [what, from, ("them" if plural_pick else "it"), tail]
	if str(e.get("to", "hand")) == "deck_shuffle":
		return "Choose %s from %s and shuffle %s into your Life Deck.%s" % [what, from, ("them" if plural_pick else "it"), tail]
	if str(e.get("to", "hand")) == "attack":
		return "Search %s for %s and perform it during this attack phase." % [from, what]
	return"Search %s for %s and put %s into %s." % [from, what, ("it" if n == 1 else "them"), dest]


## A school modifier that sits beside a matching one for every attack stacks with it in play, so
## the card reads it as the total and says "instead" rather than printing two separate bonuses the
## player has to add up. Anything without that pairing comes back untouched.
static func _rolled_up(m: Dictionary, all: Array) -> Dictionary:
	if not m.has("school"):
		return m
	var rolled: Dictionary = m.duplicate(true)
	var stacked: bool = false
	for other in all:
		var o: Dictionary = other
		if o.has("school") or str(o.get("scope", "own")) != str(m.get("scope", "own")) or str(o.get("kind", "any")) != str(m.get("kind", "any")):
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
	var parts: PackedStringArray = PackedStringArray()
	if int(m.get("stages", 0)) != 0:
		parts.append("%+d Energy" % int(m["stages"]))
	if int(m.get("life", 0)) != 0:
		parts.append("%+d %s" % [int(m["life"]), "wound" if absi(int(m["life"])) == 1 else "wounds"])
	var amount: String = " and ".join(parts)
	if bool(m.get("per_ally", false)):
		amount += " for each Ally you have in play"
	var s: String = ""
	if bool(m.get("once", false)):
		s = "Your next attack does %s." % amount
	elif scope == "own":
		s = "Your %s do %s%s." % [what, amount, (" instead" if bool(m.get("instead", false)) else "")]
	else:
		s = "%s against you do %s." % [_cap(what), amount.replace("+", "-")]
	if m.has("when"):
		s = _conditional(m["when"], s)
	return s


## Power, constants, Defense Shield of one aspect.
static func aspect_text(def: CardDef, aspect: int = 0) -> PackedStringArray:
	var t: int = aspect if aspect > 0 else def.lowest_aspect()
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
	if uses > 1:
		power.append("May be used %s per Combat." % ("twice" if uses == 2 else "%d times" % uses))
	if not power.is_empty():
		lines.append("Power: " + " ".join(power))
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
	if bool(c.get("attacks_focused", false)):
		lines.append("All of your attacks are Focused.")
	if bool(c.get("damage_removes", false)):
		lines.append("Wounds from your attacks are removed from the game.")
	if bool(c.get("protect_allies", false)):
		lines.append("Your Allies cannot be discarded or removed by your opponent's card effects.")
	if bool(c.get("ally_control_any_stage", false)):
		lines.append("Your Allies may take control of Combat at any Energy.")
	for m in c.get("modifiers", []):
		lines.append(modifier_text(m))
	if bool(c.get("allies_share", false)):
		lines.append("Your Allies get these modifiers too.")
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
			return "Let it resolve"
		&"defend":
			return "Defend with %s" % name
		&"power_defend":
			return "Defend with %s's Power" % name
		&"no_defense":
			return "Take it"
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
		&"discard_ally":
			return "Discard %s" % name
		&"lower_fervor":
			return "Lower their Fervor 1"
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
		&"discard_choice":
			return "Discard %s" % name
		&"pick_in_play":
			return "Choose %s" % name
		&"pick_none":
			if engine.prompt != null and bool(engine.prompt.context.get("search", false)):
				return "Done looking" if int(engine.prompt.context.get("amount", 1)) <= 0 else "Take nothing"
			return "Choose none"
		&"name_card":
			return "Name %s" % str(cmd.value)
		&"pick_option":
			if name != "":
				return name
			var ctx: Dictionary = engine.prompt.context if engine != null and engine.prompt != null else {}
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
			return "Counter %s?" % countered if countered != "" else "Counter the Combat card?"
		&"defense":
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
					var dest: String = "into play" if str(p.context.get("to", "hand")) == "play" else "into your hand"
					return "%s: take a card %s" % [asker, dest] if asker != "" else "Take a card %s" % dest
				"capture":
					return "%s: capture which Seal?" % asker if asker != "" else "Capture which Seal?"
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


## One line per engine event for the log. Empty string means do not log.
static func event_line(ev: GameEvent, engine: DuelEngine, seat: int = -1) -> String:
	var d: Dictionary = ev.data
	var actor: int = int(d.get("player", -1))
	var pname: String = _pname(engine, int(d.get("player", -1)))
	match ev.type:
		&"turn_start":
			return "— Turn %d: %s —" % [int(d.get("turn", 0)), pname]
		&"dev":
			return "Dev: %s runs %s on %s." % [pname, str(d.get("op", "")), ("the rival" if str(d.get("who", "self")) == "opponent" else "themselves")]
		&"draw":
			return "%s draws." % pname
		&"card_placed":
			return "%s places %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"drill_shuffled_back":
			return "%s shows %s and shuffles it back into the Life Deck." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"rearranged":
			return "%s puts %d cards back in a chosen order." % [pname, int(d.get("count", 0))]
		&"power_up":
			return "%s powers up %d to Energy %d." % [pname, int(d.get("gain", 0)), int(d.get("energy", 0))]
		&"combat_declared":
			return "%s declares Combat!" % pname
		&"combat_skipped":
			return "%s skips Combat." % pname
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
		&"cost_paid":
			return "%s pays %d Energy." % [pname, int(d.get("stages", 0))]
		&"countered":
			return "%s counters %s with %s." % [pname, _cname(engine, int(d.get("target", -1))), _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"defense_played":
			return "%s defends with %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"defense_power":
			return "%s defends with a Power." % pname
		&"no_defense":
			if not bool(d.get("auto", false)):
				return "%s does not defend." % pname
			match str(d.get("reason", "")):
				"none":
					return "%s has no defense." % pname
				"final_strike":
					return "%s cannot defend after a Final Strike." % pname
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
			return "A Seal surfaces and returns to the deck."
		&"seal_captured":
			return "%s captures %s!" % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"critical_ally":
			return "Critical damage: %s sends %s off the field." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
		&"critical_fervor":
			return "Critical damage: %s shames the rival." % pname
		&"fervor_changed":
			if int(d.get("from", 0)) == int(d.get("to", 0)):
				return ""
			var by: String = _cname(engine, int(d.get("source", -1)))
			var lead: String = "%s: " % by if by != "a card" else ""
			return "%s%s's Fervor %d → %d." % [lead, pname, int(d.get("from", 0)), int(d.get("to", 0))]
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
			return "%s loses a life card: %s." % [pname, _cname(engine, int(d.get("card", -1)), seat, actor)]
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
		&"fervor_needed_changed":
			return "%s now needs %d Fervor to rise an aspect." % [pname, int(d.get("to", 0))]
		&"aspect_up":
			return "%s ascends: %s!" % [pname, aspect_name(int(d.get("aspect", 1)), _duelist_def(engine, actor))]
		&"aspect_down":
			return "%s falls back: %s." % [pname, aspect_name(int(d.get("aspect", 1)), _duelist_def(engine, actor))]
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
		&"recover":
			return "%s returns a card to the Life Deck." % pname
		&"final_strike":
			return "%s commits to a Final Strike." % pname
		&"control":
			return "%s takes control of Combat." % _cname(engine, int(d.get("card", -1)), seat, actor)
		&"redirect":
			return "%s takes the damage." % _cname(engine, int(d.get("card", -1)), seat, actor)
		&"bracket_rule":
			return "The weaker duelist opens the duel."
		&"reserve_swap":
			return "%s brings %s in from the Reserve." % [pname, _cname(engine, int(d.get("in", -1)), seat, actor)]
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
		&"game_over":
			var reason: String = str(d.get("reason", ""))
			var w: String = _pname(engine, int(d.get("winner", -1)))
			match reason:
				"ascension":
					return "%s ascends fully and the site answers. %s is Eidolarch!" % [w, w]
				"seal":
					return "The seventh Seal is carved and the gate opens. %s is Eidolarch!" % w
				_:
					return "The rival's mind gives out. %s is Eidolarch!" % w
		_:
			return ""


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
		"if_stopped":
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
			return "%s%s may not %s%s." % [lead, pname, str(FORBID_TEXT.get(what, what.replace("_", " "))), span]
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
		"no_ally_control":
			return "%s%s's Allies cannot take control%s." % [lead, pname, span]
		"damage_removes":
			return "%s%s's wounds remove cards from the game%s." % [lead, pname, span]
		"next_attack_tax":
			return "%s%s's next attack costs %d more Energy." % [lead, pname, int(d.get("stages", 0))]
		"modifier", "stopped_last", "prevent_art_life", "copied_attack":
			return ""
		_:
			return "%s%s: %s in effect%s." % [lead, pname, str(d.get("op", "")).replace("_", " "), span]


## Strike Table bands are lettered A upward, as on the printed table.
static func band_letter(band: int) -> String:
	return char(65 + clampi(band, 0, 25))


static func might_band(might: int, band: int) -> String:
	return "%s (%s)" % [short_number(might), band_letter(band)]


## "4 stages, 1 wound" with the right plurals; "no damage" when both are 0.
static func damage_amount(stages: int, life: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if stages != 0:
		parts.append("%d stage%s" % [stages, "" if absi(stages) == 1 else "s"])
	if life != 0:
		parts.append("%d wound%s" % [life, "" if absi(life) == 1 else "s"])
	return ", ".join(parts) if not parts.is_empty() else "no damage"


## Table wording for a damage total: "7 Energy", "4 wounds", "3 Energy, 2 wounds", "nothing".
static func short_damage(stages: int, life: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if stages != 0:
		parts.append("%d Energy" % stages)
	if life != 0:
		parts.append("%d wound%s" % [life, "" if absi(life) == 1 else "s"])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


## The base attack as a face badge: {kind, num, word}. A plain Strike reads "Table Energy", a
## modified one "+3 Energy", a printed one "7 Energy"; an Art reads "4 wounds" from its base or
## printed number. A card with both Energy and wound lines shows the Energy and notes the wounds.
static func attack_badge(def: CardDef) -> Dictionary:
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


## One breakdown entry without its source: "+2 stages", "x2", "cap 3 stages".
static func add_text(add: Dictionary) -> String:
	if add.has("multiply"):
		return "x%d" % int(add["multiply"])
	if add.has("cap_stages"):
		return "cap %d stages" % int(add["cap_stages"])
	if add.has("cap_life"):
		return "cap %d wounds" % int(add["cap_life"])
	return signed_damage(int(add.get("stages", 0)), int(add.get("life", 0)))


## "+2 stages", "-1 wound", "+1 stage +1 wound"; for breakdown lines.
static func signed_damage(stages: int, life: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if stages != 0:
		parts.append("%+d stage%s" % [stages, "" if absi(stages) == 1 else "s"])
	if life != 0:
		parts.append("%+d wound%s" % [life, "" if absi(life) == 1 else "s"])
	return " ".join(parts)


static func _duelist_def(engine: DuelEngine, i: int) -> CardDef:
	if i < 0 or i >= engine.state.players.size() or engine.state.players[i].duelist == null:
		return null
	return engine.state.players[i].duelist.def


static func _pname(engine: DuelEngine, i: int) -> String:
	if i < 0 or i >= engine.state.players.size():
		return "?"
	return engine.state.players[i].name


## A card's title for a log line. With a `seat`, the title shows only if that seat may see the card
## where it sits now or is the `actor` whose own play it was; otherwise "a card". Seat -1 sees all.
static func _cname(engine: DuelEngine, uid: int, seat: int = -1, actor: int = -1) -> String:
	var c: CardInstance = engine.card(uid)
	if c == null:
		return "a card"
	if seat >= 0 and seat != actor and not SeatCard.visible_to(c, seat):
		return "a card"
	return c.def.title


static func _sees(engine: DuelEngine, uid: int, seat: int, actor: int) -> bool:
	var c: CardInstance = engine.card(uid)
	return c != null and (seat < 0 or seat == actor or SeatCard.visible_to(c, seat))
