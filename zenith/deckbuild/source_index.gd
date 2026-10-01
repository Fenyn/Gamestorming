class_name SourceIndex
extends RefCounted
## Which of our cards parallel a reference-game card, looked up by name. The index holds only the
## sha256 of each normalised name, so the names themselves never ship. Built by
## tools/gen_source_index.py; `normalise` must stay identical to the one there.

const PATH: String = "res://data/import/source_index.json"

## name digest -> Array of {"id": String, "set": String digest of the printing's set, may be absent}
var names: Dictionary = {}

static var _strip: RegEx = RegEx.create_from_string("['’`]")
static var _runs: RegEx = RegEx.create_from_string("[^a-z0-9]+")
static var _level: RegEx = RegEx.create_from_string("(?i)\\b(?:lv|level)\\.?\\s*(\\d)\\b")
static var _print_number: RegEx = RegEx.create_from_string("\\d+\\s*$")


static func normalise(text: String) -> String:
	var out: String = _strip.sub(text.to_lower(), "", true)
	return _runs.sub(out, " ", true).strip_edges()


## The set named in a bracket or suffix, without a level or a print number, normalised.
static func set_hint(bracket: String) -> String:
	var hint: String = _level.sub(bracket, "", true).split(";")[0].replace(",", " ")
	return normalise(_print_number.sub(hint.strip_edges(), ""))


## The level a name or bracket gives ("Lv 3", "Level 3"), 0 for none.
static func level_in(text: String) -> int:
	var found: RegExMatch = _level.search(text)
	return int(found.get_string(1)) if found != null else 0


static func digest(text: String) -> String:
	return normalise(text).sha256_text()


static func load_from(path: String) -> SourceIndex:
	var index: SourceIndex = SourceIndex.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var table: Variant = (parsed as Dictionary).get("names", {})
		if table is Dictionary:
			index.names = table
	return index


static func shipped() -> SourceIndex:
	return load_from(PATH)


## Every card id that parallels `name`. `set_hint` is a `set_hint()` result: printings from that
## set win when any match, and every printing is returned otherwise.
func ids_for(name: String, set_hint: String = "") -> Array[String]:
	var out: Array[String] = []
	var entries: Variant = names.get(digest(name), [])
	if not (entries is Array):
		return out
	var hint: String = set_hint.sha256_text() if set_hint != "" else ""
	for entry: Variant in entries:
		if entry is Dictionary and hint != "" and str((entry as Dictionary).get("set", "")) == hint:
			out.append(str((entry as Dictionary).get("id", "")))
	if not out.is_empty():
		return out
	for entry: Variant in entries:
		if entry is Dictionary:
			out.append(str((entry as Dictionary).get("id", "")))
	return out


func has_name(name: String) -> bool:
	return names.has(digest(name))
