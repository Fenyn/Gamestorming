extends Control
## Adventure start: pick one of the playable starters and begin a run. A single-seat, filtered
## copy of the duelist select screen, reusing its roster grid and detail panel.

const ROSTER_TILE: PackedScene = preload("res://scenes/select/roster_tile.tscn")
const ADVANCE_DELAY: float = 0.6

@onready var seat_panel: SelectSeat = $Margin/Column/Body/Seat
@onready var faces: CardFaceCache = $CardFaceCache
@onready var roster: GridContainer = $Margin/Column/Body/Library/Scroll/Roster
@onready var roster_scroll: ScrollContainer = $Margin/Column/Body/Library/Scroll
@onready var motes_tile: StatTile = $Margin/Column/TitleRow/Motes
@onready var vendor_button: Button = $Margin/Column/TitleRow/Vendor
@onready var back_button: Button = $Margin/Column/Footer/Back
@onready var loadout_button: Button = $Margin/Column/Footer/Loadout
@onready var begin_button: Button = $Margin/Column/Footer/Begin
@onready var problems_label: Label = $Margin/Column/Footer/Problems

var _starter_ids: Array[String] = []
var _starters: Array[DeckList] = []
var _tiles: Array[RosterTile] = []
var _picked: int = -1
var _advancing: bool = false


func _ready() -> void:
	theme = SanctumUI.theme()
	$Margin/Column/Body.move_child(seat_panel, 0)
	SanctumUI.enter($Margin/Column/Body)
	# The name field and the second seat belong to the two-seat select flow; a run has one
	# starter and no player name to type.
	(seat_panel.get_node("Row/Header/Name") as LineEdit).visible = false
	(seat_panel.get_node("Row/Lock") as Button).visible = false
	(seat_panel.get_node("Row/Header/Tag") as Label).text = "STARTER"
	seat_panel.faces = faces
	motes_tile.set_stat("Motes", str(Session.wallet.motes), "", ZenithTheme.ACCENT)
	vendor_button.pressed.connect(_on_vendor)
	back_button.pressed.connect(_on_back)
	loadout_button.pressed.connect(_on_loadout)
	begin_button.pressed.connect(_on_begin)
	for id: String in AdventureDecks.playable_starters():
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
	SanctumUI.wire_buttons(self)


func _pick(index: int) -> void:
	if _advancing or index < 0 or index >= _starters.size():
		return
	_picked = index
	var d: DeckList = _starters[index]
	$Background.set_school(Palette.school_ui(d.style))
	seat_panel.show_deck(d)
	var problems: Array[String] = Session.deck_problems(d)
	problems_label.text = "\n".join(problems)
	begin_button.disabled = not problems.is_empty()
	loadout_button.disabled = false
	for i in range(_tiles.size()):
		_tiles[i].set_badge(1 if i == index else 0, "", ZenithTheme.ACCENT)


func _on_begin() -> void:
	if _advancing or _picked < 0:
		return
	_advancing = true
	begin_button.disabled = true
	loadout_button.disabled = true
	back_button.disabled = true
	for i in range(_tiles.size()):
		_tiles[i].disabled = true
		_tiles[i].set_badge(2 if i == _picked else 0, "", ZenithTheme.ACCENT)
	var starter_id: String = _starter_ids[_picked]
	await get_tree().create_timer(ADVANCE_DELAY).timeout
	Session.start_run(starter_id)
	Session.go_to_adventure()


## Opens the loadout screen for the highlighted starter. No signal carries the pick there today,
## so it is stashed on the loadout screen's own static var, the way AdventureDev's flags fill it
## for a dev launch.
func _on_loadout() -> void:
	if _advancing or _picked < 0:
		return
	Loadout.starter_id = _starter_ids[_picked]
	Session.go_to_loadout()


func _on_vendor() -> void:
	Session.go_to_vendor()


func _on_back() -> void:
	Session.leave_adventure()
	Session.go_to_title()


func _resize_grid() -> void:
	seat_panel.custom_minimum_size.x = clampf($Margin/Column/Body.size.x * 0.57, 640.0, 1050.0)
	roster.columns = maxi(1, mini(4, int((roster_scroll.size.x + 12) / 192)))


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
	var pick_arg: String = AdventureDev.flag("--dev-pick=")
	if pick_arg != "" and not _starters.is_empty():
		_pick(clampi(int(pick_arg), 0, _starters.size() - 1))
	AdventureDev.screenshot(self)
