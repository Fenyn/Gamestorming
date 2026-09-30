extends Control
## Title screen. Hotseat goes straight to deck select; online hosts or joins first and moves to
## the select screen as a lobby once the two clients are connected. Find a duel and Ranked match
## wait here, counting up, until the server pairs this client, and a client whose opponent left
## before the deal comes back here still waiting.
##
## The online half has one fixed slot under the ONLINE header that shows one thing at a time (the
## two queue buttons, the search with Cancel, or a running duel to rejoin or concede), and one
## fixed status line, so the column is the same height in every state. `state` is derived from Net
## and the rejoin file (`_derive`), and `apply_state` sets every node from it.

enum TitleState {IDLE, CONNECTING, SEARCHING, REJOIN_OFFERED, COOLDOWN}

## How long a casual search waits before it says nobody else is looking; ranked uses the server's
## own QUEUE_NOTICE_MS, since its window takes that long to open to everyone.
const NOTE_CASUAL_MS: int = 10000
const NOBODY_TEXT: String = "Nobody else is looking right now."
const VERSION_TEXT: String = "This copy of the game is out of date. Update it to play online."
## The failure reasons that mean this build and the duel server's differ.
const VERSION_MARKS: Array[String] = ["different version", "speaks online version", "Your cards or decks differ"]

## The queue this client waits in is the ranked one. Static, so the title a finished duel or a
## re-queue loads still knows which queue it waits in.
static var ranked_search: bool = false

@onready var background: ColorRect = $Background
@onready var tick: Timer = $Tick
@onready var title_label: Label = $Center/Column/Title
@onready var crest: TextureRect = $Center/Column/Crest
@onready var swirl: TextureRect = $Center/Column/Swirl
@onready var column: VBoxContainer = $Center/Column
@onready var adventure_button: Button = $Center/Column/Adventure
@onready var hotseat_button: Button = $Center/Column/Hotseat
@onready var vs_ai_button: Button = $Center/Column/VsAi
@onready var rating_label: Label = $Center/Column/OnlineHeader/Rating
@onready var idle_box: VBoxContainer = $Center/Column/OnlineSlot/Idle
@onready var find_button: Button = $Center/Column/OnlineSlot/Idle/FindDuel
@onready var ranked_button: Button = $Center/Column/OnlineSlot/Idle/Ranked
@onready var search_box: VBoxContainer = $Center/Column/OnlineSlot/Search
@onready var search_label: Label = $Center/Column/OnlineSlot/Search/Row/Label
@onready var elapsed_label: Label = $Center/Column/OnlineSlot/Search/Row/Elapsed
@onready var cancel_button: Button = $Center/Column/OnlineSlot/Search/Row/Cancel
@onready var search_note: Label = $Center/Column/OnlineSlot/Search/Note
@onready var rejoin_box: VBoxContainer = $Center/Column/OnlineSlot/Rejoin
@onready var rejoin_note: Label = $Center/Column/OnlineSlot/Rejoin/Note
@onready var rejoin_row: HBoxContainer = $Center/Column/OnlineSlot/Rejoin/Buttons
@onready var rejoin_button: Button = $Center/Column/OnlineSlot/Rejoin/Buttons/Rejoin
@onready var concede_button: Button = $Center/Column/OnlineSlot/Rejoin/Buttons/Concede
@onready var confirm_row: HBoxContainer = $Center/Column/OnlineSlot/Rejoin/Confirm
@onready var confirm_question: Label = $Center/Column/OnlineSlot/Rejoin/Confirm/Question
@onready var confirm_yes: Button = $Center/Column/OnlineSlot/Rejoin/Confirm/Yes
@onready var confirm_no: Button = $Center/Column/OnlineSlot/Rejoin/Confirm/No
@onready var host_button: Button = $Center/Column/Host
@onready var address_edit: LineEdit = $Center/Column/JoinRow/Address
@onready var join_button: Button = $Center/Column/JoinRow/Join
@onready var status_label: Label = $Center/Column/Status
@onready var quit_button: Button = $Center/Column/Quit

var state: TitleState = TitleState.IDLE
## The duel server refused this build as a different version. Every way online stays disabled on
## this title, since each attempt would be refused the same way; a title opened later tries again.
var out_of_date: bool = false
## The online attempt under way until Net answers: "find", "ranked", "host", "lan", "join" or
## "rejoin"; "" for none.
var _attempt: String = ""
## Bumped by every new attempt and every cancel, so a coroutine that returns late knows it is stale.
var _attempt_id: int = 0
## What Join was pressed with, for the search slot's line.
var _join_code: String = ""
## Ticks msec of the Find a duel or Ranked match press, 0 when this title pressed neither.
var _pressed_at: int = 0
## The Rejoin slot is asking whether to concede.
var _confirming: bool = false
var _status: String = ""
var _status_warn: bool = false
## A made-up rejoin ticket for `--dev-title-state=rejoin`; {} otherwise.
var _fake_ticket: Dictionary = {}


func _ready() -> void:
	if DevArgs.user_args().has("--server"):
		# The exported binary run as the duel server: no title, no window content.
		get_tree().change_scene_to_file.call_deferred("res://scenes/server.tscn")
		return
	theme = SanctumUI.theme()
	# Back at the title no run is live, so no screen shows a school edge.
	MapArt.tint_for_school("")
	background.color = ZenithTheme.BG_SCREEN
	title_label.add_theme_font_size_override("font_size", ZenithTheme.SIZE_DISPLAY)
	status_label.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
	crest.self_modulate = MapArt.tint
	swirl.self_modulate = MapArt.tint
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
	concede_button.pressed.connect(_on_concede)
	confirm_yes.pressed.connect(_on_concede_confirmed)
	confirm_no.pressed.connect(_on_concede_cancelled)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	tick.timeout.connect(_refresh)
	Net.connected.connect(_on_connected)
	Net.connection_failed.connect(_on_failed)
	Net.queue_changed.connect(_on_queue_changed)
	Net.rating_known.connect(_show_rating)
	if not Net.rating.is_empty():
		_show_rating(int(Net.rating["shown"]), bool(Net.rating["provisional"]))
	# Why the last online session ended, when a later screen sent the player back here.
	if Net.last_error != "":
		_show_failure(Net.last_error)
	else:
		_note_ended_duel()
	Net.last_error = ""
	_refresh()
	_dev_args()


func _exit_tree() -> void:
	for pair: Array in [[Net.connected, _on_connected], [Net.connection_failed, _on_failed],
			[Net.queue_changed, _on_queue_changed], [Net.rating_known, _show_rating]]:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)


## What the facts say the title is doing now.
func _derive() -> TitleState:
	if Net.queue_state == "queued":
		return TitleState.SEARCHING
	if _attempt != "":
		return TitleState.CONNECTING
	if not _rejoin_ticket().is_empty():
		return TitleState.REJOIN_OFFERED
	if Net.cooldown_left_ms() > 0:
		return TitleState.COOLDOWN
	return TitleState.IDLE


## Derives the state and shows it. The Tick timer calls this once a second, which moves the counts
## on and lets a cooldown or a rejoin file run out.
func _refresh() -> void:
	if not is_inside_tree():
		return
	var was: TitleState = state
	state = _derive()
	if was == TitleState.COOLDOWN and state == TitleState.IDLE:
		_set_status("", false)
	if state != TitleState.REJOIN_OFFERED:
		_confirming = false
	apply_state()


## Sets every node of the online half, and the buttons elsewhere that wait on it, from `state`.
func apply_state() -> void:
	var busy: bool = state == TitleState.CONNECTING or state == TitleState.SEARCHING
	var idle: bool = state == TitleState.IDLE
	# A leaver cooldown keeps this copy out of the queues only; a share-code room is still open.
	var rooms_open: bool = (idle or state == TitleState.COOLDOWN) and not out_of_date
	adventure_button.disabled = busy
	vs_ai_button.disabled = busy
	hotseat_button.disabled = busy
	idle_box.visible = idle or state == TitleState.COOLDOWN
	search_box.visible = busy
	rejoin_box.visible = state == TitleState.REJOIN_OFFERED
	find_button.disabled = not idle or out_of_date
	ranked_button.disabled = not idle or out_of_date
	host_button.disabled = not rooms_open
	join_button.disabled = not rooms_open
	address_edit.editable = rooms_open
	search_label.text = _search_text()
	elapsed_label.text = _elapsed_text()
	search_note.text = NOBODY_TEXT if _nobody_looking() else ""
	rejoin_button.disabled = out_of_date
	rejoin_row.visible = not _confirming
	confirm_row.visible = _confirming
	var ticket: Dictionary = _rejoin_ticket()
	if not ticket.is_empty():
		var what: String = "match" if _ticket_ranked(ticket) else "duel"
		rejoin_note.text = "Your %s against %s is still running." % [what, _rival(ticket)]
		confirm_question.text = "Concede the %s?" % what
	if state == TitleState.COOLDOWN:
		status_label.text = cooldown_text(Net.cooldown_left_ms())
		status_label.theme_type_variation = &"WarnLabel"
	else:
		status_label.text = _status
		status_label.theme_type_variation = &"WarnLabel" if _status_warn else &"MutedLabel"


## The status line: progress in the muted style, a reason something failed in the warning one.
func _set_status(text: String, warn: bool) -> void:
	_status = text
	_status_warn = warn


## A failure `reason` from Net on the status line; a version refusal also shuts the ways online.
func _show_failure(reason: String) -> void:
	var text: String = failure_text(reason)
	if text == VERSION_TEXT:
		out_of_date = true
	_set_status(text, true)


## "You can queue again in 4:59." for `left_ms` of cooldown, the seconds rounded up.
static func cooldown_text(left_ms: int) -> String:
	var seconds: int = ceili(maxi(0, left_ms) / 1000.0)
	return "You can queue again in %d:%02d." % [floori(seconds / 60.0), seconds % 60]


## The sentence the title shows for a failure `reason` from Net: a build mismatch in the player's
## words, a cooldown refusal as nothing (the cooldown line takes over), anything else as it came.
static func failure_text(reason: String) -> String:
	for mark in VERSION_MARKS:
		if reason.contains(mark):
			return VERSION_TEXT
	if Net.cooldown_left_ms() > 0:
		return ""
	return reason


## The search slot's line for the attempt under way.
func _search_text() -> String:
	var ranked_wait: bool = _attempt == "ranked" or (_attempt == "" and ranked_search)
	match _attempt:
		"host", "lan":
			return "Opening a room"
		"join":
			return ("Connecting to %s" if LanTransport.looks_like_address(_join_code) else "Joining room %s") % _join_code
		"rejoin":
			return "Rejoining your %s" % ("match" if _ticket_ranked(_rejoin_ticket()) else "duel")
	return "Looking for a ranked opponent" if ranked_wait else "Looking for an opponent"


## How long this client has looked, from the first join the server counted or this title's press,
## whichever is earlier; "" while no search is on.
func _elapsed_text() -> String:
	if state != TitleState.SEARCHING and not (_attempt == "find" or _attempt == "ranked"):
		return ""
	var waited: int = floori(_waited_ms() / 1000.0)
	return "%d:%02d" % [floori(waited / 60.0), waited % 60]


func _waited_ms() -> int:
	var since: int = 0
	for at: int in [Net.queue_since, _pressed_at]:
		if at != 0:
			since = at if since == 0 else mini(since, at)
	return maxi(0, Time.get_ticks_msec() - since) if since != 0 else 0


## Searching long enough that the player should hear nobody else is looking: 10 s in the casual
## queue, which pairs any two at once, 90 s in the ranked one, whose rating window opens that late.
func _nobody_looking() -> bool:
	if state != TitleState.SEARCHING:
		return false
	return _waited_ms() >= (Net.QUEUE_NOTICE_MS if ranked_search else NOTE_CASUAL_MS)


## Hotseat when `ai_seat` is -1, otherwise that seat is played by the AI.
func _offline(ai_seat: int) -> void:
	Session.leave_adventure()
	Session.ai_seat = ai_seat
	Session.go_to_select()


## Starts an online attempt of `kind`, returning its id for the coroutine to check on return.
func _begin(kind: String) -> int:
	Session.leave_adventure()
	Session.ai_seat = -1
	_attempt = kind
	_attempt_id += 1
	_set_status("", false)
	_refresh()
	return _attempt_id


## An attempt's coroutine came back with `problem` ("" when it is under way). A stale one, cancelled
## or superseded meanwhile, changes nothing.
func _returned(id: int, problem: String) -> void:
	if id != _attempt_id or problem == "" or not is_inside_tree():
		return
	_attempt = ""
	_show_failure(problem)
	_refresh()


## `kind` is "server" (a room on the duel server, with a share code) or "lan" (a plain port
## with the rules in this process, for dev runs).
func _on_host(kind: String = "server") -> void:
	var id: int = _begin("host" if kind == "server" else "lan")
	var problem: String = await Net.host(kind)
	_returned(id, problem)
	if problem == "" and kind == "lan" and id == _attempt_id and is_inside_tree():
		_set_status(Net.hosting_text(), false)
		apply_state()


func _on_join() -> void:
	if join_button.disabled:
		return
	var code: String = address_edit.text.strip_edges()
	var refused: String = Net.code_problem(code)
	if refused != "":
		_set_status(refused, true)
		apply_state()
		return
	_join_code = code if LanTransport.looks_like_address(code) else code.to_upper()
	var id: int = _begin("join")
	_returned(id, await Net.join(code))


## A finished duel's result sent this client back into a queue: which one, for the title it loads.
static func set_ranked_search(ranked: bool) -> void:
	ranked_search = ranked


## Find a duel, or Ranked match when `ranked`. The count starts at the press; a pairing loads the
## select screen from `Net`.
func _on_find(ranked: bool = false) -> void:
	ranked_search = ranked
	_pressed_at = Time.get_ticks_msec()
	var id: int = _begin("ranked" if ranked else "find")
	var problem: String = ""
	if ranked:
		problem = await Net.find_ranked()
	else:
		problem = await Net.find_duel()
	_returned(id, problem)


## Back to how the title was before the attempt, with nothing said.
func _on_cancel() -> void:
	Net.leave()
	_attempt = ""
	_attempt_id += 1
	_pressed_at = 0
	_set_status("", false)
	_refresh()


## The ranked rating as the server last sent it, right of the ONLINE header.
func _show_rating(shown: int, provisional: bool) -> void:
	if not is_inside_tree():
		return
	rating_label.text = rating_text(shown, provisional)
	rating_label.visible = true


static func rating_text(shown: int, provisional: bool) -> String:
	return "Rating %d%s" % [shown, " (provisional)" if provisional else ""]


## The rejoin ticket while it is good, {} otherwise.
func _rejoin_ticket() -> Dictionary:
	if not _fake_ticket.is_empty():
		return _fake_ticket
	var ticket: Dictionary = RejoinFile.read()
	return ticket if RejoinFile.live(ticket, int(Time.get_unix_time_from_system())) else {}


## A ranked match's ticket, from its `ranked` field. A file written before that field existed
## counts a queue seat as ranked when this process last searched the ranked queue.
func _ticket_ranked(ticket: Dictionary) -> bool:
	if ticket.is_empty():
		return false
	if ticket.has("ranked"):
		return bool(ticket["ranked"])
	return str(ticket.get("kind", "")) == "queue" and ranked_search


func _rival(ticket: Dictionary) -> String:
	return str(ticket["names"][1 - int(ticket["seat"])])


## A rejoin file past its expiry goes, and the status line says that duel is over.
func _note_ended_duel() -> void:
	var ticket: Dictionary = RejoinFile.read()
	if ticket.is_empty() or RejoinFile.live(ticket, int(Time.get_unix_time_from_system())):
		return
	RejoinFile.clear()
	_set_status("Your %s against %s has ended." % ["match" if _ticket_ranked(ticket) else "duel", _rival(ticket)], false)


func _on_rejoin() -> void:
	if rejoin_button.disabled or state != TitleState.REJOIN_OFFERED:
		return
	_confirming = false
	var id: int = _begin("rejoin")
	_returned(id, await Net.rejoin())


func _on_concede() -> void:
	_confirming = true
	apply_state()


## Nothing is connected here, so the concession goes on a connection of its own (`Net.give_up`),
## and the seat is forgotten at once.
func _on_concede_confirmed() -> void:
	Net.give_up()
	_fake_ticket = {}
	_confirming = false
	_refresh()


func _on_concede_cancelled() -> void:
	_confirming = false
	apply_state()


func _on_queue_changed(queue_state: String, _reason: String) -> void:
	if not is_inside_tree():
		return
	if queue_state == "queued":
		_set_status("", false)
	_refresh()


## Seated. A room's share code is copied for the player here; the select screen shows it too.
func _on_connected() -> void:
	if not is_inside_tree():
		return
	if OS.is_debug_build():
		print("join code: %s" % Net.join_code())
	if Net.room_code != "" and Net.local_player == 0:
		DisplayServer.clipboard_set(Net.room_code)
	Session.go_to_select()


func _on_failed(reason: String) -> void:
	if not is_inside_tree():
		return
	_attempt = ""
	_attempt_id += 1
	_pressed_at = 0
	_show_failure(reason)
	Net.last_error = ""
	_refresh()
	var shot: String = _dev_screenshot_path()
	if shot != "":
		_save_shot(shot)


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
## `--dev-queue` presses Find a duel and `--dev-ranked` Ranked match, which wins when both are
## given. A client sent back into the queue returns here still waiting and does not press either
## again; with a screenshot it saves the waiting title 2 seconds in.
## `--dev-title-state=<idle|search|search-ranked|rejoin|rejoin-ranked|cooldown|version>` fakes that
## state with made-up facts and nothing connected, for a screenshot.
func _dev_args() -> void:
	var args: PackedStringArray = DevArgs.user_args()
	var online: bool = false
	var adventure: bool = false
	var requeued: bool = Net.queue_state == "queued"
	var ranked: bool = args.has("--dev-ranked")
	var rejoinable: bool = state == TitleState.REJOIN_OFFERED
	for arg in args:
		online = online or arg.begins_with("--dev-host") or arg.begins_with("--dev-join=") or arg == "--dev-queue" \
			or arg == "--dev-ranked" or (arg == "--dev-rejoin" and rejoinable)
		adventure = adventure or arg.begins_with("--dev-adventure")
		if arg == "--dev-rejoin" and rejoinable:
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
		elif arg.begins_with("--dev-title-state="):
			dev_fake_state(arg.get_slice("=", 1))
	if adventure:
		# Deferred: a scene change fired straight from _ready() lands while the initial scene's
		# own node tree is still being built, the same reason the --server branch above defers.
		_dev_adventure.call_deferred(args)
	var shot: String = _dev_screenshot_path()
	if requeued and shot != "":
		await get_tree().create_timer(2.0).timeout
		if is_inside_tree():
			_save_shot(shot)
		return
	for arg in args:
		if online and arg.begins_with("--dev-cancel="):
			await get_tree().create_timer(float(arg.get_slice("=", 1))).timeout
			if not is_inside_tree():
				return
			if shot != "":
				await _save_shot(shot.get_basename() + "_connecting.png", false)
			_on_cancel()
			if shot != "":
				await get_tree().create_timer(Net.CONNECT_TIMEOUT_SECONDS + 1.0).timeout
				_save_shot(shot)
	if not online and not adventure and shot != "":
		await get_tree().create_timer(0.3).timeout
		_save_shot(shot)


## Puts the title in a named state from made-up facts, nothing connected. Searches read 0:42.
func dev_fake_state(which: String) -> void:
	var now: int = Time.get_ticks_msec()
	match which:
		"search", "search-ranked":
			ranked_search = which == "search-ranked"
			if ranked_search:
				_show_rating(138, true)
			Net.queue_state = "queued"
			Net.queue_since = now - 42000
		"rejoin", "rejoin-ranked":
			ranked_search = which == "rejoin-ranked"
			_fake_ticket = {"names": ["You", "Bram Ashmark"], "seat": 0, "kind": "queue", "ranked": ranked_search}
		"cooldown":
			Net.cooldown_until_msec = now + 299000
		"version":
			_show_failure(VERSION_TEXT)
	_refresh()


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
		if duel and Session.map != null and Session.run.walk_to_next_duel(Session.map, Session.library):
			Session.begin_stage()
			return
	Session.go_to_adventure()
