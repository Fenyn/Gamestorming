class_name CustomDecks
extends RefCounted
## Player-built decks, one JSON file each under user://decks, in the same format as data/decks.
## The file stem is the deck's id; a deck saved for the first time takes a stem from its name.

const DIR: String = "user://decks"
## Tests point this at a scratch folder.
static var dir_override: String = ""
## A deck name longer than this is cut on save; the lobby shows it beside the player's name.
const NAME_MAX: int = 40
## Wire limits on a custom deck from another player: an id's length and the Reserve's size.
const ID_MAX: int = 64
const RESERVE_MAX: int = 20


static func folder() -> String:
	return dir_override if dir_override != "" else DIR


static func load_all() -> Array[DeckList]:
	var out: Array[DeckList] = []
	var dir: DirAccess = DirAccess.open(folder())
	if dir == null:
		return out
	var names: Array[String] = []
	for entry in dir.get_files():
		if entry.ends_with(".json"):
			names.append(entry)
	names.sort()
	for entry in names:
		if entry.begins_with("."):
			continue
		var deck: DeckList = load_file(folder().path_join(entry))
		if deck != null:
			out.append(deck)
	return out


## One saved deck, or null when the file is not a deck object. A custom deck is always a
## tournament deck with the default AI, whatever the file says.
static func load_file(path: String) -> DeckList:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_warning("CustomDecks: %s is not a deck" % path)
		return null
	var deck: DeckList = DeckList.from_dict(parsed)
	deck.id = path.get_file().get_basename()
	deck.custom = true
	deck.mode = "tournament"
	deck.ai_profile = ""
	return deck


## Writes `deck` and returns its id. A new deck gets a free stem from its name.
static func save(deck: DeckList) -> String:
	DirAccess.make_dir_recursive_absolute(folder())
	deck.name = clean_name(deck.name)
	if deck.id == "":
		deck.id = _free_stem(deck.name)
	deck.custom = true
	var file: FileAccess = FileAccess.open(folder().path_join(deck.id + ".json"), FileAccess.WRITE)
	if file == null:
		push_error("CustomDecks: cannot write %s" % deck.id)
		return ""
	file.store_string(JSON.stringify(deck.to_dict(), "  ", false))
	file.close()
	return deck.id


## When a saved deck's file last changed, in Unix seconds; 0 when it has none.
static func modified(deck_id: String) -> int:
	var path: String = folder().path_join(deck_id + ".json")
	return int(FileAccess.get_modified_time(path)) if FileAccess.file_exists(path) else 0


static func delete(deck_id: String) -> bool:
	var path: String = folder().path_join(deck_id + ".json")
	if deck_id == "" or not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK


## A custom deck sent by another player, rebuilt field by field so nothing malformed reaches
## DeckList, and refused (null) unless it is tournament legal against `library`. Only the fields a
## deck plays with are read; labels and AI settings are dropped.
static func from_wire(raw: Variant, library: CardLibrary) -> DeckList:
	if not (raw is Dictionary):
		return null
	var d: Dictionary = raw
	var clean: Dictionary = {}
	for key: String in ["name", "style", "alignment", "mastery", "relic"]:
		var value: Variant = d.get(key, "")
		if not (value is String) or str(value).length() > ID_MAX:
			return null
		clean[key] = value
	if str(clean["name"]).length() > NAME_MAX:
		return null
	var duelist: Variant = _ids(d.get("duelist", []), DeckValidator.MAX_ASPECTS)
	var reserve: Variant = _ids(d.get("reserve", []), RESERVE_MAX)
	if duelist == null or reserve == null:
		return null
	clean["duelist"] = duelist
	clean["reserve"] = reserve
	var entries: Variant = d.get("cards", [])
	if not (entries is Array) or (entries as Array).size() > DeckValidator.MAX_CARDS_ROOT:
		return null
	var cards: Array[Dictionary] = []
	for entry: Variant in entries:
		if not (entry is Dictionary):
			return null
		var id: Variant = (entry as Dictionary).get("id")
		var count: Variant = (entry as Dictionary).get("count", 1)
		if not (id is String) or str(id).length() > ID_MAX or not (count is int or count is float):
			return null
		var n: int = int(count)
		if float(n) != float(count) or n < 1 or n > DeckValidator.SIGNATURE_LIMIT:
			return null
		cards.append({"id": id, "count": n})
	clean["cards"] = cards
	var deck: DeckList = DeckList.from_dict(clean)
	deck.custom = true
	if not DeckValidator.validate(deck, library).is_empty():
		return null
	return deck


static func _ids(raw: Variant, most: int) -> Variant:
	if not (raw is Array) or (raw as Array).size() > most:
		return null
	var out: Array[String] = []
	for id: Variant in raw:
		if not (id is String) or str(id).length() > ID_MAX:
			return null
		out.append(id)
	return out


## The deck being edited, kept after every edit so a crash or a closed window loses nothing. The
## leading dot keeps it out of `load_all`.
const DRAFT_FILE: String = ".draft.json"
## A deck code: this prefix, then the deck file deflated and base64 encoded, on one line.
const CODE_PREFIX: String = "EIDO1:"


static func save_draft(deck: DeckList) -> void:
	DirAccess.make_dir_recursive_absolute(folder())
	var file: FileAccess = FileAccess.open(folder().path_join(DRAFT_FILE), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"id": deck.id, "deck": deck.to_dict()}))


## The kept draft, or null when there is none.
static func load_draft() -> DeckList:
	var path: String = folder().path_join(DRAFT_FILE)
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("deck") is Dictionary):
		return null
	var deck: DeckList = DeckList.from_dict((parsed as Dictionary)["deck"])
	deck.id = str((parsed as Dictionary).get("id", ""))
	deck.custom = true
	return deck


static func clear_draft() -> void:
	var path: String = folder().path_join(DRAFT_FILE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func to_code(deck: DeckList) -> String:
	var bytes: PackedByteArray = JSON.stringify(deck.to_dict()).to_utf8_buffer()
	return CODE_PREFIX + "%d:" % bytes.size() + Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_DEFLATE))


## The deck file a code holds, or "" when the text is not a deck code.
static func code_text(text: String) -> String:
	var s: String = text.strip_edges()
	if not s.begins_with(CODE_PREFIX):
		return ""
	var body: String = s.substr(CODE_PREFIX.length())
	var size: int = int(body.get_slice(":", 0))
	if size <= 0 or size > 1 << 20:
		return ""
	var packed: PackedByteArray = Marshalls.base64_to_raw(body.get_slice(":", 1))
	return packed.decompress(size, FileAccess.COMPRESSION_DEFLATE).get_string_from_utf8()


static func clean_name(text: String) -> String:
	var s: String = text.strip_edges().replace("\n", " ").replace("\t", " ")
	if s == "":
		s = "New deck"
	return s.substr(0, NAME_MAX)


static func _free_stem(deck_name: String) -> String:
	var stem: String = SourceIndex.normalise(deck_name).replace(" ", "_")
	if stem == "":
		stem = "deck"
	var out: String = stem
	var n: int = 2
	while FileAccess.file_exists(folder().path_join(out + ".json")):
		out = "%s_%d" % [stem, n]
		n += 1
	return out
