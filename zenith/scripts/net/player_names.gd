class_name PlayerNames
extends RefCounted
## Online names are built, never typed: one word from each of two lists in
## `data/net/player_names.json`, "First Second". Nothing a player could type reaches another player,
## and the duel server refuses any name that is not a pair from the lists.

const FILE: String = "res://data/net/player_names.json"

static var _lists: Dictionary = {}


static func firsts() -> Array[String]:
	return _list("first")


static func seconds() -> Array[String]:
	return _list("second")


static func compose(first: String, second: String) -> String:
	return "%s %s" % [first, second]


## Whether `name` is one word from each list, in order, and not the same word twice ("Moth Moth"),
## since a few words sit on both lists.
static func valid(name: String) -> bool:
	var parts: PackedStringArray = name.split(" ")
	return parts.size() == 2 and parts[0] != parts[1] and parts[0] in firsts() and parts[1] in seconds()


## The two words of a valid name, ["", ""] otherwise.
static func split(name: String) -> Array[String]:
	if not valid(name):
		return ["", ""]
	var parts: PackedStringArray = name.split(" ")
	return [parts[0], parts[1]]


## A name drawn from the lists.
static func random(rng: RandomNumberGenerator = null) -> String:
	var r: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var a: Array[String] = firsts()
	var b: Array[String] = seconds()
	if a.is_empty() or b.is_empty():
		return ""
	var first: String = a[r.randi_range(0, a.size() - 1)]
	var second: String = b[r.randi_range(0, b.size() - 1)]
	while second == first and b.size() > 1:
		second = b[r.randi_range(0, b.size() - 1)]
	return compose(first, second)


static func _list(key: String) -> Array[String]:
	if _lists.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		_lists = parsed if parsed is Dictionary else {"first": [], "second": []}
	var out: Array[String] = []
	for word: Variant in _lists.get(key, []):
		out.append(str(word))
	return out
