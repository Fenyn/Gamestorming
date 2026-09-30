class_name AdventureReserveBundles
extends RefCounted
## The Reserve sets a Relic node offers, loaded once from data/adventure/reserve_bundles.json. A set
## is its `key` cards plus `fill_count` more drawn from `fill_from`. Data only: which sets a run may
## see and which fill cards it gets is AdventureRelic's job.

const PATH: String = "res://data/adventure/reserve_bundles.json"

static var _all: Array[Dictionary] = []
static var _by_id: Dictionary = {}


static func _load() -> void:
	if not _all.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		push_error("Reserve set list %s is not a JSON object" % PATH)
		return
	var blob: Dictionary = parsed
	for entry in blob.get("sets", []):
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var key: Array[Dictionary] = []
		for k in row.get("key", []):
			if k is Dictionary:
				var card: Dictionary = k
				key.append({"id": str(card.get("id", "")), "count": int(card.get("count", 1))})
		var fill: Dictionary = row.get("fill", {}) if row.get("fill", {}) is Dictionary else {}
		var fill_from: Array[String] = []
		for id in fill.get("from", []):
			fill_from.append(str(id))
		var bundle: Dictionary = {
			"id": str(row.get("id", "")),
			"group": str(row.get("group", "")),
			"name": str(row.get("name", "")),
			"answers": str(row.get("answers", "")),
			"key": key,
			"fill_count": int(fill.get("count", 0)),
			"fill_from": fill_from,
		}
		_all.append(bundle)
		_by_id[bundle["id"]] = bundle


static func all() -> Array[Dictionary]:
	_load()
	return _all


## One set, or an empty dictionary when no set carries that id.
static func by_id(id: String) -> Dictionary:
	_load()
	return _by_id.get(id, {})


## A set's key cards expanded, one entry per copy.
static func key_cards(bundle: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for entry in bundle.get("key", []):
		var card: Dictionary = entry
		for i in range(int(card.get("count", 1))):
			out.append(str(card.get("id", "")))
	return out


## Key cards plus fill slots: the size a set reaches when its fill pool does not run dry.
static func target_size(bundle: Dictionary) -> int:
	return key_cards(bundle).size() + int(bundle.get("fill_count", 0))


static func fill_pool(bundle: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in bundle.get("fill_from", []):
		out.append(str(id))
	return out
