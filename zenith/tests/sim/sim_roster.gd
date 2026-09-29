class_name SimRoster
extends RefCounted
## The decks a run draws from, on each side of the table, with weights.
##
## A field is a comma separated list of selectors, each optionally followed by `:weight`:
##
##   `*`                every deck
##   `steel_heir`       one deck by name
##   `@strike_beatdown` every deck of that archetype
##   `+fervor`          every deck carrying that subtheme
##   `#easy`            every deck of that pilot difficulty
##   `!storm_volley`    remove, whatever the earlier selectors added
##
## So `--field=@strike_beatdown:3,@allies:1,!pyre_beatdown` builds a bracket that is three parts
## beatdown to one part allies with one deck held out. Weights only matter in `sample` mode, where
## opponents are drawn at random; a `matrix` run plays every pair the same number of times.

var decks: Dictionary = {}          # name -> DeckList, every deck on disk
var all_names: Array[String] = []   # sorted, every deck on disk
var a_names: Array[String] = []
var b_names: Array[String] = []
var a_weights: Dictionary = {}      # name -> int
var b_weights: Dictionary = {}
var error: String = ""

const DECK_DIR: String = "res://data/decks"


## Loads every deck once and resolves both sides. `a_field` and `b_field` fall back to `field`
## when empty; `field` falls back to every deck. `deck_dir`, when set, adds the decks in that folder
## under their exact names only, so a trial list can be measured without touching `data/decks`.
static func build(field: String, a_field: String, b_field: String, deck_dir: String = "") -> SimRoster:
	var out: SimRoster = SimRoster.new()
	out._load_all()
	if out.error.is_empty() and not deck_dir.is_empty():
		out._load_extra(deck_dir)
	if not out.error.is_empty():
		return out
	var base: String = field if not field.strip_edges().is_empty() else "*"
	var a_spec: String = a_field if not a_field.strip_edges().is_empty() else base
	var b_spec: String = b_field if not b_field.strip_edges().is_empty() else base
	out.a_names = out._resolve(a_spec, out.a_weights)
	if not out.error.is_empty():
		return out
	out.b_names = out._resolve(b_spec, out.b_weights)
	if not out.error.is_empty():
		return out
	if out.a_names.is_empty() or out.b_names.is_empty():
		out.error = "A field resolved to no decks"
		return out
	if out.a_names.size() == 1 and out.b_names == out.a_names:
		out.error = "Both sides resolved to only %s; a deck cannot duel itself" % out.a_names[0]
	return out


func deck(name: String) -> DeckList:
	return decks.get(name, null)


## Every deck either side can field, sorted, for report tables.
func union() -> Array[String]:
	var seen: Dictionary = {}
	var out: Array[String] = []
	for group in [a_names, b_names]:
		for n in group:
			if not seen.has(n):
				seen[n] = true
				out.append(n)
	out.sort()
	return out


## One deck drawn from a side in proportion to its weight.
func pick(names: Array[String], weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: int = 0
	for n in names:
		total += int(weights.get(n, 1))
	if total <= 0:
		return names[rng.randi_range(0, names.size() - 1)]
	var roll: int = rng.randi_range(1, total)
	for n in names:
		roll -= int(weights.get(n, 1))
		if roll <= 0:
			return n
	return names[names.size() - 1]


## The same draw, refusing `avoid`. Returns "" when the side holds nothing else.
func pick_other(names: Array[String], weights: Dictionary, rng: RandomNumberGenerator, avoid: String) -> String:
	var pool: Array[String] = []
	for n in names:
		if n != avoid:
			pool.append(n)
	if pool.is_empty():
		return ""
	return pick(pool, weights, rng)


## One line per side, for a report header.
func describe(names: Array[String], weights: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for n in names:
		var w: int = int(weights.get(n, 1))
		parts.append(n if w == 1 else "%s:%d" % [n, w])
	return ", ".join(parts)


func _load_all() -> void:
	var dir: DirAccess = DirAccess.open(DECK_DIR)
	if dir == null:
		error = "Cannot open %s" % DECK_DIR
		return
	for file in DirAccess.get_files_at(DECK_DIR):
		if not file.ends_with(".json"):
			continue
		var name: String = file.trim_suffix(".json")
		var loaded: DeckList = DeckList.load_from(DECK_DIR.path_join(file))
		if loaded == null:
			error = "Cannot load deck %s" % file
			return
		decks[name] = loaded
		all_names.append(name)
	all_names.sort()
	# Adventure starters and opponent tiers answer to their exact names only. They stay out of
	# `all_names`, so `*`, `@archetype` and the default field are still the precons alone.
	for extra in ["res://data/adventure/starters", "res://data/adventure/opponents"]:
		if DirAccess.open(extra) == null:
			continue
		for file in DirAccess.get_files_at(extra):
			if file.ends_with(".json"):
				var adventure: DeckList = DeckList.load_from(extra.path_join(file))
				if adventure != null:
					decks[file.trim_suffix(".json")] = adventure
	if all_names.size() < 2:
		error = "Need at least two decks in %s" % DECK_DIR


func _load_extra(path: String) -> void:
	if DirAccess.open(path) == null:
		error = "Cannot open --deck-dir %s" % path
		return
	for file in DirAccess.get_files_at(path):
		if not file.ends_with(".json"):
			continue
		var loaded: DeckList = DeckList.load_from(path.path_join(file))
		if loaded == null:
			error = "Cannot load deck %s" % path.path_join(file)
			return
		decks[file.trim_suffix(".json")] = loaded


func _resolve(field: String, weights: Dictionary) -> Array[String]:
	var chosen: Array[String] = []
	var removed: Dictionary = {}
	for raw in field.split(",", false):
		var entry: String = raw.strip_edges()
		if entry.is_empty():
			continue
		var weight: int = 1
		var colon: int = entry.rfind(":")
		if colon > 0:
			var tail: String = entry.substr(colon + 1)
			if not tail.is_valid_int() or int(tail) < 1:
				error = "Weight after ':' must be a positive whole number: %s" % entry
				return []
			weight = int(tail)
			entry = entry.substr(0, colon)
		var drop: bool = entry.begins_with("!")
		if drop:
			entry = entry.substr(1)
		var matched: Array[String] = _expand(entry)
		if not error.is_empty():
			return []
		for n in matched:
			if drop:
				removed[n] = true
				continue
			removed.erase(n)
			if not chosen.has(n):
				chosen.append(n)
			weights[n] = weight
	var out: Array[String] = []
	for n in chosen:
		if not removed.has(n):
			out.append(n)
		else:
			weights.erase(n)
	return out


func _expand(selector: String) -> Array[String]:
	var out: Array[String] = []
	if selector == "*":
		out.assign(all_names)
		return out
	if selector.begins_with("@"):
		var want: String = selector.substr(1)
		for n in all_names:
			if (decks[n] as DeckList).archetype == want:
				out.append(n)
		if out.is_empty():
			error = "No deck has archetype %s" % want
		return out
	if selector.begins_with("+"):
		var want_sub: String = selector.substr(1)
		for n in all_names:
			if (decks[n] as DeckList).subthemes.has(want_sub):
				out.append(n)
		if out.is_empty():
			error = "No deck has subtheme %s" % want_sub
		return out
	if selector.begins_with("#"):
		var want_diff: String = selector.substr(1)
		for n in all_names:
			if (decks[n] as DeckList).difficulty == want_diff:
				out.append(n)
		if out.is_empty():
			error = "No deck has pilot difficulty %s" % want_diff
		return out
	if not decks.has(selector):
		error = "Unknown deck %s. Known decks: %s" % [selector, ", ".join(PackedStringArray(all_names))]
		return out
	out.append(selector)
	return out
