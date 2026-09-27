class_name LeadInOverlay
extends CanvasLayer
## The pre-duel lead-in, played over the duel scene while the camera flies in and the card faces
## render: the context line just above the two portraits and, between them, one spoken line at a
## time. A click, Continue or Enter shows the next line; the last one reads Fight!. Skip ends it
## at once. Either way `finished` fires as the overlay starts to fade.

signal finished

const PORTRAIT_SIZE: float = 200.0
const FADE_IN: float = 0.4
const FADE_OUT: float = 0.3
const UNLIT: Color = Color(0.45, 0.45, 0.45)
const LINE_PAD: int = 22

@onready var root: Control = $Root
@onready var narration: Label = $Root/Margin/Column/Stage/Middle/Narration
@onready var main_portrait: CenterContainer = $Root/Margin/Column/Stage/MainSide/Portrait
@onready var main_name: Label = $Root/Margin/Column/Stage/MainSide/Name
@onready var main_side: Control = $Root/Margin/Column/Stage/MainSide
@onready var opponent_portrait: CenterContainer = $Root/Margin/Column/Stage/OpponentSide/Portrait
@onready var opponent_name: Label = $Root/Margin/Column/Stage/OpponentSide/Name
@onready var opponent_side: Control = $Root/Margin/Column/Stage/OpponentSide
@onready var line_panel: PanelContainer = $Root/Margin/Column/Stage/Middle/Line
@onready var speaker: Label = $Root/Margin/Column/Stage/Middle/Line/Column/Speaker
@onready var line_text: Label = $Root/Margin/Column/Stage/Middle/Line/Column/Text
@onready var skip_button: Button = $Root/Margin/Column/Footer/Skip
@onready var continue_button: Button = $Root/Margin/Column/Footer/Continue

var _lines: Array = []
var _shown: int = 0
var _playing: bool = false


func _ready() -> void:
	root.theme = SanctumUI.theme()
	# The context line is flavour: smaller, muted, on a soft unframed plate under the spoken line's frame.
	narration.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.SCRIM, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, LINE_PAD, 8))
	narration.add_theme_color_override("font_color", ZenithTheme.MUTED)
	narration.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
	line_panel.add_theme_stylebox_override("panel", MapArt.panel_box(LINE_PAD, ZenithTheme.FRAME))
	root.gui_input.connect(_on_root_input)
	skip_button.pressed.connect(close)
	continue_button.pressed.connect(advance)
	SanctumUI.wire_buttons(self)


## Shows `scene` (an AdventureLeadIns.pick result) from its first line.
func play(scene: Dictionary, library: CardLibrary) -> void:
	var main: String = str(scene.get("main", ""))
	var opponent: String = str(scene.get("opponent", ""))
	narration.text = str(scene.get("narration", ""))
	narration.visible = narration.text != ""
	main_name.text = main
	opponent_name.text = opponent
	_set_portrait(main_portrait, main, library, false)
	_set_portrait(opponent_portrait, opponent, library, true)
	_lines = scene.get("lines", [])
	_shown = 0
	_playing = true
	visible = true
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, FADE_IN)
	advance()
	continue_button.grab_focus()


func playing() -> bool:
	return _playing


## Shows the next line, or closes once every line has been up.
func advance() -> void:
	if not _playing:
		return
	if _shown >= _lines.size():
		close()
		return
	_show_line(_lines[_shown])
	_shown += 1
	continue_button.text = "Fight!" if _shown >= _lines.size() else "Continue"


func close() -> void:
	if not _playing:
		return
	_playing = false
	finished.emit()
	var fade: Tween = create_tween()
	fade.tween_property(root, "modulate:a", 0.0, FADE_OUT)
	fade.finished.connect(func() -> void: visible = false)


## The speaker's portrait is lit and their name takes their side's colour. An Ally's line lights
## neither portrait; a whisper has no name and sits muted.
func _show_line(line: Dictionary) -> void:
	var side: String = str(line.get("side", AdventureLeadIns.SIDE_ALLY))
	var ink: Color = ZenithTheme.TEXT
	if side == AdventureLeadIns.SIDE_MAIN:
		ink = ZenithTheme.DEFEND
	elif side == AdventureLeadIns.SIDE_OPPONENT:
		ink = ZenithTheme.ATTACK
	speaker.add_theme_color_override("font_color", ink)
	speaker.text = str(line.get("speaker", ""))
	speaker.visible = speaker.text != ""
	line_text.text = str(line.get("text", ""))
	var whisper: bool = side == AdventureLeadIns.SIDE_WHISPER
	line_text.add_theme_color_override("font_color", ZenithTheme.MUTED if whisper else ZenithTheme.TEXT)
	line_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if whisper else HORIZONTAL_ALIGNMENT_LEFT
	main_side.modulate = Color.WHITE if side == AdventureLeadIns.SIDE_MAIN else UNLIT
	opponent_side.modulate = Color.WHITE if side == AdventureLeadIns.SIDE_OPPONENT else UNLIT


## The opponent's portrait is mirrored so the two face each other across the line.
func _set_portrait(slot: CenterContainer, character: String, library: CardLibrary, mirrored: bool) -> void:
	for child in slot.get_children():
		child.queue_free()
	if character != "":
		slot.add_child(ProgressUI.portrait(character, library, PORTRAIT_SIZE, false, mirrored))


func _on_root_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		advance()
		root.accept_event()
