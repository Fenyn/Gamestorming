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
}

## Policies that are not the name of a level file under `data/ai/profiles`.
const BUILT_IN: Array[String] = ["random", "scorer", "search", "rollout"]

var label: String = "a"
var policy: String = "search"
var styles: bool = true
var think: Dictionary = {}       # `think` overrides laid over the profile
var error: String = ""


## Reads the `a` or `b` side out of parsed flags.
static func from_args(args: SimArgs, p_label: String) -> SimSeat:
	var out: SimSeat = SimSeat.new()
	out.label = p_label
	out.policy = args.str_of(p_label) if args.has(p_label) else args.str_of("policy")
	out.styles = args.bool_of("%s-styles" % p_label) if args.has("%s-styles" % p_label) else args.bool_of("styles")
	if not BUILT_IN.has(out.policy) and not FileAccess.file_exists(AiProfile.DIR.path_join(out.policy + ".json")):
		out.error = "--%s=%s is neither a built-in policy (%s) nor a profile under %s" % [
			p_label, out.policy, ", ".join(PackedStringArray(BUILT_IN)), AiProfile.DIR]
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
	return AiPlayer.new(profile, seed_value)


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
		else:
			think[key] = text
