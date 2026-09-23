class_name PresenceState
extends RefCounted
## What one online player is doing right now, as the other player may see it: where their pointer
## is on the table, which public card or hand slot it is over, and which pile or panel they have
## open. Presence is cosmetic. It never reaches the engine or the Referee, it rides its own
## unreliable channel, and it carries nothing the receiver cannot already see.
##
## Wire keys, all optional on the way in and all present on the way out of `sanitise`:
##   on: bool          the pointer is over the table
##   x, z: float       the pointer on the table plane, in the shared layout (`TableLayout.to_shared`)
##   card: int         uid of a public table card under the pointer, -1 for none
##   hand: int         slot index of the sender's own hand card under the pointer, -1 for none
##   look: String      "" | "pile" | "inspect" | "log" | "choice"
##   seat: int         whose pile, for "pile"
##   zone: String      "discard" | "removed" | "relic", for "pile"
##   look_card: int    uid of the public card being inspected, for "inspect"

const KEYS: Array[String] = ["on", "x", "z", "card", "hand", "look", "seat", "zone", "look_card"]
const LOOKS: Array[String] = ["", "pile", "inspect", "log", "choice"]
const PILE_ZONES: Array[String] = ["discard", "removed", "relic"]
## Zones whose cards the other seat cannot see, whatever the sender's own view says.
const PRIVATE_ZONES: Array[StringName] = [&"hand", &"reserve", &"life_deck"]
## The table top, in world units (the Table mesh is 10.4 by 7.4 around the origin).
const TABLE_BOUNDS: Rect2 = Rect2(-5.2, -3.7, 10.4, 7.4)
const MAX_HAND_SLOT: int = 39
const MAX_UID: int = 1 << 20
const MAX_TEXT: int = 16
const MAX_RAW_KEYS: int = 24


## The empty state: pointer off the table, nothing hovered, nothing open.
static func idle() -> Dictionary:
	return {"on": false, "x": 0.0, "z": 0.0, "card": -1, "hand": -1, "look": "", "seat": -1, "zone": "", "look_card": -1}


## Keeps only the allowed keys with the right types, clamps the point to the table, drops slot
## indexes and uids out of range, caps and checks strings. Returns {} for anything malformed, so
## a caller drops it. Pure: the server, a hosting client and the receiving client all run it.
static func sanitise(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	if d.size() > MAX_RAW_KEYS:
		return {}
	var out: Dictionary = idle()
	for key in d.keys():
		if not (key is String) or not KEYS.has(key):
			continue   # unknown keys, including any card id or title, are simply not copied
		var value: Variant = d[key]
		match key:
			"on":
				if not (value is bool):
					return {}
				out["on"] = value
			"x", "z":
				if not (value is float or value is int):
					return {}
				var f: float = float(value)
				if is_nan(f) or is_inf(f):
					return {}
				out[key] = f
			"card", "hand", "seat", "look_card":
				if not (value is int):
					return {}
				out[key] = int(value)
			"look", "zone":
				if not (value is String or value is StringName):
					return {}
				# Capped before it is compared, so an oversized string costs nothing to refuse.
				out[key] = str(value).substr(0, MAX_TEXT)
	if bool(out["on"]):
		out["x"] = clampf(float(out["x"]), TABLE_BOUNDS.position.x, TABLE_BOUNDS.end.x)
		out["z"] = clampf(float(out["z"]), TABLE_BOUNDS.position.y, TABLE_BOUNDS.end.y)
	else:
		out["x"] = 0.0
		out["z"] = 0.0
	if int(out["card"]) < 0 or int(out["card"]) > MAX_UID:
		out["card"] = -1
	if int(out["hand"]) < 0 or int(out["hand"]) > MAX_HAND_SLOT:
		out["hand"] = -1
	# A hand hover is a slot and nothing else: whatever card rides with it is dropped.
	if int(out["hand"]) >= 0:
		out["card"] = -1
	if not LOOKS.has(str(out["look"])):
		out["look"] = ""
	var look: String = str(out["look"])
	if look != "pile" or not PILE_ZONES.has(str(out["zone"])) or int(out["seat"]) < 0 or int(out["seat"]) > 1:
		out["zone"] = ""
		out["seat"] = -1
		if look == "pile":
			out["look"] = ""
	if str(out["look"]) != "inspect" or int(out["look_card"]) < 0 or int(out["look_card"]) > MAX_UID:
		out["look_card"] = -1
		if str(out["look"]) == "inspect":
			out["look"] = ""
	return out


## Whether both seats can see this card: face known to the viewer and sitting in a public zone.
## The sender checks its own hand and Reserve this way before naming a card, since its own view
## shows them.
static func is_public(c: SeatCard) -> bool:
	return c != null and not c.hidden() and not PRIVATE_ZONES.has(c.zone)


## A sanitised state trimmed to what `view` (the receiver's) can see: a card uid the receiver
## cannot see is dropped, and an inspect of one becomes nothing.
static func for_view(state: Dictionary, view: SeatView) -> Dictionary:
	if state.is_empty() or view == null:
		return state
	var out: Dictionary = state.duplicate()
	if int(out["card"]) >= 0 and not is_public(view.card(int(out["card"]))):
		out["card"] = -1
	if int(out["look_card"]) >= 0 and not is_public(view.card(int(out["look_card"]))):
		out["look_card"] = -1
		out["look"] = ""
	return out


## Whether two states differ enough to be worth sending: any field, or the point by more than
## `epsilon` table units.
static func differs(a: Dictionary, b: Dictionary, epsilon: float = 0.01) -> bool:
	if a.is_empty() != b.is_empty():
		return true
	for key in KEYS:
		if key == "x" or key == "z":
			if absf(float(a.get(key, 0.0)) - float(b.get(key, 0.0))) > epsilon:
				return true
		elif a.get(key) != b.get(key):
			return true
	return false
