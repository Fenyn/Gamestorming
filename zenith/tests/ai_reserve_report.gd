extends SceneTree
## Prints what the AI reads in each deck's setup cards and what it would bring in from the Reserve
## against each opponent, with the score of every Reserve card.
## godot --headless --path zenith -s tests/ai_reserve_report.gd


func _init() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var names: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://data/decks")
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.ends_with(".json"):
			names.append(entry.trim_suffix(".json"))
		entry = dir.get_next()
	names.sort()
	for mine in names:
		print("== %s" % mine)
		for theirs in names:
			var decks: Array[DeckList] = [DeckList.load_from("res://data/decks/%s.json" % mine), DeckList.load_from("res://data/decks/%s.json" % theirs)]
			var e: DuelEngine = DuelEngine.new()
			e.shuffle_decks = false
			e.setup(decks, lib, table, 1)
			var profile: AiProfile = AiProfile.for_deck(decks[0], "")
			if theirs == names[0]:
				print("   reads as: %s" % str(AiReserve.read_setup(e.player(0))))
			var parts: PackedStringArray = PackedStringArray()
			var seen: Dictionary = {}
			for c in e.player(0).reserve:
				if seen.has(c.def.id):
					continue
				seen[c.def.id] = true
				var s: float = AiReserve.score(e, 0, c, profile)
				parts.append("%s%s %s" % ["+" if s > 0.0 else "", c.def.title, "never" if s == -INF else "%.1f" % s])
			print("   vs %-18s %s" % [theirs, ", ".join(parts)])
	quit(0)
