extends SceneTree
## Checks every adventure starter against DeckValidator in adventure mode.
## godot --headless --path zenith -s tools/validate_starters.gd

func _init() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var bad: int = 0
	var seen: int = 0
	for source in ["res://data/adventure/starters", "res://data/adventure/opponents"]:
		var dir: DirAccess = DirAccess.open(source)
		if dir == null:
			continue
		for entry in dir.get_files():
			if not entry.ends_with(".json"):
				continue
			seen += 1
			var deck: DeckList = DeckList.load_from(source + "/" + entry)
			var problems: Array[String] = DeckValidator.validate(deck, lib)
			var label: String = entry.trim_suffix(".json")
			if problems.is_empty():
				print("ok   %-26s %d cards, %d aspects" % [label, deck.total_cards(), deck.duelist_ids.size()])
			else:
				bad += 1
				print("FAIL %-26s %s" % [label, ", ".join(problems)])
	print("%d adventure decks, %d with problems" % [seen, bad])
	quit(1 if bad > 0 else 0)
