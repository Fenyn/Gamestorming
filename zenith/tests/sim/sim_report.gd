class_name SimReport
extends RefCounted
## Folds match results into per-deck records, a matchup grid and per-side timing, then prints them
## and optionally writes a TSV of every match and a JSON summary.
##
## Win rates carry a 95% Wilson interval. That is the number to read when asking whether a balance
## change did anything: at 100 matches a 55% win rate spans roughly 45-64%, so it is not yet a
## result. Widen `--repeats` or `--games` until the intervals stop overlapping.

const REASONS: Array[String] = SimMatch.REASONS
const SIDE_NAMES: Array[String] = ["a", "b"]
## 95% two-sided normal quantile, for the Wilson interval.
const Z: float = 1.959964

var side_rows: Array[Dictionary] = [{}, {}]   # side -> deck name -> record
var matchup: Dictionary = {}                  # "a_deck|b_deck" -> [a wins, played]
var side_wins: Array[int] = [0, 0]
var side_timing: Array[Dictionary] = [SimMatch.blank_timing(), SimMatch.blank_timing()]
var tsv_rows: Array[String] = []
var games: int = 0
var failures: int = 0
var failure_notes: Array[String] = []


func add(result: Dictionary, a_deck: String, b_deck: String) -> void:
	games += 1
	for side in range(2):
		_fold_timing(side_timing[side], (result["timing"] as Array)[side])
	if not bool(result["ok"]):
		failures += 1
		if failure_notes.size() < 20:
			failure_notes.append("%s vs %s: %s" % [a_deck, b_deck, str(result["error"])])
		return
	var names: Array[String] = [a_deck, b_deck]
	var a_won: bool = bool(result["a_won"])
	var reason: String = str(result["reason"])
	var turn: int = int(result["turn"])
	var distance: Array = result["distance"]
	var full_life: Array = result["full_life"]

	for side in range(2):
		var row: Dictionary = _row(side, names[side])
		var won: bool = a_won if side == 0 else not a_won
		row["played"] = int(row["played"]) + 1
		row["turns"] = int(row["turns"]) + turn
		var mine: Dictionary = distance[side]
		if won:
			row["won"] = int(row["won"]) + 1
			side_wins[side] += 1
			_bump(row["win"], reason)
			# What this deck had left of its own when it won: how near the win came to going the
			# other way. The loser's own distance is not worth averaging, since a survival win
			# puts it at zero by definition.
			_fold(row["margin"], mine)
		else:
			_bump(row["loss"], reason)
			_fold(row["shortfall"], mine)
			_bump(row["closest"], SimMatch.closest_route(mine, int(full_life[side])))

	var key: String = "%s|%s" % [a_deck, b_deck]
	var grid: Array = matchup.get(key, [0, 0])
	grid[0] = int(grid[0]) + (1 if a_won else 0)
	grid[1] = int(grid[1]) + 1
	matchup[key] = grid

	var timing: Array = result["timing"]
	tsv_rows.append("\t".join(PackedStringArray([
		a_deck, b_deck, str(int(result["a_seat"])), "a" if a_won else "b", reason, str(turn),
		str(int(full_life[0])), str(int(full_life[1])),
		str(int(distance[0]["survival"])), str(int(distance[0]["seal"])), "%.3f" % float(distance[0]["ascension"]),
		str(int(distance[1]["survival"])), str(int(distance[1]["seal"])), "%.3f" % float(distance[1]["ascension"]),
		str(int(timing[0]["decisions"])), "%.1f" % (float(timing[0]["total_usec"]) / 1000.0),
		str(int(timing[1]["decisions"])), "%.1f" % (float(timing[1]["total_usec"]) / 1000.0),
	])))


# --- Printing -------------------------------------------------------------

func print_all(roster: SimRoster, a_side: SimSeat, b_side: SimSeat, header: String) -> void:
	print("")
	print(header)
	print("side a: %s" % a_side.describe())
	print("side b: %s" % b_side.describe())
	print("%d matches, %d unusable" % [games, failures])
	for note in failure_notes:
		print("  FAILED %s" % note)
	var same: bool = a_side.describe() == b_side.describe()

	if same:
		var merged: Dictionary = _merged_rows()
		_print_record("RECORD  (both sides, %s)" % a_side.describe(), merged)
		_print_closeness(merged)
	else:
		_print_record("RECORD as side a  (%s)" % a_side.describe(), side_rows[0])
		_print_record("RECORD as side b  (%s)" % b_side.describe(), side_rows[1])
		var a_total: int = _total(side_rows[0], "played")
		var b_total: int = _total(side_rows[1], "played")
		print("")
		print("SIDES  side a %s, side b %s" % [
			rate_text(side_wins[0], a_total), rate_text(side_wins[1], b_total)])
		_print_closeness(_merged_rows())

	_print_matchups(roster)
	_print_timing(a_side, b_side)


func _print_record(title: String, rows: Dictionary) -> void:
	print("")
	print(title)
	print("%-18s %6s %-20s   %-20s   %-21s   %5s" % [
		"deck", "played", "win% (95% range)", "won by surv/seal/asc", "lost to surv/seal/asc", "turns"])
	var totals: Dictionary = {}
	for name in _ordered(rows):
		var t: Dictionary = rows[name]
		for r in REASONS:
			totals[r] = int(totals.get(r, 0)) + int((t["win"] as Dictionary).get(r, 0))
		print("%-18s %6d %-20s   %20s   %21s   %5.1f" % [
			name, int(t["played"]), rate_text(int(t["won"]), int(t["played"])),
			_counts_of(t["win"]), _counts_of(t["loss"]),
			float(int(t["turns"])) / float(maxi(1, int(t["played"]))),
		])
	print("all wins by route: %s" % _counts_of(totals))


func _print_closeness(rows: Dictionary) -> void:
	print("")
	print("HOW CLOSE IT CAME WHEN IT LOST  (life cards left / Seals missing / share of the Fervor climb left)")
	print("%-18s %6s   %-26s   %s" % ["deck", "losses", "own distance at the end", "nearest route: surv/seal/asc"])
	for name in _ordered(rows):
		var t: Dictionary = rows[name]
		print("%-18s %6d   %26s   %s" % [
			name, int((t["shortfall"] as Dictionary)["n"]), _averages(t["shortfall"]), _counts_of(t["closest"])])
	print("")
	print("WHAT IT HAD LEFT WHEN IT WON  (same three numbers, for the winner itself)")
	print("%-18s %6s   %s" % ["deck", "wins", "own distance at the end"])
	for name in _ordered(rows):
		var t: Dictionary = rows[name]
		print("%-18s %6d   %s" % [name, int((t["margin"] as Dictionary)["n"]), _averages(t["margin"])])


func _print_matchups(roster: SimRoster) -> void:
	if matchup.is_empty():
		return
	print("")
	print("MATCHUPS  (side a deck's win% against side b deck, n in brackets)")
	var head: PackedStringArray = ["%-18s" % "a \\ b"]
	for n in roster.b_names:
		head.append("%12s" % n.substr(0, 12))
	print(" ".join(head))
	for a in roster.a_names:
		var line: PackedStringArray = ["%-18s" % a]
		for b in roster.b_names:
			var grid: Array = matchup.get("%s|%s" % [a, b], [0, 0])
			if int(grid[1]) == 0:
				line.append("%12s" % "-")
				continue
			line.append("%8.0f%%[%s]" % [100.0 * float(int(grid[0])) / float(int(grid[1])), _short(int(grid[1]))])
		print(" ".join(line))


func _print_timing(a_side: SimSeat, b_side: SimSeat) -> void:
	print("")
	print("DECISION COST")
	print("%-6s %-28s %9s %8s %8s %8s %8s   %s" % [
		"side", "policy", "decisions", "mean ms", "med ms", "p95 ms", "max ms", "search: mean depth / fallbacks"])
	var sides: Array[SimSeat] = [a_side, b_side]
	for side in range(2):
		var t: Dictionary = side_timing[side]
		var samples: Array = t["samples_ms"]
		samples.sort()
		var decisions: int = maxi(1, int(t["decisions"]))
		print("%-6s %-28s %9d %8.2f %8.2f %8.2f %8.0f   %.2f / %d" % [
			SIDE_NAMES[side], sides[side].describe().substr(0, 28), int(t["decisions"]),
			float(t["total_usec"]) / 1000.0 / decisions,
			percentile(samples, 0.5), percentile(samples, 0.95), float(t["max_usec"]) / 1000.0,
			float(int(t["depth_total"])) / float(maxi(1, int(t["search_decisions"]))), int(t["fallbacks"]),
		])
		if not (t["stops"] as Dictionary).is_empty():
			print("       search stops: %s" % str(t["stops"]))


# --- Files ----------------------------------------------------------------

func write_tsv(path: String) -> bool:
	var folder_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if folder_error != OK:
		push_error("Cannot create %s: %s" % [path.get_base_dir(), error_string(folder_error)])
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_line("a_deck\tb_deck\ta_seat\twinner_side\treason\tturn\ta_life_start\tb_life_start\ta_life\ta_seals_missing\ta_asc_left\tb_life\tb_seals_missing\tb_asc_left\ta_decisions\ta_ms\tb_decisions\tb_ms")
	for r in tsv_rows:
		file.store_line(r)
	file.close()
	print("")
	print("wrote %s (%d matches)" % [path, tsv_rows.size()])
	return true


func write_json(path: String, config: Dictionary) -> bool:
	var summary: Dictionary = {
		"version": 1,
		"godot_version": Engine.get_version_info()["string"],
		"written_unix": Time.get_unix_time_from_system(),
		"config": config,
		"games": games,
		"unusable": failures,
		"failures": failure_notes,
		"side_wins": side_wins,
		"decks": {"a": _json_rows(side_rows[0]), "b": _json_rows(side_rows[1])},
		"matchups": _json_matchups(),
		"timing": [_json_timing(0), _json_timing(1)],
		# The mergeable form, for `tools/merge_matchlab.gd`. Everything above it is for reading.
		"state": to_state(),
	}
	var folder_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if folder_error != OK:
		push_error("Cannot create %s: %s" % [path.get_base_dir(), error_string(folder_error)])
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(summary, "\t") + "\n")
	file.close()
	print("wrote %s" % path)
	return true


# --- Merging --------------------------------------------------------------

## Everything this report counted, in a form another report can absorb. This is what lets a run be
## split across processes with `--shard` and folded back into one exact report afterwards. The raw
## timing samples travel with it, so the merged median and p95 are the true ones and not an average
## of averages.
func to_state() -> Dictionary:
	for side in range(2):
		(side_timing[side]["samples_ms"] as Array).sort()
	return {
		"games": games, "failures": failures, "failure_notes": failure_notes,
		"side_wins": side_wins, "side_rows": side_rows, "side_timing": side_timing,
		"matchup": matchup,
	}


## Folds another run's state into this one. Counts add, the two timing streams join.
func absorb(state: Dictionary) -> void:
	games += int(state["games"])
	failures += int(state["failures"])
	for note in state["failure_notes"]:
		if failure_notes.size() < 20:
			failure_notes.append(str(note))
	for side in range(2):
		side_wins[side] += int((state["side_wins"] as Array)[side])
		_fold_timing(side_timing[side], (state["side_timing"] as Array)[side])
		var incoming: Dictionary = (state["side_rows"] as Array)[side]
		for name in incoming.keys():
			var source: Dictionary = incoming[name]
			var target: Dictionary = _row(side, str(name))
			for key in ["played", "won", "turns"]:
				target[key] = int(target[key]) + int(source[key])
			for key in ["win", "loss", "closest"]:
				for r in (source[key] as Dictionary).keys():
					(target[key] as Dictionary)[r] = int((target[key] as Dictionary).get(r, 0)) + int((source[key] as Dictionary)[r])
			for key in ["margin", "shortfall"]:
				var t_acc: Dictionary = target[key]
				var s_acc: Dictionary = source[key]
				t_acc["n"] = int(t_acc["n"]) + int(s_acc["n"])
				for r in REASONS:
					t_acc[r] = float(t_acc[r]) + float(s_acc[r])
	for key in (state.get("matchup", {}) as Dictionary).keys():
		var incoming_grid: Array = (state["matchup"] as Dictionary)[key]
		var grid: Array = matchup.get(key, [0, 0])
		grid[0] = int(grid[0]) + int(incoming_grid[0])
		grid[1] = int(grid[1]) + int(incoming_grid[1])
		matchup[key] = grid


func _json_rows(rows: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for name in rows.keys():
		var t: Dictionary = rows[name]
		var played: int = int(t["played"])
		var bounds: Array[float] = wilson(int(t["won"]), played)
		out[name] = {
			"played": played, "won": int(t["won"]),
			"win_rate": float(int(t["won"])) / float(maxi(1, played)),
			"win_low": bounds[0], "win_high": bounds[1],
			"mean_turns": float(int(t["turns"])) / float(maxi(1, played)),
			"win_by": t["win"], "loss_to": t["loss"], "closest_when_lost": t["closest"],
			"margin": _mean_of(t["margin"]), "shortfall": _mean_of(t["shortfall"]),
		}
	return out


func _json_matchups() -> Dictionary:
	var out: Dictionary = {}
	for key in matchup.keys():
		var grid: Array = matchup[key]
		var bounds: Array[float] = wilson(int(grid[0]), int(grid[1]))
		out[key] = {"a_wins": int(grid[0]), "played": int(grid[1]),
			"a_rate": float(int(grid[0])) / float(maxi(1, int(grid[1]))),
			"a_low": bounds[0], "a_high": bounds[1]}
	return out


func _json_timing(side: int) -> Dictionary:
	var t: Dictionary = side_timing[side]
	var samples: Array = t["samples_ms"]
	samples.sort()
	var decisions: int = maxi(1, int(t["decisions"]))
	return {
		"decisions": int(t["decisions"]),
		"mean_ms": float(t["total_usec"]) / 1000.0 / decisions,
		"median_ms": percentile(samples, 0.5),
		"p95_ms": percentile(samples, 0.95),
		"max_ms": float(t["max_usec"]) / 1000.0,
		"search_decisions": int(t["search_decisions"]),
		"branching_decisions": int(t["branching_decisions"]),
		"mean_completed_depth": float(int(t["depth_total"])) / float(maxi(1, int(t["search_decisions"]))),
		"max_completed_depth": int(t["max_depth"]),
		"fallbacks": int(t["fallbacks"]),
		"stops": t["stops"],
	}


# --- Statistics -----------------------------------------------------------

## The 95% Wilson score interval for `wins` out of `n`. Well behaved at small n and at 0% or 100%,
## where the plain normal interval is not.
static func wilson(wins: int, n: int) -> Array[float]:
	if n <= 0:
		return [0.0, 1.0]
	var p: float = float(wins) / float(n)
	var denominator: float = 1.0 + Z * Z / float(n)
	var centre: float = (p + Z * Z / (2.0 * float(n))) / denominator
	var margin: float = Z * sqrt(p * (1.0 - p) / float(n) + Z * Z / (4.0 * float(n) * float(n))) / denominator
	return [maxf(0.0, centre - margin), minf(1.0, centre + margin)]


static func percentile(sorted: Array, fraction: float) -> float:
	if sorted.is_empty():
		return 0.0
	return float(sorted[mini(sorted.size() - 1, int(ceil(fraction * sorted.size())) - 1)])


# --- Internals ------------------------------------------------------------

func _row(side: int, name: String) -> Dictionary:
	var rows: Dictionary = side_rows[side]
	if not rows.has(name):
		rows[name] = blank_row()
	return rows[name]


static func blank_row() -> Dictionary:
	return {
		"played": 0, "won": 0, "turns": 0,
		"win": {}, "loss": {}, "closest": {},
		"margin": {"n": 0, "survival": 0.0, "seal": 0.0, "ascension": 0.0},
		"shortfall": {"n": 0, "survival": 0.0, "seal": 0.0, "ascension": 0.0},
	}


func _merged_rows() -> Dictionary:
	var out: Dictionary = {}
	for side in range(2):
		for name in (side_rows[side] as Dictionary).keys():
			var source: Dictionary = (side_rows[side] as Dictionary)[name]
			if not out.has(name):
				out[name] = blank_row()
			var target: Dictionary = out[name]
			for key in ["played", "won", "turns"]:
				target[key] = int(target[key]) + int(source[key])
			for key in ["win", "loss", "closest"]:
				for r in (source[key] as Dictionary).keys():
					(target[key] as Dictionary)[r] = int((target[key] as Dictionary).get(r, 0)) + int((source[key] as Dictionary)[r])
			for key in ["margin", "shortfall"]:
				var t_acc: Dictionary = target[key]
				var s_acc: Dictionary = source[key]
				t_acc["n"] = int(t_acc["n"]) + int(s_acc["n"])
				for r in REASONS:
					t_acc[r] = float(t_acc[r]) + float(s_acc[r])
	return out


func _ordered(rows: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for name in rows.keys():
		out.append(str(name))
	out.sort_custom(func(x: String, y: String) -> bool:
		return _rate(rows[x]) > _rate(rows[y]))
	return out


func _total(rows: Dictionary, key: String) -> int:
	var sum: int = 0
	for name in rows.keys():
		sum += int((rows[name] as Dictionary)[key])
	return sum


func _rate(t: Dictionary) -> float:
	return float(int(t["won"])) / float(maxi(1, int(t["played"])))


static func rate_text(wins: int, n: int) -> String:
	if n <= 0:
		return "     - "
	var bounds: Array[float] = wilson(wins, n)
	return "%5.1f%% (%4.1f-%4.1f)" % [100.0 * float(wins) / float(n), 100.0 * bounds[0], 100.0 * bounds[1]]


func _averages(acc: Dictionary) -> String:
	var n: float = float(maxi(1, int(acc["n"])))
	return "%5.1f life /%4.1f seals /%4.0f%% asc" % [
		float(acc["survival"]) / n, float(acc["seal"]) / n, 100.0 * float(acc["ascension"]) / n]


func _mean_of(acc: Dictionary) -> Dictionary:
	var n: float = float(maxi(1, int(acc["n"])))
	return {"n": int(acc["n"]), "survival": float(acc["survival"]) / n,
		"seal": float(acc["seal"]) / n, "ascension": float(acc["ascension"]) / n}


func _counts_of(counts: Dictionary) -> String:
	var out: PackedStringArray = PackedStringArray()
	for r in REASONS:
		out.append(str(int(counts.get(r, 0))))
	return "/".join(out)


func _short(n: int) -> String:
	return str(n) if n < 1000 else "%dk" % (n / 1000)


func _bump(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _fold(acc: Dictionary, d: Dictionary) -> void:
	acc["n"] = int(acc["n"]) + 1
	for r in REASONS:
		acc[r] = float(acc[r]) + float(d[r])


func _fold_timing(acc: Dictionary, one: Dictionary) -> void:
	for key in ["decisions", "total_usec", "search_decisions", "branching_decisions", "depth_total", "fallbacks"]:
		acc[key] = int(acc[key]) + int(one[key])
	acc["max_usec"] = maxi(int(acc["max_usec"]), int(one["max_usec"]))
	acc["max_depth"] = maxi(int(acc["max_depth"]), int(one["max_depth"]))
	(acc["samples_ms"] as Array).append_array(one["samples_ms"])
	for stop in (one["stops"] as Dictionary).keys():
		(acc["stops"] as Dictionary)[stop] = int((acc["stops"] as Dictionary).get(stop, 0)) + int((one["stops"] as Dictionary)[stop])
