extends SceneTree
## Plays AI policies against each other across the starter decks under the printed rules and reports
## who wins and how long a decision takes. Every pairing is played from both seats.
## godot --headless --path zenith -s tests/ai_arena.gd -- --a=search --b=scorer --seeds=1
## Policies: random, scorer, search, rollout (historical search), or a difficulty profile.
## Options: --seeds=N, --decks=pyre_beatdown,storm_volley (default every deck in data/decks), any
## search knob SimSeat names (--budget=MS, default 600, --samples=N, --turns=N, --steps=N, ...), --verbose for a
## line per game, --report=<path> for a JSON summary. A deck's own playstyle profile (`ai_profile` in
## its JSON) is used unless --styles=a, --styles=b or --styles=none says which policies get one;
## that is how a playstyle is measured against the defaults. `--resonances-a=<ids>` and
## `--resonances-b=<ids>` (comma-separated ResonanceData ids) give that policy's deck those
## Resonances, as an adventure run or an Elite holds them.

const MAX_STEPS: int = 6000


func _init() -> void:
	var spec: Dictionary = {
		"a": {"type": "str", "default": "search"},
		"b": {"type": "str", "default": "random"},
		"seeds": {"type": "int", "default": 1, "min": 1, "max": 100000},
		"decks": {"type": "str", "default": ""},
		"styles": {"type": "str", "default": "ab", "choices": ["ab", "a", "b", "none"]},
		"verbose": {"type": "bool", "default": "off"},
		"report": {"type": "str", "default": ""},
		"resonances-a": {"type": "str", "default": ""},
		"resonances-b": {"type": "str", "default": ""},
	}
	# Search knobs stay unset unless given, so a profile's own value holds. The budget is the
	# exception: 600 ms is where search stops falling back to the scorer, at about a third of the
	# profile's 1600 ms (2026-09-26 probe: 349 fallbacks in 18 games at 300 ms, 3 at 600, 0 at 1000).
	for suffix in SimSeat.KNOBS.keys():
		spec[suffix] = {"type": "str", "default": ""}
	spec["budget"] = {"type": "str", "default": "600"}
	var args: SimArgs = SimArgs.parse(spec, OS.get_cmdline_user_args())
	if not args.error.is_empty():
		push_error(args.error)
		quit(1)
		return
	var sides: Array[SimSeat] = []
	for i in range(2):
		var key: String = "ab"[i]
		var side: SimSeat = SimSeat.from_legacy(args.str_of(key), args.values, args.str_of("styles").contains(key))
		if not side.error.is_empty():
			push_error("--%s: %s" % [key, side.error])
			quit(1)
			return
		sides.append(side)
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var sim: SimMatch = SimMatch.make(lib, table, MAX_STEPS)
	var names: Array[String] = deck_names(args.str_of("decks"))
	var resonances: Array[Array] = [[], []]
	for i in range(2):
		var held: Array[String] = []
		for id in args.str_of("resonances-" + "ab"[i]).split(",", false):
			if not ResonanceData.has(id):
				push_error("--resonances-%s: no Resonance named '%s'" % ["ab"[i], id])
				quit(1)
				return
			held.append(id)
		resonances[i] = held
	var policies: Array[String] = [sides[0].policy, sides[1].policy]
	var wins: Array[int] = [0, 0]
	var broken: int = 0
	var games: int = 0
	var reasons: Dictionary = {}
	var by_deck: Dictionary = {}     # deck -> [wins as policy a, games as policy a]
	var think_usec: Array[int] = [0, 0]
	var decisions: Array[int] = [0, 0]
	var slowest_usec: Array[int] = [0, 0]
	var timings: Array = [[], []]
	var search_depths: Array[int] = [0, 0]
	var search_decisions: Array[int] = [0, 0]
	var fallbacks: Array[int] = [0, 0]
	for deck_a in names:
		for deck_b in names:
			for s in range(args.int_of("seeds")):
				for a_seat in range(2):
					var seeds: Array[int] = [100 + s, games * 2 + 1, games * 2 + 2, games + 1]
					var a_deck: DeckList = DeckList.resolve(deck_a)
					var b_deck: DeckList = DeckList.resolve(deck_b)
					a_deck.resonances.assign(resonances[0])
					b_deck.resonances.assign(resonances[1])
					var result: Dictionary = sim.play(a_deck, b_deck, a_seat, sides[0], sides[1], seeds)
					games += 1
					for side in range(2):
						var t: Dictionary = (result["timing"] as Array)[side]
						think_usec[side] += int(t["total_usec"])
						decisions[side] += int(t["decisions"])
						slowest_usec[side] = maxi(slowest_usec[side], int(t["max_usec"]))
						(timings[side] as Array).append_array(t["samples_ms"])
						search_depths[side] += int(t["depth_total"])
						search_decisions[side] += int(t["search_decisions"])
						fallbacks[side] += int(t["fallbacks"])
					var tally: Array = by_deck.get(deck_a, [0, 0])
					tally[1] = int(tally[1]) + 1
					if bool(result["ok"]):
						var winner: int = 0 if bool(result["a_won"]) else 1
						wins[winner] += 1
						if winner == 0:
							tally[0] = int(tally[0]) + 1
						var key: String = "%s:%s" % [policies[winner], str(result["reason"])]
						reasons[key] = int(reasons.get(key, 0)) + 1
					else:
						broken += 1
						print("BROKEN %s(%s) vs %s(%s) seed %d seat %d: %s" % [policies[0], deck_a, policies[1], deck_b, s, a_seat, str(result["error"])])
					by_deck[deck_a] = tally
					if args.bool_of("verbose"):
						print("%s(%s) vs %s(%s) seed %d seat %d: winner %s by %s in %d steps" % [policies[0], deck_a, policies[1], deck_b, s, a_seat,
							policies[0] if bool(result["a_won"]) else policies[1], str(result["reason"]), int(result["steps"])])
	print("games %d, broken or unfinished %d" % [games, broken])
	for i in range(2):
		print("%s: %d wins (%.1f%%), %.2f ms per decision, slowest %.0f ms" % [policies[i], wins[i], 100.0 * wins[i] / maxi(1, games), think_usec[i] / 1000.0 / maxi(1, decisions[i]), slowest_usec[i] / 1000.0])
		(timings[i] as Array).sort()
		print("  median %.2f ms, p95 %.2f ms; mean completed depth %.2f, scorer fallbacks %d" % [percentile(timings[i], 0.5), percentile(timings[i], 0.95), float(search_depths[i]) / maxi(1, search_decisions[i]), fallbacks[i]])
	print("win reasons %s" % str(reasons))
	for d in names:
		var t: Array = by_deck.get(d, [0, 0])
		print("  %s as %s: %d of %d" % [d, policies[0], int(t[0]), int(t[1])])
	if not args.str_of("report").is_empty():
		var summary: Dictionary = {"arguments": args.to_dict(), "games": games, "unfinished": broken,
			"policies": policies, "wins": wins, "by_deck": by_deck, "win_reasons": reasons,
			"decisions": decisions, "total_usec": think_usec, "max_usec": slowest_usec,
			"median_ms": [percentile(timings[0], 0.5), percentile(timings[1], 0.5)],
			"p95_ms": [percentile(timings[0], 0.95), percentile(timings[1], 0.95)],
			"search_depth_totals": search_depths, "search_decisions": search_decisions, "fallbacks": fallbacks}
		var output: FileAccess = FileAccess.open(args.str_of("report"), FileAccess.WRITE)
		if output == null:
			push_error("Cannot write arena report: %s" % args.str_of("report"))
			quit(1)
			return
		output.store_string(JSON.stringify(summary, "\t") + "\n")
	quit(1 if broken > 0 else 0)


func percentile(sorted: Array, fraction: float) -> float:
	return float(sorted[mini(sorted.size() - 1, int(ceil(fraction * sorted.size())) - 1)]) if not sorted.is_empty() else 0.0


func deck_names(wanted: String) -> Array[String]:
	var names: Array[String] = []
	if wanted != "":
		for n in wanted.split(","):
			names.append(n)
		return names
	for entry in DirAccess.get_files_at("res://data/decks"):
		if entry.ends_with(".json"):
			names.append(entry.trim_suffix(".json"))
	names.sort()
	return names
