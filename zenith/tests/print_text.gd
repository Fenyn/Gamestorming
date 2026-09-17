extends SceneTree
## Prints the generated rules text of shipped cards, for the roster and for a quick read.
## godot --headless --path zenith -s tests/print_text.gd -- ember_mastery steel_triple_blast


func _init() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	for id in OS.get_cmdline_user_args():
		var def: CardDef = lib.defs.get(id)
		print("%s: %s" % [id, CardText.rules_text(def).replace("\n", " ") if def != null else "no such card"])
	quit(0)
