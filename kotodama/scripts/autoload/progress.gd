extends Node
## The learner's state: a stage and due day per item, today's tally, the save file.

signal item_changed(key: String)
signal day_rolled(today: int)

const SAVE_PATH: String = "user://kotodama.json"
const SAVE_VERSION: int = 1
const KANJI_PREFIX: String = "k:"
const WORD_PREFIX: String = "w:"

const KANJI_DRILLS: int = 3
const WORD_DRILLS: int = 2

var items: Dictionary = {}
var tally: Dictionary = {}
var last_day: int = 0
var first_day: int = 0

var _save: SaveFileHandler


func _ready() -> void:
	use_path(SAVE_PATH)


## Switches the save file. Tests use a path of their own so the real save is untouched.
func use_path(path: String) -> void:
	_save = SaveFileHandler.new(path, SAVE_VERSION)
	load_state()
	roll_day()


# ---------------------------------------------------------------- keys

static func kanji_key(ch: String) -> String:
	return KANJI_PREFIX + ch


static func word_key(word: String) -> String:
	return WORD_PREFIX + word


static func is_kanji_key(key: String) -> bool:
	return key.begins_with(KANJI_PREFIX)


static func key_text(key: String) -> String:
	return key.substr(2)


# ---------------------------------------------------------------- save

func load_state() -> void:
	var d: Dictionary = _save.load_dict()
	items = d.get("items", {})
	tally = d.get("tally", {})
	last_day = int(d.get("last_day", 0))
	first_day = int(d.get("first_day", 0))


func save_state() -> void:
	_save.save_dict({"items": items, "tally": tally, "last_day": last_day, "first_day": first_day})


func reset_state() -> void:
	items = {}
	tally = {}
	last_day = 0
	first_day = 0
	_save.delete_save()
	roll_day()


# ---------------------------------------------------------------- day

## Days since the first visit, starting at 1.
func day_number() -> int:
	return last_day - first_day + 1


func roll_day() -> void:
	var today: int = Srs.today()
	if first_day == 0:
		first_day = today
	if today != last_day:
		last_day = today
		tally = {"called": 0, "watered": 0, "invited": 0, "planted": 0, "missed": 0}
		save_state()
		day_rolled.emit(today)


func count(what: String) -> void:
	tally[what] = int(tally.get(what, 0)) + 1


# ---------------------------------------------------------------- items

func is_known(key: String) -> bool:
	return items.has(key)


func stage_of(key: String) -> int:
	if not items.has(key):
		return -1
	return int(items[key]["stage"])


func is_due(key: String, today: int) -> bool:
	if not items.has(key):
		return false
	var it: Dictionary = items[key]
	return int(it["stage"]) < Srs.BURNED and int(it["due"]) <= today


func is_overdue(key: String, today: int) -> bool:
	if not items.has(key):
		return false
	var it: Dictionary = items[key]
	return int(it["stage"]) < Srs.BURNED and int(it["due"]) < today


## Which drill to ask next: 0 call, 1 what, 2 form (kanji only).
func next_drill(key: String) -> int:
	if not items.has(key):
		return 0
	var drills: int = KANJI_DRILLS if is_kanji_key(key) else WORD_DRILLS
	return int(items[key]["drill"]) % drills


func learn(key: String, today: int) -> void:
	items[key] = {"stage": 0, "due": today, "lapses": 0, "drill": 0, "learned": today}
	count("invited" if is_kanji_key(key) else "planted")
	save_state()
	item_changed.emit(key)


func record_pass(key: String, today: int) -> void:
	var it: Dictionary = items[key]
	var stage: int = Srs.pass_stage(int(it["stage"]))
	it["stage"] = stage
	it["due"] = Srs.due_day(stage, today)
	it["drill"] = int(it["drill"]) + 1
	count("called" if is_kanji_key(key) else "watered")
	save_state()
	item_changed.emit(key)


func record_miss(key: String, today: int) -> void:
	var it: Dictionary = items[key]
	it["stage"] = Srs.miss_stage(int(it["stage"]))
	it["due"] = today
	it["lapses"] = int(it["lapses"]) + 1
	it["drill"] = int(it["drill"]) + 1
	count("missed")
	save_state()
	item_changed.emit(key)


## Due keys, most overdue first.
func due_keys(today: int) -> Array[String]:
	var out: Array[String] = []
	for key in items:
		if is_due(key, today):
			out.append(key)
	out.sort_custom(func(a: String, b: String) -> bool: return int(items[a]["due"]) < int(items[b]["due"]))
	return out


func known_kanji() -> Array[String]:
	var out: Array[String] = []
	for key in items:
		if is_kanji_key(key):
			out.append(key_text(key))
	return out


func known_words() -> Array[String]:
	var out: Array[String] = []
	for key in items:
		if not is_kanji_key(key):
			out.append(key_text(key))
	return out


func is_part_known(part_id: String) -> bool:
	if is_known(kanji_key(part_id)):
		return true
	if Data.parts_by_id.has(part_id):
		var introduced_by: String = Data.parts_by_id[part_id]["introduced_by"]
		return is_known(kanji_key(introduced_by))
	return false


## The next kanji to invite, in teaching order.
func next_kanji(count_wanted: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in Data.kanji:
		var k: Dictionary = entry
		if not is_known(kanji_key(k["ch"])):
			out.append(k)
			if out.size() >= count_wanted:
				break
	return out


## Words not yet planted whose kanji are all known, in planting order.
func plantable_words(count_wanted: int, extra_known: Array[String] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in Data.words:
		var w: Dictionary = entry
		if is_known(word_key(w["word"])):
			continue
		var ready: bool = true
		for ch in w["kanji"]:
			var c: String = ch
			if not is_known(kanji_key(c)) and not extra_known.has(c):
				ready = false
				break
		if ready:
			out.append(w)
			if out.size() >= count_wanted:
				break
	return out
