class_name Referee
extends RefCounted
## Holds the one true DuelEngine and speaks to seats only in views. A seat submits a Command in
## wire form; the referee accepts it only if it is the pending prompt's and one of its options,
## then hands each seat a SeatUpdate with what happened and what it may see now.
##
## The same object serves hotseat (one process, both seats), a hosting client (seat 0 local,
## seat 1 over the wire) and later a headless server (both seats over the wire).

var engine: DuelEngine = DuelEngine.new()
var _pending_events: Array[GameEvent] = []


func setup(decks: Array[DeckList], library: CardLibrary, table: StrikeTable, seed_value: int) -> void:
	engine.setup(decks, library, table, seed_value)


func start() -> void:
	engine.start()


func is_over() -> bool:
	return engine.is_over()


func seed_value() -> int:
	return engine.state.seed_value


## "" when applied, otherwise the reason it was refused. Nothing changes on a refusal.
func submit(seat: int, wire: Dictionary) -> String:
	var p: Prompt = engine.prompt
	if p == null or engine.is_over():
		return "Nothing is waiting on a decision."
	if p.player != seat:
		return "It is not your decision."
	var cmd: Command = Command.from_dict(wire)
	if cmd.player != seat:
		return "That command belongs to another seat."
	var accepted: Command = p.accept(cmd)
	if accepted == null:
		return "That choice is not open right now."
	engine.submit(accepted)
	return ""


## Dev tool: {"player": seat, "effect": {...}}. Only the process holding the engine can call it.
func dev(wire: Dictionary) -> String:
	if engine.is_over():
		return "The duel is over."
	return engine.dev_effect(int(wire.get("player", 0)), wire.get("effect", {}))


## The updates owed to both seats since the last call, index by seat.
func take_updates() -> Array[SeatUpdate]:
	var events: Array[GameEvent] = engine.take_events()
	var out: Array[SeatUpdate] = []
	for seat in range(2):
		var u: SeatUpdate = SeatUpdate.new()
		# Lines are worded per seat: a card this seat may not see is never named in its log.
		for ev in events:
			var line: String = CardText.event_line(ev, engine, seat)
			u.lines.append({"type": String(ev.type), "player": int(ev.data.get("player", -1)), "line": line})
		u.view = view_for(seat)
		u.prompt = prompt_for(seat)
		out.append(u)
	return out


func view_for(seat: int) -> SeatView:
	return SeatView.of(engine, seat)


## The pending prompt when it is this seat's, else null.
func prompt_for(seat: int) -> PromptView:
	if engine.prompt == null or engine.prompt.player != seat:
		return null
	return PromptView.of(engine.prompt, engine)
