extends SceneTree
## The adventure bench: one starter, many whole runs, played duel by duel across the node map until
## the run is won or dies. The path is picked at random at every fork and rewards are taken at
## random from what the run is offered, so the numbers say what an average unguided run reaches
## rather than what a perfect one does. "Stage" in the report is the duel number: stage 1 is the
## run's first duel, whichever node it was.
##
## It answers "how far does this starter get", "which stage kills runs" and "which opponents beat
## it", which matchlab cannot: matchlab plays one duel at a time and never carries a deck forward.
##
##   godot --headless --path zenith -s tests/adventure_lab.gd -- --starter=pyre_beatdown_start --runs=20
##   godot --headless --path zenith -s tests/adventure_lab.gd -- --starter=storm_volley_start \
##       --runs=40 --policy=scorer --tsv=res://reports/storm_runs.tsv
##
## The player plays `--policy` (the scorer by default; the sequence planner is too slow for eight
## staged duels a run). Each opponent plays the profile its ladder row names unless
## `--opponent-policy` overrides it. Unknown flags are an error, as in matchlab.
## The player plays `--policy` (the scorer by default); each opponent plays the ai_level its map
## node names.

const SPEC: Dictionary = {
	"starter": {"type": "str", "default": ""},
	"runs": {"type": "int", "default": 10, "min": 1, "max": 100000},
	"seed": {"type": "int", "default": 1, "min": 0, "max": 2147483647},
	"policy": {"type": "str", "default": "scorer"},
	"opponent-policy": {"type": "str", "default": ""},
	"lives": {"type": "bool", "default": "on"},
	"max-steps": {"type": "int", "default": 6000, "min": 100, "max": 1000000},
	"tsv": {"type": "str", "default": ""},
	"json": {"type": "str", "default": ""},
	"verbose": {"type": "bool", "default": "off"},
	"progress": {"type": "int", "default": 0, "min": 0, "max": 1000000},
}

## A run that somehow never leaves a status is cut off here rather than hanging the bench.
const MAX_STEPS_PER_RUN: int = 200

var library: CardLibrary = null
var table: StrikeTable = null
var runner: SimMatch = null
var player_side: SimSeat = null
var use_lives: bool = true
var verbose: bool = false
var opponent_sides: Dictionary = {}   # policy name -> SimSeat

var stage_rows: Array[Dictionary] = []
var run_rows: Array[Dictionary] = []


func _init() -> void:
	var args: SimArgs = SimArgs.parse(SPEC, OS.get_cmdline_user_args())
	if not args.error.is_empty():
		_fail(args.error)
		return

	var starter: String = args.str_of("starter").strip_edges()
	var starters: Array[String] = AdventureDecks.playable_starters()
	if starter.is_empty() or not starters.has(starter):
		_fail("--starter must name a deck under %s. Known starters: %s" % [
			AdventureDecks.STARTERS_DIR, ", ".join(PackedStringArray(starters))])
		return

	player_side = SimSeat.from_legacy(args.str_of("policy"), {}, true)
	if not player_side.error.is_empty():
		_fail("--policy: %s" % player_side.error)
		return
	var opponent_policy: String = args.str_of("opponent-policy").strip_edges()
	if not opponent_policy.is_empty():
		var problem: String = SimSeat.policy_error(opponent_policy)
		if not problem.is_empty():
			_fail("--opponent-policy: %s" % problem)
			return

	library = CardLibrary.new()
	library.load_dir("res://data/cards")
	table = StrikeTable.load_from("res://data/strike_table.json")
	runner = SimMatch.make(library, table, args.int_of("max-steps"))
	use_lives = args.bool_of("lives")
	verbose = args.bool_of("verbose")

	var runs: int = args.int_of("runs")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = args.int_of("seed")
	if AdventureMap.generate(starter, 1) == null:
		_fail("No map for starter '%s'" % starter)
		return

	print("adventure_lab: %s, %d runs" % [starter, runs])
	print("  player   : %s" % player_side.describe())
	print("  opponents: %s" % (opponent_policy if not opponent_policy.is_empty() else "the ai_level of each map node"))
	print("  rule     : %s" % ("lives, player %d / opponent %d / boss %d" % [
		AdventureRules.PLAYER_LIVES, AdventureRules.OPPONENT_LIVES, AdventureRules.BOSS_LIVES]
		if use_lives else "symmetric first to 2"))
	print("  map      : random path at every fork")
	print("  flags    : %s" % args.describe_given())

	var started: int = Time.get_ticks_msec()
	var progress: int = args.int_of("progress")
	for index in range(runs):
		var run_seed: int = rng.randi_range(1, 2147483646)
		run_rows.append(_play_run(index, starter, run_seed, opponent_policy))
		if progress > 0 and (index + 1) % progress == 0:
			var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
			print("  %d/%d runs, %.0fs elapsed" % [index + 1, runs, elapsed])

	_report(starter, float(Time.get_ticks_msec() - started) / 1000.0)

	var wrote: bool = true
	if not args.str_of("tsv").is_empty():
		wrote = _write_tsv(ProjectSettings.globalize_path(args.str_of("tsv"))) and wrote
	if not args.str_of("json").is_empty():
		wrote = _write_json(ProjectSettings.globalize_path(args.str_of("json")), args, starter) and wrote
	quit(0 if wrote else 1)


func _fail(message: String) -> void:
	push_error(message)
	print("adventure_lab: %s" % message)
	quit(2)


# --- One run ----------------------------------------------------------------


## Plays one whole run and returns its summary row; the per-stage rows go into `stage_rows`.
func _play_run(index: int, starter: String, run_seed: int, opponent_policy: String) -> Dictionary:
	var run: AdventureRun = AdventureRun.begin(starter, run_seed)
	var map: AdventureMap = AdventureMap.generate(starter, run_seed)
	if run == null or map == null:
		return {"run": index, "status": "broken", "cleared": 0, "motes": 0,
			"error": "could not begin a run for %s" % starter, "deck": 0, "picks": []}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = run_seed
	var motes: int = 0
	var cleared: int = 0
	var error: String = ""
	var taken: Array[String] = []   # bundle ids taken so far, for the "did it help" credit
	var mana_earned: int = 0
	var mana_spent: int = 0
	var shops: int = 0
	var guard: int = 0
	while run.status in ["map", "stage", "forge", "shop", "relic", "reserve", "aspect", "reward"] and guard < MAX_STEPS_PER_RUN:
		guard += 1
		match run.status:
			"map":
				var next: Array[String] = run.choices(map)
				if next.is_empty():
					error = "no way on from %s" % run.node_id
					break
				run.enter(map, next[rng.randi_range(0, next.size() - 1)])
			"forge":
				_visit_forge(run, rng)
			"shop":
				shops += 1
				mana_spent += _visit_shop(run)
			"relic", "reserve":
				_visit_relic(run, rng)
			"stage":
				var row: Dictionary = map.duel_for(run.node_id)
				var record: Dictionary = _play_stage(index, run, map, row, opponent_policy, taken.duplicate())
				if not str(record["error"]).is_empty():
					error = str(record["error"])
					stage_rows.append(record)
					if verbose:
						print("  run %d stage %d: FAILED %s" % [index + 1, run.stage + 1, error])
					return {"run": index, "status": "broken", "cleared": cleared, "motes": motes,
						"error": error, "deck": run.cards.size(), "picks": run.picks.duplicate(true)}
				var won: bool = bool(record["won"])
				var mana_before: int = run.mana
				var payout: int = AdventureRewards.finish_stage(run, map, library, won)
				mana_earned += run.mana - mana_before
				motes += payout
				record["motes"] = payout
				if won:
					cleared += 1
				stage_rows.append(record)
				if verbose:
					print("  run %d stage %d vs %-26s %s by %-9s turn %2d  %d-%d" % [
						index + 1, int(record["stage"]), str(record["opponent"]),
						"win " if won else "loss", str(record["reason"]), int(record["turn"]),
						int(record["player_points"]), int(record["rival_points"])])
			"aspect":
				var aspects: Array[String] = run.pending_aspects
				if not aspects.is_empty():
					AdventureRewards.apply_aspect(run, library, aspects[rng.randi_range(0, aspects.size() - 1)])
				AdventureRewards.finish_aspect(run, map, library)
			"reward":
				var offer: Array[String] = run.pending_offer
				var took: String = ""
				if not offer.is_empty():
					took = offer[rng.randi_range(0, offer.size() - 1)]
					if not AdventureRewards.apply_bundle(run, library, took):
						took = ""
				if took.is_empty():
					AdventureRewards.apply_skip(run)
				else:
					taken.append(took)
				_credit_pick(index, took)
				motes += AdventureRewards.finish_reward(run, map)
	return {
		"run": index, "status": run.status if error.is_empty() else "broken", "cleared": cleared,
		"motes": motes, "error": error, "reached": map.place_of(run.node_id),
		"deck": run.cards.size(), "aspects": run.aspects(), "picks": run.picks.duplicate(true),
		"seed": run_seed, "mana_earned": mana_earned, "mana_spent": mana_spent, "mana_left": run.mana,
		"shops": shops,
	}


## A Shop visit: buy the cheapest card the run can afford and legally add, again until none is left,
## then leave. Returns the Mana spent.
func _visit_shop(run: AdventureRun) -> int:
	AdventureShop.open(run, library)
	var before: int = run.mana
	var stock: Array[String] = AdventureShop.stock(run)
	var guard: int = 0
	while guard < stock.size():
		guard += 1
		var best: int = -1
		for slot in range(stock.size()):
			if AdventureShop.slot_block(run, library, slot) != "":
				continue
			if best < 0 or AdventureShop.price(library, stock[slot]) < AdventureShop.price(library, stock[best]):
				best = slot
		if best < 0 or not AdventureShop.buy(run, library, best):
			break
	AdventureShop.leave(run)
	return before - run.mana


## The Relic node: a random offer, or the held Relic kept as often as any one offer is taken, then
## the last Reserve cards set aside until the Reserve fits.
func _visit_relic(run: AdventureRun, rng: RandomNumberGenerator) -> void:
	if run.status == "relic":
		AdventureRelic.open(run, library)
		var choices: int = run.relic_offers.size() + (1 if run.relic_id != "" else 0)
		var pick: int = rng.randi_range(0, maxi(0, choices - 1))
		if pick >= run.relic_offers.size() or not AdventureRelic.take(run, library, pick):
			AdventureRelic.pass_through(run, library)
	if run.status == "reserve":
		AdventureRelic.pass_through(run, library)


## A Forge visit: half the time a copy of a random eligible card, otherwise a cut of the cheapest
## card by settlement price, the nearest thing to "the weakest" the run has. Falls back to the other
## action, then to leaving, when one is closed.
func _visit_forge(run: AdventureRun, rng: RandomNumberGenerator) -> void:
	var options: Array[String] = AdventureForge.copy_options(run, library)
	var copy_first: bool = rng.randf() < 0.5
	if copy_first and not options.is_empty():
		AdventureForge.copy(run, library, options[rng.randi_range(0, options.size() - 1)])
		return
	if AdventureRewards.can_cut(run) and AdventureForge.cut(run, library, _cheapest(run)):
		return
	if not options.is_empty():
		AdventureForge.copy(run, library, options[rng.randi_range(0, options.size() - 1)])
		return
	AdventureForge.leave(run)


func _cheapest(run: AdventureRun) -> String:
	var best: String = ""
	var best_price: int = 0
	for id in run.cards:
		var price: int = AdventureEconomy.price(library.defs[id])
		if best == "" or price < best_price or (price == best_price and id < best):
			best = id
			best_price = price
	return best


## Attaches the bundle (or the skip) to the stage row that was just played, so a TSV reader sees
## what the run took after each fight.
func _credit_pick(index: int, bundle_id: String) -> void:
	for i in range(stage_rows.size() - 1, -1, -1):
		var row: Dictionary = stage_rows[i]
		if int(row["run"]) == index:
			row["took"] = bundle_id if not bundle_id.is_empty() else "(skip)"
			return


## One map duel. The player is seat 0 and side a throughout, so `distance[0]` is always theirs.
func _play_stage(index: int, run: AdventureRun, map: AdventureMap, row: Dictionary,
		opponent_policy: String, held: Array[String]) -> Dictionary:
	var opponent_id: String = str(row.get("opponent", ""))
	var player_deck: DeckList = run.deck()
	var opponent_deck: DeckList = DeckList.resolve(opponent_id)
	var here: Dictionary = map.node(run.node_id)
	var record: Dictionary = {
		"run": index, "stage": run.stage + 1, "opponent": opponent_id,
		"act": int(here.get("act", 0)), "map_tier": int(here.get("tier", 0)),
		"node": str(row.get("node", "")),
		"family": AdventureDecks.family_of(opponent_id), "tier": str(row.get("tier", "")),
		"band": str(row.get("band", "")), "ai_level": str(row.get("ai_level", "default")),
		"won": false, "reason": "", "turn": 0, "steps": 0,
		"player_points": 0, "rival_points": 0, "player_life": 0, "rival_life": 0,
		"deck": player_deck.cards.size() if player_deck != null else 0,
		"aspects": run.aspects(), "took": "", "motes": 0, "held": held, "error": "",
	}
	if player_deck == null or opponent_deck == null:
		record["error"] = "could not resolve %s" % (opponent_id if opponent_deck == null else run.starter_id)
		return record
	var opponent_side: SimSeat = _opponent_side(
		opponent_policy if not opponent_policy.is_empty() else str(row.get("ai_level", "default")))
	if opponent_side == null:
		record["error"] = "no AI side for '%s'" % str(row.get("ai_level", "default"))
		return record

	var no_lives: Array[int] = []
	runner.points_to_win = 1 if use_lives else 2
	runner.lives = AdventureRules.lives_for(row) if use_lives else no_lives
	var base: int = run.stage_seed(run.stage)
	var seeds: Array[int] = [base, base + 1, base + 2, base + 3]
	var result: Dictionary = runner.play(player_deck, opponent_deck, 0, player_side, opponent_side, seeds)
	if not bool(result["ok"]):
		record["error"] = str(result["error"])
		return record
	record["won"] = bool(result["a_won"])
	record["reason"] = str(result["reason"])
	record["turn"] = int(result["turn"])
	record["steps"] = int(result["steps"])
	var points: Array = result["points"]
	record["player_points"] = int(points[0])
	record["rival_points"] = int(points[1])
	var distance: Array = result["distance"]
	record["player_life"] = int((distance[0] as Dictionary).get("survival", 0))
	record["rival_life"] = int((distance[1] as Dictionary).get("survival", 0))
	return record


## The AI side for a policy name, built once and reused. Null when the name will not load.
func _opponent_side(policy: String) -> SimSeat:
	if opponent_sides.has(policy):
		return opponent_sides[policy]
	var side: SimSeat = SimSeat.from_legacy(policy, {}, true)
	if not side.error.is_empty():
		push_error("adventure_lab: %s" % side.error)
		opponent_sides[policy] = null
		return null
	opponent_sides[policy] = side
	return side


# --- Report -----------------------------------------------------------------


func _report(starter: String, seconds: float) -> void:
	print("")
	print("=== adventure_lab: %s, %.0fs ===" % [starter, seconds])
	_survival_table()
	_act_table()
	_run_summary()
	_reward_summary()
	_opponent_summary()


## The highest duel number any run reached.
func _longest() -> int:
	var most: int = 0
	for row in stage_rows:
		most = maxi(most, int(row["stage"]))
	return most


func _survival_table() -> void:
	print("")
	print("Survival, one line per duel number:")
	print("  %-5s %7s %5s %-22s %6s  %-28s %s" % [
		"stage", "reached", "wins", "win rate (95% Wilson)", "turns", "losses by route", "lost to"])
	for n in range(1, _longest() + 1):
		var reached: int = 0
		var wins: int = 0
		var turns: int = 0
		var routes: Dictionary = {}
		var families: Dictionary = {}
		for row in stage_rows:
			if int(row["stage"]) != n or not str(row["error"]).is_empty():
				continue
			reached += 1
			turns += int(row["turn"])
			if bool(row["won"]):
				wins += 1
			else:
				var reason: String = str(row["reason"])
				routes[reason] = int(routes.get(reason, 0)) + 1
				var family: String = str(row["family"])
				families[family] = int(families.get(family, 0)) + 1
		if reached == 0:
			continue
		var bounds: Array[float] = SimReport.wilson(wins, reached)
		print("  %-5d %7d %5d %5.1f%% (%5.1f-%5.1f) %6.1f  %-28s %s" % [
			n, reached, wins, 100.0 * float(wins) / float(reached), 100.0 * bounds[0], 100.0 * bounds[1],
			float(turns) / float(reached), _counts(routes, 3), _counts(families, 3)])


## One line per act and node type: how often it was fought and won.
func _act_table() -> void:
	var tally: Dictionary = {}   # "act N node" -> [wins, played]
	for row in stage_rows:
		if not str(row["error"]).is_empty():
			continue
		var key: String = "act %d %s" % [int(row.get("act", 0)), str(row.get("node", ""))]
		var entry: Array = tally.get(key, [0, 0])
		entry[1] = int(entry[1]) + 1
		if bool(row["won"]):
			entry[0] = int(entry[0]) + 1
		tally[key] = entry
	var keys: Array = tally.keys()
	keys.sort()
	print("")
	print("By act and node:")
	for key in keys:
		var entry: Array = tally[key]
		print("  %-16s fought %4d   won %5.1f%%" % [str(key), int(entry[1]), 100.0 * _rate(entry)])


func _run_summary() -> void:
	var won: int = 0
	var broken: int = 0
	var first_error: String = ""
	var cleared_total: int = 0
	var motes_total: int = 0
	var mana_earned: int = 0
	var mana_spent: int = 0
	var mana_left: int = 0
	var shops: int = 0
	var deaths: Array[int] = []
	for row in run_rows:
		cleared_total += int(row["cleared"])
		motes_total += int(row["motes"])
		mana_earned += int(row.get("mana_earned", 0))
		mana_spent += int(row.get("mana_spent", 0))
		mana_left += int(row.get("mana_left", 0))
		shops += int(row.get("shops", 0))
		match str(row["status"]):
			"won":
				won += 1
			"broken":
				broken += 1
				if first_error.is_empty():
					first_error = str(row["error"])
			_:
				deaths.append(int(row["cleared"]) + 1)
	deaths.sort()
	var runs: int = run_rows.size()
	print("")
	print("Runs: %d, won %d (%.0f%%), died %d, broken %d" % [
		runs, won, 100.0 * float(won) / float(maxi(1, runs)), deaths.size(), broken])
	print("  mean duels won      : %.2f" % [float(cleared_total) / float(maxi(1, runs))])
	var reached: Dictionary = {}
	for row in run_rows:
		var place: String = str(row.get("reached", ""))
		var act_word: String = place.substr(0, place.find(",")) if place.find(",") > 0 else place
		reached[act_word] = int(reached.get(act_word, 0)) + 1
	print("  where runs ended    : %s" % _counts(reached, 8))
	print("  median stage of death: %s" % (
		"%d" % int(deaths[deaths.size() / 2]) if not deaths.is_empty() else "-"))
	print("  mean Motes          : %.0f" % [float(motes_total) / float(maxi(1, runs))])
	var per_run: float = float(maxi(1, runs))
	print("  mean Mana           : %d at the start, %.0f earned, %.0f spent over %.1f Shops, %.0f left at the end" % [
		AdventureEconomy.mana_start(), float(mana_earned) / per_run, float(mana_spent) / per_run,
		float(shops) / per_run, float(mana_left) / per_run])
	if broken > 0:
		print("  first error         : %s" % first_error)


func _reward_summary() -> void:
	var picked: Dictionary = {}     # bundle id -> times taken
	var after: Dictionary = {}      # bundle id -> [wins, played] of stages played while held
	var aspects: int = 0
	var skips: int = 0
	var cuts: int = 0
	var copies: int = 0
	var bought: int = 0
	for row in run_rows:
		for entry in row.get("picks", []):
			var kind: String = str((entry as Dictionary).get("kind", ""))
			if kind == AdventureShop.KIND_BUY:
				bought += 1
			elif kind == "aspect":
				aspects += 1
			elif kind == "skip":
				skips += 1
			elif kind == AdventureForge.ACTION_CUT:
				cuts += 1
			elif kind == AdventureForge.ACTION_COPY:
				copies += 1
	for row in stage_rows:
		if not str(row["error"]).is_empty():
			continue
		for id in row["held"]:
			var tally: Array = after.get(str(id), [0, 0])
			tally[1] = int(tally[1]) + 1
			if bool(row["won"]):
				tally[0] = int(tally[0]) + 1
			after[str(id)] = tally
		if str(row["took"]) != "" and str(row["took"]) != "(skip)":
			picked[str(row["took"])] = int(picked.get(str(row["took"]), 0)) + 1
	print("")
	print("Forge: %d cuts, %d copies." % [cuts, copies])
	print("Shop: %d cards bought, the cheapest affordable each time." % bought)
	print("Rewards: %d Aspect picks, %d skipped offers. The win rate is the stages played after" % [aspects, skips])
	print("taking the bundle, over every run that took it, which is rough: a bundle taken late is")
	print("credited with fewer and harder stages than one taken early.")
	var ids: Array = picked.keys()
	ids.sort()
	for id in ids:
		var tally: Array = after.get(str(id), [0, 0])
		var played: int = int(tally[1])
		print("  %-34s taken %2d   after: %2d/%-3d %s" % [
			str(id), int(picked[id]), int(tally[0]), played,
			"%5.1f%%" % (100.0 * float(int(tally[0])) / float(played)) if played > 0 else "    -"])


func _opponent_summary() -> void:
	var tally: Dictionary = {}      # opponent id -> [wins, played]
	for row in stage_rows:
		if not str(row["error"]).is_empty():
			continue
		var id: String = str(row["opponent"])
		var entry: Array = tally.get(id, [0, 0])
		entry[1] = int(entry[1]) + 1
		if bool(row["won"]):
			entry[0] = int(entry[0]) + 1
		tally[id] = entry
	var ids: Array = tally.keys()
	ids.sort_custom(func(x: Variant, y: Variant) -> bool:
		return _rate(tally[x]) < _rate(tally[y]))
	print("")
	print("Opponents faced, worst matchup first:")
	for id in ids:
		var entry: Array = tally[id]
		print("  %-30s faced %3d   player wins %5.1f%%" % [
			str(id), int(entry[1]), 100.0 * _rate(entry)])


static func _rate(entry: Array) -> float:
	return float(int(entry[0])) / float(maxi(1, int(entry[1])))


## The top `limit` counts of a tally, largest first, as "a 3, b 1".
static func _counts(counts: Dictionary, limit: int) -> String:
	var keys: Array = counts.keys()
	keys.sort_custom(func(x: Variant, y: Variant) -> bool:
		return int(counts[x]) > int(counts[y]))
	var parts: PackedStringArray = PackedStringArray()
	for key in keys:
		if parts.size() >= limit:
			break
		parts.append("%s %d" % [str(key), int(counts[key])])
	return ", ".join(parts) if not parts.is_empty() else "-"


# --- Files ------------------------------------------------------------------


const TSV_COLUMNS: Array[String] = ["run", "stage", "act", "map_tier", "node", "opponent", "family", "tier", "band",
	"ai_level", "won", "reason", "turn", "steps", "player_points", "rival_points",
	"player_life", "rival_life", "deck", "aspects", "took", "motes", "error"]


func _write_tsv(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("adventure_lab: cannot write %s" % path)
		return false
	file.store_line("\t".join(PackedStringArray(TSV_COLUMNS)))
	for row in stage_rows:
		var out: PackedStringArray = PackedStringArray()
		for key in TSV_COLUMNS:
			out.append(str(row.get(key, "")))
		file.store_line("\t".join(out))
	file.close()
	print("wrote %s" % path)
	return true


func _write_json(path: String, args: SimArgs, starter: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("adventure_lab: cannot write %s" % path)
		return false
	file.store_string(JSON.stringify({
		"config": args.to_dict(),
		"starter": starter,
		"player_side": player_side.to_dict(),
		"stages": stage_rows,
		"runs": run_rows,
	}, "  "))
	file.close()
	print("wrote %s" % path)
	return true
