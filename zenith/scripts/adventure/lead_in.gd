extends Control
## The lead-in before an adventure duel: a context line, the two portraits, and the exchange one
## line at a time. Continue shows the next line, then starts the duel; Skip starts it at once.
##
## Opened with no lead-in waiting (straight from the editor, or with `--dev-lead-ins`) it becomes
## a browser over every scene in data/adventure/lead_ins.json, with all lines shown, Previous and
## Next, and Reload to pick up edits to the file without restarting. `--dev-lead-in=N` opens on
## the Nth scene; `--dev-screenshot=<png>` saves the screen and quits.

const PORTRAIT_SIZE: float = 200.0
const LINE_WIDTH: float = 520.0

@onready var where_label: Label = $Margin/Column/TitleRow/Where
@onready var narration: Label = $Margin/Column/Narration
@onready var lines_box: VBoxContainer = $Margin/Column/Stage/Lines
@onready var main_portrait: CenterContainer = $Margin/Column/Stage/MainSide/Portrait
@onready var main_name: Label = $Margin/Column/Stage/MainSide/Name
@onready var opponent_portrait: CenterContainer = $Margin/Column/Stage/OpponentSide/Portrait
@onready var opponent_name: Label = $Margin/Column/Stage/OpponentSide/Name
@onready var prev_button: Button = $Margin/Column/Footer/Prev
@onready var next_button: Button = $Margin/Column/Footer/Next
@onready var reload_button: Button = $Margin/Column/Footer/Reload
@onready var skip_button: Button = $Margin/Column/Footer/Skip
@onready var continue_button: Button = $Margin/Column/Footer/Continue

var _browse: bool = false
var _scenes: Array[Dictionary] = []
var _index: int = 0
var _scene: Dictionary = {}
var _revealed: int = 0


func _ready() -> void:
	theme = SanctumUI.theme()
	SanctumUI.dress(self, $Margin/Column/TitleRow/Title as Label)
	_browse = Session.lead_in.is_empty() or AdventureDev.has_flag("--dev-lead-ins")
	prev_button.visible = _browse
	next_button.visible = _browse
	reload_button.visible = _browse
	skip_button.visible = not _browse
	continue_button.visible = not _browse
	prev_button.pressed.connect(func() -> void: _step(-1))
	next_button.pressed.connect(func() -> void: _step(1))
	reload_button.pressed.connect(_reload)
	skip_button.pressed.connect(_to_duel)
	continue_button.pressed.connect(_advance)
	if _browse:
		_scenes = AdventureLeadIns.all_scenes()
		_index = clampi(int(AdventureDev.flag("--dev-lead-in=")), 0, maxi(0, _scenes.size() - 1))
		_show(_scenes[_index] if not _scenes.is_empty() else {})
	else:
		_show(Session.lead_in)
	SanctumUI.wire_buttons(self)
	(next_button if _browse else continue_button).grab_focus()
	AdventureDev.screenshot(self)


func _unhandled_input(event: InputEvent) -> void:
	if _browse and event.is_action_pressed("ui_left"):
		_step(-1)
	elif _browse and event.is_action_pressed("ui_right"):
		_step(1)
	elif _browse and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_F5:
		_reload()
	else:
		return
	get_viewport().set_input_as_handled()


func _show(scene: Dictionary) -> void:
	_scene = scene
	_revealed = 0
	var main: String = str(scene.get("main", ""))
	var opponent: String = str(scene.get("opponent", ""))
	narration.text = str(scene.get("narration", ""))
	main_name.text = main
	opponent_name.text = opponent
	_set_portrait(main_portrait, main)
	_set_portrait(opponent_portrait, opponent)
	if _browse:
		where_label.text = "%s     %d / %d" % [str(scene.get("title", "")), _index + 1, _scenes.size()]
	else:
		where_label.text = ""
	for child in lines_box.get_children():
		child.queue_free()
	if _browse:
		_revealed = (scene.get("lines", []) as Array).size()
		for line in scene.get("lines", []):
			lines_box.add_child(_line_row(line))
	else:
		_advance()


func _set_portrait(slot: CenterContainer, character: String) -> void:
	for child in slot.get_children():
		child.queue_free()
	if character != "":
		slot.add_child(ProgressUI.portrait(character, Session.library, PORTRAIT_SIZE))


## Shows the next line, or starts the duel once every line is up.
func _advance() -> void:
	var lines: Array = _scene.get("lines", [])
	if _revealed >= lines.size():
		_to_duel()
		return
	lines_box.add_child(_line_row(lines[_revealed]))
	_revealed += 1
	continue_button.text = "Fight!" if _revealed >= lines.size() else "Continue"


## One spoken line: the speaker's name over the text, leaning toward their portrait. A whisper
## sits in the middle with no name.
func _line_row(line: Dictionary) -> Control:
	var side: String = str(line.get("side", AdventureLeadIns.SIDE_ALLY))
	var row: HBoxContainer = HBoxContainer.new()
	var box: PanelContainer = PanelContainer.new()
	box.custom_minimum_size.x = LINE_WIDTH
	var border: Color = ZenithTheme.BORDER
	if side == AdventureLeadIns.SIDE_MAIN:
		border = ZenithTheme.DEFEND
	elif side == AdventureLeadIns.SIDE_OPPONENT:
		border = ZenithTheme.ATTACK
	box.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG, border, ZenithTheme.RADIUS, 1, 16, 10))
	var column: VBoxContainer = VBoxContainer.new()
	var speaker: String = str(line.get("speaker", ""))
	if speaker != "":
		var name_label: Label = Label.new()
		name_label.text = speaker
		name_label.theme_type_variation = &"CaptionLabel"
		column.add_child(name_label)
	var text: Label = Label.new()
	text.text = str(line.get("text", ""))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if side == AdventureLeadIns.SIDE_WHISPER:
		text.add_theme_color_override("font_color", ZenithTheme.MUTED)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	column.add_child(text)
	box.add_child(column)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if side == AdventureLeadIns.SIDE_OPPONENT:
		row.add_child(gap)
		row.add_child(box)
	elif side == AdventureLeadIns.SIDE_MAIN:
		row.add_child(box)
		row.add_child(gap)
	else:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(box)
	return row


func _step(delta: int) -> void:
	if _scenes.is_empty():
		return
	_index = posmod(_index + delta, _scenes.size())
	_show(_scenes[_index])


## Reads the file again and keeps the same place, so an edit shows without restarting.
func _reload() -> void:
	_scenes = AdventureLeadIns.all_scenes()
	_index = clampi(_index, 0, maxi(0, _scenes.size() - 1))
	_show(_scenes[_index] if not _scenes.is_empty() else {})


func _to_duel() -> void:
	if _browse:
		return
	Session.lead_in = {}
	Session.go_to_duel()
