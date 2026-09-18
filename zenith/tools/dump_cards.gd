extends SceneTree
## Dumps every shipped card as JSON lines (id, title, type line, school, type, character, rules text,
## one entry per Aspect for Duelists) for the roster generator. Usage:
## godot --headless --path zenith -s tools/dump_cards.gd -- <out.jsonl>


func _init() -> void:
	var lib: CardLibrary = CardLibrary.new()
	lib.load_dir("res://data/cards")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: FileAccess = FileAccess.open(args[0] if args.size() > 0 else "user://cards.jsonl", FileAccess.WRITE)
	var ids: Array = lib.defs.keys()
	ids.sort()
	for id in ids:
		var def: CardDef = lib.defs[id]
		if def.is_personality():
			for t in def.aspects:
				var aspect: int = int(t.get("aspect", 0))
				out.store_line(JSON.stringify({
					"id": "%s_a%d" % [def.id, aspect], "base": def.id, "aspect": aspect,
					"title": "%s, %s" % [def.title, CardText.aspect_name(aspect, def)],
					"type_line": CardText.type_line(def), "school": def.school, "type": CardText.type_label(def),
					"character": def.character,
					"text": "Surge %d. %s" % [int(t.get("surge", 0)), " ".join(CardText.aspect_text(def, aspect))],
				}))
		else:
			out.store_line(JSON.stringify({
				"id": def.id, "base": def.id, "aspect": 0, "title": def.title,
				"type_line": CardText.type_line(def), "school": def.school, "type": CardText.type_label(def),
				"character": def.character, "text": CardText.rules_text(def).replace("\n", " "),
			}))
	out.close()
	quit(0)
