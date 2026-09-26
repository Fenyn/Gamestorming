class_name AdventureCollection
extends RefCounted
## The permanent card collection: one row per card id with a copy count. It is a library, not a
## box of cards. A run copies out of it and never takes anything away, so a card swapped into a
## starter is still there for the next run.
##
## The collection holds at most three copies of a normal card and four of a card named for a
## character. Personalities and Seals are one apiece. A card that prints a tighter limit of its own
## keeps that lower number, because there is no reason to hold three of a card printed at two.
##
## Anything past the cap dissolves into Motes on the spot rather than sitting unusable. The settle
## screen and the vendor stop selling at the cap instead, so nobody pays full price for a copy that
## would dissolve for a quarter; the auto-dissolve is for a saved row whose card's cap has since
## dropped and any other path that lands copies the collection cannot hold.

const PATH: String = "user://adventure/collection.json"
const SAVE_VERSION: int = 2

## The most copies of a normal card, and of a card named for a character.
const CAP_NORMAL: int = 3
const CAP_SIGNATURE: int = 4

## Tests point this somewhere else so nothing lands on the player's save.
static var path_override: String = ""

var counts: Dictionary = {}   # id -> int copies held


static func path() -> String:
	return path_override if path_override != "" else PATH


func copies(id: String) -> int:
	return int(counts.get(id, 0))


## The most copies of `id` the collection will hold: three for a normal card, four for a card named
## for a character, one for a personality or a Seal. A card that prints a limit below three keeps
## that lower number; a printed limit is the tighter rule and wins. 0 for a card the library does
## not know.
static func cap(id: String, library: CardLibrary) -> int:
	var def: CardDef = library.defs.get(id)
	if def == null:
		return 0
	if def.type == CardDef.Type.SEAL or def.type == CardDef.Type.PERSONALITY:
		return 1
	if def.limit_per_deck < DeckValidator.DEFAULT_LIMIT:
		return def.limit_per_deck
	return CAP_SIGNATURE if def.is_signature() else CAP_NORMAL


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


## Adds `n` copies and dissolves whatever will not fit, paying `wallet` for each dissolved copy.
## This is the path for copies that land past the cap; the settle screen and the vendor stop at the
## cap instead. Returns a report: {"added", "copies", "motes", "rows"}, where `copies` is how many
## dissolved and `rows` is one {"id", "copies", "motes"} per id.
func bank(id: String, n: int, library: CardLibrary, wallet: AdventureWallet) -> Dictionary:
	var report: Dictionary = {"added": 0, "copies": 0, "motes": 0, "rows": []}
	if n <= 0 or not library.defs.has(id):
		return report
	var added: int = add(id, n, library)
	report["added"] = added
	var spare: int = n - added
	if spare > 0:
		_dissolve_into(report, id, spare, library, wallet)
	return report


## Trims every row back to its cap, paying `wallet` the dissolve value of each copy taken. Returns
## the same report shape as `bank`, with "added" always 0. Cheap and safe to call on a collection
## that is already within its caps: it reports nothing and touches nothing.
func trim_to_cap(library: CardLibrary, wallet: AdventureWallet) -> Dictionary:
	var report: Dictionary = {"added": 0, "copies": 0, "motes": 0, "rows": []}
	for id in all_ids():
		var over: int = copies(id) - AdventureCollection.cap(id, library)
		if over <= 0:
			continue
		remove(id, over)
		_dissolve_into(report, id, over, library, wallet)
	return report


## Pays `n` copies of `id` back as Motes and records the row. The copies are already gone from the
## counts (or never landed), so this only prices them and credits the wallet.
func _dissolve_into(report: Dictionary, id: String, n: int, library: CardLibrary,
		wallet: AdventureWallet) -> void:
	var def: CardDef = library.defs.get(id)
	if def == null or n <= 0:
		return
	var motes: int = AdventureEconomy.dissolve_value(def) * n
	if wallet != null and motes > 0:
		wallet.earn(motes, AdventureWallet.REASON_DISSOLVE, id)
	report["copies"] = int(report["copies"]) + n
	report["motes"] = int(report["motes"]) + motes
	(report["rows"] as Array).append({"id": id, "copies": n, "motes": motes})


## The one line a screen shows for a report, or "" when nothing dissolved.
static func report_line(report: Dictionary) -> String:
	var copies_value: int = int(report.get("copies", 0))
	if copies_value <= 0:
		return ""
	return "%d %s dissolved for %d Motes" % [
		copies_value, "copy" if copies_value == 1 else "copies", int(report.get("motes", 0))]


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
	return AdventureCollection.from_dict(parsed as Dictionary)


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
