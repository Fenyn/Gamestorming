extends SceneTree
## Shared simulation policy construction and legacy runner refusal regressions.

var checks: int = 0
var failures: int = 0


func _init() -> void:
	var deck: DeckList = DeckList.load_from("res://data/decks/tide_companions.json")
	for policy in ["search", "scorer", "rollout", "easy", "default", "hard"]:
		var configured: SimSeat = SimSeat.from_legacy(policy, {"budget": "7", "samples": "1", "rollout-steps": "3"})
		var profile: AiProfile = configured.make_profile(deck)
		var player: AiPlayer = configured.make_player(deck, 889)
		_check(configured.error.is_empty() and player.profile.data == profile.data, policy + ": diagnostics and drivers share profile construction")
		_check(profile.think_int("budget_ms") == 7 and profile.think_int("samples") == 1 and profile.think_int("rollout_steps") == 3, policy + ": legacy knob overrides survive")
		_check(player.rng.seed == 889, policy + ": player seed survives")
		if policy == "scorer":
			_check(not profile.searches(), "Scorer stays explicitly disabled")
		elif policy == "rollout":
			_check(profile.searches() and profile.data["think"]["algorithm"] == "rollout", "Rollout does not silently become sequence")
		else:
			_check(profile.searches() and profile.data["think"]["algorithm"] == "sequence", policy + ": planner route preserved")
	_check(SimSeat.from_legacy("random", {}).make_player(deck, 1) == null, "Random remains the null-driver policy")
	var defaults: AiProfile = SimSeat.from_legacy("search", {"budget": "", "samples": ""}, false).make_profile(deck)
	_check(defaults.data == AiProfile.default_profile().data, "Empty optional knobs and disabled deck styles preserve defaults")
	_check(not SimSeat.from_legacy("rollotu", {}).error.is_empty(), "Misspelled policy rejected by shared adapter")
	_check(not SimSeat.policy_error("../profiles/hard").is_empty(), "Policy names cannot escape profile directory")
	var override: SimSeat = SimSeat.from_legacy("hard", {})
	override.think.merge({"search": true, "algorithm": "sequence"})
	_check(override.make_profile(deck).think_int("budget_ms") == AiProfile.for_deck(deck, "hard").think_int("budget_ms"), "Search-deck override keeps named difficulty knobs")
	_test_rollout(deck)
	for runner in ["deck_report", "deck_outcomes", "ai_arena", "ally_probe", "ai_trace"]:
		var output: Array = []
		var argument: String = "--a=rollotu" if runner == "ai_arena" else "--policy=rollotu"
		var log_path: String = OS.get_environment("TEMP").path_join("zenith-policy-%s.log" % runner)
		var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--log-file", log_path, "-s", "tests/%s.gd" % runner, "--", argument]
		var code: int = OS.execute(OS.get_executable_path(), args, output, true)
		_check(code == 1 and FileAccess.get_file_as_string(log_path).contains("Unknown policy 'rollotu'"), runner + ": unknown policy fails before a game starts")
	print("Simulation policies: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_rollout(deck: DeckList) -> void:
	var library: CardLibrary = CardLibrary.new()
	library.load_dir("res://data/cards")
	var referee: Referee = Referee.new()
	var decks: Array[DeckList] = [deck, DeckList.load_from("res://data/decks/pyre_beatdown.json")]
	referee.setup(decks, library, StrikeTable.load_from("res://data/strike_table.json"), 77, [], false)
	referee.start()
	for attempt in range(4):
		if referee.engine.prompt.kind != &"reserve":
			break
		for option in referee.engine.prompt.options:
			if option.type == &"reserve_done":
				_check(referee.submit(option.player, option.to_dict()).is_empty(), "Reserve exits legally")
				break
		referee.engine.take_events()
	var player: AiPlayer = SimSeat.from_legacy("rollout", {"budget": "1", "samples": "1", "steps": "2", "top-k": "2"}).make_player(deck, 181)
	var seat: int = referee.engine.prompt.player
	var command: Dictionary = player.choose(referee, seat)
	_check(player.search.metrics.get("algorithm", "") == "rollout", "Legacy rollout reaches actual historical search implementation")
	_check(referee.submit(seat, command).is_empty(), "Historical rollout returns a legal command")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
