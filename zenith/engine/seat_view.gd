class_name SeatView
extends RefCounted
## The duel as one seat is allowed to see it: public standings, every zone as uids, and a card
## table where cards this seat may not see carry only uid and zone. This is the only thing a
## client renders from, so a client never holds information its player could not have.

var seat: int = 0
var turn: int = 0
var step: int = GameState.Step.SETUP
var phase: int = GameState.Phase.NONE
var active: int = 0
var attacker: int = 0
var winner: int = -1
var win_reason: String = ""
var deciding: int = -1                 # who the pending prompt belongs to, -1 when none
var deciding_kind: StringName = &""
var attack: Dictionary = {}            # public summary of the attack in the air, {} when none
var battle_step: int = 0               # where the battle sequence stands while `attack` is in the air
var last_attack: Dictionary = {}       # outcome of the last attack this Combat, {} until one ends
var forecasts: Dictionary = {}         # uid -> damage breakdown for each attack this seat may declare now
var grounds: int = -1
var resolving: Array[int] = []
var players: Array[SeatPlayer] = []
var cards: Dictionary = {}             # uid -> SeatCard


func is_over() -> bool:
	return winner >= 0


func player(i: int) -> SeatPlayer:
	return players[i]


## Live Vigor for a personality in play that this seat can see, else -1.
func live_vigor(uid: int) -> int:
	var c: SeatCard = card(uid)
	if c == null or c.hidden():
		return -1
	for p in players:
		if p.fighter == uid or p.allies.has(uid):
			return c.vigor
	return -1


## The player whose fighter this card is, else null. Faces read Acclaim and the other effective
## values from it.
func fighter_owner(uid: int) -> SeatPlayer:
	for p in players:
		if p.fighter == uid:
			return p
	return null


func card(uid: int) -> SeatCard:
	return cards.get(uid)


## Every card the seat may see the face of.
func visible_cards() -> Array[SeatCard]:
	var out: Array[SeatCard] = []
	for c in cards.values():
		if not c.hidden():
			out.append(c)
	return out


func to_dict() -> Dictionary:
	var ps: Array = []
	for p in players:
		ps.append(p.to_dict())
	var cs: Array = []
	for c in cards.values():
		cs.append(c.to_dict())
	return {
		"seat": seat, "turn": turn, "step": step, "phase": phase, "active": active, "attacker": attacker,
		"winner": winner, "win_reason": win_reason, "deciding": deciding, "deciding_kind": String(deciding_kind),
		"attack": attack, "battle_step": battle_step, "last_attack": last_attack, "forecasts": forecasts,
		"grounds": grounds, "resolving": resolving, "players": ps, "cards": cs,
	}


## The forecast for a card this seat could attack with now, {} when there is none.
func forecast(uid: int) -> Dictionary:
	return forecasts.get(uid, forecasts.get(str(uid), {}))


static func from_dict(d: Dictionary) -> SeatView:
	var v: SeatView = SeatView.new()
	v.seat = int(d.get("seat", 0))
	v.turn = int(d.get("turn", 0))
	v.step = int(d.get("step", 0))
	v.phase = int(d.get("phase", 0))
	v.active = int(d.get("active", 0))
	v.attacker = int(d.get("attacker", 0))
	v.winner = int(d.get("winner", -1))
	v.win_reason = str(d.get("win_reason", ""))
	v.deciding = int(d.get("deciding", -1))
	v.deciding_kind = StringName(str(d.get("deciding_kind", "")))
	v.attack = d.get("attack", {})
	v.battle_step = int(d.get("battle_step", 0))
	v.last_attack = d.get("last_attack", {})
	for k in d.get("forecasts", {}).keys():
		v.forecasts[int(k)] = d["forecasts"][k]
	v.grounds = int(d.get("grounds", -1))
	v.resolving = SeatPlayer.ints(d.get("resolving", []))
	for pd in d.get("players", []):
		v.players.append(SeatPlayer.from_dict(pd))
	for cd in d.get("cards", []):
		var c: SeatCard = SeatCard.from_dict(cd)
		v.cards[c.uid] = c
	return v


static func of(engine: DuelEngine, seat: int) -> SeatView:
	var s: GameState = engine.state
	var v: SeatView = SeatView.new()
	v.seat = seat
	v.turn = s.turn
	v.step = s.step
	v.phase = s.phase
	v.active = s.active
	v.attacker = s.attacker
	v.winner = s.winner
	v.win_reason = s.win_reason
	if engine.prompt != null:
		v.deciding = engine.prompt.player
		v.deciding_kind = engine.prompt.kind
	v.attack = _attack_summary(engine)
	v.battle_step = s.battle_step
	v.last_attack = _last_attack_summary(engine)
	v.forecasts = engine.attack_forecasts(seat)
	v.grounds = s.grounds.uid if s.grounds != null else -1
	for p in s.players:
		v.players.append(SeatPlayer.of(p, engine))
	for c in engine.all_cards():
		v.cards[c.uid] = SeatCard.of(c, seat)
		if c.zone == &"resolving":
			v.resolving.append(c.uid)
	# A seat choosing among cards may see them, wherever they sit (a search through the Life Deck,
	# a look at the top cards). Only the deciding seat gets this.
	if engine.prompt != null and engine.prompt.player == seat:
		for o in engine.prompt.options:
			if o.card >= 0 and v.cards.has(o.card) and (v.cards[o.card] as SeatCard).hidden():
				v.cards[o.card] = SeatCard.of(engine.card(o.card), seat, true)
		# A search of the Life Deck shows the whole deck, not only the cards that match.
		for uid in engine.prompt.context.get("library", []):
			if v.cards.has(int(uid)) and (v.cards[int(uid)] as SeatCard).hidden():
				v.cards[int(uid)] = SeatCard.of(engine.card(int(uid)), seat, true)
	return v


## The parts of the attack in the air that both players can see.
static func _attack_summary(engine: DuelEngine) -> Dictionary:
	var a: Dictionary = engine.state.attack
	if a.is_empty():
		return {}
	var s: GameState = engine.state
	var out: Dictionary = {
		"kind": str(a.get("kind", "strike")),
		"attacker": int(a.get("attacker", 0)),
		"defender": int(a.get("defender", 1)),
		"focused": bool(a.get("focused", false)),
		"is_final": bool(a.get("is_final", false)),
		"is_power": bool(a.get("is_power", false)),
		"empowered": bool(a.get("empowered", false)),
		"unstoppable": bool(a.get("unstoppable", false)),
		"stops_needed": int(a.get("stops_needed", 1)),
		"stop_count": int(a.get("stop_count", 0)),
		"no_prevent": bool(a.get("no_prevent", false)),
		"stopped": bool(a.get("stopped", false)),
		"source_title": "",
		"performer_title": "",
		# The numbers, step by step: what the table gives, what each card adds, what would land.
		# `landed` once the battle sequence has fixed them (steps 9 and 10 are done); before that
		# they are the forecast the defender is answering.
		"damage": engine.damage_breakdown(a),
		"landed": s.battle_step >= 12 and not bool(a.get("stopped", false)),
		"stages": int(a.get("stages", 0)),
		"life": int(a.get("life", 0)),
		"stages_dealt": int(a.get("stages_dealt", 0)),
		"life_dealt": int(a.get("life_dealt", 0)),
		"life_remaining": int(a.get("life_remaining", 0)),
		"target": int(a.get("target", -1)),
		"stopped_by": a.get("stopped_by", {}),
		"stopped_by_title": _stopper_title(engine, a.get("stopped_by", {})),
		"endurance_prevented": int(a.get("endurance_prevented", 0)),
	}
	var src: CardInstance = engine.card(int(a.get("source", -1)))
	if src != null:
		out["source_title"] = src.def.title
	var performer: CardInstance = engine.card(int(a.get("performer", -1)))
	if performer != null:
		out["performer_title"] = performer.def.title
	return out


## The outcome of the last attack, with titles resolved, so a client can say what happened
## after the attack itself has left the view.
static func _last_attack_summary(engine: DuelEngine) -> Dictionary:
	var la: Dictionary = engine.state.last_attack
	if la.is_empty():
		return {}
	var out: Dictionary = la.duplicate(true)
	out["source_title"] = ""
	out["performer_title"] = ""
	out["target_title"] = ""
	var src: CardInstance = engine.card(int(la.get("source", -1)))
	if src != null:
		out["source_title"] = src.def.title
	var performer: CardInstance = engine.card(int(la.get("performer", -1)))
	if performer != null:
		out["performer_title"] = performer.def.title
	var target: CardInstance = engine.card(int(la.get("target", -1)))
	if target != null:
		out["target_title"] = target.def.title
	out["stopped_by_title"] = _stopper_title(engine, la.get("stopped_by", {}))
	return out


## "Tide Parry", "Dame Alder Rooke's Power", "a Defense Shield", "a standing defense", or "".
static func _stopper_title(engine: DuelEngine, by: Dictionary) -> String:
	var c: CardInstance = engine.card(int(by.get("card", -1)))
	match str(by.get("how", "")):
		"card":
			return c.def.title if c != null else "a card"
		"power":
			return "%s's Power" % (c.def.title if c != null else "a personality")
		"shield":
			return "a Defense Shield"
		"floating":
			return "a standing defense"
	return ""
