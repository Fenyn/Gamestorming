extends SceneTree
## Paired sequence-search treatment against the current scorer baseline. Each pair shares
## engine and per-seat AI seeds; wall-clock search budgets still permit timing variation.
## --targets=steel_heir,pyre_ascent,tide_companions,shade_salvage --opponents=deck,...
## --seeds=1 --seed=1 --budget=400 --samples=2 --report=res://reports/comparison.json
## --resume reuses only completed matches, with identical configuration and input hashes.

const MAX_STEPS: int = 6000
var config: Dictionary = {}
var report: Dictionary = {}
var output_path: String = ""
var failure: String = ""
var deck_snapshot: Dictionary = {}
var profile_snapshot: Dictionary = {}


func _init() -> void:
	var args: Dictionary = {"targets": "steel_heir,pyre_ascent,tide_companions,shade_salvage", "opponents": "", "seeds": "1", "seed": "1", "budget": "400", "samples": "2", "report": "res://reports/deck_ai_comparison.json", "resume": false}
	var seen: Dictionary = {}
	for raw in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.trim_prefix("--").split("=", true, 1)
		var key: String = parts[0]
		if not raw.begins_with("--") or not args.has(key) or seen.has(key) or (key == "resume" and parts.size() != 1) or (key != "resume" and parts.size() != 2):
			_fail("Invalid or duplicate argument: " + raw)
			return
		seen[key] = true
		args[key] = true if key == "resume" else parts[1]
	for key in ["seeds", "seed", "budget", "samples"]:
		var value: String = str(args[key])
		if not value.is_valid_int() or int(value) < 1 or int(value) > 2147483647:
			_fail("--%s must be an integer from 1 to 2147483647" % key)
			return
	var available: Array[String] = []
	for file in DirAccess.get_files_at("res://data/decks"):
		if file.ends_with(".json"):
			available.append(file.trim_suffix(".json"))
	available.sort()
	var targets: Array[String] = _deck_list(str(args["targets"]), available)
	var opponents: Array[String] = available if str(args["opponents"]) == "" else _deck_list(str(args["opponents"]), available)
	if not failure.is_empty() or targets.is_empty() or opponents.is_empty():
		_fail(failure if not failure.is_empty() else "Deck lists cannot be empty")
		return
	for target in targets:
		if opponents.size() == 1 and opponents[0] == target:
			_fail("No other opponent supplied for " + target)
			return
	output_path = ProjectSettings.globalize_path(str(args["report"]))
	if not output_path.is_absolute_path() or not output_path.ends_with(".json"):
		_fail("--report must be an absolute or res:// JSON path")
		return
	config = {"targets": targets, "opponents": opponents, "seeds": int(args["seeds"]), "seed": int(args["seed"]), "budget_ms": int(args["budget"]), "samples": int(args["samples"]), "max_steps": MAX_STEPS}
	# Normalize JSON number/array types so a saved configuration compares identically.
	config = JSON.parse_string(JSON.stringify(config))
	var hashes: Dictionary = _input_hashes()
	report = {"version": 1, "config": config, "input_sha256": hashes, "matches": [], "status": "running", "note": "Baseline is the current scorer without sequence search; paired seeds do not guarantee identical random draws after policies diverge."}
	report["godot_version"] = Engine.get_version_info()["string"]
	if bool(args["resume"]):
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(output_path))
		if not loaded is Dictionary or loaded.get("version", 0) != 1 or loaded.get("config", {}) != config or loaded.get("input_sha256", {}) != hashes or not loaded.get("matches", null) is Array:
			_fail("Resume report is invalid or its configuration/input hashes differ")
			return
		report = loaded
	elif FileAccess.file_exists(output_path):
		_fail("Report already exists; use --resume or another path")
		return
	var schedule: Array[Dictionary] = _schedule(targets, opponents)
	var completed: Dictionary = {}
	for match_result in report["matches"]:
		if not match_result is Dictionary or not match_result.has("id") or completed.has(str(match_result["id"])):
			_fail("Resume contains malformed or duplicate matches")
			return
		var index: int = int(match_result.get("schedule_index", -1))
		if index < 0 or index >= schedule.size() or str(match_result["id"]) != str(schedule[index]["id"]):
			_fail("Resume match does not belong to this schedule")
			return
		if str(match_result.get("status", "")) == "complete":
			for field in schedule[index]:
				if not match_result.has(field) or match_result[field] != JSON.parse_string(JSON.stringify(schedule[index][field])):
					_fail("Resume match schedule metadata differs: " + str(field))
					return
			if not match_result.get("target_won", null) is bool or int(match_result.get("winner_seat", -1)) not in [0, 1] or bool(match_result["target_won"]) != (int(match_result["winner_seat"]) == int(match_result["target_seat"])) or not match_result.get("seat_statistics", null) is Array:
				_fail("Resume match has invalid outcome/statistics")
				return
			completed[str(match_result["id"])] = true
	# Failed attempts are retried, not counted as completed games.
	var retained: Array = []
	for match_result in report["matches"]:
		if completed.has(str(match_result["id"])):
			retained.append(match_result)
	report["matches"] = retained
	report["status"] = "running"
	report.erase("error")
	report["expected_matches"] = schedule.size()
	if not _save():
		quit(1)
		return
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	for name in available:
		var deck: DeckList = DeckList.load_from("res://data/decks/%s.json" % name)
		deck_snapshot[name] = deck
		profile_snapshot[name] = AiProfile.for_deck(deck, "").data.duplicate(true)
	for entry in schedule:
		if completed.has(str(entry["id"])):
			continue
		# Refuse to silently mix changing assets or AI implementations into one experiment.
		if _input_hashes() != hashes:
			report["status"] = "aborted"
			report["error"] = "Input files changed during benchmark"
			_save()
			_fail(str(report["error"]))
			return
		var result: Dictionary = _play(entry, lib, table)
		if _input_hashes() != hashes:
			result["status"] = "invalid"
			result["error"] = "Input files changed during match"
		(report["matches"] as Array).append(result)
		if result["status"] != "complete":
			report["status"] = "aborted"
			report["error"] = result["error"]
		if not _save():
			quit(1)
			return
		print("%d/%d %s: %s, target win %s, %d decisions" % [(report["matches"] as Array).size(), schedule.size(), entry["id"], result["status"], result.get("target_won", false), result["steps"]])
		if result["status"] != "complete":
			_fail(str(result["error"]))
			return
	report["status"] = "complete"
	if not _save():
		quit(1)
		return
	print(JSON.stringify(report["by_deck"]))
	quit(0)


func _deck_list(raw: String, available: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for name in raw.split(",", true):
		if not available.has(name) or result.has(name):
			failure = "Unknown, empty, or duplicate deck: " + name
			return []
		result.append(name)
	return result


func _schedule(targets: Array[String], opponents: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(config["seed"])
	for target in targets:
		for opponent in opponents:
			if target == opponent:
				continue
			for seed_index in range(int(config["seeds"])):
				for seat in range(2):
					var pair_id: String = "%s/%s/%d/%d" % [target, opponent, seed_index, seat]
					var engine_seed: int = rng.randi()
					var seat_seeds: Array[int] = [rng.randi(), rng.randi()]
					for policy in ["baseline", "treatment"]:
						result.append({"id": pair_id + "/" + policy, "pair_id": pair_id, "schedule_index": result.size(), "target": target, "opponent": opponent, "target_seat": seat, "seed_index": seed_index, "engine_seed": engine_seed, "seat_seeds": seat_seeds, "arm": policy})
	return result


func _play(entry: Dictionary, lib: CardLibrary, table: StrikeTable) -> Dictionary:
	var result: Dictionary = entry.duplicate(true)
	var decks: Array[DeckList] = [null, null]
	var target_seat: int = int(entry["target_seat"])
	decks[target_seat] = deck_snapshot[entry["target"]]
	decks[1 - target_seat] = deck_snapshot[entry["opponent"]]
	var players: Array[AiPlayer] = []
	var policies: Array[String] = []
	var statistics: Array[Dictionary] = []
	for seat in range(2):
		var searching: bool = seat == target_seat and entry["arm"] == "treatment"
		var profile: AiProfile = AiProfile.new()
		profile.data = profile_snapshot[entry["target"] if seat == target_seat else entry["opponent"]].duplicate(true)
		profile.merge({"think": {"search": searching, "algorithm": "sequence", "budget_ms": config["budget_ms"], "samples": config["samples"]}})
		players.append(AiPlayer.new(profile, int(entry["seat_seeds"][seat])))
		policies.append("search" if searching else "scorer")
		statistics.append({"decisions": 0, "total_usec": 0, "max_usec": 0, "timings_ms": [], "search_decisions": 0, "branching_decisions": 0, "completed_depth_total": 0, "max_completed_depth": 0, "fallbacks": 0, "stop_reasons": {}})
	var ref: Referee = Referee.new()
	ref.setup(decks, lib, table, int(entry["engine_seed"]), [], false)
	ref.start()
	ref.engine.take_events()
	var steps: int = 0
	var problem: String = ""
	while not ref.is_over() and steps < MAX_STEPS:
		if ref.engine.prompt == null or ref.engine.prompt.options.is_empty():
			problem = "Missing or empty prompt"
			break
		var seat: int = ref.engine.prompt.player
		if seat < 0 or seat > 1:
			problem = "Invalid prompt seat"
			break
		var start: int = Time.get_ticks_usec()
		var wire: Dictionary = players[seat].choose(ref, seat)
		var usec: int = Time.get_ticks_usec() - start
		var stats: Dictionary = statistics[seat]
		stats["decisions"] += 1
		stats["total_usec"] += usec
		stats["max_usec"] = maxi(int(stats["max_usec"]), usec)
		(stats["timings_ms"] as Array).append(usec / 1000.0)
		var metrics: Dictionary = players[seat].search.metrics
		if metrics.get("algorithm", "") == "sequence":
			var depth: int = int(metrics.get("completed_depth", 0))
			stats["search_decisions"] += 1
			stats["completed_depth_total"] += depth
			stats["max_completed_depth"] = maxi(int(stats["max_completed_depth"]), depth)
			if ref.engine.prompt.options.size() > 1:
				stats["branching_decisions"] += 1
			if depth == 0 and ref.engine.prompt.options.size() > 1:
				stats["fallbacks"] += 1
			var reason: String = str(metrics.get("cutoff", ""))
			if reason.is_empty():
				reason = "completed"
			stats["stop_reasons"][reason] = int(stats["stop_reasons"].get(reason, 0)) + 1
		steps += 1
		problem = ref.submit(seat, wire)
		ref.engine.take_events()
		if not problem.is_empty():
			result["invalid_command"] = wire
			break
	if problem.is_empty() and not ref.is_over():
		problem = "Unfinished after %d decisions" % MAX_STEPS
	if problem.is_empty() and ref.engine.state.winner not in [0, 1]:
		problem = "Terminal match has invalid winner"
	for stats in statistics:
		var timing: Array = stats["timings_ms"]
		timing.sort()
		stats["median_ms"] = _percentile(timing, 0.5)
		stats["p95_ms"] = _percentile(timing, 0.95)
		stats["mean_ms"] = float(stats["total_usec"]) / 1000.0 / maxi(1, int(stats["decisions"]))
		stats["mean_completed_depth"] = float(stats["completed_depth_total"]) / maxi(1, int(stats["search_decisions"]))
		stats["branching_mean_completed_depth"] = float(stats["completed_depth_total"]) / maxi(1, int(stats["branching_decisions"]))
		stats.erase("timings_ms")
	result.merge({"status": "complete" if problem.is_empty() else "invalid", "error": problem, "steps": steps, "turn": ref.engine.state.turn, "winner_seat": ref.engine.state.winner, "target_won": problem.is_empty() and ref.engine.state.winner == target_seat, "win_reason": str(ref.engine.state.win_reason), "policies": policies, "seat_statistics": statistics})
	return result


func _percentile(sorted: Array, fraction: float) -> float:
	return float(sorted[mini(sorted.size() - 1, int(ceil(fraction * sorted.size())) - 1)]) if not sorted.is_empty() else 0.0


func _input_hashes() -> Dictionary:
	var paths: Array[String] = ["res://tests/deck_ai_comparison.gd", "res://project.godot"]
	for folder in ["res://ai", "res://engine", "res://data"]:
		_collect_inputs(folder, paths)
	paths.sort()
	var result: Dictionary = {}
	for path in paths:
		result[path] = FileAccess.get_sha256(path)
	return result


func _collect_inputs(folder: String, paths: Array[String]) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd") or file.ends_with(".json"):
			paths.append(folder.path_join(file))
	for child in DirAccess.get_directories_at(folder):
		_collect_inputs(folder.path_join(child), paths)


func _save() -> bool:
	var pairs: Dictionary = {}
	var by_deck: Dictionary = {}
	for target in config["targets"]:
		by_deck[target] = {"completed_pairs": 0, "baseline_wins": 0, "search_wins": 0, "gained_wins": 0, "lost_wins": 0, "both_won": 0, "both_lost": 0, "net_wins": 0}
	for match_result in report["matches"]:
		if match_result["status"] != "complete":
			continue
		var pair_id: String = str(match_result["pair_id"])
		if not pairs.has(pair_id):
			pairs[pair_id] = {}
		pairs[pair_id][match_result["arm"]] = match_result
	for pair in pairs.values():
		if not pair.has("baseline") or not pair.has("treatment"):
			continue
		var stats: Dictionary = by_deck[pair["baseline"]["target"]]
		var before: bool = bool(pair["baseline"]["target_won"])
		var after: bool = bool(pair["treatment"]["target_won"])
		stats["completed_pairs"] += 1
		stats["baseline_wins"] += int(before)
		stats["search_wins"] += int(after)
		stats["gained_wins"] += int(after and not before)
		stats["lost_wins"] += int(before and not after)
		stats["both_won"] += int(before and after)
		stats["both_lost"] += int(not before and not after)
		stats["net_wins"] = int(stats["search_wins"]) - int(stats["baseline_wins"])
	report["by_deck"] = by_deck
	report["updated_unix"] = Time.get_unix_time_from_system()
	var folder_error: Error = DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if folder_error != OK:
		_fail("Cannot create report directory: %s" % error_string(folder_error))
		return false
	var temporary: String = output_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write report: " + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		_fail("Cannot flush report: " + error_string(write_error))
		return false
	var rename_error: Error = DirAccess.rename_absolute(temporary, output_path)
	if rename_error != OK:
		_fail("Cannot replace report: " + error_string(rename_error))
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
