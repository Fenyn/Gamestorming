extends Control
## Title screen. Hotseat goes straight to deck select; online hosts or joins first and moves to
## the select screen as a lobby once the two clients are connected. Find a duel and Ranked duel wait
## here, counting up, until the server pairs this client, and a client whose opponent left before the
## deal comes back here still waiting. The ranked rating shows beside Ranked duel once the server
## has sent it.

## The queue this client waits in is the ranked one. Static, so the title a finished duel or a
## re-queue loads still knows which queue it waits in.
static var ranked_search: bool = false

@onready var adventure_button: Button = $Center/Column/Adventure
@onready var hotseat_button: Button = $Center/Column/Hotseat
@onready var vs_ai_button: Button = $Center/Column/VsAi
@onready var find_button: Button = $Center/Column/FindDuel
@onready var ranked_button: Button = $Center/Column/RankedRow/Ranked
@onready var rating_label: Label = $Center/Column/RankedRow/Rating
@onready var host_button: Button = $Center/Column/Host
@onready var address_edit: LineEdit = $Center/Column/JoinRow/Address
@onready var join_button: Button = $Center/Column/JoinRow/Join
@onready var quit_button: Button = $Center/Column/Quit
@onready var status_label: Label = $Center/Column/StatusRow/Status
@onready var search_note: Label = $Center/Column/SearchNote
@onready var cancel_button: Button = $Center/Column/StatusRow/Cancel
@onready var rejoin_note: Label = $Center/Column/RejoinNote
@onready var rejoin_row: HBoxContainer = $Center/Column/RejoinRow
@onready var rejoin_button: Button = $Center/Column/RejoinRow/Rejoin
@onready var give_up_button: Button = $Center/Column/RejoinRow/GiveUp


func _ready() -> void:
	if DevArgs.user_args().has("--server"):
		# The exported binary run as the duel server: no title, no window content.
		get_tree().change_scene_to_file.call_deferred("res://scenes/server.tscn")
		return
	theme = SanctumUI.theme()
	# Back at the title no run is live, so no screen shows a school edge.
	MapArt.tint_for_school("")
	_dress()
	# A player sent back into the queue lands here still connected and waiting.
	if Net.queue_state != "queued":
		Net.leave()
	adventure_button.pressed.connect(func() -> void: Session.go_to_adventure())
	hotseat_button.pressed.connect(func() -> void: _offline(-1))
	vs_ai_button.pressed.connect(func() -> void: _offline(1))
	find_button.pressed.connect(_on_find)
	ranked_button.pressed.connect(_on_find.bind(true))
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	address_edit.text_submitted.connect(func(_t: String) -> void: _on_join())
	cancel_button.pressed.connect(_on_cancel)
	rejoin_button.pressed.connect(_on_rejoin)
	give_up_button.pressed.connect(_on_give_up)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	Net.connected.connect(_on_connected)
	Net.connection_failed.connect(_on_failed)
	Net.rating_known.connect(_show_rating)
	if not Net.rating.is_empty():
		_show_rating(int(Net.rating["shown"]), bool(Net.rating["provisional"]))
	# Why the last online session ended, when a later screen sent the player back here.
	_say(Net.last_error, true)
	Net.last_error = ""
	_show_rejoin()
	if Net.queue_state == "queued":
		_set_buttons(false)
	_dev_args()


## While Find a duel or Ranked duel waits: how long, and under it the server's word on the wait, or
## after QUEUE_NOTICE_MS that nobody else is looking.
func _process(_delta: float) -> void:
	if Net.queue_state != "queued":
		return
	var waited: int = floori(maxi(0, Time.get_ticks_msec() - Net.queue_since) / 1000.0)
	var who: String = "a ranked opponent" if ranked_search else "an opponent"
	_say("Looking for %s  %d:%02d" % [who, floori(waited / 60.0), waited % 60])
	var line: String = Net.queue_reason
	if waited * 1000 >= Net.QUEUE_NOTICE_MS and line != Net.QUEUE_FULL:
		line = Net.QUEUE_NOBODY
	search_note.text = line
	search_note.visible = line != ""


## The line under the menu: progress in the muted style, a reason something failed in the warning one.
func _say(text: String, warn: bool = false) -> void:
	status_label.text = text
	status_label.theme_type_variation = &"WarnLabel" if warn else &"MutedLabel"


## Filigree around the menu: a crest over the name and a swirl under the tagline.
func _dress() -> void:
	var column: VBoxContainer = $Center/Column
	var crest: TextureRect = MapArt.ornament("crest", 34.0)
	column.add_child(crest)
	column.move_child(crest, $Center/Column/Title.get_index())
	var swirl: TextureRect = MapArt.ornament("swirl", 26.0)
	column.add_child(swirl)
	column.move_child(swirl, $Center/Column/Sub.get_index() + 1)


## Hotseat when `ai_seat` is -1, otherwise that seat is played by the AI.
func _offline(ai_seat: int) -> void:
	Session.leave_adventure()
	Session.ai_seat = ai_seat
	Session.go_to_select()


## `kind` is "server" (a room on the duel server, with a share code) or "lan" (a plain port
## with the rules in this process, for dev runs).
func _on_host(kind: String = "server") -> void:
	Session.leave_adventure()
	Session.ai_seat = -1
	_set_buttons(false)
	_say("Opening a room on the duel server…" if kind == "server" else "Opening a port…")
	var problem: String = await Net.host(kind)
	if problem != "":
		_set_buttons(true)
		_say(problem, true)
		return
	if kind == "lan":
		_say(Net.hosting_text())


func _on_join() -> void:
	if join_button.disabled:
		return
	var code: String = address_edit.text.strip_edges()
	var refused: String = Net.code_problem(code)
	if refused != "":
		_say(refused, true)
		return
	Session.leave_adventure()
	Session.ai_seat = -1
	_set_buttons(false)
	if LanTransport.looks_like_address(code):
		_say("Connecting to %s…" % code)
	else:
		_say("Joining room %s…" % code.to_upper())
	var problem: String = await Net.join(code)
	if problem != "":
		_set_buttons(true)
		_say(problem, true)
		return


## A finished duel's result sent this client back into a queue: which one, for the title it loads.
static func set_ranked_search(ranked: bool) -> void:
	ranked_search = ranked


## Find a duel, or Ranked duel when `ranked`. The wait shows on the status line from the server's
## first answer; a pairing loads the select screen from `Net`.
func _on_find(ranked: bool = false) -> void:
	Session.leave_adventure()
	Session.ai_seat = -1
	ranked_search = ranked
	_set_buttons(false)
	_say("Connecting to the duel server…")
	var problem: String = ""
	if ranked:
		problem = await Net.find_ranked()
	else:
		problem = await Net.find_duel()
	if problem != "":
		_set_buttons(true)
		_say(problem, true)


func _on_cancel() -> void:
	var searching: bool = Net.queue_state != ""
	Net.leave()
	_set_buttons(true)
	_say("Stopped looking." if searching else "Stopped connecting.")


## The ranked rating as the server last sent it, beside Ranked duel.
func _show_rating(shown: int, provisional: bool) -> void:
	rating_label.text = "Rating %d%s" % [shown, " · Provisional" if provisional else ""]
	rating_label.visible = true


## A duel on the server this client dropped out of: "Your duel against X is still running." with
## Rejoin and Give up while its rejoin file is inside its expiry. A file past it goes, and the
## status line says the duel ended.
func _show_rejoin() -> void:
	var ticket: Dictionary = RejoinFile.read()
	var live: bool = RejoinFile.live(ticket, int(Time.get_unix_time_from_system()))
	rejoin_note.visible = live
	rejoin_row.visible = live
	if ticket.is_empty():
		RejoinFile.clear()
		return
	var rival: String = str(ticket["names"][1 - int(ticket["seat"])])
	if live:
		rejoin_note.text = "Your duel against %s is still running." % rival
	else:
		RejoinFile.clear()
		_say("Your duel against %s has ended." % rival)


func _on_rejoin() -> void:
	if rejoin_button.disabled:
		return
	Session.leave_adventure()
	Session.ai_seat = -1
	_set_buttons(false)
	_say("Rejoining your duel…")
	var problem: String = await Net.rejoin()
	if problem != "":
		_set_buttons(true)
		_show_rejoin()
		_say(problem, true)


## Nothing is connected here, so this cannot concede: the seat is forgotten and the server ends
## the duel once the seat's time is gone.
func _on_give_up() -> void:
	var ticket: Dictionary = RejoinFile.read()
	Net.give_up()
	_show_rejoin()
	if not ticket.is_empty():
		_say("You gave up your duel against %s." % str(ticket["names"][1 - int(ticket["seat"])]))


## Seated. A room's share code is copied for the player here; the select screen shows it too.
func _on_connected() -> void:
	if OS.is_debug_build():
		print("join code: %s" % Net.join_code())
	if Net.room_code != "" and Net.local_player == 0:
		DisplayServer.clipboard_set(Net.room_code)
	Session.go_to_select()


func _on_failed(reason: String) -> void:
	_set_buttons(true)
	# A refused rejoin has already deleted the file, so the row goes; a server out of reach keeps it.
	_show_rejoin()
	_say(reason, true)
	Net.last_error = ""
	var shot: String = _dev_screenshot_path()
	if shot != "":
		_save_shot(shot)


## Everything but Quit waits while an online attempt is in flight; Cancel stands in for them.
func _set_buttons(on: bool) -> void:
	adventure_button.disabled = not on
	hotseat_button.disabled = not on
	vs_ai_button.disabled = not on
	find_button.disabled = not on
	ranked_button.disabled = not on
	host_button.disabled = not on
	join_button.disabled = not on
	rejoin_button.disabled = not on
	give_up_button.disabled = not on
	address_edit.editable = on
	cancel_button.visible = not on
	if on:
		search_note.visible = false


## `--dev-host` opens a plain LAN port with the rules in this process and `--dev-join=<address>`
## connects to one; `--dev-host-code` opens a room on the duel server and `--dev-join=<code>`
## joins it.
## `--dev-adventure=<starter_id>` abandons any saved run and starts a fresh one; `--dev-adventure`
## alone resumes the save, or opens the start screen when there is none. `--dev-stage=N` (only
## with `--dev-adventure=<id>`) sets the run's stage before going on. `--dev-adventure-duel` (only
## with `--dev-adventure=<id>`) duels the stage straight away instead of opening the stage screen.
## `--dev-scratch=<dir>` keeps all of it off the player's saves.
## `--dev-screenshot=<png>` alone saves the title once drawn, then quits. With an online flag the
## duel further on takes it, unless the attempt fails, when the title takes it with the reason.
## `--dev-cancel=N` presses Cancel N seconds into an online attempt. With a screenshot it saves
## `<png>_connecting.png` just before, and the screenshot itself once the connect timeout would
## have passed, so it also shows that no late failure lands.
## `--dev-rejoin` presses Rejoin when the title offers it (with `--dev-scratch=<dir>` for the
## rejoin file a dev client wrote there).
## `--dev-queue` presses Find a duel and `--dev-ranked` Ranked duel, which wins when both are given
## (`Net.find_duel()` also goes ranked under `--dev-ranked`). A client sent back into the queue
## returns here still waiting and does not press either again; with a screenshot it saves the
## waiting title 2 seconds in.
func _dev_args() -> void:
	var args: PackedStringArray = DevArgs.user_args()
	var online: bool = false
	var adventure: bool = false
	var requeued: bool = Net.queue_state == "queued"
	var ranked: bool = args.has("--dev-ranked")
	for arg in args:
		online = online or arg.begins_with("--dev-host") or arg.begins_with("--dev-join=") or arg == "--dev-queue" \
			or arg == "--dev-ranked" or (arg == "--dev-rejoin" and rejoin_row.visible)
		adventure = adventure or arg.begins_with("--dev-adventure")
		if arg == "--dev-rejoin" and rejoin_row.visible:
			_on_rejoin()
		elif arg == "--dev-ranked" and not requeued:
			_on_find(true)
		elif arg == "--dev-queue" and not requeued and not ranked:
			_on_find()
		elif arg == "--dev-host":
			_on_host("lan")
		elif arg == "--dev-host-code":
			_on_host("server")
		elif arg.begins_with("--dev-join="):
			address_edit.text = arg.get_slice("=", 1)
			_on_join()
	if adventure:
		# Deferred: a scene change fired straight from _ready() lands while the initial scene's
		# own node tree is still being built, the same reason the --server branch above defers.
		_dev_adventure.call_deferred(args)
	var shot: String = _dev_screenshot_path()
	if requeued and shot != "":
		await get_tree().create_timer(2.0).timeout
		_save_shot(shot)
		return
	for arg in args:
		if online and arg.begins_with("--dev-cancel="):
			await get_tree().create_timer(float(arg.get_slice("=", 1))).timeout
			if shot != "":
				await _save_shot(shot.get_basename() + "_connecting.png", false)
			_on_cancel()
			if shot != "":
				await get_tree().create_timer(Net.CONNECT_TIMEOUT_SECONDS + 1.0).timeout
				_save_shot(shot)
	if not online and not adventure and shot != "":
		await get_tree().create_timer(0.3).timeout
		_save_shot(shot)


func _dev_screenshot_path() -> String:
	for arg in DevArgs.user_args():
		if arg.begins_with("--dev-screenshot="):
			return arg.get_slice("=", 1)
	return ""


func _save_shot(path: String, then_quit: bool = true) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved to %s" % path)
	if then_quit:
		get_tree().quit()


func _dev_adventure(args: PackedStringArray) -> void:
	var starter_id: String = ""
	var stage: int = -1
	var duel: bool = false
	for arg in args:
		if arg.begins_with("--dev-adventure="):
			starter_id = arg.get_slice("=", 1)
		elif arg.begins_with("--dev-stage="):
			stage = int(arg.get_slice("=", 1))
		elif arg == "--dev-adventure-duel":
			duel = true
	if AdventureDev.flag("--dev-scratch=") != "":
		AdventureDev.use_scratch_saves()
	if starter_id != "":
		Session.abandon_run()
		Session.start_run(starter_id)
		if stage > 0 and Session.map != null:
			AdventureDev.walk(stage)
		if duel and Session.map != null and Session.run.walk_to_next_duel(Session.map):
			Session.begin_stage()
			return
	Session.go_to_adventure()
