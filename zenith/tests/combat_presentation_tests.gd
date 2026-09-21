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
	await _test_legal_actions(hud)
	hud.free()
	await process_frame
	print("Combat presentation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _defense_position(pending: bool = false) -> DuelEngine:
	var decks: Array[DeckList] = []
	for seat in range(2):
		var deck: DeckList = DeckList.new()
		deck.duelist_id = "tf_vigil"
		deck.aspects = 3
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
	_check(hud.exchange_damage.text == baseline, "Both seats see identical public incoming damage")
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
	_check(hud.exchange_damage.text.contains("4 Energy / 2 wounds") and hud.exchange_damage.text.to_lower().contains("dealt"), "Resolved receipt uses actual dealt totals")
	landed.step = GameState.Step.NON_COMBAT
	hud._show_attack(landed, null)
	_check(not hud.exchange_rail.visible, "Last combat receipt disappears outside Combat")
	var current: SeatView = SeatView.from_dict(active.to_dict().duplicate(true))
	current.last_attack = receipt.last_attack.duplicate(true)
	hud._show_attack(current, null)
	_check(hud.exchange_state.text != "LAST EXCHANGE / RESOLVED" and not hud.exchange_damage.text.begins_with("Last:"), "Current attack supersedes the last receipt")


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
	_check(hud.focus.visible and hud.prompt_title.visible and not hud.prompt_who.visible, "Announced card keeps the actionable decision question without repeated owner text")
	_check(not hud.exchange_state.visible and not hud.exchange_route.visible and not hud.exchange_response.visible, "Attached status does not repeat card identity, type and response prose")
	_check(hud.prompt_panel.get_theme_stylebox("panel") is StyleBoxEmpty, "Attached actions have no separate boxed information panel")
	for window_size in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = window_size
		await process_frame
		hud._layout_prompt_column()
		await process_frame
		# DuelView hides the fallback 2D CardFace. Its camera-mounted 512x716 Sprite3D
		# occupies the focus width below a 32px caption; test that displayed card footprint.
		var focus_rect: Rect2 = hud.focus.get_global_rect()
		var face: Rect2 = Rect2(focus_rect.position + Vector2(0, 32), Vector2(focus_rect.size.x, focus_rect.size.x * 716.0 / 512.0))
		var decision: Rect2 = hud.prompt_panel.get_global_rect()
		var viewport: Rect2 = root.get_visible_rect()
		_check(absf(face.position.x - decision.position.x) < 2.0 and absf(face.size.x - decision.size.x) < 2.0, "Decision shares the focused card's column at %dp" % window_size.y)
		_check(decision.position.y >= face.end.y and decision.position.y - face.end.y <= 20.0, "Decision attaches immediately below the face at %dp" % window_size.y)
		_check(viewport.encloses(hud.prompt_title.get_global_rect()), "Decision question stays inside viewport at %dp" % window_size.y)
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
	_check(hud.actions_scroll.size.y <= 261.0 and root.get_visible_rect().encloses(hud.actions_scroll.get_global_rect()), "Long action list scrolls within its bounded viewport slot")
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


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
