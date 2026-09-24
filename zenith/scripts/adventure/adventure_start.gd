extends Control
## Adventure start: pick a character, then one of their unlocked starters when they have more than
## one, and begin a run. A single-seat, filtered copy of the duelist select screen, reusing its
## roster grid and detail panel.

const ROSTER_TILE: PackedScene = preload("res://scenes/select/roster_tile.tscn")
const ADVANCE_DELAY: float = 0.6

@onready var seat_panel: SelectSeat = $Margin/Column/Body/Seat
@onready var faces: CardFaceCache = $CardFaceCache
@onready var roster: GridContainer = $Margin/Column/Body/Library/Scroll/Roster
@onready var roster_scroll: ScrollContainer = $Margin/Column/Body/Library/Scroll
@onready var motes_tile: StatTile = $Margin/Column/TitleRow/Motes
@onready var vendor_button: Button = $Margin/Column/TitleRow/Vendor
@onready var journal_button: Button = $Margin/Column/TitleRow/Journal
@onready var decks_row: HBoxContainer = $Margin/Column/Footer/Decks
@onready var back_button: Button = $Margin/Column/Footer/Back
@onready var loadout_button: Button = $Margin/Column/Footer/Loadout
@onready var begin_button: Button = $Margin/Column/Footer/Begin
@onready var problems_label: Label = $Margin/Column/Footer/Problems

## One entry per character: their unlocked starter ids and decks, in the order the unlocks list
## them. A tile stands for a character and shows their first deck.
var _starter_ids: Array[Array] = []
var _starters: Array[Array] = []
var _tiles: Array[RosterTile] = []
var _picked: int = -1
var _deck_index: int = 0
var _deck_group: ButtonGroup = ButtonGroup.new()
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
	journal_button.pressed.connect(_on_journal)
	back_button.pressed.connect(_on_back)
	loadout_button.pressed.connect(_on_loadout)
	begin_button.pressed.connect(_on_begin)
	_dev_unlocks()
	var characters: Array[String] = []
	for id: String in Session.unlocks.available_starters():
		var d: DeckList = DeckList.resolve(id)
		if d == null:
			continue
		var character: String = AdventureDecks.character_of(AdventureDecks.family_of(id))
		var index: int = characters.find(character)
		if index < 0:
			characters.append(character)
			_starter_ids.append([])
			_starters.append([])
			index = characters.size() - 1
			var tile: RosterTile = ROSTER_TILE.instantiate()
			roster.add_child(tile)
			tile.setup(index, d)
			tile.picked.connect(_pick)
			_tiles.append(tile)
		_starter_ids[index].append(id)
		_starters[index].append(d)
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
	_deck_index = 0
	for i in range(_tiles.size()):
		_tiles[i].set_badge(1 if i == index else 0, "", ZenithTheme.ACCENT)
	_fill_decks_row()
	_show_deck()


## One toggle per deck of the picked character, shown only when there is a choice to make.
func _fill_decks_row() -> void:
	for child in decks_row.get_children():
		decks_row.remove_child(child)
		child.queue_free()
	var decks: Array = _starters[_picked]
	decks_row.visible = decks.size() > 1
	if decks.size() <= 1:
		return
	for i in range(decks.size()):
		var button: Button = Button.new()
		button.toggle_mode = true
		button.button_group = _deck_group
		button.text = (decks[i] as DeckList).name
		button.custom_minimum_size = Vector2(0, 44)
		button.button_pressed = i == _deck_index
		button.pressed.connect(_pick_deck.bind(i))
		decks_row.add_child(button)


func _pick_deck(index: int) -> void:
	if _advancing or _picked < 0:
		return
	_deck_index = index
	_show_deck()


func _show_deck() -> void:
	var d: DeckList = _starters[_picked][_deck_index]
	$Background.set_school(Palette.school_ui(d.style))
	seat_panel.show_deck(d)
	var problems: Array[String] = Session.deck_problems(d)
	problems_label.text = "\n".join(problems)
	begin_button.disabled = not problems.is_empty()
	loadout_button.disabled = false


func _picked_starter() -> String:
	return str(_starter_ids[_picked][_deck_index])


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
	var starter_id: String = _picked_starter()
	await get_tree().create_timer(ADVANCE_DELAY).timeout
	Session.start_run(starter_id)
	Session.go_to_adventure()


## Opens the loadout screen for the highlighted starter. No signal carries the pick there today,
## so it is stashed on the loadout screen's own static var, the way AdventureDev's flags fill it
## for a dev launch.
func _on_loadout() -> void:
	if _advancing or _picked < 0:
		return
	Loadout.starter_id = _picked_starter()
	Session.go_to_loadout()


func _on_vendor() -> void:
	Session.go_to_vendor()


func _on_journal() -> void:
	Session.go_to_journal()


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


## `--dev-unlock-all` opens every starter file and saves it; `--dev-unlock-reset` deletes the
## unlocks save so only the storylines' open starters remain. With `--dev-scratch=<dir>` both act on
## a scratch save instead of the player's.
func _dev_unlocks() -> void:
	if AdventureDev.flag("--dev-scratch=") != "":
		AdventureDev.use_scratch_saves()
	if AdventureDev.has_flag("--dev-unlock-reset"):
		AdventureUnlocks.clear()
		Session.unlocks = AdventureUnlocks.new()
	if AdventureDev.has_flag("--dev-unlock-all"):
		for id in AdventureDecks.playable_starters():
			Session.unlocks.unlock(id)
		Session.unlocks.save()


## `--dev-pick=N` highlights the Nth character and `--dev-deck=N` their Nth deck.
## `--dev-screenshot=<png>` saves the screen once laid out, then quits.
func _dev_args() -> void:
	var pick_arg: String = AdventureDev.flag("--dev-pick=")
	if pick_arg != "" and not _starters.is_empty():
		_pick(clampi(int(pick_arg), 0, _starters.size() - 1))
	var deck_arg: String = AdventureDev.flag("--dev-deck=")
	if deck_arg != "" and _picked >= 0:
		var index: int = clampi(int(deck_arg), 0, _starters[_picked].size() - 1)
		_pick_deck(index)
		if index < decks_row.get_child_count():
			(decks_row.get_child(index) as Button).button_pressed = true
	AdventureDev.screenshot(self)
