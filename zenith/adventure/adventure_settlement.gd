class_name AdventureSettlement
extends RefCounted
## The run-end screen's rules. Nothing banks for free: at the end of a run, won or lost, the
## player sees what the run put in the deck and pays Motes per copy to keep it.
##
## A loss offers the cards the run added. A win offers the whole run deck, starter cards included,
## at a discount, once, on that screen only. Closing the settlement ends the run for good.

const REASON_KEEP: String = AdventureWallet.REASON_KEEP


## Moves a finished run to its run-end screen, remembering which way it ended. Does nothing to a
## run that is not finished.
static func open(run: AdventureRun) -> bool:
	if run == null or run.settled:
		return false
	if run.status != "won" and run.status != "lost":
		return false
	run.outcome = run.status
	run.status = "settle"
	return true


static func is_open(run: AdventureRun) -> bool:
	return run != null and run.status == "settle" and not run.settled


static func won(run: AdventureRun) -> bool:
	return run != null and run.outcome == "won"


## One row per distinct card the run can bank, sorted by id:
##   id              the card
##   count           copies on offer: what the run added, less what has been kept already
##   price           Motes for one copy
##   discount_price  Motes for one copy on a won run; the same as `price` on a loss
##   unit            what a copy actually costs right now, so a screen never picks between the two
##   band            the price band, for a label
##   cap_remaining   room left in the collection, or -1 when no collection was passed
## `collection` is optional: pass it and the rows say how many copies would fit.
static func offers(run: AdventureRun, library: CardLibrary, won_value: bool,
		collection: AdventureCollection = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if run == null:
		return out
	var pool: Array[String] = _pool(run, won_value)
	var counts: Dictionary = {}
	for id in pool:
		counts[id] = int(counts.get(id, 0)) + 1
	var ids: Array[String] = []
	ids.assign(counts.keys())
	ids.sort()
	for id in ids:
		var def: CardDef = library.defs.get(id)
		if def == null:
			continue
		var left: int = int(counts[id]) - int(run.kept.get(id, 0))
		if left <= 0:
			continue
		var full: int = AdventureEconomy.price(def)
		var cut: int = AdventureEconomy.discount_price(def) if won_value else full
		out.append({
			"id": id,
			"count": left,
			"price": full,
			"discount_price": cut,
			"unit": cut,
			"band": AdventureEconomy.band(def),
			"cap_remaining": collection.room_for(id, library) if collection != null else -1,
		})
	return out


## What a run puts on the table. A loss offers what the run added and nothing else; a win opens
## the whole deck it finished with, the starter's own cards included.
static func _pool(run: AdventureRun, won_value: bool) -> Array[String]:
	var out: Array[String] = []
	if won_value:
		out.append_array(run.cards)
		out.append_array(run.duelist_ids)
	else:
		out.append_array(run.added_cards())
		out.append_array(run.added_duelist_cards())
	return out


## Buys `count` copies of one offered card into the collection. Returns how many landed: 0 when
## the settlement is closed, the card is not on offer, the wallet is short, or the collection is
## already full of it. Partial buys are allowed; the price is charged per copy that lands.
static func keep(run: AdventureRun, id: String, count: int, wallet: AdventureWallet,
		collection: AdventureCollection, library: CardLibrary) -> int:
	if not is_open(run) or count <= 0 or wallet == null or collection == null:
		return 0
	var row: Dictionary = _row(run, library, id, collection)
	if row.is_empty():
		return 0
	var unit: int = int(row["unit"])
	var want: int = mini(count, int(row["count"]))
	want = mini(want, collection.room_for(id, library))
	while want > 0 and not wallet.can_afford(unit * want):
		want -= 1
	if want <= 0:
		return 0
	if not wallet.spend(unit * want, REASON_KEEP, run.run_id):
		return 0
	var added: int = collection.add(id, want, library)
	run.kept[id] = int(run.kept.get(id, 0)) + added
	return added


## The offer row for one card, or an empty dictionary when it is not on offer.
static func _row(run: AdventureRun, library: CardLibrary, id: String,
		collection: AdventureCollection) -> Dictionary:
	for row in offers(run, library, won(run), collection):
		if str(row["id"]) == id:
			return row
	return {}


## What keeping everything on offer would cost, which is the number the screen shows as the total.
static func total_price(rows: Array[Dictionary]) -> int:
	var sum: int = 0
	for row in rows:
		sum += int(row["unit"]) * int(row["count"])
	return sum


## Ends the settlement. The run is over: nothing more can be kept, and it cannot be reopened.
static func close(run: AdventureRun) -> void:
	if run == null:
		return
	run.settled = true
	run.status = run.outcome if run.outcome != "" else "lost"
