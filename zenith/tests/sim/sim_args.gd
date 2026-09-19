class_name SimArgs
extends RefCounted
## Validated command-line flags for the simulation harness. A flag the spec does not name is an
## error rather than a silent no-op, and an integer flag that will not parse is an error rather
## than a zero. That is the difference between a run you can trust and `--repeat=20` quietly
## running the default nine.
##
## A spec entry is `key -> {"type": "int"|"float"|"str"|"bool", "default": value, "min": n,
## "max": n, "choices": [..]}`. `bool` flags may be written bare (`--verbose`) or with a value
## (`--verbose=off`).
##
## `--scenario=<path>` loads a JSON object of the same keys as a base layer; anything on the
## command line overrides it. Values in the file may be written as JSON numbers or booleans, and a
## key starting with `_` is a note rather than a flag.

const SCENARIO_KEY: String = "scenario"

var spec: Dictionary = {}
var values: Dictionary = {}      # key -> String, every key in the spec present
var given: Dictionary = {}       # key -> true for keys the caller actually set
var error: String = ""
var scenario_path: String = ""


## The parsed flags, or an object whose `error` is set. `raw` is normally `OS.get_cmdline_user_args()`.
static func parse(p_spec: Dictionary, raw: PackedStringArray) -> SimArgs:
	var out: SimArgs = SimArgs.new()
	out.spec = p_spec
	for key in p_spec.keys():
		out.values[key] = str((p_spec[key] as Dictionary).get("default", ""))
	var typed: Array[Array] = []
	for entry in raw:
		var pair: Array = out._split(entry)
		if not out.error.is_empty():
			return out
		typed.append(pair)
	for pair in typed:
		if str(pair[0]) == SCENARIO_KEY:
			out.scenario_path = str(pair[1])
	if not out.scenario_path.is_empty():
		out._apply_scenario(out.scenario_path)
		if not out.error.is_empty():
			return out
	for pair in typed:
		out._set(str(pair[0]), str(pair[1]))
		if not out.error.is_empty():
			return out
	out._validate()
	return out


func has(key: String) -> bool:
	return bool(given.get(key, false))


func str_of(key: String) -> String:
	return str(values.get(key, ""))


func int_of(key: String) -> int:
	return int(str_of(key))


func float_of(key: String) -> float:
	return float(str_of(key))


func bool_of(key: String) -> bool:
	var v: String = str_of(key).to_lower()
	return v in ["1", "true", "on", "yes"]


## The flags as a dictionary of native types, for a report header.
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for key in spec.keys():
		var kind: String = str((spec[key] as Dictionary).get("type", "str"))
		match kind:
			"int": out[key] = int_of(key)
			"float": out[key] = float_of(key)
			"bool": out[key] = bool_of(key)
			_: out[key] = str_of(key)
	return out


## The flags the caller set, as one line, so a report says what produced it.
func describe_given() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var keys: Array = given.keys()
	keys.sort()
	for key in keys:
		parts.append("--%s=%s" % [key, str_of(str(key))])
	return " ".join(parts) if not parts.is_empty() else "(all defaults)"


func _split(entry: String) -> Array:
	if not entry.begins_with("--"):
		error = "Arguments start with --: %s" % entry
		return []
	var parts: PackedStringArray = entry.trim_prefix("--").split("=", true, 1)
	var key: String = parts[0]
	if not spec.has(key):
		error = "Unknown flag --%s. Known flags: %s" % [key, ", ".join(_known())]
		return []
	if parts.size() == 1:
		if str((spec[key] as Dictionary).get("type", "str")) != "bool":
			error = "--%s needs a value" % key
			return []
		return [key, "1"]
	return [key, parts[1]]


func _apply_scenario(path: String) -> void:
	if not FileAccess.file_exists(path):
		error = "Scenario file not found: %s" % path
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		error = "Scenario file is not a JSON object: %s" % path
		return
	var loaded: Dictionary = parsed
	for key in loaded.keys():
		var name: String = str(key)
		# A leading underscore is a note to a reader, not a flag.
		if name == SCENARIO_KEY or name.begins_with("_"):
			continue
		if not spec.has(name):
			error = "Scenario %s names an unknown flag: %s" % [path, name]
			return
		var raw: Variant = loaded[key]
		var text: String = str(raw)
		if raw is bool:
			text = "1" if raw else "0"
		elif raw is float and is_equal_approx(raw, roundf(raw)):
			text = str(int(raw))
		_set(name, text)
		if not error.is_empty():
			return


func _set(key: String, text: String) -> void:
	values[key] = text
	given[key] = true


func _validate() -> void:
	for key in spec.keys():
		var rule: Dictionary = spec[key]
		var kind: String = str(rule.get("type", "str"))
		var text: String = str_of(str(key))
		match kind:
			"int":
				if not text.is_valid_int():
					error = "--%s must be a whole number, got %s" % [key, text]
					return
				var n: int = int(text)
				if rule.has("min") and n < int(rule["min"]):
					error = "--%s must be at least %d" % [key, int(rule["min"])]
					return
				if rule.has("max") and n > int(rule["max"]):
					error = "--%s must be at most %d" % [key, int(rule["max"])]
					return
			"float":
				if not text.is_valid_float():
					error = "--%s must be a number, got %s" % [key, text]
					return
			"bool":
				if not text.to_lower() in ["1", "0", "true", "false", "on", "off", "yes", "no"]:
					error = "--%s must be on or off, got %s" % [key, text]
					return
			_:
				if rule.has("choices") and not (rule["choices"] as Array).has(text):
					error = "--%s must be one of %s, got %s" % [key, ", ".join(PackedStringArray(rule["choices"])), text]
					return


func _known() -> PackedStringArray:
	var keys: Array = spec.keys()
	keys.sort()
	var out: PackedStringArray = PackedStringArray()
	for k in keys:
		out.append(str(k))
	return out
