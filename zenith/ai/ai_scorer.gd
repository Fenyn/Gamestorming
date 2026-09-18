class_name AiScorer
extends RefCounted
## Scores the options of the pending prompt without simulating anything. It is the easy AI on
## its own, the move ordering for AiSearch, and the policy both seats follow inside a playout.
## It reads card data (attack numbers, defense specs, effect ops), never card ids, so new cards
## and decks are scored without new code. Only call it on an engine the seat may hold.

## Options that mean "do nothing here". AiSearch always keeps one in its shortlist.
const QUIET: Array[StringName] = [&"pass", &"no_defense", &"done", &"skip", &"decline", &"no_endure", &"no_critical", &"no_recover", &"pick_none", &"reserve_done", &"discard_all", &"deal_damage"]


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
			return _attack_score(profile, me, foe, o, c, forecasts)
		&"use":
			if c == null:
				return 0.2
			return effects_value(c.def.effects, profile, ["use", "secondary", "relic_use"]) + _aspect_jump_value(c, me, profile) - profile.w("play", "use_cost")
		&"relic":
			return 1.0
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
			return 0.5 + hold_value(c, profile)
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
			return float(engine.strike_table.band(c.might())) + (profile.w("play", "control_ally") if c != me.duelist else 0.0)
		&"target":
			# Send damage at an Ally rather than the Duelist when one can take it.
			return 1.0 if c != null and c != me.duelist else 0.0
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
			return _choice_sign(prompt, seat) * hold_value(c, profile)
		&"pick_in_play":
			var mine: bool = c != null and c.controller == seat
			return (-1.0 if mine else 1.0) * (1.0 + hold_value(c, profile))
		&"pick_option":
			return _pick_option_score(profile, o, c)
	# Every "do nothing" option, and anything this file has not met yet.
	return 0.0


static func _attack_score(profile: AiProfile, me: PlayerState, foe: PlayerState, o: Command, c: CardInstance, forecasts: Dictionary) -> float:
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
		if o.type == &"power":
			var effects: Array = c.power().get("effects", [])
			v += effects_value(effects, profile, ["secondary", "if_successful", "use"])
		else:
			v += effects_value(c.def.effects, profile, ["secondary", "if_successful", "use"])
	return v + 0.1


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


static func _declare_score(profile: AiProfile, me: PlayerState) -> float:
	var attackers: int = 0
	for c in me.hand:
		if c.def.is_attack():
			attackers += 1
	if me.in_control().power().has("attack"):
		attackers += 1
	for al in me.allies():
		if al.power().has("attack"):
			attackers += 1
	return attackers * 1.0 + profile.w("play", "declare_bias")


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


static func _pick_option_score(profile: AiProfile, o: Command, c: CardInstance) -> float:
	if c != null:
		# A search, a look at the top cards, a Seal to capture: take the best card on offer.
		return 1.0 + hold_value(c, profile)
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
		CardDef.Type.ALLY:
			v += profile.w("own", "ally")
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
static func effects_value(effects: Array, profile: AiProfile, triggers: Array) -> float:
	var total: float = 0.0
	for raw in effects:
		if not (raw is Dictionary):
			continue
		var e: Dictionary = raw
		var trigger: String = str(e.get("trigger", "secondary"))
		if not triggers.is_empty() and not triggers.has(trigger):
			continue
		var v: float = _effect_value(e, profile)
		if e.has("then") and e["then"] is Array:
			var chained: Array = e["then"]
			for t in chained:
				if t is Dictionary:
					v += _effect_value(t, profile)
		if trigger == "if_successful":
			v *= profile.w("effect", "if_successful")
		elif trigger == "if_stopped":
			v *= profile.w("effect", "if_stopped")
		if e.has("when"):
			v *= profile.w("effect", "conditional")
		total += v
	return total


static func _effect_value(e: Dictionary, profile: AiProfile) -> float:
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
			return -side * (5.0 - amount) * profile.w("effect", "energy")
	return profile.w("effect", "other")
