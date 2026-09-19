extends SceneTree
## Bounded latency/depth probe, not a tournament or a playing-strength estimate.

const REPORT: String = "res://docs/ai_budget_probe.json"
var failure: String = ""


func _init() -> void:
	var library: CardLibrary = CardLibrary.new()
	library.load_dir("res://data/cards")
	var table: StrikeTable = StrikeTable.load_from("res://data/strike_table.json")
	var positions: Array[Dictionary] = []
	for deck_id in ["steel_heir", "tide_companions", "pyre_ascent"]:
		positions.append_array(_positions(deck_id, library, table, 2 if deck_id == "pyre_ascent" else 3))
	if not failure.is_empty() or positions.size() != 8:
		_abort(failure if not failure.is_empty() else "Expected eight representative positions")
		return
	var report: Dictionary = {"godot": Engine.get_version_info()["string"], "note": "Eight selected positions from seeded scorer games. Same per-position root, AI seed and profile except Normal time/node caps. Wall-clock timing is illustrative; no win-rate or strength claim.", "old_caps": {"budget_ms": 400, "node_budget": 1500}, "new_caps": {"budget_ms": 1600, "node_budget": 6000}, "positions": []}
	for index in range(positions.size()):
		var position: Dictionary = positions[index]
		var referee: Referee = position["referee"]
		var seat: int = referee.engine.prompt.player
		var before: Variant = _fingerprint(referee.engine)
		var row: Dictionary = position.duplicate()
		row.erase("referee")
		row.erase("deck")
		row["ai_seed"] = 9900 + index
		# Alternate pair order to reduce a systematic first/second-call timing bias.
		for arm in (["old", "new"] if index % 2 == 0 else ["new", "old"]):
			var profile: AiProfile = AiProfile.for_deck(position["deck"], "default")
			profile.merge({"think": {"search": true, "algorithm": "sequence", "budget_ms": 400 if arm == "old" else 1600, "node_budget": 1500 if arm == "old" else 6000}})
			var player: AiPlayer = AiPlayer.new(profile, int(row["ai_seed"]))
			var began: int = Time.get_ticks_usec()
			var command: Dictionary = player.choose(referee, seat)
			var elapsed_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
			if before != _fingerprint(referee.engine):
				_abort("Planner mutated authoritative position: %s" % row["deck_id"])
				return
			if referee.engine.prompt.accept(Command.from_dict(command)) == null:
				_abort("Planner returned an illegal command")
				return
			var metrics: Dictionary = player.search.metrics
			if metrics.get("algorithm", "") != "sequence":
				_abort("Probe did not invoke sequence search")
				return
			row[arm] = {"completed_depth": int(metrics.get("completed_depth", 0)), "nodes": int(metrics.get("nodes", 0)), "fallback": int(metrics.get("completed_depth", 0)) == 0, "elapsed_ms": elapsed_ms, "cutoff": str(metrics.get("cutoff", "")), "choice": command, "think": profile.data["think"].duplicate(true)}
		row["choice_changed"] = row["old"]["choice"] != row["new"]["choice"]
		row["root_unchanged"] = true
		(report["positions"] as Array).append(row)
		if not _save(report):
			return
		print("%s %s turn %d (%d options): depth %d -> %d, nodes %d -> %d, %.1f -> %.1f ms, choice changed %s" % [row["deck_id"], row["kind"], row["turn"], row["options"], row["old"]["completed_depth"], row["new"]["completed_depth"], row["old"]["nodes"], row["new"]["nodes"], row["old"]["elapsed_ms"], row["new"]["elapsed_ms"], row["choice_changed"]])
	# One separate top-difficulty smoke: this changes Hard's profile as well as its caps,
	# so it is deliberately excluded from the paired Normal comparison above.
	var hard_position: Dictionary = positions[0]
	var hard_referee: Referee = hard_position["referee"]
	var hard_before: Variant = _fingerprint(hard_referee.engine)
	var hard_profile: AiProfile = AiProfile.for_deck(hard_position["deck"], "hard")
	var hard_player: AiPlayer = AiPlayer.new(hard_profile, 9900)
	var hard_start: int = Time.get_ticks_usec()
	var hard_command: Dictionary = hard_player.choose(hard_referee, hard_referee.engine.prompt.player)
	var hard_elapsed: float = float(Time.get_ticks_usec() - hard_start) / 1000.0
	if hard_before != _fingerprint(hard_referee.engine) or hard_referee.engine.prompt.accept(Command.from_dict(hard_command)) == null or hard_player.search.metrics.get("algorithm", "") != "sequence":
		_abort("Hard smoke changed root state or returned an invalid command/route")
		return
	report["hard_smoke"] = {"position_index": 0, "ai_seed": 9900, "think": hard_profile.data["think"].duplicate(true), "elapsed_ms": hard_elapsed, "completed_depth": hard_player.search.metrics.get("completed_depth", 0), "nodes": hard_player.search.metrics.get("nodes", 0), "cutoff": hard_player.search.metrics.get("cutoff", ""), "choice": hard_command, "root_unchanged": true, "legal": true}
	if not _save(report):
		return
	print("Separate Hard smoke: %.1f ms, depth %d, %d nodes, legal command and unchanged root" % [hard_elapsed, report["hard_smoke"]["completed_depth"], report["hard_smoke"]["nodes"]])
	print("Budget probe saved %d positions to %s" % [positions.size(), REPORT])
	quit(0)


func _positions(deck_id: String, library: CardLibrary, table: StrikeTable, count: int) -> Array[Dictionary]:
	var target: DeckList = DeckList.load_from("res://data/decks/%s.json" % deck_id)
	var opponent: DeckList = DeckList.load_from("res://data/decks/pyre_beatdown.json")
	var decks: Array[DeckList] = [target, opponent]
	var referee: Referee = Referee.new()
	var names: Array[String] = []
	referee.setup(decks, library, table, 731, names, false)
	referee.start()
	referee.engine.take_events()
	var players: Array[AiPlayer] = []
	for seat in range(2):
		var profile: AiProfile = AiProfile.for_deck(decks[seat], "")
		profile.merge({"think": {"search": false, "noise": 0.0}})
		players.append(AiPlayer.new(profile, 445 + seat))
	var candidates: Dictionary = {}
	var moves: int = 0
	while not referee.is_over() and moves < 600:
		var prompt: Prompt = referee.engine.prompt
		if prompt.player == 0 and prompt.kind != &"reserve" and prompt.options.size() > 1:
			var category: String = _category(prompt)
			if category != "" and not candidates.has(category):
				var snapshot: Referee = Referee.new()
				snapshot.engine = referee.engine.clone()
				candidates[category] = {"referee": snapshot, "deck": target, "deck_id": deck_id, "opponent": "pyre_beatdown", "engine_seed": 731, "scorer_seeds": [445, 446], "move": moves, "turn": referee.engine.state.turn, "kind": str(prompt.kind), "category": category, "options": prompt.options.size()}
		var seat: int = prompt.player
		var problem: String = referee.submit(seat, players[seat].choose(referee, seat))
		if not problem.is_empty():
			failure = "Scorer replay failed: " + problem
			return []
		referee.engine.take_events()
		moves += 1
	var selected: Array[Dictionary] = []
	# Include direct play and strategic setup, preferring a tutor decision over generic defense.
	for category in ["attack", "tutor", "setup", "defense", "control", "declare", "other"]:
		if candidates.has(category) and selected.size() < count:
			selected.append(candidates[category])
	if selected.size() < count:
		failure = "Insufficient multi-option positions for " + deck_id
	return selected


func _category(prompt: Prompt) -> String:
	match prompt.kind:
		&"attack_action": return "attack"
		&"search", &"pick_search": return "tutor"
		&"non_combat", &"start_play": return "setup"
		&"defense", &"respond": return "defense"
		&"control": return "control"
		&"declare": return "declare"
		&"pick_option":
			return "tutor" if prompt.context.has("library") or str(prompt.context.get("op", "")) == "search" else "other"
	return ""


func _fingerprint(engine: DuelEngine) -> Dictionary:
	var cards: Dictionary = {}
	for card in engine.all_cards():
		cards[card.uid] = _properties(card)
	return {"state": _properties(engine.state), "cards": cards, "rng_seed": engine.rng._rng.seed, "rng_state": engine.rng._rng.state, "prompts": _plain(engine.prompts), "queue": _plain(engine._queue), "choice": _plain(engine._choice), "then": _plain(engine._pending_then)}


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


func _save(report: Dictionary) -> bool:
	var output: FileAccess = FileAccess.open(REPORT, FileAccess.WRITE)
	if output == null:
		_abort("Cannot write budget probe JSON")
		return false
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	return true


func _abort(problem: String) -> void:
	push_error(problem)
	quit(1)
