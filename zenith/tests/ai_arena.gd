extends SceneTree
## Plays AI policies against each other across the starter decks and reports who wins and how
## long a decision takes. Every pairing is played from both seats.
## godot --headless --path zenith -s tests/ai_arena.gd -- --a=search --b=scorer --seeds=1
## Policies: random, scorer, search, or a profile name under data/ai/profiles (easy, hard).
## Options: --seeds=N, --decks=ember_beatdown,storm_volley (default all), --budget=MS and
## --samples=N for searching policies, --verbose for a line per game. A deck's own playstyle
## profile (`ai_profile` in its JSON) is used unless --styles=a, --styles=b or --styles=none says
## which policies get one; that is how a playstyle is measured against the defaults.

const MAX_STEPS: int = 6000


func _init() -> void:
	var args: Dictionary = {"a": "scorer", "b": "random", "seeds": "1", "decks": "", "budget": "", "samples": "", "verbose": "", "styles": "ab"}
	for raw in OS.get_cmdline_user_args():
		var text: String = raw.trim_prefix("--")
		var parts: PackedStringArray = text.split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var names: Array[String] = deck_names(str(args["decks"]))
	var policies: Array[String] = [str(args["a"]), str(args["b"])]
	var wins: Array[int] = [0, 0]
	var unfinished: int = 0
	var games: int = 0
	var reasons: Dictionary = {}
	var by_deck: Dictionary = {}     # deck -> [wins as policy a, games as policy a]
	var think_usec: Array[int] = [0, 0]
	var decisions: Array[int] = [0, 0]
	var slowest_usec: Array[int] = [0, 0]
	for deck_a in names:
		for deck_b in names:
			for s in range(int(args["seeds"])):
				for a_seat in range(2):
					# Policy a plays deck_a in seat `a_seat`; policy b plays deck_b in the other.
					var decks: Array[DeckList] = [null, null]
					decks[a_seat] = DeckList.load_from("res://data/decks/%s.json" % deck_a)
					decks[1 - a_seat] = DeckList.load_from("res://data/decks/%s.json" % deck_b)
					var ref: Referee = Referee.new()
					ref.setup(decks, lib, table, 100 + s)
					ref.start()
					var seats: Array[int] = [a_seat, 1 - a_seat]
					var players: Array[AiPlayer] = [null, null]
					for i in range(2):
						var styled: bool = str(args["styles"]).contains("ab"[i])
						players[seats[i]] = make_player(policies[i], args, games * 2 + i + 1, decks[seats[i]] if styled else null)
					var picker: RandomNumberGenerator = RandomNumberGenerator.new()
					picker.seed = games + 1
					var steps: int = 0
					while not ref.is_over() and steps < MAX_STEPS:
						steps += 1
						var seat: int = ref.engine.prompt.player
						var who: int = 0 if seat == a_seat else 1
						var wire: Dictionary = {}
						var t0: int = Time.get_ticks_usec()
						if players[seat] == null:
							var opts: Array[Command] = ref.engine.prompt.options
							wire = opts[picker.randi_range(0, opts.size() - 1)].to_dict()
						else:
							wire = players[seat].choose(ref, seat)
						var spent: int = Time.get_ticks_usec() - t0
						think_usec[who] += spent
						decisions[who] += 1
						slowest_usec[who] = maxi(slowest_usec[who], spent)
						var problem: String = ref.submit(seat, wire)
						if problem != "":
							print("ILLEGAL %s chose %s at %s: %s" % [policies[who], str(wire), ref.engine.prompt.describe(), problem])
							quit(1)
							return
						ref.engine.take_events()
					games += 1
					var tally: Array = by_deck.get(deck_a, [0, 0])
					tally[1] = int(tally[1]) + 1
					if ref.is_over():
						var winner: int = 0 if ref.engine.state.winner == a_seat else 1
						wins[winner] += 1
						if winner == 0:
							tally[0] = int(tally[0]) + 1
						var key: String = "%s:%s" % [policies[winner], ref.engine.state.win_reason]
						reasons[key] = int(reasons.get(key, 0)) + 1
					else:
						unfinished += 1
						print("UNFINISHED %s(%s) vs %s(%s) seed %d seat %d at turn %d: %s" % [policies[0], deck_a, policies[1], deck_b, s, a_seat, ref.engine.state.turn, ref.engine.prompt.describe()])
					by_deck[deck_a] = tally
					if str(args["verbose"]) != "":
						print("%s(%s) vs %s(%s) seed %d seat %d: winner %s by %s in %d steps" % [policies[0], deck_a, policies[1], deck_b, s, a_seat, policies[0] if ref.engine.state.winner == a_seat else policies[1], ref.engine.state.win_reason, steps])
	print("games %d, unfinished %d" % [games, unfinished])
	for i in range(2):
		print("%s: %d wins (%.1f%%), %.2f ms per decision, slowest %.0f ms" % [policies[i], wins[i], 100.0 * wins[i] / maxi(1, games), think_usec[i] / 1000.0 / maxi(1, decisions[i]), slowest_usec[i] / 1000.0])
	print("win reasons %s" % str(reasons))
	for d in names:
		var t: Array = by_deck.get(d, [0, 0])
		print("  %s as %s: %d of %d" % [d, policies[0], int(t[0]), int(t[1])])
	quit(1 if unfinished > 0 else 0)


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
