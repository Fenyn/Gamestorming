class_name StrikeTable
extends RefCounted
## Base damage for a Strike. Bands are Might ranges; damage is the band gap plus one, capped.

var thresholds: Array[int] = [0]   # band i applies when might >= thresholds[i]; must be ascending, starting at 0
var cap: int = 9


static func from_dict(d: Dictionary) -> StrikeTable:
	var t: StrikeTable = StrikeTable.new()
	t.thresholds.assign(d.get("thresholds", [0]))
	t.cap = int(d.get("cap", 9))
	assert(t.thresholds.size() > 0 and t.thresholds[0] == 0, "Strike table must start at 0")
	return t


static func load_from(path: String) -> StrikeTable:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "Strike table %s is not a JSON object" % path)
	return StrikeTable.from_dict(parsed)


func band(might: int) -> int:
	# Thresholds ascend, so the first one met from the top is the answer.
	for i in range(thresholds.size() - 1, -1, -1):
		if might >= thresholds[i]:
			return i
	return 0


func base_damage(attacker_might: int, defender_might: int) -> int:
	return clampi(band(attacker_might) - band(defender_might) + 1, 0, cap)
