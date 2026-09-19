extends SceneTree
## Focused evaluator/scorer regressions. Fixture state is arranged on Referee simulations only.

var library: CardLibrary = CardLibrary.new()
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	library.load_dir("res://tests/fixtures/cards")
	for raw in [
		{"id": "feature_cycle_a", "title": "Test Cycle A", "type": "combat", "effects": [{"op": "search", "title_contains": "Test Cycle B"}]},
		{"id": "feature_cycle_b", "title": "Test Cycle B", "type": "combat", "effects": [{"op": "search", "source": "hand", "title_contains": "Test Cycle A"}]},
		{"id": "feature_reward", "title": "Test Feature Reward", "type": "combat", "effects": [{"op": "draw", "amount": 5}]},
		{"id": "feature_aspect_tutor", "title": "Test Aspect Tutor", "type": "personality", "character": "Test Aspect Tutor", "aspects": [
			{"aspect": 1, "might": [0], "power": {"effects": [{"op": "search", "title_contains": "Test Absent Reward"}]}},
			{"aspect": 2, "might": [0], "power": {"effects": [{"op": "search", "title_contains": "Test Feature Reward"}]}}]},
		{"id": "feature_draw_engine", "title": "Test Draw Engine", "type": "drill", "once_per_combat": true,
			"effects": [{"trigger": "use", "op": "draw", "amount": 2, "when": {"hand_min": 1}}]},
		{"id": "feature_empty_engine", "title": "Test Empty Engine", "type": "non_combat",
			"effects": [{"trigger": "use", "op": "search", "title_contains": "Test Absent Reward"}]},
	]:
		var definition: CardDef = CardDef.from_dict(raw)
		library.defs[definition.id] = definition
	for test: Callable in [_explanation, _tutor_cycle_and_context, _current_aspect, _unavailable_power, _missing_combo, _activated_engines]:
		test.call()
	print("AI features: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _engine() -> DuelEngine:
	var decks: Array[DeckList] = []
	for seat in range(2):
		var deck: DeckList = DeckList.new()
		deck.duelist_id = "tf_vigil"
		deck.aspects = 3
		deck.alignment = "vigil"
		for i in range(30):
			deck.cards.append("t_strike")
		decks.append(deck)
	var referee: Referee = Referee.new()
	referee.setup(decks, library, StrikeTable.load_from("res://tests/fixtures/strike_table.json"), 17)
	var engine: DuelEngine = referee.sim_for(0, 17)
	engine.state.step = GameState.Step.COMBAT
	engine.state.phase = GameState.Phase.ATTACK
	engine.state.turn = 1
	engine.state.combat_count = 1
	engine.player(0).duelist.energy = 10
	engine.player(1).duelist.energy = 10
	return engine


func _card(engine: DuelEngine, id: String, zone: StringName) -> CardInstance:
	var card: CardInstance = engine._instance(library.get_def(id), 0, zone)
	var player: PlayerState = engine.player(0)
	match zone:
		&"hand": player.hand.append(card)
		&"life_deck": player.life_deck.append(card)
		&"in_play": player.in_play.append(card)
	return card


func _profile() -> AiProfile:
	var profile: AiProfile = AiProfile.default_profile()
	profile.merge({"play": {"tutor_decay": 0.8, "bond_band": 8.0}})
	return profile


func _explanation() -> void:
	var engine: DuelEngine = _engine()
	var profile: AiProfile = _profile()
	_card(engine, "t_strike", &"hand")
	_card(engine, "feature_draw_engine", &"in_play")
	for seat in range(2):
		var report: Dictionary = AiEvaluator.explain(engine, seat, profile)
		_check(float(report["total"]) == AiEvaluator.evaluate(engine, seat, profile), "Explanation exactly matches evaluation")
		var sum: float = 0.0
		for amount in (report["terms"] as Dictionary).values():
			sum += float(amount)
		_check(is_equal_approx(sum, float(report["total"])), "Signed named terms sum to total")
		_check((report["terms"] as Dictionary).has("own.engine"), "Engine contribution is named")
	engine.state.winner = 0
	for seat in range(2):
		var report: Dictionary = AiEvaluator.explain(engine, seat, profile)
		_check(bool(report["terminal"]) and float(report["total"]) == AiEvaluator.evaluate(engine, seat, profile), "Terminal explanation preserves win/loss value")


func _tutor_cycle_and_context() -> void:
	var engine: DuelEngine = _engine()
	var a: CardInstance = _card(engine, "feature_cycle_a", &"hand")
	_card(engine, "feature_cycle_b", &"life_deck")
	var profile: AiProfile = _profile()
	var short: float = AiScorer.card_value(engine, engine.player(0), a, profile, 2)
	_check(is_equal_approx(short, AiScorer.card_value(engine, engine.player(0), a, profile, 7)), "Tutor cycle cannot grow valuation with depth")
	var flat: AiProfile = AiProfile.default_profile()
	_check(AiScorer.card_value(engine, engine.player(0), a, flat, 3) < short, "Different profile does not reuse stale tutor cache")
	_check(is_equal_approx(short, AiScorer.card_value(engine, engine.player(0), a, profile, 2)), "Previous profile remains repeatable without cache clearing")


func _current_aspect() -> void:
	var engine: DuelEngine = _engine()
	var source: CardInstance = _card(engine, "feature_aspect_tutor", &"in_play")
	_card(engine, "feature_reward", &"life_deck")
	engine.player(0).controlling = source
	var profile: AiProfile = _profile()
	var first: float = AiScorer.card_value(engine, engine.player(0), source, profile, 3)
	source.aspect = 2
	_check(AiScorer.card_value(engine, engine.player(0), source, profile, 3) > first, "Tutor follows current Aspect power")


func _unavailable_power() -> void:
	var engine: DuelEngine = _engine()
	var player: PlayerState = engine.player(0)
	var profile: AiProfile = _profile()
	_check(AiScorer.usable_power_value(engine, player, player.duelist, profile) > 0, "Ready affordable power has utility")
	player.duelist.power_used_turn = engine.state.turn
	player.duelist.power_used_combat = engine.state.combat_count
	player.duelist.power_uses_combat = 1
	_check(AiScorer.usable_power_value(engine, player, player.duelist, profile) == 0, "Spent power has no current utility")
	player.duelist.power_used_turn = -1
	player.duelist.energy = 0
	_check(AiScorer.usable_power_value(engine, player, player.duelist, profile) == 0, "Unaffordable power has no current utility")
	player.duelist.energy = 10
	engine.state.floating.append({"owner": 0, "op": "forbid", "what": "powers"})
	_check(AiScorer.usable_power_value(engine, player, player.duelist, profile) == 0, "Prohibited power has no current utility")


func _missing_combo() -> void:
	var engine: DuelEngine = _engine()
	_card(engine, "t_ally_twin_a", &"in_play")
	var partner: CardInstance = _card(engine, "t_ally_twin_b", &"in_play")
	var rite: CardInstance = _card(engine, "t_bonding_rite", &"hand")
	var profile: AiProfile = _profile()
	var ready: float = AiScorer.card_value(engine, engine.player(0), rite, profile, 3)
	engine.player(0).in_play.erase(partner)
	partner.zone = &"removed"
	engine.player(0).removed.append(partner)
	_check(AiScorer.card_value(engine, engine.player(0), rite, profile, 3) < ready, "Missing prerequisite removes speculative combo premium")
	var other: CardInstance = _card(engine, "t_ally_twin_a", &"hand")
	_check(AiScorer._combo_value(engine, engine.player(0), other, profile) == 0, "Duplicate existing partner adds no assembly progress")


func _activated_engines() -> void:
	var engine: DuelEngine = _engine()
	var player: PlayerState = engine.player(0)
	var profile: AiProfile = _profile()
	var source: CardInstance = _card(engine, "feature_draw_engine", &"in_play")
	_card(engine, "t_strike", &"hand")
	_check(AiEvaluator.usable_engine_value(engine, player, profile) > 0, "Usable draw Drill contributes beyond material count")
	source.power_used_combat = engine.state.combat_count
	_check(AiEvaluator.usable_engine_value(engine, player, profile) == 0, "Spent once-per-Combat engine contributes no activation value")
	source.power_used_combat = -1
	engine.state.floating.append({"owner": 0, "op": "forbid", "what": "drills"})
	_check(AiEvaluator.usable_engine_value(engine, player, profile) == 0, "Forbidden engine contributes no activation value")
	engine.state.floating.clear()
	player.hand.clear()
	_check(AiEvaluator.usable_engine_value(engine, player, profile) == 0, "False activation condition contributes no value")
	_card(engine, "feature_empty_engine", &"in_play")
	_check(AiEvaluator.usable_engine_value(engine, player, profile) == 0, "Tutor engine without any matching target adds no activation value")
	var public_before: float = AiEvaluator.usable_engine_value(engine, player, profile, true)
	var reward: CardDef = CardDef.from_dict({"id": "feature_later_reward", "title": "Test Absent Reward", "type": "combat", "effects": [{"op": "draw"}]})
	library.defs[reward.id] = reward
	_card(engine, reward.id, &"life_deck")
	_check(AiEvaluator.usable_engine_value(engine, player, profile) > 0, "Known matching target enables own tutor engine")
	_check(AiEvaluator.usable_engine_value(engine, player, profile, true) == public_before, "Opponent public engine value does not inspect hidden target identities")
