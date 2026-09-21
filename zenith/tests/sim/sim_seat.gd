class_name SimSeat
extends RefCounted
## One side of a test run: which policy it plays, whether it uses each deck's own playstyle, and
## how hard it is allowed to think. Both sides are configured independently, so a run can ask
## "does Hard beat Easy" or "does 800 ms beat 200 ms" rather than only "which deck is stronger".
##
## Every knob reads a side flag first (`--a-budget`) and a shared flag second (`--budget`). A knob
## neither flag sets is left to the profile.

## Flag suffix -> the `think` key it overrides, and whether it is a whole number.
const KNOBS: Dictionary = {
	"budget": ["budget_ms", true],
	"samples": ["samples", true],
	"turns": ["turns", true],
	"steps": ["max_steps", true],
	"depth": ["sequence_depth", true],
	"nodes": ["node_budget", true],
	"branches": ["branch_width", true],
	"responses": ["response_width", true],
	"top-k": ["top_k", true],
	"rollout-steps": ["rollout_steps", true],
	"noise": ["noise", false],
	"prior": ["prior", false],
	"settle-plies": ["settle_plies", true],
	"settle-lead": ["settle_lead", false],
	"branch-margin": ["branch_margin", false],
	"predict-depth": ["predict_depth", true],
}

## Policies that are not the name of a level file under `data/ai/profiles`.
const BUILT_IN: Array[String] = ["random", "scorer", "search", "rollout"]

var label: String = "a"
var policy: String = "search"
var styles: bool = true
var think: Dictionary = {}       # `think` overrides laid over the profile
var error: String = ""


static func policy_error(value: String) -> String:
	if BUILT_IN.has(value):
		return ""
	if value.is_empty() or value.contains("/") or value.contains("\\") or not FileAccess.file_exists(AiProfile.DIR.path_join(value + ".json")):
		return "Unknown policy '%s'; expected %s or a profile under %s" % [value, ", ".join(PackedStringArray(BUILT_IN)), AiProfile.DIR]
	return ""


## Adapter for older runners' string dictionaries, preserving their optional empty knobs.
static func from_legacy(policy_name: String, args: Dictionary, use_styles: bool = true) -> SimSeat:
	var out: SimSeat = SimSeat.new()
	out.policy = policy_name
	out.styles = use_styles
	out.error = policy_error(policy_name)
	if not out.error.is_empty():
		return out
	for suffix in KNOBS:
		if not args.has(suffix) or str(args[suffix]).is_empty():
			continue
		var mapping: Array = KNOBS[suffix]
		out.think[mapping[0]] = int(args[suffix]) if bool(mapping[1]) else float(args[suffix])
	# ai_arena historically used an underscore for this one option.
	if args.has("rollout_steps") and not str(args["rollout_steps"]).is_empty():
		out.think["rollout_steps"] = int(args["rollout_steps"])
	return out


## Rebuilds a side from what `to_dict` wrote into a report, for the shard merge.
static func from_dict(d: Dictionary) -> SimSeat:
	var out: SimSeat = SimSeat.new()
	out.policy = str(d.get("policy", "scorer"))
	out.styles = bool(d.get("styles", true))
	out.think = (d.get("think", {}) as Dictionary).duplicate()
	return out


## Reads the `a` or `b` side out of parsed flags.
static func from_args(args: SimArgs, p_label: String) -> SimSeat:
	var out: SimSeat = SimSeat.new()
	out.label = p_label
	var policy_key: String = p_label if args.has(p_label) else "policy"
	out.policy = args.str_of(policy_key)
	out.styles = args.bool_of("%s-styles" % p_label) if args.has("%s-styles" % p_label) else args.bool_of("styles")
	out.error = policy_error(out.policy)
	if not out.error.is_empty():
		out.error = "--%s: %s" % [policy_key, out.error]
		return out
	for suffix in KNOBS.keys():
		var pair: Array = KNOBS[suffix]
		var side_key: String = "%s-%s" % [p_label, suffix]
		var key: String = side_key if args.has(side_key) else str(suffix)
		if not args.has(key):
			continue
		out.think[str(pair[0])] = args.int_of(key) if bool(pair[1]) else args.float_of(key)
	var raw: String = args.str_of("%s-think" % p_label) if args.has("%s-think" % p_label) else args.str_of("think")
	if not raw.strip_edges().is_empty():
		out._parse_think(raw)
	return out


## The driver for `deck`, or null when this side plays uniformly at random.
func make_player(deck: DeckList, seed_value: int) -> AiPlayer:
	var profile: AiProfile = make_profile(deck)
	return AiPlayer.new(profile, seed_value) if profile != null else null


## Diagnostics can inspect exactly the same resolved profile as the normal seat driver.
func make_profile(deck: DeckList) -> AiProfile:
	error = policy_error(policy)
	if not error.is_empty():
		push_error(error)
		return null
	if policy == "random":
		return null
	var level: String = "" if BUILT_IN.has(policy) else policy
	var profile: AiProfile = AiProfile.for_deck(deck if styles else null, level)
	match policy:
		"scorer":
			profile.merge({"think": {"search": false}})
		"search":
			profile.merge({"think": {"search": true, "algorithm": "sequence"}})
		"rollout":
			profile.merge({"think": {"search": true, "algorithm": "rollout"}})
	if not think.is_empty():
		profile.merge({"think": think.duplicate()})
	return profile


func describe() -> String:
	var parts: PackedStringArray = PackedStringArray([policy])
	if not styles:
		parts.append("no deck playstyle")
	var keys: Array = think.keys()
	keys.sort()
	for k in keys:
		parts.append("%s=%s" % [k, str(think[k])])
	return " / ".join(parts)


func to_dict() -> Dictionary:
	return {"policy": policy, "styles": styles, "think": think.duplicate()}


## `--a-think=budget_ms=800;cache=1` for any knob without its own flag.
func _parse_think(raw: String) -> void:
	for chunk in raw.split(";", false):
		var parts: PackedStringArray = chunk.strip_edges().split("=", true, 1)
		if parts.size() != 2 or parts[0].strip_edges().is_empty():
			error = "--%s-think takes key=value pairs separated by ';', got %s" % [label, chunk]
			return
		var key: String = parts[0].strip_edges()
		var text: String = parts[1].strip_edges()
		if not (AiProfile.DEFAULTS["think"] as Dictionary).has(key):
			error = "--%s-think names an unknown knob: %s" % [label, key]
			return
		if text.is_valid_int():
			think[key] = int(text)
		elif text.is_valid_float():
			think[key] = float(text)
		elif text.to_lower() in ["true", "on", "yes"]:
			think[key] = true
		elif text.to_lower() in ["false", "off", "no"]:
			think[key] = false
		elif text.begins_with("[") and text.ends_with("]"):
			# A list, written [a,b,c]. Used by `scorer_kinds`.
			var items: Array = []
			for item in text.substr(1, text.length() - 2).split(",", false):
				items.append(item.strip_edges())
			think[key] = items
		else:
			think[key] = text
