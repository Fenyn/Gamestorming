extends SceneTree
## UID retention, immediate private-face removal, and shared public status presentation.
const PLAYER_STATUS: Script = preload("res://scripts/duel/player_status.gd")
var checks: int = 0
var failures: int = 0
var redraws: int = 0
var menu_emitted: Array[StringName] = []

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


## The options menu: the items each mode offers, the confirm that stands in for them, and Esc
## opening it only while no inspect view, tray or pile browser is open. Hotseat and vs AI set the
## HUD up the same way, so one case covers both.
func _check_options_menu() -> void:
	var tools: Array[String] = ["Reduced motion", "Fullscreen"]
	var offline: Node = _menu_hud()
	_check(_menu_items(offline) == ["Resume", "Concede", "Rematch", "Back to title"] + tools, "Hotseat and vs-AI menu lists Resume, Concede, Rematch, Back to title")
	offline.menu_rematch.pressed.emit()
	_check(offline.menu_confirm.visible and not offline.menu_items.visible and menu_emitted.is_empty(), "A rematch mid-duel asks first")
	offline.menu_no.pressed.emit()
	_check(offline.menu_items.visible and not offline.menu_confirm.visible, "Cancel goes back to the items")
	offline.show_game_over("Player 1 wins", "", true)
	_check(_menu_items(offline) == ["Resume", "Rematch", "Back to title"] + tools, "Concede leaves the menu once the duel is over")
	offline.menu_rematch.pressed.emit()
	_check(menu_emitted == [&"rematch"] and not offline.options_menu.visible, "A rematch after the result goes at once")
	_check_escape(offline)
	offline.free()
	var adventure: Node = _menu_hud()
	adventure.set_adventure()
	adventure.set_options_open(true)
	_check(_menu_items(adventure) == ["Resume", "Concede", "Save and quit to title"] + tools, "Adventure menu has no Rematch or Back to title")
	adventure.menu_concede.pressed.emit()
	_check(adventure.menu_question.text == "Concede: this ends the run." and adventure.menu_yes.text == "Concede", "Adventure concede warns that the run ends")
	menu_emitted.clear()
	adventure.menu_yes.pressed.emit()
	_check(menu_emitted == [&"concede"] and not adventure.options_menu.visible, "Confirming concedes and closes the menu")
	adventure.menu_leave.pressed.emit()
	_check(menu_emitted == [&"concede", &"leave"], "Save and quit does not ask")
	adventure.free()
	var host: Node = _menu_hud()
	host.set_online(true)
	host.set_options_open(true)
	_check(_menu_items(host) == ["Resume", "Concede", "Rematch", "Leave duel"] + tools, "Online menu with a rematch available")
	host.menu_concede.pressed.emit()
	_check(host.menu_question.text == "Concede the duel.", "Online concede asks in its own words")
	host.drop_rematch("")
	host.set_options_open(true)
	_check(_menu_items(host) == ["Resume", "Concede", "Leave duel"] + tools, "Rematch goes once the other player has left")
	host.free()
	var joiner: Node = _menu_hud()
	joiner.set_online(false)
	joiner.set_options_open(true)
	_check(_menu_items(joiner) == ["Resume", "Concede", "Leave duel"] + tools, "Online menu without a rematch")
	joiner.free()


func _check_escape(hud: Node) -> void:
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	hud._unhandled_input(esc)
	_check(hud.options_menu.visible and hud.options_shade.visible and hud.options_shade.mouse_filter == Control.MOUSE_FILTER_STOP,
		"Esc opens the menu, and the shade under it takes the mouse")
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


## The decision clock: nothing until the server sends a state, never offline, the countdown on the
## deciding seat's own panel (the tray when that is up), warning orange with the fuse in the last
## 10 s and on the bank, the other seat's plate line, and all of it gone with the result.
func _check_clock() -> void:
	var offline: Node = _clock_hud()
	offline.set_clock(0, 25000, 60000, "run")
	offline._show_clock()
	_check(not offline.prompt_clock.visible and not offline.fuse.visible and offline.plate_clock(0, "Ada")["label"] == "",
		"Offline no clock state is taken and nothing about a clock shows")
	offline.free()
	var hud: Node = _clock_hud()
	hud.set_online(true)
	hud._show_clock()
	_check(not hud.prompt_clock.visible and not hud.fuse.visible, "Online, nothing shows before a clock state arrives")
	hud.set_clock(0, 25000, 60000, "run")
	hud._show_clock()
	_check(hud.prompt_clock.visible and hud.prompt_clock.text == "0:25" and not hud.fuse.visible, "A running clock counts down on the panel: %s" % hud.prompt_clock.text)
	hud.set_clock(0, 8000, 60000, "warn")
	hud._show_clock()
	_check(hud.prompt_clock.text == "0:08" and hud.fuse.visible and hud.prompt_clock.get_theme_color("font_color") == ZenithTheme.WARN,
		"The last 10 s turn it warning orange and light the fuse")
	hud.set_clock(0, 0, 48000, "bank")
	hud._show_clock()
	_check(hud.prompt_clock.text == "Time bank 0:48" and hud.fuse.visible, "On the bank it says so: %s" % hud.prompt_clock.text)
	hud.tray.visible = true
	hud._show_clock()
	_check(hud.tray_clock.visible and not hud.prompt_clock.visible and hud.tray_clock.text == "Time bank 0:48", "A decision in the tray carries the countdown there")
	hud.tray.visible = false
	_check(hud.plate_clock(1, "Bryn")["label"] == "", "The other seat's plate says nothing until its clock runs")
	hud.set_clock(1, 23000, 60000, "run")
	_check(hud.plate_clock(1, "Bryn") == {"label": "Bryn is deciding", "time": "0:23", "warn": false}, "Its plate reads who is deciding and the time")
	hud.set_clock(1, 0, 48000, "bank")
	_check(hud.plate_clock(1, "Bryn") == {"label": "Time bank", "time": "0:48", "warn": true}, "and then the bank")
	hud.show_game_over("Ada wins", "Bryn ran out of time.")
	hud._show_clock()
	hud.set_clock(1, 23000, 60000, "run")
	_check(not hud.prompt_clock.visible and not hud.fuse.visible and hud.plate_clock(1, "Bryn")["label"] == "", "The result clears every clock and takes no more")
	hud.free()
	var readout: Control = load("res://scripts/duel/duelist_readout.gd").new()
	readout.set_clock("Bryn is deciding", "0:23", false)
	_check(readout.clock_text() == "Bryn is deciding 0:23", "The plate keeps the line it is given")
	readout.set_clock("", "", false)
	_check(readout.clock_text() == "", "and drops it")
	readout.free()


## Reconnecting: the overlay covers the table with the seat's time left and Give up, and Esc does not
## open the menu under it; the result takes it away. The other seat's plate says who lost connection
## and how long they have, the time being their grace or their clock, whichever is shorter.
func _check_reconnect() -> void:
	var hud: Node = _clock_hud()
	hud.set_online(true)
	var gave_up: Array[bool] = [false]
	hud.give_up_requested.connect(func() -> void: gave_up[0] = true)
	_check(not hud.reconnect.visible, "Nothing about reconnecting shows while connected")
	hud.show_reconnecting(65000)
	_check(hud.reconnect.visible and hud.get_node("Root/Reconnect/Center/Column/Title").text == "Connection lost"
		and hud.reconnect_status.text == "Reconnecting 1:05", "The overlay reads Connection lost, Reconnecting 1:05: %s" % hud.reconnect_status.text)
	hud.show_reconnecting(64000)
	_check(hud.reconnect_status.text == "Reconnecting 1:04", "and counts down")
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	hud._unhandled_input(esc)
	_check(not hud.options_menu.visible, "Esc does not open the menu under the overlay")
	hud.reconnect_give_up.pressed.emit()
	_check(gave_up[0], "Give up asks the table to give up")
	hud.show_game_over("Connection lost", "Could not get back into the duel in time.")
	_check(not hud.reconnect.visible, "The result takes the overlay away")
	hud.free()
	var clocks: Node = _clock_hud()
	clocks.set_online(true)
	_check(clocks.clock_left_ms(1) == -1, "No clock, no time left to count")
	clocks.set_clock(1, 20000, 60000, "run")
	var total: int = clocks.clock_left_ms(1)
	clocks.set_clock(1, 0, 48000, "bank")
	var bank: int = clocks.clock_left_ms(1)
	_check(total > 79000 and total <= 80000 and bank > 47000 and bank <= 48000, "Time left is the timer and the bank together, then the bank alone: %d, %d" % [total, bank])
	var line: String = clocks.away_text("Bryn", 72000)
	clocks.free()
	_check(line == "Bryn lost connection. 1:12 to return.", "The away line: %s" % line)
	var readout: Control = load("res://scripts/duel/duelist_readout.gd").new()
	readout.set_clock("Bryn is deciding", "0:23", false)
	readout.set_away(line)
	_check(readout.away_text() == "Bryn lost connection. 1:12 to return." and readout.clock_text() == "Bryn is deciding 0:23",
		"The plate takes the away line beside its clock")
	readout.set_away("")
	_check(readout.away_text() == "", "and drops it when they are back")
	readout.free()


## Replay mode: the bar and the menu's speed and view rows exist only there and the menu drops
## Concede and Rematch; a recorded decision lists every option, lights the one taken and takes no
## clicks; the end reads on the panel; a record with another catalog hash is refused in words.
func _check_replay() -> void:
	var tools: Array[String] = ["Reduced motion", "Fullscreen"]
	var live: Node = _menu_hud()
	_check(not live.replay_bar.visible and not live.menu_replay_speed.get_parent().visible and not live.menu_replay_view.get_parent().visible,
		"Outside a replay there is no replay bar and no speed or view in the menu")
	live.free()
	var hud: Node = _menu_hud()
	var turns: Array[Dictionary] = [{"turn": 1, "player": 0, "index": 2}, {"turn": 2, "player": 1, "index": 9}]
	var names: Array[String] = ["Ada", "Bryn"]
	hud.set_match_replay(names, turns, 2)
	hud.set_options_open(true)
	_check(hud.replay_bar.visible and hud.replay_turn.item_count == 2 and hud.replay_turn.get_item_id(1) == 9,
		"A replay shows the bar, with a turn list that jumps to each turn's first entry")
	_check(_menu_items(hud) == ["Resume", "Back to title"] + tools and hud.menu_replay_speed.get_parent().visible and hud.menu_replay_view.get_parent().visible,
		"The replay menu holds Resume, speed, view and Back to title, no Concede: %s" % str(_menu_items(hud)))
	_check(hud.replay_view.get_item_text(0) == "Ada" and hud.replay_view.selected == 2 and hud.menu_replay_view.selected == 2,
		"The view switch names the players and starts on the view asked for")
	var commands: Array[Array] = []
	hud.replay_command.connect(func(action: StringName, value: int) -> void: commands.append([action, value]))
	hud.menu_replay_speed.item_selected.emit(2)
	_check(commands.size() == 1 and commands[0][0] == &"speed" and int(commands[0][1]) == 4 and hud.replay_speed.selected == 2,
		"The menu's speed and the bar's are one control: %s" % str(commands))
	menu_emitted.clear()
	hud.menu_leave.pressed.emit()
	_check(menu_emitted == [&"leave"], "Back to title leaves without asking")
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
		and not hud.game_over.visible, "The end of a replay reads on the panel, a concession included, with the table still up")
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
		_check(hud.game_over.visible and hud.game_over_reason.text == refusal and not hud.rematch_button.visible and hud.select_button.text == "Back to title",
			"and the refusal shows with only the way back to the title")
	hud.free()


## The result of a duel Find a duel paired offers Rematch, Find another duel and Title, in that
## order; Title stays when the other player leaves and Rematch goes. No other result has a Title.
func _check_queue_result() -> void:
	var room: Node = _menu_hud()
	room.set_online(true)
	room.show_game_over("Ada wins", "Bryn conceded.")
	_check(not room.title_button.visible and room.select_button.text == "Back to lobby", "A share-code room's result has no Title button")
	room.free()
	var hud: Node = _menu_hud()
	var titled: Array[bool] = [false]
	hud.title_requested.connect(func() -> void: titled[0] = true)
	hud.set_online(true)
	hud.set_queue_duel()
	hud.show_game_over("Ada wins", "Bryn conceded.")
	var shown: Array[String] = []
	for child in hud.get_node("Root/GameOver/Center/Column/Buttons").get_children():
		if child is Button and (child as Button).visible:
			shown.append((child as Button).text)
	_check(shown == ["Rematch", "Find another duel", "Title"], "A queue duel's result offers Rematch, Find another duel and Title: %s" % str(shown))
	_check(hud.title_button.custom_minimum_size == hud.select_button.custom_minimum_size and hud.title_button.theme_type_variation == hud.select_button.theme_type_variation,
		"Title is sized and styled like Find another duel")
	hud.title_button.pressed.emit()
	_check(titled[0], "Title asks the table to leave for the title")
	hud.drop_rematch("Bryn left.")
	_check(not hud.rematch_button.visible and hud.title_button.visible and hud.select_button.visible, "The other player leaving takes only Rematch away")
	hud.free()


## Ranked: the title's Ranked duel under Find a duel, the rating beside it only once the server has
## sent one, and the ranked searching line; the series line only in a ranked room; the menu that
## concedes a game and leaves the match; the between-games panel with its count and Next game; the
## match result with the rating line, Provisional and no Rematch.
func _check_ranked() -> void:
	var tools: Array[String] = ["Reduced motion", "Fullscreen"]
	var net: Node = root.get_node("Net")
	var title_script: Script = load("res://scripts/main.gd")
	# Loaded here rather than named, since this script compiles before the autoloads it reads exist.
	var hud_script: Script = load("res://scripts/duel/duel_hud.gd")
	var title: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(title)
	var row: Node = title.get_node("Center/Column/RankedRow")
	_check(row.get_index() == title.get_node("Center/Column/FindDuel").get_index() + 1 and (row.get_node("Ranked") as Button).text == "Ranked duel",
		"Ranked duel sits right under Find a duel")
	var rating: Label = row.get_node("Rating")
	_check(not rating.visible, "No rating shows before the server has sent one")
	net.rating_known.emit(138, false)
	_check(rating.visible and rating.text == "Rating 138", "The rating shows beside Ranked duel once known: %s" % rating.text)
	net.rating_known.emit(0, true)
	_check(rating.text == "Rating 0 · Provisional", "and says Provisional while the server does: %s" % rating.text)
	title_script.set_ranked_search(true)
	net.queue_state = "queued"
	net.queue_since = Time.get_ticks_msec()
	title._process(0.0)
	var status: Label = title.get_node("Center/Column/StatusRow/Status")
	_check(status.text == "Looking for a ranked opponent  0:00", "The ranked search counts in its own words: %s" % status.text)
	net.queue_state = ""
	net.queue_since = 0
	title_script.set_ranked_search(false)
	title.free()
	var casual: Node = _menu_hud()
	casual.set_online(false)
	casual.set_queue_duel()
	_check(not casual.series_line.visible, "Outside a ranked room there is no series line")
	casual.free()
	_check(hud_script.series_text(1, 3, 0, 0) == "Game 1 of 3" and hud_script.series_text(2, 3, 1, 0) == "Game 2 of 3 · 1-0",
		"The series reads the game and, once a game is won, the viewer's score first")
	var hud: Node = _menu_hud()
	var asked: Array[StringName] = []
	hud.next_game_requested.connect(func() -> void: asked.append(&"next"))
	hud.ranked_requested.connect(func() -> void: asked.append(&"ranked"))
	# Told it may rematch, a ranked HUD still offers none.
	hud.set_online(true)
	hud.set_ranked("Game 2 of 3 · 1-0")
	_check(hud.series_line.visible and hud.series_line.text == "Game 2 of 3 · 1-0" and hud.series_line.theme_type_variation == &"CompactButton",
		"A ranked room shows the series line in the quiet compact style")
	hud.set_options_open(true)
	_check(_menu_items(hud) == ["Resume", "Concede this game", "Leave match"] + tools, "The ranked menu concedes a game or leaves the match: %s" % str(_menu_items(hud)))
	hud.menu_concede.pressed.emit()
	_check(hud.menu_question.text == "Concede: this loses the game, not the match." and hud.menu_yes.text == "Concede", "Concede says it loses the game only")
	hud.menu_no.pressed.emit()
	menu_emitted.clear()
	hud.menu_leave.pressed.emit()
	_check(hud.menu_question.text == "Leave the match. This loses it." and menu_emitted.is_empty(), "Leave match asks first")
	hud.menu_yes.pressed.emit()
	_check(menu_emitted == [&"leave"], "and then leaves")
	hud.show_game_over("Ada wins", "Bryn conceded.")
	_check(_shown_buttons(hud).is_empty(), "A ranked game's result offers nothing, Rematch included, until the match says what follows: %s" % str(_shown_buttons(hud)))
	hud.show_between("Game 1 of 3 · 1-0", Time.get_ticks_msec() + 17500)
	_check(hud.game_over_series.visible and hud.game_over_series.text == "Game 1 of 3 · 1-0" and hud.game_over_title.text == "Ada wins"
		and hud.game_over_reason.text == "Bryn conceded." and hud.game_over_note.visible and hud.game_over_note.text == "Next game in 18",
		"Between games the result carries the score, who won and why, and the count: %s" % hud.game_over_note.text)
	_check(_shown_buttons(hud) == ["Next game"], "and only Next game: %s" % str(_shown_buttons(hud)))
	hud.set_options_open(true)
	_check(_menu_items(hud) == ["Resume", "Leave match"] + tools, "Between games the menu can still leave the match: %s" % str(_menu_items(hud)))
	hud.menu_leave.pressed.emit()
	_check(hud.menu_confirm.visible and hud.menu_question.text == "Leave the match. This loses it.", "and still asks")
	hud.set_options_open(false)
	hud.next_button.pressed.emit()
	_check(asked == [&"next"] and hud.next_button.disabled and hud.next_button.text == "Waiting for the other player",
		"Next game asks for the next game and then waits for the other player")
	hud.show_match_result(hud_script.match_title(0, 0, [2, 1]), "Bryn conceded.", hud_script.rating_change_text(112, 138, true, true))
	_check(hud.game_over_title.text == "You win the match 2-1" and hud.game_over_reason.text == "Bryn conceded." and hud.game_over_rating.visible
		and hud.game_over_rating.text == "Rating 112 → 138 · Provisional" and not hud.game_over_series.visible and not hud.game_over_note.visible,
		"The match result reads the match, the reason and the rating change: %s" % hud.game_over_rating.text)
	_check(_shown_buttons(hud) == ["Find another ranked duel", "Find a duel", "Title"], "and offers Find another ranked duel, Find a duel and Title, no Rematch: %s" % str(_shown_buttons(hud)))
	hud.ranked_button.pressed.emit()
	_check(asked == [&"next", &"ranked"], "Find another ranked duel asks the table for the ranked queue")
	hud.set_options_open(true)
	_check(_menu_items(hud) == ["Resume", "Leave duel"] + tools, "Once the match is decided the menu has no Leave match and no Rematch: %s" % str(_menu_items(hud)))
	hud.drop_series()
	_check(_shown_buttons(hud) == ["Find a duel"] and not hud.ranked_button.visible, "A lost connection keeps only the way out, which the table renames")
	hud.free()
	_check(hud_script.match_title(1, 0, [0, 2]) == "You lose the match 0-2" and hud_script.match_title(-1, 1, [1, 1]) == "No result"
		and hud_script.rating_change_text(138, 138, false, false) == "Rating 138, not rated" and hud_script.rating_change_text(112, 138, false, true) == "Rating 112 → 138",
		"The match title puts the viewer's games first, and an unrated match shows the rating as it stands")


func _shown_buttons(hud: Node) -> Array[String]:
	var shown: Array[String] = []
	for child in hud.get_node("Root/GameOver/Center/Column/Buttons").get_children():
		if child is Button and (child as Button).visible:
			shown.append((child as Button).text)
	return shown


## A HUD holding the viewer's own decision, as the table leaves it once the panel is up.
func _clock_hud() -> Node:
	var hud: Node = load("res://scenes/duel/hud.tscn").instantiate()
	root.add_child(hud)
	hud.set_loading(false)
	hud._current_prompt = PromptView.new()
	hud.prompt_panel.show()
	return hud


func _menu_hud() -> Node:
	var hud: Node = load("res://scenes/duel/hud.tscn").instantiate()
	root.add_child(hud)
	hud.set_loading(false)
	hud.concede_requested.connect(func() -> void: menu_emitted.append(&"concede"))
	hud.rematch_requested.connect(func() -> void: menu_emitted.append(&"rematch"))
	hud.leave_requested.connect(func() -> void: menu_emitted.append(&"leave"))
	hud.set_options_open(true)
	return hud


func _menu_items(hud: Node) -> Array[String]:
	var out: Array[String] = []
	var items: Node = hud.get("menu_items")
	for child in items.get_children():
		if child is Button and (child as Button).visible:
			out.append((child as Button).text)
	return out


func _run() -> void:
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
	var readout: Control = load("res://scripts/duel/duelist_readout.gd").new()
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
	_check_clock()
	_check_reconnect()
	_check_replay()
	_check_queue_result()
	_check_ranked()
	var hud: Node = load("res://scenes/duel/hud.tscn").instantiate()
	_check(not hud.has_node("Root/TopPanel") and not hud.has_node("Root/BottomPanel"), "HUD must not instantiate hidden legacy player panels")
	hud.free()
	readout.free()
	camera.free()
	cache.free()
	await process_frame
	print("UI cleanup tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
