extends SceneTree
## Display-free referees and lightweight AI reads must preserve every gameplay outcome.

var checks: int = 0
var failures: int = 0
var captured_events: int = 0
var benchmarked: bool = false
var planner_checked: bool = false


func _init() -> void:
	var library: CardLibrary = CardLibrary.new()
	library.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var decks: Array[DeckList] = [DeckList.load_from("res://data/decks/pyre_beatdown.json"), DeckList.load_from("res://data/decks/steel_heir.json")]
	var normal: Referee = Referee.new()
	var fast: Referee = Referee.new()
	var names: Array[String] = ["Pilot", "Rival"]
	normal.setup(decks, library, table, 731, names)
	fast.setup(decks, library, table, 731, names, false)
	_check(normal.engine.record_display_state, "Normal referee captures display state by default")
	_check(not fast.engine.record_display_state, "Headless referee disables snapshots before setup")
	_compare(normal, fast, "setup")
	normal.start()
	fast.start()
	_compare(normal, fast, "start")
	var profile: AiProfile = AiProfile.default_profile()
	profile.merge({"think": {"search": false, "noise": 0.0}})
	var drivers: Array[AiPlayer] = [AiPlayer.new(profile, 997), AiPlayer.new(profile, 998)]
	var moves: int = 0
	while not normal.is_over() and moves < 1200 and failures == 0:
		var seat: int = normal.engine.prompt.player
		if not normal.view_for(seat).forecasts.is_empty():
			if not planner_checked:
				_compare_planners(normal, fast, seat)
			if not benchmarked:
				_benchmark(normal, seat)
		var command: Dictionary = drivers[seat].choose(normal, seat)
		_check(normal.submit(seat, command).is_empty(), "Normal referee accepts scorer move")
		_check(fast.submit(seat, command).is_empty(), "Headless referee accepts identical move")
		moves += 1
		_compare(normal, fast, "move %d" % moves)
	_check(normal.is_over() and fast.is_over(), "Both identical games finish")
	_check(captured_events > 0, "Normal gameplay retains populated animation snapshots")
	_check(benchmarked, "Timing benchmark reaches a real attack-choice forecast")
	_check(planner_checked, "Fixed-node planner comparison reaches a real attack choice")
	print("Headless overhead: %d checks, %d failures, %d identical moves, %d display snapshots retained in normal mode" % [checks, failures, moves, captured_events])
	quit(0 if failures == 0 else 1)


func _compare(normal: Referee, fast: Referee, label: String) -> void:
	_check(_state(normal.engine) == _state(fast.engine), label + ": complete mutable state and RNG agree")
	for seat in range(2):
		var full: Dictionary = normal.view_for(seat).to_dict()
		_check(full == fast.view_for(seat).to_dict(), label + ": seat view agrees")
		var light: Dictionary = normal.view_for(seat, false).to_dict()
		_check((light["forecasts"] as Dictionary).is_empty(), label + ": lightweight view skips forecasts")
		full.erase("forecasts")
		light.erase("forecasts")
		_check(full == light, label + ": lightweight view preserves every other field")
		_check(normal.view_for(seat, false).to_dict() == fast.view_for(seat, false).to_dict(), label + ": headless lightweight view agrees")
		var normal_prompt: PromptView = normal.prompt_for(seat)
		var fast_prompt: PromptView = fast.prompt_for(seat)
		_check((normal_prompt.to_dict() if normal_prompt != null else {}) == (fast_prompt.to_dict() if fast_prompt != null else {}), label + ": prompt agrees")
		var kind: StringName = normal_prompt.kind if normal_prompt != null else &""
		_check(normal.prompt_kind_for(seat) == kind and fast.prompt_kind_for(seat) == kind, label + ": lightweight kind matches own prompt")
	var normal_events: Array[GameEvent] = normal.engine.take_events()
	var fast_events: Array[GameEvent] = fast.engine.take_events()
	_check(normal_events.size() == fast_events.size(), label + ": event counts agree")
	for i in range(mini(normal_events.size(), fast_events.size())):
		var display: GameEvent = normal_events[i]
		var headless: GameEvent = fast_events[i]
		_check(display.type == headless.type and display.data == headless.data, label + ": event type and rule data agree")
		_check(headless.state.is_empty(), label + ": headless event has no animation snapshot")
		if not display.state.is_empty():
			captured_events += 1


func _compare_planners(normal: Referee, fast: Referee, seat: int) -> void:
	var profile: AiProfile = AiProfile.default_profile()
	profile.merge({"think": {"search": true, "algorithm": "sequence", "budget_ms": 0, "samples": 1, "node_budget": 40, "sequence_depth": 2, "branch_width": 2, "response_width": 1, "rollout_steps": 2, "settle_steps": 3}})
	var a: AiPlayer = AiPlayer.new(profile, 111)
	var b: AiPlayer = AiPlayer.new(profile, 111)
	var before: Dictionary = _state(normal.engine)
	var command_a: Dictionary = a.choose(normal, seat)
	var command_b: Dictionary = b.choose(fast, seat)
	_check(command_a == command_b, "Fixed-node planner chooses identical commands with and without display capture")
	_check(a.search.metrics.get("algorithm", "") == "sequence" and b.search.metrics.get("algorithm", "") == "sequence", "Both comparisons actually use sequence planning")
	for key in ["completed_depth", "nodes", "cutoff"]:
		_check(a.search.metrics.get(key) == b.search.metrics.get(key), "Fixed-node planner preserves " + key)
	_check(before == _state(normal.engine) and before == _state(fast.engine), "Planner comparison preserves both authoritative engines")
	planner_checked = true


func _benchmark(referee: Referee, seat: int) -> void:
	const ITERATIONS: int = 100
	# Alternate the paths so warming and clock order do not all favor the second path.
	var full_usec: int = 0
	var light_usec: int = 0
	for index in range(ITERATIONS):
		for pass_index in range(2):
			var full: bool = (index + pass_index) % 2 == 0
			var began: int = Time.get_ticks_usec()
			if full:
				referee.prompt_for(seat)
				referee.view_for(seat)
				full_usec += Time.get_ticks_usec() - began
			else:
				referee.prompt_kind_for(seat)
				referee.view_for(seat, false)
				light_usec += Time.get_ticks_usec() - began
	print("Illustrative attack-choice read timing (%d iterations): full prompt+view %.3f ms/read; kind+view without forecasts %.3f ms/read; no speed assertion" % [ITERATIONS, float(full_usec) / ITERATIONS / 1000.0, float(light_usec) / ITERATIONS / 1000.0])
	benchmarked = true


func _state(engine: DuelEngine) -> Dictionary:
	var cards: Dictionary = {}
	for card in engine.all_cards():
		cards[card.uid] = _properties(card)
	return {"state": _properties(engine.state), "cards": cards, "rng": _properties(engine.rng)}


## Card relationships are UID references, avoiding attachment/stack cycles; every card's own
## mutable fields are recorded separately by _state. Definitions are immutable shared inputs.
func _plain(value: Variant) -> Variant:
	if value is CardInstance:
		return value.uid
	if value is CardDef:
		return value.id
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_plain(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = _plain(value[key])
		return result
	if value is Object:
		return _properties(value)
	return value


func _properties(object: Object) -> Dictionary:
	var result: Dictionary = {}
	for property in object.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			result[property["name"]] = _plain(object.get(property["name"]))
	return result


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
