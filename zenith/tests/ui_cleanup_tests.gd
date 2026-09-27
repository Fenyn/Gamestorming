extends SceneTree
## UID retention, immediate private-face removal, shared public status presentation, and the duel
## HUD's online presentation: the options menu, the result card in every state, the clocks, the
## rival's plate tab and the reconnect card.
const PLAYER_STATUS: Script = preload("res://scripts/duel/player_status.gd")
const TOOLS: Array[String] = ["Reduced motion", "Fullscreen"]
## Words the menu and the result card no longer use for a way out.
const RETIRED: Array[String] = ["Leave duel", "Leave match", "Title", "Give up", "Leave", "Save and quit to title"]
var checks: int = 0
var failures: int = 0
var redraws: int = 0
var emitted: Array[StringName] = []
## Loaded rather than named, since this script compiles before the autoloads the HUD reads exist.
var hud_script: Script = null
var readout_script: Script = null

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

## Per-battle seat colours: the same seed repeats, Player 1 never moves, and the two seats stay
## far enough apart to tell at a glance even when both picked the same style.
func _check_seat_colors() -> void:
	var seed_value: int = 4242
	var pair: Array[Color] = SeatColors.roll(["root", "tide"], seed_value)
	_check(pair == SeatColors.roll(["root", "tide"], seed_value), "A seat colour seed must repeat, or two clients draw different colours")
	_check(SeatColors.roll(["root", "root"], seed_value)[0] == SeatColors.roll(["root", "pyre"], seed_value)[0],
		"Player 1's colour must not move when the other seat changes its style")
	_check(SeatColors.arc(pair[0].h * 360.0, pair[1].h * 360.0) >= SeatColors.APART_DEGREES - 0.1,
		"Two styles on separate hues must end up at least 45 degrees apart")
	for s in [7, 99, 4242, 123456]:
		var same: Array[Color] = SeatColors.roll(["root", "root"], s)
		_check(SeatColors.arc(same[0].h * 360.0, same[1].h * 360.0) >= SeatColors.SAME_STYLE_DEGREES - 0.1,
			"Two seats on one style must still be pulled apart on the wheel (seed %d)" % s)
		_check(absf(same[0].v - same[1].v) >= SeatColors.SAME_STYLE_VALUE - 0.01,
			"Two seats on one style must also split their brightness (seed %d)" % s)


# --- Helpers ----------------------------------------------------------------

func _mode(name: String) -> int:
	return int(hud_script.get_script_constant_map()["Mode"][name])


func _state(name: String) -> int:
	return int(hud_script.get_script_constant_map()["ResultState"][name])


## A HUD in `mode` whose every way out is recorded in `emitted`.
func _hud(mode: String = "LOCAL", can_rematch: bool = true, clocked: bool = false) -> Node:
	var hud: Node = load("res://scenes/duel/hud.tscn").instantiate()
	root.add_child(hud)
	hud.set_loading(false)
	for pair: Array in [["concede_requested", &"concede"], ["concede_match_requested", &"concede_match"], ["rematch_requested", &"rematch"],
			["leave_requested", &"leave"], ["select_requested", &"select"], ["title_requested", &"title"], ["find_requested", &"find"],
			["ranked_requested", &"ranked"], ["next_game_requested", &"next"], ["give_up_requested", &"give_up"]]:
		var tag: StringName = pair[1]
		hud.connect(str(pair[0]), func() -> void: emitted.append(tag))
	hud.set_mode(_mode(mode), can_rematch, clocked)
	emitted.clear()
	return hud


## A clocked HUD holding the viewer's own decision, as the table leaves it once the panel is up.
func _clock_hud() -> Node:
	var hud: Node = _hud("CODE", true, true)
	hud._current_prompt = PromptView.new()
	hud.prompt_panel.show()
	return hud


func _facts(extra: Dictionary = {}) -> Dictionary:
	var facts: Dictionary = {"viewer": 0, "names": ["Ada", "Bryn"], "winner": 0, "reason": "survival", "game": 1, "wins": [0, 0], "best_of": 3}
	for key in extra:
		facts[key] = extra[key]
	return facts


func _menu_items(hud: Node) -> Array[String]:
	hud.set_options_open(true)
	var out: Array[String] = []
	for child in hud.menu_items.get_children():
		if child is Button and (child as Button).visible:
			out.append((child as Button).text)
	return out


## The result card's nodes that show, by name, with their words: {name: text}.
func _card(hud: Node) -> Dictionary:
	var out: Dictionary = {}
	if not hud.modal.visible or not hud.game_over.visible:
		return out
	for path: String in ["Title", "Body", "Rating", "Note", "Ready", "Primary", "Actions/Rematch", "Actions/Leave"]:
		var node: Control = hud.game_over.get_node(path)
		# The note keeps an empty line in the states that can say one; an empty line says nothing.
		if node.is_visible_in_tree() and not (node is Label and (node as Label).text == ""):
			out[str(node.name)] = (node as Label).text if node is Label else (node as Button).text
	return out


func _no_retired(words: Array, where: String) -> void:
	for word in words:
		_check(not RETIRED.has(str(word)), "%s still says %s" % [where, str(word)])


# --- Options menu -------------------------------------------------------------

## The items each mode offers while a game runs and once a result is up, the confirm that stands
## in for them in each mode's words, and Esc.
func _check_options_menu() -> void:
	var offline: Node = _hud("LOCAL")
	_check(_menu_items(offline) == ["Resume", "Concede", "Rematch", "Back to title"] + TOOLS, "Hotseat and vs-AI menu: %s" % str(_menu_items(offline)))
	offline.menu_rematch.pressed.emit()
	_check(offline.menu_confirm.visible and offline.menu_question.text == "Abandon this duel and deal a new one?" and emitted.is_empty(),
		"A rematch mid-duel asks first: %s" % offline.menu_question.text)
	_check(offline.menu_yes.theme_type_variation == &"CompactButton" and offline.menu_no.theme_type_variation == &"CompactButton"
		and offline.menu_no.text == "Cancel", "The confirm's two buttons are quiet compact buttons")
	offline.menu_no.pressed.emit()
	_check(offline.menu_items.visible and not offline.menu_confirm.visible, "Cancel goes back to the items")
	offline.menu_concede.pressed.emit()
	_check(offline.menu_question.text == "Concede the duel?" and offline.menu_yes.text == "Concede", "Offline concede asks: %s" % offline.menu_question.text)
	offline.menu_no.pressed.emit()
	offline.menu_leave.pressed.emit()
	_check(offline.menu_question.text == "Abandon this duel and return to the title?" and offline.menu_yes.text == "Back to title",
		"Leaving a running offline duel asks: %s" % offline.menu_question.text)
	offline.apply_result(_state("RESULT"), _facts({"rules_text": "The rival's mind gives out."}))
	_check(_menu_items(offline) == ["Resume", "Back to title"] + TOOLS, "After a result the menu has Resume and Back to title only: %s" % str(_menu_items(offline)))
	offline.menu_leave.pressed.emit()
	_check(emitted == [&"leave"] and not offline.options_menu.visible, "After the result Back to title goes at once")
	_check_escape(offline)
	offline.free()
	var adventure: Node = _hud("ADVENTURE", false)
	_check(_menu_items(adventure) == ["Resume", "Concede", "Back to title"] + TOOLS, "Adventure menu: %s" % str(_menu_items(adventure)))
	adventure.menu_concede.pressed.emit()
	_check(adventure.menu_question.text == "Conceding ends the run." and adventure.menu_yes.text == "Concede", "Adventure concede warns that the run ends")
	adventure.menu_yes.pressed.emit()
	_check(emitted == [&"concede"] and not adventure.options_menu.visible, "Confirming concedes and closes the menu")
	adventure.set_options_open(true)
	adventure.menu_leave.pressed.emit()
	_check(emitted == [&"concede", &"leave"], "An adventure's Back to title does not ask, the run is saved")
	adventure.free()
	var casual: Node = _hud("QUEUE", true, true)
	_check(_menu_items(casual) == ["Resume", "Concede"] + TOOLS, "A running online duel offers Concede and nothing that leaves for free: %s" % str(_menu_items(casual)))
	casual.menu_concede.pressed.emit()
	_check(casual.menu_question.text == "Concede the duel?", "Online concede asks: %s" % casual.menu_question.text)
	casual.apply_result(_state("RESULT"), _facts({"winner": 1, "reason": "concede"}))
	_check(_menu_items(casual) == ["Resume", "Back to title"] + TOOLS, "and after its result Back to title: %s" % str(_menu_items(casual)))
	casual.free()
	var joiner: Node = _hud("CODE", false, false)
	_check(_menu_items(joiner) == ["Resume", "Concede"] + TOOLS, "A LAN joiner's menu: %s" % str(_menu_items(joiner)))
	joiner.free()
	var ranked: Node = _hud("RANKED", false, true)
	ranked.apply_result(_state("NONE"), _facts({"game": 2, "wins": [1, 0]}))
	var items: Array[String] = _menu_items(ranked)
	_check(items == ["Resume", "Concede game", "Concede match"] + TOOLS, "The ranked menu concedes a game or the match: %s" % str(items))
	_no_retired(items, "The ranked menu")
	ranked.menu_concede.pressed.emit()
	_check(ranked.menu_question.text == "Concede game 2?" and ranked.menu_yes.text == "Concede", "Concede game names the game: %s" % ranked.menu_question.text)
	ranked.menu_yes.pressed.emit()
	_check(emitted == [&"concede"], "and concedes it")
	ranked.apply_result(_state("NONE"), _facts({"game": 2, "wins": [0, 1]}))
	ranked.set_options_open(true)
	ranked.menu_concede.pressed.emit()
	_check(ranked.menu_question.text == "Conceding this game ends the match.", "At match point it says the match ends: %s" % ranked.menu_question.text)
	ranked.menu_no.pressed.emit()
	ranked.menu_concede_match.pressed.emit()
	_check(ranked.menu_question.text == "Concede the match?" and ranked.menu_yes.text == "Concede", "Concede match asks: %s" % ranked.menu_question.text)
	ranked.menu_yes.pressed.emit()
	_check(emitted == [&"concede", &"concede_match"], "and concedes the match")
	ranked.apply_result(_state("BETWEEN"), _facts({"wins": [1, 0], "next_at": Time.get_ticks_msec() + 18000}))
	_check(_menu_items(ranked) == ["Resume", "Concede match"] + TOOLS, "Between games the menu can only concede the match: %s" % str(_menu_items(ranked)))
	ranked.apply_result(_state("MATCH"), _facts({"match": {"winner": 1, "wins": [0, 2], "reason": "survival", "shown_before": [120, 96], "shown_after": [102, 138]}}))
	_check(_menu_items(ranked) == ["Resume", "Back to title"] + TOOLS, "Once the match is decided, Resume and Back to title: %s" % str(_menu_items(ranked)))
	ranked.free()


func _check_escape(hud: Node) -> void:
	hud.set_options_open(false)
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	hud._unhandled_input(esc)
	_check(hud.options_menu.visible and hud.options_shade.visible and hud.options_shade.mouse_filter == Control.MOUSE_FILTER_STOP
		and hud.options_shade.color == ZenithTheme.SCRIM_LIGHT, "Esc opens the menu, and the shade under it takes the mouse")
	hud._unhandled_input(esc)
	_check(not hud.options_menu.visible and not hud.options_shade.visible, "Esc closes the menu")
	for overlay: Control in [hud.inspect, hud.tray, hud.pile]:
		overlay.visible = true
		hud._unhandled_input(esc)
		_check(not hud.options_menu.visible and overlay.visible == (overlay == hud.tray),
			"Esc closes %s first (a tray stays) and does not open the menu" % overlay.name)
		overlay.visible = false
	hud.set_options_open(true)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud.options_shade.gui_input.emit(click)
	_check(not hud.options_menu.visible, "A click outside the menu closes it")


# --- The result card ----------------------------------------------------------

## Every ResultState in every mode that reaches it shows exactly its nodes and its words, and each
## button asks the table for the right thing.
func _check_result_states() -> void:
	var now: int = Time.get_ticks_msec()
	var ranked: Node = _hud("RANKED", false, true)
	ranked.apply_result(_state("NONE"), _facts({"game": 1}))
	_check(not ranked.modal.visible and ranked.series_line.visible and ranked.series_line.text == "Game 1 of 3", "A game running shows no card and the chip: %s" % ranked.series_line.text)
	ranked.apply_result(_state("GAME_PENDING"), _facts({"winner": 0, "reason": "concede"}))
	_check(_card(ranked) == {"Title": "You win game 1", "Note": "Waiting for the result."} and not ranked.series_line.visible,
		"A ranked game's result waits for the match in one line: %s" % str(_card(ranked)))
	ranked.apply_result(_state("BETWEEN"), _facts({"winner": 1, "wins": [0, 1], "next_at": now + 17500}))
	_check(_card(ranked) == {"Title": "Bryn wins game 1", "Body": "Bryn leads 1-0.", "Note": "Game 2 starts in 18 seconds.", "Ready": "Ready"},
		"Between games: who won, the score, the count and Ready, nothing else: %s" % str(_card(ranked)))
	_no_retired(_card(ranked).values(), "The between-games card")
	ranked.ready_button.pressed.emit()
	_check(emitted == [&"next"] and ranked.ready_button.disabled and ranked.ready_button.text == "Ready", "Ready asks for the next game and disables itself, text unchanged")
	ranked.apply_result(_state("BETWEEN"), _facts({"winner": 0, "wins": [1, 0], "game": 1, "next_at": now + 5000, "ready": true}))
	_check(ranked.game_over_body.text == "You lead 1-0." and ranked.game_over_title.text == "You win game 1" and ranked.ready_button.disabled,
		"The viewer's own lead reads from their side: %s" % ranked.game_over_body.text)
	ranked.apply_result(_state("BETWEEN"), _facts({"winner": 1, "wins": [1, 1], "game": 2, "next_at": now - 400, "ready": true}))
	ranked._show_next_count()
	_check(ranked.game_over_body.text == "The match is tied 1-1." and ranked.game_over_note.text == "Game 3 starts in 1 second.",
		"A count past its deal keeps its last second rather than a new line: %s" % ranked.game_over_note.text)
	emitted.clear()
	ranked.apply_result(_state("MATCH"), _facts({"match": {"winner": 0, "wins": [2, 1], "reason": "concede_match", "shown_before": [96, 120], "shown_after": [138, 102]}}))
	_check(_card(ranked) == {"Title": "You win the match 2-1", "Body": "Bryn conceded.", "Rating": "Your rating rose by 42 to 138.",
		"Primary": "Find another ranked match", "Leave": "Back to title"}, "The match result: %s" % str(_card(ranked)))
	_check(ranked.primary_button.theme_type_variation == &"AccentButton" and ranked.primary_button.custom_minimum_size == Vector2(540, 60)
		and ranked.leave_button.custom_minimum_size == Vector2(264, 54) and ranked.game_over_rating.theme_type_variation == &"RatingLabel",
		"The primary is the 540 accent, Back to title the 264 secondary, the rating line its own variation")
	_check(not ranked.series_line.visible, "The chip goes under the match result")
	ranked.primary_button.pressed.emit()
	ranked.leave_button.pressed.emit()
	_check(emitted == [&"ranked", &"title"], "Find another ranked match and Back to title ask for those: %s" % str(emitted))
	ranked.apply_result(_state("MATCH"), _facts({"match": {"winner": 1, "wins": [0, 2], "reason": "timeout", "shown_before": [120, 96], "shown_after": [102, 138]}}))
	_check(ranked.game_over_title.text == "You lose the match 0-2" and ranked.game_over_body.text == "You ran out of time." and ranked.game_over_rating.text == "Your rating fell by 18 to 102.",
		"A loss on the clock: %s / %s / %s" % [ranked.game_over_title.text, ranked.game_over_body.text, ranked.game_over_rating.text])
	ranked.apply_result(_state("MATCH"), _facts({"match": {"winner": -1, "wins": [1, 1], "reason": "abandoned", "shown_before": [120, 96], "shown_after": [120, 96]}}))
	_check(ranked.game_over_title.text == "No result" and ranked.game_over_rating.text == "Your rating is unchanged.", "No result: %s" % ranked.game_over_rating.text)
	ranked.apply_result(_state("MATCH"), _facts({"match": {"winner": 0, "wins": [2, 0], "reason": "seal", "shown_before": [96, 120], "shown_after": [138, 102]}}))
	_check(_card(ranked).keys() == ["Title", "Rating", "Primary", "Leave"], "A match won by the rules has no reason line: %s" % str(_card(ranked)))
	ranked.free()
	var sudden: Node = _hud("RANKED", false, true)
	sudden._current_prompt = PromptView.new()
	sudden.prompt_panel.show()
	sudden.apply_result(_state("NONE"), _facts({"game": 2, "wins": [1, 0]}))
	_check(sudden.series_line.text == "Game 2 of 3 · 1-0", "The chip reads the game and the score: %s" % sudden.series_line.text)
	sudden.apply_result(_state("NONE"), _facts({"viewer": 1, "game": 2, "wins": [1, 0]}))
	_check(sudden.series_line.text == "Game 2 of 3 · 0-1", "with the viewer's games first: %s" % sudden.series_line.text)
	sudden.apply_result(_state("MATCH"), _facts({"match": {"winner": 0, "wins": [2, 0], "reason": "concede_match", "shown_before": [96, 120], "shown_after": [138, 102]}}))
	_check(sudden.modal.visible and _card(sudden)["Title"] == "You win the match 2-0" and not sudden.prompt_panel.visible and not sudden.series_line.visible,
		"A match result with no game result before it covers the running game and takes the chip")
	sudden.free()
	_check(hud_script.series_text(1, 3, 0, 0) == "Game 1 of 3" and hud_script.series_text(3, 3, 1, 1) == "Game 3 of 3 · 1-1",
		"The chip leaves the score off before a game is won")
	var queue: Node = _hud("QUEUE", true, true)
	queue.apply_result(_state("RESULT"), _facts({"winner": 0, "reason": "concede"}))
	_check(_card(queue) == {"Title": "You win", "Body": "Bryn conceded.", "Primary": "Find another duel", "Rematch": "Rematch", "Leave": "Back to title"},
		"A casual queue result: %s" % str(_card(queue)))
	var width: Vector2 = queue.rematch_button.get_combined_minimum_size()
	queue.apply_result(_state("RESULT"), _facts({"winner": 0, "reason": "concede", "rival_asked": true}))
	_check(queue.rematch_button.text == "Accept rematch" and queue.rematch_button.get_combined_minimum_size() == width, "The rival's request relabels Rematch without resizing it")
	queue.primary_button.pressed.emit()
	queue.rematch_button.pressed.emit()
	queue.leave_button.pressed.emit()
	_check(emitted == [&"find", &"rematch", &"title"], "Find another duel, Rematch and Back to title: %s" % str(emitted))
	queue.apply_result(_state("RESULT"), _facts({"winner": 0, "reason": "concede", "rematch_sent": true}))
	_check(queue.rematch_button.disabled and queue.game_over_note.text == "Waiting for Bryn.", "An asked rematch waits in a sentence: %s" % queue.game_over_note.text)
	queue.apply_result(_state("RESULT"), _facts({"winner": 0, "reason": "left", "rival_gone": true, "gone_note": ""}))
	_check(_card(queue) == {"Title": "You win", "Body": "Bryn left.", "Primary": "Find another duel", "Leave": "Back to title"},
		"A rival who left takes Rematch with them: %s" % str(_card(queue)))
	queue.apply_result(_state("RESULT"), _facts({"winner": 1, "reason": "survival"}))
	_check(_card(queue).get("Title") == "You lose" and not _card(queue).has("Body"), "A rules loss has no reason line")
	queue.apply_result(_state("RESULT"), _facts({"winner": 1, "reason": "concede"}))
	_check(not _card(queue).has("Body"), "The viewer's own concession is not read back to them")
	queue.apply_result(_state("RESULT"), _facts({"winner": 0, "reason": "timeout"}))
	_check(queue.game_over_body.text == "Bryn ran out of time.", "A clock run out: %s" % queue.game_over_body.text)
	queue.free()
	var code: Node = _hud("CODE", true, true)
	code.apply_result(_state("RESULT"), _facts({"winner": 1, "reason": "survival"}))
	_check(_card(code) == {"Title": "You lose", "Rematch": "Rematch", "Leave": "Back to lobby"}, "A share-code result: %s" % str(_card(code)))
	code.leave_button.pressed.emit()
	_check(emitted == [&"select"], "Back to lobby asks for the lobby")
	code.apply_result(_state("RESULT"), _facts({"winner": 1, "reason": "survival", "rival_gone": true, "gone_note": "Bryn left."}))
	_check(_card(code) == {"Title": "You lose", "Note": "Bryn left.", "Leave": "Back to title"}, "and once the rival is gone, Back to title: %s" % str(_card(code)))
	code.free()
	var joiner: Node = _hud("CODE", false, false)
	joiner.apply_result(_state("RESULT"), _facts({"winner": 0, "reason": "survival"}))
	_check(_card(joiner) == {"Title": "You win", "Leave": "Back to title"}, "A LAN joiner leaves rematches to its host: %s" % str(_card(joiner)))
	joiner.free()
	var local: Node = _hud("LOCAL")
	local.apply_result(_state("RESULT"), _facts({"viewer": -1, "winner": 1, "reason": "seal", "rules_text": "All seven Seals carved."}))
	_check(_card(local) == {"Title": "Bryn wins", "Body": "All seven Seals carved.", "Primary": "Rematch", "Leave": "Choose duelists"},
		"Hotseat and vs AI keep who wins and their buttons: %s" % str(_card(local)))
	local.free()
	var adventure: Node = _hud("ADVENTURE", false)
	adventure.apply_result(_state("RESULT"), _facts({"winner": 0, "rules_text": "The rival's mind gives out."}))
	_check(_card(adventure) == {"Title": "Ada wins", "Body": "The rival's mind gives out.", "Primary": "Continue"}, "An adventure result: %s" % str(_card(adventure)))
	adventure.primary_button.pressed.emit()
	_check(emitted == [&"select"], "Continue goes on to the stage")
	adventure.free()
	var lost: Node = _hud("QUEUE", true, true)
	lost.apply_result(_state("LOST"), _facts({"text": "Could not get back into the duel in time."}))
	_check(_card(lost) == {"Title": "Connection lost", "Body": "Could not get back into the duel in time.", "Leave": "Back to title"}, "Connection lost: %s" % str(_card(lost)))
	_no_retired(_card(lost).values(), "The lost card")
	lost.free()


## The card is 612 wide with 540 of content, and a reason of any length wraps to two lines at most,
## so the card's size holds.
func _check_card_size() -> void:
	var hud: Node = _hud("QUEUE", true, true)
	hud.apply_result(_state("LOST"), _facts({"text": "The connection closed while the next game was being dealt, so this copy of the game went back to the title."}))
	await process_frame
	await process_frame
	var two: Vector2 = hud.result_card.size
	hud.apply_result(_state("LOST"), _facts({"text": "The duel server went away. ".repeat(12)}))
	await process_frame
	await process_frame
	var long: Vector2 = hud.result_card.size
	_check(hud.game_over_body.text.length() >= 300 and hud.game_over_body.get_line_count() > 2 and hud.game_over_body.get_visible_line_count() == 2,
		"A 300-character reason wraps and shows two lines: %d of %d" % [hud.game_over_body.get_visible_line_count(), hud.game_over_body.get_line_count()])
	_check(is_equal_approx(long.x, 612.0) and is_equal_approx(two.x, 612.0) and is_equal_approx(long.y, two.y), "The card holds its size: %s then %s" % [str(two), str(long)])
	hud.apply_result(_state("RESULT"), _facts({"winner": 0, "reason": "concede"}))
	await process_frame
	await process_frame
	var quiet: Rect2 = hud.result_card.get_global_rect()
	hud.apply_result(_state("RESULT"), _facts({"winner": 0, "reason": "concede", "rematch_sent": true}))
	await process_frame
	await process_frame
	_check(hud.game_over_note.text == "Waiting for Bryn." and hud.result_card.get_global_rect().is_equal_approx(quiet),
		"A note arriving later does not move the card: %s then %s" % [str(quiet), str(hud.result_card.get_global_rect())])
	hud.apply_result(_state("BETWEEN"), _facts({"winner": 0, "wins": [1, 0], "next_at": Time.get_ticks_msec() + 18000}))
	await process_frame
	var note: Rect2 = hud.game_over_note.get_global_rect()
	var column: Rect2 = hud.game_over.get_global_rect()
	_check(hud.game_over_note.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and is_equal_approx(note.position.x, column.position.x) and is_equal_approx(note.size.x, column.size.x),
		"The between-games count is centred across the card: %s in %s" % [str(note), str(column)])
	hud.free()


# --- Clocks and the plate tab -------------------------------------------------

## The decision clock: nothing offline or before the server sends a state, the timer and the bank
## in words, the warning and the fuse only in the last 10 s of both together, in a head row that
## keeps the panel still, and all of it gone with the result.
func _check_clock() -> void:
	var offline: Node = _hud("LOCAL")
	offline._current_prompt = PromptView.new()
	offline.prompt_panel.show()
	offline.set_clock(0, 25000, 60000, "run")
	offline._show_clock()
	_check(not offline.prompt_clock.visible and not offline.prompt_fuse.visible and not offline.prompt_head.visible,
		"Offline no clock state is taken and the head row is not kept")
	offline.free()
	var hud: Node = _clock_hud()
	hud._show_clock()
	var head: float = hud.prompt_head.get_combined_minimum_size().y
	_check(hud.prompt_head.visible and not hud.prompt_clock.visible and head > 30.0, "A clocked decision keeps its head row before the clock arrives: %.0f" % head)
	hud.set_clock(0, 23000, 70000, "run")
	hud._show_clock()
	_check(hud.prompt_clock.visible and hud.prompt_clock.text == "0:23 + bank 1:10" and hud.prompt_clock.theme_type_variation == &"ClockLabel" and not hud.prompt_fuse.visible,
		"The timer and the bank: %s" % hud.prompt_clock.text)
	_check(is_equal_approx(hud.prompt_head.get_combined_minimum_size().y, head), "and the head row does not grow")
	hud.set_clock(0, 8000, 60000, "warn")
	hud._show_clock()
	_check(hud.prompt_clock.text == "0:08 + bank 1:00" and not hud.prompt_fuse.visible, "The server's warning phase with a bank behind it is no warning: %s" % hud.prompt_clock.text)
	hud.set_clock(0, 0, 48000, "bank")
	hud._show_clock()
	_check(hud.prompt_clock.text == "Bank 0:48" and not hud.prompt_fuse.visible and hud.prompt_clock.theme_type_variation == &"ClockLabel", "On the bank: %s" % hud.prompt_clock.text)
	hud.set_clock(0, 0, 9000, "bank")
	hud._show_clock()
	_check(hud.prompt_clock.text == "You lose in 0:09." and hud.prompt_clock.theme_type_variation == &"ClockWarnLabel" and hud.prompt_fuse.visible
		and hud.prompt_fuse.theme_type_variation == &"FuseBar" and hud.prompt_fuse.value > 0.8 and hud.prompt_fuse.value <= 0.9,
		"Under 10 s in all it warns in a sentence and the fuse burns: %s %.2f" % [hud.prompt_clock.text, hud.prompt_fuse.value])
	_check(is_equal_approx(hud.prompt_head.get_combined_minimum_size().y, head), "and the fuse costs the panel nothing")
	hud.set_clock(0, 6000, 0, "warn")
	hud._show_clock()
	_check(hud.prompt_clock.text == "You lose in 0:06.", "A timer with no bank left warns too: %s" % hud.prompt_clock.text)
	hud.tray.visible = true
	hud._show_clock()
	_check(hud.tray_clock.visible and not hud.prompt_clock.visible and hud.tray_clock.text == "You lose in 0:06." and hud.tray_fuse.visible,
		"A decision in the tray carries the clock in its own head row")
	hud.tray.visible = false
	hud.apply_result(_state("RESULT"), _facts({"winner": 1, "reason": "timeout"}))
	hud.set_clock(0, 23000, 60000, "run")
	hud._show_clock()
	_check(not hud.prompt_clock.visible and not hud.prompt_fuse.visible and hud.clock_left_ms(0) == -1, "The result clears every clock and takes no more")
	hud.free()
	var rejoined: Node = _clock_hud()
	rejoined.set_clock(0, 20000, 14000, "run")
	rejoined.set_rejoined(true)
	_check(rejoined.prompt_hint.visible and rejoined.prompt_hint.text.ends_with("You have 0:34 left."), "After a rejoin the decision says how long it has: %s" % rejoined.prompt_hint.text)
	rejoined.show_sending()
	rejoined.set_rejoined(rejoined._rejoined)
	_check(not rejoined.prompt_hint.text.contains("You have"), "and stops once answered")
	rejoined.free()


## The rival's plate tab per PlateTab: nothing while they decide on their timer, the bank, their
## connection down, and the readout that draws it at one size clear of the base line.
func _check_plate_tab() -> void:
	var tabs: Dictionary = readout_script.get_script_constant_map()["PlateTab"]
	var hud: Node = _hud("CODE", true, true)
	_check(int(hud.plate_tab(1, -1)["tab"]) == int(tabs["NONE"]), "No clock, no tab")
	hud.set_clock(1, 23000, 60000, "run")
	_check(int(hud.plate_tab(1, -1)["tab"]) == int(tabs["NONE"]), "A rival deciding on their timer shows no tab, the panel says it")
	hud.set_clock(1, 0, 48000, "bank")
	_check(hud.plate_tab(1, -1) == {"tab": int(tabs["BANK"]), "text": "Time bank 0:48", "warn": false}, "On their bank: %s" % str(hud.plate_tab(1, -1)))
	hud.set_clock(1, 0, 8000, "bank")
	_check(bool(hud.plate_tab(1, -1)["warn"]), "which warns in its last 10 s")
	hud.set_clock(1, 30000, 60000, "run")
	_check(hud.plate_tab(1, 76000) == {"tab": int(tabs["AWAY"]), "text": "Disconnected 1:16", "warn": true}, "Their connection down: %s" % str(hud.plate_tab(1, 76000)))
	hud.set_clock(1, 0, 20000, "bank")
	_check(str(hud.plate_tab(1, 76000)["text"]) == "Disconnected 0:20", "counting the clock when it ends before their grace")
	_check(hud_script.away_line("Sable Draik", 76000) == "Sable Draik has 1:16 to come back.", "The panel's away line")
	hud.show_waiting("Bryn", &"declare", SeatView.new())
	_check(not hud.prompt_hint.visible, "A waiting panel has no hint")
	hud.set_rival_away(hud_script.away_line("Bryn", 76000))
	_check(hud.prompt_title.text == "Bryn has 1:16 to come back." and not hud.prompt_hint.visible,
		"While they are away the panel says how long they have, naming them once: %s" % hud.prompt_title.text)
	hud.set_rival_away("")
	_check(hud.prompt_title.text == "Waiting for Bryn" and not hud.prompt_hint.visible, "and waits on them again when they are back")
	hud.apply_result(_state("RESULT"), _facts({"winner": 0, "reason": "left"}))
	_check(int(hud.plate_tab(1, 76000)["tab"]) == int(tabs["NONE"]), "A result takes the tab down")
	hud.free()
	var unclocked: Node = _hud("CODE", false, false)
	_check(int(unclocked.plate_tab(1, 76000)["tab"]) == int(tabs["NONE"]), "A LAN duel has no tab")
	unclocked.free()
	var readout: Control = readout_script.new()
	root.add_child(readout)
	readout.set_tab(int(tabs["BANK"]), "Time bank 0:48", false)
	_check(readout.tab_kind() == int(tabs["BANK"]) and readout.tab_text() == "Time bank 0:48" and not readout.tab_warns(), "The plate keeps the tab it is given")
	readout.set_tab(int(tabs["AWAY"]), "Disconnected 1:16", true)
	_check(readout.tab_text() == "Disconnected 1:16" and readout.tab_warns(), "The away tab warns")
	readout.set_tab(int(tabs["NONE"]), "Time bank 0:48", true)
	_check(readout.tab_text() == "" and not readout.tab_warns(), "NONE clears it")
	var constants: Dictionary = readout_script.get_script_constant_map()
	var pad: Vector2 = constants["PLATE_PAD"]
	var tracker: Rect2 = Rect2(pad, constants["TRACKER_SIZE"])
	var tab: Rect2 = readout.tab_rect(tracker)
	var canvas: Vector2i = constants["PLATE_CANVAS"]
	_check(tab.size == Vector2(440, 54) and int(constants["TAB_FONT"]) == 44 and tab.position.y > tracker.position.y + 150.0 and tab.end.y <= canvas.y,
		"The tab is 440 wide at 44, under the base line and inside the plate: %s" % str(tab))
	readout.free()


# --- The reconnect card -------------------------------------------------------

func _check_reconnect() -> void:
	var hud: Node = _hud("QUEUE", true, true)
	var overlays: Dictionary = hud_script.get_script_constant_map()["Overlay"]
	hud.apply_result(_state("RESULT"), _facts({"winner": 0, "reason": "concede"}))
	hud.set_overlay(int(overlays["RECONNECTING"]), 89000)
	_check(hud.modal.visible and hud.reconnect.visible and not hud.game_over.visible, "The reconnect card takes the result card's place")
	_check(hud.get_node("Root/Modal/Center/Card/Reconnect/Title").text == "Connection lost" and hud.reconnect_status.text == "You lose if you are not back in 1:29."
		and hud.reconnect_give_up.text == "Concede", "It reads: %s" % hud.reconnect_status.text)
	hud.set_overlay(int(overlays["RECONNECTING"]), 88000)
	_check(hud.reconnect_status.text == "You lose if you are not back in 1:28.", "and counts down")
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	hud._unhandled_input(esc)
	_check(not hud.options_menu.visible, "Esc does not open the menu under it")
	hud.reconnect_give_up.pressed.emit()
	_check(hud.reconnect_confirm.visible and not hud.reconnect_give_up.visible and hud.reconnect_question.text == "Concede the duel?"
		and hud.reconnect_yes.text == "Concede" and hud.reconnect_no.text == "Keep trying" and emitted.is_empty(), "Concede asks first: %s" % hud.reconnect_question.text)
	hud.reconnect_no.pressed.emit()
	_check(not hud.reconnect_confirm.visible and hud.reconnect_give_up.visible, "Keep trying goes back")
	hud.reconnect_give_up.pressed.emit()
	hud.reconnect_yes.pressed.emit()
	_check(emitted == [&"give_up"], "and Concede gives up")
	hud.set_overlay(int(overlays["NONE"]))
	_check(hud.modal.visible and hud.game_over.visible and not hud.reconnect.visible, "The result comes back once the card goes")
	hud.free()
	var ranked: Node = _hud("RANKED", false, true)
	ranked.set_overlay(int(overlays["RECONNECTING"]), 60000)
	_check(ranked.reconnect_question.text == "Concede the match?" and ranked.modal.visible and not ranked.game_over.visible, "In a ranked match it concedes the match")
	ranked.free()


## Replay mode: the bar and the menu's speed and view rows exist only there and the menu drops
## Concede and Rematch; a recorded decision lists every option, lights the one taken and takes no
## clicks; the end reads on the panel; a record with another catalog hash is refused in words.
func _check_replay() -> void:
	var live: Node = _hud("LOCAL")
	_check(not live.replay_bar.visible and not live.menu_replay_speed.get_parent().visible and not live.menu_replay_view.get_parent().visible,
		"Outside a replay there is no replay bar and no speed or view in the menu")
	live.free()
	var hud: Node = _hud("LOCAL")
	var turns: Array[Dictionary] = [{"turn": 1, "player": 0, "index": 2}, {"turn": 2, "player": 1, "index": 9}]
	var names: Array[String] = ["Ada", "Bryn"]
	hud.set_match_replay(names, turns, 2)
	_check(hud.replay_bar.visible and hud.replay_turn.item_count == 2 and hud.replay_turn.get_item_id(1) == 9,
		"A replay shows the bar, with a turn list that jumps to each turn's first entry")
	_check(_menu_items(hud) == ["Resume", "Back to title"] + TOOLS and hud.menu_replay_speed.get_parent().visible and hud.menu_replay_view.get_parent().visible,
		"The replay menu holds Resume, speed, view and Back to title, no Concede: %s" % str(_menu_items(hud)))
	_check(hud.replay_view.get_item_text(0) == "Ada" and hud.replay_view.selected == 2 and hud.menu_replay_view.selected == 2,
		"The view switch names the players and starts on the view asked for")
	var commands: Array[Array] = []
	hud.replay_command.connect(func(action: StringName, value: int) -> void: commands.append([action, value]))
	hud.menu_replay_speed.item_selected.emit(2)
	_check(commands.size() == 1 and commands[0][0] == &"speed" and int(commands[0][1]) == 4 and hud.replay_speed.selected == 2,
		"The menu's speed and the bar's are one control: %s" % str(commands))
	emitted.clear()
	hud.menu_leave.pressed.emit()
	_check(emitted == [&"leave"], "Back to title leaves without asking")
	var chosen: Array[OptionView] = []
	hud.option_chosen.connect(func(opt: OptionView) -> void: chosen.append(opt))
	var p: PromptView = PromptView.new()
	p.player = 1
	p.kind = &"declare"
	p.title = "Declare Combat?"
	for type: StringName in [&"declare", &"skip"]:
		var o: OptionView = OptionView.new()
		o.type = type
		o.label = String(type).capitalize()
		p.options.append(o)
	hud.show_replay_decision(p, SeatView.new(), {"player": 1, "type": "skip", "card": -1, "value": null, "at": 5000}, "BRYN · DECISION", 3200)
	var rows: Array[Node] = hud.primary_box.get_children()
	var lit: Array[String] = []
	var takes_clicks: bool = false
	for row in rows:
		var b: Button = row
		b.pressed.emit()
		takes_clicks = takes_clicks or b.mouse_filter != Control.MOUSE_FILTER_IGNORE or b.focus_mode != Control.FOCUS_NONE
		if not b.disabled:
			lit.append(b.text)
	_check(rows.size() == 2 and lit == ["Skip"], "Every option is listed and only the one taken is lit: %s" % str(lit))
	_check(chosen.is_empty() and not takes_clicks, "The recorded decision takes no clicks and answers nothing")
	_check(hud.prompt_who.visible and hud.prompt_who.text == "BRYN · DECISION" and hud.prompt_hint.text == "Took 3.2 s",
		"It says whose decision it was and how long it took: %s" % hud.prompt_hint.text)
	hud.show_replay_result("Ada wins", "Bryn conceded.")
	_check(hud.prompt_panel.visible and hud.prompt_title.text == "Ada wins" and hud.prompt_hint.visible and hud.prompt_hint.text == "Bryn conceded."
		and not hud.modal.visible, "The end of a replay reads on the panel, a concession included, with the table still up")
	var record: MatchRecord = MatchRecord.load_file("res://tests/fixtures/match_records.jsonl")
	_check(record != null, "The fixture file gives its last record: %s" % MatchRecord.file_problem("res://tests/fixtures/match_records.jsonl"))
	if record != null:
		var net: Node = root.get_node("Net")
		var d: Dictionary = record.to_dict()
		d["protocol"] = int(net.get_script().get_script_constant_map()["PROTOCOL"])
		d["catalog"] = str(net.catalog_fingerprint())
		d["build"] = str(ProjectSettings.get_setting("application/config/version", ""))
		var same: MatchRecord = MatchRecord.from_dict(d)
		d["catalog"] = "0".repeat(64) if str(d["catalog"]) != "0".repeat(64) else "f".repeat(64)
		var other: MatchRecord = MatchRecord.from_dict(d)
		var script: Script = load("res://scripts/duel/duel_view.gd")
		_check(same != null and script.replay_refusal(same) == "", "A record from this build plays")
		var refusal: String = script.replay_refusal(other) if other != null else ""
		_check(refusal == "This replay was recorded on another version of the game.", "One with another catalog hash is refused: %s" % refusal)
		hud.show_replay_refused(refusal)
		_check(_card(hud) == {"Title": "Cannot play this replay", "Body": refusal, "Leave": "Back to title"},
			"and the refusal shows with only the way back to the title: %s" % str(_card(hud)))
	hud.free()


## A duel scene built after its result facts already reached Net (the signals went to the scene
## before) shows them from `_ready`: the match result over the between-games facts, and without a
## match, the game's result from `Net.last_duel_ended` as the between-games card.
func _check_scene_catch_up() -> void:
	var net: Node = root.get_node("Net")
	var session: Node = root.get_node("Session")
	session.chosen.assign([session.decks[0], session.decks[1 if session.decks.size() > 1 else 0]])
	session.player_names.assign(["Ada", "Bryn"])
	var now: int = Time.get_ticks_msec()
	var cases: Array[Dictionary] = [
		{"match": {"winner": 0, "wins": [2, 1], "reason": "concede_match", "rated": true, "shown_before": [96, 120], "shown_after": [138, 102],
			"provisional": [false, false], "rating_before": {"mu": 25.0, "sigma": 8.3}, "rating_after": {"mu": 27.6, "sigma": 8.1}},
			"game_over": {"game": 3, "wins": [1, 1], "next_in_s": 20, "at_msec": now}, "ended": {"winner": 0, "reason": "concede"},
			"state": "MATCH", "title": "You win the match 2-1", "body": "Bryn conceded."},
		{"match": {}, "game_over": {"game": 1, "wins": [0, 1], "next_in_s": 20, "at_msec": now + 20000}, "ended": {"winner": 1, "reason": "concede"},
			"state": "BETWEEN", "title": "Bryn wins game 1", "body": "Bryn leads 1-0."},
	]
	for case: Dictionary in cases:
		net.mode = "client"
		net._via_server = true
		net.room_code = "TESTR"
		net._room_kind = "queue"
		net._ranked = true
		net.local_player = 0
		net.series_game = 1
		net.series_wins.assign([0, 0])
		net.last_match = case["match"]
		net.last_game_over = case["game_over"]
		net.last_duel_ended = case["ended"]
		var duel: Node = load("res://scenes/duel/duel.tscn").instantiate()
		root.add_child(duel)
		var hud: Node = duel.get_node("Hud")
		var card: Dictionary = _card(hud)
		_check(int(hud._result) == _state(str(case["state"])) and card.get("Title", "") == case["title"] and card.get("Body", "") == case["body"],
			"A scene built after the facts shows %s from _ready: %s" % [case["state"], str(card)])
		_check(not hud.series_line.visible, "and no series chip under it")
		duel.queue_free()
		await process_frame
		await process_frame
		net.leave()


## The theme carries the variations the duel HUD names, and the HUD's scrims and chip use them.
func _check_theme() -> void:
	var theme: Theme = ZenithTheme.get_theme()
	for pair: Array in [["ClockLabel", "Label"], ["ClockWarnLabel", "Label"], ["ChipLabel", "Label"], ["RatingLabel", "Label"], ["FuseBar", "ProgressBar"]]:
		_check(theme.get_type_variation_base(StringName(pair[0])) == StringName(pair[1]), "%s is a %s variation" % [pair[0], pair[1]])
	_check(theme.get_font_size("font_size", "ClockLabel") == ZenithTheme.SIZE_ROW and theme.get_color("font_color", "ClockWarnLabel") == ZenithTheme.WARN
		and theme.get_font_size("font_size", "ChipLabel") == ZenithTheme.SIZE_CAPTION, "Clock at the row size, its warning in WARN, the chip at caption size")
	var hud: Node = _hud("RANKED", false, true)
	hud.apply_result(_state("NONE"), _facts({"game": 1}))
	await process_frame
	var short: float = hud.series_line.size.x
	hud.apply_result(_state("NONE"), _facts({"game": 3, "wins": [1, 1]}))
	await process_frame
	var chip: Rect2 = hud.series_line.get_rect()
	var gear: Rect2 = hud.options_button.get_rect()
	_check(hud.series_line.theme_type_variation == &"ChipLabel" and chip.size.x > short and is_equal_approx(chip.size.x, hud.series_line.get_combined_minimum_size().x)
		and is_equal_approx(gear.position.x - chip.end.x, 12.0), "The series chip fits its text and stays 12 px left of the gear: %s" % str(chip))
	_check(hud.modal.color == ZenithTheme.SCRIM and hud.tray.color == ZenithTheme.SCRIM and hud.inspect.color == ZenithTheme.SCRIM_STRONG and hud.loading.color == ZenithTheme.BG_SCREEN,
		"The scrims come from the tokens")
	hud.free()


func _run() -> void:
	hud_script = load("res://scripts/duel/duel_hud.gd")
	readout_script = load("res://scripts/duel/duelist_readout.gd")
	var session: Node = root.get_node("Session")
	var def: CardDef = session.library.defs.values()[0]
	var cache: CardFaceCache = CardFaceCache.new()
	var texture: ImageTexture = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	cache._cache[CardFaceCache.key_for(def, 1)] = texture
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	var hand: Node3D = load("res://scripts/duel/hand_3d.gd").new()
	camera.add_child(hand)
	hand.set_process(false)
	var view: SeatView = SeatView.new()
	var cards: Array[SeatCard] = []
	for uid in range(1, 4):
		var card: SeatCard = SeatCard.from_dict({"uid": uid, "def": def.id, "title": "Test card", "zone": "hand"})
		cards.append(card)
		view.cards[uid] = card
	hand.set_hand(cards, cache, {}, view)
	hand.preview_index(1)
	var original: Node3D = hand._items[1]["node"]
	var face: Sprite3D = hand._items[1]["face"]
	var pose: Transform3D = original.transform
	cards.reverse()
	view.forecasts[2] = {"stages": 7, "life": 0, "cost_stages": 2}
	hand.set_hand(cards, cache, {2: true}, view)
	_check(hand._items[1]["node"] == original and hand._items[1]["face"] == face, "Refresh must retain the actual node and face for a surviving UID")
	_check(original.transform.is_equal_approx(pose), "Refresh must not snap a surviving card's animated pose")
	_check(hand.revealed and hand.keyboard_active and hand._items[hand._hovered]["uid"] == 2, "Reordering must retain browsing and hover by UID")
	_check(hand._items[1]["legal"] and "7" in hand._items[1]["summary"].text and "Cost 2" in hand._items[1]["summary"].text, "Retained cards must receive updated legality and forecast captions")
	hand.remove_uid(3)
	_check(hand._items[hand._hovered]["uid"] == 2, "Removing a different card must retain the hovered UID")
	var hidden: SeatCard = SeatCard.from_dict({"uid": 2, "zone": "hand"})
	var masked: Array[SeatCard] = [hidden, cards[2]]
	hand.set_hand(masked, cache, {}, view)
	_check(not original.visible and original.is_queued_for_deletion(), "A newly hidden card must disappear synchronously before deferred deletion")
	_check(hand._hovered == -1 and hand._items.size() == 1, "Newly hidden cards must leave picking and hover state")
	hand.preview_index(0)
	var old_private: Node3D = hand._items[0]["node"]
	view.seat = 1
	hand.set_hand(masked, cache, {}, view)
	_check(not old_private.visible and hand._items[0]["node"] != old_private, "Changing viewer must discard the previous viewer's render nodes")
	_check(not hand.revealed and not hand.keyboard_active and hand._hovered == -1, "Changing viewer must reset private browsing state")
	var p: SeatPlayer = SeatPlayer.new()
	p.energy_blocked = true
	p.fervor_needed = 7
	p.fervor_gain = 0
	p.restrictions = ["mastery"]
	p.duelist = 1
	p.controlling = 1
	view.players = [p]
	var readout: Control = readout_script.new()
	root.add_child(readout)
	readout.reduced_motion = true
	readout.refresh(view, 0, 0)
	_check(readout._flags == PLAYER_STATUS.flags(p), "Field readout must use the same complete status formatter as inspection")
	_check("Needs 7 Fervor" in readout.status_text() and "Fervor gain x0" in readout.status_text() and "Cannot gain Energy" in readout.status_text(), "Changed thresholds, blocked gains and restrictions must remain available in full status")
	readout.redraw_requested.connect(func() -> void: redraws += 1)
	readout.card_bounds = readout.card_bounds
	readout.duelist_bounds = readout.duelist_bounds
	_check(redraws == 0, "Unchanged projected bounds must not redraw a paused resource viewport")
	readout.card_bounds = Rect2(10, 20, 100, 140)
	_check(redraws == 1, "Changed projected bounds must request a resource viewport redraw")
	_check_seat_colors()
	_check_options_menu()
	_check_result_states()
	await _check_card_size()
	_check_clock()
	_check_plate_tab()
	_check_reconnect()
	_check_replay()
	await _check_theme()
	await _check_scene_catch_up()
	var hud: Node = load("res://scenes/duel/hud.tscn").instantiate()
	_check(not hud.has_node("Root/TopPanel") and not hud.has_node("Root/BottomPanel"), "HUD must not instantiate hidden legacy player panels")
	hud.free()
	readout.free()
	camera.free()
	cache.free()
	await process_frame
	print("UI cleanup tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
