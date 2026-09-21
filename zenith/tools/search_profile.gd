extends SceneTree
## Where a real search decision spends its time. Plays search against search on shipped decks and
## sums the counters AiSearch keeps in `metrics`, so the split is measured inside actual play
## rather than priced one operation at a time the way search_cost.gd and decision_cost.gd do.
##
## godot --headless --path zenith -s tools/search_profile.gd -- --budget=150 --samples=1 --decisions=300

const PAIRS: Array = [
	["steel_beatdown", "tide_companions"],
	["pyre_beatdown", "storm_volley"],
	["shade_salvage", "root_seals"],
]
const SUMMED: Array[String] = [
	"elapsed_ms", "nodes", "tree_nodes", "rollout_nodes", "rollout_leaves", "rollout_usec",
	"scores_calls", "forced_scores", "switches", "switch_usec", "scorer_usec", "clone_usec",
	"eval_usec", "evals", "discarded_usec", "completed_depth",
]


func _init() -> void:
	var budget: int = 150
	var samples: int = 1
	var wanted: int = 300
	var think: Dictionary = {}
	for raw in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2 or not parts[1].is_valid_int():
			continue
		match parts[0]:
			"budget": budget = int(parts[1])
			"samples": samples = int(parts[1])
			"decisions": wanted = int(parts[1])
			"rollout-steps": think["rollout_steps"] = int(parts[1])
			"settle-steps": think["settle_steps"] = int(parts[1])
			"settle-plies": think["settle_plies"] = int(parts[1])
			"predict-depth": think["predict_depth"] = int(parts[1])
	think["budget_ms"] = budget
	think["samples"] = samples

	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var sums: Dictionary = {}
	for key in SUMMED:
		sums[key] = 0
	var depths: Dictionary = {}
	var cutoffs: Dictionary = {}
	var decisions: int = 0
	var game: int = 0
	while decisions < wanted:
		var pair: Array = PAIRS[game % PAIRS.size()]
		game += 1
		var decks: Array[DeckList] = [DeckList.load_from("res://data/decks/%s.json" % pair[0]),
			DeckList.load_from("res://data/decks/%s.json" % pair[1])]
		var referee: Referee = Referee.new()
		referee.setup(decks, lib, table, 1000 + game, [], false)
		referee.start()
		referee.engine.take_events()
		var players: Array[AiPlayer] = []
		for i in range(2):
			var style: AiProfile = AiProfile.for_deck(decks[i], "default")
			style.merge({"think": think.duplicate()})
			players.append(AiPlayer.new(style, 31 * game + i))
		var steps: int = 0
		while not referee.is_over() and steps < 3000 and decisions < wanted:
			steps += 1
			var seat: int = referee.engine.prompt.player
			var cmd: Dictionary = players[seat].choose(referee, seat)
			var m: Dictionary = players[seat].search.metrics
			if m.has("tree_nodes") and int(m.get("completed_depth", 0)) >= 0 and int(m.get("elapsed_ms", 0)) > 0:
				decisions += 1
				for key in SUMMED:
					sums[key] = int(sums[key]) + int(m.get(key, 0))
				var d: int = int(m.get("completed_depth", 0))
				depths[d] = int(depths.get(d, 0)) + 1
				var c: String = str(m.get("cutoff", "")) if str(m.get("cutoff", "")) != "" else "completed"
				cutoffs[c] = int(cutoffs.get(c, 0)) + 1
			referee.submit(seat, cmd)
			referee.engine.take_events()

	var n: float = float(maxi(1, decisions))
	var elapsed_us: float = float(sums["elapsed_ms"]) * 1000.0
	print("think %s: %d searched decisions over %d games" % [str(think), decisions, game])
	print("")
	print("per decision:")
	print("  elapsed                    %8.1f ms" % (float(sums["elapsed_ms"]) / n))
	print("  tree nodes                 %8.1f" % (float(sums["tree_nodes"]) / n))
	print("  playout nodes              %8.1f   (%.0f%% of all nodes)" % [float(sums["rollout_nodes"]) / n,
		100.0 * float(sums["rollout_nodes"]) / float(maxi(1, int(sums["nodes"])))])
	print("  leaves played out          %8.1f   (%.1f steps each)" % [float(sums["rollout_leaves"]) / n,
		float(sums["rollout_nodes"]) / float(maxi(1, int(sums["rollout_leaves"])))])
	print("  scoring calls              %8.1f   (%.0f%% on a prompt with one option)" % [float(sums["scores_calls"]) / n,
		100.0 * float(sums["forced_scores"]) / float(maxi(1, int(sums["scores_calls"])))])
	print("  perspective switches       %8.1f" % (float(sums["switches"]) / n))
	print("")
	print("share of elapsed time:")
	for row in [["inside leaf playouts", "rollout_usec"], ["perspective switches", "switch_usec"],
			["AiScorer.scores", "scorer_usec"], ["clones", "clone_usec"], ["evaluate", "eval_usec"],
			["depth thrown away on timeout", "discarded_usec"]]:
		print("  %-30s %5.1f%%" % [row[0], 100.0 * float(sums[row[1]]) / maxf(1.0, elapsed_us)])
	print("  (the rows overlap: playouts contain switches, scoring, clones and evaluates)")
	print("")
	var ds: Array = depths.keys()
	ds.sort()
	var dline: PackedStringArray = PackedStringArray()
	for d in ds:
		dline.append("%d: %d" % [d, depths[d]])
	print("completed depth: " + ", ".join(dline))
	print("stopped by: " + str(cutoffs))
	quit(0)
