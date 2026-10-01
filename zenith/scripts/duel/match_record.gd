class_name MatchRecord
extends RefCounted
## One finished game: the unit that rating, stats and replay read. One JSON object per game, one
## per line of a `.jsonl` file. The duel server writes and signs the online ones (`MatchLog`); a
## client writes its offline duels itself, unsigned, and keeps the server's copies of its online
## ones. The seed and the command list rebuild the whole game, both hands and the deck order
## included, so a record leaves the process that ran the rules only after the game's result is
## written.
##
## The loader is strict: every field is type-checked, an unknown key or version is refused, and a
## record that fails any check is refused whole. A new field means a new `VERSION`. Version 2 added
## `match_id` and `game`, and on the game that decides a ranked match `match` and `seats[].rating`;
## a version 1 record still loads, and writes back as version 1 so its signature still checks.

const VERSION: int = 2
const VERSIONS: Array[int] = [1, 2]
const MAX_GAMES: int = 3
const MAX_COMMANDS: int = 5000
const MODES: Array[String] = ["ranked", "casual", "code", "lan", "vs_ai", "hotseat", "adventure"]
const ORIGINS: Array[String] = ["server", "client"]
const FIRST_REASONS: Array[String] = ["double_power", "chance", "forced"]
const RESULT_REASONS: Array[String] = ["survival", "seal", "ascension", "concede", "timeout", "left", "abandoned"]
## What can end a ranked match: any game result, or "concede_match", a player conceding the whole
## match (Leave match, or a give-up while cut off). The game it ended on still reads "concede".
const MATCH_REASONS: Array[String] = ["survival", "seal", "ascension", "concede", "timeout", "left", "abandoned", "concede_match"]
const KEYS: Array[String] = ["v", "id", "origin", "protocol", "catalog", "build", "mode", "started", "seed",
	"color_seed", "first", "rules", "seats", "commands", "result", "disconnects", "reconnects", "dev", "sig"]
const NAME_MAX: int = 64
const TEXT_MAX: int = 64
const IDENTITY_MAX: int = 128
const DECK_CARDS_MAX: int = 200
const DECK_LIST_MAX: int = 20      # a duelist stack, a Reserve, a deck's subthemes
const BATCH_MAX: int = 128         # card uids in one batch answer, as Net takes them
const DEV_KEYS_MAX: int = 16
## JSON numbers are doubles, so a larger whole number would not come back as itself.
const JSON_INT_MAX: int = 9007199254740991

## Client files. Tests and dev runs (`--dev-scratch=<dir>`) point `dir_override` at another folder
## so no record lands among the player's own.
const CLIENT_DIR: String = "user://matches"
const LOCAL_FILE: String = "local.jsonl"
const ONLINE_FILE: String = "online.jsonl"
const CLIENT_KEEP: int = 200
static var dir_override: String = ""

static var _hex16: RegEx = RegEx.create_from_string("^[0-9a-f]{16}$")
static var _hex64: RegEx = RegEx.create_from_string("^[0-9a-f]{64}$")
static var _ident: RegEx = RegEx.create_from_string("^[a-z0-9_]{1,64}$")
static var _identity: RegEx = RegEx.create_from_string("^[A-Za-z0-9_+/=:.-]*$")

var v: int = VERSION
var id: String = ""
## Shared by every game of one match; the record's own `id` in a match of one game. "" reads as `id`.
var match_id: String = ""
## Which game of its match this is, from 1.
var game: int = 1
## On the game that decided a ranked match only: {"winner": seat or -1, "wins": [int, int],
## "reason": what ended the match, one of MATCH_REASONS}. The seats then carry "rating" when it was
## rated.
var match_result: Dictionary = {}
## "server" for a record the duel server wrote and signed, "client" for one a client wrote about
## its own offline duel. Nothing trusts a client record for rating or shared stats.
var origin: String = "client"
var protocol: int = 0
var catalog: String = ""
var build: String = ""
var mode: String = ""
## Unix seconds, UTC, at the deal.
var started: int = 0
var seed_value: int = 0
var color_seed: int = 0
## {"seat", "reason"}: who opened and why, as the engine's `setup` event says.
var first: Dictionary = {}
## The options set on the engine before `start()`: {"lives": [player, rival], "seal_point",
## "second_life", "guest": [id per seat], "boss_power": [id per seat]}.
var rules: Dictionary = {}
## Per seat {"identity", "name", "deck", "ai"}, plus "list" (the deck inline) for a deck that is
## not a catalog file as it stands, such as an adventure run's, and "rating" ({"before": {"mu",
## "sigma"}, "after": {...}}) on the game that decided a rated match.
var seats: Array[Dictionary] = []
## `Referee.history` in wire form, each entry with "at", ms since the deal.
var commands: Array[Dictionary] = []
## {"winner", "reason", "turns", "duration_ms", "points"}; empty until the game ends.
var result: Dictionary = {}
var disconnects: Array[int] = [0, 0]
var reconnects: Array[int] = [0, 0]
## True once any dev effect is in `commands`; stats skip these.
var dev: bool = false
## HMAC-SHA256 of `canonical()` under the server's key, as hex. Empty on a client record.
var sig: String = ""


## The header of a game about to be dealt, read off a referee after `setup()` and every `set_*`
## option and before `start()`, since the setup events are gone once the first update is taken.
static func begin(referee: Referee, decks: Array[DeckList], p_mode: String, p_origin: String) -> MatchRecord:
	var r: MatchRecord = MatchRecord.new()
	r.id = Crypto.new().generate_random_bytes(8).hex_encode()
	r.match_id = r.id
	r.origin = p_origin
	r.mode = p_mode
	r.build = str(ProjectSettings.get_setting("application/config/version", ""))
	r.started = int(Time.get_unix_time_from_system())
	var engine: DuelEngine = referee.engine
	var s: GameState = engine.state
	r.seed_value = s.seed_value
	# No setup event means `start()` already ran; the empty reason then fails the loader rather
	# than recording an opener nobody checked.
	r.first = {"seat": s.active, "reason": ""}
	var guests: Array[String] = ["", ""]
	for ev in engine.events:
		if ev.type == &"setup":
			r.first = {"seat": int(ev.data.get("first", s.active)), "reason": str(ev.data.get("reason", ""))}
		elif ev.type == &"guest_ally":
			guests[int(ev.data.get("player", 0))] = engine.card(int(ev.data.get("card", -1))).def.id
	var powers: Array[String] = ["", ""]
	for i in range(2):
		if s.players[i].boss_power != null:
			powers[i] = s.players[i].boss_power.def.id
	r.rules = {"lives": [s.points_to_win[1], s.points_to_win[0]], "seal_point": s.seal_scores_point,
		"second_life": s.second_life_returns_used, "guest": guests, "boss_power": powers}
	for i in range(2):
		r.seats.append({"identity": "", "name": s.players[i].name, "deck": decks[i].id, "ai": ""})
		# A player-built deck is no catalog file, so a replay needs the list itself.
		if decks[i].custom:
			r.seats[i]["deck"] = ""
			r.seats[i]["list"] = deck_dict(decks[i])
	return r


## One accepted command or dev effect, stamped `at` ms since the deal.
func add_command(entry: Dictionary, at: int) -> void:
	var stamped: Dictionary = entry.duplicate(true)
	stamped["at"] = maxi(0, at)
	commands.append(stamped)
	if entry.has("dev"):
		dev = true


## The game's outcome. The first result stands; a later call changes nothing.
func finish(winner: int, reason: String, engine: DuelEngine, duration_ms: int) -> void:
	if has_result():
		return
	result = {"winner": winner, "reason": reason, "turns": engine.state.turn, "duration_ms": maxi(0, duration_ms),
		"points": [engine.state.points[0], engine.state.points[1]]}


func has_result() -> bool:
	return not result.is_empty()


## A deck that is not a catalog file as it stands, inline, in the shape `DeckList.from_dict` reads.
static func deck_dict(deck: DeckList) -> Dictionary:
	return {"name": deck.name, "duelist": deck.duelist_ids.duplicate(), "style": deck.style,
		"alignment": deck.alignment, "mastery": deck.mastery_id, "relic": deck.relic_id,
		"reserve": deck.reserve.duplicate(), "archetype": deck.archetype,
		"subthemes": deck.subthemes.duplicate(), "cards": deck.cards.duplicate()}


func to_dict() -> Dictionary:
	var out: Dictionary = {
		"v": v, "id": id, "origin": origin, "protocol": protocol, "catalog": catalog, "build": build,
		"mode": mode, "started": started, "seed": seed_value, "color_seed": color_seed,
		"first": first.duplicate(), "rules": rules.duplicate(true), "seats": seats.duplicate(true),
		"commands": commands.duplicate(true), "result": result.duplicate(true),
		"disconnects": disconnects.duplicate(), "reconnects": reconnects.duplicate(), "dev": dev, "sig": sig,
	}
	if v >= 2:
		out["match_id"] = match_id if match_id != "" else id
		out["game"] = game
		if not match_result.is_empty():
			out["match"] = match_result.duplicate(true)
	return out


## The record as one file line: the canonical text with `sig` in it.
func line() -> String:
	return JSON.stringify(_whole_numbers(to_dict()), "", true, true)


## The exact text a signature covers: JSON with every object's keys sorted, no whitespace, full
## precision, every whole number written as an integer, and `sig` left out. A record read back
## from its own line gives the same text, which is what lets a verifier recompute the signature.
static func canonical(d: Dictionary) -> String:
	var copy: Dictionary = d.duplicate(true)
	copy.erase("sig")
	return JSON.stringify(_whole_numbers(copy), "", true, true)


## JSON hands every number back as a float. A record holds no fractions outside a dev effect, so
## each whole float goes back to an int, or replayed commands stop matching their options.
static func _whole_numbers(value: Variant) -> Variant:
	if value is float:
		var f: float = value
		if is_finite(f) and f == floorf(f) and absf(f) <= float(JSON_INT_MAX):
			return int(f)
		return f
	if value is Dictionary:
		var fields: Dictionary = {}
		for key in (value as Dictionary).keys():
			fields[key] = _whole_numbers((value as Dictionary)[key])
		return fields
	if value is Array:
		var items: Array = []
		for item in (value as Array):
			items.append(_whole_numbers(item))
		return items
	return value


## A record from parsed JSON, or null when anything about it is off; `problem_of` says what.
static func from_dict(raw: Variant) -> MatchRecord:
	var r: MatchRecord = MatchRecord.new()
	return r if _parse(raw, r) == "" else null


## Why `raw` is not a record this build accepts, or "" when it is.
static func problem_of(raw: Variant) -> String:
	return _parse(raw, MatchRecord.new())


## A record from a file: the line of a `.jsonl` whose id is `record_id`, or its last line when no id
## is given, or the whole of a `.replay.json`. Null when that fails; `file_problem` says why.
static func load_file(path: String, record_id: String = "") -> MatchRecord:
	var r: MatchRecord = MatchRecord.new()
	return r if _read_file(path, record_id, r) == "" else null


static func file_problem(path: String, record_id: String = "") -> String:
	return _read_file(path, record_id, MatchRecord.new())


static func _read_file(path: String, record_id: String, r: MatchRecord) -> String:
	if not FileAccess.file_exists(path):
		return "there is no file at %s" % path
	var text: String = FileAccess.get_file_as_string(path)
	var lines: PackedStringArray = PackedStringArray([text]) if path.ends_with(".json") else text.split("\n", false)
	for i in range(lines.size() - 1, -1, -1):
		var raw: Variant = JSON.parse_string(lines[i])
		if record_id != "" and not (raw is Dictionary and str((raw as Dictionary).get("id", "")) == record_id):
			continue
		var problem: String = _parse(raw, r)
		return "" if problem == "" else "the record does not load: " + problem
	return "no record %s in %s" % [record_id, path] if record_id != "" else "no record in %s" % path


static func _parse(raw: Variant, r: MatchRecord) -> String:
	if not (raw is Dictionary):
		return "not an object"
	var d: Dictionary = raw
	var version: Variant = _int(d.get("v"))
	if version == null or not VERSIONS.has(int(version)):
		return "unknown version"
	r.v = int(version)
	var required: Array = KEYS.duplicate()
	if r.v >= 2:
		required.append_array(["match_id", "game"])
	var keys: String = _exact_keys(d, required, ["match"] if r.v >= 2 else [])
	if keys != "":
		return keys
	if not (d["id"] is String and _hex16.search(d["id"]) != null):
		return "id"
	r.id = d["id"]
	r.match_id = r.id
	if r.v >= 2:
		var game_number: Variant = _int(d["game"])
		if not (d["match_id"] is String and _hex16.search(d["match_id"]) != null):
			return "match_id"
		if game_number == null or int(game_number) < 1 or int(game_number) > MAX_GAMES:
			return "game"
		r.match_id = d["match_id"]
		r.game = int(game_number)
		if d.has("match"):
			var problem_match: String = _parse_match(d["match"], r)
			if problem_match != "":
				return problem_match
	if not (d["origin"] is String and ORIGINS.has(d["origin"])):
		return "origin"
	r.origin = d["origin"]
	if not (d["mode"] is String and MODES.has(d["mode"])):
		return "mode"
	r.mode = d["mode"]
	if not (d["catalog"] is String and (d["catalog"] == "" or _hex64.search(d["catalog"]) != null)):
		return "catalog"
	r.catalog = d["catalog"]
	if _text(d["build"], TEXT_MAX) == null:
		return "build"
	r.build = d["build"]
	for key in ["protocol", "started"]:
		if _int(d[key]) == null or int(_int(d[key])) < 0:
			return key
	r.protocol = int(_int(d["protocol"]))
	r.started = int(_int(d["started"]))
	if _int(d["seed"]) == null or _int(d["color_seed"]) == null:
		return "seed"
	r.seed_value = int(_int(d["seed"]))
	r.color_seed = int(_int(d["color_seed"]))
	var problem: String = _parse_first(d["first"], r)
	if problem == "":
		problem = _parse_rules(d["rules"], r)
	if problem == "":
		problem = _parse_seats(d["seats"], r)
	if problem == "":
		problem = _parse_commands(d["commands"], r)
	if problem == "":
		problem = _parse_result(d["result"], r)
	if problem != "":
		return problem
	var counts: Array = [_pair(d["disconnects"], 0), _pair(d["reconnects"], 0)]
	if counts[0] == null or counts[1] == null:
		return "disconnects or reconnects"
	r.disconnects.assign(counts[0])
	r.reconnects.assign(counts[1])
	if not (d["dev"] is bool):
		return "dev"
	if bool(d["dev"]) != r.dev:
		return "dev does not match the commands"
	if not (d["sig"] is String):
		return "sig"
	var signature: String = d["sig"]
	if r.origin == "client" and signature != "":
		return "a client record carries a signature"
	if r.origin == "server" and _hex64.search(signature) == null:
		return "a server record without a signature"
	r.sig = signature
	return ""


static func _parse_first(raw: Variant, r: MatchRecord) -> String:
	if not (raw is Dictionary) or _exact_keys(raw, ["seat", "reason"], []) != "":
		return "first"
	var d: Dictionary = raw
	var seat: Variant = _int(d["seat"])
	if seat == null or int(seat) < 0 or int(seat) > 1 or not (d["reason"] is String and FIRST_REASONS.has(d["reason"])):
		return "first"
	r.first = {"seat": int(seat), "reason": str(d["reason"])}
	return ""


static func _parse_rules(raw: Variant, r: MatchRecord) -> String:
	if not (raw is Dictionary) or _exact_keys(raw, ["lives", "seal_point", "second_life", "guest", "boss_power"], []) != "":
		return "rules"
	var d: Dictionary = raw
	var lives: Variant = _pair(d["lives"], 1)
	if lives == null or not (d["seal_point"] is bool and d["second_life"] is bool):
		return "rules"
	var cards: Array[Array] = []
	for key in ["guest", "boss_power"]:
		if not (d[key] is Array and (d[key] as Array).size() == 2):
			return "rules " + key
		var ids: Array[String] = []
		for item in (d[key] as Array):
			if not (item is String and (item == "" or _ident.search(item) != null)):
				return "rules " + key
			ids.append(item)
		cards.append(ids)
	r.rules = {"lives": lives, "seal_point": d["seal_point"], "second_life": d["second_life"],
		"guest": cards[0], "boss_power": cards[1]}
	return ""


static func _parse_seats(raw: Variant, r: MatchRecord) -> String:
	if not (raw is Array and (raw as Array).size() == 2):
		return "seats"
	var optional: Array = ["list", "rating"] if r.v >= 2 else ["list"]
	for item in (raw as Array):
		if not (item is Dictionary) or _exact_keys(item, ["identity", "name", "deck", "ai"], optional) != "":
			return "seats"
		var d: Dictionary = item
		if _text(d["identity"], IDENTITY_MAX) == null or _identity.search(d["identity"]) == null:
			return "seat identity"
		if _text(d["name"], NAME_MAX) == null or str(d["name"]).strip_edges() == "" \
				or str(d["name"]).contains("[") or str(d["name"]).contains("]"):
			return "seat name"
		if not (d["ai"] is String and (d["ai"] == "" or (_ident.search(d["ai"]) != null and str(d["ai"]).length() <= 32))):
			return "seat ai"
		var seat: Dictionary = {"identity": d["identity"], "name": d["name"], "deck": d["deck"], "ai": d["ai"]}
		if d.has("list"):
			var list: Variant = _deck_list(d["list"])
			if list == null:
				return "seat list"
			seat["list"] = list
		if d.has("rating"):
			var change: Dictionary = {}
			if not (d["rating"] is Dictionary) or _exact_keys(d["rating"], ["before", "after"], []) != "":
				return "seat rating"
			for key in ["before", "after"]:
				var rating: Variant = _rating((d["rating"] as Dictionary)[key])
				if rating == null:
					return "seat rating"
				change[key] = rating
			seat["rating"] = change
		if not (d["deck"] is String and ((d["deck"] == "" and d.has("list")) or _ident.search(d["deck"]) != null)):
			return "seat deck"
		r.seats.append(seat)
	return ""


## {"mu", "sigma"} as floats, finite, sigma above 0, or null.
static func _rating(raw: Variant) -> Variant:
	if not (raw is Dictionary) or _exact_keys(raw, ["mu", "sigma"], []) != "":
		return null
	var mu: Variant = (raw as Dictionary)["mu"]
	var sigma: Variant = (raw as Dictionary)["sigma"]
	if not ((mu is int or mu is float) and (sigma is int or sigma is float)):
		return null
	if not is_finite(float(mu)) or not is_finite(float(sigma)) or float(sigma) <= 0.0:
		return null
	return {"mu": float(mu), "sigma": float(sigma)}


static func _parse_match(raw: Variant, r: MatchRecord) -> String:
	if not (raw is Dictionary) or _exact_keys(raw, ["winner", "wins", "reason"], []) != "":
		return "match"
	var d: Dictionary = raw
	var winner: Variant = _int(d["winner"])
	var wins: Variant = _pair(d["wins"], 0)
	if winner == null or int(winner) < -1 or int(winner) > 1 or wins == null \
			or not (d["reason"] is String and MATCH_REASONS.has(d["reason"])):
		return "match"
	r.match_result = {"winner": int(winner), "wins": wins, "reason": d["reason"]}
	return ""


## An inline deck, every field checked, or null.
static func _deck_list(raw: Variant) -> Variant:
	if not (raw is Dictionary) or _exact_keys(raw, ["name", "duelist", "style", "alignment", "mastery",
			"relic", "reserve", "archetype", "subthemes", "cards"], []) != "":
		return null
	var d: Dictionary = raw
	if _text(d["name"], NAME_MAX) == null:
		return null
	for key in ["style", "alignment", "archetype"]:
		if not (d[key] is String and (d[key] == "" or _ident.search(d[key]) != null)):
			return null
	for key in ["mastery", "relic"]:
		if not (d[key] is String and (d[key] == "" or _ident.search(d[key]) != null)):
			return null
	var out: Dictionary = {"name": d["name"], "style": d["style"], "alignment": d["alignment"],
		"archetype": d["archetype"], "mastery": d["mastery"], "relic": d["relic"]}
	for key in ["duelist", "reserve", "subthemes", "cards"]:
		var limit: int = DECK_CARDS_MAX if key == "cards" else DECK_LIST_MAX
		if not (d[key] is Array and (d[key] as Array).size() <= limit):
			return null
		var ids: Array[String] = []
		for item in (d[key] as Array):
			if not (item is String and _ident.search(item) != null):
				return null
			ids.append(item)
		out[key] = ids
	if (out["duelist"] as Array).is_empty():
		return null
	return out


static func _parse_commands(raw: Variant, r: MatchRecord) -> String:
	if not (raw is Array):
		return "commands"
	var list: Array = raw
	if list.size() > MAX_COMMANDS:
		return "more than %d commands" % MAX_COMMANDS
	for i in range(list.size()):
		var entry: Variant = _command(list[i])
		if entry == null:
			return "command %d" % i
		r.commands.append(entry)
		if (entry as Dictionary).has("dev"):
			r.dev = true
	return ""


## One history entry with its `at`, checked the way `Net.clean_command` checks the wire, or null.
static func _command(raw: Variant) -> Variant:
	if not (raw is Dictionary):
		return null
	var d: Dictionary = raw
	var player: Variant = _int(d.get("player"))
	var at: Variant = _int(d.get("at"))
	if player == null or int(player) < 0 or int(player) > 1 or at == null or int(at) < 0:
		return null
	if d.has("dev"):
		if _exact_keys(d, ["player", "dev", "at"], []) != "":
			return null
		var effect: Variant = _dev_effect(d["dev"])
		return null if effect == null else {"player": int(player), "dev": effect, "at": int(at)}
	if _exact_keys(d, ["player", "type", "card", "value", "at"], []) != "":
		return null
	var card: Variant = _int(d["card"])
	if card == null or int(card) < -1 or not (d["type"] is String and _ident.search(d["type"]) != null):
		return null
	var value: Variant = _whole_numbers(d["value"])
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			pass
		TYPE_STRING:
			if _text(value, TEXT_MAX) == null:
				return null
		TYPE_ARRAY:
			var uids: Array[int] = []
			if (value as Array).size() > BATCH_MAX:
				return null
			for item in (value as Array):
				if typeof(item) != TYPE_INT:
					return null
				uids.append(item)
			value = uids
		_:
			return null
	return {"player": int(player), "type": d["type"], "card": int(card), "value": value, "at": int(at)}


## A dev effect: a flat object of short keys and plain values.
static func _dev_effect(raw: Variant) -> Variant:
	if not (raw is Dictionary) or (raw as Dictionary).size() > DEV_KEYS_MAX:
		return null
	var out: Dictionary = {}
	for key in (raw as Dictionary).keys():
		if not (key is String and _ident.search(key) != null):
			return null
		var value: Variant = _whole_numbers((raw as Dictionary)[key])
		match typeof(value):
			TYPE_NIL, TYPE_BOOL, TYPE_INT:
				pass
			TYPE_FLOAT:
				if not is_finite(float(value)):
					return null
			TYPE_STRING:
				if _text(value, TEXT_MAX) == null:
					return null
			_:
				return null
		out[key] = value
	return out


static func _parse_result(raw: Variant, r: MatchRecord) -> String:
	if not (raw is Dictionary) or _exact_keys(raw, ["winner", "reason", "turns", "duration_ms", "points"], []) != "":
		return "result"
	var d: Dictionary = raw
	var winner: Variant = _int(d["winner"])
	var turns: Variant = _int(d["turns"])
	var duration: Variant = _int(d["duration_ms"])
	var points: Variant = _pair(d["points"], 0)
	if winner == null or int(winner) < -1 or int(winner) > 1 or not (d["reason"] is String and RESULT_REASONS.has(d["reason"])):
		return "result"
	if turns == null or int(turns) < 0 or duration == null or int(duration) < 0 or points == null:
		return "result"
	r.result = {"winner": int(winner), "reason": d["reason"], "turns": int(turns), "duration_ms": int(duration), "points": points}
	return ""


## "" when `d` holds every key of `required`, any of `optional`, and nothing else.
static func _exact_keys(d: Dictionary, required: Array, optional: Array) -> String:
	for key in required:
		if not d.has(key):
			return "missing " + str(key)
	for key in d.keys():
		if not (key is String) or not (required.has(key) or optional.has(key)):
			return "unexpected key " + str(key).left(32)
	return ""


## An int, or a whole float JSON made of one, else null.
static func _int(v: Variant) -> Variant:
	if v is int:
		return v if absi(int(v)) <= JSON_INT_MAX else null
	if v is float:
		var whole: Variant = _whole_numbers(v)
		return whole if whole is int else null
	return null


## Two ints of at least `floor`, else null.
static func _pair(v: Variant, floor_value: int) -> Variant:
	if not (v is Array and (v as Array).size() == 2):
		return null
	var out: Array[int] = []
	for item in (v as Array):
		var n: Variant = _int(item)
		if n == null or int(n) < floor_value:
			return null
		out.append(int(n))
	return out


## A string of at most `limit` characters with no control characters, else null.
static func _text(v: Variant, limit: int) -> Variant:
	if not (v is String) or (v as String).length() > limit:
		return null
	for ch in (v as String):
		var code: int = ch.unicode_at(0)
		if code < 32 or code == 127:
			return null
	return v


## A referee standing where this game was dealt, set up the way `Session` and the duel server set
## one up: the decks by catalog id or inline, the names, the seed and the recorded options, the
## opener forced when the record says it was. `Referee.replay(commands)` then plays the game out.
## Null when a deck cannot be found.
func setup_referee(library: CardLibrary, strike_table: StrikeTable, capture_display: bool = true) -> Referee:
	var decks: Array[DeckList] = []
	var names: Array[String] = []
	for seat in seats:
		var deck: DeckList = DeckList.from_dict(seat["list"]) if seat.has("list") else DeckList.resolve(str(seat["deck"]))
		if deck == null:
			return null
		decks.append(deck)
		names.append(str(seat["name"]))
	var referee: Referee = Referee.new()
	referee.setup(decks, library, strike_table, seed_value, names, capture_display)
	var engine: DuelEngine = referee.engine
	engine.set_lives(rules["lives"])
	engine.set_points_options(bool(rules["seal_point"]), bool(rules["second_life"]))
	for seat in range(2):
		if str(rules["guest"][seat]) != "":
			engine.set_guest_ally(seat, str(rules["guest"][seat]))
	for seat in range(2):
		if str(rules["boss_power"][seat]) != "":
			engine.set_boss_power(seat, str(rules["boss_power"][seat]))
	if str(first["reason"]) == "forced":
		engine.set_first_player(int(first["seat"]))
	return referee


static func client_dir() -> String:
	return dir_override if dir_override != "" else CLIENT_DIR


## Adds `text` as the last line of a client file and keeps its last `keep` lines. "" when written,
## otherwise why not.
static func keep_line(file_name: String, text: String, keep: int = CLIENT_KEEP) -> String:
	var dir: String = client_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var made: Error = DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return error_string(made)
	var path: String = dir.path_join(file_name)
	var lines: PackedStringArray = PackedStringArray()
	if FileAccess.file_exists(path):
		lines = FileAccess.get_file_as_string(path).split("\n", false)
	lines.append(text)
	if lines.size() > keep:
		lines = lines.slice(lines.size() - keep)
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return error_string(FileAccess.get_open_error())
	var stored: bool = file.store_string("\n".join(lines) + "\n")
	file.close()
	if not stored:
		return "the write did not complete"
	var moved: Error = DirAccess.rename_absolute(temp, path)
	return "" if moved == OK else error_string(moved)
