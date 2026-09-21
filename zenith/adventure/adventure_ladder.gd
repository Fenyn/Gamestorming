class_name AdventureLadder
extends RefCounted
## The fixed run of opponents one starter fights, loaded from data/adventure/ladders.

const DIR: String = "res://data/adventure/ladders"

## Stage rows: {opponent: deck id, ai_level: easy | default | hard, grant: "" | "aspect", story: ""}
var starter_id: String = ""
var stages: Array[Dictionary] = []


static func load_for(starter_id_value: String) -> AdventureLadder:
	var path: String = "%s/%s.json" % [DIR, starter_id_value]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("Ladder %s is not a JSON object" % path)
		return null
	var blob: Dictionary = parsed
	var ladder: AdventureLadder = AdventureLadder.new()
	ladder.starter_id = str(blob.get("starter", starter_id_value))
	for entry in blob.get("stages", []):
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		ladder.stages.append({
			"opponent": str(row.get("opponent", "")),
			"ai_level": str(row.get("ai_level", "default")),
			"grant": str(row.get("grant", "")),
			"story": str(row.get("story", "")),
		})
	return ladder


## Starter ids with a ladder file, sorted.
static func playable_starters() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(DIR)
	if dir == null:
		return out
	for entry in dir.get_files():
		if entry.ends_with(".json"):
			out.append(entry.trim_suffix(".json"))
	out.sort()
	return out


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
