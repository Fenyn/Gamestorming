extends SceneTree
## What one AI search node costs. Run before and after any change to `DuelEngine.clone`,
## `PlayerState.copy`, `CardInstance.copy` or `AiEvaluator`; the search pays these per node.
##
## godot --headless --path zenith -s tools/search_cost.gd -- --runs=3000 --steps=60

const DECKS: Array[String] = ["steel_beatdown", "tide_companions"]


func _init() -> void:
	var runs: int = 3000
	var warm_up: int = 60
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

	# Play in with the cheap scorer, so the measured board is a real one.
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

	var cards: int = engine.all_cards().size()
	var life: int = engine.player(0).life_deck.size() + engine.player(1).life_deck.size()
	print("turn %d, %d cards, %d face-down Life Deck; %d runs each" % [engine.state.turn, cards, life, runs])
	print("")
	var clone_us: float = _time(runs, func() -> void: engine.clone())
	var profile: AiProfile = AiProfile.for_deck(decks[0], "hard")
	var eval_us: float = _time(runs, func() -> void: AiEvaluator.evaluate(engine, 0, profile))
	var source: Array[CardInstance] = engine.all_cards()
	var pool: Dictionary = _pool(engine)
	var spare: DuelEngine = engine.clone()
	var pooled_us: float = _time(runs, func() -> void: engine.clone_into(spare))
	print("clone()                          %8.1f us" % clone_us)
	print("clone_into() a recycled engine   %8.1f us   <- what the search pays" % pooled_us)
	print("  CardInstance.copy() calls      %8.1f us" % _time(runs, func() -> void: _copies(source, false)))
	print("  the same, Life Deck shared     %8.1f us" % _time(runs, func() -> void: _copies(source, true)))
	print("  cards_under/attached remap     %8.1f us" % _time(runs, func() -> void: _remap(pool)))
	print("  state.copy() zone remapping    %8.1f us" % _time(runs, func() -> void: engine.state.copy(pool)))
	print("evaluate()                       %8.1f us" % eval_us)
	print("")
	var node_us: float = pooled_us + eval_us
	print("one node %.2f ms: %.0f%% clone, %.0f%% evaluate" % [
		node_us / 1000.0, 100.0 * pooled_us / node_us, 100.0 * eval_us / node_us])
	for budget in [1000, 2000, 4000]:
		print("  a %d ms budget buys about %d nodes" % [budget, int(float(budget) * 1000.0 / node_us)])
	quit(0)


func _time(runs: int, body: Callable) -> float:
	var started: int = Time.get_ticks_usec()
	for i in range(runs):
		body.call()
	return float(Time.get_ticks_usec() - started) / float(runs)


## `shared` prices leaving face-down Life Deck cards uncopied. Not safe as it stands, since a card
## is mutated in place once it leaves the deck; it only sets the ceiling on the idea.
func _copies(source: Array[CardInstance], shared: bool) -> void:
	var out: Dictionary = {}
	for c in source:
		out[c.uid] = c if shared and c.zone == &"life_deck" else c.copy()


func _remap(pool: Dictionary) -> void:
	for uid in pool:
		var c: CardInstance = pool[uid]
		if c.attached_to != null:
			c.attached_to = pool[c.attached_to.uid]
		if c.cards_under.is_empty():
			c.cards_under = [] as Array[CardInstance]
		else:
			c.cards_under = PlayerState._mapped_list(c.cards_under, pool)


func _pool(engine: DuelEngine) -> Dictionary:
	var out: Dictionary = {}
	for c in engine.all_cards():
		out[c.uid] = c.copy()
	return out
