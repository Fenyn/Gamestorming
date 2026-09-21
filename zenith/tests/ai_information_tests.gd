extends SceneTree
## A weighted information-set regression using real legal engine transitions. The probe leaf
## utility deliberately rewards opposite attacks in indistinguishable hidden worlds: a fair
## common choice earns 7.5, while secretly choosing separately would incorrectly earn 10.
## godot --headless --path zenith -s tests/ai_information_tests.gd

class UtilityProbe extends AiSearch:
	var first_uid: int = -1
	var second_uid: int = -1
	var secret_uid: int = -1
	var own_group_sizes: Array[int] = []

	func _scores(worlds: Array[DuelEngine]) -> Array[float]:
		var prompt: Prompt = worlds[0].prompt
		var scores: Array[float] = []
		if prompt.player == _seat:
			own_group_sizes.append(worlds.size())
		for option in prompt.options:
			var score: float = -100.0
			if prompt.player != _seat:
				score = 100.0 if option.type == &"pass" else -100.0
			elif option.type == &"attack":
				score = 0.0
				for world in worlds:
					score += _reward(world, option.card) * _weight(world) / _mass(worlds)
			scores.append(score)
		return scores

	func _reward(world: DuelEngine, source: int) -> float:
		var first_good: bool = world.card(secret_uid).def.id == "ai_strategy_block"
		if source == first_uid:
			return 10.0 if first_good else 0.0
		if source == second_uid:
			return 0.0 if first_good else 10.0
		return -50.0

	func _value(world: DuelEngine) -> float:
		if world.is_over():
			return 40.0 if world.state.winner == _seat else -40.0
		return _reward(world, int(world.state.attack.get("source", world.state.last_attack.get("source", -1))))

class MassProbe extends UtilityProbe:
	func _value(world: DuelEngine) -> float:
		return 10.0 if world.card(secret_uid).def.id == "ai_strategy_block" else 0.0

var checks: int = 0
var failures: int = 0
var library: CardLibrary = CardLibrary.new()
var first_uid: int = -1
var second_uid: int = -1
var secret_uid: int = -1

func _initialize() -> void:
	library.load_dir("res://tests/fixtures/cards")
	library.load_file("res://tests/fixtures/ai_strategy_cards.json")
	var worlds: Array[DuelEngine] = _worlds()
	_check(AiObservation.key(worlds[0], 0) == AiObservation.key(worlds[1], 0), "Root observations must be identical before the opponent's common public pass")
	_check(AiObservation.key(worlds[0], 1) != AiObservation.key(worlds[1], 1), "The opponent must have distinct private hands and legal choices in the two worlds")
	var successors: Array[DuelEngine] = []
	for world in worlds:
		var copy: DuelEngine = world.clone()
		_check(copy.submit(copy.prompt.find(&"pass")), "The same public opponent pass must be a real accepted engine action")
		_check(copy.prompt != null and copy.prompt.player == 0, "Passing must return the actual decision to the root player")
		successors.append(copy)
	_check(AiObservation.key(successors[0], 0) == AiObservation.key(successors[1], 0), "The common public reply must not reveal which opponent private hand was sampled")
	var search: UtilityProbe = _probe(worlds)
	var sequence: Dictionary = search._visit(worlds, 2, 0)
	_check(not search._aborted, "Information-consistency puzzle must complete within its generous node bound")
	_check(is_equal_approx(float(sequence["value"]), 7.5), "Sequence value must use one weighted common follow-up (7.5), not hidden-world optimal choices (10)")
	_check(search.own_group_sizes.has(2), "Own scoring must see the reunited two-world belief after the opponent passes")
	search = _probe(worlds)
	var rollout: Dictionary = search._rollout(worlds, 2)
	_check(is_equal_approx(float(rollout["value"]), 7.5), "Greedy continuation must also reunite the belief and apply its particle weights")
	var mass_probe: UtilityProbe = _probe(worlds, true)
	mass_probe._profile.merge({"think": {"response_width": 3}})
	var branched: Dictionary = mass_probe._visit(worlds, 1, 0)
	_check(is_equal_approx(float(branched["value"]), 7.5), "Unequal numbers of plausible opponent replies must conserve each original world's probability mass")
	search.goal_steps = [{"type": "attack", "card": "ai_strategy_attack", "value": null}]
	var hint: Dictionary = search._goal_hint(successors[0], successors[0].prompt)
	_check(not hint.is_empty() and AiObservation.find_command(successors[0].prompt, hint) != null, "Semantic continuation hints must resolve to a currently offered legal command")
	_check(hint == search._goal_hint(successors[1], successors[1].prompt), "A semantic hint must not depend on the opponent's unobserved hand")
	search.goal_steps = [{"type": "attack", "card": "no_such_fixture_card", "value": null}]
	_check(search._goal_hint(successors[0], successors[0].prompt).is_empty(), "Unavailable remembered cards must not manufacture commands or force stale plans")
	var terminal: DuelEngine = worlds[0].clone()
	terminal.state.winner = 1
	terminal.prompts.clear()
	var mixed: Array[DuelEngine] = [worlds[0], worlds[1], terminal]
	search = _probe(worlds)
	search._weights[worlds[0].get_instance_id()] = 0.375
	search._weights[worlds[1].get_instance_id()] = 0.125
	search._weights[terminal.get_instance_id()] = 0.5
	var mixed_result: Dictionary = search._visit(mixed, 2, 0)
	_check(is_equal_approx(float(mixed_result["value"]), -16.25), "Terminal probability mass must remain in sequence expectation alongside live worlds")
	var mixed_rollout: Dictionary = search._rollout(mixed, 2)
	_check(is_equal_approx(float(mixed_rollout["value"]), -16.25), "Terminal probability mass must remain in rollout expectation alongside live worlds")
	var win: DuelEngine = terminal.clone()
	win.state.winner = 0
	search._weights[win.get_instance_id()] = 0.8
	search._weights[terminal.get_instance_id()] = 0.2
	var leaves: Array[DuelEngine] = [win, terminal]
	_check(is_equal_approx(float(search._evaluate(leaves)["value"]), 24.0), "Leaf evaluation must be probability weighted, not an unweighted particle count")
	print("AI information consistency: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _worlds() -> Array[DuelEngine]:
	var decks: Array[DeckList] = []
	for seat in range(2):
		var deck: DeckList = DeckList.new()
		deck.set_duelist(["ai_strategy_duelist_1", "ai_strategy_duelist_2", "ai_strategy_duelist_3"])
		deck.style = "freestyle"
		deck.alignment = "vigil" if seat == 0 else "pact"
		for i in range(40):
			deck.cards.append("t_strike")
		decks.append(deck)
	var referee: Referee = Referee.new()
	referee.setup(decks, library, StrikeTable.load_from("res://tests/fixtures/strike_table.json"), 17)
	referee.start()
	var base: DuelEngine = referee.sim_for(0, 19)
	for seat in range(2):
		for card in base.player(seat).hand.duplicate():
			base._move_to_discard(card)
	first_uid = _card(base, 0, "ai_strategy_attack")
	second_uid = _card(base, 0, "ai_strategy_lethal")
	secret_uid = _card(base, 1, "ai_strategy_block")
	base.state.step = GameState.Step.COMBAT
	base.state.phase = GameState.Phase.ATTACK
	base.state.active = 1
	base.state.attacker = 1
	base.state.turn = 1
	base.state.consecutive_passes = 0
	base.prompts.clear()
	base._prompt_attack_action(base.player(1))
	var alternative: DuelEngine = base.clone()
	alternative.card(secret_uid).def = library.get_def("t_strike")
	alternative._prompt_attack_action(alternative.player(1))
	return [base, alternative]

func _card(engine: DuelEngine, seat: int, id: String) -> int:
	var card: CardInstance = engine._instance(library.get_def(id), seat, &"hand")
	engine.player(seat).hand.append(card)
	return card.uid

func _probe(worlds: Array[DuelEngine], mass_only: bool = false) -> UtilityProbe:
	var probe: UtilityProbe = MassProbe.new() if mass_only else UtilityProbe.new()
	probe.first_uid = first_uid
	probe.second_uid = second_uid
	probe.secret_uid = secret_uid
	probe._seat = 0
	probe._profile = AiProfile.default_profile()
	probe._profile.merge({"think": {"cache": false, "branch_width": 3, "response_width": 1, "max_steps": 12, "rollout_steps": 0, "settle_steps": 0}})
	probe._policy_base = probe._profile
	probe._foe_base = probe._profile
	probe._node_limit = 1000
	probe._last_turn = 10
	probe._weights[worlds[0].get_instance_id()] = 0.75
	probe._weights[worlds[1].get_instance_id()] = 0.25
	return probe

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
