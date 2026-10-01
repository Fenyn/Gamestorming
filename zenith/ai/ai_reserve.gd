class_name AiReserve
extends RefCounted
## The Reserve swap. A Reserve holds three kinds of card: answers that are strong against one
## kind of deck and dead against the rest, plain strong cards, and a toolbox that a card in the
## main deck can fetch from the Reserve later. Each card brought in pushes a random Life Deck card
## out, so a card comes in only when it is worth more than the average card it replaces.
##
## What the opponent is playing is read from what both players show before the swap: the deck's
## declared archetype and subthemes, and their duelist, Mastery and Relic. Everything is read
## from data, never from card ids.

## What an answer card is aimed at, and the matching sign in the opponent's setup cards.
const KINDS: Array[String] = ["ally", "drill", "non_combat", "seal"]
## How likely a deck is to hold a kind of card when its setup cards say nothing about it.
const PRIOR: float = 0.25


## How much `c` is worth bringing in for `seat`, above zero to swap. `profile.reserve` sets how
## much an answer counts (`tech`), how much a toolbox target is worth leaving behind
## (`toolbox_keep`) and the bar to clear (`threshold`).
static func score(engine: DuelEngine, seat: int, c: CardInstance, profile: AiProfile) -> float:
	var me: PlayerState = engine.player(seat)
	var def: CardDef = c.def
	if def.start_in_play:
		return -INF   # it begins the game in play from the Reserve; swapping it in only loses a card
	if def.raw.has("bond_of"):
		return -INF   # a Bond card is fetched by its Bonding card, never drawn
	if not _usable_by(def, me):
		return -INF
	var signs: Dictionary = read_setup(engine.player(1 - seat))
	var own: Dictionary = own_shares(me)
	var value: float = AiScorer.hold_value(c, profile) - average_hold(me, profile)
	var tech: float = 0.0
	var aimed: bool = false
	for raw in def.effects:
		var e: Dictionary = raw
		var kind: String = _aimed_kind(e)
		if kind == "":
			continue
		aimed = true
		var reach: float = 2.0 if bool(e.get("all", false)) else 1.0
		# "Discard an Ally in play" with no side named still lets the user pick, so it reads as an
		# answer aimed at the opponent rather than as something that costs the user a card.
		var side: String = str(e.get("who", "self"))
		if side == "opponent" or (side == "any" and bool(e.get("choose", false))):
			tech += (_sign(signs, kind) - 0.5) * 2.0 * reach
		else:
			tech -= _sign(own, kind) * 2.0 * reach   # it hits my own cards of that kind too
	# A line that only works against one declared style ("if your opponent declared a Red
	# Tokui-Waza") is an answer to that style and dead weight against the rest. The style is public.
	var foe_style: String = engine.player(1 - seat).style
	for raw in def.effects:
		var gate: Dictionary = (raw as Dictionary).get("when", {})
		if gate.has("opponent_style"):
			aimed = true
			tech += 1.0 if str(gate["opponent_style"]) == foe_style else -0.5
	for raw in def.forbid:
		var what: String = str((raw as Dictionary).get("what", ""))
		var kind: String = "seal" if what == "seals" else ("drill" if what == "drills" else ("non_combat" if what == "non_combats" else ""))
		if kind != "":
			aimed = true
			tech += (_sign(signs, kind) - 0.5) * 2.0 - _sign(own, kind) * 2.0
	if _pushes_aspects(def):
		# Raising both players' Fervor knocks a deck off the aspect it wants to sit on, and costs
		# me the Ascension win.
		aimed = true
		tech += (float(signs.get("camps", PRIOR)) - 0.5) * 2.0 - profile.w("own", "ascension") / 30.0
	if def.type == CardDef.Type.GROUNDS:
		value += AiEvaluator.grounds_value(engine, seat, def, profile) * 0.5
	var total: float = value * 0.5 + tech * profile.w("reserve", "tech")
	if def.is_attack() and fetches_from_reserve(me):
		total -= profile.w("reserve", "toolbox_keep")   # reachable where it is; keep the deck slot
	return total - profile.w("reserve", "threshold")


## Signs of each kind of deck in a player's duelist, Mastery and Relic: 0 to 1 per kind, plus
## `camps` for a duelist whose lowest aspect carries a constant power worth staying on.
static func read_setup(p: PlayerState) -> Dictionary:
	var words: Dictionary = {}
	for c in [p.duelist, p.mastery, p.relic]:
		if c != null and c.def != null:
			_scan(c.def.raw, words)
	var out: Dictionary = {}
	for kind in KINDS:
		out[kind] = PRIOR
	# Only what a card fetches or shields says what its deck holds; a card that discards the
	# opponent's Non-Combats says nothing about its owner's.
	if words.has("protect_allies") or words.has("allies_share") or words.has("ally_control_any_stage") or words.has("search=ally") or words.has("ally_present") or words.has("allies_min"):
		out["ally"] = 1.0
	if words.has("protect_drills") or words.has("search=drill") or words.has("promote_if_successful"):
		out["drill"] = 1.0
		out["non_combat"] = 0.6
	if words.has("search=seal") or words.has("op=capture_seal") or words.has("seals_min"):
		out["seal"] = 1.0
	if words.has("search=non_combat"):
		out["non_combat"] = 1.0
	# A deck sits on its lowest aspect when that aspect's constant power shields its cards.
	out["camps"] = PRIOR
	if p.duelist != null:
		var lowest: Dictionary = p.duelist.stack.aspect_data(p.duelist.stack.lowest_aspect())
		var constant: Dictionary = lowest.get("constant", {})
		for key in constant.keys():
			if str(key).begins_with("protect_"):
				out["camps"] = 1.0
	# The deck's declared archetype and subthemes are public and say the same things outright.
	var declared: Dictionary = Archetype.signs(p.archetype, p.subthemes)
	for k in declared.keys():
		out[k] = maxf(float(out.get(k, PRIOR)), float(declared[k]))
	return out


## The share of my own Life Deck and Reserve that is each kind, scaled so a deck built around a
## kind reads near 1. Used for cards that hit both sides.
static func own_shares(p: PlayerState) -> Dictionary:
	var counts: Dictionary = {"ally": 0, "drill": 0, "non_combat": 0, "seal": 0}
	for c in p.life_deck:
		match c.def.type:
			CardDef.Type.PERSONALITY:
				counts["ally"] = int(counts["ally"]) + 1
			CardDef.Type.DRILL:
				counts["drill"] = int(counts["drill"]) + 1
			CardDef.Type.NON_COMBAT:
				counts["non_combat"] = int(counts["non_combat"]) + 1
			CardDef.Type.SEAL:
				counts["seal"] = int(counts["seal"]) + 1
	var out: Dictionary = {}
	for kind in counts.keys():
		out[kind] = clampf(float(int(counts[kind])) / 5.0, 0.0, 1.0)
	return out


## True when the main deck holds a card that searches the Reserve, so attacks left there are a
## toolbox and not dead weight.
static func fetches_from_reserve(p: PlayerState) -> bool:
	for c in p.life_deck:
		for raw in c.def.effects:
			if str((raw as Dictionary).get("op", "")) == "search" and str((raw as Dictionary).get("source", "")) == "reserve":
				return true
	return false


static func average_hold(p: PlayerState, profile: AiProfile) -> float:
	if p.life_deck.is_empty():
		return 0.0
	var total: float = 0.0
	for c in p.life_deck:
		total += AiScorer.hold_value(c, profile)
	return total / float(p.life_deck.size())


## The kind of in-play card an effect removes, or "" when it is not an answer card's line.
static func _aimed_kind(e: Dictionary) -> String:
	if str(e.get("op", "")) != "discard_in_play":
		return ""
	match str(e.get("card_type", "non_combat")):
		"ally":
			return "ally"
		"drill", "freestyle_drill":
			return "drill"
		"seal":
			return "seal"
		"non_combat_or_ally", "drill_or_ally":
			return "ally_or_other"
		_:
			return "non_combat"


static func _sign(signs: Dictionary, kind: String) -> float:
	if kind == "ally_or_other":
		return maxf(float(signs.get("ally", PRIOR)), maxf(float(signs.get("non_combat", PRIOR)), float(signs.get("drill", PRIOR))))
	return float(signs.get(kind, PRIOR))


## A card that raises the opponent's Fervor on purpose.
static func _pushes_aspects(def: CardDef) -> bool:
	for raw in def.effects:
		var e: Dictionary = raw
		if str(e.get("op", "")) == "fervor" and str(e.get("who", "self")) == "opponent" and int(e.get("amount", 0)) > 0:
			return true
	return false


static func _usable_by(def: CardDef, p: PlayerState) -> bool:
	if not CardDef.side_allows(p.alignment, def.alignment_only):
		return false
	if def.only.has("duelist_character") and p.duelist.def.character != str(def.only["duelist_character"]):
		return false
	return true


## Collects every key, and every `key=value` for string values, anywhere in a card's data.
static func _scan(v: Variant, words: Dictionary) -> void:
	if v is Dictionary:
		var d: Dictionary = v
		if str(d.get("op", "")) == "search" and d.has("card_type"):
			words["search=%s" % str(d["card_type"])] = true
		for k in d.keys():
			words[str(k)] = true
			if d[k] is String:
				words["%s=%s" % [str(k), str(d[k])]] = true
			else:
				_scan(d[k], words)
	elif v is Array:
		for item in (v as Array):
			_scan(item, words)
