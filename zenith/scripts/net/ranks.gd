class_name Ranks
extends RefCounted
## The ranked ladder: six ranks, each reached at a shown rating and never lost, since the duel
## server keeps every identity's best shown rating as its "peak". Everyone starts at the first.
## Names, emblems and colours as the user picked them on 2026-10-03 (set A).

const LADDER: Array[Dictionary] = [
	{"name": "Novice", "icon": "novice", "color": Color(0.588, 0.573, 0.549), "at": 0},
	{"name": "Adept", "icon": "adept", "color": Color(0.769, 0.478, 0.290), "at": 200},
	{"name": "Duelist", "icon": "duelist", "color": Color(0.627, 0.769, 0.824), "at": 400},
	{"name": "Archmage", "icon": "archmage", "color": Color(0.886, 0.361, 0.235), "at": 600},
	{"name": "Gatecarver", "icon": "gatecarver", "color": Color(0.690, 0.471, 0.910), "at": 800},
	{"name": "Eidolarch", "icon": "eidolarch", "color": Color(0.957, 0.910, 0.784), "at": 1000},
]
const ICON_DIR: String = "res://assets/ui/profile_icons"


## The rank a best shown rating of `peak` has reached.
static func index_for(peak: int) -> int:
	var out: int = 0
	for i in LADDER.size():
		if peak >= int(LADDER[i]["at"]):
			out = i
	return out


static func clamp_index(rank: int) -> int:
	return clampi(rank, 0, LADDER.size() - 1)


static func rank_name(rank: int) -> String:
	return str(LADDER[clamp_index(rank)]["name"])


static func color(rank: int) -> Color:
	return LADDER[clamp_index(rank)]["color"]


static func icon_path(rank: int) -> String:
	return "%s/%s.png" % [ICON_DIR, str(LADDER[clamp_index(rank)]["icon"])]
