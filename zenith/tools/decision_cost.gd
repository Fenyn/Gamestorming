extends SceneTree
## What a search node costs OUTSIDE clone and evaluate.
##
## `tools/search_cost.gd` prices the node body: one clone plus, at a leaf, one evaluate. It came
## out at 0.66 ms, which at a 1600 ms budget predicts about 2400 nodes. `docs/ai_budget_probe.json`
## measures about 300. This tool prices what the search pays per node that the other tool does not
## see: move ordering, option matching, the perspective switch, and the transposition key.
##
## godot --headless --path zenith -s tools/decision_cost.gd -- --runs=400 --steps=20

const DECKS: Array[String] = ["steel_beatdown", "tide_companions"]


func _init() -> void:
	var runs: int = 400
	var warm_up: int = 20
	for raw in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2 or not parts[1].is_valid_int():
			continue
		if parts[0] == "runs":
			runs = maxi(1, int(parts[1]))
		elif parts[0] == "steps":
			warm_up = maxi(0, int(parts[1]))

	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var decks: Array[DeckList] = []
	for name in DECKS:
		decks.append(DeckList.load_from("res://data/decks/%s.json" % name))
	var referee: Referee = Referee.new()
	referee.setup(decks, lib, table, 12345, [], false)
	referee.start()
	referee.engine.take_events()

	var players: Array[AiPlayer] = []
	for i in range(2):
		var style: AiProfile = AiProfile.for_deck(decks[i], "")
		style.merge({"think": {"search": false}})
		players.append(AiPlayer.new(style, 7 + i))
	var steps: int = 0
	while not referee.is_over() and steps < warm_up:
		steps += 1
		var seat: int = referee.engine.prompt.player
		referee.submit(seat, players[seat].choose(referee, seat))
		referee.engine.take_events()
	var engine: DuelEngine = referee.engine
	if engine.is_over():
		print("the warm-up finished the duel; lower --steps")
		quit(1)
		return

	var seat: int = engine.prompt.player
	var options: int = engine.prompt.options.size()
	var profile: AiProfile = AiProfile.for_deck(decks[seat], "default")
	var tide: AiProfile = AiProfile.for_deck(decks[1], "default")
	print("turn %d, seat %d, %d options in the prompt; %d runs each" % [
		engine.state.turn, seat, options, runs])
	print("")

	var scorer_us: float = _time(runs, func() -> void: AiScorer.scores(engine, profile, seat))
	var first: Command = engine.prompt.options[0]
	var key_us: float = _time(runs, func() -> void: AiObservation.command_key(first))
	var view_us: float = _time(runs, func() -> void: SeatView.of(engine, seat, false))
	var pivot_us: float = _time(runs, func() -> void:
		tide.state_key(SeatView.of(engine, seat, false), seat))
	var perspective: Referee = Referee.new()
	perspective.engine = engine
	var sim_us: float = _time(maxi(1, runs / 10), func() -> void: perspective.sim_for(1 - seat, 7919))
	var state_key_us: float = _time(maxi(1, runs / 10), func() -> void: AiObservation.state_key(engine))
	# Inside the belief sample: the public-view pass over every card, and the seat wrapper.
	var all_us: float = _time(runs, func() -> void: engine.all_cards())
	var seatcards_us: float = _time(runs, func() -> void:
		for card in engine.all_cards():
			SeatCard.of(card, seat, false))
	var seatplayer_us: float = _time(runs, func() -> void:
		SeatPlayer.of(engine.player(1 - seat), engine))
	var reuse: DuelEngine = engine.clone()
	var sim_into_us: float = _time(maxi(1, runs / 10), func() -> void:
		perspective.sim_into(1 - seat, 7919, reuse))
	# Break sim_for into its three parts: the clone, the determinize, and the belief sample.
	var spare: DuelEngine = engine.clone()
	var clone_us: float = _time(maxi(1, runs / 10), func() -> void: engine.clone_into(spare))
	var det_us: float = _time(maxi(1, runs / 10), func() -> void:
		var one: DuelEngine = engine.clone()
		one.determinize(1 - seat, 7919))
	var pooled_det_us: float = _time(maxi(1, runs / 10), func() -> void:
		engine.clone_into(spare)
		spare.determinize(1 - seat, 7919))

	print("AiScorer.scores()                %9.1f us   once per world per node" % scorer_us)
	print("AiObservation.command_key()      %9.1f us   JSON.stringify, twice per option per world" % key_us)
	print("  the same for %2d options x2     %9.1f us" % [options, key_us * options * 2.0])
	print("SeatView.of(include_forecasts=0) %9.1f us   only when a profile has `when`" % view_us)
	print("AiProfile.state_key() with view  %9.1f us   tide_companions is the only profile" % pivot_us)
	print("Referee.sim_for()                %9.1f us   the perspective switch, per opponent node" % sim_us)
	print("AiObservation.state_key()        %9.1f us   the transposition key, `cache` is off" % state_key_us)
	print("  sim_for = clone %.0f + determinize %.0f + belief sample %.0f us" % [
		clone_us, det_us - clone_us, sim_us - det_us])
	print("  the same with a pooled engine:   %9.1f us before the belief sample" % pooled_det_us)
	print("Referee.sim_into() (pooled)      %9.1f us   what the search now calls" % sim_into_us)
	print("  inside the belief sample:")
	print("    all_cards()                  %9.1f us" % all_us)
	print("    SeatCard.of() over every card%9.1f us" % seatcards_us)
	print("    SeatPlayer.of(rival)         %9.1f us" % seatplayer_us)
	print("")

	var ordering: float = scorer_us + key_us * options * 2.0
	print("Move ordering alone costs %.2f ms a node, against 0.66 ms for clone plus evaluate." % (ordering / 1000.0))
	print("With the perspective switch on an opponent node: %.2f ms." % ((ordering + sim_into_us) / 1000.0))
	print("With the tide_companions pivot as well:          %.2f ms." % ((ordering + sim_into_us + pivot_us) / 1000.0))
	quit(0)


func _time(runs: int, body: Callable) -> float:
	var started: int = Time.get_ticks_usec()
	for i in range(runs):
		body.call()
	return float(Time.get_ticks_usec() - started) / float(runs)
