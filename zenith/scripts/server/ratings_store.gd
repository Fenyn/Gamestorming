class_name RatingsStore
extends RefCounted
## Ranked ratings on the duel server: `ratings.json` in its data directory, identity id ->
## {"mu", "sigma", "games" (rated matches played), "wins", "last_played" (Unix seconds)}. The file is
## written whole to a temporary file and renamed over the old one, so a crash leaves one or the
## other. The match records stay the source of truth: `rebuild` replays every ranked match result.

const FILE: String = "ratings.json"
const ID_MAX: int = 128

## Where `save` writes, "" to keep everything in memory.
var path: String = ""
var entries: Dictionary = {}


## Loads the file from `dir`, or starts empty when there is none. "" when ready, otherwise why not;
## the server does not start on a file it cannot read, since writing over it would reset everyone.
func open(dir: String) -> String:
	path = dir.path_join(FILE)
	entries.clear()
	if not FileAccess.file_exists(path):
		return ""
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return "%s is not a ratings file" % path
	for key: Variant in (json.data as Dictionary).keys():
		var entry: Dictionary = _entry((json.data as Dictionary)[key])
		if not (key is String) or str(key) == "" or str(key).length() > ID_MAX or entry.is_empty():
			return "%s has a malformed entry" % path
		entries[str(key)] = entry
	return ""


## An identity's rating, a new player's when it has none. A copy; nothing is stored until `apply`.
func get_or_new(id: String) -> Dictionary:
	if entries.has(id):
		return (entries[id] as Dictionary).duplicate()
	return {"mu": Rating.MU, "sigma": Rating.SIGMA, "games": 0, "wins": 0, "last_played": 0}


## One rated match, won by `winner_id`, applied and saved: {"winner": {"before", "after"}, "loser":
## {...}, "problem"}, each before and after {"mu", "sigma"}, and "problem" "" or why the file was not
## written. {} for an identity playing itself, which is never rated.
func apply(winner_id: String, loser_id: String, now: int) -> Dictionary:
	var change: Dictionary = _apply(winner_id, loser_id, now)
	if not change.is_empty():
		change["problem"] = save()
	return change


func _apply(winner_id: String, loser_id: String, now: int) -> Dictionary:
	if winner_id == loser_id or winner_id == "" or loser_id == "":
		return {}
	var w: Dictionary = get_or_new(winner_id)
	var l: Dictionary = get_or_new(loser_id)
	var after: Array[Dictionary] = Rating.rate(w, l)
	entries[winner_id] = {"mu": after[0]["mu"], "sigma": after[0]["sigma"], "games": int(w["games"]) + 1,
		"wins": int(w["wins"]) + 1, "last_played": now}
	entries[loser_id] = {"mu": after[1]["mu"], "sigma": after[1]["sigma"], "games": int(l["games"]) + 1,
		"wins": int(l["wins"]), "last_played": now}
	return {"winner": {"before": {"mu": w["mu"], "sigma": w["sigma"]}, "after": after[0]},
		"loser": {"before": {"mu": l["mu"], "sigma": l["sigma"]}, "after": after[1]}}


## "" when written, otherwise why not.
func save() -> String:
	if path == "":
		return ""
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return error_string(FileAccess.get_open_error())
	var stored: bool = file.store_string(JSON.stringify(entries, "", true, true) + "\n")
	file.close()
	if not stored:
		return "the write did not complete"
	var moved: Error = DirAccess.rename_absolute(temp, path)
	return "" if moved == OK else error_string(moved)


## Starts over and replays every ranked match result in `records` (MatchRecords, in the order they
## were played, as the day files hold them): each server record whose `match` has a winner, between
## two identities. Returns how many matches it applied. Nothing is saved; `save` writes the result.
func rebuild(records: Array) -> int:
	entries.clear()
	var applied: int = 0
	for item: Variant in records:
		if not (item is MatchRecord):
			continue
		var record: MatchRecord = item
		if record.mode != "ranked" or record.origin != "server" or record.dev or record.match_result.is_empty():
			continue
		var winner: int = int(record.match_result["winner"])
		if winner < 0:
			continue
		var ids: Array[String] = [str(record.seats[0]["identity"]), str(record.seats[1]["identity"])]
		if not _apply(ids[winner], ids[1 - winner], record.started).is_empty():
			applied += 1
	return applied


## A stored entry with every field checked, or {}.
static func _entry(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = raw
	var mu: Variant = d.get("mu")
	var sigma: Variant = d.get("sigma")
	if not ((mu is float or mu is int) and (sigma is float or sigma is int)) or not is_finite(float(mu)) \
			or not is_finite(float(sigma)) or float(sigma) <= 0.0:
		return {}
	var counts: Array[int] = []
	for key in ["games", "wins", "last_played"]:
		var n: Variant = d.get(key)
		if not (n is float or n is int) or float(n) < 0.0 or float(n) != floorf(float(n)):
			return {}
		counts.append(int(n))
	if counts[1] > counts[0]:
		return {}
	return {"mu": float(mu), "sigma": float(sigma), "games": counts[0], "wins": counts[1], "last_played": counts[2]}
