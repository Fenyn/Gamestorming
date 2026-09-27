extends Control
## A browser over every lead-in scene in data/adventure/lead_ins.json, with all lines shown,
## Previous and Next, and Reload to pick up edits to the file without restarting. In a run the
## lead-ins play over the duel's opening instead (LeadInOverlay). `--dev-lead-in=N` opens on the
## Nth scene; `--dev-screenshot=<png>` saves the screen and quits.

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

var _scenes: Array[Dictionary] = []
var _index: int = 0


func _ready() -> void:
	theme = SanctumUI.theme()
	SanctumUI.dress(self, $Margin/Column/TitleRow/Title as Label)
	prev_button.pressed.connect(func() -> void: _step(-1))
	next_button.pressed.connect(func() -> void: _step(1))
	reload_button.pressed.connect(_reload)
	_scenes = AdventureLeadIns.all_scenes()
	_index = clampi(int(AdventureDev.flag("--dev-lead-in=")), 0, maxi(0, _scenes.size() - 1))
	_show(_scenes[_index] if not _scenes.is_empty() else {})
	SanctumUI.wire_buttons(self)
	next_button.grab_focus()
	AdventureDev.screenshot(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_step(-1)
	elif event.is_action_pressed("ui_right"):
		_step(1)
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_F5:
		_reload()
	else:
		return
	get_viewport().set_input_as_handled()


func _show(scene: Dictionary) -> void:
	var main: String = str(scene.get("main", ""))
	var opponent: String = str(scene.get("opponent", ""))
	narration.text = str(scene.get("narration", ""))
	main_name.text = main
	opponent_name.text = opponent
	_set_portrait(main_portrait, main, false)
	_set_portrait(opponent_portrait, opponent, true)
	where_label.text = "%s     %d / %d" % [str(scene.get("title", "")), _index + 1, _scenes.size()]
	for child in lines_box.get_children():
		child.queue_free()
	for line in scene.get("lines", []):
		lines_box.add_child(_line_row(line))


## The opponent's portrait is mirrored so the two face each other.
func _set_portrait(slot: CenterContainer, character: String, mirrored: bool) -> void:
	for child in slot.get_children():
		child.queue_free()
	if character != "":
		slot.add_child(ProgressUI.portrait(character, Session.library, PORTRAIT_SIZE, false, mirrored))


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
