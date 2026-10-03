class_name PlayerProfile
extends RefCounted
## Who the player is to other players: the name they built on first launch (`PlayerNames`), saved
## in `user://profile.json` (`--dev-scratch=<dir>` moves it to `<dir>/profile.json`), and the best
## ranked rating the duel server last reported, which sets the rank this copy shows offline.
## The tag beside the name ("Ashen Warden#7625") is not stored: it comes from the install's identity
## key, so the duel server works it out from the key it has proven and no client can claim another's.

const FILE: String = "user://profile.json"
const NAME_MAX: int = 20
## Tests point this at a file of their own.
static var path_override: String = ""

## "" until the player has built one; always a `PlayerNames` pair otherwise.
var name: String = ""
var peak: int = 0


static func path() -> String:
	if path_override != "":
		return path_override
	for arg in DevArgs.user_args():
		if arg.begins_with("--dev-scratch="):
			return arg.substr("--dev-scratch=".length()).path_join("profile.json")
	return FILE


## The four-digit tag for an identity id (64 hex characters), the same on every machine.
static func tag_of(identity_id: String) -> String:
	if identity_id.length() < 8 or not identity_id.left(8).is_valid_hex_number():
		return ""
	return "%04d" % (identity_id.left(8).hex_to_int() % 10000)


## `raw` as a name may travel and reach a log: no brackets (rich text), no "#" (the tag's mark), no
## control characters, at most NAME_MAX characters, and `fallback` when nothing is left.
static func clean(raw: String, fallback: String) -> String:
	var out: String = ""
	for ch in raw.left(NAME_MAX * 4):
		var code: int = ch.unicode_at(0)
		if ch == "[" or ch == "]" or ch == "#" or code < 32 or code == 127:
			continue
		out += ch
	out = out.strip_edges().left(NAME_MAX).strip_edges()
	return out if out != "" else fallback


## "Name#7625", or the name alone without a tag.
static func display(player_name: String, tag: String) -> String:
	return player_name if tag == "" else "%s#%s" % [player_name, tag]


## The stored profile, or a new one without a name when there is none or it cannot be read. A
## stored name that is no longer a pair from the lists is dropped, so the title asks again.
static func load_profile(file: String = path()) -> PlayerProfile:
	var out: PlayerProfile = PlayerProfile.new()
	if not FileAccess.file_exists(file):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if parsed is Dictionary:
		var stored_name: String = str((parsed as Dictionary).get("name", ""))
		out.name = stored_name if PlayerNames.valid(stored_name) else ""
		var stored_peak: Variant = (parsed as Dictionary).get("peak", 0)
		if stored_peak is float or stored_peak is int:
			out.peak = maxi(0, int(stored_peak))
	return out


func named() -> bool:
	return name != ""


## "" when written, otherwise why not.
func save(file: String = path()) -> String:
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var f: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		return error_string(FileAccess.get_open_error())
	f.store_string(JSON.stringify({"name": name, "peak": peak}, "\t") + "\n")
	return ""


func rank() -> int:
	return Ranks.index_for(peak)
