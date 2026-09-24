class_name AdventureDecks
extends RefCounted
## Where the adventure's decks live and how their ids read: the starters a run can begin from, the
## opponent bands, and the family and tier an opponent id names. The run's opponents themselves
## come from the node map (AdventureMap).

const STARTERS_DIR: String = "res://data/adventure/starters"
const BANDS: String = "res://data/adventure/opponent_bands.json"
## The deck-id suffixes that mark a starter or an opponent tier; strip one to get the family.
const SUFFIXES: Array[String] = ["_start", "_t1", "_t2", "_t3", "_t4", "_t5", "_boss"]


## band -> families, as written; a family is the deck id without its tier suffix.
static func read_bands() -> Dictionary:
	if not FileAccess.file_exists(BANDS):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BANDS))
	return parsed if parsed is Dictionary else {}


## Every band's families, flattened and sorted.
static func banded_families() -> Array[String]:
	var out: Array[String] = []
	var bands: Dictionary = read_bands()
	for band in bands.keys():
		for f in bands[band]:
			if not out.has(str(f)):
				out.append(str(f))
	out.sort()
	return out


## Starter ids, sorted: every deck file in the starters folder.
static func playable_starters() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(STARTERS_DIR)
	if dir == null:
		return out
	for entry in dir.get_files():
		if entry.ends_with(".json"):
			out.append(entry.trim_suffix(".json"))
	out.sort()
	return out


static var _characters: Dictionary = {}   # family -> Duelist character
static var _library: CardLibrary = null


## The character a family's Duelist is, read off its precon. "" when the precon or its Duelist
## card cannot be found.
static func character_of(family: String) -> String:
	if _characters.has(family):
		return str(_characters[family])
	if _library == null:
		_library = CardLibrary.new()
		_library.load_dir("res://data/cards")
	var character: String = ""
	var path: String = "res://data/decks/%s.json" % family
	if FileAccess.file_exists(path):
		var face: String = DeckList.load_from(path).duelist_face_id()
		if _library.has(face):
			var def: CardDef = _library.defs[face]
			character = def.character
	_characters[family] = character
	return character


## Every banded family whose Duelist is the same character as `family`'s, `family` included. Edric
## runs two decks, so a run of one of them must not meet the other as a random opponent.
static func same_character_families(family: String) -> Array[String]:
	var out: Array[String] = [family]
	var character: String = character_of(family)
	if character == "":
		return out
	for f in banded_families():
		if f != family and character_of(f) == character:
			out.append(f)
	return out


## The deck family a starter or opponent id belongs to: the id without its tier suffix.
static func family_of(deck_id: String) -> String:
	for suffix in SUFFIXES:
		if deck_id.ends_with(suffix):
			return deck_id.trim_suffix(suffix)
	return deck_id


## The tier word an opponent deck id ends in: T1..T5 or BOSS.
static func tier_of(opponent_id: String) -> String:
	var parts: PackedStringArray = opponent_id.split("_")
	return parts[parts.size() - 1].to_upper() if parts.size() > 0 else ""


## What every screen calls an opponent: its duelist's title, falling back to the deck name and
## then to the id.
static func opponent_name(opponent_id: String, library: CardLibrary) -> String:
	var deck: DeckList = DeckList.resolve(opponent_id)
	if deck == null:
		return opponent_id
	var duelist: CardDef = library.defs.get(deck.duelist_face_id())
	if duelist != null and duelist.title != "":
		return duelist.title
	return deck.name if deck.name != "" else opponent_id
