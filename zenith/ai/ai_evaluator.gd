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


static func side_value(engine: DuelEngine, p: PlayerState, profile: AiProfile, group: String) -> float:
	var v: float = 0.0
	var life: int = p.life_deck.size()
	v += life * profile.w(group, "life")
	v -= maxi(0, 10 - life) * profile.w(group, "life_low")
	v += p.discard.size() * profile.w(group, "discard")
	v += p.duelist.energy * profile.w(group, "energy")
	v += engine.strike_table.band(p.in_control().might()) * profile.w(group, "band")
	v += p.hand.size() * profile.w(group, "hand")
	v += p.duelist.aspect * profile.w(group, "aspect")
	v += ascension_progress(engine, p) * profile.w(group, "ascension")
	v += climb_progress(engine, p) * profile.w(group, "fervor")
	v += seal_progress(p) * profile.w(group, "seal")
	v += seal_guard_value(p) * profile.w(group, "seal_guard")
	for al in p.allies():
		v += profile.w(group, "ally") + al.energy * profile.w(group, "ally_energy")
	v += p.drills().size() * profile.w(group, "drill")
	v += p.non_combats().size() * profile.w(group, "non_combat")
	v += p.attachments().size() * profile.w(group, "attachment")
	v -= engine.restrictions(p).size() * profile.w(group, "forbid")
	return v


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
	var lowest: int = p.duelist.def.lowest_aspect()
	var aspects: int = maxi(1, p.highest_aspect - lowest + 1)
	var done: float = float(p.duelist.aspect - lowest) + clampf(float(p.fervor) / float(needed), 0.0, 1.0)
	var part: float = clampf(done / float(aspects), 0.0, 1.0)
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


## 0 to 1, how close this player is to a full Seal set. Squared for the same reason.
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
	return part * part
