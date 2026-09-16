class_name CardText
extends RefCounted
## Human-readable text for cards, prompts, and the log. Pure functions over engine data.

const TIER_NAMES: Array[String] = ["", "Noticed", "Regarded", "Esteemed", "Honored", "Chosen"]
const GUILD_NAMES: Dictionary = {
	"": "Freestyle", "ember": "Ember", "tide": "Tide", "storm": "Storm",
	"shade": "Shade", "steel": "Steel", "root": "Root",
}
const TYPE_LABELS: Dictionary = {
	CardDef.Type.FIGHTER: "Fighter", CardDef.Type.ALLY: "Ally", CardDef.Type.STRIKE: "Strike",
	CardDef.Type.ART: "Art", CardDef.Type.COMBAT: "Combat", CardDef.Type.NON_COMBAT: "Non-Combat",
	CardDef.Type.DRILL: "Drill", CardDef.Type.TOKEN: "Royal Token", CardDef.Type.GROUNDS: "Grounds",
	CardDef.Type.MASTERY: "Mastery", CardDef.Type.MASTER: "Master",
}
const FORBID_TEXT: Dictionary = {
	"strike_attacks": "perform Strikes", "art_attacks": "perform Arts", "combat_cards": "use Combat cards",
	"strike_cards": "use Strike cards", "art_cards": "use Art cards", "powers": "use Powers",
	"mastery": "use a Mastery", "drills": "use Drills", "non_combats": "use Non-Combat cards",
	"end_combat": "use cards that end Combat", "stop_all": "use cards that stop all attacks",
	"tokens": "place Royal Tokens", "non_attack_actions": "do anything but attack or pass",
	"skip_combat": "skip declaring Combat",
}
const FLOAT_TEXT: Dictionary = {
	"no_prevent": "damage from your attacks cannot be prevented",
	"prevent_all": "all damage from attacks against you is prevented",
	"make_focused": "your attacks are Focused",
	"after_use_bottom": "your guild attacks go to the bottom of your Life Deck after use",
	"damage_removes": "wounds from your attacks are removed from the game",
	"no_gain": "your opponent's fighters cannot gain Vigor",
	"no_ally_control": "your opponent's Allies cannot take control or take damage",
	"keep_hand": "you keep your hand through the Discard step",
	"endurance_boost": "your next Endurance prevents all remaining damage",
	"no_endurance": "your opponent cannot use Endurance",
	"stop_next": "the next attack against you is stopped",
	"prevent_art_life": "Arts against you deal no wounds",
}


## Keywords in rules text: a regex over the generated wording, a colour role the client maps to a
## colour, and the tooltip a player reads on hover. Longer phrases are listed before the words they
## contain so a match takes the longer one.
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
		"tip": "A standing defense on a fighter or Drill: it stops the first unstopped attack of the named kind each Combat without spending a card."},
	{"key": "Strike Table", "pattern": "\\bStrike Table\\b", "role": "might",
		"tip": "The table that turns both fighters' Might into a Strike's base damage. The gap between Might bands sets how much Vigor a plain Strike takes."},
	{"key": "Royal Token", "pattern": "\\bRoyal Tokens?\\b", "role": "token",
		"tip": "The king's marks, seven to a set. Holding all seven of one set wins the duel. A captured Token changes hands."},
	{"key": "Non-Combat", "pattern": "\\bNon-Combat(?: cards?| step)?\\b", "role": "non_combat",
		"tip": "A card placed during your Non-Combat step that stays in play until something discards it. Drills are Non-Combat cards."},
	{"key": "Combat card", "pattern": "\\bCombat cards?\\b", "role": "combat",
		"tip": "A hand card played during Combat that is neither an attack nor a plain defense. Some cards can cancel a Combat card as it is played."},
	{"key": "Signature", "pattern": "\\bSignature cards?\\b", "role": "plain",
		"tip": "A card named for a fighter or their house. Only that fighter may use it, and searches for Signature cards find these."},
	{"key": "Life Deck", "pattern": "\\bLife Deck\\b", "role": "zone",
		"tip": "Your draw pile and your fighter's health. Every wound discards its top card. Running out of cards loses the duel."},
	{"key": "discard pile", "pattern": "\\bdiscard pile\\b", "role": "zone",
		"tip": "Where used cards and wounds go. Cards here can be recovered by effects; cards removed from the game cannot."},
	{"key": "in control", "pattern": "\\b(?:in control|takes? control|take control of Combat)\\b", "role": "ally",
		"tip": "The personality fighting for you this Combat. Your fighter has control unless an Ally steps in, which an Ally may do once your fighter is out of Vigor."},
	{"key": "Knights only", "pattern": "\\b(?:Knights|Knaves) only\\b", "role": "plain",
		"tip": "Only a fighter of that side of the court may include and use this card."},
	{"key": "Limit", "pattern": "\\bLimit \\d+ per deck\\b", "role": "plain",
		"tip": "The most copies of this card a deck may hold, Life Deck and Armory together."},
	{"key": "Endurance", "pattern": "\\bEndurance(?: \\d+| X)?\\b", "role": "defense",
		"tip": "When this card is discarded as a wound, it soaks that many further wounds from the same attack."},
	{"key": "Empower", "pattern": "\\bEmpower(?:ed)?(?: \\d+)?\\b", "role": "focus",
		"tip": "You may perform this attack Empowered: it deals that many extra wounds, but every other effect on the card is lost."},
	{"key": "Focused", "pattern": "\\bFocused\\b", "role": "attack",
		"tip": "A Focused attack gets past defenses that stop all attacks. Only a defense that says it can stop a Focused attack, or a stop-all that names Focused, can stop it."},
	{"key": "Focus", "pattern": "\\bFocus\\b", "role": "focus",
		"tip": "Declared at setup when your deck holds only one guild's cards and that guild's Mastery. A 'Focus:' line applies only if you did."},
	{"key": "Constant", "pattern": "\\bConstant:", "role": "plain",
		"tip": "Always in effect while this is your fighter's tier. It needs no action and cannot be forbidden like a Power."},
	{"key": "Power", "pattern": "\\bPowers?\\b", "role": "plain",
		"tip": "The personality's own action, usable once per Combat unless it says otherwise. It follows the same rules as a card of its kind."},
	{"key": "Vigor", "pattern": "\\bVigor\\b", "role": "vigor",
		"tip": "A fighter's stamina, 0 to 10. Strikes deal their damage to Vigor first and Arts cost Vigor to perform. At 0 the fighter is spent: damage becomes wounds and an Ally may step in."},
	{"key": "Might", "pattern": "\\bMight\\b", "role": "might",
		"tip": "How hard a fighter hits at their current Vigor. The Strike Table compares both fighters' Might to set a Strike's base damage."},
	{"key": "Surge", "pattern": "\\bSurge(?: Rate)?\\b", "role": "vigor",
		"tip": "The Vigor a personality regains during the Recover step each turn."},
	{"key": "Acclaim", "pattern": "\\bAcclaim\\b", "role": "acclaim",
		"tip": "The crowd's regard, 0 to 5. At 5 the king raises the fighter one Favor tier, Vigor refills, and Acclaim starts again at 0."},
	{"key": "Favor", "pattern": "\\bFavor(?: tiers?)?\\b", "role": "favor",
		"tip": "The king's regard for this duel, in tiers: Noticed, Regarded, Esteemed, Honored, Chosen. Rising a tier refills Vigor and discards your Drills. Reaching the top tier wins by Favor."},
	{"key": "tier", "pattern": "\\btier \\d\\b|\\bNoticed\\b|\\bRegarded\\b|\\bEsteemed\\b|\\bHonored\\b|\\bChosen\\b", "role": "favor",
		"tip": "A Favor tier. Every duel starts at Noticed (tier 1); Chosen is the top."},
	{"key": "wounds", "pattern": "\\bwounds?\\b", "role": "attack",
		"tip": "Damage to the Life Deck. Each wound discards the top card of the Life Deck; a fighter with no cards left yields."},
	{"key": "Strike", "pattern": "\\bStrikes?\\b", "role": "strike",
		"tip": "A physical attack. Its base damage comes from the Strike Table and hits Vigor first; anything past 0 Vigor becomes wounds."},
	{"key": "Art", "pattern": "\\bArts?\\b", "role": "art",
		"tip": "A woven technique. Costs 2 Vigor to perform unless the card says otherwise, and its damage is dealt as wounds."},
	{"key": "Drill", "pattern": "\\bDrills?\\b", "role": "drill",
		"tip": "Training kept in play as a Non-Combat card. All of your Drills are discarded when you rise a Favor tier."},
	{"key": "Ally", "pattern": "\\bAll(?:y|ies)\\b", "role": "ally",
		"tip": "A companion in play. An Ally can take control of Combat when your fighter is spent, take a wound in the fighter's place, and use its own Power."},
	{"key": "Grounds", "pattern": "\\bGrounds(?: cards?)?\\b", "role": "grounds",
		"tip": "The dueling grounds. Only one Grounds card is in play at a time; placing one replaces the last and skips Combat that turn."},
	{"key": "Armory", "pattern": "\\bArmory\\b", "role": "master",
		"tip": "Your Master's side deck. At setup you may swap cards from it into your Life Deck, one for one, before the shuffle."},
	{"key": "Mastery", "pattern": "\\bMaster(?:y|ies)\\b", "role": "mastery",
		"tip": "Your guild's standing bonus, in play from the first turn. It needs a Focus in that guild."},
	{"key": "Bond", "pattern": "\\bBond(?:ing|ed)?(?: card)?\\b", "role": "plain",
		"tip": "Two named Allies fold under one Bond card and fight as one at full Vigor. A life card goes under it at the start of each of your turns; at five the Bond ends and both Allies return."},
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


static func tier_name(tier: int) -> String:
	if tier >= 1 and tier < TIER_NAMES.size():
		return TIER_NAMES[tier]
	return "Tier %d" % tier


static func guild_name(guild: String) -> String:
	return str(GUILD_NAMES.get(guild, guild.capitalize()))


static func type_label(def: CardDef) -> String:
	return str(TYPE_LABELS.get(def.type, "Card"))


static func type_line(def: CardDef) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(guild_name(def.guild))
	parts.append(type_label(def))
	if def.alignment_only != "":
		parts.append(def.alignment_only.capitalize() + "s only")
	return " · ".join(parts)


## Card-type words as they appear in text: singular, plural. Keys are the engine's card_type values.
const CARD_TYPE_WORDS: Dictionary = {
	"card": ["card", "cards"], "ally": ["Ally", "Allies"], "drill": ["Drill", "Drills"],
	"non_combat": ["Non-Combat card", "Non-Combat cards"], "non_combat_only": ["Non-Combat card", "Non-Combat cards"],
	"combat": ["Combat card", "Combat cards"], "strike": ["Strike", "Strikes"], "art": ["Art", "Arts"],
	"attack": ["attack card", "attack cards"], "hand_combat": ["Strike, Art, or Combat card", "Strike, Art, or Combat cards"],
	"token": ["Royal Token", "Royal Tokens"], "grounds": ["Grounds card", "Grounds cards"],
	"drill_or_ally": ["Drill or Ally", "Drills and Allies"], "non_combat_or_ally": ["Non-Combat card or Ally", "Non-Combat cards and Allies"],
	"freestyle_drill": ["Freestyle Drill", "Freestyle Drills"], "fighter": ["Fighter", "Fighters"], "mastery": ["Mastery", "Masteries"],
}


static func _who(e: Dictionary) -> String:
	return "your opponent" if str(e.get("who", "self")) == "opponent" else "you"


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


static func _lc(s: String) -> String:
	return s.substr(0, 1).to_lower() + s.substr(1)


static func _a(word: String) -> String:
	return ("an " if word.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + word


## "a card", "an Ally", "3 cards".
static func _plural(n: int, one: String, many: String) -> String:
	if n == 1:
		return _a(one)
	return "%d %s" % [n, many]


static func _focus_only(when: Dictionary) -> bool:
	return when.size() == 1 and bool(when.get("focus", false))


## "Focus: X" for a plain Focus condition, "If cond, x" for anything else, X alone for none.
static func _conditional(when: Dictionary, body: String) -> String:
	if when.is_empty():
		return body
	if _focus_only(when):
		return "Focus: " + body
	return "If %s, %s" % [cond_text(when), _lc(body)]


## The words before an effect's instruction, from its trigger head and condition, plus whether
## the instruction keeps its capital (after a label) or is lowercased (mid-sentence).
static func _lead(head: String, when: Dictionary) -> Array:
	var focus: bool = _focus_only(when)
	var cond: String = "" if when.is_empty() or focus else cond_text(when)
	if head == "":
		if focus:
			return ["Focus: ", true]
		if cond != "":
			return ["If %s, " % cond, false]
		return ["", true]
	if head == "Hit":
		var label: String = "Focus Hit: " if focus else "Hit: "
		if cond != "":
			return [label + "If %s, " % cond, false]
		return [label, true]
	var prefix: String = ("Focus: " if focus else "") + head
	if cond != "":
		prefix += (" and " if head == "If stopped" else ", if ") + cond
	return [prefix + ", ", false]


static func type_words(card_type: String, plural: bool) -> String:
	var key: String = card_type if card_type != "" else "card"
	var words: Array = CARD_TYPE_WORDS.get(key, [key.replace("_", " "), key.replace("_", " ") + "s"])
	return str(words[1 if plural else 0])


## "a Drill", "3 Non-Combat cards", "all Allies", "up to 2 Drills".
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
		elif def.only.has("fighter_character"):
			lines.append("%s only." % str(def.only["fighter_character"]))
	if def.endurance > 0 and def.endurance_when.is_empty():
		lines.append("Endurance %d." % def.endurance)
	elif not def.endurance_when.is_empty():
		lines.append("Endurance X. X = %d if %s, otherwise %d." % [int(def.endurance_when.get("then", 0)), cond_text(def.endurance_when.get("value_if", {})), int(def.endurance_when.get("else", 0))])
	if def.counter == "combat":
		lines.append("Use when needed. Stops the effects of any Combat card.")
	if def.is_attack():
		lines.append(attack_text(def.attack))
		for v in def.attack.get("variants", []):
			lines.append(_conditional(v.get("when", {}), variant_text(v)))
	if def.is_defense():
		lines.append(defense_text(def.defense))
	if def.empower > 0:
		lines.append("Empower %d." % def.empower)
	var effect_lines: PackedStringArray = effects_text(def.effects)
	if def.type == CardDef.Type.MASTER and int(def.raw.get("uses_per_game", 0)) > 0 and not effect_lines.is_empty():
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
		lines.append(modifier_text(m))
	if def.shield != "":
		lines.append("Defense Shield: stops the first unstopped %s each Combat." % ("attack" if def.shield == "any" else def.shield.capitalize()))
	for rule in def.forbid:
		var who: String = str(rule.get("who", "all"))
		var subject: String = "Neither player may" if who == "all" else ("You may not" if who == "owner" else "Your opponent may not")
		lines.append("%s %s." % [subject, str(FORBID_TEXT.get(str(rule.get("what", "")), str(rule.get("what", ""))))])
	if not def.attachment.is_empty():
		var host: String = "the personality in control" if str(def.attachment.get("target", "in_control")) == "in_control" else "your fighter"
		var parts: PackedStringArray = PackedStringArray()
		for m in def.attachment.get("modifiers", []):
			parts.append(modifier_text(m))
		parts.append_array(effects_text(def.attachment.get("effects", [])))
		if bool(def.attachment.get("damage_removes", false)):
			parts.append("Wounds from those attacks are removed from the game.")
		lines.append("While attached to %s: %s" % [host, " ".join(parts)])
	if def.remain > 0:
		lines.append("Remain %d." % def.remain)
	if not def.remain_when.is_empty():
		lines.append(_conditional(def.remain_when.get("when", {}), "Remain %d." % int(def.remain_when.get("remain", 1))))
	if def.type == CardDef.Type.MASTER:
		var flags: PackedStringArray = PackedStringArray()
		if def.armory_size > 0:
			flags.append("Armory %d." % def.armory_size)
		if bool(def.master_flags.get("no_favor_win", false)):
			flags.append("You cannot win by Favor.")
		if bool(def.master_flags.get("acclaim_shield", false)):
			flags.append("Your opponent cannot lower your Acclaim.")
		if bool(def.master_flags.get("tier_shield", false)):
			flags.append("Your opponent cannot lower your Favor tier.")
		for i in range(flags.size()):
			lines.insert(i, flags[i])
	if def.opponent_tier_threshold > 0:
		lines.append("Your opponent needs %d Acclaim to rise a tier." % def.opponent_tier_threshold)
	if bool(def.raw.get("protect_drills", false)):
		lines.append("Your Drills cannot be discarded by card effects.")
	if int(def.raw.get("art_cost_delta", 0)) != 0:
		lines.append("Your Arts cost %d less Vigor, to a minimum of 1." % -int(def.raw.get("art_cost_delta", 0)))
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
		lines.append("Bond of %s. Enters play only through a Bonding card, at full Vigor, with both under it. At the start of each of your turns a life card goes under it; at %d the Bond ends and both return at 3 Vigor." % [" and ".join(names), int(def.raw.get("bond_timer_max", 5))])
	if bool(def.raw.get("double_costs", false)):
		lines.append("All Vigor and life card costs are doubled.")
	if def.start_in_play:
		lines.append("May begin the game in play.")
	if def.type == CardDef.Type.TOKEN and def.effects.is_empty():
		lines.append("One of the seven %s Tokens." % def.token_set.capitalize())
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
			parts.append("%d Vigor" % int(a["printed_stages"]))
		if int(a.get("printed_life", 0)) > 0:
			parts.append(_plural(int(a["printed_life"]), "wound", "wounds"))
		s += " dealing " + " and ".join(parts)
	else:
		var mods: PackedStringArray = PackedStringArray()
		if int(a.get("stages", 0)) != 0:
			mods.append("%+d Vigor" % int(a["stages"]))
		if int(a.get("life", 0)) != 0:
			mods.append("%+d %s" % [int(a["life"]), "wound" if absi(int(a["life"])) == 1 else "wounds"])
		if not mods.is_empty():
			s += " doing " + " and ".join(mods)
	if bool(a.get("stages_from_table", false)):
		s += ", plus the Strike Table result in Vigor"
	if int(a.get("life_per_ally", 0)) > 0:
		s += ", plus %d wounds for each Ally you have in play" % int(a["life_per_ally"])
	if bool(a.get("life_from_surge", false)):
		s += ", plus wounds equal to your Surge Rate"
	s += "."
	if a.has("cost_stages") or int(a.get("cost_life", 0)) > 0:
		var costs: PackedStringArray = PackedStringArray()
		if a.has("cost_stages"):
			costs.append("%d Vigor" % int(a["cost_stages"]))
		if int(a.get("cost_life", 0)) > 0:
			costs.append("%d life cards" % int(a["cost_life"]))
		s += " Costs %s to perform." % " and ".join(costs)
	if a.has("pay_stages"):
		s += " You may pay any amount of Vigor; each %d paid adds %d wound." % [int(a["pay_stages"].get("per", 2)), int(a["pay_stages"].get("life", 1))]
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
	if int(a.get("life_per_opponent_token", 0)) > 0:
		s += " +%d wounds for each Royal Token your opponent controls." % int(a["life_per_opponent_token"])
	return s


## What an attack variant adds, as a clause: "+3 Vigor and Focused".
static func variant_text(v: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if int(v.get("stages", 0)) != 0:
		parts.append("%+d Vigor" % int(v["stages"]))
	if int(v.get("life", 0)) != 0:
		parts.append("%+d %s" % [int(v["life"]), "wound" if absi(int(v["life"])) == 1 else "wounds"])
	if int(v.get("life_per_opponent_token", 0)) > 0:
		parts.append("+%d wounds for each Royal Token your opponent controls" % int(v["life_per_opponent_token"]))
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
		s += " Costs %d Vigor to use." % int(d["cost_stages"])
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
			"focus":
				parts.append("you declared a Focus" if bool(v) else "you did not declare a Focus")
			"character":
				parts.append("%s is in control" % str(v))
			"fighter_character":
				parts.append("%s is your fighter" % str(v))
			"performed_by":
				parts.append("performed by an Ally" if str(v) == "ally" else "performed by your fighter")
			"tier_min":
				parts.append("your fighter is tier %d or higher" % int(v))
			"opponent_acclaim":
				parts.append("your opponent's Acclaim is %d" % int(v))
			"allies_min":
				parts.append("you have an Ally in play" if int(v) <= 1 else "you have %d or more Allies in play" % int(v))
			"ally_present":
				parts.append("%s is in play" % str(v))
			"opponent_non_combats_min":
				parts.append("your opponent has %d or more Non-Combat cards in play" % int(v))
			"discard_top_guild":
				parts.append("the top card of your discard pile is %s" % guild_name(str(v)))
			"discard_top_guild_not":
				parts.append("the top card of your discard pile is not %s" % guild_name(str(v)))
			"discard_top2_guild":
				parts.append("the top two cards of your discard pile are %s" % guild_name(str(v)))
			"higher_might":
				parts.append("your fighter's Might is higher" if bool(v) else "your fighter's Might is not higher")
			"opponent_used_combat_card":
				parts.append("your opponent used a Combat card this Combat")
			"first_attack":
				parts.append("this is your first attack this Combat")
			"role":
				parts.append("entering Combat as the %s player" % str(v))
			"discard_min":
				parts.append("your discard pile has a card")
			"vigor_min":
				parts.append("your fighter has %d or more Vigor" % int(v))
			"opponent_focus":
				parts.append("your opponent declared a Focus" if bool(v) else "your opponent did not declare a Focus")
			"hand_min":
				parts.append("you have a card in hand" if int(v) <= 1 else "you have %d or more cards in hand" % int(v))
			"stopped_last_phase":
				parts.append("your previous attack was stopped" if bool(v) else "your previous attack was not stopped")
			"source_guild":
				parts.append("the attack is %s" % guild_name(str(v)))
			"ally_min", "allies_present":
				parts.append("you have %s in play" % _plural(int(v), "Ally", "Allies"))
			_:
				parts.append("%s is %s" % [str(k).replace("_", " "), str(v)])
	return " and ".join(parts)


## The instruction part of an effect, as a sentence, without its trigger or condition.
static func _effect_body(e: Dictionary) -> String:
	var who: String = _who(e)
	var opp: bool = who == "your opponent"
	var owner: String = "your opponent's" if opp else "your"
	var amount: Variant = e.get("amount", e.get("n", 0))
	var n: int = int(amount) if not (amount is String) else 0
	var body: String = ""
	match str(e.get("op", "")):
		"acclaim":
			body = "%s %s Acclaim %d." % [("Raise" if n >= 0 else "Lower"), owner, absi(n)]
		"set_acclaim":
			body = "Set %s Acclaim to %d." % [owner, n]
		"vigor":
			if amount is String:
				var target: String = str(e.get("target", ""))
				var whose: String = "your fighter's" if target == "fighter" else ("its" if target == "last_searched" else owner)
				body = "Raise %s Vigor to full." % whose
			elif opp:
				body = "Your opponent %s %d Vigor." % [("gains" if n >= 0 else "loses"), absi(n)]
			else:
				body = "%s %d Vigor." % [("Gain" if n >= 0 else "Lose"), absi(n)]
		"set_vigor":
			body = "Set %s Vigor to %d." % [owner, n]
		"draw":
			body = ("Your opponent draws %s." if opp else "Draw %s.") % _plural(n, "card", "cards")
		"draw_until":
			body = "Draw until you have %d cards in hand." % n
		"draw_discard":
			body = "Draw the %s %s of your discard pile." % [str(e.get("from", "bottom")), ("card" if n == 1 else "%d cards" % n)]
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
			else:
				body = "Discard %s from your hand%s." % [_plural(n, "card", "cards"), how]
		"remove_hand":
			body = ("Your opponent removes %s in hand from the game." if opp else "Remove %s in your hand from the game.") % _plural(n, "card", "cards")
		"search":
			body = search_text(e)
		"discard_in_play":
			var card_type: String = str(e.get("card_type", "non_combat"))
			var remove: bool = bool(e.get("remove", false))
			if opp:
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
			body = "Remove %s %s discard pile from the game." % [("all of" if bool(e.get("all", false)) else ("the top card of" if n == 1 else "the top %d cards of" % n)), owner]
		"shuffle_discard":
			body = "Shuffle %s from your discard pile into your Life Deck%s." % [("every card" if bool(e.get("all", false)) else _plural(n, "card", "cards")), (" for each personality you have in play" if bool(e.get("per_personality", false)) else "")]
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
			elif what == "make_focused" and params.has("guild"):
				body = "For the remainder of Combat, your other %s attacks are Focused." % guild_name(str(params["guild"]))
			elif what == "after_use_bottom":
				body = "For the remainder of Combat, %s attacks you use go to the bottom of your Life Deck instead." % guild_name(str(params.get("guild", "")))
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
		"lose_tier":
			body = "Your opponent loses one Favor tier." if opp else "Lose one Favor tier."
		"advance_tier":
			body = "Your opponent advances one Favor tier." if opp else "Advance one Favor tier."
		"set_tier":
			var t: Variant = e.get("tier", 1)
			if t is String:
				body = "Move your fighter to the tier equal to your Acclaim."
			else:
				body = "Set %s fighter to tier %d." % [("your opponent's" if who == "your opponent" else "your"), int(t)]
		"no_favor_win":
			body = "%s cannot win by Favor for the rest of the game." % _cap(who)
		"attach":
			body = "Attach this card to %s." % ("the personality in control" if str(e.get("to", "in_control")) == "in_control" else "your fighter")
		"capture_token":
			body = "Capture a Royal Token."
		"name_card":
			body = "Name a card. Neither player may play or use it while this is in play."
		"next_attack_tax":
			body = "Your opponent pays %d more Vigor for their next attack this Combat." % n
		"choose_stop_all_kind":
			body = "Choose Strikes or Arts: all attacks of that kind are stopped for the remainder of Combat, yours included."
		"draw_check":
			var check: String = str(e.get("check", ""))
			var kind: String = "a %s card" % guild_name(str(e.get("guild", "")))
			if check == "signature":
				kind = "one of your fighter's Signature cards"
			elif check == "named":
				kind = "a Signature card"
			body = "Draw a card. If it is %s, %s" % [kind, _lc(" ".join(PackedStringArray(_texts(e.get("effects", [])))))]
		"pay_vigor":
			body = "Lose any amount of Vigor."
		"look_at":
			var pick: Dictionary = e.get("pick", {})
			var what: String = type_words(str(pick.get("card_type", "card")), false)
			if pick.has("title_contains"):
				what = "\"%s\" card" % str(pick["title_contains"])
			body = "Look at the %s %d cards of your Life Deck. You may put %s from among them into %s." % [str(e.get("from", "top")), n, _a(what), ("play" if str(e.get("to", "hand")) == "play" else "your hand")]
			if e.has("play_if") and e["play_if"].has("title_contains"):
				body += " A \"%s\" card may go into play instead." % str(e["play_if"]["title_contains"])
			if bool(e.get("shuffle_after", false)):
				body += " Shuffle the rest back."
		"choose_forbid_type":
			body = "Choose Strike, Art, or Combat cards. Your opponent cannot use that type for the remainder of Combat"
			if int(e.get("unless_vigor_min", 0)) > 0:
				body += " unless their fighter has %d or more Vigor" % int(e["unless_vigor_min"])
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
			body = "Bond the two named Allies: they leave play under their Bond card, which fights as one Ally at full Vigor."
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
		if body.begins_with("Your opponent "):
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
			body += (" For each Vigor lost, " if str(e.get("op", "")) == "pay_vigor" else " If you do, ") + " ".join(follow)
	return body


const OPPONENT_VERBS: Dictionary = {
	"discards": "discard", "removes": "remove", "loses": "lose", "gains": "gain", "takes": "take",
	"draws": "draw", "skips": "skip", "pays": "pay", "must": "",
}

## Triggers that read as a label followed by an instruction, so their condition sits inside.
const COLON_TRIGGERS: Dictionary = {"use": "Use in Combat", "master_use": "", "opponent_declare": "Use during your opponent's Declare step"}


## The lead-in for an effect's trigger, without its condition. "" for a plain secondary effect.
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


## One effect as a full sentence: trigger, condition, instruction.
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


## A list of effects as lines, with effects that share a trigger and condition folded into one
## sentence, and a forbid or clear-the-board that hits both players said once.
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
				if body == "":
					continue
				var cond: String = cond_text(g.get("when", {})) if g.has("when") else ""
				inners.append(("If %s, %s" % [cond, _lc(body)]) if cond != "" else body)
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
		var head: String = _trigger_head(e)
		var cond: String = cond_text(e.get("when", {})) if e.has("when") else ""
		if cond != "":
			head += (" and " if head in ["If successful", "If stopped"] else (", if " if head != "" else "If ")) + cond
		if simple:
			var clauses: PackedStringArray = PackedStringArray()
			for b in bodies:
				clauses.append(_lc(b).trim_suffix("."))
			lines.append("%s, %s." % [head, _join_and(clauses)])
		else:
			var rest: PackedStringArray = PackedStringArray()
			for k in range(1, bodies.size()):
				rest.append(bodies[k])
			lines.append("%s, %s %s" % [head, _lc(bodies[0]), " ".join(rest)])
	return lines


static func _join_and(parts: PackedStringArray) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	if parts.size() == 2:
		return "%s and %s" % [parts[0], parts[1]]
	var head: PackedStringArray = parts.slice(0, parts.size() - 1)
	return "%s, and %s" % [", ".join(head), parts[parts.size() - 1]]


## Effects fold together when they share a trigger and condition; plain unconditional lines stay apart.
static func _group_key(e: Dictionary) -> String:
	var trigger: String = str(e.get("trigger", "secondary"))
	if COLON_TRIGGERS.has(trigger):
		return trigger
	if _trigger_head(e) == "" and not e.has("when"):
		return ""
	return "%s|%s|%s|%s" % [trigger, JSON.stringify(e.get("when", {})), str(e.get("role", "")), str(e.get("at", ""))]


## A forbid or an all-cards discard aimed at yourself and then at your opponent becomes one effect
## for both. Forbids on the same player with the same span fold their subjects together.
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
		"armory":
			from = "your Armory"
	var card_type: String = str(e.get("card_type", "card"))
	var qual: PackedStringArray = PackedStringArray()
	if str(e.get("guild", "*")) != "*":
		qual.append(guild_name(str(e["guild"])))
	if str(e.get("title_contains", "")) != "":
		qual.append("\"%s\"" % str(e["title_contains"]))
	if str(e.get("tag", "")) != "":
		qual.append(str(e["tag"]).capitalize())
	if str(e.get("signature_of", "")) == "fighter":
		qual.append("Signature")
	var n: int = int(e.get("amount", 1))
	var noun: String = (" ".join(qual) + " " if not qual.is_empty() else "") + type_words(card_type, n != 1)
	var what: String = _a(noun) if n == 1 else "%d %s" % [n, noun]
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
		dest = "play" + (" at Vigor %d" % int(e["stages"]) if e.has("stages") else "")
	return "Search %s for %s and put %s into %s." % [from, what, ("it" if n == 1 else "them"), dest]


static func modifier_text(m: Dictionary) -> String:
	var kind: String = str(m.get("kind", "any"))
	var scope: String = str(m.get("scope", "own"))
	var what: String = "attacks" if kind == "any" else kind.capitalize() + "s"
	if m.has("guild"):
		what = guild_name(str(m["guild"])) + " " + what
	if m.has("title_contains"):
		what = "\"%s\" %s" % [str(m["title_contains"]), what]
	var parts: PackedStringArray = PackedStringArray()
	if int(m.get("stages", 0)) != 0:
		parts.append("%+d Vigor" % int(m["stages"]))
	if int(m.get("life", 0)) != 0:
		parts.append("%+d %s" % [int(m["life"]), "wound" if absi(int(m["life"])) == 1 else "wounds"])
	var amount: String = " and ".join(parts)
	if bool(m.get("per_ally", false)):
		amount += " for each Ally you have in play"
	var s: String = ""
	if bool(m.get("once", false)):
		s = "Your next attack does %s." % amount
	elif scope == "own":
		s = "Your %s do %s." % [what, amount]
	else:
		s = "%s against you do %s." % [_cap(what), amount.replace("+", "-")]
	if m.has("when"):
		s = _conditional(m["when"], s)
	return s


## What a personality's tier card says: its Power (attack, defense, effects, uses), then any
## constant powers, then its Defense Shield. Used by the card face and the roster dump.
static func tier_text(def: CardDef, tier: int = 0) -> PackedStringArray:
	var t: int = tier if tier > 0 else def.lowest_tier()
	var td: Dictionary = def.tier_data(t)
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


## Constant Combat Powers on a personality tier, one sentence each.
static func constant_text(c: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if bool(c.get("first_styled_unstoppable", false)):
		lines.append("Your first attack each Combat with a guild card cannot be stopped.")
	if bool(c.get("attacks_focused", false)):
		lines.append("All of your attacks are Focused.")
	if bool(c.get("damage_removes", false)):
		lines.append("Wounds from your attacks are removed from the game.")
	if bool(c.get("protect_allies", false)):
		lines.append("Your Allies cannot be discarded or removed by your opponent's card effects.")
	if bool(c.get("ally_control_any_stage", false)):
		lines.append("Your Allies may take control of Combat at any Vigor.")
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
		&"armory_in":
			return "Bring in %s" % name
		&"armory_done":
			return "Finish Armory swap"
		&"place":
			return "Place %s" % name
		&"master":
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
			return "Use Endurance"
		&"no_endure":
			return "Decline Endurance"
		&"capture":
			return "Capture %s" % name
		&"no_capture":
			return "No capture"
		&"keep":
			return "Keep %s" % name
		&"discard_all":
			return "Discard everything"
		&"recover":
			return "Recover top discard"
		&"no_recover":
			return "Skip recovery"
		&"pay":
			return "Pay %d Vigor" % int(cmd.value)
		&"discard_choice":
			return "Discard %s" % name
		&"pick_in_play":
			return "Choose %s" % name
		&"pick_none":
			return "Choose none"
		&"name_card":
			return "Name %s" % str(cmd.value)
		&"pick_option":
			if name != "":
				return name
			match str(cmd.value):
				"yes":
					return "Yes, do it"
				"no":
					return "No, skip it"
				_:
					return str(cmd.value).replace("_", " ").capitalize()
		_:
			return str(cmd.type)


static func prompt_title(p: Prompt) -> String:
	match p.kind:
		&"armory":
			return "Armory: bring cards into your Life Deck?"
		&"non_combat":
			return "Non-Combat step: place cards"
		&"declare":
			return "Declare Combat?"
		&"attack_action":
			return "Your attack phase"
		&"respond":
			if str(p.context.get("mode", "")) == "declare":
				return "Your opponent's Declare step: respond?"
			return "Counter the Combat card?"
		&"defense":
			return "Defend against the %s?" % str(p.context.get("kind", "attack")).capitalize()
		&"control":
			return "Who takes control of Combat?"
		&"redirect":
			return "Who takes the damage?"
		&"endurance":
			return "Endurance %d: prevent wounds?" % int(p.context.get("endurance", 0))
		&"capture":
			return "Capture a Royal Token?"
		&"keep":
			return "Discard step: keep one card"
		&"recover":
			return "Recover a card from your discard?"
		&"pay":
			return "Pay extra Vigor?"
		&"discard_choice":
			var n: int = int(p.context.get("amount", 1))
			return "Choose %d cards to discard" % n if n > 1 else "Choose a card to discard"
		&"pick_in_play":
			var n: int = int(p.context.get("amount", 1))
			if n > 1:
				return "Choose up to %d cards in play" % n if bool(p.context.get("up_to", false)) else "Choose %d cards in play" % n
			return "Choose a card in play"
		&"name_card":
			return "Name a card"
		&"pick_option":
			if bool(p.context.get("may", false)):
				return "Optional effect: use it?"
			if bool(p.context.get("search", false)):
				var n: int = int(p.context.get("amount", 1))
				return "Search: take up to %d cards" % n if n > 1 else "Search: take a card"
			return "Choose"
		_:
			return str(p.kind)


## One line per engine event for the log. Empty string means do not log.
static func event_line(ev: GameEvent, engine: DuelEngine) -> String:
	var d: Dictionary = ev.data
	var pname: String = _pname(engine, int(d.get("player", -1)))
	match ev.type:
		&"turn_start":
			return "— Turn %d: %s —" % [int(d.get("turn", 0)), pname]
		&"draw":
			return "%s draws." % pname
		&"card_placed":
			return "%s places %s." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"power_up":
			return "%s powers up %d to Vigor %d." % [pname, int(d.get("gain", 0)), int(d.get("vigor", 0))]
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
			return "%s uses %s." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"power_used":
			return "%s uses %s's Power." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"master_used":
			return "%s calls on %s." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"cost_paid":
			return "%s pays %d Vigor." % [pname, int(d.get("stages", 0))]
		&"countered":
			return "%s counters %s with %s." % [pname, _cname(engine, int(d.get("target", -1))), _cname(engine, int(d.get("card", -1)))]
		&"defense_played":
			return "%s defends with %s." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"defense_power":
			return "%s defends with a Power." % pname
		&"no_defense":
			return "" if bool(d.get("auto", false)) else "%s does not defend." % pname
		&"shield":
			return "%s's Defense Shield activates." % pname
		&"floating_stop":
			return "%s's standing defense stops the attack." % pname
		&"attack_stopped":
			return "The attack is stopped."
		&"attack_successful":
			return "The attack lands."
		&"damage_stages":
			var s: String = "%s loses %d Vigor" % [pname, int(d.get("stages", 0))]
			if int(d.get("overflow", 0)) > 0:
				s += " and takes %d wounds from the overflow" % int(d["overflow"])
			return s + "."
		&"life_card_flipped":
			return "%s takes a wound: %s." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"endurance_used":
			return "%s uses Endurance and prevents %d." % [pname, int(d.get("prevented", 0))]
		&"token_bypassed":
			return "A Royal Token surfaces and returns to the deck."
		&"token_captured":
			return "%s captures %s!" % [pname, _cname(engine, int(d.get("card", -1)))]
		&"acclaim_changed":
			return "%s's Acclaim: %d → %d." % [pname, int(d.get("from", 0)), int(d.get("to", 0))]
		&"acclaim_shielded":
			return "%s's Master shields their Acclaim." % pname
		&"tier_up":
			return "The king raises %s to %s!" % [pname, tier_name(int(d.get("tier", 1)))]
		&"tier_down":
			return "%s falls to %s." % [pname, tier_name(int(d.get("tier", 1)))]
		&"acclaim_peak":
			return "%s is already at the king's peak favor and recovers full Vigor." % pname
		&"no_favor_win":
			return "%s can no longer win by Favor." % pname
		&"combat_end":
			return "Combat ends."
		&"discard_step":
			return "%s discards %d." % [pname, int(d.get("discarded", 0))]
		&"hand_discarded":
			return "%s discards %s from hand." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"recover":
			return "%s returns a card to the Life Deck." % pname
		&"final_strike":
			return "%s commits to a Final Strike." % pname
		&"control":
			return "%s takes control of Combat." % _cname(engine, int(d.get("card", -1)))
		&"redirect":
			return "%s takes the damage." % _cname(engine, int(d.get("card", -1)))
		&"bracket_rule":
			return "The weaker fighter opens the duel."
		&"armory_swap":
			return "%s brings %s in from the Armory." % [pname, _cname(engine, int(d.get("in", -1)))]
		&"search":
			return "%s searches out %s." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"in_play_discarded":
			return "%s loses %s from play." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"attached":
			return "%s attaches %s." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"remain":
			return "%s keeps %s on the table to use again." % [pname, _cname(engine, int(d.get("card", -1)))]
		&"card_named":
			return "%s names %s." % [pname, str(d.get("name", ""))]
		&"token_victory_pending":
			return "%s holds all seven Tokens. The king decides at the start of their next turn." % pname
		&"game_over":
			var reason: String = str(d.get("reason", ""))
			var w: String = _pname(engine, int(d.get("winner", -1)))
			match reason:
				"favor":
					return "%s wins the king's Favor!" % w
				"token":
					return "%s holds all seven Tokens and is crowned!" % w
				_:
					return "%s wins. The rival yields." % w
		_:
			return ""


static func _pname(engine: DuelEngine, i: int) -> String:
	if i < 0 or i >= engine.state.players.size():
		return "?"
	return engine.state.players[i].name


static func _cname(engine: DuelEngine, uid: int) -> String:
	var c: CardInstance = engine.card(uid)
	return c.def.title if c != null else "a card"
