class_name AdventureLadder
extends RefCounted
## The run of opponents a starter fights: one shared pipeline of stages, each rolled from a band
## of opponent decks by the run's seed. Every starter goes through the same pipeline; the roll is
## what makes two runs differ, and the same seed rolls the same opponents on resume.

const DIR: String = "res://data/adventure/ladders"
const PIPELINE: String = "res://data/adventure/ladders/pipeline.json"
const BANDS: String = "res://data/adventure/opponent_bands.json"
const STARTERS_DIR: String = "res://data/adventure/starters"
## The deck-id suffixes that mark a starter or an opponent tier; strip one to get the family.
const SUFFIXES: Array[String] = ["_start", "_t1", "_t2", "_t3", "_t4", "_t5", "_boss"]

## Stage rows: {opponent: deck id, tier: t1..t5 | boss, band: weaker | medium | stronger,
## ai_level: easy | default | hard, grant: "" | "aspect", story: ""}
var starter_id: String = ""
var stages: Array[Dictionary] = []


## The pipeline rolled for one run. A row that names an `opponent` outright keeps it; every other
## row draws a family from its band, never the starter's own family and never one already drawn
## while the band still has others, and fights that family's deck at the row's tier.
static func load_for(starter_id_value: String, run_seed: int = 0) -> AdventureLadder:
	var rows: Array = _read_rows()
	if rows.is_empty():
		return null
	var bands: Dictionary = _read_bands()
	var ladder: AdventureLadder = AdventureLadder.new()
	ladder.starter_id = starter_id_value
	var own: String = family_of(starter_id_value)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [starter_id_value, run_seed])
	var drawn: Array[String] = []
	for entry in rows:
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var tier: String = str(row.get("tier", "t1"))
		var band: String = str(row.get("band", ""))
		var opponent: String = str(row.get("opponent", ""))
		if opponent.is_empty():
			var pool: Array[String] = _pool(bands, band, own, drawn)
			if pool.is_empty():
				push_error("Pipeline band '%s' has no deck for %s" % [band, starter_id_value])
				return null
			var family: String = pool[rng.randi_range(0, pool.size() - 1)]
			drawn.append(family)
			opponent = "%s_%s" % [family, tier]
		ladder.stages.append({
			"opponent": opponent,
			"tier": tier,
			"band": band,
			"ai_level": str(row.get("ai_level", "default")),
			"grant": str(row.get("grant", "")),
			"story": str(row.get("story", "")),
		})
	return ladder


## The families a row may draw: its band minus the starter's own and minus those already drawn;
## repeats are allowed again only once the band is used up.
static func _pool(bands: Dictionary, band: String, own: String, drawn: Array[String]) -> Array[String]:
	var members: Array[String] = []
	for f in bands.get(band, []):
		if str(f) != own:
			members.append(str(f))
	var fresh: Array[String] = []
	for f in members:
		if not drawn.has(f):
			fresh.append(f)
	return fresh if not fresh.is_empty() else members


static func _read_rows() -> Array:
	if not FileAccess.file_exists(PIPELINE):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PIPELINE))
	if not (parsed is Dictionary):
		push_error("Pipeline %s is not a JSON object" % PIPELINE)
		return []
	return (parsed as Dictionary).get("stages", [])


## band -> families, as written; a family is the deck id without its tier suffix.
static func _read_bands() -> Dictionary:
	if not FileAccess.file_exists(BANDS):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BANDS))
	return parsed if parsed is Dictionary else {}


## Every band's families, flattened and sorted.
static func banded_families() -> Array[String]:
	var out: Array[String] = []
	var bands: Dictionary = _read_bands()
	for band in bands.keys():
		for f in bands[band]:
			if not out.has(str(f)):
				out.append(str(f))
	out.sort()
	return out


## Starter ids, sorted: every deck file in the starters folder feeds the pipeline.
static func playable_starters() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(STARTERS_DIR)
	if dir == null:
		return out
	for entry in dir.get_files():
		if entry.ends_with(".json"):
			out.append(entry.trim_suffix(".json"))
	out.sort()
	return out


## The deck family a starter or opponent id belongs to: the id without its tier suffix.
static func family_of(deck_id: String) -> String:
	for suffix in SUFFIXES:
		if deck_id.ends_with(suffix):
			return deck_id.trim_suffix(suffix)
	return deck_id


## The tier word an opponent deck id ends in: T1..T5 or BOSS.
static func tier_of(opponent_id: String) -> String:
	var parts: PackedStringArray = opponent_id.split("_")
	return parts[parts.size() - 1].to_upper() if parts.size() > 0 else ""


## What every screen calls an opponent: its duelist's title, falling back to the deck name and
## then to the id.
static func opponent_name(opponent_id: String, library: CardLibrary) -> String:
	var deck: DeckList = DeckList.resolve(opponent_id)
	if deck == null:
		return opponent_id
	var duelist: CardDef = library.defs.get(deck.duelist_face_id())
	if duelist != null and duelist.title != "":
		return duelist.title
	return deck.name if deck.name != "" else opponent_id


func size() -> int:
	return stages.size()


func stage(n: int) -> Dictionary:
	if n < 0 or n >= stages.size():
		return {}
	return stages[n]
