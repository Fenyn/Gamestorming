extends SceneTree
## Folds `matchlab --shard` reports back into one. Shards sift a schedule that was built whole, so
## the merge is exactly the run you would have got from one process.
##
## godot --headless --path zenith -s tools/merge_matchlab.gd -- --in=res://reports/s0.json,... \
##     --json=res://reports/all.json


func _init() -> void:
	var inputs: PackedStringArray = PackedStringArray()
	var out_path: String = ""
	for raw in OS.get_cmdline_user_args():
		var parts: PackedStringArray = raw.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2:
			continue
		if parts[0] == "in":
			inputs = parts[1].split(",", false)
		elif parts[0] == "json":
			out_path = parts[1]
	if inputs.size() < 2:
		print("merge_matchlab: --in needs at least two shard reports")
		quit(2)
		return

	var report: SimReport = SimReport.new()
	var config: Dictionary = {}
	for path in inputs:
		var text: String = FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))
		var parsed: Variant = JSON.parse_string(text)
		if not parsed is Dictionary or not (parsed as Dictionary).has("state"):
			print("merge_matchlab: %s is not a matchlab report" % path)
			quit(2)
			return
		var one: Dictionary = parsed
		if config.is_empty():
			config = one["config"]
		elif not _same_run(config, one["config"]):
			print("merge_matchlab: %s was run with different settings" % path)
			quit(2)
			return
		report.absorb(one["state"])
	print("merged %d shards" % inputs.size())

	var a_side: SimSeat = SimSeat.from_dict(config.get("a_side", {}))
	var b_side: SimSeat = SimSeat.from_dict(config.get("b_side", {}))
	var roster: SimRoster = SimRoster.build("", ",".join(PackedStringArray(config.get("a_field", []))), ",".join(PackedStringArray(config.get("b_field", []))), str(config.get("deck-dir", "")))
	if not roster.error.is_empty():
		print("merge_matchlab: %s" % roster.error)
		quit(2)
		return
	report.print_all(roster, a_side, b_side, "=== matchlab, %d shards merged ===" % inputs.size())
	if not out_path.is_empty():
		report.write_json(ProjectSettings.globalize_path(out_path), config)
	quit(1 if report.failures > 0 else 0)


## Everything that shapes the schedule has to match, or the shards are not one run. Which slice a
## shard played and where it wrote its own files are the only differences allowed.
const PER_SHARD: Array[String] = ["shard", "json", "tsv", "records", "decisions", "progress", "verbose"]


func _same_run(a: Dictionary, b: Dictionary) -> bool:
	for key in a.keys():
		if not PER_SHARD.has(str(key)) and a[key] != b.get(key, null):
			return false
	return true
