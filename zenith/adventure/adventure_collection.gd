class_name AdventureCollection
extends RefCounted
## The permanent card collection: one row per card id with a copy count. It is a library, not a
## box of cards. A run copies out of it and never takes anything away, so a card swapped into a
## starter is still there for the next run.
##
## The cap per id is what a deck may legally run, read off DeckValidator's own constants: there is
## no reason to hold four of a card printed at three.

const PATH: String = "user://adventure/collection.json"
const SAVE_VERSION: int = 1

## Tests point this somewhere else so nothing lands on the player's save.
static var path_override: String = ""

var counts: Dictionary = {}   # id -> int copies held


static func path() -> String:
	return path_override if path_override != "" else PATH


func copies(id: String) -> int:
	return int(counts.get(id, 0))


## The most copies of `id` the collection will hold: what DeckValidator would allow a deck to run.
## A personality and a Seal are one apiece; a card named for a character allows the signature
## fourth, unless it prints a tighter limit of its own; everything else is its printed limit.
## 0 for a card the library does not know.
static func cap(id: String, library: CardLibrary) -> int:
	var def: CardDef = library.defs.get(id)
	if def == null:
		return 0
	if def.type == CardDef.Type.SEAL or def.type == CardDef.Type.PERSONALITY:
		return 1
	if def.is_signature() and def.limit_per_deck >= DeckValidator.DEFAULT_LIMIT:
		return DeckValidator.SIGNATURE_LIMIT
	return def.limit_per_deck


## Room left for `id` before the cap.
func room_for(id: String, library: CardLibrary) -> int:
	return maxi(0, AdventureCollection.cap(id, library) - copies(id))


## Adds up to `n` copies, stopping at the cap. Returns how many actually landed.
func add(id: String, n: int, library: CardLibrary) -> int:
	if n <= 0:
		return 0
	var added: int = mini(n, room_for(id, library))
	if added <= 0:
		return 0
	counts[id] = copies(id) + added
	return added


## Takes up to `n` copies away. Returns how many actually went.
func remove(id: String, n: int) -> int:
	if n <= 0:
		return 0
	var gone: int = mini(n, copies(id))
	if gone <= 0:
		return 0
	var left: int = copies(id) - gone
	if left > 0:
		counts[id] = left
	else:
		counts.erase(id)
	return gone


## Dissolves one copy into Motes, paid into `wallet`. Returns the Motes paid, 0 when there was no
## copy to dissolve.
func dissolve(id: String, library: CardLibrary, wallet: AdventureWallet) -> int:
	var def: CardDef = library.defs.get(id)
	if def == null or copies(id) <= 0:
		return 0
	var value: int = AdventureEconomy.dissolve_value(def)
	remove(id, 1)
	if wallet != null and value > 0:
		wallet.earn(value, AdventureWallet.REASON_DISSOLVE, id)
	return value


## Every id held, sorted, so a screen lists the collection the same way twice.
func all_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(counts.keys())
	out.sort()
	return out


## Copies held across every id.
func total_copies() -> int:
	var n: int = 0
	for id in counts.keys():
		n += int(counts[id])
	return n


## True when the collection holds as many copies of `id` as it ever will.
func is_full(id: String, library: CardLibrary) -> bool:
	return room_for(id, library) <= 0


func to_dict() -> Dictionary:
	var rows: Dictionary = {}
	for id in all_ids():
		rows[id] = copies(id)
	return {"version": SAVE_VERSION, "cards": rows}


## Tolerant of JSON, which hands every number back as a float.
static func from_dict(d: Dictionary) -> AdventureCollection:
	var c: AdventureCollection = AdventureCollection.new()
	var rows: Dictionary = d.get("cards", {})
	for id in rows.keys():
		var n: int = int(rows[id])
		if n > 0:
			c.counts[str(id)] = n
	return c


## The saved collection, or an empty one when there is no file yet. Never null.
static func load_collection() -> AdventureCollection:
	var file: String = path()
	if not FileAccess.file_exists(file):
		return AdventureCollection.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not (parsed is Dictionary):
		push_error("AdventureCollection: %s is not a JSON object" % file)
		return AdventureCollection.new()
	return AdventureCollection.from_dict(parsed)


func save() -> bool:
	var file: String = AdventureCollection.path()
	var dir: String = file.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var handle: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	if handle == null:
		push_error("AdventureCollection: cannot write %s" % file)
		return false
	handle.store_string(JSON.stringify(to_dict(), "  "))
	handle.close()
	return true


static func exists() -> bool:
	return FileAccess.file_exists(path())


static func clear() -> void:
	var file: String = path()
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
