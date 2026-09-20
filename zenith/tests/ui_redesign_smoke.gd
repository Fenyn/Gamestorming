extends SceneTree
## Integration smoke test for scene wiring and private-hand safety. Uses real shipped decks
## and public referee views, but placeholder face textures so the headless renderer is enough.
## Run: godot --headless --path zenith -s tests/ui_redesign_smoke.gd

var failures: int = 0
var checks: int = 0
var clicks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var session: Node = root.get_node("Session")
	var chosen: Array[DeckList] = [session.decks[0], session.decks[1]]
	session.chosen = chosen
	session.seed_value = 5
	session.ai_seat = -1
	var scene: PackedScene = load("res://scenes/duel/duel.tscn")
	var duel: Node3D = scene.instantiate()
	var cache: CardFaceCache = duel.get_node("CardFaceCache")
	var placeholder: ImageTexture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	cache._back = placeholder
	for value in session.library.defs.values():
		var def: CardDef = value
		if def.is_personality():
			for aspect in def.aspects:
				cache._cache[CardFaceCache.key_for(def, int(aspect.get("aspect", 1)))] = placeholder
		else:
			cache._cache[CardFaceCache.key_for(def)] = placeholder
	root.add_child(duel)
	var deadline: int = Time.get_ticks_msec() + 12000
	while (duel.view == null or duel.hud.loading.visible) and Time.get_ticks_msec() < deadline:
		await process_frame
	await create_timer(1.0).timeout
	_check(duel.view != null, "Real duel scene must finish loading a public view")
	if duel.view == null:
		quit(1)
		return
	# Finish both Reserve decisions through their offered commands, without any UI shortcut.
	var host: DuelHost = duel.duel_host
	for seat in range(2):
		var reserve: PromptView = host.prompt_for(seat)
		if reserve == null:
			continue
		for option in reserve.options:
			if option.type == &"reserve_done":
				var result: Dictionary = host.apply(seat, option.to_command(seat).to_dict())
				_check(str(result.get("problem", "")) == "", "Reserve completion must be an accepted engine option")
				break
	# Build a crowded hand and a genuinely private opposing hand with supported debug
	# effects through the referee, without mutating engine state or fabricating cards.
	for seat in range(2):
		var draw_result: Dictionary = host.dev(seat, {"op": "draw", "amount": 12 if seat == 0 else 3})
		_check(str(draw_result.get("problem", "")) == "", "Debug draw must produce a valid integration fixture")
	duel.viewer = 0
	duel.view = host.view_for(0)
	duel.prompt = host.prompt_for(0)
	duel.hud.hide_handoff()
	duel.hud.tray.hide()
	duel._set_hand({})
	duel._refresh_displays()
	await process_frame
	var hand: Node3D = duel.hand_3d
	# This direct public-view fixture bypasses prompt delivery; explicitly enable its hand.
	hand.set_available(true)
	_check(not hand._items.is_empty(), "Opening hand must be presented after Reserve")
	hand.clicked.connect(func(_uid: int) -> void: clicks += 1)
	hand.reduced_motion = true
	hand._layout(true)
	_check(not hand.revealed, "Hand must start retracted rather than occupying the table")
	var viewport_size: Vector2 = root.get_visible_rect().size
	var bottom_pointer: Vector2 = Vector2(viewport_size.x * 0.52, viewport_size.y - 20.0)
	_check(hand._hit(bottom_pointer, true) == -1, "Retracted hand must have no invisible picking regions")
	_check(hand.blocks_pointer(bottom_pointer), "Hand activation band must suppress board tooltips before cards expand")
	_check(not hand.blocks_pointer(Vector2(viewport_size.x * 0.5, 100.0)), "Tucked hand must not suppress unrelated board picking")
	var hidden_center: Vector2 = duel.camera.unproject_position(hand._items[0]["node"].global_position)
	_check(hidden_center.y > viewport_size.y, "Tucked hand card centers must stay below the viewport")
	var card_height: float = minf(hand.CARD_WIDTH, viewport_size.x * 0.105) * hand.FACE_SIZE.y / hand.FACE_SIZE.x
	var exposed_fraction: float = (viewport_size.y - hidden_center.y + card_height * 0.5) / card_height
	_check(exposed_fraction >= 0.10 and exposed_fraction <= 0.20, "Tucked hand must expose only the top ten to twenty percent as an affordance")
	_check(not hand._items[0]["title"].visible and not hand._items[0]["summary"].visible, "Tucked card tops must not retain floating title or forecast clutter")
	hand._update_pointer(bottom_pointer)
	_check(hand.revealed, "Entering the bottom fifteen percent must reveal the hand")
	var rest_center: Vector2 = hand._items[0]["rect"].get_center()
	hand._update_pointer(rest_center)
	_check(hand._hovered == 0, "A revealed hand card must be selectable by hovering its face")
	var expanded_point: Vector2 = hand._expanded_rect.get_center()
	hand._update_pointer(expanded_point)
	_check(hand.revealed and hand._hovered >= 0, "Expanded face must keep the hand open above its reveal band")
	_check(hand.blocks_pointer(expanded_point), "Expanded hand face must suppress board picking above the activation band")
	hand._update_pointer(Vector2(viewport_size.x * 0.5, 100.0))
	_check(not hand.revealed and hand._hovered == -1, "Leaving the hand and bottom band must retract it and clear preview")
	_check(hand._hit(rest_center, true) == -1, "Former hand slots must stop intercepting the board immediately on retraction")
	var board_point: Vector2 = Vector2(rest_center.x, minf(rest_center.y, viewport_size.y * 0.85 - 1.0))
	_check(not hand.blocks_pointer(board_point), "Retracted hand must restore board tooltip access outside the bottom band")
	var browse_key: InputEventKey = InputEventKey.new()
	browse_key.pressed = true
	browse_key.keycode = KEY_H
	hand._unhandled_input(browse_key)
	_check(hand.revealed and hand.keyboard_active and hand._hovered >= 0, "H must reveal the hand and select a card for keyboard browsing")
	browse_key.keycode = KEY_ESCAPE
	hand._unhandled_input(browse_key)
	_check(not hand.revealed and not hand.keyboard_active, "Escape must retract the hand and leave keyboard mode")
	_check(clicks == 0, "Revealing and retracting the hand must never play a card")
	hand.reduced_motion = false

	for item in hand._items:
		var card: SeatCard = duel.view.card(int(item["uid"]))
		_check(card != null and not card.hidden() and duel.view.player(0).hand.has(card.uid), "Physical hand must contain only viewer-owned visible hand cards")
	for uid in duel.view.player(1).hand:
		_check(duel.view.card(uid).hidden(), "Opponent hand identities must remain hidden")
	var readout: Control = duel.near_duelist.readout
	_check(readout._life == duel.view.player(0).life_deck.size(), "Medallion Life must match the displayed seat")
	_check(duel.near_duelist.life_value.text == str(duel.view.player(0).life_deck.size()), "Life Deck counter must display the actual remaining deck size")
	for seat in range(2):
		var life_slot: Transform3D = duel.zones.slot(seat, &"life_deck", 0, 1, 0)
		var identity_slot: Transform3D = duel.zones.slot(seat, &"duelist", 0, 1, 0)
		_check(is_equal_approx(life_slot.origin.z, identity_slot.origin.z), "Each Life Deck must share its duelist's table row")
		_check(life_slot.origin.distance_to(identity_slot.origin) < 2.0, "Each Life Deck must sit beside its own duelist")
	# The backline left the felt: the piles and the two used cards are rail rows, and the table
	# keeps no zone for them at all.
	for zone in [&"discard", &"removed", &"mastery", &"relic"]:
		_check(not TableLayout.SINGLES.has(zone) and not TableLayout.ROWS.has(zone), "The table must hold no %s zone" % zone)
	for rail in [duel.hud.near_backline, duel.hud.far_backline]:
		for zone in BacklineRail.ROWS:
			_check(rail.row_anchor(zone) != Vector2.ZERO, "The rail must anchor its %s row" % zone)
	var controller: SeatCard = duel.view.card(duel.view.player(0).controlling)
	_check(readout._energy == controller.energy, "Medallion Energy must belong to the controlling personality")
	# Camera zoom changes the projected card footprint; attached resource crests must move
	# outside that footprint and leave the physical card available for its own picking.
	var home_camera: Transform3D = duel.camera.transform
	var home_target: Vector3 = duel.camera._target
	var home_idle: float = duel.camera._idle
	duel._layout_fixtures()
	var footprint_areas: Array[float] = []
	for fixture in [duel.near_duelist, duel.far_duelist]:
		footprint_areas.append(fixture.readout.card_bounds.get_area())
		_check_fixture_geometry(duel, fixture)
	duel.camera.dev_set(Vector2.ZERO, 4)
	duel._layout_fixtures()
	for i in range(2):
		var fixture: Node3D = duel.near_duelist if i == 0 else duel.far_duelist
		_check(fixture.readout.card_bounds.get_area() > footprint_areas[i], "Zooming in must expand each measured physical card footprint")
		_check_fixture_geometry(duel, fixture)
	duel.camera.transform = home_camera
	duel.camera._target = home_target
	duel.camera._idle = home_idle
	duel._layout_fixtures()
	var duelist_uid: int = duel.view.player(0).duelist
	duel._layout_fixtures()
	var field_duelist: Card3D = duel.views.get(duelist_uid)
	_check(field_duelist != null and duel.near_duelist.global_position.is_equal_approx(field_duelist.global_position), "Duelist resource fixture must follow its actual field card")
	if field_duelist != null:
		duel.near_duelist.interactive = true
		_check(not duel.near_duelist.hit_test(duel.camera.unproject_position(field_duelist.global_position), duel.camera), "Resource fixture opening must leave its central field card clickable")
	var live: Dictionary = {"energy": {str(controller.uid): 3}, "might": {str(controller.uid): 27},
		"aspect": {str(duelist_uid): 2}, "controlling": [controller.uid],
		"zones": [[17, 4, 2, 0]], "fervor": [2]}
	duel.near_duelist.refresh(duel.view, 0, 0, live)
	_check(readout._life == 17 and readout._energy == 3 and readout._fervor == 2, "Intermediate event counts must override final counts together")
	_check(duel.near_duelist.life_value.text == "17", "Life Deck counter must show the current event snapshot rather than the final deck count")
	_check(readout._might == 27 and readout._aspect == 2, "Readout must trust replay Might and Aspect instead of inferring them from the final card")
	duel.near_duelist.refresh(duel.view, 0, 0)
	_check(duel.near_duelist.life_value.text == str(duel.view.player(0).life_deck.size()), "Life Deck counter must return to the settled count after replay")
	# A real newly drawn public card joins the existing hand without snapping its neighbours.
	var poses: Dictionary = {}
	for item in hand._items:
		poses[int(item["uid"])] = item["node"].transform
	var draw: Dictionary = host.dev(0, {"op": "draw", "amount": 1})
	_check(str(draw.get("problem", "")) == "", "Arrival fixture must draw a real card")
	duel.view = host.view_for(0)
	var arriving: SeatCard = null
	for uid in duel.view.player(0).hand:
		if not poses.has(uid):
			arriving = duel.view.card(uid)
	_check(arriving != null, "Arrival fixture must expose exactly one newly drawn identity")
	if arriving != null:
		var source: Vector3 = duel.camera.global_position - duel.camera.global_basis.z * 4.0
		hand.receive_card(arriving, cache, duel.view, source)
		var copies: int = 0
		var retained: bool = true
		var launched: bool = false
		for item in hand._items:
			var uid: int = int(item["uid"])
			var node: Node3D = item["node"]
			if uid == arriving.uid:
				copies += 1
				launched = node.global_position.is_equal_approx(source)
			elif poses.has(uid):
				retained = retained and node.transform.is_equal_approx(poses[uid])
		_check(copies == 1 and hand._items.size() == poses.size() + 1, "Draw arrival must add the correct UID exactly once")
		_check(launched and retained, "Arrival must begin at its source while preserving every existing card pose")
		var count_after: int = hand._items.size()
		hand.receive_card(arriving, cache, duel.view, source)
		_check(hand._items.size() == count_after, "Repeated arrival notification must not duplicate a card")
		var hidden: SeatCard = duel.view.card(duel.view.player(1).hand[0])
		_check(hidden.hidden(), "Arrival privacy fixture must contain a genuinely hidden opponent card")
		hand.receive_card(hidden, cache, duel.view, source)
		_check(hand._items.size() == count_after, "A hidden opponent draw must never enter the visible hand")
	var before: Dictionary = host.view_for(0).to_dict()
	hand.preview_index(0)
	hand.preview_index(hand._items.size() - 1)
	_check(hand._page > 0 and hand._items[hand._hovered]["node"].visible, "Keyboard browsing must reach visible cards beyond the first page")
	_check(clicks == 0 and host.view_for(0).to_dict() == before, "Browsing hand must never submit a player choice")
	# Real viewport resizing must preserve the focused card even when page capacity changes.
	var original_scale: Vector2i = root.content_scale_size
	root.content_scale_size = Vector2i(1280, 720)
	hand._layout(true)
	var narrow_capacity: int = hand._per_page
	var focused_uid: int = int(hand._items[hand._hovered]["uid"])
	root.content_scale_size = Vector2i(3840, 1080)
	hand._layout(true)
	_check(hand._per_page != narrow_capacity, "Resize fixture must change the number of cards per page")
	_check(int(hand._items[hand._hovered]["uid"]) == focused_uid and hand._items[hand._hovered]["node"].visible, "Resize must keep the browsed card visible on a valid page")
	root.content_scale_size = Vector2i(1280, 720)
	hand._layout(true)
	hand._set_hover(-1)
	root.content_scale_size = Vector2i(3840, 1080)
	hand._layout(true)
	var visible_cards: int = 0
	for item in hand._items:
		if item["node"].visible:
			visible_cards += 1
	_check(visible_cards > 0, "Resizing an unfocused last page must not leave an empty hand")
	root.content_scale_size = original_scale
	hand._layout(true)
	hand.preview_index(1)
	var overlap: Rect2 = hand._expanded_rect.intersection(hand._items[2]["rect"])
	_check(overlap.has_area(), "Expanded-card fixture must cover part of its neighbour")
	_check(hand._hit(overlap.get_center(), true) == 1, "Clicking the expanded face must pick that face, not its covered neighbour")
	var under_card: Node3D = duel.views[duel.view.player(0).duelist]
	under_card.set_hovered(true)
	duel.hud.peek.show()
	duel._process(0.0)
	_check(not under_card.pick.input_ray_pickable and not under_card._hovering, "Browsing the hand must disable board picking and clear existing hover lift")
	duel._on_card_hovered(under_card.uid, true)
	_check(not duel.hud.peek.visible, "Late board hover signals must not show a tooltip through the hand")
	duel._on_card_inspected(under_card.uid)
	_check(not duel.hud.inspect.visible, "Board inspection must not bleed through the hand")
	duel.hud.inspect.show()
	duel._process(0.0)
	_check(not hand.visible and not duel.near_duelist.interactive and not duel.far_duelist.interactive, "Inspection overlay must disable hand and medallion picking")
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_ENTER
	hand._unhandled_input(key)
	_check(clicks == 0, "Hidden hand must not accept keyboard activation behind inspection")
	duel.hud.inspect.hide()
	# Thinking, resolution and network waits restrict commands, not public observation.
	var focus_was_visible: bool = duel.hud.focus.visible
	var actions_were_visible: bool = duel.hud.prompt_panel.visible
	duel.hud.focus.show()
	duel.hud.prompt_panel.show()
	_check(duel._preview_blocks_point(duel.hud.focus.get_global_rect().get_center()), "Preview card must shield the field underneath from hover and picking")
	_check(duel._preview_blocks_point(duel.hud.prompt_panel.get_global_rect().get_center()), "Attached choices must shield the field underneath")
	duel.hud.focus.hide()
	duel.hud.prompt_panel.hide()
	_check(not duel._preview_blocks_point(duel.hud.focus.get_global_rect().get_center()), "Hidden previews must release their picking region")
	duel.hud.focus.visible = focus_was_visible
	duel.hud.prompt_panel.visible = actions_were_visible
	hand.keyboard_active = false
	hand._set_revealed(false)
	var saved_prompt: PromptView = duel.prompt
	var saved_deciding: int = duel.view.deciding
	var saved_active: int = duel.view.active
	duel.prompt = host.prompt_for(0)
	var choice_for_test: OptionView = duel.prompt.options[0]
	var state_before_observing: Dictionary = host.view_for(0).to_dict()
	duel.busy = true
	duel._process(0.0)
	_check(under_card.pick.input_ray_pickable and duel.near_duelist.interactive, "AI thinking and replay must retain public board hover and inspection")
	_check(not hand.enabled, "Replay must disable hand plays without hiding the hand")
	duel._on_card_hovered(under_card.uid, true)
	_check(duel.hud.peek.visible, "Public hover previews must open while the opponent is acting")
	duel._on_card_inspected(under_card.uid)
	_check(duel.hud.inspect.visible, "Full inspection must remain available during resolution")
	duel._on_option_chosen(choice_for_test)
	_check(host.view_for(0).to_dict() == state_before_observing, "Browsing during resolution must not submit a game command")
	duel.hud.hide_inspect()
	duel.busy = false
	duel.view.deciding = 1
	duel._process(0.0)
	_check(under_card.pick.input_ray_pickable and not hand.enabled, "Opponent decisions must keep observation available without enabling plays")
	duel._on_option_chosen(choice_for_test)
	_check(host.view_for(0).to_dict() == state_before_observing, "A stale local option must not submit during the opponent's decision")
	duel.view.deciding = 0
	duel.view.active = 1
	_check(duel._can_choose(), "A local response is allowed during the opponent's turn when the referee asks this viewer")
	duel._awaiting_answer = true
	duel._process(0.0)
	_check(under_card.pick.input_ray_pickable and not duel._can_choose(), "Network acknowledgement waits must preserve browsing and reject duplicate commands")
	duel._awaiting_answer = false
	duel.view.deciding = saved_deciding
	duel.view.active = saved_active
	duel.prompt = saved_prompt
	duel.hud.hide_peek()
	# Advance through real offered choices until the next seat is asked to decide.
	for step in range(120):
		if host.deciding() == 1 or host.is_over():
			break
		var current_prompt: PromptView = host.prompt_for(0)
		if current_prompt == null or current_prompt.options.is_empty():
			break
		var choice: OptionView = current_prompt.options.back()
		for option in current_prompt.options:
			if option.type in [&"done", &"pass", &"rest", &"decline"]:
				choice = option
				break
		host.apply(0, choice.to_command(0).to_dict())
	_check(host.deciding() == 1, "Hotseat fixture must reach a genuine opposing decision")
	if host.deciding() == 1:
		duel.view = host.view_for(0)
		duel.hud.show_handoff(duel.view.player(1).name)
		duel._on_handoff_confirmed()
		# Deliberately inspect synchronously, before the camera animation's first awaited frame.
		_check(duel.viewer == 1 and duel.busy, "Handoff must lock input before animating the new seat")
		var private_uids: Array = []
		for item in hand._items:
			private_uids.append(int(item["uid"]))
		var new_view: SeatView = host.view_for(1)
		_check(private_uids.size() == new_view.player(1).hand.size(), "Handoff must replace the complete hand before uncovering it")
		for uid in private_uids:
			_check(new_view.player(1).hand.has(uid) and not new_view.card(uid).hidden(), "No previous-seat identity may survive the first handoff frame")
		await create_timer(1.2).timeout
	duel.queue_free()
	await process_frame
	print("UI redesign smoke: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check_fixture_geometry(duel: Node3D, fixture: Node3D) -> void:
	var readout: Control = fixture.readout
	_check(readout.card_bounds.has_area(), "Readout must measure a real projected card footprint")
	_check(not readout.stat_hit_rects.is_empty(), "Headless layout must produce resource click regions without a draw callback")
	var separated: bool = true
	var fits_canvas: bool = true
	var canvas: Rect2 = Rect2(-Vector2(fixture.viewport.size) * 0.5, Vector2(fixture.viewport.size))
	for rect: Rect2 in readout.stat_hit_rects:
		separated = separated and not rect.intersects(readout.card_bounds)
		fits_canvas = fits_canvas and canvas.encloses(rect)
	_check(separated, "Resource click regions must stay outside the projected card face")
	_check(fits_canvas, "Dynamic resource canvas must contain every stat region without clipping at this zoom")
	var physical: Node3D = duel.views[fixture.duelist_uid]
	var card_center: Vector2 = duel.camera.unproject_position(physical.front.global_position)
	_check(not fixture.hit_test(card_center, duel.camera), "A click on the actual card center must never be intercepted by its resource display")
	var life_center: Vector2 = duel.camera.unproject_position(fixture.life_transform.origin)
	_check(not fixture.hit_test(life_center, duel.camera), "Life Deck center must remain clear of surrounding resource hit regions")
