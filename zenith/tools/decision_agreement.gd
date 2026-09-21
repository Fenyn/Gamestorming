extends SceneTree
## Which decisions actually need the search. Plays search against search and, at every decision
## with a real choice, also asks two cheap deciders what they would have picked:
##   scorer  - AiScorer.scores, the hand-written one-ply heuristic (~0.03 ms)
##   eval1   - play each option once and score the result with AiEvaluator (~0.7 ms an option)
## Agreement with the search, split by prompt kind and by how far the scorer's favourite led, says
## where search can be skipped. It also counts options that are the same card doing the same thing,
## which the search currently expands separately.
##
## godot --headless --path zenith -s tools/decision_agreement.gd -- --budget=400 --samples=2 --decisions=1500

const PAIRS: Array = [
	["tide_companions", "steel_beatdown"],
	["pyre_beatdown", "storm_volley"],
	["shade_salvage", "root_seals"],
	["steel_heir", "pyre_attrition"],
	["shade_henchmen", "tide_deepwater"],
	["freestyle_swords", "pyre_ascent"],
]
## Fraction of the scorer's best-to-worst spread by which its favourite leads the runner-up.
const MARGIN_BUCKETS: Array[float] = [0.1, 0.3, 0.6, 1.01]


func _init() -> void:
	var budget: int = 400
	var samples: int = 2
	var wanted: int = 1500
	for raw in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2 or not parts[1].is_valid_int():
			continue
		match parts[0]:
			"budget": budget = int(parts[1])
			"samples": samples = int(parts[1])
			"decisions": wanted = int(parts[1])

	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var by_kind: Dictionary = {}     # kind -> {n, options, scorer, eval1, ms, dup_prompts, dup_options}
	var by_margin: Array[Dictionary] = []
	for i in range(MARGIN_BUCKETS.size()):
		by_margin.append({"n": 0, "scorer": 0, "eval1": 0})
	var decisions: int = 0
	var game: int = 0
	var probe_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	probe_rng.seed = 5
	while decisions < wanted:
		var pair: Array = PAIRS[game % PAIRS.size()]
		game += 1
		print("game %d: %s vs %s, %d decisions so far" % [game, pair[0], pair[1], decisions])
		var decks: Array[DeckList] = [DeckList.load_from("res://data/decks/%s.json" % pair[0]),
			DeckList.load_from("res://data/decks/%s.json" % pair[1])]
		var referee: Referee = Referee.new()
		referee.setup(decks, lib, table, 2000 + game, [], false)
		referee.start()
		referee.engine.take_events()
		var players: Array[AiPlayer] = []
		for i in range(2):
			var style: AiProfile = AiProfile.for_deck(decks[i], "default")
			style.merge({"think": {"budget_ms": budget, "samples": samples, "rollout_steps": 0, "predict_depth": 1}})
			players.append(AiPlayer.new(style, 17 * game + i))
		var steps: int = 0
		while not referee.is_over() and steps < 3000 and decisions < wanted:
			steps += 1
			var seat: int = referee.engine.prompt.player
			var real: Prompt = referee.engine.prompt_of(seat)
			var worth_asking: bool = real != null and real.options.size() > 1 and real.kind != &"reserve"
			var scorer_pick: int = -1
			var eval_pick: int = -1
			var margin: float = 0.0
			var base: DuelEngine = null
			if worth_asking:
				var playing: AiProfile = players[seat]._matchup_profile(referee, seat)
				base = referee.sim_for(seat, probe_rng.randi())
				var prompt: Prompt = base.prompt_of(seat)
				var scores: Array[float] = AiScorer.scores(base, playing, seat)
				scorer_pick = _argmax(scores)
				margin = _lead(scores)
				var values: Array[float] = []
				for option in prompt.options:
					var after: DuelEngine = base.clone()
					after.submit(option)
					after.take_events()
					values.append(AiEvaluator.evaluate(after, seat, playing))
				eval_pick = _argmax(values)
			if OS.get_cmdline_user_args().has("--trace"):
				print("  step %d seat %d kind %s options %d" % [steps, seat, real.kind if real != null else &"-",
					real.options.size() if real != null else 0])
			var cmd: Dictionary = players[seat].choose(referee, seat)
			if worth_asking and players[seat].search.metrics.has("tree_nodes"):
				var prompt: Prompt = base.prompt_of(seat)
				var chosen: int = -1
				var wanted_cmd: Command = Command.from_dict(cmd)
				for i in range(prompt.options.size()):
					if prompt.options[i].matches(wanted_cmd):
						chosen = i
				if chosen >= 0:
					decisions += 1
					var kind: String = String(real.kind)
					if not by_kind.has(kind):
						by_kind[kind] = {"n": 0, "options": 0, "scorer": 0, "eval1": 0, "ms": 0,
							"dup_prompts": 0, "dup_options": 0}
					var row: Dictionary = by_kind[kind]
					row["n"] = int(row["n"]) + 1
					row["options"] = int(row["options"]) + prompt.options.size()
					row["ms"] = int(row["ms"]) + int(players[seat].search.metrics.get("elapsed_ms", 0))
					if scorer_pick == chosen:
						row["scorer"] = int(row["scorer"]) + 1
					if eval_pick == chosen:
						row["eval1"] = int(row["eval1"]) + 1
					var dups: int = _duplicates(base, prompt)
					if dups > 0:
						row["dup_prompts"] = int(row["dup_prompts"]) + 1
						row["dup_options"] = int(row["dup_options"]) + dups
					for b in range(MARGIN_BUCKETS.size()):
						if margin < MARGIN_BUCKETS[b]:
							by_margin[b]["n"] = int(by_margin[b]["n"]) + 1
							if scorer_pick == chosen:
								by_margin[b]["scorer"] = int(by_margin[b]["scorer"]) + 1
							if eval_pick == chosen:
								by_margin[b]["eval1"] = int(by_margin[b]["eval1"]) + 1
							break
			referee.submit(seat, cmd)
			referee.engine.take_events()

	print("search at %d ms, %d samples, quiet leaves and predicted depth on" % [budget, samples])
	print("%d decisions with a real choice, %d games" % [decisions, game])
	print("")
	print("%-18s %6s %6s %8s %8s %9s %11s" % ["prompt kind", "n", "opts", "scorer=", "eval1=", "search ms", "has dupes"])
	var kinds: Array = by_kind.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool: return int(by_kind[a]["ms"]) > int(by_kind[b]["ms"]))
	var total_ms: int = 0
	for k in kinds:
		total_ms += int(by_kind[k]["ms"])
	for k in kinds:
		var r: Dictionary = by_kind[k]
		var n: float = float(r["n"])
		print("%-18s %6d %6.1f %7.0f%% %7.0f%% %6.0f %2.0f%% %7.0f%% (%d)" % [k, r["n"], float(r["options"]) / n,
			100.0 * float(r["scorer"]) / n, 100.0 * float(r["eval1"]) / n, float(r["ms"]) / n,
			100.0 * float(r["ms"]) / float(maxi(1, total_ms)), 100.0 * float(r["dup_prompts"]) / n, r["dup_options"]])
	print("")
	print("agreement by how far the scorer's favourite led (share of its best-to-worst spread):")
	var low: float = 0.0
	for b in range(MARGIN_BUCKETS.size()):
		var m: Dictionary = by_margin[b]
		var n: float = float(maxi(1, int(m["n"])))
		print("  lead %.2f-%.2f  n=%4d   scorer agrees %3.0f%%   eval1 agrees %3.0f%%" % [low, minf(1.0, MARGIN_BUCKETS[b]),
			m["n"], 100.0 * float(m["scorer"]) / n, 100.0 * float(m["eval1"]) / n])
		low = MARGIN_BUCKETS[b]
	quit(0)


static func _argmax(values: Array[float]) -> int:
	var best: int = 0
	for i in range(values.size()):
		if values[i] > values[best]:
			best = i
	return best


## How far the favourite leads the runner-up, as a share of the best-to-worst spread.
static func _lead(values: Array[float]) -> float:
	if values.size() < 2:
		return 1.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var spread: float = sorted[sorted.size() - 1] - sorted[0]
	if spread <= 0.0:
		return 0.0
	return (sorted[sorted.size() - 1] - sorted[sorted.size() - 2]) / spread


## Options beyond the first that are the same card definition, from the same zone, doing the same
## thing. Those are the ones the search expands as if they were different moves.
static func _duplicates(sim: DuelEngine, prompt: Prompt) -> int:
	var seen: Dictionary = {}
	var extra: int = 0
	for option in prompt.options:
		var key: String = String(option.type) + "|" + str(option.value)
		if option.card >= 0:
			var c: CardInstance = sim.card(option.card)
			if c != null:
				key += "|" + c.def.id + "|" + String(c.zone)
			else:
				key += "|#" + str(option.card)
		if seen.has(key):
			extra += 1
		else:
			seen[key] = true
	return extra
