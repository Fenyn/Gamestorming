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
var grounds: int = -1
var resolving: Array[int] = []
var players: Array[SeatPlayer] = []
var cards: Dictionary = {}             # uid -> SeatCard


func is_over() -> bool:
	return winner >= 0


func player(i: int) -> SeatPlayer:
	return players[i]


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
		"attack": attack, "grounds": grounds, "resolving": resolving, "players": ps, "cards": cs,
	}


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
	v.grounds = s.grounds.uid if s.grounds != null else -1
	for p in s.players:
		v.players.append(SeatPlayer.of(p))
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
	return v


## The parts of the attack in the air that both players can see.
static func _attack_summary(engine: DuelEngine) -> Dictionary:
	var a: Dictionary = engine.state.attack
	if a.is_empty():
		return {}
	var out: Dictionary = {
		"kind": str(a.get("kind", "strike")),
		"focused": bool(a.get("focused", false)),
		"is_final": bool(a.get("is_final", false)),
		"is_power": bool(a.get("is_power", false)),
		"unstoppable": bool(a.get("unstoppable", false)),
		"stops_needed": int(a.get("stops_needed", 1)),
		"no_prevent": bool(a.get("no_prevent", false)),
		"source_title": "",
		"performer_title": "",
	}
	var src: CardInstance = engine.card(int(a.get("source", -1)))
	if src != null:
		out["source_title"] = src.def.title
	var performer: CardInstance = engine.card(int(a.get("performer", -1)))
	if performer != null:
		out["performer_title"] = performer.def.title
	return out
