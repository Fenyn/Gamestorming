class_name AdventureUpgrades
extends RefCounted
## Deck slots bought with Motes, per starter, and kept for good.
##
## A starter begins at the size its own file prints. A bought slot raises that starter's loadout
## size cap by one; the loadout fills it with any legal pick from the collection, and a starter
## with empty slots may still begin, because the cap is a ceiling and not a requirement. Buying a
## slot for one starter does nothing for another. Aspect cards are owned, not bought (design doc
## 8.6).

const PATH: String = "user://adventure/upgrades.json"
const SAVE_VERSION: int = 2

## Tests point this somewhere else so nothing lands on the player's save.
static var path_override: String = ""

## starter id -> {"extra_slots": int}.
var rows: Dictionary = {}


static func path() -> String:
	return path_override if path_override != "" else PATH


func _row(starter_id: String) -> Dictionary:
	return rows.get(starter_id, {})


## Extra deck slots bought for `starter_id`.
func slots(starter_id: String) -> int:
	return int(_row(starter_id).get("extra_slots", 0))


## What the next slot costs, 0 when this starter has bought every slot it has room for.
## `max_slots` is how many the starter may ever buy, which is what DeckValidator's card maximum
## leaves above the deck it prints; -1 means "do not check", for a caller that has no deck to hand.
func next_slot_cost(starter_id: String, max_slots: int = -1) -> int:
	var bought: int = slots(starter_id)
	if max_slots >= 0 and bought >= max_slots:
		return 0
	return AdventureEconomy.slot_cost(bought + 1)


## Buys one slot. False, and nothing moves, when the starter has no room left for another or the
## wallet is short. See `next_slot_cost` for `max_slots`.
func buy_slot(starter_id: String, wallet: AdventureWallet, max_slots: int = -1) -> bool:
	if wallet == null:
		return false
	var cost: int = next_slot_cost(starter_id, max_slots)
	if cost <= 0 or not wallet.spend(cost, AdventureWallet.REASON_SLOT, starter_id):
		return false
	rows[starter_id] = {"extra_slots": slots(starter_id) + 1}
	return true


## Starter ids with something bought, sorted, so a screen lists them the same way twice.
func all_starters() -> Array[String]:
	var out: Array[String] = []
	out.assign(rows.keys())
	out.sort()
	return out


func to_dict() -> Dictionary:
	var saved: Dictionary = {}
	for starter_id in all_starters():
		saved[starter_id] = {"extra_slots": slots(starter_id)}
	return {"version": SAVE_VERSION, "starters": saved}


## Tolerant of JSON, which hands every number back as a float. A version 1 file's `aspect_tiers`
## are dropped.
static func from_dict(d: Dictionary) -> AdventureUpgrades:
	var u: AdventureUpgrades = AdventureUpgrades.new()
	var saved: Dictionary = d.get("starters", {})
	for starter_id in saved.keys():
		var entry: Variant = saved[starter_id]
		if not (entry is Dictionary):
			continue
		var extra: int = maxi(0, int((entry as Dictionary).get("extra_slots", 0)))
		if extra > 0:
			u.rows[str(starter_id)] = {"extra_slots": extra}
	return u


## The saved upgrades, or an empty set when there is no file yet. Never null.
static func load_upgrades() -> AdventureUpgrades:
	var file: String = path()
	if not FileAccess.file_exists(file):
		return AdventureUpgrades.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not (parsed is Dictionary):
		push_error("AdventureUpgrades: %s is not a JSON object" % file)
		return AdventureUpgrades.new()
	return AdventureUpgrades.from_dict(CardRenames.migrate(parsed) as Dictionary)


func save() -> bool:
	var file: String = AdventureUpgrades.path()
	var dir: String = file.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var handle: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	if handle == null:
		push_error("AdventureUpgrades: cannot write %s" % file)
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
