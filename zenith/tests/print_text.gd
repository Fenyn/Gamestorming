extends SceneTree
## Prints the generated rules text of shipped cards, for the roster and for a quick read.
## godot --headless --path zenith -s tests/print_text.gd -- pyre_mastery steel_triple_blast
## With no card ids it prints every shipped card, which is what `tools/audit_sources.py` reads.


func _init() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var ids: Array = OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = lib.defs.keys()
		ids.sort()
	for id in ids:
		var def: CardDef = lib.defs.get(id)
		print("%s: %s" % [id, CardText.rules_text(def).replace("\n", " ") if def != null else "no such card"])
	quit(0)
