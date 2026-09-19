extends SceneTree
## Deck balance with the endgame state attached. Every deck pilots the same number of matches against
## every other deck from both seats, and at the moment the game ends we record how far each side still
## had to go on all three win routes. That says not only who won but how close the loser came, and by
## which route they were closest.
##
## godot --headless --path zenith -s tests/deck_outcomes.gd -- --repeats=9
##
## Options: --repeats=N matches per ordered pair per seat (default 9, so 7 decks give 108 matches per
## pilot and 756 in all), --policy=random|scorer|search (default scorer), --decks=a,b to cut the field,
## --seed=N, --budget=MS and --samples=N for searching policies, --styles=off for the default profile
## on every deck, and --tsv=path to dump one row per match for your own analysis.

## --search-decks=a,b forces only those field decks onto the sequence planner.
const MAX_STEPS: int = 6000
const REASONS: Array[String] = ["survival", "seal", "ascension"]

var search_decks: Array[String] = []

func _init() -> void:
	var args: Dictionary = {"repeats": "9", "policy": "scorer", "decks": "", "seed": "1", "budget": "", "samples": "", "styles": "on", "tsv": ""}
	for raw in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var names: Array[String] = deck_names(str(args["decks"]))
	for target in str(args.get("search-decks", "")).split(",", false):
		var target_name: String = target.strip_edges()
		if not names.has(target_name):
			push_error("Search override deck is not in the field: %s" % target_name)
			quit(1)
			return
		if not search_decks.has(target_name):
			search_decks.append(target_name)
	print("Base policy: %s; sequence search overrides: %s; styles: %s; search budget: %s ms; samples: %s" % [
		str(args["policy"]), ", ".join(search_decks) if not search_decks.is_empty() else "(none)",
		str(args["styles"]), str(args["budget"]) if str(args["budget"]) != "" else "profile",
		str(args["samples"]) if str(args["samples"]) != "" else "profile"])
	if names.size() < 2:
		print("need at least two decks")
		quit(1)
		return
	var repeats: int = maxi(1, int(args["repeats"]))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(args["seed"])

	var tally: Dictionary = {}
	for n in names:
		tally[n] = blank_deck_row()
	var matchup: Dictionary = {}     # "pilot|foe" -> [wins, played]
	var rows: Array[String] = []
	var unfinished: int = 0
	var games: int = 0

	for r in range(repeats):
		for pilot in names:
			for foe in names:
				if foe == pilot:
					continue
				for seat in [0, 1]:
					games += 1
					var decks: Array[DeckList] = [null, null]
					decks[seat] = DeckList.load_from("res://data/decks/%s.json" % pilot)
					decks[1 - seat] = DeckList.load_from("res://data/decks/%s.json" % foe)
					var ref: Referee = Referee.new()
					ref.setup(decks, lib, table, rng.randi())
					ref.start()
					ref.engine.take_events()
					var players: Array[AiPlayer] = [null, null]
					for i in range(2):
						players[i] = make_player(str(args["policy"]), args, games * 2 + i, decks[i] if str(args["styles"]) != "off" else null, pilot if i == seat else foe)
					var steps: int = 0
					while not ref.is_over() and steps < MAX_STEPS:
						steps += 1
						var who: int = ref.engine.prompt.player
						var command: Dictionary
						if players[who] == null:
							var opts: Array[Command] = ref.engine.prompt.options
							command = opts[rng.randi_range(0, opts.size() - 1)].to_dict()
						else:
							command = players[who].choose(ref, who)
						var error: String = ref.submit(who, command)
						if error != "":
							push_error("Rejected action in %s vs %s, seat %d, step %d: %s (%s)" % [pilot, foe, who, steps, error, command])
							quit(1)
							return
						ref.engine.take_events()
					if not ref.is_over():
						unfinished += 1
						print("UNFINISHED %s vs %s at turn %d" % [pilot, foe, ref.engine.state.turn])
						continue
					record(tally, matchup, rows, ref, pilot, foe, seat)
	report(names, tally, matchup, games, unfinished)
	if str(args["tsv"]) != "":
		write_tsv(str(args["tsv"]), rows)
	quit(1 if unfinished > 0 else 0)


# --- Recording ------------------------------------------------------------

## One finished match, folded into both decks' rows and into the matchup grid. `pilot` sat in `seat`.
func record(tally: Dictionary, matchup: Dictionary, rows: Array[String], ref: Referee, pilot: String, foe: String, seat: int) -> void:
	var engine: DuelEngine = ref.engine
	var reason: String = engine.state.win_reason
	var turn: int = engine.state.turn
	var pilot_won: bool = engine.state.winner == seat
	var near: Array[Dictionary] = [distances(engine, 0), distances(engine, 1)]

	for pair in [[pilot, seat, foe], [foe, 1 - seat, pilot]]:
		var deck_name: String = pair[0]
		var my_seat: int = pair[1]
		var won: bool = engine.state.winner == my_seat
		var row: Dictionary = tally[deck_name]
		row["played"] = int(row["played"]) + 1
		row["turns"] = int(row["turns"]) + turn
		if won:
			row["won"] = int(row["won"]) + 1
			bump(row["win"], reason)
			# What this deck had left of its own when it won: how near the win was to going the
			# other way. The loser's distance is not worth averaging, since a survival win puts it
			# at zero by definition.
			fold(row["margin"], near[my_seat])
		else:
			bump(row["loss"], reason)
			# How much this deck had left when it died: how close it came, and by which route.
			fold(row["shortfall"], near[my_seat])
			bump(row["closest"], closest_route(near[my_seat]))

	var key: String = "%s|%s" % [pilot, foe]
	var grid: Array = matchup.get(key, [0, 0])
	grid[0] = int(grid[0]) + (1 if pilot_won else 0)
	grid[1] = int(grid[1]) + 1
	matchup[key] = grid

	rows.append("\t".join(PackedStringArray([
		pilot, foe, str(seat), pilot if pilot_won else foe, reason, str(turn),
		str(near[seat]["survival"]), str(near[seat]["seal"]), "%.3f" % float(near[seat]["ascension"]),
		str(near[1 - seat]["survival"]), str(near[1 - seat]["seal"]), "%.3f" % float(near[1 - seat]["ascension"]),
	])))


## What one seat still needed on each route, at the moment the game ended. Lower is closer.
## `survival` is life cards left to lose, `seal` is Seals missing from the best set, `ascension` is
## the fraction of the Fervor-and-aspect climb still to go.
func distances(engine: DuelEngine, seat: int) -> Dictionary:
	var p: PlayerState = engine.state.players[seat]
	var sets: Dictionary = {}
	for t in p.seals():
		sets[t.def.seal_set] = int(sets.get(t.def.seal_set, 0)) + 1
	var best: int = 0
	for s in sets.keys():
		best = maxi(best, int(sets[s]))
	var need: int = maxi(1, engine.fervor_needed(p))
	var target: int = p.highest_aspect * need
	var have: int = (p.duelist.aspect - 1) * need + p.fervor
	return {
		"survival": p.life_deck.size(),
		"seal": DuelEngine.SEALS_PER_SET - best,
		# A forbidden Ascension is as far away as it gets, not as near.
		"ascension": 1.0 if p.no_ascension_win else float(target - have) / float(target),
	}


## The route a seat was nearest to finishing, on a common scale: each distance as a share of a full
## run from nothing. Ascension is already a fraction; the other two are divided by their full climb.
func closest_route(d: Dictionary) -> String:
	var scaled: Dictionary = {
		"survival": float(int(d["survival"])) / 40.0,
		"seal": float(int(d["seal"])) / float(DuelEngine.SEALS_PER_SET),
		"ascension": float(d["ascension"]),
	}
	var best: String = "survival"
	for r in REASONS:
		if float(scaled[r]) < float(scaled[best]):
			best = r
	return best


func blank_deck_row() -> Dictionary:
	return {
		"played": 0, "won": 0, "turns": 0,
		"win": {}, "loss": {}, "closest": {},
		"margin": {"n": 0, "survival": 0.0, "seal": 0.0, "ascension": 0.0},
		"shortfall": {"n": 0, "survival": 0.0, "seal": 0.0, "ascension": 0.0},
	}


func fold(acc: Dictionary, d: Dictionary) -> void:
	acc["n"] = int(acc["n"]) + 1
	for r in REASONS:
		acc[r] = float(acc[r]) + float(d[r])


func bump(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


# --- Reporting ------------------------------------------------------------

func report(names: Array[String], tally: Dictionary, matchup: Dictionary, games: int, unfinished: int) -> void:
	var order: Array[String] = names.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return rate(tally[a]) > rate(tally[b]))

	print("%d matches, %d unfinished" % [games, unfinished])
	print("")
	print("RECORD")
	print("%-18s %6s %6s   %-20s   %-21s   %5s" % ["deck", "played", "win%", "won by surv/seal/asc", "lost to surv/seal/asc", "turns"])
	var totals: Dictionary = {}
	for deck_name in order:
		var t: Dictionary = tally[deck_name]
		for r in REASONS:
			totals[r] = int(totals.get(r, 0)) + int((t["win"] as Dictionary).get(r, 0))
		print("%-18s %6d %5.1f%%   %20s   %21s   %5.1f" % [
			deck_name, int(t["played"]), 100.0 * rate(t),
			counts_of(t["win"]), counts_of(t["loss"]),
			float(int(t["turns"])) / float(maxi(1, int(t["played"]))),
		])
	print("all wins by route: %s" % counts_of(totals))

	print("")
	print("HOW CLOSE IT CAME WHEN IT LOST  (life cards left / Seals missing / share of the Fervor climb left)")
	print("%-18s %6s   %-26s   %s" % ["deck", "losses", "own distance at the end", "nearest route: surv/seal/asc"])
	for deck_name in order:
		var t: Dictionary = tally[deck_name]
		print("%-18s %6d   %26s   %s" % [
			deck_name, int((t["shortfall"] as Dictionary)["n"]),
			averages(t["shortfall"]), counts_of(t["closest"]),
		])

	print("")
	print("WHAT IT HAD LEFT WHEN IT WON  (same three numbers, for the winner itself)")
	print("%-18s %6s   %s" % ["deck", "wins", "own distance at the end"])
	for deck_name in order:
		var t: Dictionary = tally[deck_name]
		print("%-18s %6d   %s" % [deck_name, int((t["margin"] as Dictionary)["n"]), averages(t["margin"])])

	print("")
	print("MATCHUPS  (row's win% as pilot against column)")
	var head: PackedStringArray = ["%-18s" % "pilot \\ foe"]
	for n in order:
		head.append("%7s" % n.substr(0, 7))
	print(" ".join(head))
	for a in order:
		var line: PackedStringArray = ["%-18s" % a]
		for b in order:
			if a == b:
				line.append("%7s" % "-")
				continue
			var grid: Array = matchup.get("%s|%s" % [a, b], [0, 0])
			line.append("%6.0f%%" % (100.0 * float(int(grid[0])) / float(maxi(1, int(grid[1])))))
		print(" ".join(line))


func averages(acc: Dictionary) -> String:
	var n: float = float(maxi(1, int(acc["n"])))
	return "%5.1f life /%4.1f seals /%4.0f%% asc" % [
		float(acc["survival"]) / n, float(acc["seal"]) / n, 100.0 * float(acc["ascension"]) / n,
	]


func rate(t: Dictionary) -> float:
	return float(int(t["won"])) / float(maxi(1, int(t["played"])))


func counts_of(counts: Dictionary) -> String:
	var out: PackedStringArray = []
	for r in REASONS:
		out.append(str(int(counts.get(r, 0))))
	return "/".join(out)


func write_tsv(path: String, rows: Array[String]) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("could not write %s" % path)
		return
	f.store_line("pilot\tfoe\tpilot_seat\twinner\treason\tturn\tpilot_life\tpilot_seals_missing\tpilot_asc_left\tfoe_life\tfoe_seals_missing\tfoe_asc_left")
	for r in rows:
		f.store_line(r)
	f.close()
	print("")
	print("wrote %s (%d matches)" % [path, rows.size()])


func deck_names(wanted: String) -> Array[String]:
	var names: Array[String] = []
	if wanted != "":
		for n in wanted.split(","):
			names.append(n)
		return names
	var dir: DirAccess = DirAccess.open("res://data/decks")
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.ends_with(".json"):
			names.append(entry.trim_suffix(".json"))
		entry = dir.get_next()
	names.sort()
	return names


## null means uniform random play.
func make_player(policy: String, args: Dictionary, seed_value: int, deck: DeckList, deck_name: String = "") -> AiPlayer:
	var force_sequence: bool = search_decks.has(deck_name)
	if policy == "random" and not force_sequence:
		return null
	var level: String = "" if policy in ["scorer", "search", "random"] else policy
	var profile: AiProfile = AiProfile.for_deck(deck, level)
	if policy == "scorer":
		profile.merge({"think": {"search": false}})
	if force_sequence:
		profile.merge({"think": {"search": true, "algorithm": "sequence"}})
	var over: Dictionary = {}
	if str(args["budget"]) != "":
		over["budget_ms"] = int(args["budget"])
	if str(args["samples"]) != "":
		over["samples"] = int(args["samples"])
	if not over.is_empty():
		profile.merge({"think": over})
	return AiPlayer.new(profile, seed_value)
