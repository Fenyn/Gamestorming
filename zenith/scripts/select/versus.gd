extends Control
## The matchup after both seats lock in: the two decks side by side, seed and AI level, and
## Start. Hotseat and vs AI start from here. Online, both clients arrive when both are locked,
## the host starts, and either side's Back sends both back to the select screen.

@onready var sheets: Array[DeckSheet] = [$Margin/Column/Sides/S0, $Margin/Column/Sides/S1]
@onready var faces: CardFaceCache = $CardFaceCache
@onready var status_label: Label = $Margin/Column/TitleRow/Status
@onready var seed_label: Label = $Margin/Column/Footer/SeedLabel
@onready var seed_edit: LineEdit = $Margin/Column/Footer/Seed
@onready var ai_label: Label = $Margin/Column/Footer/AiLabel
@onready var ai_level: OptionButton = $Margin/Column/Footer/AiLevel
@onready var problems_label: Label = $Margin/Column/Footer/Problems
@onready var start_button: Button = $Margin/Column/Footer/Start
@onready var back_button: Button = $Margin/Column/Footer/Back
@onready var vs_mark: Label = $VsMark

## Profile file names behind the AiLevel items, in item order.
const AI_LEVELS: Array[String] = ["easy", "default", "hard"]
const SLIDE: float = 360.0

var _online: bool = false
var _started: bool = false
var _leaving: bool = false


func _ready() -> void:
	theme = ZenithTheme.get_theme()
	_online = Net.active()
	_dev_setup()
	if not Session.can_start():
		Session.go_to_select()
		return
	seed_edit.text = str(Session.seed_value)
	seed_edit.text_changed.connect(func(t: String) -> void: Session.seed_value = int(t))
	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(_on_back)
	for i in range(2):
		sheets[i].setup(i, faces)
		sheets[i].show_deck(Session.chosen[i], _tag(i))
	if _online:
		seed_label.visible = Net.is_host()
		seed_edit.visible = Net.is_host()
		start_button.visible = Net.is_host()
		Net.lobby_changed.connect(_on_lobby_changed)
		Net.peer_left.connect(_on_peer_left)
		Net.connection_failed.connect(_on_connection_failed)
	elif Session.ai_seat >= 0:
		ai_label.visible = true
		ai_level.visible = true
		ai_level.select(maxi(0, AI_LEVELS.find(Session.ai_profile)))
		ai_level.item_selected.connect(func(i: int) -> void: Session.ai_profile = AI_LEVELS[i])
	_refresh()
	_enter()
	_dev_screenshot()


func _tag(seat: int) -> String:
	var who: String = "PLAYER %d" % (seat + 1)
	if _online:
		who = ("YOU" if seat == Net.local_player else "OPPONENT") + "  ·  " + who
	elif Session.ai_seat == seat:
		who = "AI OPPONENT  ·  " + who
	elif Session.ai_seat >= 0:
		who = "YOU  ·  " + who
	var player_name: String = Session.player_names[seat]
	if player_name.to_upper() == "PLAYER %d" % (seat + 1):
		return who
	return "%s  ·  %s" % [who, player_name.to_upper()]


## The two sheets slide in from their edges and the VS mark lands between them. Waits for the
## container's first layout so the slide starts from the settled position.
func _enter() -> void:
	vs_mark.scale = Vector2.ZERO
	for s in sheets:
		s.modulate.a = 0.0
	if not is_inside_tree():
		return   # an autostart already moved on
	await get_tree().process_frame
	if not is_inside_tree():
		return
	for i in range(2):
		var sheet: DeckSheet = sheets[i]
		var dx: float = -SLIDE if i == 0 else SLIDE
		sheet.position.x += dx
		sheet.modulate.a = 0.0
		var t: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(sheet, "position:x", sheet.position.x - dx, 0.35)
		t.tween_property(sheet, "modulate:a", 1.0, 0.3)
	var m: Tween = create_tween()
	m.tween_interval(0.2)
	m.tween_property(vs_mark, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for i in range(2):
		for p in Session.deck_problems(Session.chosen[i]):
			problems.append("Player %d: %s" % [i + 1, p])
	if _online and not Net.is_host() and problems.is_empty():
		problems.append("Waiting for the host to start the duel.")
	problems_label.text = "\n".join(problems)
	start_button.disabled = not problems.is_empty()
	if _online and Net.is_host() and not start_button.disabled and OS.get_cmdline_user_args().has("--dev-autoplay"):
		_on_start()


## The other client backed out, so this one follows it to the select screen.
func _on_lobby_changed() -> void:
	if not Net.both_locked() and not _started:
		_to_select()


func _on_peer_left() -> void:
	Net.leave()
	Session.player_names = ["Player 1", "Player 2"]
	Session.go_to_title()


func _on_connection_failed(reason: String) -> void:
	push_warning(reason)
	Session.player_names = ["Player 1", "Player 2"]
	Session.go_to_title()


func _on_start() -> void:
	if _started:
		return
	_started = true
	if _online:
		Net.start_duel()
	else:
		Session.go_to_duel()


func _on_back() -> void:
	if _online:
		var me: int = Net.local_player
		Net.set_local_pick(Session.decks.find(Session.chosen[me]), Session.player_names[me], false)
	_to_select()


func _to_select() -> void:
	if _leaving:
		return
	_leaving = true
	Session.locked = [false, false]
	Session.go_to_select()


## Opened directly: `--dev-pick=A,B` fills both seats, `--dev-ai` marks seat 2 as the AI's.
func _dev_setup() -> void:
	if _online:
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--dev-ai"):
		Session.ai_seat = 1
	for arg in args:
		if arg.begins_with("--dev-pick="):
			var picks: PackedStringArray = arg.get_slice("=", 1).split(",")
			for i in range(mini(2, picks.size())):
				var index: int = int(picks[i])
				if index >= 0 and index < Session.decks.size():
					Session.chosen[i] = Session.decks[index]
					Session.locked[i] = true


## `--dev-aspect=N` shows player 1's duelist at aspect N the way a click would, with the pointer
## left over the card so the hover lift shows too. `--dev-screenshot=<png>` saves and quits.
func _dev_screenshot() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--dev-aspect="):
			sheets[0]._hover_portrait(true)
			await sheets[0].show_aspect(int(arg.get_slice("=", 1)), true)
	for arg in args:
		if arg.begins_with("--dev-screenshot=") and not _online:
			var path: String = arg.get_slice("=", 1)
			await get_tree().create_timer(0.8).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			print("screenshot saved to %s" % path)
			get_tree().quit()
