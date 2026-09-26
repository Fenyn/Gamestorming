class_name AdventureSave
extends RefCounted
## The single saved run. One file, rewritten whenever the run moves.

const PATH: String = "user://adventure/run.json"

## Tests point this somewhere else so a run never lands on the player's save.
static var path_override: String = ""


static func path() -> String:
	return path_override if path_override != "" else PATH


static func exists() -> bool:
	return FileAccess.file_exists(path())


static func load_run() -> AdventureRun:
	var file: String = path()
	if not FileAccess.file_exists(file):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	var run: AdventureRun = null
	if parsed is Dictionary:
		run = AdventureRun.from_dict(parsed as Dictionary)
	# A save from before the current version, or one that will not parse, is dropped rather than
	# left to offer a Continue that can never load.
	if run == null:
		clear()
	return run


static func store(run: AdventureRun) -> bool:
	if run == null:
		return false
	var file: String = path()
	var dir: String = file.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var handle: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	if handle == null:
		push_error("AdventureSave: cannot write %s" % file)
		return false
	handle.store_string(JSON.stringify(run.to_dict(), "  "))
	handle.close()
	return true


static func clear() -> void:
	var file: String = path()
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
