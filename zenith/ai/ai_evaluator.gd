class_name AiEvaluator
extends RefCounted
## How good a position is for one seat, as a single number. It reads generic state only, never
## card ids, so any deck can be judged. Each win route is its own term (Life Decks for survival,
## Fervor and aspects for Ascension, Seals for the set win) and a profile turns routes up or down.
## Only call this on an engine the seat may hold (Referee.sim_for).

const WIN: float = 1000.0


static func evaluate(engine: DuelEngine, seat: int, profile: AiProfile) -> float:
	var s: GameState = engine.state
	if s.is_over():
		return WIN if s.winner == seat else -WIN
	var grounds: CardDef = s.grounds.def if s.grounds != null else null
	return side_value(engine, engine.player(seat), profile, "own") - side_value(engine, engine.player(1 - seat), profile, "foe") + grounds_value(engine, seat, grounds, profile)


## Signed named contributions for diagnostics; requesting a report never changes scoring.
static func explain(engine: DuelEngine, seat: int, profile: AiProfile) -> Dictionary:
	if engine.state.is_over():
		var terminal: float = WIN if engine.state.winner == seat else -WIN
		return {"terminal": true, "terms": {"terminal": terminal}, "total": terminal}
	var own: Dictionary = {}
	var foe: Dictionary = {}
	var own_value: float = side_value(engine, engine.player(seat), profile, "own", own)
	var foe_value: float = side_value(engine, engine.player(1 - seat), profile, "foe", foe)
	var grounds: CardDef = engine.state.grounds.def if engine.state.grounds != null else null
	var ground_value: float = grounds_value(engine, seat, grounds, profile)
	var terms: Dictionary = {}
	for key in own:
		terms["own." + str(key)] = own[key]
	for key in foe:
		terms["foe." + str(key)] = -float(foe[key])
	terms["grounds"] = ground_value
	return {"terminal": false, "terms": terms, "total": own_value - foe_value + ground_value}


static func side_value(engine: DuelEngine, p: PlayerState, profile: AiProfile, group: String, details: Variant = null) -> float:
	var terms: Dictionary = {}
	var life: int = p.life_deck.size()
	terms["life"] = life * profile.w(group, "life")
	terms["life_low"] = -maxi(0, 10 - life) * profile.w(group, "life_low")
	terms["discard"] = p.discard.size() * profile.w(group, "discard")
	terms["energy"] = held_energy(engine, p) * profile.w(group, "energy")
	terms["band"] = engine.strike_table.band(p.in_control().might()) * profile.w(group, "band")
	terms["hand"] = kept_hand(engine, p) * profile.w(group, "hand")
	terms["aspect"] = p.duelist.aspect * profile.w(group, "aspect")
	terms["ascension"] = ascension_progress(engine, p) * profile.w(group, "ascension")
	terms["fervor"] = climb_progress(engine, p) * profile.w(group, "fervor")
	terms["seal"] = seal_progress(p) * profile.w(group, "seal")
	terms["seal_guard"] = seal_guard_value(p) * profile.w(group, "seal_guard")
	terms["ally_handover"] = handover_progress(engine, p) * profile.w(group, "ally_handover")
	var allies: float = 0.0
	for al in p.allies():
		allies += profile.w(group, "ally") + al.energy * profile.w(group, "ally_energy")
	terms["allies"] = allies
	var power_weight: float = _feature_weight(profile, group, "power", 0.35)
	var power: float = 0.0
	if power_weight != 0.0:
		for al in p.allies():
			power += AiScorer.usable_power_value(engine, p, al, profile)
		power += AiScorer.usable_power_value(engine, p, p.duelist, profile)
	terms["power"] = power * power_weight
	# Hand identity is known only on our side. Use the same contextual value as tutor/keep/discard
	# choices, while retaining the ordinary count term for both sides.
	var hand_weight: float = _feature_weight(profile, group, "hand_quality", 0.15)
	var quality: float = 0.0
	if group == "own" and hand_weight != 0.0:
		var seen: Dictionary = {}
		for card in p.hand:
			var copies: int = int(seen.get(card.def.id, 0))
			seen[card.def.id] = copies + 1
			quality += minf(20.0, maxf(0.0, AiScorer.card_value(engine, p, card, profile, AiScorer.TUTOR_DEPTH))) / float(1 + copies)
	terms["hand_quality"] = quality * hand_weight
	var combo_weight: float = _feature_weight(profile, group, "combo_progress", 0.5 if group == "own" else 0.35)
	terms["combo_progress"] = AiScorer.combo_progress(engine, p, profile, group != "own") * combo_weight if combo_weight != 0.0 else 0.0
	terms["drills"] = p.drills().size() * profile.w(group, "drill")
	terms["non_combats"] = p.non_combats().size() * profile.w(group, "non_combat")
	terms["attachments"] = p.attachments().size() * profile.w(group, "attachment")
	terms["restrictions"] = -engine.restrictions(p).size() * profile.w(group, "forbid")
	terms["standing"] = standing_modifier_value(engine, p, profile) * _feature_weight(profile, group, "standing", 1.0)
	var engine_weight: float = _feature_weight(profile, group, "engine", 0.25)
	terms["engine"] = usable_engine_value(engine, p, profile, group != "own") * engine_weight if engine_weight != 0.0 else 0.0
	var v: float = 0.0
	for key in terms:
		v += float(terms[key])
	if details is Dictionary:
		(details as Dictionary).merge(terms, true)
	return v


## The Duelist's Energy as it carries forward. Energy the next Power Up would refill anyway is only
## half held: it still soaks and sets Might through the opponent's turn, but it buys nothing after,
## so spending it on an attack now costs less than the gauge says.
static func held_energy(engine: DuelEngine, p: PlayerState) -> float:
	var energy: int = p.duelist.energy
	var refilled: int = maxi(0, energy + engine.recover_gain(p) - CardInstance.MAX_STAGE)
	return float(energy) - 0.5 * float(mini(refilled, energy))


## The hand as it will stand once it matters. On its own turn a player keeps only a few cards
## through the discard step, so the cards past that limit count half: they can still be played
## this turn, but whatever is left of them goes to the discard pile.
static func kept_hand(engine: DuelEngine, p: PlayerState) -> float:
	var held: int = p.hand.size()
	if engine.state.active != p.index or engine.state.step >= GameState.Step.DISCARD:
		return float(held)
	var keep: int = engine._hand_keep(p)
	return float(mini(held, keep)) + 0.5 * float(maxi(0, held - keep))


## Standing modifiers this side has put out (a floating "+1 to every attack for the rest of the
## game"), priced by what they add per attack and how many attacks they are expected to touch.
static func standing_modifier_value(engine: DuelEngine, p: PlayerState, profile: AiProfile) -> float:
	var total: float = 0.0
	for f in engine.state.floating:
		if int(f.get("owner", -1)) != p.index or str(f.get("op", "")) != "modifier" or not engine._phase_float_live(f):
			continue
		total += AiScorer.modifier_value(f, str(f.get("duration", "combat")), profile)
	return total


static func _feature_weight(profile: AiProfile, group: String, key: String, fallback: float) -> float:
	var weights: Dictionary = profile.data.get(group, {})
	return float(weights.get(key, fallback))


## Available activated card engines, beyond their flat material count. The engine remains the
## authority on gates and usage limits; a spent or prohibited activation has no current utility.
static func usable_engine_value(engine: DuelEngine, p: PlayerState, profile: AiProfile, public_only: bool = false) -> float:
	if engine.state.step != GameState.Step.COMBAT or p.final_strike_used or engine._forbidden(p, "non_attack_actions"):
		return 0.0
	var total: float = 0.0
	var sources: Array[CardInstance] = p.drills()
	sources.append_array(p.non_combats())
	for source in sources:
		var category: String = "drills" if source.def.type == CardDef.Type.DRILL else "non_combats"
		if engine._forbidden(p, category) or not engine._can_play(p, source.def) or not engine._use_allowed(p, source.def):
			continue
		if source.def.type == CardDef.Type.DRILL and not engine._drill_use_available(source):
			continue
		var value: float = 0.0
		for effect in source.def.effects_for("use"):
			value += _available_effect_value(engine, p, source, effect, profile, 8, public_only)
		total += maxf(0.0, value - profile.w("play", "use_cost"))
	return total


static func _available_effect_value(engine: DuelEngine, p: PlayerState, source: CardInstance, effect: Dictionary, profile: AiProfile, depth: int, public_only: bool) -> float:
	# A line whose gate fails is skipped whole, as the engine skips it.
	if depth <= 0 or not engine._cond(effect.get("when", {}), p.index, {}):
		return 0.0
	var op: String = str(effect.get("op", ""))
	var amount: Variant = effect.get("amount", 1)
	if str(effect.get("who", "self")) == "self" and (amount is int or amount is float):
		if op == "discard_hand" and int(amount) > p.hand.size():
			return 0.0
		if op == "remove_discard" and int(amount) > p.discard.size():
			return 0.0
	# Opponent deck/hand identities are not a public engine feature; retain the generic
	# search weight without checking their hidden pool. Their discard is observable.
	var known_pool: bool = not public_only or str(effect.get("source", "deck")) == "discard"
	if op == "search" and known_pool and engine.search_candidates(p, effect).is_empty():
		return 0.0
	if op == "bond" and AiScorer._bond_value(engine, p, source.def, profile) <= 0.0:
		return 0.0
	var value: float = 0.0
	if op != "spend_source":
		var current: Dictionary = effect.duplicate()
		for key in ["then", "effects", "else_effects", "when"]:
			current.erase(key)
		value = AiScorer.effects_value([current], profile, [], AiEvaluator.handover_progress(engine, p))
	for branch in AiScorer.branches(effect, profile):
		value += float(branch["share"]) * _available_effect_value(engine, p, source, branch["effect"], profile, depth - 1, public_only)
	return value


## 0 to 1: how close this side is to fighting through an Ally instead of its Duelist. An Ally only
## takes over once the Duelist is spent, so for a deck built that way the Duelist's own Energy is
## something to spend rather than hoard, and this term prices that. Zero when no Ally is out and
## zero when no Ally would swing harder than the Duelist, so a deck that simply happens to have an
## Ally in play is not pushed into wrecking its own Energy.
static func handover_progress(engine: DuelEngine, p: PlayerState) -> float:
	if p.allies().is_empty():
		return 0.0
	var mine: int = engine.strike_table.band(p.duelist.might())
	var best: int = -1
	for al in p.allies():
		best = maxi(best, engine.strike_table.band(al.might()))
	if best <= mine:
		return 0.0
	if engine.may_ally_control(p):
		return 1.0
	var gap: int = p.duelist.energy - DuelEngine.ALLY_CONTROL_MAX_ENERGY
	return clampf(1.0 - float(gap) / float(CardInstance.MAX_STAGE), 0.0, 1.0)


## What the Grounds `def` are worth to `seat` while they are in play: how much of my deck they
## help or hinder, less the same for the opponent. Grounds bind both players, so a card that
## forbids Non-Combats is good for a deck without any and bad for a Drill deck. Null is no Grounds.
static func grounds_value(engine: DuelEngine, seat: int, def: CardDef, profile: AiProfile) -> float:
	if def == null:
		return 0.0
	var mine: float = _grounds_fit(engine.player(seat), def, true) * profile.w("own", "grounds")
	var theirs: float = _grounds_fit(engine.player(1 - seat), def, false) * profile.w("foe", "grounds")
	return mine - theirs + _grounds_climb_value(def, profile)


## A Fervor cap on the Grounds binds both players, so it is not a per-card matter and `_grounds_fit`
## cannot see it. It is worth the difference between how much the opponent wants to climb and how
## much we do, which the profile already states through its Ascension and Fervor weights.
static func _grounds_climb_value(def: CardDef, profile: AiProfile) -> float:
	if not def.raw.has("fervor_gain_cap"):
		return 0.0
	return (_climb_want(profile, "foe") - _climb_want(profile, "own")) * profile.w("own", "grounds")


## 0 to 1, how badly one side of the table wants its Fervor meter to keep rising.
static func _climb_want(profile: AiProfile, group: String) -> float:
	return clampf(profile.w(group, "ascension") / 45.0 + profile.w(group, "fervor") / 10.0, 0.0, 1.0)


## -1 to 1: the share of a player's cards these Grounds help, minus the share they hinder. My
## own deck is known to me; the opponent is judged on the cards they have shown (in play, discard,
## removed), which is all a fair player has to go on.
static func _grounds_fit(p: PlayerState, def: CardDef, own: bool) -> float:
	var pool: Array[CardInstance] = []
	pool.append_array(p.in_play)
	pool.append_array(p.discard)
	pool.append_array(p.removed)
	if own:
		pool.append_array(p.hand)
		pool.append_array(p.life_deck)
	if pool.is_empty():
		return 0.0
	var helped: float = 0.0
	for c in pool:
		helped += _grounds_card_fit(c.def, def)
	return clampf(helped / float(pool.size()) * 4.0, -1.0, 1.0)


## How one card fares under the Grounds: above zero helped, below zero hindered.
static func _grounds_card_fit(card: CardDef, def: CardDef) -> float:
	var fit: float = 0.0
	for raw in def.forbid:
		var what: String = str((raw as Dictionary).get("what", ""))
		if what == "non_combats" and (card.type == CardDef.Type.NON_COMBAT or card.type == CardDef.Type.DRILL):
			fit -= 1.0
		elif what == "drills" and card.type == CardDef.Type.DRILL:
			fit -= 1.0
		elif what == "seals" and card.type == CardDef.Type.SEAL:
			fit -= 1.0
		elif what == "combat_cards" and card.type == CardDef.Type.COMBAT:
			fit -= 1.0
	if bool(def.raw.get("double_costs", false)) and card.is_attack() and card.attack_kind() == "art":
		fit -= 0.7
	# Grounds that tax one kind of attack hurt exactly the decks built on that kind.
	if card.is_attack():
		fit -= 0.35 * float(int(def.raw.get("%s_cost_delta" % card.attack_kind(), 0)))
	for raw in def.modifiers:
		var m: Dictionary = raw
		var kind: String = str(m.get("kind", "any"))
		if card.is_attack() and (kind == "any" or kind == card.attack_kind()):
			fit += 0.25 * float(int(m.get("stages", 0))) + 0.5 * float(int(m.get("life", 0)))
	for raw in def.effects:
		var e: Dictionary = raw
		if str(e.get("op", "")) == "search" and CardDef.TYPE_NAMES.get(str(e.get("card_type", "")), -1) == card.type:
			var school: String = str(e.get("school", "*"))
			if school == "*" or school == card.school:
				fit += 1.0
	return fit


## 0 to 1, how far along the Ascension win this player is. Squared so the last steps count most.
static func ascension_progress(engine: DuelEngine, p: PlayerState) -> float:
	if p.no_ascension_win:
		return 0.0
	var needed: int = maxi(1, engine.fervor_needed(p))
	var lowest: int = p.duelist.stack.lowest_aspect()
	var done: float = float(p.duelist.aspect - lowest) + clampf(float(p.fervor) / float(needed), 0.0, 1.0)
	# The Most Powerful Personality win lands on the Aspect itself, so a taller ladder than the
	# rival's is a shorter road: the target is the first Aspect above theirs, with no extra meter
	# to fill. Otherwise it is the top Aspect plus one more full meter.
	var mppv: int = engine.mppv_aspect(p)
	var target: float = float(mppv - lowest) if mppv > 0 else float(p.highest_aspect - lowest) + 1.0
	var part: float = clampf(done / maxf(1.0, target), 0.0, 1.0)
	return part * part


## 0 to 1, how far the Fervor meter is toward the next aspect. 0 at the top aspect. Unlike
## `ascension_progress` this still counts for a deck that cannot win by Ascension and climbs for the
## better aspect power.
static func climb_progress(engine: DuelEngine, p: PlayerState) -> float:
	if p.duelist.aspect >= p.highest_aspect:
		return 0.0
	return clampf(float(p.fervor) / float(maxi(1, engine.fervor_needed(p))), 0.0, 1.0)


## What a Seal-guarding Drill in play is worth, 0 when there is none. A Drill that guards Seals
## shuts off capture entirely, so it is worth more the more Seals stand behind it, and it is worth
## a little before the first one because it has to be down first. Linear, not squared, so the guard
## is already worth landing early.
static func seal_guard_value(p: PlayerState) -> float:
	if not seals_guarded(p):
		return 0.0
	return 0.25 + float(p.seals().size()) / float(DuelEngine.SEALS_PER_SET)


## Whether a Drill this player controls stops the opponent capturing their Seals.
static func seals_guarded(p: PlayerState) -> bool:
	for d in p.drills():
		if bool(d.def.raw.get("protect_seals", false)):
			return true
	return false


## 0 to 1, how close this player is to a full Seal set. Half linear and half squared: the last
## Seals count most, but the first one still has to be worth putting down.
static func seal_progress(p: PlayerState) -> float:
	if p.seal_victory_pending:
		return 1.5
	var best: int = 0
	var counted: Dictionary = {}
	for t in p.seals():
		var set_name: String = t.def.seal_set
		counted[set_name] = int(counted.get(set_name, 0)) + 1
		best = maxi(best, int(counted[set_name]))
	var part: float = float(best) / float(DuelEngine.SEALS_PER_SET)
	return 0.5 * part + 0.5 * part * part
