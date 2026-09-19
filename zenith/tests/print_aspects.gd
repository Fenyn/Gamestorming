extends SceneTree
## Prints the generated rules text of a personality's Aspects, which `print_text.gd` leaves out.
## godot --headless --path zenith -s tests/print_aspects.gd -- duelist_iota companion_epsilon


func _init() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var ids: Array = OS.get_cmdline_user_args()
	if ids.is_empty():
		for id in lib.defs.keys():
			if (lib.defs[id] as CardDef).type == CardDef.Type.PERSONALITY:
				ids.append(id)
		ids.sort()
	for id in ids:
		var def: CardDef = lib.defs.get(id)
		if def == null:
			print("%s: no such card" % id)
			continue
		print("%s (%s)" % [id, def.title])
		for a in def.aspects:
			var n: int = int((a as Dictionary).get("aspect", 0))
			print("  %d %s | %s" % [n, str((a as Dictionary).get("title", "")), " ".join(CardText.aspect_text(def, n))])
	quit(0)
