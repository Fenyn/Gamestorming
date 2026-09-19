extends SceneTree
## The deck and AI test bench. One runner for balance questions ("which deck wins"), difficulty
## questions ("does Hard beat Easy") and cost questions ("does another 400 ms buy anything").
##
## The two sides of the table are configured independently. Side `a` is the pilot, side `b` the
## field it is measured against; in `matrix` mode every a/b pair is played the same number of times
## from both seats, and in `sample` mode opponents are drawn at random in proportion to the weights
## in the field.
##
##   godot --headless --path zenith -s tests/matchlab.gd -- --repeats=9
##   godot --headless --path zenith -s tests/matchlab.gd -- --a=hard --b=easy --repeats=4
##   godot --headless --path zenith -s tests/matchlab.gd -- --a-field=tide_companions \
##       --b-field=@strike_beatdown --repeats=30 --json=res://reports/tide.json
##   godot --headless --path zenith -s tests/matchlab.gd -- --mode=sample --games=400 \
##       --field=@strike_beatdown:3,@allies:2,@art_beatdown:2,@seals:1,@drills:1
##   godot --headless --path zenith -s tests/matchlab.gd -- --a=search --a-budget=800 \
##       --b=search --b-budget=200 --repeats=6
##
## Every flag can also live in a scenario file, `--scenario=res://tests/scenarios/<name>.json`,
## whose keys are the same flag names. A flag on the command line overrides the file, which is how
## you vary one axis against a fixed baseline.
##
## Unknown flags are an error, not a shrug. `--repeat=20` stops the run and says so.

const SPEC_BASE: Dictionary = {
	"scenario": {"type": "str", "default": ""},

	"mode": {"type": "str", "default": "matrix", "choices": ["matrix", "sample"]},
	"repeats": {"type": "int", "default": 9, "min": 1, "max": 100000},
	"games": {"type": "int", "default": 200, "min": 1, "max": 1000000},
	"limit": {"type": "int", "default": 0, "min": 0, "max": 1000000},
	"seed": {"type": "int", "default": 1, "min": 0, "max": 2147483647},
	"max-steps": {"type": "int", "default": 6000, "min": 100, "max": 1000000},

	"field": {"type": "str", "default": ""},
	"decks": {"type": "str", "default": ""},
	"a-field": {"type": "str", "default": ""},
	"b-field": {"type": "str", "default": ""},

	"policy": {"type": "str", "default": "search"},
	"a": {"type": "str", "default": ""},
	"b": {"type": "str", "default": ""},
	"styles": {"type": "bool", "default": "on"},
	"a-styles": {"type": "bool", "default": "on"},
	"b-styles": {"type": "bool", "default": "on"},
	"think": {"type": "str", "default": ""},
	"a-think": {"type": "str", "default": ""},
	"b-think": {"type": "str", "default": ""},

	# `--shard=2/8` plays only every eighth match, starting at the third. The whole schedule is
	# built first and then sifted, so the seeds a shard plays are the ones it would have played in
	# the full run, and `tools/merge_matchlab.gd` folds the shards back into one exact report.
	"shard": {"type": "str", "default": ""},

	"tsv": {"type": "str", "default": ""},
	"json": {"type": "str", "default": ""},
	"verbose": {"type": "bool", "default": "off"},
	"progress": {"type": "int", "default": 0, "min": 0, "max": 1000000},
}


var shard_error: String = ""
var shard_label: String = ""


func _init() -> void:
	var args: SimArgs = SimArgs.parse(_spec(), OS.get_cmdline_user_args())
	if not args.error.is_empty():
		push_error(args.error)
		print("matchlab: %s" % args.error)
		quit(2)
		return

	var field: String = args.str_of("field")
	if field.strip_edges().is_empty():
		field = args.str_of("decks")
	var roster: SimRoster = SimRoster.build(field, args.str_of("a-field"), args.str_of("b-field"))
	if not roster.error.is_empty():
		push_error(roster.error)
		print("matchlab: %s" % roster.error)
		quit(2)
		return

	var a_side: SimSeat = SimSeat.from_args(args, "a")
	var b_side: SimSeat = SimSeat.from_args(args, "b")
	for side in [a_side, b_side]:
		if not side.error.is_empty():
			push_error(side.error)
			print("matchlab: %s" % side.error)
			quit(2)
			return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = args.int_of("seed")
	var schedule: Array[Array] = _schedule(args, roster, rng)
	if not shard_error.is_empty():
		push_error(shard_error)
		print("matchlab: %s" % shard_error)
		quit(2)
		return
	if schedule.is_empty():
		print("matchlab: the schedule came out empty; check --a-field, --b-field and --shard")
		quit(2)
		return

	print("matchlab %s%s: %d matches" % [args.str_of("mode"), shard_label, schedule.size()])
	print("  a field: %s" % roster.describe(roster.a_names, roster.a_weights))
	print("  b field: %s" % roster.describe(roster.b_names, roster.b_weights))
	print("  a side : %s" % a_side.describe())
	print("  b side : %s" % b_side.describe())
	print("  flags  : %s" % args.describe_given())

	var library: CardLibrary = CardLibrary.new()
	library.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var runner: SimMatch = SimMatch.make(library, table, args.int_of("max-steps"))
	var report: SimReport = SimReport.new()
	var verbose: bool = args.bool_of("verbose")
	var progress: int = args.int_of("progress")
	var started: int = Time.get_ticks_msec()

	for index in range(schedule.size()):
		var entry: Array = schedule[index]
		var a_deck: String = entry[0]
		var b_deck: String = entry[1]
		var a_seat: int = entry[2]
		var seeds: Array[int] = [entry[3], entry[4], entry[5], entry[6]]
		var result: Dictionary = runner.play(roster.deck(a_deck), roster.deck(b_deck), a_seat, a_side, b_side, seeds)
		report.add(result, a_deck, b_deck)
		if not bool(result["ok"]):
			print("FAILED %s vs %s (a in seat %d): %s" % [a_deck, b_deck, a_seat, str(result["error"])])
		elif verbose:
			print("%s vs %s (a in seat %d): %s wins by %s on turn %d" % [
				a_deck, b_deck, a_seat, "a" if bool(result["a_won"]) else "b",
				str(result["reason"]), int(result["turn"])])
		if progress > 0 and (index + 1) % progress == 0:
			var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
			var rate: float = float(index + 1) / maxf(0.001, elapsed)
			print("  %d/%d, %.0fs elapsed, ~%.0fs left" % [
				index + 1, schedule.size(), elapsed, float(schedule.size() - index - 1) / maxf(0.001, rate)])

	report.print_all(roster, a_side, b_side, "=== matchlab, %.0fs ===" % (float(Time.get_ticks_msec() - started) / 1000.0))

	var config: Dictionary = args.to_dict()
	config["a_side"] = a_side.to_dict()
	config["b_side"] = b_side.to_dict()
	config["a_field"] = roster.a_names
	config["b_field"] = roster.b_names
	config["a_weights"] = roster.a_weights
	config["b_weights"] = roster.b_weights
	var wrote: bool = true
	if not args.str_of("tsv").is_empty():
		wrote = report.write_tsv(ProjectSettings.globalize_path(args.str_of("tsv"))) and wrote
	if not args.str_of("json").is_empty():
		wrote = report.write_json(ProjectSettings.globalize_path(args.str_of("json")), config) and wrote
	quit(0 if report.failures == 0 and wrote else 1)


## The full spec: the base flags plus one shared and two per-side flags for every think knob.
func _spec() -> Dictionary:
	var spec: Dictionary = SPEC_BASE.duplicate(true)
	for suffix in SimSeat.KNOBS.keys():
		var whole: bool = bool((SimSeat.KNOBS[suffix] as Array)[1])
		var rule: Dictionary = {"type": "int", "default": 0, "min": 0, "max": 2147483647} if whole else {"type": "float", "default": 0.0}
		for key in [str(suffix), "a-%s" % suffix, "b-%s" % suffix]:
			spec[key] = rule.duplicate()
	return spec


## One entry per match: [a deck, b deck, a's seat, engine seed, a seed, b seed, random seed].
func _schedule(args: SimArgs, roster: SimRoster, rng: RandomNumberGenerator) -> Array[Array]:
	var out: Array[Array] = []
	if args.str_of("mode") == "matrix":
		for repeat in range(args.int_of("repeats")):
			for a_deck in roster.a_names:
				for b_deck in roster.b_names:
					if a_deck == b_deck:
						continue
					for a_seat in range(2):
						out.append(_entry(a_deck, b_deck, a_seat, rng))
	else:
		for game in range(args.int_of("games")):
			var a_deck: String = roster.pick(roster.a_names, roster.a_weights, rng)
			var b_deck: String = roster.pick_other(roster.b_names, roster.b_weights, rng, a_deck)
			if b_deck.is_empty():
				# The b field holds nothing but this deck; draw the pilot from what b can answer.
				a_deck = roster.pick_other(roster.a_names, roster.a_weights, rng, roster.b_names[0])
				b_deck = roster.b_names[0]
				if a_deck.is_empty():
					continue
			out.append(_entry(a_deck, b_deck, rng.randi_range(0, 1), rng))
	var limit: int = args.int_of("limit")
	if limit > 0 and out.size() > limit:
		out.resize(limit)
	return _sift(args, out)


## `--shard=i/n` keeps every nth match starting at i, after the full schedule and its seeds exist.
## Running all n shards covers the schedule exactly once, with no match played twice.
func _sift(args: SimArgs, full: Array[Array]) -> Array[Array]:
	var spec: String = args.str_of("shard").strip_edges()
	if spec.is_empty():
		return full
	var parts: PackedStringArray = spec.split("/", true)
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		shard_error = "--shard takes i/n, for example 0/8; got %s" % spec
		return []
	var index: int = int(parts[0])
	var count: int = int(parts[1])
	if count < 1 or index < 0 or index >= count:
		shard_error = "--shard=i/n needs n at least 1 and i from 0 to n-1; got %s" % spec
		return []
	shard_label = " shard %d of %d" % [index + 1, count]
	var out: Array[Array] = []
	for i in range(full.size()):
		if i % count == index:
			out.append(full[i])
	return out


func _entry(a_deck: String, b_deck: String, a_seat: int, rng: RandomNumberGenerator) -> Array:
	return [a_deck, b_deck, a_seat, rng.randi(), rng.randi(), rng.randi(), rng.randi()]
