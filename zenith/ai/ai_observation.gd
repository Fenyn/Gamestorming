class_name AiObservation
extends RefCounted
## Observation keys group choices across sampled worlds, never equivalent engine states.
## Callers must obtain simulations through Referee.sim_for and retain observation/action
## history along each policy branch: the current SeatView is not a perfect-recall transcript.
## Referee samples undisclosed opposing composition from a broad public library prior.
## These helpers preserve that information boundary; they do not infer a known custom list.


static func key(sim: DuelEngine, seat: int) -> String:
	var pending: Prompt = sim.prompt_of(seat)
	return from_views(SeatView.of(sim, seat, false), PromptView.of(pending, sim) if pending != null else null)


## Reuse already-created permitted views when available. Derived forecasts are excluded in
## both paths; no true-state field or opponent-only prompt is added to this observation.
static func from_views(view: SeatView, prompt: PromptView = null) -> String:
	var visible: Dictionary = view.to_dict()
	visible.erase("forecasts")  # Derived action summaries do not add an observation.
	var cards: Array = visible["cards"]
	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["uid"]) < int(b["uid"]))
	var decision: Dictionary = prompt.to_dict() if prompt != null else {}
	if not decision.is_empty():
		var options: Array = decision["options"]
		options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _wire(a) < _wire(b))
	return _wire({"view": visible, "prompt": decision})


static func command_key(cmd: Command) -> String:
	return _wire(cmd.to_dict())


## Resolve by command contents, never by the option's position in another sampled prompt.
## Batch commands are accepted only through the prompt's existing validation path.
static func find_command(prompt: Prompt, wire: Dictionary) -> Command:
	if prompt == null:
		return null
	var wanted: String = _wire(wire)
	for option in prompt.options:
		if command_key(option) == wanted:
			return option
	return prompt.accept(Command.from_dict(wire))


## Exact, search-local state serialization, intentionally separate from observation grouping.
## Includes RNG, pending queues/choices, usage flags, card identities and ordered zones. Card
## references become UIDs and each mutable card record appears once. Shared immutable rules
## are scoped by their object identities, so this key must not be persisted between searches.
## This is deliberately conservative and can be expensive: skipping transpositions is safer
## than caching leaf values by key(). Unknown object types return "" to disable caching.
static func state_key(sim: DuelEngine) -> String:
	var valid: Dictionary = {"ok": true, "schemas": {}}
	var omitted: Array[String] = ["events", "record_display_state", "prompt", "library", "strike_table", "_cards", "rng"]
	var cards: Array = []
	var ids: Array = sim._cards.keys()
	ids.sort()
	for uid in ids:
		cards.append(_record(sim._cards[uid], valid))
	var record: Dictionary = {
		"rules_library": sim.library.get_instance_id() if sim.library != null else 0,
		"strike_table": sim.strike_table.get_instance_id() if sim.strike_table != null else 0,
		"engine": _record(sim, valid, omitted), "cards": cards,
		"rng_seed": str(sim.rng._rng.seed) if sim.rng != null else "",
		"rng_state": str(sim.rng._rng.state) if sim.rng != null else "",
	}
	return Marshalls.raw_to_base64(var_to_bytes(record)) if bool(valid["ok"]) else ""


static func _record(object: Object, valid: Dictionary, excluded: Array[String] = []) -> Array:
	var script: Script = object.get_script()
	var script_id: int = script.get_instance_id()
	# A per-serialization metadata cache avoids concurrent worker writes to a static table.
	var schemas: Dictionary = valid["schemas"]
	if not schemas.has(script_id):
		var names: Array[String] = []
		for property in object.get_property_list():
			if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				names.append(str(property["name"]))
		names.sort()
		schemas[script_id] = names
	var values: Array = []
	for name in schemas[script_id]:
		if not excluded.has(name):
			values.append(_normalized(object.get(name), valid))
	# Script identity fixes this sorted field schema within one search; write names once in
	# metadata rather than hundreds of times in every sampled card record.
	return [script_id, values]


static func _normalized(value: Variant, valid: Dictionary) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_BOOL:
			return value  # Binary serialization preserves primitive type and full precision.
	if value is CardInstance:
		return {"card_ref": (value as CardInstance).uid}
	if value is CardDef:
		return {"definition": (value as CardDef).id}
	if value is Dictionary:
		var entries: Array = []
		var keys: Array = value.keys()
		var uniform: bool = true
		for entry_key in keys:
			uniform = uniform and typeof(entry_key) == typeof(keys[0])
		if uniform:
			keys.sort()
		else:
			# Mixed key types are unusual; compute the ordering token once per key.
			var tokens: Dictionary = {}
			for entry_key in keys:
				tokens[entry_key] = Marshalls.raw_to_base64(var_to_bytes(entry_key))
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(tokens[a]) < str(tokens[b]))
		for entry_key in keys:
			entries.append([_normalized(entry_key, valid), _normalized(value[entry_key], valid)])
		return {"dictionary": entries}
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_normalized(item, valid))
		return {"array": items}
	if value is GameState or value is PlayerState or value is Prompt or value is Command:
		return {"record": _record(value, valid)}
	valid["ok"] = false
	return null


static func _wire(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)
