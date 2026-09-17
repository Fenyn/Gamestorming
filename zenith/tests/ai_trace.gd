extends SceneTree
## Plays one AI game and tallies what seat 0 did, to see how a playstyle profile behaves.
## godot --headless --path zenith -s tests/ai_trace.gd -- --deck=tide_companions --foe=ember_beatdown --seed=100 --budget=100
## Prints seat 0's command types, the events it caused, and a per-turn line of the table.


func _init() -> void:
	var args: Dictionary = {"deck": "tide_companions", "foe": "ember_beatdown", "seed": "100", "budget": "100", "log-turn": "-1"}
	for raw in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var decks: Array[DeckList] = [DeckList.load_from("res://data/decks/%s.json" % args["deck"]), DeckList.load_from("res://data/decks/%s.json" % args["foe"])]
	var ref: Referee = Referee.new()
	ref.setup(decks, lib, StrikeTable.load_from("res://data/strike_table.json"), int(args["seed"]))
	ref.start()
	var mine: AiProfile = AiProfile.for_deck(decks[0], "")
	# `--samples=N` with a large budget makes a run repeatable: the search stops on count, not time.
	mine.merge({"think": {"budget_ms": int(args["budget"])}})
	if args.has("samples"):
		mine.merge({"think": {"samples": int(args["samples"]), "budget_ms": 600000}})
	var theirs: AiProfile = AiProfile.for_deck(decks[1], "")
	theirs.merge({"think": {"search": false}})
	var players: Array[AiPlayer] = [AiPlayer.new(mine, 1), AiPlayer.new(theirs, 2)]
	var commands: Dictionary = {}
	var events: Dictionary = {}
	var turn: int = -1
	var steps: int = 0
	while not ref.is_over() and steps < 6000:
		steps += 1
		var e: DuelEngine = ref.engine
		if e.state.turn != turn:
			turn = e.state.turn
			var p: PlayerState = e.player(0)
			var q: PlayerState = e.player(1)
			print("turn %d active %d | me life %d hand %d vigor %d tier %d acclaim %d allies %d | foe life %d vigor %d tier %d acclaim %d" % [turn, e.state.active, p.life_deck.size(), p.hand.size(), p.fighter.vigor, p.fighter.tier, p.acclaim, p.allies().size(), q.life_deck.size(), q.fighter.vigor, q.fighter.tier, q.acclaim])
		var seat: int = e.prompt.player
		var wire: Dictionary = players[seat].choose(ref, seat)
		if seat == 0:
			var key: String = "%s:%s" % [e.prompt.kind, wire.get("type", "")]
			commands[key] = int(commands.get(key, 0)) + 1
		ref.submit(seat, wire)
		for ev in e.take_events():
			# `--log-turn=N` prints every log line of that turn, as seat 0 would read it.
			if e.state.turn == int(args["log-turn"]) or turn == int(args["log-turn"]):
				var line: String = CardText.event_line(ev, e, 0)
				if line != "":
					print("    ", line)
			if int(ev.data.get("player", -1)) == 0:
				events[ev.type] = int(events.get(ev.type, 0)) + 1
	print("winner %d by %s after %d steps" % [ref.engine.state.winner, ref.engine.state.win_reason, steps])
	print("seat 0 commands: %s" % str(commands))
	print("seat 0 events: %s" % str(events))
	quit(0)
