extends Control
## Title screen. Hotseat goes straight to deck select; online hosts or joins first and moves to
## the select screen as a lobby once the two clients are connected.

@onready var adventure_button: Button = $Center/Column/Adventure
@onready var hotseat_button: Button = $Center/Column/Hotseat
@onready var vs_ai_button: Button = $Center/Column/VsAi
@onready var host_button: Button = $Center/Column/Host
@onready var address_edit: LineEdit = $Center/Column/JoinRow/Address
@onready var join_button: Button = $Center/Column/JoinRow/Join
@onready var quit_button: Button = $Center/Column/Quit
@onready var status_label: Label = $Center/Column/Status


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--server"):
		# The exported binary run as the duel server: no title, no window content.
		get_tree().change_scene_to_file.call_deferred("res://scenes/server.tscn")
		return
	theme = ZenithTheme.get_theme()
	Net.leave()
	adventure_button.pressed.connect(func() -> void: Session.go_to_adventure())
	hotseat_button.pressed.connect(func() -> void: _offline(-1))
	vs_ai_button.pressed.connect(func() -> void: _offline(1))
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	address_edit.text_submitted.connect(func(_t: String) -> void: _on_join())
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	Net.connected.connect(_on_connected)
	Net.connection_failed.connect(_on_failed)
	status_label.text = ""
	_dev_args()


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
	status_label.text = "Opening a room on the duel server…" if kind == "server" else "Opening a port…"
	var problem: String = await Net.host(kind)
	if problem != "":
		_set_buttons(true)
		status_label.text = problem
		return
	status_label.text = Net.hosting_text()


func _on_join() -> void:
	Session.leave_adventure()
	Session.ai_seat = -1
	_set_buttons(false)
	status_label.text = "Connecting to %s…" % address_edit.text.strip_edges()
	var problem: String = await Net.join(address_edit.text)
	if problem != "":
		_set_buttons(true)
		status_label.text = problem
		return


## Seated. A room's share code is copied for the player here; the select screen shows it too.
func _on_connected() -> void:
	print("join code: %s" % Net.join_code())
	if Net.room_code != "" and Net.local_player == 0:
		DisplayServer.clipboard_set(Net.room_code)
	Session.go_to_select()


func _on_failed(reason: String) -> void:
	_set_buttons(true)
	status_label.text = reason


func _set_buttons(on: bool) -> void:
	adventure_button.disabled = not on
	hotseat_button.disabled = not on
	vs_ai_button.disabled = not on
	host_button.disabled = not on
	join_button.disabled = not on


## `--dev-host` opens a plain LAN port with the rules in this process and `--dev-join=<address>`
## connects to one; `--dev-host-code` opens a room on the duel server and `--dev-join=<code>`
## joins it.
## `--dev-adventure=<starter_id>` abandons any saved run and starts a fresh one; `--dev-adventure`
## alone resumes the save, or opens the start screen when there is none. `--dev-stage=N` (only
## with `--dev-adventure=<id>`) sets the run's stage before going on. `--dev-adventure-duel` (only
## with `--dev-adventure=<id>`) duels the stage straight away instead of opening the stage screen.
## `--dev-screenshot=<png>` alone saves the title once drawn, then quits.
func _dev_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var online: bool = false
	var adventure: bool = false
	for arg in args:
		online = online or arg.begins_with("--dev-host") or arg.begins_with("--dev-join=")
		adventure = adventure or arg.begins_with("--dev-adventure")
		if arg == "--dev-host":
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
	if not online and not adventure:
		for arg in args:
			if arg.begins_with("--dev-screenshot="):
				var path: String = arg.get_slice("=", 1)
				await get_tree().create_timer(0.3).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(path)
				print("screenshot saved to %s" % path)
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
	if starter_id != "":
		Session.abandon_run()
		Session.start_run(starter_id)
		if stage >= 0 and Session.ladder != null:
			Session.run.stage = clampi(stage, 0, Session.ladder.size() - 1)
		if duel:
			Session.begin_stage()
			return
	Session.go_to_adventure()
