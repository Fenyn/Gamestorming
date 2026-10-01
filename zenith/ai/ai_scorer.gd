class_name AiScorer
extends RefCounted
## Scores the options of the pending prompt without simulating anything. It is the easy AI on
## its own, the move ordering for AiSearch, and the policy both seats follow inside a playout.
## It reads card data (attack numbers, defense specs, effect ops), never card ids, so new cards
## and decks are scored without new code. Only call it on an engine the seat may hold.

## Options that mean "do nothing here". AiSearch always keeps one in its shortlist.
const QUIET: Array[StringName] = [&"pass", &"no_defense", &"done", &"skip", &"decline", &"no_endure", &"no_critical", &"no_recover", &"pick_none", &"reserve_done", &"discard_all", &"deal_damage", &"order_confirm"]

## How many links of a tutor chain to follow. Three covers "fetch the card that fetches the card
## that does the thing", which is as long as the shipped decks get.
const TUTOR_DEPTH: int = 3

## How many attacks a standing modifier is expected to touch, by how long it lasts. A Combat is
## worth about one more attack after the one that set it; a game-long one about six.
## The lines a card resolves when it is used, in whichever window it was offered: the ordinary use,
## a Relic's, and the answer to the rival declaring Combat.
const USE_TRIGGERS: Array = ["use", "secondary", "relic_use", "opponent_declare"]

## The Strike Table result between duelists on the same Might band (`StrikeTable.base_damage`), the
## stand-in for a plain Strike's base when no matchup is at hand.
const EVEN_TABLE_STAGES: int = 1

## The share of a hidden hand card that can block an attack, for reading a rival's hand size as a
## chance of a block. About a third of a starter list defends.
const BLOCK_SHARE: float = 0.35

const MODIFIER_ATTACKS: Dictionary = {"combat": 1.5, "turn": 1.5, "next_attack_phase": 1.0, "next_turn_end": 3.0, "game": 6.0}


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
			return _use_score(engine, profile, me, c)
		&"relic":
			# The Relic fires once a game, so it is worth what it actually fetches rather than a
			# flat "do something". With a tutor decay set, that includes the chain it opens.
			return relic_score(engine, profile, me, c)
		&"defend", &"power_defend":
			return _defense_score(engine, profile, me, o, c)
		&"declare":
			# Declaring makes the rival draw three, and a Life Deck that empties loses at once, so
			# three or fewer left decks them out.
			if foe.life_deck.size() <= DuelEngine.DRAW_COUNT:
				return AiEvaluator.WIN
			return _declare_score(engine, profile, me)
		&"skip":
			return 1.0
		&"place":
			if c != null and c.def.type == CardDef.Type.GROUNDS:
				return _grounds_score(engine, profile, me, c)
			return 1.0 + hold_value(c, profile)
		&"shuffle_back":
			return -0.5
		&"keep":
			return _keep_score(engine, me, c, profile)
		&"reserve_in":
			# Cards already swapped out are in the Reserve but not on offer, which counts the swaps.
			var swaps: int = me.reserve.size() - prompt.card_options().size()
			if c == null or swaps >= int(profile.w("reserve", "max_swaps")):
				return -1.0
			return AiReserve.score(engine, seat, c, profile)
		&"counter":
			return _counter_score(engine, profile, me, prompt, c)
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
			return _capture_score(engine, profile, me, foe, c)
		&"deal_damage":
			return _landing_value(engine, profile, foe)
		&"lower_fervor":
			return _lower_fervor_score(engine, profile, foe)
		&"recover":
			return 1.0
		&"pay":
			return _pay_score(engine, profile, me, o)
		&"pay_life":
			if int(o.value) <= 0:
				return 0.0
			return _paid_bonus_value(engine, profile, "pay_life") - life_card_price(me, profile)
		&"pay_hand":
			if int(o.value) <= 0 or me.hand.is_empty():
				return 0.0
			return _paid_bonus_value(engine, profile, "pay_hand") - _cheapest_in_hand(me, profile)
		&"burn_defense":
			return _burn_score(engine, profile, me, o)
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
			if str(prompt.context.get("purpose", "")) == "wild_might":
				return _wild_might_score(engine, profile, me, prompt, o)
			return _pick_option_score(engine, me, profile, o, c)
		&"order_confirm":
			# The usual order is printed order; reordering is left to a player who has a reason.
			return 0.1
	# Every "do nothing" option, and anything this file has not met yet.
	return 0.0


static func _attack_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, foe: PlayerState, o: Command, c: CardInstance, forecasts: Dictionary) -> float:
	var f: Dictionary = forecasts.get(o.card, {})
	var empowered: bool = o.type == &"attack" and o.value != null and str(o.value) == "empower"
	if empowered and f.has("empowered"):
		f = f["empowered"]
	elif o.type == &"power" and o.value != null and str(o.value) == "alt" and f.has("alt"):
		f = f["alt"]
	elif o.type == &"final_strike" and f.has("final"):
		f = f["final"]
	elif o.type == &"copied_attack":
		f = _copied_forecast(engine, me)
	# Energy past what the defender stands on becomes wounds, one for one.
	var wounds: int = int(f.get("wounds", f.get("life", 0)))
	var soaked: int = int(f.get("stages", 0)) - int(f.get("overflow", 0))
	if wounds >= foe.life_deck.size() and wounds > 0:
		return AiEvaluator.WIN
	var v: float = wounds * profile.w("play", "damage_life") + soaked * profile.w("play", "damage_stage")
	v -= int(f.get("cost_stages", 0)) * _cost_weight(engine, profile, me)
	# Life Deck cards paid to perform it are wounds this side deals itself.
	v -= int(f.get("cost_life", 0)) * life_card_price(me, profile)
	if o.type == &"final_strike":
		# A bare Strike: the card is thrown away unplayed, and the rest of the Combat is spent passing.
		return v - card_value(engine, me, c, profile, TUTOR_DEPTH) - profile.w("play", "final_strike_penalty") - me.hand.size() * 0.5
	if c != null:
		var handover: float = AiEvaluator.handover_progress(engine, me)
		var kind: String = str(c.power().get("attack", {}).get("kind", "strike")) if o.type == &"power" else c.def.attack_kind()
		var lines: Array = c.power().get("effects", []) if o.type == &"power" else c.def.effects
		if empowered and not engine._has_floating(me.index, "empower_keeps_text"):
			# Empowering trades the card's "after Empower" text for the bigger number.
			lines = lines.filter(func(e: Dictionary) -> bool: return not bool(e.get("after_empower", false)))
		v += effects_value(lines, profile, ["secondary", "if_successful", "use"], handover, engine, me.index)
		v += _tutor_value(engine, me, c.def, profile, TUTOR_DEPTH, c)
		v += _mastery_attack_value(engine, profile, me, c.def, kind, handover)
		if o.type == &"attack" and c.zone == &"hand":
			# A card thrown into a block is gone for nothing, so while the rival can still block, lead
			# with the lesser card and keep the better one for a swing that lands.
			v -= profile.w("play", "attack_hold") * block_chance(foe) * hold_value(c, profile)
		if o.type == &"attack" and profile.w("play", "combo") > 0.0:
			v -= _combo_hold(engine, profile, me, c)
	return v + 0.1


## Wild Might makes a Might comparison the user's pick. The answer that runs the line is worth what
## the line does for this side; the other is worth nothing. An attack's own question carries no line,
## and its conditional lines are bonuses, so "higher" wins it.
static func _wild_might_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, prompt: Prompt, o: Command) -> float:
	var runs: bool = str(o.value) == str(prompt.context.get("runs_on", "higher"))
	var line: Dictionary = prompt.context.get("line", {})
	if line.is_empty():
		return 1.0 if runs else 0.0
	var value: float = effects_value([line], profile, [], AiEvaluator.handover_progress(engine, me), engine, me.index)
	return value if runs else 0.0


## The chance a rival holding this many hidden cards has at least one that blocks.
static func block_chance(foe: PlayerState) -> float:
	return 1.0 - pow(1.0 - BLOCK_SHARE, float(foe.hand.size()))


## The attack a copy repeats ("perform the attack that was just used against you"), read off the
## floating copy this side holds, priced from its data.
static func _copied_forecast(engine: DuelEngine, me: PlayerState) -> Dictionary:
	for fl in engine.state.floating:
		if int(fl.get("owner", -1)) == me.index and str(fl.get("op", "")) == "copied_attack":
			var spec: Dictionary = fl.get("spec", {})
			var base: Dictionary = DuelEngine.printed_base(spec, str(spec.get("kind", "strike")))
			var stages: int = int(base["stages"]) + int(spec.get("stages", 0))
			if str(spec.get("kind", "strike")) == "strike" and not spec.has("printed_stages") and not spec.has("printed_life"):
				stages += EVEN_TABLE_STAGES
			var life: int = int(base["life"]) + int(spec.get("life", 0))
			# The copy keeps the modifiers the copied attack had.
			for add in spec.get("copied_adds", []):
				stages += int((add as Dictionary).get("stages", 0))
				life += int((add as Dictionary).get("life", 0))
			var times: int = maxi(1, int(spec.get("copied_multiply", 1)))
			return {"stages": stages * times, "life": life * times}
	return {}


## What the Mastery adds to this attack: its `on_attack` lines, and its `on_success` lines priced as
## a hit ("if your Storm Art is successful, they may not use Strikes"). A line gated on the attack is
## counted only when this attack meets the gate.
static func _mastery_attack_value(engine: DuelEngine, profile: AiProfile, me: PlayerState, source: CardDef, kind: String, handover: float) -> float:
	if me.mastery == null or engine._forbidden(me, "mastery"):
		return 0.0
	var v: float = 0.0
	for e in me.mastery.def.effects:
		var trigger: String = str(e.get("trigger", "secondary"))
		if trigger != "on_attack" and trigger != "on_success":
			continue
		var fit: float = _attack_gate(e.get("when", {}), source, kind, profile)
		if fit <= 0.0:
			continue
		var line: Dictionary = e.duplicate()
		line.erase("when")
		line["trigger"] = "if_successful" if trigger == "on_success" else "secondary"
		v += fit * effects_value([line], profile, [], handover)
	return v


## 1 when an attack from `source` of `kind` meets a gate that reads the attack, 0 when it fails one,
## and the conditional share when the gate reads something only the resolving attack can tell.
static func _attack_gate(when: Dictionary, source: CardDef, kind: String, profile: AiProfile) -> float:
	var fit: float = 1.0
	for key in when.keys():
		match str(key):
			"source_school":
				if source == null or source.school != str(when[key]):
					return 0.0
			"attack_kind":
				if kind != str(when[key]):
					return 0.0
			_:
				fit = profile.w("effect", "conditional")
	return fit


## Damage lands whole on one personality, and stage damage past that personality's 0 turns into life
## cards one for one. So the one to pick is whoever can soak the most, not simply an Ally: an
## eight-stage hit put on an Ally standing at three is five stages that become five wounds, and five
## wounds is critical damage. Once the damage is soaked either way, it goes on whichever personality
## the profile values least.
static func _redirect_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, c: CardInstance) -> float:
	if c == null:
		return 0.0
	var b: Dictionary = engine.damage_breakdown(engine.state.attack)
	var stages: int = int(b.get("stages", 0))
	var overflow: int = maxi(0, stages - c.energy)
	var v: float = -float(overflow) * profile.w("play", "damage_life")
	var soaked: float = float(mini(stages, c.energy))
	if c == me.duelist:
		v -= soaked * duelist_energy_price(engine, me, profile)
	else:
		v -= soaked * profile.w("own", "ally_energy")
	return v


static func _defense_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, o: Command, c: CardInstance) -> float:
	var a: Dictionary = engine.state.attack
	var threat: float = _threat(engine, profile, me)
	# The attacker's hit lines, valued as the attacker's gain, which is this side's loss.
	threat += effects_value(a.get("effects", []), profile, ["if_successful"], 0.0, engine, 1 - me.index)
	# A card played only to try to stop an attack it cannot stop saves nothing; it is worth its
	# own lines alone.
	if o.value != null and str(o.value) == DuelEngine.TRY_STOP:
		threat = 0.0
	# A Shield in play that will stop it anyway leaves a hand block nothing to save.
	elif not engine._available_shields(me, str(a.get("kind", "strike")), bool(a.get("focused", false))).is_empty() and int(a.get("stops_needed", 1)) - int(a.get("stop_count", 0)) <= 1:
		threat = 0.0
	# An attack that needs two stops is stopped by this block only if another follows it.
	elif int(a.get("stops_needed", 1)) - int(a.get("stop_count", 0)) > 1:
		threat *= 0.5
	var cost: float = profile.w("play", "defend_in_play")
	if o.type == &"defend" and c != null and c.zone == &"hand":
		cost = profile.w("play", "defend_card")
		# A card that also attacks is a swing given up.
		if c.def.is_attack():
			cost += _expected_damage_value(c.def.attack, c.def.attack_kind(), profile) * profile.w("play", "kept_off_turn")
	if c != null and o.type == &"defend":
		var spec: Dictionary = c.def.defense
		cost += int(spec.get("cost_life", 0)) * life_card_price(me, profile)
		cost += int(spec.get("cost_hand", 0)) * (_cheapest_in_hand(me, profile) if me.hand.size() > 1 else 0.0)
		cost += int(spec.get("cost_stages", 0)) * duelist_energy_price(engine, me, profile)
	# What the block itself does on the way ("stop it and gain 2 Energy"), so the better block wins.
	var own_lines: float = 0.0
	if c != null:
		var lines: Array = c.power().get("effects", []) if o.type == &"power_defend" else c.def.effects
		own_lines = effects_value(lines, profile, ["secondary"], AiEvaluator.handover_progress(engine, me), engine, me.index)
	return threat - cost + own_lines


## What the attack in the air would cost this side if it landed: its wounds, counting the Energy that
## overflows into them, plus the Energy it takes. A killing blow is a lost game.
static func _threat(engine: DuelEngine, profile: AiProfile, me: PlayerState) -> float:
	return _landing_value(engine, profile, me)


## What the attack in the air does to `victim` when it lands: wounds (overflow included) and the
## Energy soaked. A killing blow is worth the game.
static func _landing_value(engine: DuelEngine, profile: AiProfile, victim: PlayerState) -> float:
	var b: Dictionary = engine.damage_breakdown(engine.state.attack)
	var wounds: int = int(b.get("wounds", 0))
	if wounds >= victim.life_deck.size() and wounds > 0:
		return AiEvaluator.WIN
	var soaked: int = int(b.get("stages", 0)) - int(b.get("overflow", 0))
	return wounds * profile.w("play", "damage_life") + soaked * profile.w("play", "damage_stage")


## Capturing a Seal instead of dealing damage: the Seal leaves their set and joins ours. A capture
## that completes our set wins; so does refusing it for damage that kills, which `deal_damage` prices.
static func _capture_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, foe: PlayerState, t: CardInstance) -> float:
	if t == null:
		return 0.0
	var mine_after: float = _seal_part(me, t.def.seal_set, 1)
	if mine_after >= 1.0:
		return AiEvaluator.WIN
	var gain: float = (mine_after - _seal_part(me, t.def.seal_set, 0)) * profile.w("own", "seal")
	var denied: float = (_seal_part(foe, "", 0) - _seal_part(foe, t.def.seal_set, -1)) * profile.w("foe", "seal")
	return gain + denied + profile.w("effect", "capture_seal") * 0.25


## `AiEvaluator.seal_progress` for `p` with `delta` Seals of `seal_set` added or taken away.
static func _seal_part(p: PlayerState, seal_set: String, delta: int) -> float:
	var counted: Dictionary = {}
	for s in p.seals():
		counted[s.def.seal_set] = int(counted.get(s.def.seal_set, 0)) + 1
	if seal_set != "":
		counted[seal_set] = maxi(0, int(counted.get(seal_set, 0)) + delta)
	var best: int = 0
	for k in counted:
		best = maxi(best, int(counted[k]))
	var part: float = float(best) / float(DuelEngine.SEALS_PER_SET)
	return 0.5 * part + 0.5 * part * part


## Taking a Fervor from the rival: the Fervor itself, plus how far it sets back their Ascension clock.
static func _lower_fervor_score(engine: DuelEngine, profile: AiProfile, foe: PlayerState) -> float:
	if foe.fervor <= 0:
		return 0.0
	var before: float = AiEvaluator.ascension_progress(engine, foe)
	foe.fervor -= 1
	var after: float = AiEvaluator.ascension_progress(engine, foe)
	foe.fervor += 1
	return _fervor_value(-1.0, true, profile) + (before - after) * profile.w("foe", "ascension")


## Countering the card the rival is playing: what its lines would have done for them, less the card
## that answers it.
static func _counter_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, prompt: Prompt, c: CardInstance) -> float:
	var pending: CardInstance = engine.card(int(prompt.context.get("card", -1)))
	if pending == null:
		return 1.5
	var foe_seat: int = 1 - me.index
	var denied: float = effects_value(pending.def.effects, profile, USE_TRIGGERS, 0.0, engine, foe_seat)
	if pending.def.is_attack():
		denied += _expected_damage_value(pending.def.attack, pending.def.attack_kind(), profile)
	return denied - (hold_value(c, profile) * 0.5 if c != null else 0.0)


## Buying wounds off with the discard pile: the wounds prevented, less the cards burned. The engine
## offers no more cards than clear the attack, so the bigger the hit, the more burning pays.
static func _burn_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, o: Command) -> float:
	var burn: Dictionary = me.mastery.def.raw.get("defense_burn", {}) if me.mastery != null else {}
	var per: int = maxi(1, int(burn.get("prevent_per", 2)))
	var cards: int = int(o.value) if o.value != null else 0
	var wounds: int = int(engine.damage_breakdown(engine.state.attack).get("wounds", 0))
	if wounds >= me.life_deck.size() and wounds - cards * per < me.life_deck.size():
		return AiEvaluator.WIN
	var prevented: int = mini(cards * per, wounds)
	return prevented * profile.w("play", "damage_life") - cards * profile.w("effect", "remove_discard")


## An optional cost bought for more damage ("discard the top card of your Life Deck: +3 wounds"):
## the bonus is only worth anything if the attack lands.
static func _paid_bonus_value(engine: DuelEngine, profile: AiProfile, key: String) -> float:
	var bonus: Dictionary = (engine.state.attack.get("spec", {}) as Dictionary).get(key, {})
	var damage: float = int(bonus.get("life", 0)) * profile.w("play", "damage_life") + int(bonus.get("stages", 0)) * profile.w("play", "damage_stage")
	return damage * profile.w("effect", "if_successful")


## What one card off this side's own Life Deck costs: a wound, and more once the deck runs low.
static func life_card_price(me: PlayerState, profile: AiProfile) -> float:
	var price: float = profile.w("play", "damage_life")
	if me.life_deck.size() <= 10:
		price += profile.w("own", "life_low")
	return price


static func _cheapest_in_hand(me: PlayerState, profile: AiProfile) -> float:
	var cheapest: float = INF
	for c in me.hand:
		cheapest = minf(cheapest, hold_value(c, profile))
	return cheapest


## Whether to open Combat, against `skip` at 1.0. Declaring hands the rival three cards and an attack
## phase of their own, so it needs a reason: an attack the engine would offer right now, or cards and
## powers to use in the attack phase that pay more than the rival's draw. Entering-Combat lines only
## add to a Combat worth having; a card drawn on entry is no reason to sit through the rival's
## attacks. Without a reason it is ruled out whatever the profile's `declare_bias`, which is a stance
## about how readily to fight, and out of reach of a weaker level's noise. `declare_use` weighs what
## is carried.
static func _declare_score(engine: DuelEngine, profile: AiProfile, me: PlayerState) -> float:
	var attackers: int = 0
	var carried: float = 0.0
	var handover: float = AiEvaluator.handover_progress(engine, me)
	for o in engine.attack_phase_options(me):
		var c: CardInstance = engine.card(o.card)
		match o.type:
			&"attack", &"copied_attack":
				attackers += 1
			&"power":
				var pw: Dictionary = c.power_alt() if o.value != null and str(o.value) == "alt" else c.power()
				if pw.has("attack"):
					attackers += 1
				else:
					carried += maxf(0.0, effects_value(pw.get("effects", []), profile, ["secondary"], handover, engine, me.index))
			&"use":
				if c != null:
					carried += maxf(0.0, _use_score(engine, profile, me, c))
			&"ransom":
				carried += profile.w("effect", "discard_in_play")
	if attackers == 0 and carried <= DuelEngine.DRAW_COUNT * profile.w("effect", "draw"):
		return -AiEvaluator.WIN
	return attackers * 1.0 + carried * profile.w("play", "declare_use") + _entering_value(engine, profile, me, handover) \
		+ profile.w("play", "declare_bias")


## What this side's own entering-Combat lines pay when it declares: its Drills, Non-Combats,
## attachments, Mastery and Grounds, its Duelist's power, and hand cards used on entry.
static func _entering_value(engine: DuelEngine, profile: AiProfile, me: PlayerState, handover: float) -> float:
	var lines: Array[Dictionary] = []
	for c in engine._in_play_sources(me, true):
		for e in c.def.effects_for("entering_combat"):
			if DuelEngine.role_matches(str(e.get("role", "")), "active"):
				lines.append(e)
		if c.attached_to != null:
			for e in c.def.attachment.get("effects", []):
				if str(e.get("trigger", "")) == "entering_combat":
					lines.append(e)
	for e in me.duelist.power().get("effects", []):
		if str(e.get("trigger", "")) == "entering_combat" and DuelEngine.role_matches(str(e.get("role", "")), "active"):
			lines.append(e)
	var v: float = effects_value(lines, profile, [], handover, engine, me.index)
	for c in me.hand:
		if str(c.def.raw.get("use_at", "")) == "entering_combat" and c.def.is_hand_combat_card() and engine._can_play(me, c.def):
			v += maxf(0.0, effects_value(c.def.effects, profile, [], handover, engine, me.index))
	return v


## Using `c` now: what its lines do, less the small price of spending an action on it.
static func _use_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, c: CardInstance) -> float:
	var handover: float = AiEvaluator.handover_progress(engine, me)
	return effects_value(c.def.effects, profile, USE_TRIGGERS, handover, engine, me.index) \
		+ _aspect_jump_value(c, me, profile) + _bond_use_value(engine, me, c.def, profile) \
		+ _tutor_value(engine, me, c.def, profile, TUTOR_DEPTH, c) \
		+ _combo_tutor_value(engine, profile, me, c) \
		- profile.w("play", "use_cost")


## Placing Grounds: what the new Grounds are worth to me against the ones they replace (or none),
## less the Combat given up, because a player who places Grounds cannot declare Combat that turn.
static func _grounds_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, c: CardInstance) -> float:
	var current: CardDef = engine.state.grounds.def if engine.state.grounds != null else null
	var gain: float = AiEvaluator.grounds_value(engine, me.index, c.def, profile) - AiEvaluator.grounds_value(engine, me.index, current, profile)
	return gain - maxf(0.0, _declare_score(engine, profile, me)) * profile.w("play", "grounds_skip")


## A card that moves the duelist to the aspect matching its Fervor: worth the aspects gained, and a
## loss when Fervor is lower than the aspect already held.
static func _aspect_jump_value(c: CardInstance, me: PlayerState, profile: AiProfile) -> float:
	for raw in c.def.effects:
		if raw is Dictionary and str((raw as Dictionary).get("op", "")) == "set_aspect" and str((raw as Dictionary).get("aspect", "")) == "fervor" and str((raw as Dictionary).get("who", "self")) == "self":
			var target: int = clampi(me.fervor, me.duelist.stack.lowest_aspect(), me.highest_aspect)
			return float(target - me.duelist.aspect) * profile.w("own", "aspect")
	return 0.0


## Using the Relic now: what its lines do this turn. Its uses are few, so a line that takes nothing
## away (forbidding a Mastery the rival does not have) is no reason to spend one.
static func relic_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, c: CardInstance) -> float:
	if c == null:
		return 0.0
	# A use spent is one fewer for later, so a use that does nothing loses to not using it.
	return effects_value(c.def.effects, profile, ["relic_use"], AiEvaluator.handover_progress(engine, me), engine, me.index) \
		+ _tutor_value(engine, me, c.def, profile, TUTOR_DEPTH, c) - profile.w("play", "use_cost")


## Whether forbidding `what` to the rival takes anything away: a forbidden Mastery, Drill, Ally or
## Relic they do not have in play costs them nothing. Kinds of card they play from hand are assumed live.
static func _foe_has(foe: PlayerState, what: String) -> bool:
	match what:
		"mastery":
			return foe.mastery != null
		"drills":
			return not foe.drills().is_empty()
		"non_combats":
			return not foe.non_combats().is_empty()
		"allies":
			return not foe.allies().is_empty()
		"relic":
			return foe.relic != null
	return true


## For the player whose turn is ending, a card kept through the discard step waits out the
## opponent's turn, where only a defense can act. Anything else matters again only after the next
## draw has refilled the hand, so it keeps `play.kept_off_turn` of its worth. The other player's turn is next, so
## whatever they keep is theirs to use at once.
static func _keep_score(engine: DuelEngine, me: PlayerState, c: CardInstance, profile: AiProfile) -> float:
	if c == null:
		return 0.5
	var worth: float = card_value(engine, me, c, profile, TUTOR_DEPTH)
	var waits: bool = me.index == engine.state.active and not c.def.is_defense()
	return 0.5 + (worth * profile.w("play", "kept_off_turn") if waits else worth)


## Paying Energy into a card: what each `per` Energy buys, less the Energy. On an attack
## (`pay_stages`) the bought damage lands only if the attack does; on a card line (`pay_energy`) it
## buys the line's `then` once per `per`.
static func _pay_score(engine: DuelEngine, profile: AiProfile, me: PlayerState, o: Command) -> float:
	var amount: int = int(o.value) if o.value != null else 0
	if amount <= 0:
		return 0.0
	var price: float = amount * duelist_energy_price(engine, me, profile)
	if str(engine._choice.get("kind", "")) == "pay_energy":
		var per: int = maxi(1, int(engine._choice.get("per", 1)))
		var bought: float = effects_value(engine._choice.get("then", []), profile, [], AiEvaluator.handover_progress(engine, me), engine, me.index)
		return float(amount / per) * bought - price
	var spec: Dictionary = (engine.state.attack.get("spec", {}) as Dictionary).get("pay_stages", {})
	var per_attack: int = maxi(1, int(spec.get("per", 2)))
	var damage: float = int(spec.get("stages", 0)) * profile.w("play", "damage_stage") + int(spec.get("life", 1 if spec.is_empty() else 0)) * profile.w("play", "damage_life")
	return float(amount / per_attack) * damage * profile.w("effect", "if_successful") - price


## What one Energy of an attack's cost weighs. Normally a price. A deck that fights through its
## Allies sets `play.attack_cost_handover` (usually below zero), and the price slides toward it as
## the handover comes within reach, the same way `effect.energy_self` does: spending the Duelist
## down to where an Ally takes over is the point of the card. Only while the Duelist is the one
## paying, since an Ally in control pays from its own Energy.
static func _cost_weight(engine: DuelEngine, profile: AiProfile, me: PlayerState) -> float:
	var base: float = profile.w("play", "attack_cost")
	if not (profile.data["play"] as Dictionary).has("attack_cost_handover") or me.in_control() != me.duelist:
		return base
	return lerpf(base, profile.w("play", "attack_cost_handover"), AiEvaluator.handover_progress(engine, me))


## What one of the Duelist's Energy is worth keeping. A deck that fights through its Allies sets
## `effect.energy_self` (usually below zero), and as the handover comes within reach the price
## slides toward it, the same blend `_effect_value` applies to an Energy effect.
static func duelist_energy_price(engine: DuelEngine, me: PlayerState, profile: AiProfile) -> float:
	var base: float = profile.w("own", "energy")
	if not (profile.data["effect"] as Dictionary).has("energy_self"):
		return base
	return lerpf(base, profile.w("effect", "energy_self"), AiEvaluator.handover_progress(engine, me))


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
		if readiness == 1.0 and source != me.in_control() and not engine.ally_power_without_control(me, source) and not engine.may_ally_control(me):
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
		# A line whose gate fails is skipped whole, as the engine skips it.
		if not engine._cond(e.get("when", {}), me.index, {}):
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
		for branch in branches(e, profile):
			pending.append({"effect": branch["effect"], "factor": factor * float(branch["share"])})
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
	if profile.w("play", "combo") > 0.0:
		var recursion: float = _recursion_combo_value(engine, me, c, profile)
		if recursion > 0.0:
			return recursion
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


# --- Recursion combos -------------------------------------------------------
# Two roles, read off the card data: a recursion card shuffles every card of a named character from
# the discard pile back ("shuffle all Vegeta Named cards in your discard pile into your Life Deck"),
# and an enabler makes the bottom of the pile count as that character's for the Combat. Played in
# that order in one Combat, the recursion takes back far more. `play.combo` turns the planning on.

## {"role": "recur" or "enable", "character", "count"} for a card that plays either part, else empty.
static func combo_role(def: CardDef) -> Dictionary:
	for raw in def.effects:
		if not (raw is Dictionary):
			continue
		var e: Dictionary = raw
		var op: String = str(e.get("op", ""))
		if op == "shuffle_discard" and bool(e.get("all", false)) and str(e.get("character", "")) != "":
			return {"role": "recur", "character": str(e["character"])}
		if op == "float" and str(e.get("what", "")) == "discard_named":
			var params: Dictionary = e.get("params", {})
			return {"role": "enable", "character": str(params.get("character", "")), "count": int(params.get("count", 0))}
	return {}


## The first card in `pool` playing `role` for `character`, other than `except`.
static func _combo_piece(pool: Array[CardInstance], role: String, character: String, except: CardInstance = null) -> CardInstance:
	for c in pool:
		if c == except:
			continue
		var r: Dictionary = combo_role(c.def)
		if str(r.get("role", "")) == role and str(r.get("character", "")) == character:
			return c
	return null


## What the recursion takes back if the enabler's float is out first: the pile's own named cards
## plus the bottom `count` it names, as recovery on a hit.
static func _combo_payoff(engine: DuelEngine, me: PlayerState, character: String, count: int, profile: AiProfile) -> float:
	var taken: int = 0
	for i in range(me.discard.size()):
		var c: CardInstance = me.discard[i]
		if i < count or engine.counts_as_named(me, c, character):
			taken += 1
	return float(taken) * profile.w("effect", "recover") * profile.w("effect", "if_successful")


## How much a recursion card loses by going before an enabler it could have waited for: the
## enabler is in hand, its float is not out yet, and the gap between the two payoffs is the price.
static func _combo_hold(engine: DuelEngine, profile: AiProfile, me: PlayerState, c: CardInstance) -> float:
	if c == null:
		return 0.0
	var role: Dictionary = combo_role(c.def)
	if str(role.get("role", "")) != "recur":
		return 0.0
	var character: String = str(role["character"])
	if not engine._floating_first(me.index, "discard_named").is_empty():
		return 0.0
	var enabler: CardInstance = _combo_piece(me.hand, "enable", character, c)
	if enabler == null or not engine._can_pay(me.in_control(), me, enabler.def.attack, enabler):
		return 0.0
	var count: int = int(combo_role(enabler.def).get("count", 0))
	var gain: float = _combo_payoff(engine, me, character, count, profile) - _combo_payoff(engine, me, character, 0, profile)
	return maxf(0.0, gain) * profile.w("play", "combo")


## A card that is one half of the combo is worth the payoff while its other half is at hand (in
## hand, or the enabler's float already out). This is what makes a search fetch the missing half
## and makes the discard step and a Mastery's fodder keep the pieces.
static func _recursion_combo_value(engine: DuelEngine, me: PlayerState, c: CardInstance, profile: AiProfile) -> float:
	var role: Dictionary = combo_role(c.def)
	if role.is_empty():
		return 0.0
	var character: String = str(role["character"])
	var partner_role: String = "enable" if str(role["role"]) == "recur" else "recur"
	var partner: CardInstance = _combo_piece(me.hand, partner_role, character, c)
	var float_out: bool = not engine._floating_first(me.index, "discard_named").is_empty()
	if partner == null and not (str(role["role"]) == "recur" and float_out):
		return 0.0
	var count: int = int(role.get("count", 0))
	if partner != null and str(role["role"]) == "recur":
		count = int(combo_role(partner.def).get("count", 0))
	return _combo_payoff(engine, me, character, count, profile) * profile.w("play", "combo")


## Using a search that can fetch a missing half of the combo while the other half is in hand, or
## both halves when neither is: worth the payoff it assembles.
static func _combo_tutor_value(engine: DuelEngine, profile: AiProfile, me: PlayerState, c: CardInstance) -> float:
	if c == null or profile.w("play", "combo") <= 0.0:
		return 0.0
	var best: float = 0.0
	for raw in c.def.effects:
		if not (raw is Dictionary):
			continue
		var e: Dictionary = raw
		if str(e.get("op", "")) != "search":
			continue
		var reach: int = int(e.get("amount", 1))
		var pieces: Dictionary = {}
		for cand in engine.search_candidates(me, e):
			var r: Dictionary = combo_role(cand.def)
			if not r.is_empty():
				pieces["%s|%s" % [r["role"], r["character"]]] = r
		for key in pieces.keys():
			var r: Dictionary = pieces[key]
			var character: String = str(r["character"])
			var partner_role: String = "enable" if str(r["role"]) == "recur" else "recur"
			var have_partner: bool = _combo_piece(me.hand, partner_role, character) != null
			var fetches_partner: bool = pieces.has("%s|%s" % [partner_role, character]) and reach >= 2
			if have_partner or fetches_partner:
				var count: int = int(r.get("count", 0))
				if str(r["role"]) == "recur":
					var partner: Dictionary = pieces.get("enable|%s" % character, {})
					var held: CardInstance = _combo_piece(me.hand, "enable", character)
					count = int(partner.get("count", 0)) if not partner.is_empty() else (int(combo_role(held.def).get("count", 0)) if held != null else 0)
				best = maxf(best, _combo_payoff(engine, me, character, count, profile))
	return best * profile.w("play", "combo")


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
	var controls: bool = c == me.in_control() or (c != me.duelist and engine.ally_power_without_control(me, c))
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
	match str(engine._choice.get("kind", "")):
		"energy_target":
			# "Raise any personality to their highest Energy": worth it on ours, a gift on theirs.
			if c == null:
				return 0.0
			var gain: float = float(CardInstance.MAX_STAGE - c.energy)
			if c.controller == me.index:
				return gain * (duelist_energy_price(engine, me, profile) if c == me.duelist else profile.w("own", "ally_energy"))
			var owner: PlayerState = engine.player(c.controller)
			return -gain * profile.w("foe", "energy" if c == owner.duelist else "ally_energy")
		"reveal_pick":
			# Picking from the rival's revealed cards for them: hand them the worst.
			if int(engine._choice.get("player", me.index)) != me.index:
				return -hold_value(c, profile)
		"play_or_hand":
			return 1.0 + hold_value(c, profile) if str(o.value) == "play" else hold_value(c, profile)
		"drawn_drills":
			# Shuffling a Drill that cannot be placed back draws nothing in its place, the same
			# trade the Non-Combat step's `shuffle_back` prices.
			return -0.5
	if c != null:
		# A search, a look at the top cards, a Seal to capture: take the best card on offer, which
		# for a deck that runs tutor chains means the card that carries the chain furthest.
		return 1.0 + card_value(engine, me, c, profile, TUTOR_DEPTH)
	var word: String = str(o.value) if o.value != null else ""
	var kind: String = str(engine._choice.get("kind", ""))
	if kind == "pay_cost":
		if word != "yes":
			return 0.0
		return effects_value(engine._choice.get("then", []), profile, [], AiEvaluator.handover_progress(engine, me), engine, me.index) \
			- int(engine._choice.get("stages", 0)) * duelist_energy_price(engine, me, profile)
	if kind == "may":
		# The line belongs to its owner; when the question was put across the table, what is good
		# for the owner is bad for the one answering.
		var owner: int = int(engine._choice.get("owner", me.index))
		var sign: float = 1.0 if owner == me.index else -1.0
		var line_owner: PlayerState = engine.player(owner)
		if word == "yes":
			return sign * _may_yes_score(engine, line_owner, profile)
		if word == "no":
			return sign * effects_value((engine._choice.get("effect", {}) as Dictionary).get("otherwise", []), profile, [], 0.0, engine, owner)
	return _word_score(engine, me, profile, word)


## A named choice ("life" or "cost", "self" or "opponent", a card type, one of several lines),
## priced by what that answer makes the effect do.
static func _word_score(engine: DuelEngine, me: PlayerState, profile: AiProfile, word: String) -> float:
	var choice: Dictionary = engine._choice
	var handover: float = AiEvaluator.handover_progress(engine, me)
	match str(choice.get("kind", "")):
		"life_for_cost":
			# The Energy kept against the Life Deck card given up for it.
			if word != "life":
				return 0.0
			var stages: int = int((engine.prompt.context if engine.prompt != null else {}).get("stages", 0))
			var payer: CardInstance = engine._performer(engine.state.attack)
			var per: float = duelist_energy_price(engine, me, profile) if payer == me.duelist else profile.w("own", "ally_energy")
			return stages * per - life_card_price(me, profile)
		"art_boost":
			if word == "life":
				return int(engine._art_boost(me, me.duelist).get("life", 1)) * profile.w("play", "damage_life") * profile.w("effect", "if_successful")
			var prompt_ctx: Dictionary = engine.prompt.context if engine.prompt != null else {}
			return (int(prompt_ctx.get("full", 0)) - int(prompt_ctx.get("cheap", 0))) * _cost_weight(engine, profile, me)
		"discard_side":
			var sided: Dictionary = (choice.get("effect", {}) as Dictionary).duplicate()
			sided["who"] = word
			return effects_value([sided], profile, [], handover, engine, me.index)
		"card_type":
			var typed: Dictionary = (choice.get("effect", {}) as Dictionary).duplicate()
			typed["card_type"] = word
			return effects_value([typed], profile, [], handover, engine, me.index)
		"choose_one":
			var picks: Array = choice.get("choices", [])
			var i: int = int(word) if word.is_valid_int() else -1
			if i < 0 or i >= picks.size():
				return 0.0
			var pick: Dictionary = picks[i]
			return effects_value(pick.get("effects", [pick]), profile, [], handover, engine, me.index)
		"draw_count":
			var drawn: Dictionary = (choice.get("effect", {}) as Dictionary).duplicate()
			drawn["amount"] = int(word) if word.is_valid_int() else 0
			return effects_value([drawn], profile, [], handover, engine, me.index)
		"forbid_type", "stop_kind":
			# Aimed at what the rival has shown they play: their discard pile says which kind.
			return float(_shown_count(engine.player(1 - me.index), word))
	return 0.0


## How many cards of a kind a player has shown in their discard pile, for a choice that names
## a kind ("strike_cards", "art_cards", "combat_cards", "strike", "art").
static func _shown_count(p: PlayerState, word: String) -> int:
	var n: int = 0
	for c in p.discard:
		match word:
			"strike_cards", "strike":
				n += 1 if c.def.is_attack() and c.def.attack_kind() == "strike" else 0
			"art_cards", "art":
				n += 1 if c.def.is_attack() and c.def.attack_kind() == "art" else 0
			"combat_cards":
				n += 1 if c.def.type == CardDef.Type.COMBAT else 0
	return n


## A "you may" line is worth what the line itself costs or gives, plus what it leads on to. A card
## or life card paid is priced like any other card or wound. Focus ("discard a card to make this
## attack Focused") is worth the attack's damage only as often as the rival holds a block and that
## block is one Focus gets past; the hand's size and their shown defences are public, the cards are not.
static func _may_yes_score(engine: DuelEngine, me: PlayerState, profile: AiProfile) -> float:
	var e: Dictionary = engine._choice.get("effect", {})
	if e.is_empty():
		return 0.5
	var own_line: Dictionary = e.duplicate()
	for key in ["then", "effects", "else_effects", "may", "when", "trigger"]:
		own_line.erase(key)
	var amount: int = maxi(1, int(e.get("amount", 1))) if (e.get("amount", 1) is int or e.get("amount", 1) is float) else 1
	var mine: bool = str(e.get("who", "self")) == "self"
	var value: float = 0.0
	match str(e.get("op", "")):
		"discard_hand" when mine:
			if me.hand.is_empty():
				return -1.0
			value = -_cheapest_in_hand(me, profile) * amount
		"discard_life" when mine:
			value = -life_card_price(me, profile) * amount
		_:
			value = effects_value([own_line], profile, [], AiEvaluator.handover_progress(engine, me), engine, me.index)
	for branch in branches(e, profile):
		var child: Dictionary = branch["effect"]
		if str(child.get("op", "")) == "focus_attack":
			value += float(branch["share"]) * _focus_value(engine, me, profile)
		else:
			value += float(branch["share"]) * effects_value([child], profile, [], AiEvaluator.handover_progress(engine, me), engine, me.index)
	# "Instead of dealing damage, ...": a yes gives up the hit it replaces.
	if bool(e.get("skip_damage", false)) and not engine.state.attack.is_empty():
		value -= _landing_value(engine, profile, engine.player(1 - me.index))
	return value


## What making the attack in the air Focused is worth: its damage, times the chance the rival holds
## a block, times the share of their blocks that Focus gets past.
static func _focus_value(engine: DuelEngine, me: PlayerState, profile: AiProfile) -> float:
	if engine.state.attack.is_empty():
		return 0.0
	var foe: PlayerState = engine.player(1 - me.index)
	var d: Dictionary = engine.damage_breakdown(engine.state.attack)
	var swing: float = float(d.get("wounds", 0)) * profile.w("play", "damage_life") + float(d.get("stages", 0)) * profile.w("play", "damage_stage")
	return swing * block_chance(foe) * _stop_any_share(foe)


## The share of a rival's shown defences that Focus gets past: those that stop both kinds and do
## not say they stop a Focused attack. One of three until they have shown otherwise.
static func _stop_any_share(foe: PlayerState) -> float:
	var any: float = 1.0
	var total: float = 3.0
	for pile in [foe.discard, foe.removed, foe.in_play]:
		for c in pile:
			var spec: Dictionary = c.def.defense
			if spec.is_empty():
				continue
			total += 1.0
			if str(spec.get("stops", "")) == "any" and not spec.has("stop_focused"):
				any += 1.0
	return any / total


## What a card is worth keeping for, from its data alone.
static func hold_value(c: CardInstance, profile: AiProfile) -> float:
	if c == null or c.def == null:
		return 0.0
	var def: CardDef = c.def
	var v: float = 0.0
	if def.is_attack():
		v += 1.5 + _expected_damage_value(def.attack, def.attack_kind(), profile)
		if bool(def.attack.get("focused", false)) or bool(def.attack.get("unstoppable", false)):
			v += 1.0
	if def.is_defense():
		# A defense is worth the hit it stops, read as an Art's base wounds, the same yardstick a
		# held attack is measured by.
		v += 1.5 + DuelEngine.ART_BASE_LIFE * profile.w("play", "damage_life")
	match def.type:
		CardDef.Type.PERSONALITY:
			v += profile.w("own", "ally")
			# Allies differ mostly in what their power does, and a deck that searches for one wants
			# the one that can swing, not whichever the list happens to offer first.
			var pw: Dictionary = c.power()
			if pw.has("attack"):
				var pa: Dictionary = pw["attack"]
				v += 1.5 + _expected_damage_value(pa, str(pa.get("kind", "strike")), profile)
				if bool(pa.get("focused", false)) or bool(pa.get("unstoppable", false)):
					v += 1.0
			v += effects_value(pw.get("effects", []), profile, []) * 0.5
		CardDef.Type.DRILL, CardDef.Type.MASTERY:
			if def.type == CardDef.Type.DRILL:
				v += profile.w("own", "drill")
			# What it adds to every attack while it stands. A Drill goes when its Duelist climbs, so
			# it is counted for about half a game.
			for m in def.modifiers:
				v += modifier_value(m, "game", profile) * (0.5 if def.type == CardDef.Type.DRILL else 1.0)
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


## What an attack is expected to deal from its data alone, priced: its printed numbers or an Art's
## base, plus what the card adds. A plain Strike's base comes from the Strike Table and depends on
## the matchup, so it is read as the table result between equal Might bands.
static func _expected_damage_value(spec: Dictionary, kind: String, profile: AiProfile) -> float:
	var base: Dictionary = DuelEngine.printed_base(spec, kind)
	var life: int = int(base["life"]) + int(spec.get("life", 0))
	var stages: int = int(base["stages"]) + int(spec.get("stages", 0))
	if kind == "strike" and not spec.has("printed_stages") and not spec.has("printed_life"):
		stages += EVEN_TABLE_STAGES
	return life * profile.w("play", "damage_life") + stages * profile.w("play", "damage_stage")


## Sum of what a list of effects is worth to the player who owns them. `triggers` filters by
## trigger when it is not empty. Effects aimed at the opponent count for what they take away.
## `handover` is AiEvaluator.handover_progress for the player who owns the effects: 0 normally, 1
## when an Ally is out and only waiting on the Duelist to be spent. It flips the sign of what this
## player's own Energy is worth, so a deck that fights through Allies reads a self-drain as a gain.
## `board` and `seat` are the table and the owner when the effect is about to happen; with them a
## line is priced against the position (how many cards "all" is, whether a draw decks someone,
## whether a forbid takes anything away), and without them from the card data alone.
static func effects_value(effects: Array, profile: AiProfile, triggers: Array, handover: float = 0.0, board: DuelEngine = null, seat: int = -1) -> float:
	var total: float = 0.0
	for raw in effects:
		if not (raw is Dictionary):
			continue
		var e: Dictionary = raw
		var trigger: String = str(e.get("trigger", "secondary"))
		if not triggers.is_empty() and not triggers.has(trigger):
			continue
		var v: float = _effect_value(e, profile, handover, board, seat)
		if absf(v) >= AiEvaluator.WIN:
			return v
		for branch in branches(e, profile):
			v += float(branch["share"]) * effects_value([branch["effect"]], profile, [], handover, board, seat)
		if trigger == "if_successful":
			v *= profile.w("effect", "if_successful")
		elif trigger == "if_stopped":
			v *= profile.w("effect", "if_stopped")
		if e.has("when"):
			v *= profile.w("effect", "conditional")
		total += v
	return total


## What an effect leads on to, each as {effect, share}: the share of the time it happens. `then`
## always follows. `effects` and `else_effects` hang off a check the engine settles as the line
## resolves (the school of a drawn or burned card), so with both branches each is an even call, and
## a lone pass branch is priced like any other condition.
static func branches(e: Dictionary, profile: AiProfile) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child in e.get("then", []):
		if child is Dictionary:
			out.append({"effect": child, "share": 1.0})
	var hit: Array = e.get("effects", [])
	var miss: Array = e.get("else_effects", [])
	var hit_share: float = 0.5 if not miss.is_empty() else profile.w("effect", "conditional")
	for child in hit:
		if child is Dictionary:
			out.append({"effect": child, "share": hit_share})
	for child in miss:
		if child is Dictionary:
			out.append({"effect": child, "share": 0.5})
	return out


## A standing modifier's worth: what it adds to one attack, times the attacks it is expected to
## touch while it lasts. `own` raises this side's damage, `against` cuts what lands on this side,
## and the two cost scopes move what attacks cost.
static func modifier_value(m: Dictionary, duration: String, profile: AiProfile) -> float:
	var damage: float = int(m.get("stages", 0)) * profile.w("play", "damage_stage") + int(m.get("life", 0)) * profile.w("play", "damage_life")
	var per_attack: float = 0.0
	match str(m.get("scope", "own")):
		"own":
			per_attack = damage
		"against":
			per_attack = -damage
		"cost":
			per_attack = -int(m.get("stages", 0)) * profile.w("play", "attack_cost")
		"opponent_cost":
			per_attack = int(m.get("stages", 0)) * profile.w("play", "attack_cost")
		_:
			return profile.w("effect", "float")
	# One kind of attack ("your Arts do +1") touches about half of them.
	var reach: float = 1.0 if str(m.get("kind", "any")) == "any" else 0.5
	return per_attack * reach * float(MODIFIER_ATTACKS.get(duration, 1.5))


static func _effect_value(e: Dictionary, profile: AiProfile, handover: float = 0.0, board: DuelEngine = null, seat: int = -1) -> float:
	var who: String = str(e.get("who", "self"))
	var known: bool = board != null and seat >= 0
	if who == "any":
		# "Every Ally in play" hits both sides at once; "an Ally in play" is the chooser's aim, so it
		# is worth its better aim.
		if bool(e.get("all", false)) and known:
			var mine_all: Dictionary = e.duplicate()
			mine_all["who"] = "self"
			var theirs_all: Dictionary = e.duplicate()
			theirs_all["who"] = "opponent"
			return _effect_value(mine_all, profile, handover, board, seat) + _effect_value(theirs_all, profile, handover, board, seat)
		var mine: Dictionary = e.duplicate()
		mine["who"] = "self"
		var theirs: Dictionary = e.duplicate()
		theirs["who"] = "opponent"
		return maxf(_effect_value(mine, profile, handover, board, seat), _effect_value(theirs, profile, handover, board, seat))
	var op: String = str(e.get("op", ""))
	var on_foe: bool = who == "opponent"
	var side: float = -1.0 if on_foe else 1.0
	var me: PlayerState = board.player(seat) if known else null
	var target: PlayerState = (board.player(1 - seat) if on_foe else me) if known else null
	var amount: float = _amount(e, board, target, me)
	match op:
		"energy":
			if str(e.get("amount", "")) == "max":
				amount = float(CardInstance.MAX_STAGE - target.duelist.energy) if known else 5.0
			elif known and amount > 0.0:
				# A gain past a full gauge is lost, so only the room left counts.
				amount = minf(amount, float(CardInstance.MAX_STAGE - target.duelist.energy))
			# A deck that fights through its Allies wants its own Energy spent rather than gained,
			# since the Allies only take over once the Duelist is down to 0 or 1. It says so with
			# `energy_self`, often below zero, the way a camping deck sets `fervor_self`. It only
			# applies as far as the handover is actually on the table: with no Ally out, spending
			# the Duelist's Energy just leaves it unable to attack.
			if not on_foe and handover > 0.0 and (profile.data["effect"] as Dictionary).has("energy_self"):
				return amount * lerpf(profile.w("effect", "energy"), profile.w("effect", "energy_self"), handover)
			return side * amount * profile.w("effect", "energy")
		"fervor":
			var fervor_v: float = _fervor_value(amount, on_foe, profile)
			if known and profile.w("effect", "fervor_climb") > 0.0:
				fervor_v += _climb_bonus(board, target, amount, on_foe, profile)
			return fervor_v
		"set_fervor":
			if not known:
				return profile.w("effect", "other")
			return _fervor_value(amount - float(target.fervor), on_foe, profile)
		"draw", "draw_until", "draw_discard":
			# Drawing from an empty Life Deck loses the duel, whoever made the draw.
			if known and op == "draw" and int(amount) >= target.life_deck.size():
				return -side * AiEvaluator.WIN
			return side * amount * profile.w("effect", "draw")
		"search", "look_at", "return_removed":
			return _search_value(e, profile, board, me) if known and not on_foe and op == "search" else profile.w("effect", "search")
		"discard_in_play":
			if known:
				amount = float(_in_play_count(target, str(e.get("card_type", "")))) if bool(e.get("all", false)) else minf(amount, float(_in_play_count(target, str(e.get("card_type", "")))))
			return -side * amount * profile.w("effect", "discard_in_play")
		"discard_hand":
			return -side * amount * profile.w("effect", "discard_hand")
		"remove_hand":
			# Out of the game rather than to the pile, so a deck can price it apart; by default it
			# weighs the same as a discard.
			var removal: String = "remove_hand" if (profile.data["effect"] as Dictionary).has("remove_hand") else "discard_hand"
			return -side * amount * profile.w("effect", removal)
		"reveal_hand":
			# Showing a hand hands information across the table and takes nothing, so it is a small
			# price the rest of the card has to pay for.
			return -side * profile.w("effect", "discard_hand") * 0.25
		"discard_life":
			# Milling a Life Deck to nothing ends the duel; a card off one's own deck costs a wound.
			if known and int(amount) >= target.life_deck.size() and amount > 0.0:
				return -side * AiEvaluator.WIN
			if known and not on_foe:
				return -amount * life_card_price(me, profile)
			return -side * amount * profile.w("effect", "discard_life")
		"recover", "shuffle_discard":
			# "Shuffle every <kind> card in your discard pile": as many as the pile holds of it.
			if known and op == "shuffle_discard" and bool(e.get("all", false)):
				amount = float(_discard_matches(board, target, e))
			return side * amount * profile.w("effect", "recover")
		"remove_discard":
			return -side * amount * profile.w("effect", "remove_discard")
		"forbid", "choose_forbid_type":
			# A forbid on this side is a cost; one on the rival takes away only what they have.
			if not on_foe:
				return -profile.w("effect", "forbid")
			if known and op == "forbid" and not _foe_has(target, str(e.get("what", ""))):
				return 0.0
			# A second forbid of what is already forbidden changes nothing.
			if known and op == "forbid" and board._forbidden(target, str(e.get("what", ""))):
				return 0.0
			if known and op == "forbid" and str(e.get("what", "")) == "mastery":
				return _mastery_lock_value(board, profile, me, target)
			return profile.w("effect", "forbid")
		"next_attack_tax", "force_declare":
			return profile.w("effect", "forbid")
		"float":
			if str(e.get("what", "")) == "modifier":
				return modifier_value(e.get("params", {}), str(e.get("duration", "combat")), profile)
			if str(e.get("what", "")) == "discard_named" and known and not on_foe:
				return _named_discard_value(e, profile, board, me)
			return profile.w("effect", "float")
		"focus_attack":
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
		"set_aspect":
			# To a named Aspect: worth the Aspects moved. To the one matching Fervor: see _aspect_jump_value.
			if not known or not (e.get("aspect", "") is int or e.get("aspect", "") is float):
				return profile.w("effect", "other")
			var moved: float = float(int(e["aspect"]) - target.duelist.aspect)
			return moved * (profile.w("foe", "aspect") * -1.0 if on_foe else profile.w("own", "aspect"))
		"lose_aspect":
			return profile.w("foe", "aspect") if on_foe else -profile.w("own", "aspect")
		"no_ascension_win":
			# Giving up the Ascension win costs what the climb toward it was worth.
			var progress: float = AiEvaluator.ascension_progress(board, target) if known else 0.25
			return progress * (profile.w("foe", "ascension") if on_foe else -profile.w("own", "ascension"))
		"skip_next_attack_phase", "pass_next_phase":
			# An attack phase lost is an attack not made: an Art's base hit, the reference swing.
			return -side * DuelEngine.ART_BASE_LIFE * profile.w("play", "damage_life")
		"copy_drill":
			# A copy of a Drill in play works for this side until Combat ends: a Drill's worth, and
			# nothing when there is no Drill to copy.
			if not known:
				return profile.w("own", "drill")
			for q in [me, board.player(1 - seat)]:
				for d in (q as PlayerState).drills():
					if not d.def.has_trigger("entering_combat"):
						return profile.w("own", "drill")
			return 0.0
	return profile.w("effect", "other")


## Locking the rival's Mastery: what that Mastery does for them in a Combat, and only as far as a
## Combat is coming. Used before Combat, it is worth something only on a turn this side means to
## declare, so a limited lock (a Relic used twice a game) waits for the Combat it protects.
static func _mastery_lock_value(board: DuelEngine, profile: AiProfile, me: PlayerState, foe: PlayerState) -> float:
	if foe.mastery == null:
		return 0.0
	var threat: float = mastery_threat(board, foe, profile)
	if board.state.step == GameState.Step.COMBAT:
		return threat
	return threat if _declare_score(board, profile, me) > 0.0 else 0.0


## What a player's Mastery is worth to them over one Combat: its standing damage, its triggered
## lines as they would read them, and a Mastery that buys wounds off instead of blocking.
static func mastery_threat(board: DuelEngine, p: PlayerState, profile: AiProfile) -> float:
	var def: CardDef = p.mastery.def
	var v: float = 0.0
	for m in def.modifiers:
		v += maxf(0.0, modifier_value(m, "combat", profile))
	v += maxf(0.0, effects_value(def.effects, profile, [], 0.0, board, p.index))
	if def.raw.has("defense_burn"):
		v += 2.0 * profile.w("play", "defend_card")
	if def.opponent_aspect_threshold > 0:
		v += profile.w("effect", "fervor")
	return v


## Cards in `p`'s discard pile a "shuffle every ..." line would take: its school and its named
## character, read the way the engine reads them.
static func _discard_matches(board: DuelEngine, p: PlayerState, e: Dictionary) -> int:
	var school: String = str(e.get("school", ""))
	var character: String = str(e.get("character", ""))
	var n: int = 0
	for c in p.discard:
		if (school == "" or c.def.school == school) and (character == "" or board.counts_as_named(p, c, character)):
			n += 1
	return n


## "The bottom N cards of your discard pile are <Name> Named cards": worth the cards it newly names,
## as recovery, when a card in hand shuffles that character's cards back; a quarter of that when
## the payoff is still somewhere in the deck.
static func _named_discard_value(e: Dictionary, profile: AiProfile, board: DuelEngine, me: PlayerState) -> float:
	var params: Dictionary = e.get("params", {})
	var character: String = str(params.get("character", ""))
	var count: int = mini(int(params.get("count", 0)), me.discard.size())
	var newly: int = 0
	for i in range(count):
		if me.discard[i].def.character != character:
			newly += 1
	var share: float = 0.25
	for c in me.hand:
		if _recycles_named(c.def.effects, character):
			share = profile.w("effect", "if_successful")
			break
	return float(newly) * share * profile.w("effect", "recover")


static func _recycles_named(effects: Array, character: String) -> bool:
	for raw in effects:
		if not (raw is Dictionary):
			continue
		var e: Dictionary = raw
		if str(e.get("op", "")) == "shuffle_discard" and str(e.get("character", "")) == character:
			return true
		if _recycles_named(e.get("then", []), character):
			return true
	return false


## `effect.fervor_climb` (off by default): a Fervor gain that completes a climb is worth the Aspect
## it reaches, scaled by the knob. A deck whose second Aspect is its whole plan sets it, so the gain
## that gets there reads as more than the same gain anywhere else.
static func _climb_bonus(board: DuelEngine, target: PlayerState, amount: float, on_foe: bool, profile: AiProfile) -> float:
	if amount <= 0.0 or target.duelist.stack == null:
		return 0.0
	if target.duelist.aspect >= target.duelist.stack.highest_aspect():
		return 0.0
	var needed: int = board.fervor_needed(target)
	if target.fervor >= needed or target.fervor + int(amount) * board.fervor_gain(target) < needed:
		return 0.0
	var worth: float = profile.w("foe", "aspect") * -1.0 if on_foe else profile.w("own", "aspect")
	return worth * profile.w("effect", "fervor_climb")


## A Fervor change, priced by whose it is. A deck that wants to stay on its aspect sets `fervor_self`,
## often below zero, and one built to police the rival's climb sets `fervor_foe` above `fervor`.
static func _fervor_value(amount: float, on_foe: bool, profile: AiProfile) -> float:
	var weights: Dictionary = profile.data["effect"]
	if not on_foe and weights.has("fervor_self"):
		return amount * profile.w("effect", "fervor_self")
	if on_foe and weights.has("fervor_foe"):
		return -amount * profile.w("effect", "fervor_foe")
	return (-amount if on_foe else amount) * profile.w("effect", "fervor")


## An effect's amount: the engine's own count when the table is at hand, else the printed number
## (1 for a count read off the table, 2 for "all").
static func _amount(e: Dictionary, board: DuelEngine, target: PlayerState, owner: PlayerState) -> float:
	var raw: Variant = e.get("amount", 1)
	if raw is int or raw is float:
		return float(raw)
	if board != null and target != null:
		return float(board.effect_amount(e, target, owner))
	return 2.0 if bool(e.get("all", false)) else 1.0


## How many of `p`'s cards in play a line naming `card_type` could take ("" is any).
static func _in_play_count(p: PlayerState, card_type: String) -> int:
	if card_type == "":
		return p.in_play.size()
	var wanted: int = int(CardDef.TYPE_NAMES.get(card_type, -1))
	var n: int = 0
	for c in p.in_play:
		if c.def.type == wanted:
			n += 1
	return n


## A search for this side: worth the search weight scaled by how good the best card it can fetch is
## against the deck's average card, and nothing when it can fetch nothing.
static func _search_value(e: Dictionary, profile: AiProfile, board: DuelEngine, me: PlayerState) -> float:
	var found: Array = board.search_candidates(me, e)
	if found.is_empty():
		return 0.0
	var best: float = 0.0
	for c in found:
		best = maxf(best, hold_value(c, profile))
	var average: float = AiReserve.average_hold(me, profile)
	return profile.w("effect", "search") * clampf(best / maxf(1.0, average), 0.5, 2.0)
