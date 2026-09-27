extends SceneTree
## Public combat presentation contracts; synthetic landed states use public wire fields only.

var checks: int = 0
var failures: int = 0
var library: CardLibrary = CardLibrary.new()
var emitted: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	library.load_dir("res://tests/fixtures/cards")
	var engine: DuelEngine = _defense_position()
	_check(engine.prompt.kind == &"defense", "Fixture reaches a real defense decision")
	if engine.prompt.kind != &"defense":
		quit(1)
		return
	var hud: Node = load("res://scenes/duel/hud.tscn").instantiate()
	root.add_child(hud)
	var defender: SeatView = SeatView.of(engine, 1)
	var attacker: SeatView = SeatView.of(engine, 0)
	var prompt: PromptView = PromptView.of(engine.prompt, engine)
	_test_rail(hud, defender, attacker, prompt, engine)
	_test_response(hud)
	_test_links(defender)
	_test_labels(hud, defender)
	_test_seat_names()
	await _test_legal_actions(hud)
	await _test_strip_and_queue(hud, defender)
	await _test_read_holds(hud, defender)
	await _test_beat_banner(hud)
	_test_hit_tiers()
	await _test_card_motion()
	hud.free()
	await process_frame
	print("Combat presentation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _defense_position(pending: bool = false) -> DuelEngine:
	var decks: Array[DeckList] = []
	for seat in range(2):
		var deck: DeckList = DeckList.new()
		deck.set_duelist(["tf_vigil_1", "tf_vigil_2", "tf_vigil_3"])
		deck.alignment = "vigil" if seat == 0 else "pact"
		for index in range(25):
			if pending and index < 3:
				deck.cards.append("t_taunt" if seat == 0 else "t_counter")
			else:
				deck.cards.append("t_parry" if seat == 1 and index < 3 else "t_strike")
		decks.append(deck)
	var engine: DuelEngine = DuelEngine.new()
	engine.shuffle_decks = false
	engine.setup(decks, library, StrikeTable.load_from("res://tests/fixtures/strike_table.json"), 5)
	engine.set_first_player(0)   # the scripted sequence below is seat 0's opening turn
	engine.start()
	if engine.prompt.kind == &"non_combat":
		engine.submit(engine.prompt.find(&"done"))
	engine.submit(engine.prompt.find(&"declare"))
	engine.submit(engine.prompt.find(&"use" if pending else &"attack", engine.player(0).hand[0].uid))
	return engine


func _test_rail(hud: Node, defender: SeatView, attacker: SeatView, prompt: PromptView, engine: DuelEngine) -> void:
	hud._view = defender
	hud._current_prompt = prompt
	hud._show_attack(defender, prompt)
	_check(hud.exchange_rail.visible, "Attack renders the shared combat rail")
	var own_response: String = hud.exchange_response.text
	var baseline: String = hud.exchange_damage.text
	_check(not baseline.is_empty(), "Energy-only attack has a meaningful damage baseline")
	var public_before: Dictionary = defender.to_dict().duplicate(true)
	var prompt_before: Dictionary = prompt.to_dict().duplicate(true)
	var engine_attack_before: Dictionary = engine.state.attack.duplicate(true)
	var defender_energy: int = engine.player(1).duelist.energy
	var block: OptionView = prompt.find(&"defend", engine.player(1).hand[0].uid)
	_check(block != null and bool(block.outcome.get("stopped", false)), "Real block option previews a full stop")
	hud.preview_hand_card(block.card, true)
	_check(hud.prompt_outcome.visible and hud.prompt_outcome.text.begins_with("Preview:"), "Hover is explicitly identified as preview")
	_check(hud.exchange_damage.text == baseline, "Hover leaves the actual damage baseline untouched")
	_check(not hud.exchange_damage.visible, "Explicit preview replaces the visible baseline rather than duplicating it")
	_check(defender.to_dict() == public_before and prompt.to_dict() == prompt_before, "Hover preserves public input views")
	_check(engine.state.attack == engine_attack_before and engine.player(1).duelist.energy == defender_energy, "Hover cannot change authoritative damage or resources")
	hud.preview_hand_card(block.card, false)
	_check(not hud.prompt_outcome.visible, "Leaving a card clears only its hypothetical preview")
	_check(hud.exchange_damage.visible and hud.exchange_damage.text == baseline, "Leaving a preview restores the actual baseline")
	hud._show_attack(attacker, null)
	_check(hud.exchange_response.text != own_response, "Acting and waiting seats get distinct response ownership")
	_check(hud.exchange_damage.text.get_slice(": ", 1) == baseline.get_slice(": ", 1), "Both seats see identical public incoming damage")
	_check(baseline.begins_with("Incoming: ") and hud.exchange_damage.text.begins_with("Deals: "), "The defender reads the numbers as incoming and the attacker as what it deals")
	var landed: SeatView = SeatView.from_dict(defender.to_dict().duplicate(true))
	landed.attack.merge({"landed": true, "stages_dealt": 2, "life_dealt": 1, "life_remaining": 3, "damage": {"stages": 9, "wounds": 8}} , true)
	hud._show_attack(landed, null)
	var landed_text: String = hud.exchange_damage.text
	_check(landed_text.contains("2") and landed_text.contains("1") and landed_text.contains("3"), "Landed damage distinguishes actual Energy/wounds and remaining wounds")
	_check(not landed_text.contains("9") and not landed_text.contains("8"), "Landed rail never redisplays original forecast as damage dealt")
	var stopped: SeatView = SeatView.from_dict(defender.to_dict().duplicate(true))
	stopped.attack.merge({"stopped": true, "stop_count": 1, "stops_needed": 1}, true)
	hud._show_attack(stopped, null)
	_check(hud.exchange_state.text.to_lower().contains("stop"), "Stopped attack is explicitly shown as stopped")
	_check(hud.exchange_damage.text != baseline, "Stopped attack stops promising incoming damage")
	var partial: SeatView = SeatView.from_dict(defender.to_dict().duplicate(true))
	partial.attack.merge({"stop_count": 1, "stops_needed": 2}, true)
	hud._show_attack(partial, prompt)
	_check(hud.exchange_stops.text.contains("1") and hud.exchange_stops.text.contains("2"), "Partial block displays actual stops against required stops")
	var no_attack: SeatView = SeatView.from_dict(defender.to_dict().duplicate(true))
	no_attack.attack = {}
	no_attack.resolving.clear()
	hud._show_attack(no_attack, null)
	_check(not hud.exchange_rail.visible, "Resolved empty exchange clears the rail")
	var hidden: SeatCard = SeatCard.from_dict({"uid": 992, "zone": "hand", "title": "PRIVATE IDENTITY"})
	no_attack.cards[hidden.uid] = hidden
	no_attack.resolving.append(hidden.uid)
	var response: PromptView = PromptView.new()
	response.player = 1
	response.kind = &"respond"
	response.context = {"source": hidden.uid}
	hud._show_attack(no_attack, response)
	_check(not hud.exchange_rail.visible, "Hidden resolving and prompt-source cards cannot expose their identities")
	var public_card: SeatCard = SeatCard.from_dict({"uid": 993, "def": "public_response", "title": "Public combat effect", "zone": "resolving"})
	no_attack.cards[public_card.uid] = public_card
	no_attack.resolving.append(public_card.uid)
	hud._show_attack(no_attack, response)
	_check(hud.exchange_rail.visible and hud.exchange_state.text == "RESPONSE WINDOW", "Public nonattack resolution gets a response rail")
	_check(hud.exchange_route.text.contains(public_card.title) and not hud.exchange_route.text.contains(hidden.title), "Resolving rail names only public identities")
	_check(not hud.exchange_damage.visible, "Nonattack response does not display invented damage")
	no_attack.resolving.clear()
	no_attack.pending_card = public_card.uid
	no_attack.deciding = 1
	no_attack.deciding_kind = &"respond"
	hud._show_attack(no_attack, null)
	_check(hud.exchange_rail.visible and hud.exchange_route.text.contains(public_card.title), "Waiting seat sees the publicly announced nonattack card without private prompt data")
	var nested: SeatView = SeatView.from_dict(defender.to_dict().duplicate(true))
	nested.cards[public_card.uid] = public_card
	nested.pending_card = public_card.uid
	response.context = {"source": public_card.uid}
	hud._show_attack(nested, response)
	_check(hud.exchange_damage.text == baseline and hud.exchange_response.text.contains(public_card.title), "Nested response identifies its public card while keeping underlying attack damage")
	_check(not hud.exchange_damage.visible and not hud.exchange_stops.visible, "Unrelated pending response does not show underlying attack damage as the announced card's effect")
	engine.submit(block.to_command(1))
	var real_stop: bool = false
	for event in engine.take_events():
		if event.type == &"attack_stopped":
			real_stop = true
	_check(real_stop, "The stop preview agrees with actual fixture defense resolution")
	_test_receipt(hud, SeatView.of(engine, 1), defender)


func _test_receipt(hud: Node, receipt: SeatView, active: SeatView) -> void:
	_check(not receipt.last_attack.is_empty() and receipt.attack.is_empty(), "Actual stopped attack produces a public completed receipt")
	hud._view = receipt
	hud._show_attack(receipt, null)
	_check(hud.exchange_rail.visible and hud.exchange_state.text == "LAST EXCHANGE / RESOLVED", "Resolved combat receipt remains available between attacks")
	_check(hud.exchange_damage.text.to_lower().contains("stopped") and not hud.exchange_response.visible and not hud.exchange_stops.visible, "Stopped receipt is an outcome rather than an actionable defense")
	_check(hud._focus_uid(null) == -1, "Last receipt does not reopen a large attack focus")
	var landed: SeatView = SeatView.from_dict(receipt.to_dict().duplicate(true))
	landed.last_attack.merge({"stopped": false, "stages_dealt": 4, "life_dealt": 2}, true)
	hud._show_attack(landed, null)
	_check(hud.exchange_damage.text.contains("4 Energy, 2 wounds") and hud.exchange_damage.text.to_lower().contains("dealt"), "Resolved receipt uses actual dealt totals")
	landed.step = GameState.Step.NON_COMBAT
	hud._show_attack(landed, null)
	_check(not hud.exchange_rail.visible, "Last combat receipt disappears outside Combat")
	var current: SeatView = SeatView.from_dict(active.to_dict().duplicate(true))
	current.last_attack = receipt.last_attack.duplicate(true)
	hud._show_attack(current, null)
	_check(hud.exchange_state.text != "LAST EXCHANGE / RESOLVED" and not hud.exchange_damage.text.begins_with("Last:"), "Current attack supersedes the last receipt")


## The defence question names the attack from public fields, and the tray widens and balances.
func _test_labels(hud: Node, defender: SeatView) -> void:
	var a: Dictionary = defender.attack
	var name: String = hud.attack_name(a)
	_check(name == str(a["source_title"]), "A card attack is named by its card")
	_check(hud.attack_name({"performer_title": "Caedan Vale", "source_title": "Some discard", "is_final": true}) == "Caedan Vale's Final Strike", "A Final Strike is named by who makes it, not the card thrown away")
	_check(hud.attack_name({"performer_title": "Enrys", "is_power": true}) == "Enrys' Power", "A name ending in s takes a bare apostrophe")
	_check(hud.attack_name({}) == "the Strike", "An attack with no public names falls back to its kind")
	var screen: Vector2 = Vector2(1920, 1080)
	var seven: Dictionary = hud.tray_layout(7, screen)
	_check(int(seven["columns"]) == 4, "Seven tray cards sit four and three, not six and one")
	var three: Dictionary = hud.tray_layout(3, screen)
	var face: Vector2 = three["face"]
	_check(int(three["columns"]) == 3 and is_equal_approx(face.x, 340.0), "A short tray widens its faces up to the cap")
	var many: Dictionary = hud.tray_layout(12, screen)
	_check((many["face"] as Vector2).x >= 204.0 and int(many["columns"]) == 6, "A full tray keeps the smallest face and six across")


func _test_seat_names() -> void:
	var session: Node = root.get_node("Session")
	if session.decks.size() < 2:
		return
	var saved_chosen: Array[DeckList] = session.chosen
	var saved_names: Array[String] = session.player_names
	var saved_ai: int = session.ai_seat
	var pair: Array[DeckList] = [session.decks[0], session.decks[1]]
	var stock: Array[String] = ["Player 1", "Player 2"]
	var versus_ai: Array[String] = ["Player 1", "The AI"]
	var typed: Array[String] = ["Midge", "The AI"]
	session.chosen = pair
	session.player_names = stock
	session.ai_seat = -1
	var hotseat: Array[String] = session.seat_names()
	_check(hotseat == stock, "Hotseat keeps Player 1 and Player 2")
	session.ai_seat = 1
	session.player_names = versus_ai
	var against_ai: Array[String] = session.seat_names()
	var expected: Array[String] = [session.duelist_name(pair[0]), session.duelist_name(pair[1])]
	if expected[0] != expected[1]:
		_check(against_ai == expected, "Against the AI both seats go by their duelists' names")
	session.player_names = typed
	var kept: Array[String] = session.seat_names()
	_check(kept[0] == "Midge", "A name the player typed is kept")
	session.chosen = saved_chosen
	session.player_names = saved_names
	session.ai_seat = saved_ai


func _test_response(hud: Node) -> void:
	var engine: DuelEngine = _defense_position(true)
	_check(engine.prompt.kind == &"respond", "Real Combat card opens an opponent counter window")
	if engine.prompt.kind != &"respond":
		return
	var prompt: PromptView = PromptView.of(engine.prompt, engine)
	var announced: int = int(engine.prompt.context["card"])
	for seat in range(2):
		var view: SeatView = SeatView.of(engine, seat)
		view.last_attack = {"source_title": "Older attack", "stopped": false, "stages_dealt": 9, "life_dealt": 9}
		hud._show_attack(view, prompt if prompt.player == seat else null)
		_check(view.pending_card == announced and not view.card(announced).hidden(), "Real announced card is public to both seats")
		_check(hud.exchange_state.text == "RESPONSE WINDOW" and hud.exchange_route.text.contains(view.card(announced).title), "Real response supersedes an older receipt for both acting and waiting seats")
		_check(not hud.exchange_damage.visible, "Real nonattack counter window has no invented attack forecast")
		_check(hud.exchange_response.text.begins_with("You") == (seat == prompt.player), "Real counter window identifies response ownership")
		for uid in view.player(1 - seat).hand:
			if uid != announced:
				_check(view.card(uid).hidden(), "Real response does not reveal unannounced opponent hand cards")
	engine.submit(engine.prompt.find(&"decline"))
	_check(SeatView.of(engine, 0).pending_card == -1, "Real response completion clears announced pending card")


func _test_links(view: SeatView) -> void:
	var script: Script = load("res://scripts/duel/duel_view.gd")
	var expected_target: int = view.player(1).controlling
	if expected_target < 0:
		expected_target = view.player(1).duelist
	var cards: Vector2i = script.attack_link_cards(view, view.attack)
	_check(cards.x == int(view.attack["source"]) and cards.y == expected_target, "Pending attack links its public source to defender's controlling personality")
	var spent: SeatView = SeatView.from_dict(view.to_dict().duplicate(true))
	var spent_card: SeatCard = spent.card(int(spent.attack["source"]))
	spent_card.zone = &"discard"
	_check(script.attack_link_cards(spent, spent.attack).x == spent.player(0).controlling, "A spent attack links from its fighter instead of its discard rail")
	var redirected: SeatView = SeatView.from_dict(view.to_dict().duplicate(true))
	var ally: SeatCard = SeatCard.from_dict({"uid": 990, "def": "fixture_ally", "title": "Visible ally", "zone": "in_play", "owner": 1})
	redirected.cards[ally.uid] = ally
	redirected.attack["target"] = ally.uid
	_check(script.attack_link_cards(redirected, redirected.attack).y == ally.uid, "Redirected damage targets the public Ally rather than the Duelist")
	var hidden: SeatCard = SeatCard.from_dict({"uid": 991, "zone": "hand", "owner": 0})
	redirected.cards[hidden.uid] = hidden
	redirected.attack["source"] = hidden.uid
	_check(script.attack_link_cards(redirected, redirected.attack).x == redirected.player(0).duelist, "Hidden source falls back to public attacker identity")
	redirected.attack["target"] = hidden.uid
	_check(script.attack_link_cards(redirected, redirected.attack).y == expected_target, "Hidden target falls back to the public defender")
	var live_controllers: Array = [redirected.player(0).duelist, ally.uid]
	_check(script.attack_link_cards(redirected, redirected.attack, live_controllers).y == ally.uid, "Replay controller selects the correct Ally before final state arrives")
	var fx: DuelFx = DuelFx.new()
	root.add_child(fx)
	fx.reduced_motion = true
	fx.show_attack_link(Vector3.ZERO, Vector3(2, 0, 1), &"pending")
	var link: MeshInstance3D = fx._attack_link
	_check(link != null and link.visible and link.mesh != null, "Reduced motion retains a visible static attack route")
	var count: int = fx.get_child_count()
	fx.show_attack_link(Vector3.ZERO, Vector3(2, 0, 1), &"stopped")
	_check(fx._attack_link == link and fx._link_state == &"stopped", "Stopping updates the same route node and its semantic state")
	fx.show_attack_link(Vector3.ZERO, Vector3(2, 0, 1), &"landed")
	_check(fx._link_state == &"landed" and fx.get_child_count() == count, "Landing reuses the cue without accumulating effect nodes")
	fx.burst(Vector3.ZERO, Color.WHITE)
	_check(fx.get_child_count() == count, "Reduced motion suppresses moving spark particles")
	for child in fx.get_children():
		_check(not child is CollisionObject3D, "Attack cue never intercepts card input")
	fx.clear_attack_link()
	_check(not link.visible, "Attack end clears the persistent route")
	fx.free()


func _test_legal_actions(hud: Node) -> void:
	# Fixture faces use the same library lookup as real preview cards.
	root.get_node("Session").library.defs.merge(library.defs)
	var engine: DuelEngine = _defense_position(true)
	var prompt: PromptView = PromptView.of(engine.prompt, engine)
	var view: SeatView = SeatView.of(engine, prompt.player)
	hud.option_chosen.connect(func(option: OptionView) -> void: emitted.append(option.to_command(prompt.player).to_dict()))
	await hud.show_prompt(prompt, view)
	await process_frame
	_check(hud.focus.visible and hud.prompt_title.visible and not hud.prompt_who.visible, "Announced card keeps the actionable decision question, with no owner line for the local decider")
	_check(not hud.exchange_state.visible and not hud.exchange_route.visible and not hud.exchange_response.visible, "Attached status does not repeat card identity, type and response prose")
	for window_size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1200), Vector2i(2560, 1080)]:
		root.size = window_size
		await process_frame
		hud._layout_prompt_column()
		await process_frame
		# DuelView hides the fallback 2D CardFace. Its camera-mounted 512x716 Sprite3D
		# occupies the focus width above the caption; test that displayed card footprint.
		var focus_rect: Rect2 = hud.focus.get_global_rect()
		var face: Rect2 = hud.focus_face_rect()
		var decision: Rect2 = hud.prompt_panel.get_global_rect()
		var viewport: Rect2 = root.get_visible_rect()
		var constants: Dictionary = hud.get_script().get_script_constant_map()
		_check(face.position.x >= decision.position.x - 1.0 and face.end.x <= decision.end.x + 1.0, "Decision shares the focused card's column at %dp" % window_size.y)
		_check(decision.position.y >= focus_rect.end.y - float(constants["PROMPT_LONG_RISE"]) - 1.0, "The decision never reaches the focused card's face at %dp" % window_size.y)
		_check(is_equal_approx(focus_rect.size.x, float(constants["RAIL_CARD_WIDTH"])), "The focused card keeps one size with the decision up at %dp" % window_size.y)
		_check(focus_rect.position.y >= float(constants["RAIL_TOP"]) - 1.0, "The focused card stays under the corner toggles at %dp" % window_size.y)
		_check(absf(focus_rect.end.x - (viewport.end.x - float(constants["GUTTER"]))) < 1.0 and absf(focus_rect.position.y - hud.rail_top()) < 1.0, "The rail card sits where the rail puts it, off the right edge, at %s" % str(window_size))
		_check(absf(decision.end.y - (viewport.end.y - float(constants["PROMPT_BOTTOM"]))) < 1.0, "The decision frame stands on one bottom edge at %s" % str(window_size))
		_check(viewport.encloses(hud.prompt_title.get_global_rect()), "Decision question stays inside viewport at %dp" % window_size.y)
		if hud.exchange_damage.is_visible_in_tree():
			_check(viewport.encloses(hud.exchange_damage.get_global_rect()), "Incoming consequence stays inside viewport at %dp" % window_size.y)
		_check(viewport.encloses(hud.actions_scroll.get_global_rect()), "Response action region stays inside viewport at %dp" % window_size.y)
		for child in hud.primary_box.get_children():
			if child is Button and child.visible:
				_check(viewport.encloses(child.get_global_rect()), "Primary action stays inside viewport at %dp: %s" % [window_size.y, child.text])
	for child in hud.primary_box.get_children():
		if child is Button:
			child.pressed.emit()
	# Card-based counters remain available through their real per-card action chooser.
	var tested_cards: Dictionary = {}
	for option in prompt.options:
		if option.card < 0 or tested_cards.has(option.card):
			continue
		tested_cards[option.card] = true
		var options: Array[OptionView] = prompt.options_for_card(option.card)
		await hud.show_card_choice(options)
		await process_frame
		for child in hud.tray_buttons.get_children():
			if child is Button:
				for offered in options:
					if child.text == offered.label:
						child.pressed.emit()
	for option in prompt.options:
		_check(emitted.has(option.to_command(prompt.player).to_dict()), "Response option remains reachable through an actual UI action: " + option.label)
	_check(engine.prompt.kind == &"respond", "Presentation action tests emit choices without submitting or mutating rules")
	hud._hide_tray()
	var waiting: SeatView = SeatView.of(engine, 0)
	hud.show_waiting(view.player(1).name, &"respond", waiting)
	await process_frame
	_check(hud.focus.visible and hud.primary_box.get_child_count() == 0, "Waiting seat retains the announced preview without local action buttons")
	var defense_engine: DuelEngine = _defense_position()
	var defense_view: SeatView = SeatView.of(defense_engine, 1)
	var defense_prompt: PromptView = PromptView.of(defense_engine.prompt, defense_engine)
	await hud.show_prompt(defense_prompt, defense_view)
	await process_frame
	var decline_button: Button = hud.primary_box.get_child(0)
	var decline_before_focus: Rect2 = decline_button.get_global_rect()
	decline_button.focus_entered.emit()
	await process_frame
	_check(hud.prompt_outcome.visible and hud.prompt_outcome.text.begins_with("Preview:"), "Keyboard focus shows the same explicit outcome preview as pointer hover")
	_check(decline_button.get_global_rect().is_equal_approx(decline_before_focus), "Keyboard outcome preview does not move the focused action")
	decline_button.focus_exited.emit()
	await process_frame
	var before_hover: Rect2 = hud.primary_box.get_global_rect()
	var defend: OptionView = defense_prompt.find(&"defend", defense_engine.player(1).hand[0].uid)
	hud.preview_hand_card(defend.card, true)
	await process_frame
	_check(hud.primary_box.get_global_rect().is_equal_approx(before_hover), "Hover preview does not move response buttons")
	hud.preview_hand_card(defend.card, false)
	await process_frame
	_check(hud.primary_box.get_global_rect().is_equal_approx(before_hover), "Leaving hover does not move response buttons")
	var complex_view: SeatView = SeatView.from_dict(defense_view.to_dict().duplicate(true))
	complex_view.attack["stops_needed"] = 3
	complex_view.attack["stop_count"] = 1
	complex_view.attack["no_prevent"] = true
	var complex_prompt: PromptView = PromptView.from_dict(defense_prompt.to_dict().duplicate(true))
	complex_prompt.title = "Defend against the relentless three-part Focused Strike?"
	await hud.show_prompt(complex_prompt, complex_view)
	await process_frame
	var complex_viewport: Rect2 = root.get_visible_rect()
	_check(complex_viewport.encloses(hud.prompt_title.get_global_rect()), "Long combat question stays inside the viewport")
	_check(hud.exchange_stops.visible and complex_viewport.encloses(hud.exchange_stops.get_global_rect()), "Multi-stop and prevention details stay inside the viewport")
	for child in hud.primary_box.get_children():
		if child is Button and child.visible:
			_check(complex_viewport.encloses(child.get_global_rect()), "Complex combat prompt keeps its primary action inside the viewport: " + child.text)
	var generic: PromptView = PromptView.new()
	generic.kind = &"control"
	generic.player = 1
	generic.title = "Who takes control?"
	generic.context = {"source": int(defense_view.attack["source"])}
	await hud.show_prompt(generic, defense_view)
	_check(hud.focus.visible and hud.prompt_title.visible and hud.prompt_title.text == generic.title, "Card-linked control choice keeps its purposeful question")
	await _test_endurance_action(hud, defense_view)
	var cardless: SeatView = SeatView.from_dict(view.to_dict().duplicate(true))
	cardless.attack = {}
	cardless.pending_card = -1
	cardless.resolving.clear()
	cardless.last_attack.clear()
	var choose: PromptView = PromptView.new()
	choose.player = view.seat
	choose.kind = &"declare"
	choose.title = "Enter Combat?"
	var option: OptionView = OptionView.new()
	option.type = &"skip"
	option.label = "Skip Combat"
	choose.options.append(option)
	await hud.show_prompt(choose, cardless)
	await process_frame
	_check(not hud.focus.visible and hud.prompt_title.visible and hud.primary_box.get_child_count() == 1, "Cardless choice keeps its standalone question and legal action")
	_check(root.get_visible_rect().encloses(hud.prompt_panel.get_global_rect()), "Cardless fallback stays inside viewport")
	var gutter: float = float(hud.get_script().get_script_constant_map()["PROMPT_BOTTOM"])
	_check(absf(hud.prompt_panel.get_global_rect().end.y - (root.get_visible_rect().end.y - gutter)) < 1.0, "A cardless decision stands on the same bottom edge as a card's decision")
	var many: Array[OptionView] = []
	for index in range(18):
		var alternative: OptionView = OptionView.new()
		alternative.type = &"pick_option"
		alternative.value = index
		alternative.label = "Choose alternative %d" % index
		many.append(alternative)
	hud._fill_buttons(many, hud.primary_box, true)
	await process_frame
	hud._fit_actions()
	await process_frame
	_check(hud.primary_box.get_child_count() == many.size(), "Long action list retains every offered option")
	var ceiling: float = hud._panel_top() - float(hud.get_script().get_script_constant_map()["PROMPT_LONG_RISE"])
	_check(hud.prompt_panel.get_global_rect().position.y >= ceiling - 1.0 and root.get_visible_rect().encloses(hud.actions_scroll.get_global_rect()), "Long action list scrolls under the frame's ceiling")
	_check(absf(hud.prompt_panel.get_global_rect().end.y - (root.get_visible_rect().end.y - gutter)) < 1.0, "A long list keeps the frame on its bottom edge")
	_check(hud.actions_scroll.follow_focus and hud.actions_scroll.get_v_scroll_bar().max_value > hud.actions_scroll.size.y, "Clipped alternatives remain reachable by scrolling and keyboard focus")
	var before_last: int = emitted.size()
	hud.primary_box.get_child(many.size() - 1).pressed.emit()
	_check(emitted.size() == before_last + 1 and emitted.back() == many.back().to_command(view.seat).to_dict(), "Last scrollable option still emits its original command")
	hud.clear_prompt()


func _test_endurance_action(hud: Node, view: SeatView) -> void:
	var prompt: PromptView = PromptView.new()
	prompt.kind = &"endurance"
	prompt.player = view.seat
	var uid: int = int(view.attack["source"])
	prompt.context = {"card": uid, "source": uid, "remaining": 5, "endurance": 2}
	var endure: OptionView = OptionView.new()
	endure.type = &"endure"
	endure.card = uid
	endure.label = "Use " + view.card(uid).title
	endure.outcome = {"life": 0}
	prompt.options.append(endure)
	var decline: OptionView = OptionView.new()
	decline.type = &"decline"
	decline.label = "Take wounds"
	decline.outcome = {"life": 5}
	prompt.options.append(decline)
	await hud.show_prompt(prompt, view)
	await process_frame
	var button: Button = hud.primary_box.get_child(0)
	_check(not button.text.contains(view.card(uid).title), "Endurance action does not repeat the preview card's title")
	_check(button.tooltip_text.contains("Prevents 5 wounds") and button.tooltip_text.contains("Remove"), "Boosted Endurance explains removal and actual five-wound prevention from referee outcome")
	var before: int = emitted.size()
	button.pressed.emit()
	_check(emitted.size() == before + 1 and emitted.back() == endure.to_command(prompt.player).to_dict(), "Clearer Endurance wording preserves the exact offered command")


## The phase track on the table, the pending pile and the one-action button all read public
## state only.
func _test_strip_and_queue(hud: Node, base: SeatView) -> void:
	var view: SeatView = SeatView.from_dict(base.to_dict().duplicate(true))
	var track: PhaseTrack = load("res://scenes/duel/phase_track.tscn").instantiate()
	track.reduced_motion = true
	root.add_child(track)
	view.step = GameState.Step.COMBAT
	view.phase = GameState.Phase.ATTACK
	view.consecutive_passes = 1
	track.refresh(view)
	_check(track.lit == &"attack", "Combat lights its Attack icon in the ring")
	_check(track.icon(&"attack").modulate == Color(ZenithTheme.ATTACK, 1.0), "The Attack icon wears the attack colour")
	_check(is_equal_approx(track.icon(&"declare").modulate.a, track.DONE_ALPHA) and is_equal_approx(track.icon(&"discard").modulate.a, track.AHEAD_ALPHA), "Steps behind are dimmed and steps ahead are faint")
	_check(track.icon(&"end").modulate == Color(ZenithTheme.WARN, track.WARN_ALPHA), "One pass so far warms the End icon: the next pass ends Combat")
	view.phase = GameState.Phase.FIGHT_BACK
	track.refresh(view)
	_check(track.lit == &"attack", "A fight back stays on the Attack icon rather than a step of its own")
	view.phase = GameState.Phase.DEFEND
	view.consecutive_passes = 0
	track.refresh(view)
	_check(track.lit == &"defend" and is_equal_approx(track.icon(&"attack").modulate.a, track.DONE_ALPHA), "Defend lights and Attack falls behind it")
	view.phase = GameState.Phase.BATTLE
	track.refresh(view)
	_check(track.lit == &"resolve", "The battle sequence lights Resolve")
	view.step = GameState.Step.POWER_UP
	view.phase = GameState.Phase.NONE
	track.refresh(view)
	_check(track.lit == &"power_up" and is_equal_approx(track.icon(&"enter").modulate.a, track.AHEAD_ALPHA), "Outside Combat a turn step lights and the ring waits")
	var live: Dictionary = {"step": GameState.Step.DISCARD, "phase": GameState.Phase.NONE}
	track.refresh(view, live)
	_check(track.lit == &"discard", "The track reads the beat's own stamp before the view")
	# A pulse caught while an icon is fading must still settle on the faded state.
	track.reduced_motion = false
	view.step = GameState.Step.COMBAT
	view.phase = GameState.Phase.BATTLE
	track.refresh(view)
	view.phase = GameState.Phase.DEFEND
	track.refresh(view)
	track.pulse(&"resolve")
	await create_timer(0.6).timeout
	_check(is_equal_approx(track.icon(&"resolve").modulate.a, track.AHEAD_ALPHA), "A pulsed icon settles on its state, not on the colour it had mid-fade")
	track.queue_free()
	# Reduced Motion so a popped face is gone by the next check instead of drifting out of it.
	hud.reduced_motion_toggle.set_pressed_no_signal(true)
	hud.clear_prompt()
	hud.hide_focus()
	var source: int = int(view.attack.get("source", -1))
	await _test_stack_from_pending(hud, view, source)
	hud.hide_focus()
	hud.quiet_beat("Nothing to respond with", ZenithTheme.MUTED)
	_check(hud.banner.visible and hud.banner_text.text == "Nothing to respond with", "A skipped window still gets its own quiet beat")
	var cardless: SeatView = SeatView.from_dict(view.to_dict().duplicate(true))
	cardless.attack = {}
	cardless.pending_card = -1
	cardless.resolving.clear()
	cardless.last_attack.clear()
	cardless.consecutive_passes = 1
	var declare: PromptView = PromptView.new()
	declare.player = 1
	declare.kind = &"declare"
	declare.title = "Enter Combat?"
	var skip: OptionView = OptionView.new()
	skip.type = &"skip"
	skip.label = "Skip Combat"
	declare.options.append(skip)
	await hud.show_prompt(declare, cardless)
	await process_frame
	_check(hud._single_action != null and hud._single_action.text == "No Combat", "A lone action is relabelled by what it does")
	_check(hud._single_action.custom_minimum_size.y >= 56.0, "The lone action button is large enough to be the whole decision")
	var attack_action: PromptView = PromptView.new()
	attack_action.player = 1
	attack_action.kind = &"attack_action"
	attack_action.title = "Attack?"
	var pass_option: OptionView = OptionView.new()
	pass_option.type = &"pass"
	pass_option.label = "Pass"
	attack_action.options.append(pass_option)
	await hud.show_prompt(attack_action, cardless)
	await process_frame
	_check(hud._single_action != null and hud._single_action.text.contains("ends Combat"), "The last pass before Combat ends says so on the button")
	var space: InputEventKey = InputEventKey.new()
	space.pressed = true
	space.keycode = KEY_SPACE
	var before: int = emitted.size()
	hud._unhandled_input(space)
	_check(emitted.size() == before + 1 and emitted.back() == pass_option.to_command(1).to_dict(), "Space takes the lone action and nothing else")
	var both: PromptView = PromptView.from_dict(attack_action.to_dict().duplicate(true))
	var decline: OptionView = OptionView.new()
	decline.type = &"decline"
	decline.label = "Let it resolve"
	both.options.append(decline)
	await hud.show_prompt(both, cardless)
	await process_frame
	_check(hud._single_action == null and hud.primary_box.get_child_count() == 2, "Two alternatives stay equal rows with no Space shortcut")
	hud.reduced_motion_toggle.set_pressed_no_signal(false)
	hud.clear_prompt()


## Everything waiting to resolve is one pile on the right. `SeatView.pending` picks the anchor and
## the faces stacked over it, the wound loop is a line on the caption rather than a face, a job that
## leaves the queue leaves the pile, and the filament to the target comes off the anchored card.
func _test_stack_from_pending(hud: Node, view: SeatView, source: int) -> void:
	var anchors: AnchorStub = AnchorStub.new()
	root.add_child(anchors)
	hud.table = anchors
	var triggers: Array[SeatCard] = []
	for index in range(6):
		var card: SeatCard = SeatCard.from_dict({"uid": 700 + index, "def": "t_taunt",
			"title": "Trigger %d" % index, "zone": "in_play", "owner": index % 2})
		view.cards[card.uid] = card
		triggers.append(card)
	hud._view = view
	var attack_item: Dictionary = {"kind": &"attack", "uid": source, "title": view.card(source).title,
		"owner": 0, "target": view.player(1).duelist, "note": "5 Energy", "current": true}
	var first_item: Dictionary = {"kind": &"trigger", "uid": triggers[0].uid, "title": triggers[0].title,
		"owner": 1, "target": -1, "note": "when entering Combat", "current": false}
	var second_item: Dictionary = {"kind": &"trigger", "uid": triggers[1].uid, "title": triggers[1].title,
		"owner": 0, "target": -1, "note": "now", "current": false}
	var queue: Array[Dictionary] = [attack_item, first_item, second_item]
	view.pending = queue
	hud.refresh_state(view, 1)
	await process_frame
	_check(hud.focus.visible and hud.focus_uid() == source, "A declared attack anchors the pile on the right")
	_check(hud.stack_depth() == 2, "The jobs queued behind it are faces stacked over it")
	_check(int(hud.stack.get_child(1).get_meta("uid", -1)) == triggers[0].uid, "The job resolving next is the face on top")
	_check(int(hud.stack.get_child(0).get_meta("uid", -1)) == triggers[1].uid, "and the one after it sits under it")
	_check((hud.stack.get_child(1).get_node("Strip") as Label).text == "TRIGGER", "A queued trigger carries its own caption strip")
	# Only triggers: the first to resolve becomes the anchor and says what it is waiting on.
	var only: Array[Dictionary] = [first_item, second_item]
	view.pending = only
	hud.refresh_state(view, 1)
	await process_frame
	_check(hud.focus_uid() == triggers[0].uid, "With no attack the job resolving first anchors the pile")
	_check(hud.focus_caption.text == "TRIGGER · WHEN ENTERING COMBAT", "and its caption reads as a trigger with the engine's note")
	_check(hud.stack_depth() == 1 and hud.has_response(triggers[1].uid), "with the job behind it as the only stacked face")
	var masked: Dictionary = {"kind": &"hidden", "uid": -1, "title": "", "owner": 0, "target": -1,
		"note": "", "current": false}
	var with_masked: Array[Dictionary] = [first_item, masked]
	view.pending = with_masked
	hud.refresh_state(view, 1)
	await process_frame
	_check(hud.stack_depth() == 1 and not hud.has_response(triggers[1].uid), "A job that left the queue leaves the pile")
	var back: Control = hud.stack.get_child(hud.stack_depth() - 1)
	_check(not (back.get_child(0) is CardFace), "A masked job is a card back rather than a readable face")
	_check((back.get_node("Strip") as Label).text == "OPPONENT'S TRIGGER", "and it says only whose it is")
	# The wound loop borrows the attack's uid but is the loop rather than the card.
	var wounds_item: Dictionary = {"kind": &"wounds", "uid": source, "title": "", "owner": 0,
		"target": view.player(1).duelist, "note": "3 wounds", "current": true}
	var with_wounds: Array[Dictionary] = [attack_item, wounds_item]
	view.pending = with_wounds
	hud.refresh_state(view, 1)
	await process_frame
	_check(hud.stack_depth() == 0, "The wound loop is not a face of its own")
	_check(hud.focus_caption.text.contains("3 WOUNDS"), "and it is a line on the anchor's caption instead")
	# A beat naming a card the queue already dealt renames that face rather than dealing a second.
	var again: Array[Dictionary] = [attack_item, second_item]
	view.pending = again
	hud.refresh_state(view, 1)
	await process_frame
	_check(hud.stack_depth() == 1, "The queue behind the attack is one face")
	var def: CardDef = library.defs.get(view.card(triggers[1].uid).def_id)
	_check(hud.push_response(def, "Counter", &"defend", triggers[1].uid), "A response beat for a card already on the pile is taken")
	_check(hud.stack_depth() == 1, "and it does not deal a second copy of the same card")
	_check((hud._entry_for_uid(triggers[1].uid).get_node("Strip") as Label).text == "COUNTER", "It renames the face that is already there")
	# Deeper than the pile shows: the jobs furthest from resolving are counted on the top face.
	var crowded: Array[Dictionary] = [attack_item]
	for card in triggers:
		crowded.append({"kind": &"trigger", "uid": card.uid, "title": card.title,
			"owner": 0, "target": -1, "note": "now", "current": false})
	view.pending = crowded
	hud.refresh_state(view, 1)
	await process_frame
	_check(hud.stack_depth() == hud.STACK_MAX, "The pile never shows more faces than it has levels")
	_check(hud._overflow != null and hud._overflow.text == "+2", "The jobs it cannot show are counted on the top face")
	var settled: Array[Dictionary] = [attack_item]
	view.pending = settled
	hud.refresh_state(view, 1)
	await process_frame
	_check(hud.stack_depth() == 0 and hud._overflow == null, "An emptied queue takes every stacked face and the badge with it")
	_check(hud.filament.visible, "The filament runs from the anchored card to the target")
	var thread: Line2D = hud.filament_thread
	var origin: Vector2 = thread.points[0] + hud.filament.global_position
	var face: Rect2 = hud.focus.get_global_rect()
	_check(absf(origin.x - face.position.x) <= hud.FILAMENT_TAIL + 2.0, "and it leaves the card's left edge")
	_check(thread.points[thread.points.size() - 1].distance_to(anchors.point - hud.filament.global_position) <= hud.FILAMENT_HEAD + 2.0,
		"and reaches the target's anchor on the table")
	view.attack["stopped"] = true
	hud.refresh_state(view, 1)
	await process_frame
	_check(hud.filament_cap.visible and not hud.filament_head.visible, "A stopped attack closes the thread with a transverse cap")
	view.attack["stopped"] = false
	view.attack["landed"] = true
	hud.refresh_state(view, 1)
	await process_frame
	_check(hud.filament_head.visible and hud.filament_head_trail.visible, "A landed attack takes a double chevron")
	view.attack["landed"] = false
	# A trigger anchor aimed nowhere draws no thread at all.
	var aimless: Array[Dictionary] = [second_item]
	view.pending = aimless
	hud.refresh_state(view, 1)
	await process_frame
	_check(not hud.filament.visible, "An anchor aimed at nothing draws no thread")
	view.pending = settled
	anchors.point = Vector2(-1, -1)
	hud.refresh_state(view, 1)
	await process_frame
	_check(not hud.filament.visible, "No anchor on the table means no filament")
	anchors.point = Vector2(400, 500)
	var empty: Array[Dictionary] = []
	view.pending = empty
	hud.refresh_state(view, 1)
	await process_frame
	_check(not hud.focus.visible and not hud.filament.visible, "An empty queue clears the slot and the thread with it")
	hud.table = root
	anchors.free()


## A declared attack is pinned in the same slot a prompt uses, its caption moves on with the
## exchange, and the cards that answer it stack over it inside the same rect, entering as they are
## played and leaving as they resolve.
func _test_read_holds(hud: Node, base: SeatView) -> void:
	var script: Script = load("res://scripts/duel/duel_view.gd")
	var constants: Dictionary = script.get_script_constant_map()
	_check(float(constants.get("ATTACK_READ", 0.0)) >= 2.0, "An opponent's declared attack is held long enough to read")
	_check(float(constants.get("ATTACK_READ_OWN", 0.0)) >= 1.0, "The viewer's own attack still gets a hold")
	_check(float(constants.get("FOCUS_RELEASE", 0.0)) > 0.0 and float(constants.get("CARD_USE_READ", 0.0)) >= 0.8,
		"The pinned attack is released on a hold and a used card has its own read time")
	_check(float(constants.get("ANSWER_READ_OWN", 0.0)) >= 1.0, "The viewer's own response still holds on top of the stack")
	_check(hud.stack != null and hud.stack.get_parent() == hud.focus and hud.stack.clip_contents,
		"The response stack lives inside the Focus rect and is clipped to it")
	_check(hud.get("answer") == null, "The separate Answer slot is gone")
	hud.clear_prompt()
	hud._view = base
	var attack_uid: int = int(base.attack["source"])
	var attack_def: CardDef = library.defs.get(base.card(attack_uid).def_id)
	hud.show_focus(attack_uid, "Incoming")
	await process_frame
	var prompt_rect: Rect2 = hud.focus.get_global_rect()
	_check(hud.stack_depth() == 0, "Nothing has answered yet, so the stack is empty")
	_check(hud.show_replay_card(attack_def, "You attack · %s" % attack_def.title, ZenithTheme.ATTACK), "A declared attack pins its own face in the slot")
	await process_frame
	_check(hud.focus.get_global_rect().is_equal_approx(prompt_rect), "The pinned attack and the prompt's card share one slot, at one place")
	_check(hud.focus_caption.text == ("You attack · %s" % attack_def.title).to_upper(), "The pinned attack names itself")
	hud.set_focus_caption("No defense · nothing playable", ZenithTheme.DEFEND)
	await process_frame
	_check(hud.focus.visible and hud.focus_caption.text == "NO DEFENSE · NOTHING PLAYABLE", "A quiet no_defense leaves the attack pinned and moves its caption on")
	_check(hud.focus.get_global_rect().is_equal_approx(prompt_rect), "The caption change does not move the card")
	hud.set_focus_caption("Hits for 5 Energy", ZenithTheme.ATTACK)
	_check(hud.focus_caption.text == "HITS FOR 5 ENERGY", "The same slot carries the outcome of the attack it pinned")
	# Reduced Motion, so a popped card is gone by the next check instead of flying out of it.
	hud.reduced_motion_toggle.set_pressed_no_signal(true)
	for window_size in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = window_size
		await process_frame
		hud.clear_stack()
		hud.show_replay_card(attack_def, "You attack · %s" % attack_def.title, ZenithTheme.ATTACK)
		await process_frame
		var anchored: Rect2 = hud.focus.get_global_rect()
		_check(hud.push_response(attack_def, "Defense", &"defend", 501), "A response pushes onto the stack at %dp" % window_size.y)
		_check(hud.push_response(attack_def, "Shield", &"attack", 502), "A second response stacks on the first at %dp" % window_size.y)
		await process_frame
		_check(hud.stack_depth() == 2 and hud.stack.get_child_count() == 2, "Two responses are two cards on the stack at %dp" % window_size.y)
		var lower: Control = hud.stack.get_child(0)
		var upper: Control = hud.stack.get_child(1)
		_check(upper.get_index() > lower.get_index(), "The newest response draws over the older one at %dp" % window_size.y)
		_check(is_equal_approx(upper.position.x - lower.position.x, hud.STACK_STEP.x)
			and is_equal_approx(upper.position.y - lower.position.y, hud.STACK_STEP.y),
			"Each level steps up and to the left by the stack offset at %dp" % window_size.y)
		_check(signf(upper.rotation_degrees) != signf(lower.rotation_degrees) and absf(absf(lower.rotation_degrees) - hud.STACK_TILT) < 0.01,
			"The tilt alternates sign so the pile does not read as one card at %dp" % window_size.y)
		_check(absf(lower.size.x - anchored.size.x * hud.STACK_SCALE) < 1.0, "A stacked face is the smaller of the pair at %dp" % window_size.y)
		_check(hud.focus.get_global_rect().is_equal_approx(anchored), "Pushing responses never moves the anchored attack at %dp" % window_size.y)
		var ground: Vector2 = lower.position
		var covered: Rect2 = Rect2(upper.position, upper.size)
		_check(covered.position.y >= hud.FOCUS_CAPTION_HEIGHT - 2.0, "The stack never covers the attack's caption at %dp" % window_size.y)
		_check(covered.end.y <= hud.focus.size.y + 1.0 and covered.end.x <= hud.focus.size.x + 1.0,
			"The stack stays inside the Focus rect at %dp" % window_size.y)
		_check(root.get_visible_rect().encloses(hud.focus.get_global_rect()), "The Focus rect and everything stacked in it fit on screen at %dp" % window_size.y)
		_check(hud.pop_response(501) and hud.stack_depth() == 1, "A resolved response leaves the stack by uid at %dp" % window_size.y)
		await process_frame
		_check(int(hud.stack.get_child(0).get_meta("uid", -1)) == 502, "The response left behind is the one that has not resolved at %dp" % window_size.y)
		_check(is_equal_approx(hud.stack.get_child(0).position.y, ground.y), "The survivor drops to the level the stack has left at %dp" % window_size.y)
		_check(not hud.pop_response(9001), "A beat resolving something the stack never held does nothing at %dp" % window_size.y)
		var decision: PromptView = PromptView.new()
		decision.player = base.seat
		decision.kind = &"attack_action"
		decision.title = "Attack?"
		var pass_option: OptionView = OptionView.new()
		pass_option.type = &"pass"
		pass_option.label = "Pass"
		decision.options.append(pass_option)
		await hud.show_prompt(decision, base)
		await process_frame
		_check(hud.stack_depth() == 1 and hud.stack.is_visible_in_tree(),
			"An open decision keeps the stack, because it costs the column no room at %dp" % window_size.y)
		_check(hud.push_response(attack_def, "Counter", &"defend", 503) and hud.stack_depth() == 2,
			"A response beat can still stack over an open decision at %dp" % window_size.y)
		await process_frame
		for child in hud.primary_box.get_children():
			if child is Button and child.visible:
				_check(root.get_visible_rect().encloses((child as Button).get_global_rect()), "The decision button stays on screen under the pinned attack at %dp: %s" % [window_size.y, str((child as Button).get_global_rect())])
		_check(root.get_visible_rect().encloses(hud.prompt_panel.get_global_rect()), "The decision panel still fits under the same rect at %dp" % window_size.y)
		hud.clear_prompt()
		await process_frame
		_check(hud.stack_depth() == 0 and hud.stack.get_child_count() == 0, "Clearing the decision empties the stack with the Focus")
	hud.reduced_motion_toggle.set_pressed_no_signal(false)


## One banner home for every beat: a quiet line never cuts short a louder banner still being read,
## a louder one always replaces what is up, and the banner never reaches under the rail.
func _test_beat_banner(hud: Node) -> void:
	hud.reduced_motion_toggle.set_pressed_no_signal(true)
	hud.toast("Hits for 3 Energy", ZenithTheme.ATTACK)
	hud.quiet_beat("Passes", ZenithTheme.MUTED)
	_check(hud.banner_text.text == "Hits for 3 Energy", "A quiet beat waits behind an outcome banner still being read")
	hud.handover("Exchange 2  ·  Test attacks", ZenithTheme.ATTACK)
	_check(hud.banner.visible and hud.banner_text.text.begins_with("Exchange 2"), "A hand-over replaces whatever banner is up")
	_check(hud.banner.size.y > hud.BANNER_HEIGHT[hud.Banner.OUTCOME] - 1.0, "A hand-over is the tallest banner")
	var rail_left: float = hud.root.size.x + hud.RAIL_LEFT
	_check(hud.banner.position.x + hud.banner.size.x <= rail_left, "The banner stays clear of the rail")
	_check(hud.banner.position.y >= 0.0 and hud.banner.position.y + hud.banner.size.y <= hud.root.size.y, "The banner stays on screen")
	hud.reduced_motion_toggle.set_pressed_no_signal(false)
	hud._clear_banner()
	await process_frame


func _test_hit_tiers() -> void:
	var view_script: GDScript = load("res://scripts/duel/duel_view.gd")
	_check(view_script.hit_tier(1, 0) == 0, "A one-stage hit is a chip")
	_check(view_script.hit_tier(4, 0) == 1, "A four-stage hit is solid")
	_check(view_script.hit_tier(7, 0) == 1, "Seven stages are still solid")
	_check(view_script.hit_tier(1, 1) == 1, "One wound is solid, so an ordinary Art does not punch the camera")
	_check(view_script.hit_tier(0, 3) == 2 and view_script.hit_tier(9, 0) == 2, "Three wounds' weight lands heavy")


## A Card3D motion cut off by a newer one still releases whoever awaited it, since a killed tween
## never emits `finished`, and the Body comes to rest at the origin.
func _test_card_motion() -> void:
	var card: Card3D = load("res://scenes/duel/card_3d.tscn").instantiate()
	root.add_child(card)
	await process_frame
	var done: Array[bool] = [false]
	var watch: Callable = func() -> void:
		await card.shake(0.05)
		done[0] = true
	watch.call()
	await process_frame
	card.hop(0.1)
	await process_frame
	_check(done[0], "A shake cut off by a hop releases its awaiter")
	await card.jab(Vector3.FORWARD, 0.02)
	_check(card.body.position.is_zero_approx(), "The Body rests at the origin after a jab")
	card.queue_free()
	await process_frame


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


## Stands in for `DuelView` so the HUD filament can be tested without a table behind it.
class AnchorStub extends Node:
	var point: Vector2 = Vector2(400, 500)

	func screen_anchor(_uid: int) -> Vector2:
		return point
