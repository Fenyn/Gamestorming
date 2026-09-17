class_name AiProfile
extends RefCounted
## How one AI opponent values things. Everything is data: `own` weighs the AI's side of the
## table, `foe` weighs the opponent's, `effect` weighs card effect ops, and the knobs set how hard
## it thinks. A profile file only needs the entries it changes; the rest come from DEFAULTS.

const DIR: String = "res://data/ai/profiles"

const DEFAULTS: Dictionary = {
	"own": {
		"life": 1.0, "life_low": 1.5, "discard": 0.05, "vigor": 0.6, "band": 1.0, "hand": 1.2,
		"tier": 4.0, "favor": 30.0, "acclaim": 0.0, "token": 25.0, "ally": 2.5, "ally_vigor": 0.3, "drill": 2.0,
		"non_combat": 1.5, "attachment": 1.5, "forbid": 1.0, "grounds": 8.0,
	},
	"foe": {
		"life": 1.0, "life_low": 1.5, "discard": 0.05, "vigor": 0.6, "band": 1.0, "hand": 1.0,
		"tier": 4.0, "favor": 30.0, "token": 25.0, "ally": 2.5, "ally_vigor": 0.3, "drill": 2.0,
		"non_combat": 1.5, "attachment": 1.5, "forbid": 1.0, "grounds": 8.0,
	},
	"effect": {
		"vigor": 0.6, "acclaim": 2.0, "draw": 1.2, "search": 1.8, "discard_in_play": 2.2,
		"discard_hand": 1.0, "discard_life": 1.0, "recover": 0.8, "remove_discard": 0.15,
		"forbid": 1.5, "float": 1.0, "stop_all": 2.5, "attach": 1.5, "capture_token": 3.0,
		"other": 0.5, "if_successful": 0.6, "if_stopped": 0.3, "conditional": 0.7,
	},
	"play": {
		"damage_life": 1.0, "damage_stage": 0.5, "attack_cost": 0.5, "final_strike_penalty": 4.0,
		"defend_card": 1.0, "defend_in_play": 0.3, "use_cost": 0.3, "declare_bias": 0.5, "control_ally": 0.0, "grounds_skip": 0.6,
	},
	"think": {"search": true, "top_k": 6, "samples": 6, "budget_ms": 400, "max_steps": 80, "noise": 0.0, "prior": 0.05},
}

var name: String = "default"
var data: Dictionary = DEFAULTS.duplicate(true)


static func default_profile() -> AiProfile:
	return AiProfile.new()


static func load_from(path: String) -> AiProfile:
	var p: AiProfile = AiProfile.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "AI profile %s is not a JSON object" % path)
	p.merge(parsed)
	return p


## The profile for an AI playing `deck` at `level`: the defaults, then the deck's playstyle file
## (what it values), then the level file (how hard it thinks). Either name may be "".
static func for_deck(deck: DeckList, level: String) -> AiProfile:
	var p: AiProfile = AiProfile.new()
	var names: Array[String] = [deck.ai_profile if deck != null else "", level]
	for file in names:
		var path: String = DIR.path_join(file + ".json")
		if file == "" or not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			p.merge(parsed)
	return p


## Lays `over` on top of what is here, group by group.
func merge(over: Dictionary) -> void:
	name = str(over.get("name", name))
	for group in over.keys():
		if not (over[group] is Dictionary) or not data.has(group):
			continue
		var target: Dictionary = data[group]
		var source: Dictionary = over[group]
		for key in source.keys():
			target[key] = source[key]


func w(group: String, key: String) -> float:
	var g: Dictionary = data.get(group, {})
	return float(g.get(key, 0.0))


func think_int(key: String) -> int:
	return int(w("think", key))


func searches() -> bool:
	var g: Dictionary = data["think"]
	return bool(g.get("search", true))
