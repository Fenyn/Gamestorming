extends SceneTree
## Integration checks for shipped difficulty profiles, simulation seats and Session/DuelHost.

var checks: int = 0
var failures: int = 0


func _init() -> void:
	var session: Node = load("res://scripts/autoload/session.gd").new()
	session.call("_ready")
	var decks: Array[DeckList] = session.get("decks")
	_check(not decks.is_empty(), "Session loads shipped decks")
	for deck in decks:
		for level in ["", "default", "easy", "hard"]:
			var profile: AiProfile = AiProfile.for_deck(deck, level)
			_check(_sequence(profile), "%s / %s routes to sequence planning" % [deck.name, level])
	_check(int(AiProfile.for_deck(decks[0], "easy").data["think"]["budget_ms"]) < int(AiProfile.for_deck(decks[0], "hard").data["think"]["budget_ms"]), "Easy retains a smaller planning budget than Hard")
	_test_sim_seat(decks[0])
	var chosen: Array[DeckList] = [decks[0], decks[1]]
	session.set("chosen", chosen)
	session.set("seed_value", 773)
	_check(session.call("build_ai") == null, "Session without AI seat keeps human play")
	for level in ["default", "easy", "hard"]:
		_test_host(session, level)
	session.free()
	print("AI routing: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _sequence(profile: AiProfile) -> bool:
	return profile.searches() and str(profile.data["think"].get("algorithm", "")) == "sequence"


func _test_sim_seat(deck: DeckList) -> void:
	_check(_sequence(SimSeat.new().make_player(deck, 17).profile), "Bare SimSeat defaults to planner")
	# Use the actual harness specification; loading its Script does not instantiate its runner.
	var runner: Script = load("res://tests/matchlab.gd")
	var specification: Dictionary = runner.get_script_constant_map()["SPEC_BASE"]
	var defaults: SimArgs = SimArgs.parse(specification, PackedStringArray())
	_check(defaults.error.is_empty(), "Matchlab defaults parse")
	var default_seat: SimSeat = SimSeat.from_args(defaults, "a")
	_check(default_seat.error.is_empty() and _sequence(default_seat.make_player(deck, 17).profile), "Matchlab default side routes through planner")
	for policy in ["search", "scorer", "rollout", "easy", "default", "hard", "random"]:
		var args: SimArgs = SimArgs.parse(specification, PackedStringArray(["--policy=" + policy]))
		var seat: SimSeat = SimSeat.from_args(args, "a")
		_check(args.error.is_empty() and seat.error.is_empty(), "Explicit %s policy parses" % policy)
		var player: AiPlayer = seat.make_player(deck, 19)
		if policy == "random":
			_check(player == null, "Explicit random policy stays random")
		elif policy == "scorer":
			_check(not player.profile.searches(), "Explicit scorer remains available")
		elif policy == "rollout":
			_check(player.profile.searches() and player.profile.data["think"]["algorithm"] == "rollout", "Explicit historical rollout remains available")
		else:
			_check(_sequence(player.profile), "Explicit %s uses sequence planner" % policy)


func _test_host(session: Node, level: String) -> void:
	session.set("ai_profile", level)
	var referee: Referee = session.call("build_referee")
	referee.start()
	# Reserve uses its dedicated pregame selection heuristic; move to a live game prompt.
	for attempt in range(4):
		if referee.engine.prompt.kind != &"reserve":
			break
		var done: Command = null
		for option in referee.engine.prompt.options:
			if option.type == &"reserve_done":
				done = option
		if done == null:
			_check(false, "Reserve offers its completion command")
			return
		_check(referee.submit(done.player, done.to_dict()).is_empty(), "Reserve completes legally")
		referee.engine.take_events()
	_check(referee.engine.prompt.kind != &"reserve", "Live prompt reached")
	var seat: int = referee.engine.prompt.player
	session.set("ai_seat", seat)
	var player: AiPlayer = session.call("build_ai")
	_check(_sequence(player.profile), "Session %s builds a planner" % level)
	player.profile.merge({"think": {"budget_ms": 1, "samples": 1, "node_budget": 30}})
	var host: DuelHost = DuelHost.new()
	var remote: Array[int] = []
	host.setup(referee, remote, player, seat)
	var before: Array = [referee.view_for(0).to_dict(), referee.view_for(1).to_dict(), referee.prompt_for(seat).to_dict()]
	var command: Dictionary = host.ai_choice()
	_check(player.search.metrics.get("algorithm", "") == "sequence", "Session -> DuelHost -> AiPlayer actually invokes sequence for " + level)
	_check(before == [referee.view_for(0).to_dict(), referee.view_for(1).to_dict(), referee.prompt_for(seat).to_dict()], "Planning preserves authoritative state for " + level)
	var legal: bool = false
	for option in referee.engine.prompt.options:
		if option.to_dict() == command:
			legal = true
	_check(legal, "Planner returns an offered command for " + level)
	_check(str(host.apply(seat, command)["problem"]).is_empty(), "Host accepts planner command for " + level)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
