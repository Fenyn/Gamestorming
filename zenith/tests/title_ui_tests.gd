extends SceneTree
## The title's online half, the queue lobby's lock-in line and the matchup line: each title state
## shows exactly its own nodes, the column keeps one height in every state, and the wording as
## shipped. Run with --headless --path zenith -s tests/title_ui_tests.gd.

const REJOIN_PATH: String = "user://title_ui_tests/rejoin.json"

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


## Which of the online slot's children and rows show, and which controls take input, as one string
## per state so a failure prints the whole picture.
func _shown(title: Node) -> String:
	var parts: Array[String] = []
	for key: String in ["idle_box", "search_box", "rejoin_box", "rejoin_row", "confirm_row"]:
		if (title.get(key) as Control).visible:
			parts.append(key)
	for key: String in ["adventure_button", "vs_ai_button", "hotseat_button", "find_button", "ranked_button", "host_button", "join_button", "quit_button"]:
		if not (title.get(key) as Button).disabled:
			parts.append(key)
	if (title.get("address_edit") as LineEdit).editable:
		parts.append("address")
	return ",".join(parts)


func _column_height(title: Node) -> float:
	var column: Control = title.get("column")
	return column.get_combined_minimum_size().y


func _run() -> void:
	var net: Node = root.get_node("Net")
	RejoinFile.path_override = REJOIN_PATH
	RejoinFile.clear()
	var title_script: Script = load("res://scripts/main.gd")
	var title: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(title)
	await process_frame
	var states: Dictionary = (title_script as GDScript).get_script_constant_map()["TitleState"]
	_check(not title.has_method("_process"), "The title counts on its Tick timer, not every frame")
	var status: Label = title.get("status_label")
	var heights: Dictionary = {}

	# IDLE
	_check(title.get("state") == states["IDLE"], "With nothing going on the title is idle")
	_check(_shown(title) == "idle_box,rejoin_row,adventure_button,vs_ai_button,hotseat_button,find_button,ranked_button,host_button,join_button,quit_button,address",
		"Idle shows Find a duel and Ranked match, everything enabled: %s" % _shown(title))
	_check(status.visible and status.text == "", "The status line is there and empty")
	heights["IDLE"] = _column_height(title)

	# CONNECTING (Host a duel on its way)
	title.set("_attempt", "host")
	title.call("_refresh")
	_check(title.get("state") == states["CONNECTING"], "An attempt under way is connecting")
	_check(_shown(title) == "search_box,rejoin_row,quit_button", "Connecting shows the search slot with Cancel and only Quit besides: %s" % _shown(title))
	_check((title.get("search_label") as Label).text == "Opening a room" and (title.get("elapsed_label") as Label).text == "",
		"Opening a room has no count")
	heights["CONNECTING"] = _column_height(title)
	title.call("_on_cancel")
	_check(title.get("state") == states["IDLE"] and status.text == "", "Cancel goes back to idle and says nothing")

	# SEARCHING, casual
	title_script.set_ranked_search(false)
	net.queue_state = "queued"
	net.queue_since = Time.get_ticks_msec() - 9000
	title.call("_refresh")
	_check(title.get("state") == states["SEARCHING"], "Queued is searching")
	_check(_shown(title) == "search_box,rejoin_row,quit_button", "Searching shows the search slot and only Quit besides: %s" % _shown(title))
	_check((title.get("search_label") as Label).text == "Looking for an opponent" and (title.get("elapsed_label") as Label).text == "0:09",
		"The casual search counts from the first join: %s" % (title.get("elapsed_label") as Label).text)
	_check((title.get("search_note") as Label).text == "", "Nobody-looking waits for 10 s in the casual queue")
	heights["SEARCHING"] = _column_height(title)
	net.queue_since = Time.get_ticks_msec() - 11000
	title.call("_refresh")
	_check((title.get("search_note") as Label).text == "Nobody else is looking right now.", "and says it after 10 s")
	_check(_column_height(title) == heights["SEARCHING"], "The note does not move the column")
	net.queue_changed.emit("queued", "The server is full. Still looking.")
	_check(status.text == "" and (title.get("search_note") as Label).text == "Nobody else is looking right now.",
		"A server line on the queue is not shown: %s" % status.text)
	net.queue_since = Time.get_ticks_msec() - 75000
	net.queue_changed.emit("requeued", "The other player left. Looking again.")
	_check(title.get("state") == states["SEARCHING"] and (title.get("elapsed_label") as Label).text == "1:15" and status.text == "",
		"A re-queue keeps the count from the first join and shows no notice")

	# SEARCHING, ranked
	title_script.set_ranked_search(true)
	net.queue_since = Time.get_ticks_msec() - 11000
	title.call("_refresh")
	_check((title.get("search_label") as Label).text == "Looking for a ranked opponent", "The ranked search says so")
	_check((title.get("search_note") as Label).text == "", "Nobody-looking waits for 90 s in the ranked queue")
	net.queue_since = Time.get_ticks_msec() - 91000
	title.call("_refresh")
	_check((title.get("search_note") as Label).text == "Nobody else is looking right now.", "and says it after 90 s")
	title.call("_on_cancel")
	_check(net.queue_state == "" and title.get("state") == states["IDLE"] and status.text == "", "Cancel leaves the queue silently")
	title_script.set_ranked_search(false)

	# REJOIN_OFFERED, from a real file
	var names: Array[String] = ["Ada", "Bram Ashmark"]
	var written: String = RejoinFile.write({"server": "127.0.0.1:7777", "code": "K7QMR", "seat": 0, "token": "ab".repeat(32),
		"names": names, "decks": ["x", "y"], "kind": "code", "expires": int(Time.get_unix_time_from_system()) + 150})
	_check(written == "", "The test rejoin file is written: %s" % written)
	title.call("_refresh")
	_check(title.get("state") == states["REJOIN_OFFERED"], "A good rejoin file offers the duel")
	_check(_shown(title) == "rejoin_box,rejoin_row,adventure_button,vs_ai_button,hotseat_button,quit_button",
		"The rejoin slot replaces Find a duel, and Host and Join wait: %s" % _shown(title))
	_check((title.get("rejoin_note") as Label).text == "Your duel against Bram Ashmark is still running.", "A share-code seat is a duel")
	heights["REJOIN_OFFERED"] = _column_height(title)
	RejoinFile.clear()
	title.call("_refresh")
	_check(title.get("state") == states["IDLE"], "The slot goes with the file")

	# The rejoin confirm, from a made-up ranked seat
	title.call("dev_fake_state", "rejoin-ranked")
	title_script.set_ranked_search(false)
	title.call("apply_state")
	_check((title.get("rejoin_note") as Label).text == "Your match against Bram Ashmark is still running.",
		"A seat whose file says ranked is a match, whatever this process last searched")
	_check((title.get("rejoin_button") as Button).theme_type_variation == &"AccentButton" and (title.get("concede_button") as Button).theme_type_variation == &"CompactButton",
		"Rejoin is the primary and Concede the quiet one")
	(title.get("concede_button") as Button).pressed.emit()
	_check(_shown(title).begins_with("rejoin_box,confirm_row,") and (title.get("confirm_question") as Label).text == "Concede the match?",
		"Concede asks inline first: %s" % _shown(title))
	_check(_column_height(title) == heights["REJOIN_OFFERED"], "The confirm does not move the column")
	(title.get("confirm_no") as Button).pressed.emit()
	_check(_shown(title).begins_with("rejoin_box,rejoin_row,"), "Cancel puts Rejoin and Concede back")
	title.call("dev_fake_state", "rejoin")
	_check((title.get("rejoin_note") as Label).text == "Your duel against Bram Ashmark is still running.", "A seat whose file says casual is a duel")
	title.set("_fake_ticket", {"names": ["You", "Bram Ashmark"], "seat": 0, "kind": "queue"})
	title_script.set_ranked_search(true)
	title.call("apply_state")
	_check((title.get("rejoin_note") as Label).text == "Your match against Bram Ashmark is still running.",
		"A file without the ranked field falls back to the queue this process last searched")
	title_script.set_ranked_search(false)
	title.call("apply_state")
	(title.get("concede_button") as Button).pressed.emit()
	_check((title.get("confirm_question") as Label).text == "Concede the duel?", "A casual seat asks about the duel")
	(title.get("confirm_yes") as Button).pressed.emit()
	_check(title.get("state") == states["IDLE"] and status.text == "", "Conceding forgets the seat and says nothing")

	# COOLDOWN
	net.cooldown_until_msec = Time.get_ticks_msec() + 299000
	title.call("_on_failed", "You can look for a duel again in 5 minutes.")
	_check(title.get("state") == states["COOLDOWN"], "A cooldown refusal lands in the cooldown state")
	_check(_shown(title) == "idle_box,rejoin_row,adventure_button,vs_ai_button,hotseat_button,host_button,join_button,quit_button,address",
		"On cooldown only the queue buttons wait; Host and Join stay open: %s" % _shown(title))
	_check(status.text == "You can queue again in 4:59." and status.theme_type_variation == &"WarnLabel",
		"The cooldown line replaces the server's: %s" % status.text)
	heights["COOLDOWN"] = _column_height(title)
	net.cooldown_until_msec = Time.get_ticks_msec() + 61000
	title.call("_refresh")
	_check(status.text == "You can queue again in 1:01.", "and counts down: %s" % status.text)
	_check(title_script.cooldown_text(299000) == "You can queue again in 4:59." and title_script.cooldown_text(500) == "You can queue again in 0:01.",
		"The cooldown rounds its seconds up")
	net.cooldown_until_msec = 0
	title.call("_refresh")
	_check(title.get("state") == states["IDLE"] and status.text == "", "At zero the title is idle again and the line clears")

	# Failures
	title.call("_on_failed", "This copy of the game speaks online version 8 and the duel server speaks version 9. Both need the same build of the game.")
	_check(status.text == "This copy of the game is out of date. Update it to play online." and status.theme_type_variation == &"WarnLabel",
		"A protocol refusal reads as an out-of-date copy: %s" % status.text)
	_check(_shown(title) == "idle_box,rejoin_row,adventure_button,vs_ai_button,hotseat_button,quit_button",
		"and every way online is shut: %s" % _shown(title))
	title.set("out_of_date", false)
	title.call("_on_failed", "Your cards or decks differ from those on the duel server. Both need the same build of the game.")
	_check(status.text == "This copy of the game is out of date. Update it to play online.", "and so does a data mismatch")
	title.call("_on_failed", "Could not reach the duel server. It may be offline, or this computer may not be connected.")
	_check(status.text.begins_with("Could not reach"), "Other reasons show as they came")
	title.call("_on_failed", "A reason long enough to need a third line on the status line, which holds two lines at most and cuts the rest off with an ellipsis so the column never grows.")
	_check(_column_height(title) == heights["IDLE"], "A long reason does not grow the column")

	# Rating
	net.rating_known.emit(138, false)
	var rating: Label = title.get("rating_label")
	_check(rating.visible and rating.text == "Rating 138", "The rating shows once known: %s" % rating.text)
	net.rating_known.emit(0, true)
	_check(rating.text == "Rating 0 (provisional)", "and says provisional: %s" % rating.text)

	var first: float = float(heights["IDLE"])
	for key: String in heights:
		_check(is_equal_approx(float(heights[key]), first), "The column is %.0f high in %s and %.0f idle" % [float(heights[key]), key, first])
	print("title column height per state: %s" % str(heights))
	title.free()
	net.queue_state = ""
	net.queue_since = 0

	_check_lobby()
	_check_matchup()
	RejoinFile.clear()
	RejoinFile.path_override = ""
	await process_frame
	print("Title UI tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


## The queue lobby's lock-in line beside Lock in, and the seat panel's online wording.
func _check_lobby() -> void:
	var select_script: Script = load("res://scripts/select/duelist_select.gd")
	_check(select_script.lock_text(42000) == "Lock in within 0:42.", "The lock-in line: %s" % select_script.lock_text(42000))
	_check(select_script.lock_text(9000) == "Lock in within 0:09 or you leave the queue.", "and in its last 10 s: %s" % select_script.lock_text(9000))
	_check(select_script.lock_text(10000) == "Lock in within 0:10.", "10 s left is not yet the warning")
	var seat: Node = load("res://scenes/select/select_seat.tscn").instantiate()
	root.add_child(seat)
	var lock: Button = seat.get("lock_button")
	var countdown: Label = seat.get("countdown_label")
	var name_edit: LineEdit = seat.get("name_edit")
	seat.call("set_locked", false)
	_check(lock.text == "Confirm champion" and name_edit.visible and not countdown.visible, "Offline the button confirms a champion and the name field stays")
	seat.call("set_online", true, false)
	_check(lock.text == "Lock in" and name_edit.visible and not countdown.visible, "A share-code room locks in and keeps the name field")
	seat.call("set_online", true, true)
	_check(lock.text == "Lock in" and not name_edit.visible and countdown.visible, "A queue room has no name field and shows the countdown")
	seat.call("set_countdown", select_script.lock_text(42000), false)
	_check(countdown.text == "Lock in within 0:42." and countdown.theme_type_variation == &"BodyLabel", "The countdown sits beside Lock in")
	seat.call("set_countdown", select_script.lock_text(9000), true)
	_check(countdown.theme_type_variation == &"WarnLabel", "and warns under 10 s")
	var details: Button = seat.get("details_button")
	_check(countdown.get_parent() == details.get_parent() and countdown.get_index() < details.get_index() and lock.get_parent().name == "Row",
		"The countdown sits left of Details, and Lock in keeps its own full-width row")
	seat.free()


func _check_matchup() -> void:
	var versus_script: Script = load("res://scripts/select/versus.gd")
	_check(versus_script.matchup_text(true, 1, 5000) == "Game 1 starts in 5 seconds.", "Ranked matchup: %s" % versus_script.matchup_text(true, 1, 5000))
	_check(versus_script.matchup_text(true, 2, 4100) == "Game 2 starts in 5 seconds.", "names the game of the match")
	_check(versus_script.matchup_text(false, 0, 5000) == "Starting in 5 seconds.", "Casual matchup: %s" % versus_script.matchup_text(false, 0, 5000))
	_check(versus_script.matchup_text(false, 0, 0) == "Starting in 1 second." and versus_script.matchup_text(false, 0, -300) == "Starting in 1 second.",
		"Nothing new shows at zero")
