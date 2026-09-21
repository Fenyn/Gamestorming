extends Control
## Adventure start: pick one of the playable starters and begin a run. A single-seat, filtered
## copy of the duelist select screen, reusing its roster grid and detail panel.

const ROSTER_TILE: PackedScene = preload("res://scenes/select/roster_tile.tscn")
const ADVANCE_DELAY: float = 0.6

@onready var seat_panel: SelectSeat = $Margin/Column/Body/Seat
@onready var faces: CardFaceCache = $CardFaceCache
@onready var roster: GridContainer = $Margin/Column/Body/Library/Scroll/Roster
@onready var roster_scroll: ScrollContainer = $Margin/Column/Body/Library/Scroll
@onready var back_button: Button = $Margin/Column/Footer/Back
@onready var begin_button: Button = $Margin/Column/Footer/Begin
@onready var problems_label: Label = $Margin/Column/Footer/Problems

var _starter_ids: Array[String] = []
var _starters: Array[DeckList] = []
var _tiles: Array[RosterTile] = []
var _picked: int = -1
var _advancing: bool = false


func _ready() -> void:
	theme = ZenithTheme.get_theme()
	# The name field and the second seat belong to the two-seat select flow; a run has one
	# starter and no player name to type.
	(seat_panel.get_node("Row/Header/Name") as LineEdit).visible = false
	(seat_panel.get_node("Row/Lock") as Button).visible = false
	(seat_panel.get_node("Row/Header/Tag") as Label).text = "STARTER"
	seat_panel.faces = faces
	back_button.pressed.connect(_on_back)
	begin_button.pressed.connect(_on_begin)
	for id: String in AdventureLadder.playable_starters():
		var d: DeckList = DeckList.resolve(id)
		if d == null:
			continue
		var tile: RosterTile = ROSTER_TILE.instantiate()
		roster.add_child(tile)
		tile.setup(_starters.size(), d)
		tile.picked.connect(_pick)
		_starter_ids.append(id)
		_starters.append(d)
		_tiles.append(tile)
	roster_scroll.resized.connect(_resize_grid)
	_resize_grid()
	if not _starters.is_empty():
		_pick(0)
	_dev_args()


func _pick(index: int) -> void:
	if _advancing or index < 0 or index >= _starters.size():
		return
	_picked = index
	var d: DeckList = _starters[index]
	seat_panel.show_deck(d)
	var problems: Array[String] = Session.deck_problems(d)
	problems_label.text = "\n".join(problems)
	begin_button.disabled = not problems.is_empty()
	for i in range(_tiles.size()):
		_tiles[i].set_badge(1 if i == index else 0, "", ZenithTheme.ACCENT)


func _on_begin() -> void:
	if _advancing or _picked < 0:
		return
	_advancing = true
	begin_button.disabled = true
	back_button.disabled = true
	for i in range(_tiles.size()):
		_tiles[i].disabled = true
		_tiles[i].set_badge(2 if i == _picked else 0, "", ZenithTheme.ACCENT)
	var starter_id: String = _starter_ids[_picked]
	await get_tree().create_timer(ADVANCE_DELAY).timeout
	Session.start_run(starter_id)
	Session.go_to_adventure()


func _on_back() -> void:
	Session.leave_adventure()
	Session.go_to_title()


func _resize_grid() -> void:
	roster.columns = maxi(1, mini(4, int((roster_scroll.size.x + 16) / 236)))


## Arrows browse the starter grid, the same as the duelist select screen.
func _unhandled_key_input(event: InputEvent) -> void:
	if _advancing or not event.is_pressed() or event.is_echo() or not event is InputEventKey:
		return
	if _tiles.is_empty():
		return
	var key: Key = (event as InputEventKey).keycode
	if not key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		return
	var step: int = 1
	if key == KEY_LEFT:
		step = -1
	elif key == KEY_UP:
		step = -roster.columns
	elif key == KEY_DOWN:
		step = roster.columns
	var index: int = posmod((_picked if _picked >= 0 else 0) + step, _tiles.size())
	_pick(index)
	roster_scroll.ensure_control_visible(_tiles[index])
	accept_event()


## `--dev-pick=N` highlights the Nth starter. `--dev-screenshot=<png>` saves the screen once laid
## out, then quits.
func _dev_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--dev-pick=") and not _starters.is_empty():
			_pick(clampi(int(arg.get_slice("=", 1)), 0, _starters.size() - 1))
	for arg in args:
		if arg.begins_with("--dev-screenshot="):
			var path: String = arg.get_slice("=", 1)
			await get_tree().create_timer(0.4).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			print("screenshot saved to %s" % path)
			get_tree().quit()
