class_name ResonanceData
extends RefCounted
## The Resonances an adventure run can hold (design doc 7.7), read once from
## `data/adventure/resonances.json`. A Resonance is never a card: DuelEngine keeps a player's ids in
## their own list and reads `rules` from here, so no card effect can count, target or discard one.
## Each row is {id, name, tags, style, icon, effect, penalty, rules}.

const PATH: String = "res://data/adventure/resonances.json"

static var _rows: Array[Dictionary] = []
static var _by_id: Dictionary = {}
static var _loaded: bool = false


static func all() -> Array[Dictionary]:
	_load()
	return _rows


static func ids() -> Array[String]:
	var out: Array[String] = []
	for row in all():
		out.append(str(row.get("id", "")))
	return out


static func has(id: String) -> bool:
	_load()
	return _by_id.has(id)


static func by_id(id: String) -> Dictionary:
	_load()
	return _by_id.get(id, {})


static func name_of(id: String) -> String:
	return str(by_id(id).get("name", id))


static func effect_of(id: String) -> String:
	return str(by_id(id).get("effect", ""))


static func penalty_of(id: String) -> String:
	return str(by_id(id).get("penalty", ""))


static func icon_of(id: String) -> String:
	return str(by_id(id).get("icon", ""))


static func is_style(id: String) -> bool:
	return bool(by_id(id).get("style", false))


static func tags_of(id: String) -> Array[String]:
	var out: Array[String] = []
	for tag in by_id(id).get("tags", []):
		out.append(str(tag))
	return out


static func rules(id: String) -> Dictionary:
	return by_id(id).get("rules", {})


## The log line for a Resonance taking effect, `what` naming which of its rules it was.
static func log_line(id: String, what: String, player: String, amount: int) -> String:
	var name: String = name_of(id)
	match what:
		"open_energy":
			return "%s: %s opens the duel at full Energy." % [name, player]
		"no_first_combat":
			return "%s: %s cannot declare Combat this turn." % [name, player]
		"art_free":
			return "%s: %s's Art costs no Energy." % [name, player]
		"art_wound":
			return "%s: %s's Art costs one wound." % [name, player]
		"drills_kept":
			return "%s: %s keeps their Drills." % [name, player]
		"recovered":
			return "%s: %s puts %d %s from the discard pile under the Life Deck." % [name, player, amount, "card" if amount == 1 else "cards"]
		"energy":
			return "%s: %s gains %d Energy." % [name, player, amount]
		"seal_draw":
			return "%s: %s draws a card." % [name, player]
		"setup_search":
			return "%s: %s may search the Life Deck for a Drill." % [name, player]
		"guarded":
			return "%s: the opponent cannot discard %s's Drill." % [name, player]
	return "%s takes effect for %s." % [name, player]


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		push_error("ResonanceData: %s is not a JSON object" % PATH)
		return
	for row in (parsed as Dictionary).get("resonances", []):
		if row is Dictionary:
			var entry: Dictionary = row
			_rows.append(entry)
			_by_id[str(entry.get("id", ""))] = entry
