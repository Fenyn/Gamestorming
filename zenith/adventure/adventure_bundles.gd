class_name AdventureBundles
extends RefCounted
## The theme bundles a won stage offers, loaded once from data/adventure/bundles.json.
## Data only: which bundles a run may see is AdventureRewards' job.

const PATH: String = "res://data/adventure/bundles.json"

## Group ids a bundle may carry beyond the six school ids.
const GROUP_FREESTYLE: String = "freestyle"
const GROUP_GROUNDS: String = "grounds"
const GROUP_ALLY: String = "ally"
const GROUP_SIGNATURE: String = "signature"

const TIERS: Array[String] = ["early", "mid", "late"]

static var _all: Array[Dictionary] = []
static var _by_id: Dictionary = {}


static func _load() -> void:
	if not _all.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		push_error("Bundle list %s is not a JSON object" % PATH)
		return
	var blob: Dictionary = parsed
	for entry in blob.get("bundles", []):
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var cards: Array[Dictionary] = []
		for c in row.get("cards", []):
			if not (c is Dictionary):
				continue
			var card: Dictionary = c
			cards.append({"id": str(card.get("id", "")), "count": int(card.get("count", 1))})
		var bundle: Dictionary = {
			"id": str(row.get("id", "")),
			"name": str(row.get("name", "")),
			"group": str(row.get("group", "")),
			"tier": str(row.get("tier", "")),
			"character": str(row.get("character", "")),
			"requires_character": str(row.get("requires_character", "")),
			"cards": cards,
		}
		_all.append(bundle)
		_by_id[bundle["id"]] = bundle


## Every bundle in file order.
static func all() -> Array[Dictionary]:
	_load()
	return _all


## One bundle, or an empty dictionary when no bundle carries that id.
static func by_id(id: String) -> Dictionary:
	_load()
	return _by_id.get(id, {})


## A bundle's cards expanded, one entry per copy, the way DeckList.cards is stored.
static func cards_of(bundle: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for entry in bundle.get("cards", []):
		if not (entry is Dictionary):
			continue
		var card: Dictionary = entry
		var id: String = str(card.get("id", ""))
		for i in range(int(card.get("count", 1))):
			out.append(id)
	return out


## The same, taken by bundle id.
static func cards_of_id(id: String) -> Array[String]:
	return cards_of(by_id(id))
