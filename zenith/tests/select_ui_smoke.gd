extends SceneTree
## Windowed UI regression check, including the filter/selection boundary and seat handoff.
## Run with --path zenith -s tests/select_ui_smoke.gd --resolution 1280x720.

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _run() -> void:
	var session: Node = root.get_node("Session")
	var screen: Control = load("res://scenes/select/duelist_select.tscn").instantiate()
	root.add_child(screen)
	await create_timer(0.3).timeout
	var search: LineEdit = screen.get("search")
	var filter: OptionButton = screen.get("school_filter")
	var seat: Variant = screen.get("seat_panel")
	_check(seat.lock_button.disabled, "An empty selection must not confirm")
	_check(screen.get("_visible_indices").size() == session.get("decks").size(), "All decks must be accessible")
	for i: int in range(session.get("decks").size()):
		screen.call("_pick", i)
		await process_frame
		_check(not seat.lock_button.disabled, "A selected deck must be confirmable")
		seat.get_node("Row/Details").pressed.emit()
		await process_frame
		_check(root.get_visible_rect().encloses(seat.get_global_rect()), "Every deck preview must stay onscreen")
		await process_frame
		_check(seat.deck_list.size.x <= seat.size.x, "Details must fit the preview width")
		seat.get_node("Row/Details").pressed.emit()
	_check(seat.get_global_rect().end.x <= root.get_visible_rect().size.x + 1, "Preview must fit the viewport")
	_check(seat.lock_button.get_global_rect().end.y <= root.get_visible_rect().size.y, "Confirm must stay onscreen")
	screen.call("_pick", 0)
	search.text = "no-deck-has-this-name"
	search.text_changed.emit(search.text)
	_check(screen.get("_visible_indices").is_empty(), "No-results search must hide every tile")
	_check(seat.deck == session.get("decks")[0], "Filtering must preserve the selected deck")
	_check(screen.get("empty_label").visible, "No-results guidance must appear")
	screen.call("_reset_filters")
	filter.select(1)
	filter.item_selected.emit(1)
	for index: int in screen.get("_visible_indices"):
		_check(session.get("decks")[index].style == screen.get("_schools")[1], "School filter must exclude other schools")
	search.text = session.get("decks")[0].name
	search.text_changed.emit(search.text)
	_check(screen.get("_visible_indices") == [0], "School and text filters must combine")
	seat.lock_button.pressed.emit()
	_check(screen.get("_seat") == 1, "Confirm must hand off to the second seat")
	_check(seat.deck == null and seat.lock_button.disabled, "Second seat must make its own choice")
	_check(not seat.mastery_box.visible and not seat.mastery_zoom.visible, "Handoff must clear the previous Mastery")
	_check(screen.get("_visible_indices").size() == session.get("decks").size(), "New seat must start with clear filters")
	screen.call("_on_back")
	_check(screen.get("_seat") == 0 and not session.get("locked")[0], "Back must reopen the first selection")
	_check(seat.deck == session.get("decks")[0], "Back must restore the first deck")
	screen.call("_pick", 0)
	await create_timer(0.6).timeout
	var mastery: Variant = session.get("library").defs.get(seat.deck.mastery_id)
	_check(seat.mastery_card.texture != null, "The selected Mastery must render")
	_check(seat.mastery_card.texture == screen.get("faces").face(mastery), "Rapid deck changes must leave the correct Mastery")
	_check(seat.mastery_card.size.x > 200, "Mastery must remain large at 720p")
	_check(seat.mastery_card.get_global_rect().intersects(seat.portrait.get_global_rect()), "Mastery must overlap the portrait edge")
	_check(seat.mastery_card.global_position.y > seat.aspect_title.get_global_rect().end.y, "Mastery must leave the identity readable")
	_check(seat.get_node("Row/Details").global_position.x < seat.global_position.x + 40, "Details belongs at the lower left")
	await _check_fixed_mastery(seat)
	seat.mastery_card.grab_focus()
	_check(seat.mastery_zoom.visible, "Keyboard focus must enlarge the Mastery")
	_check(root.get_visible_rect().encloses(seat.mastery_zoom.get_global_rect()), "Mastery enlargement must stay onscreen")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/select-mastery-focus720.png")
	seat.mastery_card.release_focus()
	_check(not seat.mastery_zoom.visible, "Leaving the card must dismiss its enlargement")
	seat.get_node("Row/Details").pressed.emit()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/select-details720.png")
	screen.queue_free()
	await process_frame
	var starter: Control = load("res://scenes/adventure/adventure_start.tscn").instantiate()
	root.add_child(starter)
	await create_timer(0.6).timeout
	await _check_fixed_mastery(starter.get("seat_panel"))
	print("Selection UI smoke: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)


func _check_fixed_mastery(seat: Variant) -> void:
	var original: String = seat.tagline_label.text
	seat.tagline_label.text = "Short description."
	for i in range(4):
		await process_frame
	var short_rect: Rect2 = seat.mastery_card.get_global_rect()
	seat.tagline_label.text = "A much longer description that wraps over several lines. ".repeat(20)
	for i in range(4):
		await process_frame
	_check(seat.mastery_card.get_global_rect().is_equal_approx(short_rect), "Description length must not resize or move Mastery")
	_check(seat.get_global_rect().encloses(short_rect), "Fixed Mastery must stay within its panel")
	seat.tagline_label.text = original
	for i in range(4):
		await process_frame
