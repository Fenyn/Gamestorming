extends SceneTree
## Regression tests for public replay snapshots and defense previews; no client-side rules.

var checks: int = 0
var failures: int = 0
var library: CardLibrary = CardLibrary.new()


func _initialize() -> void:
	library.load_dir("res://tests/fixtures/cards")
	_test_snapshots()
	_test_defense()
	print("Presentation data: %d checks, %d failures" % [checks, failures])
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
		deck.alignment = "vigil" if seat == 0 else "pact"
		for i in range(25):
			deck.cards.append("t_parry" if seat == 1 and i < 3 else "t_strike")
		decks.append(deck)
	var engine: DuelEngine = DuelEngine.new()
	engine.shuffle_decks = false
	engine.record_display_state = true
	engine.setup(decks, library, StrikeTable.load_from("res://tests/fixtures/strike_table.json"), 5)
	engine.start()
	return engine


func _test_snapshots() -> void:
	var engine: DuelEngine = _engine()
	var actor: CardInstance = engine.player(0).duelist
	var before: Dictionary = engine._display_state()
	_check(before["might"][actor.uid] == actor.might() and before["aspect"][actor.uid] == actor.aspect, "Replay includes exact current Might and Aspect")
	_check(before["controlling"][0] == actor.uid, "Replay identifies each player's controlling personality")
	for key in ["might", "aspect", "energy"]:
		for uid in before[key]:
			var card: CardInstance = engine.card(int(uid))
			_check(card != null and card.zone in [&"duelist", &"in_play"], "Replay personality maps must never reveal private cards")
	var old_aspect: int = actor.aspect
	engine.dev_effect(0, {"op": "advance_aspect"})
	_check(actor.aspect > old_aspect and before["aspect"][actor.uid] == old_aspect, "Later ascension must not mutate an earlier replay snapshot")
	var found: bool = false
	for event in engine.events:
		if event.type == &"aspect_up":
			found = true
			_check(event.state["aspect"][actor.uid] == actor.aspect and event.state["might"][actor.uid] == actor.might(), "Ascension event carries matching Aspect and Might")
	_check(found, "Fixture must produce an actual ascension event")
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(before))
	_check(decoded["might"].has(str(actor.uid)) and int(decoded["controlling"][0]) == actor.uid, "Replay fields survive online JSON transport")


func _test_defense() -> void:
	var engine: DuelEngine = _engine()
	if engine.prompt.kind == &"non_combat":
		engine.submit(engine.prompt.find(&"done"))
	engine.submit(engine.prompt.find(&"declare"))
	var attack: Command = engine.prompt.find(&"attack", engine.player(0).hand[0].uid)
	engine.submit(attack)
	_check(engine.prompt.kind == &"defense", "Fixture must reach a real defense decision")
	if engine.prompt.kind != &"defense":
		return
	var options: PromptView = PromptView.of(engine.prompt, engine)
	var take: OptionView = options.find(&"no_defense")
	var block: OptionView = options.find(&"defend", engine.player(1).hand[0].uid)
	_check(take != null and block != null, "Both taking and blocking must be offered")
	if take == null or block == null:
		return
	_check(int(take.outcome["stages"]) > 0 and int(take.outcome["life"]) == 0 and not take.outcome["stopped"], "Energy-only hits must have a meaningful nonzero preview")
	_check(block.outcome["stages"] == 0 and block.outcome["life"] == 0 and block.outcome["stopped"], "Complete stop removes both damage components")
	_check(OptionView.from_dict(block.to_dict()).outcome == block.outcome, "New defense fields survive option transport")
	# A first stop against a two-stop attack must not promise a full block.
	engine.state.attack["stops_needed"] = 2
	var partial: Dictionary = engine.option_outcome(engine.prompt, block.to_command(1))
	_check(not partial["stopped"] and partial["stages"] == take.outcome["stages"], "Partial stop preserves Energy damage until the required stop count")
	engine.state.attack["stops_needed"] = 1
	engine.submit(block.to_command(1))
	var stopped: bool = false
	for event in engine.events:
		if event.type == &"attack_stopped":
			stopped = true
	_check(stopped, "The full-stop preview must agree with actual defense resolution")
