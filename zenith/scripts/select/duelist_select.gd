extends Control
## Deck selection, one seat at a time: a searchable library beside a tabbed preview. Nothing about the other seat shows here; the matchup screen
## comes after both lock in. Hotseat: Player 1 locks in, then Player 2 on the same screen. Vs AI:
## the person picks their own duelist, then the AI's. Online: this client's seat only, and the
## lobby waits for the other client's lock.

const ROSTER_TILE: PackedScene = preload("res://scenes/select/roster_tile.tscn")
const ADVANCE_DELAY: float = 0.6

@onready var seat_panel: SelectSeat = $Margin/Column/Body/Seat
@onready var faces: CardFaceCache = $CardFaceCache
@onready var roster: GridContainer = $Margin/Column/Body/Library/Scroll/Roster
@onready var title_label: Label = $Margin/Column/TitleRow/Title
@onready var status_label: Label = $Margin/Column/TitleRow/Status
@onready var back_button: Button = $Margin/Column/TitleRow/Back
@onready var players_strip: HBoxContainer = $Margin/Column/TitleRow/Players
@onready var seat_chips: Array[Label] = [$Margin/Column/TitleRow/Players/Seat0/Label, $Margin/Column/TitleRow/Players/Seat1/Label]
@onready var code_banner: PanelContainer = $Margin/Column/CodeBanner
@onready var code_label: Label = $Margin/Column/CodeBanner/Row/Code
@onready var copy_button: Button = $Margin/Column/CodeBanner/Row/Copy
@onready var copied_label: Label = $Margin/Column/CodeBanner/Row/Copied

@onready var search: LineEdit = $Margin/Column/Body/Library/Tools/Search
@onready var school_filter: OptionButton = $Margin/Column/Body/Library/Tools/School
@onready var count_label: Label = $Margin/Column/Body/Library/Count
@onready var empty_label: Label = $Margin/Column/Body/Library/Empty
@onready var reset_button: Button = $Margin/Column/Body/Library/Reset
@onready var roster_scroll: ScrollContainer = $Margin/Column/Body/Library/Scroll

var _schools: Array[String] = [""]
var _visible_indices: Array[int] = []

var _online: bool = false
var _order: Array[int] = [0, 1]   # seats this client chooses for, in turn
var _seat: int = 0                # the seat choosing now
var _tiles: Array[RosterTile] = []
var _advancing: bool = false


func _ready() -> void:
	theme = SanctumUI.theme().duplicate()
	$Margin/Column/Body.move_child(seat_panel, 0)
	SanctumUI.enter($Margin/Column/Body)
	# Arrow-key browsing needs a visible focus ring, which the shared theme leaves off.
	theme.set_stylebox("focus", "Button", ZenithTheme.box(Color.TRANSPARENT, ZenithTheme.ACCENT, ZenithTheme.RADIUS, 2, 0, 0))
	theme.set_stylebox("focus", "TileButton", ZenithTheme.box(Color.TRANSPARENT, ZenithTheme.ACCENT, ZenithTheme.RADIUS, 2, 0, 0))
	MapArt.tint_for_school("")
	SanctumUI.dress(self, title_label)
	_online = Net.active()
	if not _online and OS.get_cmdline_user_args().has("--dev-ai"):
		Session.ai_seat = 1   # the select screen opened directly, as against the AI
	Session.locked = [false, false]
	back_button.pressed.connect(_on_back)
	for i in range(Session.decks.size()):
		var tile: RosterTile = ROSTER_TILE.instantiate()
		roster.add_child(tile)
		tile.setup(i, Session.decks[i])
		tile.picked.connect(_pick)
		_tiles.append(tile)
	school_filter.add_item("All schools")
	for d: DeckList in Session.decks:
		if not _schools.has(d.style):
			_schools.append(d.style)
			school_filter.add_item(CardText.school_name(d.style))
	search.text_changed.connect(func(_text: String) -> void: _filter_decks())
	school_filter.item_selected.connect(func(_index: int) -> void: _filter_decks())
	reset_button.pressed.connect(_reset_filters)
	roster_scroll.resized.connect(_resize_grid)
	_filter_decks()
	_resize_grid()
	seat_panel.faces = faces
	seat_panel.lock_toggled.connect(_on_lock_toggled)
	seat_panel.name_changed.connect(_on_name_changed)
	if _online:
		_setup_online()
	elif Session.ai_seat >= 0:
		_order = [1 - Session.ai_seat, Session.ai_seat]
		Session.player_names[Session.ai_seat] = "The AI"
	_show_seat(_order[0])
	_dev_args()
	SanctumUI.wire_buttons(self)


func _setup_online() -> void:
	var me: int = Net.local_player
	_order = [me]
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.peer_left.connect(_on_peer_left)
	Net.connection_failed.connect(_on_connection_failed)
	# Re-announce this seat, unlocked, so a client arriving after the host picked still sees it
	# and a return from the matchup screen or a duel starts both seats fresh.
	var deck_index: int = int(Net.lobby[me]["deck"])
	if deck_index >= 0:
		Session.chosen[me] = Session.decks[deck_index]
	Net.set_local_pick(deck_index, Session.player_names[me], false)
	players_strip.visible = true
	code_label.text = Net.room_code
	copy_button.pressed.connect(_copy_code)


func _copy_code() -> void:
	DisplayServer.clipboard_set(Net.room_code)
	copied_label.text = "copied again"


func _tag(seat: int) -> String:
	if _online:
		return "YOU  ·  PLAYER %d" % (seat + 1)
	if seat == Session.ai_seat:
		return "AI OPPONENT  ·  PLAYER %d" % (seat + 1)
	if Session.ai_seat >= 0:
		return "YOU  ·  PLAYER %d" % (seat + 1)
	return "PLAYER %d" % (seat + 1)


func _show_seat(seat: int) -> void:
	_seat = seat
	seat_panel.set_seat(seat, _tag(seat))
	_reset_filters()
	if seat == Session.ai_seat:
		title_label.text = "Choose the opponent's deck"
	elif _online or Session.ai_seat >= 0:
		title_label.text = "Choose your deck"
	else:
		title_label.text = "Player %d, choose your deck" % (seat + 1)
	_refresh()


func _pick(index: int) -> void:
	if index < 0 or index >= Session.decks.size() or Session.locked[_seat]:
		return
	Session.chosen[_seat] = Session.decks[index]
	seat_panel.show_deck(Session.decks[index])
	if _online:
		Net.set_local_pick(index, Session.player_names[_seat], false)
	_refresh()


func _on_lock_toggled(seat: int, on: bool) -> void:
	if Session.chosen[seat] == null:
		return
	Session.locked[seat] = on
	if on:
		$Background.confirm()
	seat_panel.set_locked(on)
	if _online:
		Net.set_local_pick(Session.decks.find(Session.chosen[seat]), Session.player_names[seat], on)
		_refresh()
		if Net.both_locked():
			_advance()
		return
	# Offline: a lock hands the screen to the next seat in line, or moves on when all are set.
	if on:
		var next: int = _next_seat()
		if next >= 0:
			_show_seat(next)
		else:
			_refresh()
			_advance()
	else:
		_refresh()


## The first seat in this client's order that has not locked in, -1 when all have.
func _next_seat() -> int:
	for s in _order:
		if not Session.locked[s]:
			return s
	return -1


func _on_name_changed(seat: int, player_name: String) -> void:
	if _online and seat == Net.local_player:
		var deck: DeckList = Session.chosen[seat]
		Net.set_local_pick(Session.decks.find(deck) if deck != null else -1, player_name, Session.locked[seat])


## The other client's seat changed. Only its lock matters here; its pick stays unseen.
func _on_lobby_changed() -> void:
	var other: int = Net.remote_player()
	var entry: Dictionary = Net.lobby[other]
	Session.player_names[other] = str(entry["name"])
	var deck_index: int = int(entry["deck"])
	Session.chosen[other] = Session.decks[deck_index] if deck_index >= 0 and deck_index < Session.decks.size() else null
	Session.locked[other] = bool(entry["ready"])
	_refresh()
	if Net.both_locked():
		_advance()


func _on_peer_left() -> void:
	Net.leave()
	Session.player_names = ["Player 1", "Player 2"]
	Session.go_to_title()


func _on_connection_failed(reason: String) -> void:
	push_warning(reason)
	Session.player_names = ["Player 1", "Player 2"]
	Session.go_to_title()


## Tile badges for the choosing seat, the status line, and what Back does.
func _refresh() -> void:
	var d: DeckList = Session.chosen[_seat]
	$Background.set_school(Palette.school_ui(d.style) if d != null else ZenithTheme.FRAME)
	for tile in _tiles:
		var state: int = 0
		if d != null and Session.decks[tile.index] == d:
			state = 2 if Session.locked[_seat] else 1
		tile.set_badge(state, "P%d" % (_seat + 1), Session.seat_color(_seat) if d != null else ZenithTheme.MUTED)
		tile.disabled = Session.locked[_seat]
	if _online:
		_refresh_players()
	if _online and not Net.seats_filled():
		status_label.text = "Waiting for the other player to connect." if Net.room_code == "" else ""
	elif _online and Session.locked[_seat]:
		status_label.text = "Locked in. Waiting for the other player."
	elif Session.locked[_seat]:
		status_label.text = "Both locked in."
	else:
		status_label.text = ""
	back_button.text = "Back" if _order.find(_seat) == 0 else "Back to Player %d" % (_order[0] + 1)


## The players strip in the top row: each seat's name and state, and the room code banner
## while the room still has an empty seat.
func _refresh_players() -> void:
	var me: int = Net.local_player
	var filled: bool = Net.seats_filled()
	for seat in range(2):
		var chip: Label = seat_chips[seat]
		var present: bool = seat == me or filled
		var state: String
		if not present:
			state = "waiting"
		elif bool(Net.lobby[seat]["ready"]):
			state = "locked in"
		else:
			state = "choosing"
		var who: String = str(Net.lobby[seat]["name"]) if present else "empty seat"
		if seat == me:
			who += " (you)"
		var picked: bool = present and int(Net.lobby[seat]["deck"]) >= 0
		chip.text = "P%d  %s  ·  %s" % [seat + 1, who, state]
		chip.add_theme_color_override("font_color", Session.seat_color(seat) if picked else (ZenithTheme.TEXT if present else ZenithTheme.MUTED))
		var border: Color = ZenithTheme.BORDER
		if picked:
			border = Session.seat_color(seat) if state == "locked in" else Color(Session.seat_color(seat), 0.45)
		var fill: Color = ZenithTheme.RAISED if present else Color(1, 1, 1, 0.02)
		(chip.get_parent() as PanelContainer).add_theme_stylebox_override("panel", ZenithTheme.box(fill, border, ZenithTheme.RADIUS, 1, 12, 6))
	code_banner.visible = not filled and Net.room_code != ""


func _advance() -> void:
	if _advancing or _dev_screenshot_pending():
		return   # a screenshot run wants this screen, not the next
	_advancing = true
	await get_tree().create_timer(ADVANCE_DELAY).timeout
	Session.go_to_versus()


## Offline, from the second seat, Back reopens the first seat's pick; otherwise it leaves.
func _on_back() -> void:
	var pos: int = _order.find(_seat)
	if pos > 0 and not _online:
		var prev: int = _order[pos - 1]
		Session.locked[prev] = false
		_show_seat(prev)
		return
	if _online:
		Net.leave()
		Session.player_names = ["Player 1", "Player 2"]
	Session.go_to_title()


## Filters never change the player's current choice or expose another seat's pick.
func _filter_decks() -> void:
	_visible_indices.clear()
	var query: String = search.text.strip_edges().to_lower()
	var school: String = _schools[school_filter.selected] if school_filter.selected >= 0 else ""
	for tile: RosterTile in _tiles:
		var d: DeckList = Session.decks[tile.index]
		var def: CardDef = Session.library.defs.get(d.duelist_face_id())
		var haystack: String = "%s %s %s %s %s" % [d.name, def.title if def != null else d.duelist_face_id(), Archetype.label(d.archetype), d.tagline, d.difficulty]
		tile.visible = (school == "" or d.style == school) and (query == "" or haystack.to_lower().contains(query))
		if tile.visible:
			_visible_indices.append(tile.index)
	count_label.text = "STARTER DECKS   /   %d OF %d" % [_visible_indices.size(), _tiles.size()]
	empty_label.visible = _visible_indices.is_empty()
	reset_button.visible = query != "" or school != ""
	roster_scroll.scroll_vertical = 0


func _reset_filters() -> void:
	search.text = ""
	school_filter.select(0)
	_filter_decks()


func _resize_grid() -> void:
	seat_panel.custom_minimum_size.x = clampf($Margin/Column/Body.size.x * 0.57, 640.0, 1050.0)
	roster.columns = maxi(1, mini(4, int((roster_scroll.size.x + 12) / 192)))


## Arrows browse the filtered grid. Confirmation is an explicit, focused button action.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or not event is InputEventKey:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit or Session.locked[_seat]:
		return
	var key: Key = (event as InputEventKey).keycode
	if not key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] or _visible_indices.is_empty():
		return
	var current: int = _visible_indices.find(Session.decks.find(Session.chosen[_seat]))
	var step: int = 1
	if key == KEY_LEFT:
		step = -1
	elif key == KEY_UP:
		step = -roster.columns
	elif key == KEY_DOWN:
		step = roster.columns
	var index: int = _visible_indices[posmod(current + step, _visible_indices.size()) if current >= 0 else 0]
	_pick(index)
	roster_scroll.ensure_control_visible(_tiles[index])
	accept_event()


## `--dev-pick=A,B` picks deck A for player 1 and B for player 2 (online: only this client's
## seat). `--dev-lock` locks each seat in turn as picked, so a hotseat run lands on player 2
## choosing with one pick or on "both locked" with two; `--dev-autoplay` locks online so both
## clients reach the matchup. `--dev-aspect=N` shows the choosing seat's duelist at Aspect N.
## `--dev-details` opens the deck detail tab on that seat's panel.
## `--dev-screenshot=<png>` saves the screen once laid out, then quits, except on an online
## autoplay run, where the duel further on takes it.
func _dev_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var lock: bool = args.has("--dev-lock") or (_online and args.has("--dev-autoplay"))
	for arg in args:
		if arg.begins_with("--dev-pick="):
			var picks: PackedStringArray = arg.get_slice("=", 1).split(",")
			for i in range(mini(2, picks.size())):
				if i == _seat:
					_pick(int(picks[i]))
					if lock:
						_on_lock_toggled(i, true)
	for arg in args:
		if arg.begins_with("--dev-aspect=") and Session.chosen[_seat] != null:
			seat_panel.show_aspect(int(arg.get_slice("=", 1)))
	# `--dev-details` opens the deck detail tab, the decklist.
	if args.has("--dev-details"):
		seat_panel.show_details()
	for arg in args:
		if arg.begins_with("--dev-screenshot=") and not (_online and args.has("--dev-autoplay")):
			var path: String = arg.get_slice("=", 1)
			await get_tree().create_timer(0.4).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			print("screenshot saved to %s" % path)
			get_tree().quit()


func _dev_screenshot_pending() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if _online and args.has("--dev-autoplay"):
		return false   # the screenshot is of the duel, further on
	for arg in args:
		if arg.begins_with("--dev-screenshot="):
			return true
	return false
