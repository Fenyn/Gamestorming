extends SceneTree
## Per card of one deck: how often it reaches the hand, how often it is then played, how often it
## leaves the hand unplayed (discarded, burned for a cost), and how often it is still held when
## the game ends. With the win rate of the games it was played in beside the deck's own, a card
## that is drawn and never cast, or cast and never matters, stands out.
##
## godot --headless --path zenith -s tests/card_usage_probe.gd -- --deck=shade_salvage --repeats=4
## `--deck-dir=` fields a trial list by exact name, as matchlab does.

const MAX_STEPS: int = 6000
const PLAYS: Array[StringName] = [&"attack", &"use", &"place", &"defend", &"counter", &"relic"]


func _init() -> void:
	var args: Dictionary = {"deck": "shade_salvage", "repeats": "4", "seed": "77", "policy": "scorer", "budget": "", "deck-dir": ""}
	for raw in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var me: String = str(args["deck"])
	var my_path: String = "res://data/decks/%s.json" % me
	if str(args["deck-dir"]) != "" and FileAccess.file_exists(str(args["deck-dir"]).path_join(me + ".json")):
		my_path = str(args["deck-dir"]).path_join(me + ".json")
	# `--skip=a,b` leaves those decks out of the field, such as the list a trial copy replaces.
	var skip: PackedStringArray = str(args.get("skip", "")).split(",", false)
	var foes: Array[String] = []
	for file in DirAccess.get_files_at("res://data/decks"):
		var foe: String = file.trim_suffix(".json")
		if file.ends_with(".json") and foe != me and not skip.has(foe):
			foes.append(foe)
	foes.sort()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(args["seed"])
	var stats: Dictionary = {}   # id -> counters
	var games: int = 0
	var wins: int = 0
	for r in range(int(args["repeats"])):
		for foe in foes:
			for seat in [0, 1]:
				games += 1
				var decks: Array[DeckList] = [null, null]
				decks[seat] = DeckList.load_from(my_path)
				decks[1 - seat] = DeckList.load_from("res://data/decks/%s.json" % foe)
				var ref: Referee = Referee.new()
				ref.setup(decks, lib, table, rng.randi(), [], false)
				ref.start()
				ref.engine.take_events()
				var players: Array[AiPlayer] = [
					AiPlayer.new(SimSeat.from_legacy(str(args["policy"]), args).make_profile(decks[0]), games * 2),
					AiPlayer.new(SimSeat.from_legacy(str(args["policy"]), args).make_profile(decks[1]), games * 2 + 1),
				]
				var eng: DuelEngine = ref.engine
				var p: PlayerState = eng.state.players[seat]
				var held: Dictionary = {}      # uid -> id, our hand as last seen
				var drawn: Dictionary = {}     # uid -> true once seen in hand
				var played_ids: Dictionary = {}
				var played_uids: Dictionary = {}
				var steps: int = 0
				_sync_hand(p, held, drawn, stats)
				while not ref.is_over() and steps < MAX_STEPS:
					steps += 1
					var who: int = eng.prompt.player
					var chosen: Dictionary = players[who].choose(ref, who)
					if who == seat:
						var uid: int = int(chosen.get("card", -1))
						if held.has(uid) and PLAYS.has(StringName(str(chosen.get("type", "")))):
							played_uids[uid] = true
							played_ids[held[uid]] = true
							_bump(stats, held[uid], "played")
					ref.submit(who, chosen)
					eng.take_events()
					for uid in held.keys():
						var c: CardInstance = eng.card(uid)
						if c == null or c.zone != &"hand" or c.controller != seat:
							if not played_uids.has(uid):
								_bump(stats, held[uid], "lost")
							held.erase(uid)
					_sync_hand(p, held, drawn, stats)
				var won: bool = ref.is_over() and eng.state.winner == seat
				if won:
					wins += 1
				for uid in held:
					_bump(stats, held[uid], "stuck")
				var drawn_ids: Dictionary = {}
				for uid in drawn:
					var dc: CardInstance = eng.card(uid)
					if dc != null:
						drawn_ids[dc.def.id] = true
				for id in drawn_ids:
					_bump(stats, id, "drawn_games")
					if won:
						_bump(stats, id, "drawn_wins")
				for id in played_ids:
					_bump(stats, id, "played_games")
					if won:
						_bump(stats, id, "played_wins")

	# `--tsv=` writes the raw counts, so runs on different seeds can be added together.
	if str(args.get("tsv", "")) != "":
		var f: FileAccess = FileAccess.open(str(args["tsv"]), FileAccess.WRITE)
		f.store_line("#games\t%d\t%d" % [games, wins])
		for id in stats:
			var s: Dictionary = stats[id]
			var row: PackedStringArray = [id]
			for key in ["drawn", "played", "lost", "stuck", "played_games", "played_wins", "drawn_games", "drawn_wins"]:
				row.append(str(int(s.get(key, 0))))
			f.store_line("\t".join(row))
		f.close()
	var base: float = 100.0 * float(wins) / float(maxi(1, games))
	print("%s: %d games, %d wins (%.1f%%)" % [me, games, wins, base])
	print("%-26s %-34s %6s %6s %6s %6s %8s" % ["id", "title", "drawn", "played", "lost", "stuck", "win%|pl"])
	var ids: Array = stats.keys()
	ids.sort_custom(func(a, b): return float(stats[a].get("drawn", 0)) > float(stats[b].get("drawn", 0)))
	for id in ids:
		var s: Dictionary = stats[id]
		var pg: int = int(s.get("played_games", 0))
		print("%-26s %-34s %6.2f %6.2f %6.2f %6.2f %8s" % [id, lib.get_def(id).title.left(34),
			_per(s, "drawn", games), _per(s, "played", games), _per(s, "lost", games), _per(s, "stuck", games),
			("%.0f" % (100.0 * float(s.get("played_wins", 0)) / float(pg))) if pg >= 10 else "-"])
	quit()


func _sync_hand(p: PlayerState, held: Dictionary, drawn: Dictionary, stats: Dictionary) -> void:
	for c in p.hand:
		if not held.has(c.uid):
			held[c.uid] = c.def.id
			if not drawn.has(c.uid):
				drawn[c.uid] = true
				_bump(stats, c.def.id, "drawn")


func _bump(stats: Dictionary, id: String, key: String) -> void:
	if not stats.has(id):
		stats[id] = {}
	stats[id][key] = int(stats[id].get(key, 0)) + 1


func _per(s: Dictionary, key: String, games: int) -> float:
	return float(int(s.get(key, 0))) / float(maxi(1, games))
