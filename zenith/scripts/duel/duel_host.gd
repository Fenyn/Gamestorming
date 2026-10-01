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
## This duel's record when the owner keeps one: the owner fills the header before `start`, each
## accepted entry lands in it stamped with ms since the deal, and the result is filled the moment
## the rules end the duel or `end` is called, whichever comes first.
var record: MatchRecord = null
## `on_result(record: MatchRecord)`, once per duel. For a rules finish it runs inside the command
## that ended the duel, before any update carrying the result goes out.
var on_result: Callable = Callable()
## Server rooms set this before `start`: every decision then runs on a `DuelClock`, and `tick`
## ends the duel for a seat whose time is gone.
var use_clock: bool = false
var clock: DuelClock = null
## `clock_out(seat: int, left_ms: int, bank_ms: int, phase: String)`: a seat's clock for both
## players, on every change of phase and at least once a second while it runs.
var clock_out: Callable = Callable()
## `timed_out(winner: int, reason: String)`, once, after the record of a duel lost on the clock is
## written. `winner` is -1 when both clocks ran out at the same moment.
var timed_out: Callable = Callable()
const CLOCK_RESEND_MS: int = 750
## Per seat: that player's connection dropped and the server keeps the seat for them. Their clock
## runs on, and a clock that runs out while they are away loses with "left".
var away: Array[bool] = [false, false]
var _clock_prompt: Array[Prompt] = [null, null]   # the decision each seat's clock is running for
var _clock_sent: Array[Dictionary] = [{}, {}]      # per seat: the phase last sent and when
var _paused: Array[Dictionary] = [{}, {}]          # per seat while both are away: its clock state at the pause
var _timed_out: bool = false
var _dealt_msec: int = 0


func setup(p_referee: Referee, remote_seats: Array[int], p_ai: AiPlayer = null, p_ai_seat: int = -1) -> void:
	referee = p_referee
	remote = [remote_seats.has(0), remote_seats.has(1)]
	ai = p_ai
	ai_seat = p_ai_seat if p_ai != null else -1
	referee.command_applied.connect(_on_command_applied)


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


## Deals the opening and returns every seat's first update, remote ones already sent. A referee
## already moved on by `Referee.replay` keeps its place, and its replayed entries go into the
## record stamped 0, since when they were first played is not known here.
func start() -> Array[SeatUpdate]:
	_dealt_msec = Time.get_ticks_msec()
	if record != null:
		record.started = int(Time.get_unix_time_from_system())
		for entry in referee.history:
			record.add_command(entry, 0)
	if use_clock:
		clock = DuelClock.new()
	referee.start()
	return _flush()


## The duel ended outside the rules: a concession, or a seat that left. Only the first result
## stands, so this does nothing once the rules or an earlier call have ended it. A duel ended
## before `start`, a ranked game its match was left before, lasted no time.
func end(winner: int, reason: String) -> void:
	if record != null and not record.has_result():
		if _dealt_msec == 0:
			_dealt_msec = Time.get_ticks_msec()
		_settle(winner, reason)


func _on_command_applied(_seat: int, entry: Dictionary) -> void:
	if record == null or record.has_result():
		return
	record.add_command(entry, Time.get_ticks_msec() - _dealt_msec)
	if referee.is_over():
		_settle(referee.engine.state.winner, referee.engine.state.win_reason)


func _settle(winner: int, reason: String) -> void:
	record.finish(winner, reason, referee.engine, Time.get_ticks_msec() - _dealt_msec)
	if on_result.is_valid():
		on_result.call(record)


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


## A scripted duel's board adjustment (`Referee.script`), then updates as for a command.
func script(op: Dictionary) -> Dictionary:
	var problem: String = referee.script(op)
	if problem != "":
		return {"problem": problem, "updates": []}
	return {"problem": "", "updates": _flush()}


## Options to fall back on, quietest first: a seat answering by default should not attack or
## spend anything it did not choose to.
const QUIET: Array[StringName] = [&"pass", &"no_defense", &"no_endure", &"no_critical", &"skip",
	&"done", &"no_recover", &"reserve_done", &"discard_all", &"decline", &"pick_none"]


## A copy of the referee for the AI to think on from a worker thread, so the live one is never
## read while the table submits to it. Main thread only.
func ai_snapshot() -> Referee:
	var copy: Referee = Referee.new()
	copy.engine = referee.engine.clone()
	return copy


## The AI seat's choice in wire form, or empty when it yields nothing (its search found no prompt
## in the world it sampled). `on` is the live referee by default, or an `ai_snapshot` from a worker
## thread. The caller answers an empty result with `fallback_choice` on the main thread, which
## also covers a search that failed, since that returns nothing either.
func ai_choice(on: Referee = null) -> Dictionary:
	if ai == null:
		return {}
	return ai.choose(on if on != null else referee, ai_seat)


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
	_sync_clock(updates, Time.get_ticks_msec())
	return updates


# --- Decision clocks (server rooms) -----------------------------------------

## The seat's decision panel is up (`Net._rpc_prompt_shown`), so its clock starts now instead of
## at the end of its grace. Only for the decision the seat owes, by kind.
func prompt_shown(seat: int, kind: String, now_msec: int) -> void:
	if clock == null or seat < 0 or seat > 1 or _clock_prompt[seat] == null or String(_clock_prompt[seat].kind) != kind:
		return
	clock.shown(seat, now_msec)
	_publish_clock(now_msec)


## Every 250 ms from the server: starts clocks whose grace is over, keeps both players' countdowns
## current, and ends the duel the moment a seat's timer and bank are both gone. The earlier
## deadline loses; an exact tie has no winner.
func tick(now_msec: int) -> void:
	if clock == null or _timed_out or referee.is_over():
		return
	var gone: Array[int] = clock.tick(now_msec)
	if gone.is_empty():
		_publish_clock(now_msec)
		return
	_timed_out = true
	var winner: int = 1 - gone[0]
	var reason: String = _out_of_time_reason(gone[0])
	if gone.size() == 2 and clock.out_at(0) == clock.out_at(1):
		winner = -1
		reason = "abandoned"
	end(winner, reason)
	if timed_out.is_valid():
		timed_out.call(winner, reason)


## Why a seat whose time is gone loses: "timeout" while it is connected, "left" while it is away.
func _out_of_time_reason(seat: int) -> String:
	return "left" if away[seat] else "timeout"


## Both players are away, so nobody is kept waiting: both clocks stop where they stand.
func pause_clocks(now_msec: int) -> void:
	if clock == null:
		return
	for seat in range(2):
		_paused[seat] = clock.state(seat, now_msec)
		clock.stop(seat, now_msec)


## The first player back after both were away: each clock goes on from where `pause_clocks` left it.
## A decision whose clock had not started yet gets its grace again.
func resume_clocks(now_msec: int) -> void:
	if clock == null:
		return
	for seat in range(2):
		var p: Prompt = _clock_prompt[seat]
		var was: Dictionary = _paused[seat]
		_paused[seat] = {}
		if p == null or was.is_empty():
			continue
		var context: Dictionary = _clock_context(p)
		if str(was["phase"]) == DuelClock.OFF:
			clock.arm(seat, p.kind, context, now_msec)
		else:
			# Started as far in the past as its timer had already run, so it ends `left_ms` from now.
			var length: int = DuelClock.decision_ms(p.kind, context)
			clock.start(seat, p.kind, context, now_msec - (length - int(was["left_ms"])))
	_publish_clock(now_msec)


## A remote seat back after its connection dropped: one update with its view, its prompt and this
## turn's log lines (`Referee.catch_up`), then both clocks sent again.
func catch_up(seat: int, now_msec: int) -> void:
	if remote[seat] and send.is_valid():
		send.call(seat, referee.catch_up(seat).to_dict())
	if clock != null:
		_clock_sent = [{}, {}]
		_publish_clock(now_msec)


## After each flush: a seat whose decision was answered stops its clock, a seat whose own turn
## began banks more time, and a seat that owes a new decision arms its clock. A decision still
## open, the other seat's half of a Reserve swap or Discard step, keeps running.
func _sync_clock(updates: Array[SeatUpdate], now_msec: int) -> void:
	if clock == null:
		return
	var changed: Array[bool] = [false, false]
	for seat in range(2):
		var p: Prompt = null if referee.is_over() else referee.engine.prompt_of(seat)
		changed[seat] = p != _clock_prompt[seat]
		if changed[seat]:
			clock.stop(seat, now_msec)
			_clock_prompt[seat] = p
	if not updates.is_empty():
		for line in updates[0].lines:
			if str(line.get("type", "")) == "turn_start":
				clock.bank_turn(int(line.get("player", -1)), now_msec)
	for seat in range(2):
		var p: Prompt = _clock_prompt[seat]
		if changed[seat] and p != null:
			clock.arm(seat, p.kind, _clock_context(p), now_msec)
	_publish_clock(now_msec)


## What `DuelClock.decision_ms` reads off a prompt.
static func _clock_context(p: Prompt) -> Dictionary:
	var context: Dictionary = {"batch_max": p.batch_max}
	if p.context.has("library"):
		context["library"] = true
	return context


func _publish_clock(now_msec: int) -> void:
	for seat in range(2):
		var state: Dictionary = clock.state(seat, now_msec)
		var phase: String = str(state["phase"])
		var last: Dictionary = _clock_sent[seat]
		if phase == str(last.get("phase", DuelClock.OFF)) \
				and (phase == DuelClock.OFF or now_msec - int(last.get("at", 0)) < CLOCK_RESEND_MS):
			continue
		_clock_sent[seat] = {"phase": phase, "at": now_msec}
		if clock_out.is_valid():
			clock_out.call(seat, int(state["left_ms"]), int(state["bank_ms"]), phase)
