extends SceneTree
## Behavioral search puzzles. Every played action is accepted by the real Referee;
## fixture setup alone may arrange engine state. AI simulations still cross sim_for.
## godot --headless --path zenith -s tests/ai_strategy_tests.gd

class CountingReferee extends Referee:
	var simulation_calls: int = 0
	func sim_for(seat: int, sample_seed: int) -> DuelEngine:
		simulation_calls += 1
		return super.sim_for(seat, sample_seed)

var library: CardLibrary = CardLibrary.new()
var checks: int = 0
var failures: int = 0
var current: String = ""


func _initialize() -> void:
	library.load_dir("res://tests/fixtures/cards")
	library.load_file("res://tests/fixtures/ai_strategy_cards.json")
	var tests: Array[Callable] = [_lookahead_beats_greedy, _chain_execution, _keep_only_combo_piece, _useful_controller,
		_disruption_replanning, _urgent_survival, _simulated_pivot, _fair_repeatable_bounded, _transposition_keys, _second_pending_keep]
	for test in tests:
		current = test.get_method()
		var selected: bool = true
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--case="):
				selected = current == argument.get_slice("=", 1)
		if not selected:
			continue
		print("RUN %s" % current)
		var before: int = failures
		test.call()
		print("%s %s" % ["ok" if failures == before else "FAIL", current])
	print("AI strategy: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("%s: %s" % [current, message])


func _profile(depth: int = 6, budget: int = 1500) -> AiProfile:
	var profile: AiProfile = AiProfile.default_profile()
	profile.merge({"play": {"tutor_decay": 0.8, "bond_band": 8.0},
		"own": {"combo_progress": 8.0, "hand_quality": 0.25, "power": 1.0},
		"think": {"search": true, "samples": 1, "top_k": 3, "budget_ms": 60000, "noise": 0.0,
			"sequence_depth": depth, "branch_width": 3, "response_width": 2,
			"node_budget": budget, "settle_steps": 8, "turns": 1, "max_steps": 50}})
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--nodes="):
			profile.merge({"think": {"node_budget": int(argument.get_slice("=", 1))}})
		elif argument.begins_with("--budget-ms="):
			profile.merge({"think": {"budget_ms": int(argument.get_slice("=", 1))}})
		elif argument.begins_with("--samples="):
			profile.merge({"think": {"samples": int(argument.get_slice("=", 1))}})
	return profile


func _referee() -> CountingReferee:
	var pair: Array[DeckList] = []
	for seat in range(2):
		var deck: DeckList = DeckList.new()
		deck.set_duelist(["ai_strategy_duelist_1", "ai_strategy_duelist_2", "ai_strategy_duelist_3"])
		deck.alignment = "vigil" if seat == 0 else "pact"
		for i in range(40):
			deck.cards.append("t_strike")
		pair.append(deck)
	var referee: CountingReferee = CountingReferee.new()
	referee.setup(pair, library, StrikeTable.load_from("res://tests/fixtures/strike_table.json"), 11)
	referee.engine.set_first_player(0)   # these fixtures script seat 0 as the active player
	referee.engine.shuffle_decks = false
	referee.start()
	if referee.engine.prompt.kind == &"non_combat":
		_submit_type(referee, &"done")
	_submit_type(referee, &"declare")
	for seat in range(2):
		for card in referee.engine.player(seat).hand.duplicate():
			referee.engine._move_to_discard(card)
	referee.engine._prompt_attack_action(referee.engine.player(0))
	return referee


func _card(referee: Referee, seat: int, id: String, zone: StringName = &"hand") -> CardInstance:
	var card: CardInstance = referee.engine._instance(library.get_def(id), seat, zone)
	var player: PlayerState = referee.engine.player(seat)
	match zone:
		&"hand": player.hand.append(card)
		&"life_deck": player.life_deck.append(card)
		&"in_play": player.in_play.append(card)
		&"reserve": player.reserve.append(card)
	return card


func _bond_parts(referee: Referee) -> void:
	_card(referee, 0, "t_ally_twin_a", &"in_play").energy = 3
	_card(referee, 0, "t_ally_twin_b", &"in_play").energy = 3
	_card(referee, 0, "t_bonded_twins", &"reserve")


func _life(referee: Referee, seat: int, count: int) -> void:
	var player: PlayerState = referee.engine.player(seat)
	while player.life_deck.size() > count:
		referee.engine._move_to_discard(player.life_deck.back())


func _submit_type(referee: Referee, type: StringName, uid: int = -1) -> void:
	var command: Command = referee.engine.prompt.find(type, uid)
	_check(command != null, "Required fixture option %s must exist" % type)
	if command != null:
		_check(referee.submit(command.player, command.to_dict()) == "", "Fixture choice must be accepted")


func _play(referee: Referee, ai: AiPlayer, seat: int) -> Dictionary:
	var command: Dictionary = ai.choose(referee, seat)
	if OS.get_cmdline_user_args().has("--trace"):
		print("%s chose %s metrics=%s report=%s" % [current, command, ai.search.metrics, ai.search.last_report])
	_check(not command.is_empty(), "AI must answer its real prompt")
	if not command.is_empty():
		_check(referee.submit(seat, command) == "", "AI answer must be an offered legal choice")
	return command


func _quiet(referee: Referee) -> void:
	var prompt: Prompt = referee.engine.prompt
	for type in [&"pass", &"no_defense", &"decline", &"no_endure", &"no_critical", &"done", &"skip", &"discard_all", &"no_recover"]:
		var command: Command = prompt.find(type)
		if command != null:
			_check(referee.submit(prompt.player, command.to_dict()) == "", "Opponent response remains a real legal choice")
			return
	_check(referee.submit(prompt.player, prompt.options[0].to_dict()) == "", "Forced opponent response must resolve")


func _chain_execution() -> void:
	var referee: CountingReferee = _referee()
	_bond_parts(referee)
	_card(referee, 0, "t_tutor_rite", &"life_deck")
	_card(referee, 0, "t_bonding_rite", &"life_deck")
	var opener: CardInstance = _card(referee, 0, "t_tutor_tutor")
	referee.engine.player(0).duelist.energy = 3
	for i in range(5):
		_card(referee, 0, "ai_strategy_distraction")
	referee.engine._prompt_attack_action(referee.engine.player(0))
	var ai: AiPlayer = AiPlayer.new(_profile(8, 1500), 19)
	var first: Dictionary = _play(referee, ai, 0)
	_check(int(first.get("card", -1)) == opener.uid and str(first.get("type", "")) == "use", "Tutor chain must begin despite several competing immediate attacks")
	if int(first.get("card", -1)) != opener.uid:
		return
	var bonded: bool = false
	var visited: Dictionary = {}
	for step in range(26):
		for ally in referee.engine.player(0).allies():
			bonded = bonded or ally.cards_under.size() == 2
		if bonded or referee.is_over():
			break
		var prompt: Prompt = referee.engine.prompt
		visited[prompt.kind] = true
		if prompt.player == 0:
			_play(referee, ai, 0)
		else:
			_quiet(referee)
	_check(bonded, "AI must actually fetch, play and execute the two-link Bond chain")
	_check(visited.has(&"search_pick") or visited.has(&"pick_option"), "Chain execution must pass through engine-controlled search choices")


func _lookahead_beats_greedy() -> void:
	var referee: CountingReferee = _referee()
	referee.engine.player(0).duelist.energy = 0
	_life(referee, 1, 8)
	var battery: CardInstance = _card(referee, 0, "ai_strategy_battery")
	var other_battery: CardInstance = _card(referee, 0, "ai_strategy_battery_two")
	var closer: CardInstance = _card(referee, 0, "ai_strategy_closer")
	_card(referee, 0, "ai_strategy_costly_finish")
	referee.engine._prompt_attack_action(referee.engine.player(0))
	var profile: AiProfile = _profile(5, 1500)
	var greedy_world: DuelEngine = referee.sim_for(0, 39)
	var greedy: Command = AiScorer.pick(greedy_world, profile)
	_check(greedy.card == closer.uid, "Puzzle must demonstrate that immediate scoring prefers the nonwinning Combat-ending attack")
	greedy_world.submit(greedy)
	_check(not greedy_world.is_over() and greedy_world.state.step != GameState.Step.COMBAT, "Greedy action must actually close Combat without winning")
	var greedy_followup: DuelEngine = referee.sim_for(0, 39)
	greedy_followup.submit(greedy_followup.prompt.find(&"use", other_battery.uid))
	if greedy_followup.prompt.player == 1:
		greedy_followup.submit(greedy_followup.prompt.find(&"pass"))
	_check(AiScorer.pick(greedy_followup, profile).card == closer.uid, "Even after one setup, a single greedy continuation must miss the second setup and lethal")
	var ai: AiPlayer = AiPlayer.new(profile, 39)
	var first: Dictionary = _play(referee, ai, 0)
	_check(int(first.get("card", -1)) in [battery.uid, other_battery.uid], "Lookahead must choose a lower-scored resource setup instead")
	_check(int(ai.search.metrics.get("completed_depth", 0)) > 1, "Winning line must come from branching beyond the first decision")
	for step in range(8):
		if referee.is_over():
			break
		if referee.engine.prompt.player == 0:
			_play(referee, ai, 0)
		else:
			_quiet(referee)
	_check(referee.is_over() and referee.engine.state.winner == 0, "Search must execute setup then its newly affordable lethal payoff")


func _second_pending_keep() -> void:
	var referee: CountingReferee = _referee()
	for seat in range(2):
		_card(referee, seat, "ai_strategy_attack")
		_card(referee, seat, "ai_strategy_block")
	referee.engine.prompts.clear()
	referee.engine.state.step = GameState.Step.DISCARD
	referee.engine.state.discard_index = 0
	referee.engine._advance_discard()
	_check(referee.engine.prompts.size() == 2 and referee.engine.prompt.player == 0, "Both keep choices must be pending with seat zero first")
	var profile: AiProfile = _profile(2, 500)
	profile.merge({"think": {"budget_ms": 0, "rollout_steps": 0, "settle_steps": 0}})
	var ai: AiPlayer = AiPlayer.new(profile, 28)
	var command: Dictionary = ai.choose(referee, 1)
	_check(int(ai.search.metrics.get("completed_depth", 0)) > 0, "Second pending seat must receive real lookahead instead of an inconsistent-options fallback")
	_check(str(ai.search.metrics.get("cutoff", "")) != "inconsistent_options", "Simulated choices resolve through their own seat's prompt")
	_check(int(command.get("player", -1)) == 1 and referee.submit(1, command) == "", "The second seat can submit its legal keep before the first seat")
	_check(referee.engine.prompt_of(0) != null, "The other player's independent keep decision remains pending")


func _keep_only_combo_piece() -> void:
	var referee: CountingReferee = _referee()
	_bond_parts(referee)
	var rite: CardInstance = _card(referee, 0, "t_bonding_rite")
	_card(referee, 0, "ai_strategy_attack")
	referee.engine.prompts.clear()
	referee.engine.state.step = GameState.Step.DISCARD
	referee.engine.state.discard_index = 0
	referee.engine._advance_discard()
	var ai: AiPlayer = AiPlayer.new(_profile(), 20)
	var command: Dictionary = _play(referee, ai, 0)
	_check(str(command.get("type", "")) == "keep" and int(command.get("card", -1)) == rite.uid, "Discard must preserve the only missing combo piece over a replaceable attack")
	_check(referee.engine.player(0).hand.has(rite), "The preserved piece must remain in the actual hand after discard")


func _useful_controller() -> void:
	var referee: CountingReferee = _referee()
	var caster: CardInstance = _card(referee, 0, "ai_strategy_caster", &"in_play")
	caster.energy = 5
	referee.engine.player(0).duelist.energy = 1
	_life(referee, 1, 6)
	referee.engine._prompt_attacker_control(referee.engine.player(0))
	var ai: AiPlayer = AiPlayer.new(_profile(), 21)
	_check(caster.might() < referee.engine.player(0).duelist.might(), "Controller puzzle must genuinely prefer a lower-Might body")
	var command: Dictionary = _play(referee, ai, 0)
	_check(int(command.get("card", -1)) == caster.uid, "Control must select the ally with the useful lethal power")
	var carried: bool = false
	for step in range(8):
		if referee.is_over():
			break
		if referee.engine.prompt.player == 0:
			_play(referee, ai, 0)
			carried = carried or str(ai.search.metrics.get("intent_status", "")) in ["matched", "retained"]
		else:
			_quiet(referee)
	_check(referee.is_over() and referee.engine.state.winner == 0, "Selected controller must execute its lethal power, not just score well")
	_check(carried, "Predictable next decision must reuse the validated intent as an ordering hint")


func _disruption_replanning() -> void:
	var referee: CountingReferee = _referee()
	referee.engine.player(0).duelist.energy = 0
	_life(referee, 1, 8)
	var battery: CardInstance = _card(referee, 0, "ai_strategy_battery")
	var second_battery: CardInstance = _card(referee, 0, "ai_strategy_battery_two")
	_card(referee, 0, "ai_strategy_closer")
	_card(referee, 0, "ai_strategy_costly_finish")
	referee.engine._prompt_attack_action(referee.engine.player(0))
	var ai: AiPlayer = AiPlayer.new(_profile(), 22)
	var planned: Dictionary = _play(referee, ai, 0)
	_check(int(planned.get("card", -1)) in [battery.uid, second_battery.uid], "Fixture must execute a real setup before disruption")
	if referee.engine.prompt.player == 1:
		_quiet(referee)
	var remaining: CardInstance = battery if int(planned.get("card", -1)) == second_battery.uid else second_battery
	referee.engine._move_to_discard(remaining)
	var finisher: CardInstance = _card(referee, 0, "ai_strategy_lethal")
	_life(referee, 1, 6)
	referee.engine._prompt_attack_action(referee.engine.player(0))
	var revised: Dictionary = _play(referee, ai, 0)
	_check(str(ai.search.metrics.get("intent_status", "")) == "invalidated", "Public disruption must invalidate the previously planned continuation")
	_check(int(revised.get("card", -1)) == finisher.uid, "Disrupted resource sequence must be abandoned for the new winning action")
	_check(referee.is_over() and referee.engine.state.winner == 0, "Replanned action must really win after disruption")


func _urgent_survival() -> void:
	var referee: CountingReferee = _referee()
	var ward: CardInstance = _card(referee, 0, "ai_strategy_block")
	_card(referee, 0, "t_tutor_tutor")
	var threat: CardInstance = _card(referee, 1, "ai_strategy_lethal")
	_life(referee, 0, 6)
	referee.engine.state.attacker = 1
	referee.engine._prompt_attack_action(referee.engine.player(1))
	_submit_type(referee, &"attack", threat.uid)
	var ai: AiPlayer = AiPlayer.new(_profile(), 23)
	var command: Dictionary = _play(referee, ai, 0)
	_check(str(command.get("type", "")) == "defend" and int(command.get("card", -1)) == ward.uid, "Immediate survival must override preserving cards for a long-term plan")
	_check(not referee.is_over() and referee.engine.player(0).life_deck.size() == 6, "Chosen defense must actually prevent the fatal wounds")


func _simulated_pivot() -> void:
	var referee: CountingReferee = _referee()
	var charge: CardInstance = _card(referee, 0, "ai_strategy_charge")
	_card(referee, 0, "ai_strategy_attack")
	referee.engine._prompt_attack_action(referee.engine.player(0))
	var profile: AiProfile = _profile(5, 6000)
	# The pivot speaks to both halves: `play` is what the scorer weighs, `foe.life` what the search's
	# leaf weighs. A play weight alone also raises what holding the attack is worth, so it says
	# nothing about when to swing.
	profile.merge({"when": {"fervor_min:1": {"play": {"damage_life": 8.0, "attack_cost": 0.0}, "foe": {"life": 3.0}}}})
	var ai: AiPlayer = AiPlayer.new(profile, 24)
	ai.choose(referee, 0)
	_check(int(ai.search.metrics.get("state_pivots", 0)) > 0, "Search must resolve state-dependent profiles inside hypothetical continuations")
	# Execute the same enabling change through a real offered option and verify replanning.
	_submit_type(referee, &"use", charge.uid)
	if referee.engine.prompt.player == 1:
		_quiet(referee)
	var command: Dictionary = _play(referee, ai, 0)
	_check(str(command.get("type", "")) == "attack", "The activated offensive pivot must execute an available attack")


func _fair_repeatable_bounded() -> void:
	var first: CountingReferee = _referee()
	var second: CountingReferee = _referee()
	for referee in [first, second]:
		_card(referee, 0, "ai_strategy_attack")
		_card(referee, 0, "ai_strategy_lethal")
		referee.engine._prompt_attack_action(referee.engine.player(0))
	# Same public state, different secret enemy composition. The AI must not learn it
	# merely because a local referee happens to own both clients' cards.
	for card in second.engine.player(1).life_deck:
		card.def = library.get_def("ai_strategy_lethal")
	_check(first.view_for(0).to_dict() == second.view_for(0).to_dict(), "Fairness fixtures must be indistinguishable to the acting seat")
	var sample_a: DuelEngine = first.sim_for(0, 99)
	var sample_b: DuelEngine = second.sim_for(0, 99)
	var same_belief: bool = true
	for i in range(sample_a.player(1).life_deck.size()):
		same_belief = same_belief and sample_a.player(1).life_deck[i].def.id == sample_b.player(1).life_deck[i].def.id
	_check(same_belief, "Equal observations and sample seeds must produce identical beliefs about hidden enemy composition")
	for card in first.engine.player(0).hand:
		_check(sample_a.card(card.uid).def.id == card.def.id, "Belief sampling must preserve every known own-hand identity")
	_check(PromptView.of(sample_a.prompt_of(0), sample_a).to_dict() == first.prompt_for(0).to_dict(), "Belief sampling must preserve the acting player's legal prompt")
	var before: Dictionary = first.view_for(0).to_dict()
	var profile: AiProfile = _profile(4, 1200)
	var a: AiPlayer = AiPlayer.new(profile, 25)
	var b: AiPlayer = AiPlayer.new(profile, 25)
	var c: AiPlayer = AiPlayer.new(profile, 25)
	var action_a: Dictionary = a.choose(first, 0)
	var action_b: Dictionary = b.choose(first, 0)
	var action_c: Dictionary = c.choose(second, 0)
	_check(action_a == action_b, "Identical seed and public state must produce an identical bounded-search decision")
	_check(action_a == action_c and a.search.last_report == c.search.last_report, "Secret enemy composition must not change the sampled decision or candidate values")
	_check(first.view_for(0).to_dict() == before, "Thinking must never advance the authoritative game")
	_check(first.simulation_calls > 0, "Search must obtain its worlds through Referee.sim_for")
	_check(int(a.search.metrics.get("nodes", 0)) <= profile.think_int("node_budget"), "Search must respect its deterministic node budget")
	_check(not a.search.last_report.is_empty(), "Bounded search must report evaluated candidates")
	if not a.search.last_report.is_empty():
		var depth: int = int(a.search.last_report[0].get("depth", -1))
		for row in a.search.last_report:
			_check(int(row.get("depth", -1)) == depth and int(row.get("samples", -1)) == profile.think_int("samples"), "Reported alternatives must have equal completed depth and shared-world sample counts")
	_check(first.submit(0, action_a) == "", "Final bounded-search choice must execute legally")


func _transposition_keys() -> void:
	var referee: CountingReferee = _referee()
	var original: DuelEngine = referee.sim_for(0, 101)
	var key: String = AiObservation.state_key(original)
	_check(key != "", "Ordinary simulation states must support a conservative transposition key")
	var copied: DuelEngine = original.clone()
	_check(AiObservation.state_key(copied) == key, "Equivalent clones must share a transposition key")
	copied.player(0).duelist.power_used_turn = copied.state.turn
	_check(AiObservation.state_key(copied) != key, "Once-per-turn power use must distinguish otherwise equal states")
	copied = original.clone()
	copied.rng.randi_range(0, 100)
	_check(AiObservation.state_key(copied) != key, "Future random-state changes must prevent unsafe transposition reuse")
	copied = original.clone()
	copied._queue.append({"effects": [{"op": "energy", "amount": 1}], "index": 0, "owner": 0})
	_check(AiObservation.state_key(copied) != key, "Pending unresolved effects must distinguish transposition keys")
