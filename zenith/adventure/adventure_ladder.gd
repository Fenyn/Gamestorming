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


func size() -> int:
	return stages.size()


func stage(n: int) -> Dictionary:
	if n < 0 or n >= stages.size():
		return {}
	return stages[n]
