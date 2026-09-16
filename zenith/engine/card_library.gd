class_name CardLibrary
extends RefCounted
## All CardDefs loaded from a directory tree of JSON files. Each file holds {"cards": [...]}.

var defs: Dictionary = {}   # id -> CardDef


func load_dir(path: String) -> int:
	var count: int = 0
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_error("CardLibrary: cannot open %s" % path)
		return 0
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				count += load_dir(full)
		elif entry.ends_with(".json"):
			count += load_file(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return count


func load_file(path: String) -> int:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("CardLibrary: %s is not a JSON object" % path)
		return 0
	var cards: Array = parsed.get("cards", [])
	var count: int = 0
	for entry in cards:
		if not (entry is Dictionary):
			continue
		var def: CardDef = CardDef.from_dict(entry)
		if defs.has(def.id):
			push_warning("CardLibrary: duplicate card id %s (from %s)" % [def.id, path])
		defs[def.id] = def
		count += 1
	return count


func has(id: String) -> bool:
	return defs.has(id)


func get_def(id: String) -> CardDef:
	if not defs.has(id):
		push_error("CardLibrary: unknown card id %s" % id)
		return null
	return defs[id]


func all_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(defs.keys())
	out.sort()
	return out
