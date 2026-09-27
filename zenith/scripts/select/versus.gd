extends Control
## The matchup after both seats lock in: the two decks side by side, seed and AI level, and
## Start. Hotseat and vs AI start from here. Online, both clients arrive when both are locked. In
## a server room there is no Back, and the server deals once both clients have shown the matchup
## for `MATCHUP_SECONDS`; a queue room shows only the decks and "Duel starts in 5", and the server
## deals on its own clock. A ranked room also names the game of the match. On the LAN dev path
## either side's Back sends both back to the select screen and the host presses Start.

@onready var sheets: Array[DeckSheet] = [$Margin/Column/Sides/S0, $Margin/Column/Sides/S1]
@onready var faces: CardFaceCache = $CardFaceCache
@onready var status_label: Label = $Margin/Column/TitleRow/Status
@onready var seed_label: Label = $Margin/Column/Footer/SeedLabel
@onready var seed_edit: LineEdit = $Margin/Column/Footer/Seed
@onready var advanced: CheckButton = $Margin/Column/Footer/Advanced
@onready var ai_label: Label = $Margin/Column/Footer/AiLabel
@onready var ai_level: OptionButton = $Margin/Column/Footer/AiLevel
@onready var problems_label: Label = $Margin/Column/Footer/Problems
@onready var start_button: Button = $Margin/Column/Footer/Start
@onready var back_button: Button = $Margin/Column/Footer/Back
@onready var countdown_label: Label = $Margin/Column/Footer/Countdown
@onready var vs_mark: Label = $VsMark

## Profile file names behind the AiLevel items, in item order.
const AI_LEVELS: Array[String] = ["easy", "default", "hard"]
const SLIDE: float = 360.0
const MATCHUP_SECONDS: float = 3.0

var _online: bool = false
var _started: bool = false
var _leaving: bool = false


func _ready() -> void:
	theme = SanctumUI.theme()
	MapArt.tint_for_school("")
	SanctumUI.dress(self, $Margin/Column/TitleRow/Title as Label)
	_online = Net.active()
	_dev_setup()
	if not Session.can_start():
		Session.go_to_select()
		return
	seed_edit.text = str(Session.seed_value)
	$Background.set_school(Palette.school_ui(Session.chosen[1].style), true)
	$Background.set_rival(Palette.school_ui(Session.chosen[0].style))
	seed_edit.text_changed.connect(func(t: String) -> void: Session.seed_value = int(t))
	advanced.toggled.connect(func(on: bool) -> void:
		seed_label.visible = on
		seed_edit.visible = on)
	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(_on_back)
	for i in range(2):
		sheets[i].setup(i, faces)
		sheets[i].show_deck(Session.chosen[i], _tag(i))
	if _online:
		advanced.visible = Net.is_host()
		start_button.visible = Net.is_host()
		Net.lobby_changed.connect(_on_lobby_changed)
		Net.peer_left.connect(_on_peer_left)
		Net.connection_failed.connect(_on_connection_failed)
		if Net.queue_room():
			back_button.visible = false
			countdown_label.visible = true
			if Net.ranked_room():
				var me: int = Net.local_player
				status_label.text = DuelHud.series_text(maxi(1, Net.series_game), Net.RANKED_BEST_OF,
					Net.series_wins[me], Net.series_wins[1 - me])
		elif Net.server_room():
			# Both decks are on show now, and the server refuses any pick change from here on.
			back_button.visible = false
			get_tree().create_timer(MATCHUP_SECONDS).timeout.connect(_on_matchup_shown)
	elif Session.ai_seat >= 0:
		ai_label.visible = true
		ai_level.visible = true
		ai_level.select(maxi(0, AI_LEVELS.find(Session.ai_profile)))
		ai_level.item_selected.connect(func(i: int) -> void: Session.ai_profile = AI_LEVELS[i])
	_refresh()
	_enter()
	_dev_screenshot()
	SanctumUI.wire_buttons(self)


## Queue room: the seconds to the server's deal, counted from when this client saw both picks.
func _process(_delta: float) -> void:
	if not countdown_label.visible:
		return
	var seconds: int = ceili(maxi(0, Net.deal_at - Time.get_ticks_msec()) / 1000.0)
	countdown_label.text = "Duel starts in %d" % seconds if seconds > 0 else "Dealing…"


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
	if ArcaneBackdrop.motion_reduced():
		return
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
	if _online and not Net.is_host() and problems.is_empty() and not Net.queue_room():
		problems.append("Both locked in. The duel server deals in a moment." if Net.server_room() else "Waiting for the host to start the duel.")
	problems_label.text = "\n".join(problems)
	start_button.disabled = not problems.is_empty()
	if _online and Net.is_host() and not start_button.disabled and DevArgs.user_args().has("--dev-autoplay"):
		_on_start()


## The other client backed out, so this one follows it to the select screen.
func _on_lobby_changed() -> void:
	if not Net.both_locked() and not _started:
		_to_select()


## The other player left; the select screen waits for a new one and says who left.
func _on_peer_left() -> void:
	_to_select()


## The title shows why, from `Net.last_error`.
func _on_connection_failed(_reason: String) -> void:
	Session.player_names = ["Player 1", "Player 2"]
	Session.go_to_title()


func _on_matchup_shown() -> void:
	if not _leaving:
		Net.ready_to_deal()


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
	var args: PackedStringArray = DevArgs.user_args()
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
## Online, `--dev-matchup-shot=<png>` saves the matchup 1 second in and the duel goes on.
func _dev_screenshot() -> void:
	var args: PackedStringArray = DevArgs.user_args()
	for arg in args:
		if arg.begins_with("--dev-matchup-shot=") and _online:
			await get_tree().create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.get_slice("=", 1))
			print("matchup screenshot saved to %s" % arg.get_slice("=", 1))
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
