class_name DuelHost
extends RefCounted
## The authority side of a duel: the one Referee, which seats sit in this process and which are
## served over the wire, and the optional AI seat. Hotseat has two local seats, a hosting client
## one local and one remote, a dedicated server two remote. Whoever owns the host feeds it wire
## commands and gets back the updates for its local seats; remote seats' updates and refusals
## go out through the two callables, which `Net` provides.

var referee: Referee = null
var ai: AiPlayer = null
var ai_seat: int = -1
## Per seat, true when that seat plays from another process.
var remote: Array[bool] = [false, false]
## `send(seat: int, update: Dictionary)` for a remote seat's update.
var send: Callable = Callable()
## `reject(seat: int, reason: String)` for a remote seat's refused command.
var reject: Callable = Callable()


func setup(p_referee: Referee, remote_seats: Array[int], p_ai: AiPlayer = null, p_ai_seat: int = -1) -> void:
	referee = p_referee
	remote = [remote_seats.has(0), remote_seats.has(1)]
	ai = p_ai
	ai_seat = p_ai_seat if p_ai != null else -1


func is_remote(seat: int) -> bool:
	return remote[seat]


func has_local_seat() -> bool:
	return not (remote[0] and remote[1])


func seed_value() -> int:
	return referee.seed_value()


func is_over() -> bool:
	return referee.is_over()


## The seat the pending decision belongs to, -1 when the duel is over. With a decision open for
## both seats (the Reserve swap) it is the first one, so a hotseat table serves them in turn.
func deciding() -> int:
	return referee.engine.prompt.player if referee.engine.prompt != null and not referee.is_over() else -1


func view_for(seat: int) -> SeatView:
	return referee.view_for(seat)


func prompt_for(seat: int) -> PromptView:
	return referee.prompt_for(seat)


## Deals the opening and returns every seat's first update, remote ones already sent.
func start() -> Array[SeatUpdate]:
	referee.start()
	return _flush()


## Runs one command for `seat`. Returns "" and the updates (remote ones already sent) when it
## applied; otherwise the reason, which a remote seat also hears through `reject`.
func apply(seat: int, wire: Dictionary) -> Dictionary:
	var problem: String = referee.submit(seat, wire)
	if problem != "":
		if remote[seat] and reject.is_valid():
			reject.call(seat, problem)
		return {"problem": problem, "updates": []}
	return {"problem": "", "updates": _flush()}


## Debug builds: one raw effect for `seat`, then updates as for a command.
func dev(seat: int, effect: Dictionary) -> Dictionary:
	var problem: String = referee.dev({"player": seat, "effect": effect})
	if problem != "":
		return {"problem": problem, "updates": []}
	return {"problem": "", "updates": _flush()}


## Options to fall back on, quietest first: a seat answering by default should not attack or
## spend anything it did not choose to.
const QUIET: Array[StringName] = [&"pass", &"no_defense", &"no_endure", &"no_critical", &"skip",
	&"done", &"no_recover", &"reserve_done", &"discard_all"]


## The AI seat's choice in wire form, or empty. Safe on a worker thread: nothing else may touch
## the referee until it returns.
##
## The AI yields nothing when its search finds no prompt in the world it sampled. Left at that
## the duel stands still forever with no decision on screen and no way to make one, so the host
## answers for it from the prompt's own options rather than letting the table lock up.
func ai_choice() -> Dictionary:
	if ai == null:
		return {}
	var chosen: Dictionary = ai.choose(referee, ai_seat)
	if not chosen.is_empty():
		return chosen
	return fallback_choice(ai_seat)


## One of the seat's own pending options, never a command built by hand. Empty when that seat
## owes no decision, which is the one case where answering nothing is correct.
func fallback_choice(seat: int) -> Dictionary:
	if seat < 0 or referee.is_over():
		return {}
	var p: PromptView = referee.prompt_for(seat)
	if p == null or p.player != seat or p.options.is_empty():
		return {}
	for quiet in QUIET:
		for o in p.options:
			if o.type == quiet:
				return o.to_command(seat).to_dict()
	return p.options[0].to_command(seat).to_dict()


func _flush() -> Array[SeatUpdate]:
	var updates: Array[SeatUpdate] = referee.take_updates()
	for seat in range(mini(2, updates.size())):
		if remote[seat] and send.is_valid():
			send.call(seat, updates[seat].to_dict())
	return updates
