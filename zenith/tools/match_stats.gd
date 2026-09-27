extends SceneTree
## Reads finished match records and prints the numbers to watch balance by (`MatchStats`): per
## deck, deck against deck, the first player, how duels ended, ranked matches when there are any,
## and with `--cards`, per card.
##
##   godot --headless --path zenith -s tools/match_stats.gd -- --in=C:/records
##   godot --headless --path zenith -s tools/match_stats.gd -- --in=C:/records --since=2026-09-20 \
##       --cards --json=C:/records/week.json
##   godot --headless --path zenith -s tools/match_stats.gd -- --in=user://matches/local.jsonl \
##       --origin=client --mode=vs_ai,hotseat,adventure
##
## `--in` takes one JSON-lines file, or a folder whose every `*.jsonl` is read. Unknown flags stop
## the run, as in matchlab.

const SPEC: Dictionary = {
	"in": {"type": "str", "default": "user://matches"},
	"since": {"type": "str", "default": ""},
	"until": {"type": "str", "default": ""},
	"mode": {"type": "str", "default": "ranked,casual,code"},
	"origin": {"type": "str", "default": "server", "choices": ["server", "client", "all"]},
	"secret": {"type": "str", "default": ""},
	"catalog": {"type": "str", "default": "all"},
	"cards": {"type": "bool", "default": "off"},
	"tsv": {"type": "str", "default": ""},
	"json": {"type": "str", "default": ""},
}

static var _day: RegEx = RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$")
static var _hex_prefix: RegEx = RegEx.create_from_string("^[0-9a-f]{1,64}$")


## Deferred so the `Net` autoload, which knows this build's catalog hash, is in the tree.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	quit(_main())


func _main() -> int:
	var args: SimArgs = SimArgs.parse(SPEC, OS.get_cmdline_user_args())
	var problem: String = args.error
	var stats: MatchStats = MatchStats.new()
	if problem == "":
		problem = _configure(stats, args)
	var files: Array[String] = []
	if problem == "":
		files = _record_files(args.str_of("in"))
		if files.is_empty():
			problem = "--in: no .jsonl file at %s" % ProjectSettings.globalize_path(args.str_of("in"))
	if problem != "":
		print("match_stats: %s" % problem)
		return 2

	var lines: int = 0
	for path in files:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			print("match_stats: cannot read %s: %s" % [path, error_string(FileAccess.get_open_error())])
			return 2
		while not file.eof_reached():
			var text: String = file.get_line()
			if text.strip_edges().is_empty():
				continue
			lines += 1
			stats.add_line(text)
		file.close()

	print("match_stats: %d lines from %d file%s at %s" % [
		lines, files.size(), "" if files.size() == 1 else "s", ProjectSettings.globalize_path(args.str_of("in"))])
	print("  flags  : %s" % args.describe_given())
	print("  catalog: this build runs %s" % (stats.current_catalog.left(12) if stats.current_catalog != "" else "(unknown)"))
	print("")
	print(stats.to_text())

	var wrote: bool = true
	if not args.str_of("tsv").is_empty():
		wrote = _write(ProjectSettings.globalize_path(args.str_of("tsv")), stats.to_tsv()) and wrote
	if not args.str_of("json").is_empty():
		var summary: Dictionary = stats.to_json()
		summary["config"] = args.to_dict()
		summary["written_unix"] = int(Time.get_unix_time_from_system())
		wrote = _write(ProjectSettings.globalize_path(args.str_of("json")), JSON.stringify(summary, "\t") + "\n") and wrote
	return 0 if wrote else 1


## Moves the flags onto `stats`. "" when they all make sense, otherwise what does not.
func _configure(stats: MatchStats, args: SimArgs) -> String:
	for key in ["since", "until"]:
		var day: String = args.str_of(key).strip_edges()
		if day != "" and _day.search(day) == null:
			return "--%s takes a date as YYYY-MM-DD, got %s" % [key, day]
	stats.since = args.str_of("since").strip_edges()
	stats.until = args.str_of("until").strip_edges()

	var modes: Array[String] = []
	for part in args.str_of("mode").split(",", false):
		var mode: String = part.strip_edges()
		if not MatchRecord.MODES.has(mode):
			return "--mode takes any of %s, got %s" % [", ".join(PackedStringArray(MatchRecord.MODES)), mode]
		modes.append(mode)
	if modes.is_empty():
		return "--mode names no mode"
	stats.modes = modes
	stats.origin = args.str_of("origin")

	var catalog: String = args.str_of("catalog").strip_edges().to_lower()
	if catalog != "all":
		if _hex_prefix.search(catalog) == null:
			return "--catalog takes all or the start of a catalog hash, got %s" % catalog
		stats.catalog_prefix = catalog

	if not args.str_of("secret").is_empty():
		var match_log: MatchLog = MatchLog.new()
		var problem: String = _open_secret(match_log, args.str_of("secret"))
		if problem != "":
			return problem
		stats.verifier = match_log

	var net: Node = root.get_node_or_null("Net")
	stats.current_catalog = str(net.call("catalog_fingerprint")) if net != null else ""
	if args.bool_of("cards"):
		var library: CardLibrary = CardLibrary.new()
		library.load_dir("res://data/cards")
		stats.library = library
		stats.strike_table = StrikeTable.load_from("res://data/strike_table.json")
	return ""


## Loads the server's key from `path`, the key file itself or the folder holding it.
func _open_secret(match_log: MatchLog, path: String) -> String:
	var dir: String = path
	if not DirAccess.dir_exists_absolute(path):
		if path.get_file() != MatchLog.KEY_FILE:
			return "--secret names the server's %s or the folder holding it, got %s" % [MatchLog.KEY_FILE, path]
		dir = path.get_base_dir()
	var key_path: String = dir.path_join(MatchLog.KEY_FILE)
	# `MatchLog.open` makes a fresh key where there is none, and a fresh key verifies nothing.
	if not FileAccess.file_exists(key_path):
		return "--secret: no %s at %s" % [MatchLog.KEY_FILE, ProjectSettings.globalize_path(key_path)]
	var problem: String = match_log.open(dir)
	return "--secret: " + problem if problem != "" else ""


func _record_files(path: String) -> Array[String]:
	var out: Array[String] = []
	if DirAccess.dir_exists_absolute(path):
		for file_name in DirAccess.get_files_at(path):
			if file_name.ends_with(".jsonl"):
				out.append(path.path_join(file_name))
		out.sort()
	elif FileAccess.file_exists(path):
		out.append(path)
	return out


func _write(path: String, text: String) -> bool:
	var folder_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if folder_error != OK:
		print("match_stats: cannot create %s: %s" % [path.get_base_dir(), error_string(folder_error)])
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("match_stats: cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	var stored: bool = file.store_string(text)
	file.close()
	if stored:
		print("wrote %s" % path)
	return stored
