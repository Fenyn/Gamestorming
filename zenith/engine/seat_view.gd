class_name SeatView
extends RefCounted
## The duel as one seat is allowed to see it: public standings, every zone as uids, and a card
## table where cards this seat may not see carry only uid and zone. This is the only thing a
## client renders from, so a client never holds information its player could not have.

## Handed to SeatCard for a card that carries no keywords, so the typed array is not rebuilt once
## per card per view.
const NO_TAGS: Array[String] = []

var seat: int = 0
var step: int = GameState.Step.SETUP
var phase: int = GameState.Phase.NONE
var active: int = 0
var attacker: int = 0
var winner: int = -1
var win_reason: String = ""
var points: Array = [0, 0]             # per seat, toward `points_to_win`
var points_to_win: Array = [1, 1]      # per seat, the points that seat needs to win
var deciding: int = -1                # who the pending prompt belongs to, -1 when none
var deciding_kind: StringName = &""
var attack: Dictionary = {}            # public summary of the attack in the air, {} when none
var last_attack: Dictionary = {}       # outcome of the last attack this Combat, {} until one ends
var forecasts: Dictionary = {}         # uid -> damage breakdown for each attack this seat may declare now
var grounds: int = -1
var standing: Array[Dictionary] = []   # effects that outlast the Combat: {owner, source, op, kind, stages, life}
var resolving: Array[int] = []
var pending_card: int = -1             # announced card awaiting a response, before its effects begin
## What resolves next, first element first. This IS an ordering contract: the engine works through
## it in this order, so a client may draw it first to last. Each item is
## {kind: StringName, uid: int, title: String, owner: int, target: int, note: String,
## current: bool}, `kind` one of &"attack", &"pending_card", &"trigger", &"wounds", &"hidden",
## `target` -1 when there is none, and exactly one item carrying `current` when anything is
## pending. A &"hidden" item stands in for a job whose source this seat may not see: it carries
## the owner and nothing else, so the shape of the queue is public and the card is not.
var pending: Array[Dictionary] = []
# A public count from the reference rules, so a client can say "one more pass ends Combat" without
# holding a rule of its own.
var consecutive_passes: int = 0
var players: Array[SeatPlayer] = []
var cards: Dictionary = {}             # uid -> SeatCard


func is_over() -> bool:
	return winner >= 0


func player(i: int) -> SeatPlayer:
	return players[i]


## Live Energy for a personality in play that this seat can see, else -1.
func live_energy(uid: int) -> int:
	var c: SeatCard = card(uid)
	if c == null or c.hidden():
		return -1
	for p in players:
		if p.duelist == uid or p.allies.has(uid):
			return c.energy
	return -1


## The player whose duelist this card is, else null. Faces read Fervor and the other effective
## values from it.
func duelist_owner(uid: int) -> SeatPlayer:
	for p in players:
		if p.duelist == uid:
			return p
	return null


func card(uid: int) -> SeatCard:
	return cards.get(uid)


## The Might `seat` would strike at and the Might it would strike into, read off the two
## personalities in control: (-1, -1) when either is unknown or wild, since a wild matchup never
## reads the Strike Table.
func strike_mights(seat: int, library: CardLibrary) -> Vector2i:
	if seat < 0 or seat >= players.size() or players.size() < 2:
		return Vector2i(-1, -1)
	var other: int = 1 - seat
	for i: int in [seat, other]:
		var c: SeatCard = card(players[i].controlling)
		if c == null or c.hidden():
			return Vector2i(-1, -1)
		var def: CardDef = library.defs.get(c.def_id) if library != null else null
		if def == null or bool(def.aspect_data(c.aspect).get("wild", false)):
			return Vector2i(-1, -1)
	return Vector2i(players[seat].might, players[other].might)


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
	var pend: Array = []
	for item in pending:
		var wire: Dictionary = item.duplicate()
		wire["kind"] = String(item.get("kind", &""))
		pend.append(wire)
	return {
		"pending": pend, "consecutive_passes": consecutive_passes,
		"seat": seat, "step": step, "phase": phase, "active": active, "attacker": attacker,
		"winner": winner, "win_reason": win_reason, "points": points, "points_to_win": points_to_win, "deciding": deciding, "deciding_kind": String(deciding_kind),
		"attack": attack, "last_attack": last_attack, "forecasts": forecasts,
		"grounds": grounds, "standing": standing, "resolving": resolving, "pending_card": pending_card, "players": ps, "cards": cs,
	}


## The forecast for a card this seat could attack with now, {} when there is none.
func forecast(uid: int) -> Dictionary:
	return forecasts.get(uid, forecasts.get(str(uid), {}))


static func from_dict(d: Dictionary) -> SeatView:
	var v: SeatView = SeatView.new()
	v.seat = int(d.get("seat", 0))
	v.step = int(d.get("step", 0))
	v.phase = int(d.get("phase", 0))
	v.active = int(d.get("active", 0))
	v.attacker = int(d.get("attacker", 0))
	v.winner = int(d.get("winner", -1))
	v.win_reason = str(d.get("win_reason", ""))
	var wire_points: Array = d.get("points", [0, 0])
	v.points = [int(wire_points[0]), int(wire_points[1])]
	var wire_to_win: Array = d.get("points_to_win", [1, 1])
	v.points_to_win = [int(wire_to_win[0]), int(wire_to_win[1])]
	v.deciding = int(d.get("deciding", -1))
	v.deciding_kind = StringName(str(d.get("deciding_kind", "")))
	v.attack = d.get("attack", {})
	v.last_attack = d.get("last_attack", {})
	for k in d.get("forecasts", {}).keys():
		v.forecasts[int(k)] = d["forecasts"][k]
	v.grounds = int(d.get("grounds", -1))
	for sd in d.get("standing", []):
		v.standing.append(sd)
	v.resolving = SeatPlayer.ints(d.get("resolving", []))
	v.pending_card = int(d.get("pending_card", -1))
	for item in d.get("pending", []):
		var w: Dictionary = (item as Dictionary)
		v.pending.append({
			"kind": StringName(str(w.get("kind", ""))), "uid": int(w.get("uid", -1)),
			"title": str(w.get("title", "")), "owner": int(w.get("owner", -1)),
			"target": int(w.get("target", -1)), "note": str(w.get("note", "")),
			"current": bool(w.get("current", false)),
		})
	v.consecutive_passes = int(d.get("consecutive_passes", 0))
	for pd in d.get("players", []):
		v.players.append(SeatPlayer.from_dict(pd))
	for cd in d.get("cards", []):
		var c: SeatCard = SeatCard.from_dict(cd)
		v.cards[c.uid] = c
	return v


## `reveal_all` is the full-information view a replay shows: every card's definition and every
## pending job, whoever holds them. A seat's own view never takes it.
static func of(engine: DuelEngine, seat: int, include_forecasts: bool = true, reveal_all: bool = false) -> SeatView:
	var s: GameState = engine.state
	var v: SeatView = SeatView.new()
	v.seat = seat
	v.step = s.step
	v.phase = s.phase
	v.active = s.active
	v.attacker = s.display_attacker()
	v.winner = s.winner
	v.win_reason = s.win_reason
	v.points = [s.points[0], s.points[1]]
	v.points_to_win = [s.points_to_win[0], s.points_to_win[1]]
	# When both seats hold a decision (the Reserve swap), this seat's own comes first.
	var pending: Prompt = engine.prompt_of(seat) if engine.prompt_of(seat) != null else engine.prompt
	if pending != null:
		v.deciding = pending.player
		v.deciding_kind = pending.kind
	v.attack = _attack_summary(engine)
	v.pending_card = int(s.pending_play.get("card", -1))
	for item in engine.pending_items():
		v.pending.append(item.duplicate() if reveal_all else _mask_pending(item, engine, seat))
	v.consecutive_passes = s.consecutive_passes
	v.last_attack = _last_attack_summary(engine)
	if include_forecasts:
		v.forecasts = engine.attack_forecasts(seat)
	v.grounds = s.grounds.uid if s.grounds != null else -1
	# Effects that outlast the Combat have no card left on the table, so the seat is told about
	# them separately and the client stands a ghost of the source card in for them.
	for f in s.floating:
		if str(f.get("duration", "")) != "game":
			continue
		v.standing.append({"owner": int(f.get("owner", -1)), "source": int(f.get("source", -1)),
				"op": str(f.get("op", "")), "kind": str(f.get("kind", "any")),
				"stages": int(f.get("stages", 0)), "life": int(f.get("life", 0))})
	for p in s.players:
		v.players.append(SeatPlayer.of(p, engine))
	for c in engine.all_cards():
		# An announced play is public during its response window even while its physical
		# card remains in hand. Reveal only that card, never the rest of the owner's hand.
		v.cards[c.uid] = SeatCard.of(c, seat, reveal_all or c.uid == v.pending_card, engine.tags_of(c) if c.def.is_personality() else NO_TAGS)
		if c.zone == &"resolving":
			v.resolving.append(c.uid)
	# A seat choosing among cards may see them, wherever they sit (a search through the Life Deck,
	# a look at the top cards). Only the deciding seat gets this.
	var mine: Prompt = engine.prompt_of(seat)
	if mine != null:
		for o in mine.options:
			if o.card >= 0 and v.cards.has(o.card) and (v.cards[o.card] as SeatCard).hidden():
				var shown: CardInstance = engine.card(o.card)
				v.cards[o.card] = SeatCard.of(shown, seat, true, engine.tags_of(shown) if shown.def.is_personality() else NO_TAGS)
		# A search of the Life Deck shows the whole deck, not only the cards that match.
		for uid in mine.context.get("library", []):
			if v.cards.has(int(uid)) and (v.cards[int(uid)] as SeatCard).hidden():
				var in_deck: CardInstance = engine.card(int(uid))
				v.cards[int(uid)] = SeatCard.of(in_deck, seat, true, engine.tags_of(in_deck) if in_deck.def.is_personality() else NO_TAGS)
	return v


## One pending item as this seat may see it, by the same reveal rule as `SeatCard.visible_to`.
## The attack's source and the announced card in its counter window are public from the moment
## they are declared, so only a queued trigger can need masking; a job whose source sits in a
## hidden zone becomes a &"hidden" item that names its owner and nothing else.
static func _mask_pending(item: Dictionary, engine: DuelEngine, seat: int) -> Dictionary:
	var out: Dictionary = item.duplicate()
	if StringName(out.get("kind", &"")) != &"trigger":
		return out
	var uid: int = int(out.get("uid", -1))
	if uid < 0:
		return out   # a job with no card behind it hides nothing
	var c: CardInstance = engine.card(uid)
	if c != null and SeatCard.visible_to(c, seat):
		return out
	return {"kind": &"hidden", "uid": -1, "title": "", "owner": int(out.get("owner", -1)),
			"target": -1, "note": "", "current": bool(out.get("current", false))}


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
		# The card the attack came from, public from the moment it is declared, so a client can
		# put it in front of the defender while they answer it.
		"source": int(a.get("source", -1)),
		"performer": int(a.get("performer", -1)),
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
		"stopped_by_title": stopper_title(engine, a.get("stopped_by", {})),
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
	# The titles were taken when the attack resolved, not read off the cards now: by this point the
	# source may be back in a hidden zone, where a simulation would give it another identity.
	var out: Dictionary = la.duplicate(true)
	out["source_title"] = str(la.get("source_title", ""))
	out["performer_title"] = str(la.get("performer_title", ""))
	out["target_title"] = str(la.get("target_title", ""))
	out["stopped_by_title"] = str(la.get("stopped_by_title", ""))
	return out


## "Tide Parry", "Dame Alder Rooke's Power", "a Defense Shield", "a standing defense", or "".
static func stopper_title(engine: DuelEngine, by: Dictionary) -> String:
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
