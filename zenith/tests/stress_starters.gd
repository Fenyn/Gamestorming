extends SceneTree
## Plays every starter matchup with random legal commands for a few seeds and reports crashes.
## godot --headless --path zenith -s tests/stress_starters.gd

const SEEDS: Array[int] = [1, 2, 3]
const MAX_STEPS: int = 6000


func _init() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var names: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://data/decks")
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.ends_with(".json"):
			names.append(entry)
		entry = dir.get_next()
	names.sort()
	var games: int = 0
	var unfinished: int = 0
	var reasons: Dictionary = {}
	var prompts: Dictionary = {}
	for a in names:
		for b in names:
			for s in SEEDS:
				var e: DuelEngine = DuelEngine.new()
				var pair: Array[DeckList] = [DeckList.load_from("res://data/decks".path_join(a)), DeckList.load_from("res://data/decks".path_join(b))]
				e.setup(pair, lib, table, s)
				e.start()
				var rng: RandomNumberGenerator = RandomNumberGenerator.new()
				rng.seed = s * 1000 + games
				var guard: int = 0
				while not e.is_over() and guard < MAX_STEPS:
					guard += 1
					prompts[e.prompt.kind] = int(prompts.get(e.prompt.kind, 0)) + 1
					e.submit(e.prompt.options[rng.randi_range(0, e.prompt.options.size() - 1)])
				games += 1
				if e.is_over():
					reasons[e.state.win_reason] = int(reasons.get(e.state.win_reason, 0)) + 1
				else:
					unfinished += 1
					print("UNFINISHED %s vs %s seed %d at turn %d step %d phase %d prompt %s" % [a, b, s, e.state.turn, e.state.step, e.state.phase, e.prompt.describe()])
	print("games %d, unfinished %d, wins %s" % [games, unfinished, str(reasons)])
	print("prompt kinds %s" % str(prompts))
	quit(1 if unfinished > 0 else 0)
