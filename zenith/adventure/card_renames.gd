class_name CardRenames
extends RefCounted
## Old card ids to the generic ids of 2026-09-23, applied to a saved file as it loads. Every
## string and every Dictionary key equal to an old id is swapped; everything else passes through.

const MAP_PATH: String = "res://data/migrations/card_renames.json"

static var _ids: Dictionary = {}
static var _loaded: bool = false


static func ids() -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
		if parsed is Dictionary:
			_ids = (parsed as Dictionary).get("ids", {})
		else:
			push_error("CardRenames: cannot read %s" % MAP_PATH)
	return _ids


static func migrate(value: Variant) -> Variant:
	if value is String:
		return ids().get(value, value)
	if value is Array:
		var out_a: Array = []
		for v in value:
			out_a.append(migrate(v))
		return out_a
	if value is Dictionary:
		var out_d: Dictionary = {}
		for k in (value as Dictionary).keys():
			out_d[migrate(k)] = migrate((value as Dictionary)[k])
		return out_d
	return value
