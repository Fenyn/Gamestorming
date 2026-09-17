extends Control
## Deck and fighter selection. Hotseat: both columns are editable here. Online: this screen is
## the lobby; each client edits its own seat, sees the other seat fill in, and the host starts.

@onready var sides: Array[SelectSide] = [$Margin/Column/Players/P0, $Margin/Column/Players/P1]
@onready var faces: CardFaceCache = $CardFaceCache
@onready var title_label: Label = $Margin/Column/TitleRow/Title
@onready var matchup_label: Label = $Margin/Column/TitleRow/Matchup
@onready var seed_label: Label = $Margin/Column/Footer/SeedLabel
@onready var seed_edit: LineEdit = $Margin/Column/Footer/Seed
@onready var ai_label: Label = $Margin/Column/Footer/AiLabel
@onready var ai_level: OptionButton = $Margin/Column/Footer/AiLevel
@onready var problems_label: Label = $Margin/Column/Footer/Problems
@onready var start_button: Button = $Margin/Column/Footer/Start
@onready var back_button: Button = $Margin/Column/Footer/Back

## Profile file names behind the AiLevel items, in item order.
const AI_LEVELS: Array[String] = ["easy", "default", "hard"]

var _online: bool = false
var _started: bool = false


func _ready() -> void:
	theme = ZenithTheme.get_theme()
	_online = Net.active()
	if not _online and OS.get_cmdline_user_args().has("--dev-ai"):
		Session.ai_seat = 1   # the select screen opened directly, as against the AI
	matchup_label.add_theme_color_override("font_color", ZenithTheme.MUTED)
	seed_edit.text = str(Session.seed_value)
	seed_edit.text_changed.connect(func(t: String) -> void: Session.seed_value = int(t))
	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(_on_back)
	await _render_portraits()
	var might_max: int = _might_max()
	for i in range(2):
		sides[i].setup(i, Session.decks, faces, might_max)
		sides[i].deck_chosen.connect(_on_deck_chosen)
		sides[i].name_changed.connect(_on_name_changed)
	if _online:
		_setup_online()
	else:
		if Session.ai_seat >= 0:
			_setup_ai()
		for i in range(2):
			var existing: DeckList = Session.chosen[i]
			if existing != null:
				sides[i].select(Session.decks.find(existing))
	_refresh_start()
	_dev_screenshot()


## One person against the AI: the person picks both houses, and how hard the AI thinks.
func _setup_ai() -> void:
	var seat: int = Session.ai_seat
	title_label.text = "Choose your fighter and your opponent"
	sides[1 - seat].set_locked(false, "YOU  ·  PLAYER %d" % (2 - seat))
	sides[seat].set_locked(false, "AI OPPONENT  ·  PLAYER %d" % (seat + 1))
	ai_label.visible = true
	ai_level.visible = true
	ai_level.select(maxi(0, AI_LEVELS.find(Session.ai_profile)))
	ai_level.item_selected.connect(func(i: int) -> void: Session.ai_profile = AI_LEVELS[i])


func _setup_online() -> void:
	var me: int = Net.local_player
	title_label.text = "Choose your fighter"
	sides[me].set_locked(false, "YOU  ·  PLAYER %d" % (me + 1))
	sides[1 - me].set_locked(true, "OPPONENT  ·  PLAYER %d" % (2 - me))
	seed_label.visible = Net.is_host()
	seed_edit.visible = Net.is_host()
	start_button.visible = Net.is_host()
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.peer_left.connect(_on_peer_left)
	Net.connection_failed.connect(_on_connection_failed)
	# Re-announce this seat so a client arriving after the host picked still sees it.
	var mine: Dictionary = Net.lobby[me]
	var deck_index: int = int(mine["deck"])
	if deck_index >= 0:
		sides[me].select(deck_index)
	else:
		Net.set_local_pick(-1, Session.player_names[me])
	_on_lobby_changed()


## Faces come from one shared SubViewport, so render them one after another before the sides
## ask for them.
func _render_portraits() -> void:
	for d in Session.decks:
		var def: CardDef = Session.library.defs.get(d.fighter_id)
		if def != null:
			await faces.render_face(def, def.lowest_tier())


## Highest Might any shipped fighter reaches within its deck's tiers, so the tier bars compare
## across decks rather than within one.
func _might_max() -> int:
	var best: int = 1
	for d in Session.decks:
		var def: CardDef = Session.library.defs.get(d.fighter_id)
		if def == null:
			continue
		for t in def.tiers:
			if int(t.get("tier", 0)) > d.tiers:
				continue
			var might: Array = t.get("might", [])
			if might.size() > 0:
				best = maxi(best, int(might[might.size() - 1]))
	return best


func _on_deck_chosen(player: int, deck: DeckList) -> void:
	Session.chosen[player] = deck
	if _online and player == Net.local_player:
		Net.set_local_pick(Session.decks.find(deck), Session.player_names[player])
	_refresh_start()


func _on_name_changed(player: int, player_name: String) -> void:
	if _online and player == Net.local_player:
		var deck: DeckList = Session.chosen[player]
		Net.set_local_pick(Session.decks.find(deck) if deck != null else -1, player_name)


## The other client's seat changed.
func _on_lobby_changed() -> void:
	var other: int = Net.remote_player()
	var entry: Dictionary = Net.lobby[other]
	sides[other].show_name(str(entry["name"]))
	var deck_index: int = int(entry["deck"])
	if deck_index >= 0 and deck_index < Session.decks.size():
		sides[other].select(deck_index)
	_refresh_start()


func _on_peer_left() -> void:
	Net.leave()
	Session.player_names = ["Player 1", "Player 2"]
	Session.go_to_title()


## The host's start message named a deck this build does not have.
func _on_connection_failed(reason: String) -> void:
	push_warning(reason)
	Session.player_names = ["Player 1", "Player 2"]
	Session.go_to_title()


func _refresh_start() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for i in range(2):
		var d: DeckList = Session.chosen[i]
		if d == null:
			problems.append("Player %d has not picked a house." % (i + 1))
			continue
		for p in Session.deck_problems(d):
			problems.append("Player %d: %s" % [i + 1, p])
	if _online and Net.peer_id == 0:
		problems.append("Waiting for the other player to connect.")
	if _online and not Net.is_host() and problems.is_empty():
		problems.append("Waiting for the host to start the duel.")
	problems_label.text = "\n".join(problems)
	start_button.disabled = not problems.is_empty()
	if Session.can_start():
		matchup_label.text = "%s  vs  %s" % [Session.chosen[0].name, Session.chosen[1].name]
		matchup_label.add_theme_color_override("font_color", ZenithTheme.TEXT)
	else:
		matchup_label.text = "Each player picks a house"
		matchup_label.add_theme_color_override("font_color", ZenithTheme.MUTED)
	if _online and Net.is_host() and not start_button.disabled and _dev_autostart():
		_on_start()


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
		Net.leave()
		Session.player_names = ["Player 1", "Player 2"]
	Session.go_to_title()


## `--dev-screenshot=<png>` after `--`: saves the screen once laid out, then quits.
## `--dev-ai` shows the screen as it is against the AI. `--dev-pick=A,B` selects deck A for player 1 and B for player 2 first (online: only this
## client's seat). `--dev-autoplay` makes an online host start as soon as both seats are set.
func _dev_screenshot() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-pick="):
			var picks: PackedStringArray = arg.get_slice("=", 1).split(",")
			for i in range(mini(2, picks.size())):
				if not _online or i == Net.local_player:
					sides[i].select(int(picks[i]))
	for arg in OS.get_cmdline_user_args():
		# `--dev-tier=N`: show player 1's fighter at tier N the way a click would, with the
		# pointer left over the portrait so the hover lift shows too.
		if arg.begins_with("--dev-tier="):
			sides[0]._hover_portrait(true)
			await sides[0].show_tier(int(arg.get_slice("=", 1)), true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-screenshot=") and not _online:
			var path: String = arg.get_slice("=", 1)
			await get_tree().create_timer(0.4).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			print("screenshot saved to %s" % path)
			get_tree().quit()


func _dev_autostart() -> bool:
	return OS.get_cmdline_user_args().has("--dev-autoplay")
