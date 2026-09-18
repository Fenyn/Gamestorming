extends SceneTree
## Plays the shipped decks against each other headless and reports, per deck, how often it wins and
## by which route. Every deck pilots the same share of the matches, each against a random other deck
## from a random seat, so a deck's record is read over the whole field rather than one pairing.
## This is a deck balance report; `tests/ai_arena.gd` measures AI policies instead.
##
## godot --headless --path zenith -s tests/deck_report.gd -- --games=350
##
## Options: --games=N matches in total (default 200, rounded up to a whole pass over the decks),
## --policy=random|scorer|search or a level name under data/ai/profiles (default scorer, which is
## fast; search is the shipped opponent and far slower), --decks=root_seals,storm_volley to cut the
## field down, --seed=N for a different run, --budget=MS and --samples=N for searching policies,
## --styles=off to play every deck on the default profile, and --verbose for a line per match.

const MAX_STEPS: int = 6000
const REASONS: Array[String] = ["survival", "seal", "ascension"]


func _init() -> void:
	var args: Dictionary = {"games": "200", "policy": "scorer", "decks": "", "seed": "1", "budget": "", "samples": "", "styles": "on", "verbose": ""}
	for raw in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var names: Array[String] = deck_names(str(args["decks"]))
	if names.size() < 2:
		print("need at least two decks")
		quit(1)
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(args["seed"])
	var passes: int = maxi(1, ceili(float(int(args["games"])) / float(names.size())))
	var tally: Dictionary = {}
	for n in names:
		tally[n] = {"played": 0, "won": 0, "win": {}, "loss": {}, "turns": 0}
	var unfinished: int = 0
	var games: int = 0
	for p in range(passes):
		for pilot in names:
			# A random other deck, from a random seat, so neither the field nor the first turn is fixed.
			var foe: String = names[rng.randi_range(0, names.size() - 2)]
			if foe == pilot:
				foe = names[names.size() - 1]
			var seat: int = rng.randi_range(0, 1)
			var decks: Array[DeckList] = [null, null]
			decks[seat] = DeckList.load_from("res://data/decks/%s.json" % pilot)
			decks[1 - seat] = DeckList.load_from("res://data/decks/%s.json" % foe)
			var ref: Referee = Referee.new()
			ref.setup(decks, lib, table, rng.randi())
			ref.start()
			games += 1
			var players: Array[AiPlayer] = [null, null]
			for i in range(2):
				players[i] = make_player(str(args["policy"]), args, games * 2 + i, decks[i] if str(args["styles"]) != "off" else null)
			var steps: int = 0
			while not ref.is_over() and steps < MAX_STEPS:
				steps += 1
				var who: int = ref.engine.prompt.player
				if players[who] == null:
					var opts: Array[Command] = ref.engine.prompt.options
					ref.submit(who, opts[rng.randi_range(0, opts.size() - 1)].to_dict())
				else:
					ref.submit(who, players[who].choose(ref, who))
			var mine: Dictionary = tally[pilot]
			var theirs: Dictionary = tally[foe]
			mine["played"] = int(mine["played"]) + 1
			theirs["played"] = int(theirs["played"]) + 1
			if not ref.is_over():
				unfinished += 1
				print("UNFINISHED %s vs %s at turn %d" % [pilot, foe, ref.engine.state.turn])
				continue
			var reason: String = ref.engine.state.win_reason
			var won: String = pilot if ref.engine.state.winner == seat else foe
			var lost: String = foe if won == pilot else pilot
			mine["turns"] = int(mine["turns"]) + ref.engine.state.turn
			theirs["turns"] = int(theirs["turns"]) + ref.engine.state.turn
			var winner: Dictionary = tally[won]
			winner["won"] = int(winner["won"]) + 1
			bump(winner["win"], reason)
			bump(tally[lost]["loss"], reason)
			if str(args["verbose"]) != "":
				print("%s vs %s: %s wins by %s on turn %d" % [pilot, foe, won, reason, ref.engine.state.turn])
	report(names, tally, games, unfinished)
	quit(1 if unfinished > 0 else 0)


func bump(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


## A deck's line: what share of its matches it won, which route each win took, and which route beat
## it. A deck plays both as the pass's pilot and as someone else's random opponent, so `played` runs
## ahead of the number of passes.
func report(names: Array[String], tally: Dictionary, games: int, unfinished: int) -> void:
	print("%d matches, %d unfinished" % [games, unfinished])
	print("%-18s %6s %6s   %s   %s   %5s" % ["deck", "played", "win%", "won by surv/seal/asc", "lost to surv/seal/asc", "turns"])
	var order: Array[String] = names.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return rate(tally[a]) > rate(tally[b]))
	var totals: Dictionary = {}
	for deck_name in order:
		var t: Dictionary = tally[deck_name]
		var played: int = int(t["played"])
		var wins: Dictionary = t["win"]
		for r in REASONS:
			totals[r] = int(totals.get(r, 0)) + int(wins.get(r, 0))
		print("%-18s %6d %5.1f%%   %20s   %21s   %5.1f" % [
			deck_name, played, 100.0 * rate(t),
			counts_of(t["win"]), counts_of(t["loss"]),
			float(int(t["turns"])) / float(maxi(1, played)),
		])
	print("all wins by route: %s" % counts_of(totals))


func rate(t: Dictionary) -> float:
	return float(int(t["won"])) / float(maxi(1, int(t["played"])))


func counts_of(counts: Dictionary) -> String:
	var out: PackedStringArray = []
	for r in REASONS:
		out.append(str(int(counts.get(r, 0))))
	return "/".join(out)


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
func make_player(policy: String, args: Dictionary, seed_value: int, deck: DeckList) -> AiPlayer:
	if policy == "random":
		return null
	var level: String = "" if policy == "scorer" or policy == "search" else policy
	var profile: AiProfile = AiProfile.for_deck(deck, level)
	if policy == "scorer":
		profile.merge({"think": {"search": false}})
	var over: Dictionary = {}
	if str(args["budget"]) != "":
		over["budget_ms"] = int(args["budget"])
	if str(args["samples"]) != "":
		over["samples"] = int(args["samples"])
	if not over.is_empty():
		profile.merge({"think": over})
	return AiPlayer.new(profile, seed_value)
