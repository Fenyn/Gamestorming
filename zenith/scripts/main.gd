extends Control
## Title screen. Hotseat goes straight to deck select; online hosts or joins first and moves to
## the select screen as a lobby once the two clients are connected.

@onready var hotseat_button: Button = $Center/Column/Hotseat
@onready var vs_ai_button: Button = $Center/Column/VsAi
@onready var host_button: Button = $Center/Column/Host
@onready var address_edit: LineEdit = $Center/Column/JoinRow/Address
@onready var join_button: Button = $Center/Column/JoinRow/Join
@onready var quit_button: Button = $Center/Column/Quit
@onready var status_label: Label = $Center/Column/Status


func _ready() -> void:
	theme = ZenithTheme.get_theme()
	Net.leave()
	hotseat_button.pressed.connect(func() -> void: _offline(-1))
	vs_ai_button.pressed.connect(func() -> void: _offline(1))
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	address_edit.text_submitted.connect(func(_t: String) -> void: _on_join())
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	Net.connected.connect(_on_connected)
	Net.connection_failed.connect(_on_failed)
	status_label.text = "%d card definitions · %d decks" % [Session.library.defs.size(), Session.decks.size()]
	_dev_args()


## Hotseat when `ai_seat` is -1, otherwise that seat is played by the AI.
func _offline(ai_seat: int) -> void:
	Session.ai_seat = ai_seat
	Session.go_to_select()


func _on_host() -> void:
	Session.ai_seat = -1
	var problem: String = Net.host()
	if problem != "":
		status_label.text = problem
		return
	_set_buttons(false)
	status_label.text = "Hosting on port %d. Waiting for the other player…" % Net.DEFAULT_PORT


func _on_join() -> void:
	Session.ai_seat = -1
	var problem: String = Net.join(address_edit.text)
	if problem != "":
		status_label.text = problem
		return
	_set_buttons(false)
	status_label.text = "Connecting to %s…" % address_edit.text


func _on_connected() -> void:
	Session.go_to_select()


func _on_failed(reason: String) -> void:
	_set_buttons(true)
	status_label.text = reason


func _set_buttons(on: bool) -> void:
	hotseat_button.disabled = not on
	vs_ai_button.disabled = not on
	host_button.disabled = not on
	join_button.disabled = not on


## `--dev-host` or `--dev-join=<address>` after `--` starts an online session without clicks.
func _dev_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--dev-host":
			_on_host()
		elif arg.begins_with("--dev-join="):
			address_edit.text = arg.get_slice("=", 1)
			_on_join()
