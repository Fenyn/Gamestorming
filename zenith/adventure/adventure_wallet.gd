class_name AdventureWallet
extends RefCounted
## The player's Motes, the one currency outside a run, with a short ledger the screens read back.
## Motes are earned and kept even when the run that earned them is later lost.
##
## The wallet also carries the vendor's `stock_seed`, because the two are saved and cleared
## together and a second file for one integer buys nothing.

const PATH: String = "user://adventure/wallet.json"
const SAVE_VERSION: int = 1
## How many ledger entries are kept. The screens show the last handful; older ones are dropped.
const LEDGER_MAX: int = 30

## Ledger reasons. A screen groups by these, so they are ids and not sentences.
const REASON_STAGE: String = "stage"
const REASON_COMPLETION: String = "completion"
const REASON_DISSOLVE: String = "dissolve"
const REASON_KEEP: String = "keep"
const REASON_BUY: String = "buy"
const REASON_REROLL: String = "reroll"
const REASON_SLOT: String = "slot"
const REASON_ASPECT: String = "aspect"

## Tests point this somewhere else so nothing lands on the player's save.
static var path_override: String = ""

var motes: int = 0
## Oldest first, newest last. {"reason", "amount", "run_id"} plus "stage" on a stage payout.
## `amount` is positive on an earn and negative on a spend.
var ledger: Array[Dictionary] = []
## The seed the vendor's stock is drawn from. 0 until the first roll.
var stock_seed: int = 0


static func path() -> String:
	return path_override if path_override != "" else PATH


## Adds `amount` and records it. Returns the new balance. A non-positive amount is ignored.
func earn(amount: int, reason: String, run_id: String = "", stage: int = -1) -> int:
	if amount <= 0:
		return motes
	motes += amount
	_record(amount, reason, run_id, stage)
	return motes


## Takes `amount` when it is there. False, and nothing moves, when it is not.
func spend(amount: int, reason: String, run_id: String = "", stage: int = -1) -> bool:
	if amount < 0 or amount > motes:
		return false
	motes -= amount
	_record(-amount, reason, run_id, stage)
	return true


func can_afford(amount: int) -> bool:
	return amount <= motes


func _record(amount: int, reason: String, run_id: String, stage: int) -> void:
	var entry: Dictionary = {"reason": reason, "amount": amount, "run_id": run_id}
	if stage >= 0:
		entry["stage"] = stage
	ledger.append(entry)
	while ledger.size() > LEDGER_MAX:
		ledger.remove_at(0)


## The newest `count` entries, newest first, which is the order a screen lists them in.
func recent(count: int = 10) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(ledger.size() - 1, -1, -1):
		if out.size() >= count:
			break
		out.append(ledger[i])
	return out


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"motes": motes,
		"stock_seed": stock_seed,
		"ledger": ledger.duplicate(true),
	}


## Tolerant of JSON, which hands every number back as a float.
static func from_dict(d: Dictionary) -> AdventureWallet:
	var w: AdventureWallet = AdventureWallet.new()
	w.motes = int(d.get("motes", 0))
	w.stock_seed = int(d.get("stock_seed", 0))
	for entry in d.get("ledger", []):
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var out: Dictionary = {
			"reason": str(row.get("reason", "")),
			"amount": int(row.get("amount", 0)),
			"run_id": str(row.get("run_id", "")),
		}
		if row.has("stage"):
			out["stage"] = int(row.get("stage", 0))
		w.ledger.append(out)
	return w


## The saved wallet, or an empty one when there is no file yet. Never null.
static func load_wallet() -> AdventureWallet:
	var file: String = path()
	if not FileAccess.file_exists(file):
		return AdventureWallet.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not (parsed is Dictionary):
		push_error("AdventureWallet: %s is not a JSON object" % file)
		return AdventureWallet.new()
	return AdventureWallet.from_dict(parsed as Dictionary)


func save() -> bool:
	var file: String = AdventureWallet.path()
	var dir: String = file.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var handle: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	if handle == null:
		push_error("AdventureWallet: cannot write %s" % file)
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
