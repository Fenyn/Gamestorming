class_name AiScorer
extends RefCounted
## Scores the options of the pending prompt without simulating anything. It is the easy AI on
## its own, the move ordering for AiSearch, and the policy both seats follow inside a playout.
## It reads card data (attack numbers, defense specs, effect ops), never card ids, so new cards
## and decks are scored without new code. Only call it on an engine the seat may hold.

## Options that mean "do nothing here". AiSearch always keeps one in its shortlist.
const QUIET: Array[StringName] = [&"pass", &"no_defense", &"done", &"skip", &"decline", &"no_endure", &"no_critical", &"no_recover", &"pick_none", &"reserve_done", &"discard_all", &"deal_damage"]

## How many links of a tutor chain to follow. Three covers "fetch the card that fetches the card
## that does the thing", which is as long as the shipped decks get.
const TUTOR_DEPTH: int = 3

## Legacy compatibility for callers that cleared the old cache. Evaluation never reads or writes
## this shared dictionary: every contextual valuation owns its recursion context.
static var _value_cache: Dictionary = {}


## One score per option of the pending prompt, in option order. Higher is better; 0 is "do
## nothing". `seat` picks which prompt when both players hold one; -1 takes the first.
static func scores(engine: DuelEngine, profile: AiProfile, seat: int = -1) -> Array[float]:
	var out: Array[float] = []
	var prompt: Prompt = engine.prompt_of(seat) if seat >= 0 else engine.prompt
	if prompt == null:
		return out
	seat = prompt.player
	var forecasts: Dictionary = engine.attack_forecasts(seat) if prompt.kind == &"attack_action" else {}
	for o in prompt.options:
		out.append(_score(engine, profile, prompt, o, forecasts))
	return out


## The best option by score. `rng` and the profile's noise make a weaker player misjudge.
static func pick(engine: DuelEngine, profile: AiProfile, rng: RandomNumberGenerator = null, seat: int = -1) -> Command:
	var prompt: Prompt = engine.prompt_of(seat) if seat >= 0 else engine.prompt
	var list: Array[float] = scores(engine, profile, seat)
	var noise: float = profile.w("think", "noise")
	var best: int = 0
	var best_score: float = -INF
	for i in range(list.size()):
		var s: float = list[i]
		if rng != null and noise > 0.0:
			s += rng.randf_range(-noise, noise)
		if s > best_score:
			best_score = s
			best = i
	return prompt.options[best]


static func _score(engine: DuelEngine, profile: AiProfile, prompt: Prompt, o: Command, forecasts: Dictionary) -> float:
	var seat: int = prompt.player
	var me: PlayerState = engine.player(seat)
	var foe: PlayerState = engine.player(1 - seat)
	var c: CardInstance = engine.card(o.card)
	match o.type:
		&"attack", &"power", &"final_strike", &"copied_attack":
			return _attack_score(engine, profile, me, foe, o, c, forecasts)
		&"use":
			if c == null:
				return 0.2
			var handover: float = AiEvaluator.handover_progress(engine, me)
			return effects_value(c.def.effects, profile, ["use", "secondary", "relic_use"], handover) \
				+ _aspect_jump_value(c, me, profile) + _bond_use_value(engine, me, c.def, profile) \
				+ _tutor_value(engine, me, c.def, profile, TUTOR_DEPTH, c) \
				- profile.w("play", "use_cost")
		&"relic":
			# The Relic fires once a game, so it is worth what it actually fetches rather than a
			# flat "do something". With a tutor decay set, that includes the chain it opens.
			if c == null:
				return 1.0
			return 1.0 + effects_value(c.def.effects, profile, ["relic_use"]) \
				+ _tutor_value(engine, me, c.def, profile, TUTOR_DEPTH, c)
		&"defend", &"power_defend":
			return _defense_score(engine, profile, me, o, c)
		&"declare":
			return _declare_score(profile, me)
		&"skip":
			return 1.0
		&"place":
			if c != null and c.def.type == CardDef.Type.GROUNDS:
				return _grounds_score(engine, profile, me, c)
			return 1.0 + hold_value(c, profile)
		&"shuffle_back":
			return -0.5
		&"keep":
			return 0.5 + card_value(engine, me, c, profile, TUTOR_DEPTH)
		&"reserve_in":
			# Cards already swapped out are in the Reserve but not on offer, which counts the swaps.
			var swaps: int = me.reserve.size() - prompt.card_options().size()
			if c == null or swaps >= int(profile.w("reserve", "max_swaps")):
				return -1.0
			return AiReserve.score(engine, seat, c, profile)
		&"counter":
			return 1.5
		&"control":
			# Hand Combat to whoever hits hardest on the Strike Table.
			if c == null:
				return 0.0
			return float(engine.strike_table.band(c.might())) + usable_power_value(engine, me, c, profile) \
				+ (profile.w("play", "control_ally") if c != me.duelist else 0.0)
		&"target":
			return _redirect_score(engine, profile, me, c)
		&"endure":
			return 1.0
		&"capture":
			return profile.w("effect", "capture_seal")
		&"discard_ally":
			return profile.w("foe", "ally")
		&"lower_fervor":
			return profile.w("effect", "fervor") * (1.0 if foe.fervor > 0 else 0.0)
		&"recover":
			return 1.0
		&"pay":
			return _pay_score(profile, o)
		&"discard_choice":
			var owner: PlayerState = engine.player(c.controller) if c != null else me
			# Revealing an opposing discard option does not reveal that player's tutor pool.
			var value: float = card_value(engine, owner, c, profile, TUTOR_DEPTH) if owner.index == seat else hold_value(c, profile)
			return _choice_sign(prompt, seat) * value
		&"pick_in_play":
			var mine: bool = c != null and c.controller == seat
			return (-1.0 if mine else 1.0) * (1.0 + hold_value(c, profile))
		&"name_card":
			return _name_card_score(profile, foe, o)
		&"pick_option":
			if str(prompt.context.get("purpose", "")) == "look_place":
				return _look_place_score(engine, me, profile, prompt, o)
			return _pick_option_score(engine, me, profile, o, c)
	# Every "do nothing" option, and anything this file has not met yet.
	return 0.0


static func _attack_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, foe: PlayerState, o: Command, c: CardInstance, forecasts: Dictionary) -> float:
	var f: Dictionary = forecasts.get(o.card, {})
	if o.type == &"attack" and o.value != null and str(o.value) == "empower" and f.has("empowered"):
		var emp: Dictionary = f["empowered"]
		f = {"stages": emp["stages"], "life": emp["life"], "cost_stages": f.get("cost_stages", 0)}
	var life: int = int(f.get("life", 0))
	var stages: int = int(f.get("stages", 0))
	if life >= foe.life_deck.size() and life > 0:
		return AiEvaluator.WIN
	var v: float = life * profile.w("play", "damage_life") + stages * profile.w("play", "damage_stage")
	v -= int(f.get("cost_stages", 0)) * profile.w("play", "attack_cost")
	if o.type == &"final_strike":
		# The card is thrown away and the rest of the Combat is spent passing.
		return v - profile.w("play", "final_strike_penalty") - me.hand.size() * 0.5
	if c != null:
		var handover: float = AiEvaluator.handover_progress(engine, me)
		if o.type == &"power":
			var effects: Array = c.power().get("effects", [])
			v += effects_value(effects, profile, ["secondary", "if_successful", "use"], handover)
		else:
			v += effects_value(c.def.effects, profile, ["secondary", "if_successful", "use"], handover)
		v += _tutor_value(engine, me, c.def, profile, TUTOR_DEPTH, c)
	return v + 0.1


## Damage lands whole on one personality, and stage damage past that personality's 0 turns into life
## cards one for one. So the one to pick is whoever can soak the most, not simply an Ally: an
## eight-stage hit put on an Ally standing at three is five stages that become five wounds, and five
## wounds is exactly where critical damage starts taking Allies off the table. Once the damage is
## soaked either way, it goes on whichever personality the profile values least.
static func _redirect_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, c: CardInstance) -> float:
	if c == null:
		return 0.0
	var b: Dictionary = engine.damage_breakdown(engine.state.attack)
	var stages: int = int(b.get("stages", 0))
	var overflow: int = maxi(0, stages - c.energy)
	var v: float = -float(overflow) * profile.w("play", "damage_life")
	var soaked: float = float(mini(stages, c.energy))
	if c == me.duelist:
		v -= soaked * profile.w("own", "energy")
	else:
		v -= soaked * profile.w("own", "ally_energy")
	return v


static func _defense_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, o: Command, c: CardInstance) -> float:
	var b: Dictionary = engine.damage_breakdown(engine.state.attack)
	var life: int = int(b.get("life", 0))
	var stages: int = int(b.get("stages", 0))
	var threat: float = life * profile.w("play", "damage_life") + stages * profile.w("play", "damage_stage")
	if life >= me.life_deck.size() and life > 0:
		threat = AiEvaluator.WIN
	var attack_effects: Array = engine.state.attack.get("effects", [])
	threat += effects_value(attack_effects, profile, ["if_successful"])
	var cost: float = profile.w("play", "defend_in_play")
	if o.type == &"defend" and c != null and c.zone == &"hand":
		cost = profile.w("play", "defend_card")
	return threat - cost


## Whether to open Combat. Attacks are the obvious reason, but a hand can also be carrying cards
## that only work once Combat is open, and a deck that never attacks still has to declare to spend
## them. `declare_use` is off by default, so only a profile that asks for it weighs what it carries.
static func _declare_score(profile: AiProfile, me: PlayerState) -> float:
	var attackers: int = 0
	var carried: float = 0.0
	for c in me.hand:
		if c.def.is_attack():
			attackers += 1
		elif not c.def.effects_for("use").is_empty():
			carried += effects_value(c.def.effects, profile, ["use"])
	if me.in_control().power().has("attack"):
		attackers += 1
	for al in me.allies():
		if al.power().has("attack"):
			attackers += 1
	return attackers * 1.0 + carried * profile.w("play", "declare_use") + profile.w("play", "declare_bias")


## Placing Grounds: what the new Grounds are worth to me against the ones they replace (or none),
## less the Combat given up, because a player who places Grounds cannot declare Combat that turn.
static func _grounds_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, c: CardInstance) -> float:
	var current: CardDef = engine.state.grounds.def if engine.state.grounds != null else null
	var gain: float = AiEvaluator.grounds_value(engine, me.index, c.def, profile) - AiEvaluator.grounds_value(engine, me.index, current, profile)
	return gain - _declare_score(profile, me) * profile.w("play", "grounds_skip")


## A card that moves the duelist to the aspect matching its Fervor: worth the aspects gained, and a
## loss when Fervor is lower than the aspect already held.
static func _aspect_jump_value(c: CardInstance, me: PlayerState, profile: AiProfile) -> float:
	for raw in c.def.effects:
		if raw is Dictionary and str((raw as Dictionary).get("op", "")) == "set_aspect" and str((raw as Dictionary).get("aspect", "")) == "fervor" and str((raw as Dictionary).get("who", "self")) == "self":
			var target: int = clampi(me.fervor, me.duelist.def.lowest_aspect(), me.highest_aspect)
			return float(target - me.duelist.aspect) * profile.w("own", "aspect")
	return 0.0


## Paying Energy into a card: worth it a few stages deep, not to the point of emptying the gauge.
static func _pay_score(profile: AiProfile, o: Command) -> float:
	var amount: int = int(o.value) if o.value != null else 0
	if amount > 4:
		return -float(amount)
	return amount * (profile.w("play", "damage_life") - profile.w("play", "attack_cost"))


## +1 when the chooser is discarding the other seat's cards, -1 when its own.
static func _choice_sign(prompt: Prompt, seat: int) -> float:
	return 1.0 if int(prompt.context.get("target", seat)) != seat else -1.0


## What having this card right now is worth, including everything it can go and get. This is the one
## number the tutor chain is built on: nothing here knows what a card is called, only what it is
## worth and what it can reach, so a deck's tutor priorities fall out of the weights it already has.
static func card_value(engine: DuelEngine, me: PlayerState, c: CardInstance, profile: AiProfile, depth: int) -> float:
	if c == null or c.def == null:
		return 0.0
	if depth <= 0 or profile.w("play", "tutor_decay") <= 0.0:
		return hold_value(c, profile) + _combo_value(engine, me, c, profile)
	return _context_card_value(engine, me, c, profile, maxi(0, depth), {}, {})


static func _context_card_value(engine: DuelEngine, me: PlayerState, c: CardInstance, profile: AiProfile, depth: int, cache: Dictionary, path: Dictionary) -> float:
	if c == null or c.def == null or path.has(c.def.id):
		return 0.0
	var ancestors: Array = path.keys()
	ancestors.sort()
	var key: String = "%d|%d|%s" % [c.uid, depth, str(ancestors)]
	if cache.has(key):
		return float(cache[key])
	var v: float = hold_value(c, profile) + _combo_value(engine, me, c, profile)
	if depth > 0:
		var next_path: Dictionary = path.duplicate()
		next_path[c.def.id] = true
		v += _reachable_value(engine, me, c, profile, depth, cache, next_path)
	cache[key] = v
	return v


## A card that searches is worth what the best card it can reach is worth, stepped down once per
## link by `play.tutor_decay`, so a three-card chain still reads above an ordinary play but never
## above simply holding the card at the end of it. Zero decay turns the whole thing off, which is
## the default: a deck opts in.
static func _tutor_value(engine: DuelEngine, me: PlayerState, def: CardDef, profile: AiProfile, depth: int, source: CardInstance = null) -> float:
	if depth <= 0 or profile.w("play", "tutor_decay") <= 0.0:
		return 0.0
	if source == null:
		for pool in [me.hand, me.in_play, me.life_deck, me.discard, me.reserve]:
			for c: CardInstance in pool:
				if c.def == def:
					source = c
					break
			if source != null:
				break
	if source == null or depth <= 0:
		return 0.0
	return _reachable_value(engine, me, source, profile, depth, {}, {source.def.id: true})


## An optimistic, bounded hint, not a substitute for executing a chain in search. Conditions and
## payment gates use the engine; later placements and contingent hits are explicitly discounted.
static func _reachable_value(engine: DuelEngine, me: PlayerState, source: CardInstance, profile: AiProfile, depth: int, cache: Dictionary, path: Dictionary) -> float:
	var decay: float = profile.w("play", "tutor_decay")
	if decay <= 0.0 or not engine._can_play(me, source.def):
		return 0.0
	var best: float = 0.0
	for route in _available_searches(engine, me, source, profile):
		var e: Dictionary = route["effect"]
		var reliability: float = float(route["factor"])
		var seen: Dictionary = {}
		for cand in engine.search_candidates(me, e):
			if path.has(cand.def.id) or seen.has(cand.def.id):
				continue
			seen[cand.def.id] = true
			var value: float = _context_card_value(engine, me, cand, profile, depth - 1, cache, path)
			# A card returned to the deck is recovery, not an immediately held combo piece.
			var destination: String = str(e.get("to", "hand"))
			var access: float = 0.35 if destination == "deck" or destination == "top" or destination == "bottom" else 1.0
			best = maxf(best, value * decay * reliability * access)
	return best


static func _available_searches(engine: DuelEngine, me: PlayerState, source: CardInstance, profile: AiProfile) -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	var out: Array[Dictionary] = []
	var attack: Dictionary = source.def.attack
	var payment: float = 1.0
	if source.def.is_attack() and not engine._can_pay(me.in_control(), me, attack):
		payment = 0.25 # retain future value, but do not price it as a ready chain
	for e in source.def.effects:
		pending.append({"effect": e, "factor": payment})
	if source.def.is_personality():
		var power: Dictionary = source.power()
		var readiness: float = 1.0 if source == me.duelist or me.allies().has(source) else 0.6
		if readiness == 1.0 and (not engine._power_available(me, source) or engine._forbidden(me, "powers")):
			readiness = 0.0
		if readiness == 1.0 and source != me.in_control() and not bool(power.get("no_control_needed", false)) and not engine.may_ally_control(me):
			readiness = 0.25
		if power.has("attack") and not engine._can_pay(source, me, power["attack"]):
			readiness *= 0.25
		for e in power.get("effects", []):
			pending.append({"effect": e, "factor": readiness})
	while not pending.is_empty():
		var route: Dictionary = pending.pop_back()
		var e: Dictionary = route["effect"]
		var factor: float = float(route["factor"])
		if factor <= 0.0:
			continue
		if not engine._cond(e.get("when", {}), me.index, {}):
			for branch in e.get("else_effects", []):
				pending.append({"effect": branch, "factor": factor})
			continue
		var trigger: String = str(e.get("trigger", "secondary"))
		if trigger == "if_successful":
			factor *= profile.w("effect", "if_successful")
		elif trigger == "if_stopped":
			factor *= profile.w("effect", "if_stopped")
		elif trigger == "on_wound" or trigger == "on_discard":
			factor *= 0.25
		var op: String = str(e.get("op", ""))
		var amount: Variant = e.get("amount", 1)
		if amount is int or amount is float:
			var after_play: int = me.hand.size() - (1 if source.zone == &"hand" else 0)
			if op == "discard_hand" and str(e.get("who", "self")) == "self" and int(amount) > after_play:
				continue
			if op == "remove_discard" and str(e.get("who", "self")) == "self" and int(amount) > me.discard.size():
				continue
			if op == "discard_life" and str(e.get("who", "self")) == "self" and int(amount) >= me.life_deck.size():
				continue
			if op == "energy" and str(e.get("who", "self")) == "self" and int(amount) < 0 and maxi(0, -int(amount) - me.in_control().energy) >= me.life_deck.size():
				continue
		if op == "search":
			out.append({"effect": e, "factor": factor})
		for child in e.get("then", []):
			pending.append({"effect": child, "factor": factor})
	return out


## Every `search` a card can perform, wherever it sits on the card: its own effects, the `then`
## chains hanging off them, and the effects of a personality's power.
static func _searching_effects(def: CardDef, aspect: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pending: Array = def.effects.duplicate()
	var power: Dictionary = def.aspect_data(def.lowest_aspect() if aspect < 0 else aspect).get("power", {}) if not def.aspects.is_empty() else {}
	pending.append_array(power.get("effects", []))
	while not pending.is_empty():
		var e: Variant = pending.pop_back()
		if not (e is Dictionary):
			continue
		var d: Dictionary = e
		if str(d.get("op", "")) == "search":
			out.append(d)
		if d.has("then") and d["then"] is Array:
			pending.append_array(d["then"])
		if d.has("else_effects") and d["else_effects"] is Array:
			pending.append_array(d["else_effects"])
	return out


## What a card that fuses two Allies into one is worth right now. A deck runs the partners for the
## fused card, which stands a band or more above either of them, so the fusion is worth far more
## than the attack it is used in place of. Zero unless every named partner is on the table, which
## makes the same number say "hold this until the pieces are here".
static func _bond_value(engine: DuelEngine, me: PlayerState, def: CardDef, profile: AiProfile) -> float:
	for e in def.effects:
		if str(e.get("op", "")) != "bond":
			continue
		var bond: CardDef = engine.library.get_def(str(e.get("card", "")))
		if bond == null:
			return 0.0
		return _bond_payoff(engine, me, bond, "", profile)
	return 0.0


## Whether using this card now is the fusion or a waste of it. A Bonding card played without every
## partner on the table resolves into nothing and is gone, and there is no board where that is the
## right play, so it is ruled out rather than merely discouraged. `_bond_value` is the other
## question, what the card is worth to have, which stays positive while the pieces are still coming.
static func _bond_use_value(engine: DuelEngine, me: PlayerState, def: CardDef, profile: AiProfile) -> float:
	var bonds: bool = false
	for e in def.effects:
		if str(e.get("op", "")) == "bond":
			bonds = true
			break
	if not bonds:
		return 0.0
	var ready: float = _bond_value(engine, me, def, profile)
	return ready if ready > 0.0 else -AiEvaluator.WIN


## The bands a fused card gains over the partners it eats, once every partner is on the table.
## `also` counts one partner that is not in play yet but is about to be, which is how a search that
## fetches the last piece of a fusion is priced: it is worth the fusion, not one more Ally.
static func _bond_payoff(engine: DuelEngine, me: PlayerState, bond: CardDef, also: String, profile: AiProfile) -> float:
	var names: Array = bond.raw.get("bond_of", [])
	if names.is_empty():
		return 0.0
	var best: int = 0
	var found: int = 0
	for n in names:
		if str(n) == also:
			found += 1
			continue
		for al in me.allies():
			if al.def.character == str(n):
				found += 1
				best = maxi(best, engine.strike_table.band(al.might()))
				break
	if found < names.size():
		return 0.0
	# The fused card enters at full Energy, so it is judged at the top of its own ladder.
	var ladder: Array = bond.aspect_data(bond.lowest_aspect()).get("might", [])
	if ladder.is_empty():
		return 0.0
	var gain: int = engine.strike_table.band(int(ladder[ladder.size() - 1])) - best
	return maxf(0.0, float(gain)) * profile.w("play", "bond_band") + profile.w("effect", "attach")


## How far along a fusion is and what finishing it pays. Unlike `_bond_value` this does not wait for
## every piece: a deck has to value the second-to-last piece, and the card that fetches it, or it
## will never go and get them. The payoff is scaled by the share of the combo already on the table,
## counting the card being valued as found, so the pull grows as the pieces land.
static func _bond_prospect(engine: DuelEngine, me: PlayerState, bond: CardDef, profile: AiProfile) -> float:
	var names: Array = bond.raw.get("bond_of", [])
	if names.is_empty() or profile.w("play", "bond_band") <= 0.0:
		return 0.0
	var ladder: Array = bond.aspect_data(bond.lowest_aspect()).get("might", [])
	if ladder.is_empty():
		return 0.0
	var present: int = 0
	var best: int = 0
	var access: float = 1.0
	for n in names:
		var found: bool = false
		for al in me.allies():
			if al.def.character == str(n):
				present += 1
				found = true
				best = maxi(best, engine.strike_table.band(al.might()))
				break
		if found:
			continue
		for pool in [me.hand, me.life_deck, me.reserve]:
			for candidate: CardInstance in pool:
				found = found or candidate.def.character == str(n)
		if not found:
			for candidate in me.discard:
				found = found or candidate.def.character == str(n)
			if not found:
				return 0.0 # no known remaining instance can supply this prerequisite
			access *= 0.35 # recovery is another required action, not a ready partner
	var gain: int = engine.strike_table.band(int(ladder[ladder.size() - 1])) - best
	# The pieces are the partners plus the card that fuses them, and this is one of them.
	var share: float = float(present + 1) / float(names.size() + 1)
	return maxf(0.0, float(gain)) * profile.w("play", "bond_band") * share * access


## What a card is worth as a piece of a fusion: the Bonding card itself, or an Ally it names.
static func _combo_value(engine: DuelEngine, me: PlayerState, c: CardInstance, profile: AiProfile) -> float:
	if profile.w("play", "bond_band") <= 0.0:
		return 0.0
	for e in c.def.effects:
		if str(e.get("op", "")) == "bond":
			var own_bond: CardDef = engine.library.get_def(str(e.get("card", "")))
			return _bond_prospect(engine, me, own_bond, profile) if own_bond != null else 0.0
	if c.def.type != CardDef.Type.PERSONALITY:
		return 0.0
	# A second copy of an already present partner cannot advance this assembly.
	for ally in me.allies():
		if ally != c and ally.def.character == c.def.character:
			return 0.0
	for pool in [me.life_deck, me.hand, me.discard, me.reserve, me.in_play]:
		for held in pool:
			for e in held.def.effects:
				if str(e.get("op", "")) != "bond":
					continue
				var bond: CardDef = engine.library.get_def(str(e.get("card", "")))
				if bond != null and (bond.raw.get("bond_of", []) as Array).has(c.def.character):
					return _bond_prospect(engine, me, bond, profile)
	return 0.0


## Remaining usable power, with rule-engine affordability, restrictions, control eligibility and
## damage math. No simulated commands or authoritative hidden information are introduced here.
static func usable_power_value(engine: DuelEngine, me: PlayerState, c: CardInstance, profile: AiProfile) -> float:
	if engine.state.step != GameState.Step.COMBAT or me.final_strike_used:
		return 0.0
	if c == null or not engine._power_available(me, c) or engine._forbidden(me, "powers"):
		return 0.0
	var power: Dictionary = c.power()
	if not engine._cond(power.get("when", {}), me.index, {}):
		return 0.0
	var controls: bool = c == me.in_control() or bool(power.get("no_control_needed", false))
	if not controls and c != me.duelist and not engine.may_ally_control(me):
		return 0.0
	var effects: Array[Dictionary] = []
	effects.assign(power.get("effects", []))
	var value: float = 0.0
	if power.has("attack"):
		var attack: Dictionary = power["attack"]
		if not engine._attack_allowed(me, null, str(attack.get("kind", "strike"))) or not engine._can_pay(c, me, attack):
			return 0.0
		var built: Dictionary = engine._build_attack(me.index, c, attack, effects, true, false, false, c, me.attack_count_combat == 0)
		var damage: Dictionary = engine.damage_breakdown(built)
		value += float(damage.get("life", 0)) * profile.w("play", "damage_life")
		value += float(damage.get("stages", 0)) * profile.w("play", "damage_stage")
		value -= float(engine._cost_stages(attack, me)) * profile.w("play", "attack_cost")
		if int(damage.get("life", 0)) >= engine.player(1 - me.index).life_deck.size() and int(damage.get("life", 0)) > 0:
			value += AiEvaluator.WIN * 0.1
	elif power.has("defense"):
		# Defensive utility is reusable material, not an attack action.
		if not engine._can_pay(c, me, power["defense"]):
			return 0.0
		value += profile.w("play", "defend_card")
	elif engine._forbidden(me, "non_attack_actions"):
		return 0.0
	var active_effects: Array = []
	for e in effects:
		if engine._cond(e.get("when", {}), me.index, {}):
			active_effects.append(e)
	value += effects_value(active_effects, profile, ["secondary", "use", "if_successful", "if_stopped"], AiEvaluator.handover_progress(engine, me))
	var remaining: int = maxi(1, int(power.get("uses", 1)))
	if c.power_used_combat == engine.state.combat_count:
		remaining = maxi(1, remaining - c.power_uses_combat)
	return maxf(0.0, value) * (1.0 + 0.35 * (remaining - 1)) * (1.0 if controls else 0.8)


## Normalized progress of the best assembly, not another copy of its payoff valuation. A completed
## fusion retains progress 1 after consuming its partners; its usable power is valued separately.
static func combo_progress(engine: DuelEngine, me: PlayerState, profile: AiProfile, public_only: bool = false) -> float:
	if profile.w("play", "bond_band") <= 0.0:
		return 0.0
	for ally in me.allies():
		if not (ally.def.raw.get("bond_of", []) as Array).is_empty():
			return 1.0
	var pool: Array[CardInstance] = me.in_play.duplicate()
	if not public_only:
		pool.append_array(me.hand)
		pool.append_array(me.life_deck)
		pool.append_array(me.discard)
	var plans: Dictionary = {}
	for c in pool:
		for e in c.def.effects:
			if str(e.get("op", "")) != "bond":
				continue
			var bond: CardDef = engine.library.get_def(str(e.get("card", "")))
			if bond == null:
				continue
			var names: Array = bond.raw.get("bond_of", [])
			var present: int = 0
			var accessible: int = 0
			for name in names:
				var on_board: bool = false
				var in_hand: bool = false
				for partner in me.allies():
					on_board = on_board or partner.def.character == str(name)
				if not public_only and not on_board:
					for partner in me.hand:
						in_hand = in_hand or partner.def.character == str(name)
				present += 1 if on_board else 0
				accessible += 1 if in_hand else 0
			if present + accessible == 0:
				continue
			var ready: bool = me.in_play.has(c) or me.hand.has(c)
			# A discarded enabler has no assumed route back. A deck copy retains discounted
			# future access, but cannot count as an immediately executable finish.
			var access: float = 1.0 if ready else (0.25 if me.life_deck.has(c) else 0.0)
			var progress: float = float(present) + 0.4 * accessible + (1.0 if ready else 0.0)
			progress /= maxf(1.0, float(names.size() + 1))
			var value: float = clampf(progress * access, 0.0, 1.0)
			plans[bond.id] = maxf(float(plans.get(bond.id, 0.0)), value)
	var best: float = 0.0
	for value in plans.values():
		best = maxf(best, float(value))
	return best


## Naming a card: pick whatever costs the other side most, which is one copy's worth times how many
## copies the deck this seat is holding says are in there. That deck is the dealt sample, so this is
## a guess the seat is entitled to make, not sight of the real list.
static func _name_card_score(profile: AiProfile, foe: PlayerState, o: Command) -> float:
	if o.value == null:
		return 0.0
	var title: String = str(o.value)
	var copies: int = 0
	var one: float = 0.0
	for c in foe.life_deck:
		if c.def.title == title:
			copies += 1
			one = maxf(one, hold_value(c, profile))
	return one * float(copies)


## "All on top or all on the bottom": keep what is worth drawing, bury what is not. The bar is the
## average card left in the deck, so a look that turned up nothing better than usual goes under.
static func _look_place_score(engine: DuelEngine, me: PlayerState, profile: AiProfile, prompt: Prompt, o: Command) -> float:
	var looked: Array = prompt.context.get("library", [])
	if looked.is_empty() or me.life_deck.is_empty():
		return 0.0
	var seen: float = 0.0
	for uid in looked:
		seen += hold_value(engine.card(int(uid)), profile)
	seen /= float(looked.size())
	var bar: float = 0.0
	for c in me.life_deck:
		bar += hold_value(c, profile)
	bar /= float(me.life_deck.size())
	return (seen - bar) if str(o.value) == "top" else (bar - seen)


static func _pick_option_score(engine: DuelEngine, me: PlayerState, profile: AiProfile, o: Command, c: CardInstance) -> float:
	if c != null:
		# A search, a look at the top cards, a Seal to capture: take the best card on offer, which
		# for a deck that runs tutor chains means the card that carries the chain furthest.
		return 1.0 + card_value(engine, me, c, profile, TUTOR_DEPTH)
	var word: String = str(o.value) if o.value != null else ""
	if word == "yes":
		return 0.5
	return 0.0


## What a card is worth keeping for, from its data alone.
static func hold_value(c: CardInstance, profile: AiProfile) -> float:
	if c == null or c.def == null:
		return 0.0
	var def: CardDef = c.def
	var v: float = 0.0
	if def.is_attack():
		var a: Dictionary = def.attack
		v += 1.5 + int(a.get("life", 0)) * profile.w("play", "damage_life") + int(a.get("stages", 0)) * profile.w("play", "damage_stage")
		if bool(a.get("focused", false)) or bool(a.get("unstoppable", false)):
			v += 1.0
	if def.is_defense():
		v += 2.0
	match def.type:
		CardDef.Type.PERSONALITY:
			v += profile.w("own", "ally")
			# Allies differ mostly in what their power does, and a deck that searches for one wants
			# the one that can swing, not whichever the list happens to offer first.
			var pw: Dictionary = c.power()
			if pw.has("attack"):
				var pa: Dictionary = pw["attack"]
				v += 1.5
				v += int(pa.get("life", pa.get("printed_life", 0))) * profile.w("play", "damage_life")
				v += int(pa.get("stages", pa.get("printed_stages", 0))) * profile.w("play", "damage_stage")
				if bool(pa.get("focused", false)) or bool(pa.get("unstoppable", false)):
					v += 1.0
			v += effects_value(pw.get("effects", []), profile, []) * 0.5
		CardDef.Type.DRILL:
			v += profile.w("own", "drill")
			if bool(def.raw.get("protect_seals", false)):
				# A Drill that guards Seals shuts off capture outright, so it is wanted before the
				# Seals are and, on the other side of the table, wanted gone.
				v += profile.w("own", "seal_guard") * 0.5
		CardDef.Type.NON_COMBAT:
			v += profile.w("own", "non_combat")
		CardDef.Type.SEAL:
			v += profile.w("own", "seal") / float(DuelEngine.SEALS_PER_SET)
		CardDef.Type.GROUNDS:
			v += 1.0
	v += effects_value(def.effects, profile, []) * 0.5
	return v


## Sum of what a list of effects is worth to the player who owns them. `triggers` filters by
## trigger when it is not empty. Effects aimed at the opponent count for what they take away.
## `handover` is AiEvaluator.handover_progress for the player who owns the effects: 0 normally, 1
## when an Ally is out and only waiting on the Duelist to be spent. It flips the sign of what this
## player's own Energy is worth, so a deck that fights through Allies reads a self-drain as a gain.
static func effects_value(effects: Array, profile: AiProfile, triggers: Array, handover: float = 0.0) -> float:
	var total: float = 0.0
	for raw in effects:
		if not (raw is Dictionary):
			continue
		var e: Dictionary = raw
		var trigger: String = str(e.get("trigger", "secondary"))
		if not triggers.is_empty() and not triggers.has(trigger):
			continue
		var v: float = _effect_value(e, profile, handover)
		if e.has("then") and e["then"] is Array:
			var chained: Array = e["then"]
			for t in chained:
				if t is Dictionary:
					v += _effect_value(t, profile, handover)
		if trigger == "if_successful":
			v *= profile.w("effect", "if_successful")
		elif trigger == "if_stopped":
			v *= profile.w("effect", "if_stopped")
		if e.has("when"):
			v *= profile.w("effect", "conditional")
		total += v
	return total


static func _effect_value(e: Dictionary, profile: AiProfile, handover: float = 0.0) -> float:
	var op: String = str(e.get("op", ""))
	var on_foe: bool = str(e.get("who", "self")) == "opponent"
	var side: float = -1.0 if on_foe else 1.0
	var amount: float = 1.0
	var raw_amount: Variant = e.get("amount", 1)
	if raw_amount is int or raw_amount is float:
		amount = float(raw_amount)
	if bool(e.get("all", false)):
		amount = 2.0
	match op:
		"energy":
			# A deck that fights through its Allies wants its own Energy spent rather than gained,
			# since the Allies only take over once the Duelist is down to 0 or 1. It says so with
			# `energy_self`, often below zero, the way a camping deck sets `fervor_self`. It only
			# applies as far as the handover is actually on the table: with no Ally out, spending
			# the Duelist's Energy just leaves it unable to attack.
			if not on_foe and handover > 0.0 and (profile.data["effect"] as Dictionary).has("energy_self"):
				return amount * lerpf(profile.w("effect", "energy"), profile.w("effect", "energy_self"), handover)
			return side * amount * profile.w("effect", "energy")
		"fervor":
			# A deck that wants to stay on its aspect sets `fervor_self`, often below zero.
			var effect_weights: Dictionary = profile.data["effect"]
			if not on_foe and effect_weights.has("fervor_self"):
				return amount * profile.w("effect", "fervor_self")
			return side * amount * profile.w("effect", "fervor")
		"draw", "draw_until", "draw_discard":
			return side * amount * profile.w("effect", "draw")
		"search", "look_at", "return_removed":
			return profile.w("effect", "search")
		"discard_in_play":
			return -side * amount * profile.w("effect", "discard_in_play")
		"discard_hand", "remove_hand":
			return -side * amount * profile.w("effect", "discard_hand")
		"reveal_hand":
			# Showing a hand hands information across the table and takes nothing, so it is a small
			# price the rest of the card has to pay for.
			return -side * profile.w("effect", "discard_hand") * 0.25
		"discard_life":
			return -side * amount * profile.w("effect", "discard_life")
		"recover", "shuffle_discard":
			return side * amount * profile.w("effect", "recover")
		"remove_discard":
			return -side * amount * profile.w("effect", "remove_discard")
		"forbid", "choose_forbid_type", "next_attack_tax", "force_declare":
			return profile.w("effect", "forbid")
		"float", "focus_attack":
			return profile.w("effect", "float")
		"stop_all", "choose_stop_all_kind":
			return profile.w("effect", "stop_all")
		"attach", "bond":
			return profile.w("effect", "attach")
		"capture_seal":
			return profile.w("effect", "capture_seal")
		"set_energy":
			if not on_foe and handover > 0.0 and (profile.data["effect"] as Dictionary).has("energy_self"):
				return (5.0 - amount) * -lerpf(profile.w("effect", "energy"), profile.w("effect", "energy_self"), handover)
			return -side * (5.0 - amount) * profile.w("effect", "energy")
	return profile.w("effect", "other")
