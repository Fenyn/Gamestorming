class_name BacklineRail
extends PanelContainer
## One seat's off-field cards as a screen-edge panel: Mastery, Relic and Reserve, and the two
## public piles. They leave the felt to the fighters without becoming a list. Each well is an
## empty frame with a caption; the real card is pinned behind it by the table, so it keeps its
## art, its hover preview and its click. Everything here ignores the pointer so the card under
## the well answers it, except an empty pile, which has no card to click.

signal pile_opened(player: int, zone: StringName)

## Well order, filling the grid left to right, top to bottom.
const ROWS: Array[StringName] = [&"mastery", &"relic", &"discard", &"removed"]
const CAPTIONS: Dictionary = {&"mastery": "MASTERY", &"relic": "RELIC", &"discard": "DISCARD", &"removed": "OUT"}

@onready var title: Label = $Column/Title
@onready var rows: GridContainer = $Column/Rows

var player: int = -1
var _frames: Dictionary = {}      # zone -> Panel the card is pinned behind
var _captions: Dictionary = {}    # zone -> Label under it


func _ready() -> void:
	for i in range(ROWS.size()):
		var zone: StringName = ROWS[i]
		var well: VBoxContainer = rows.get_child(i)
		_frames[zone] = well.get_node("Frame")
		_captions[zone] = well.get_node("Caption")
		(_frames[zone] as Panel).gui_input.connect(_on_frame_input.bind(zone))
		_set_frame(zone, false)


## Only reached for an empty pile: with no card in the well, the frame itself takes the pointer
## so the browser is still one click away.
func _on_frame_input(event: InputEvent, zone: StringName) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and (zone == &"discard" or zone == &"removed"):
		accept_event()
		pile_opened.emit(player, zone)


## Fills the captions for one seat. `prompt` is the viewer's pending decision, so a Mastery this
## seat may use now frames in the accent a legal table card carries. The seat colour is passed
## in; the rail renders what it is handed and reads no session state of its own.
func refresh(view: SeatView, seat: int, viewer: int, prompt: PromptView, accent: Color) -> void:
	player = seat
	var p: SeatPlayer = view.player(seat)
	title.text = "%s  ·  %s" % [p.name.to_upper(), "YOU" if seat == viewer else "OPPONENT"]
	title.add_theme_color_override("font_color", accent)
	# The two rails sit one above the other, so each carries its seat's colour as a standing edge:
	# which backline you are looking at reads without going back to the caption.
	var edge: StyleBoxFlat = StyleBoxFlat.new()
	edge.bg_color = Color(0.02, 0.03, 0.05, 0.35)
	edge.set_corner_radius_all(10)
	edge.border_width_left = 3
	edge.border_color = Color(accent, 0.85)
	edge.content_margin_left = 12.0
	edge.content_margin_right = 10.0
	edge.content_margin_top = 8.0
	edge.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", edge)
	_fill_card(&"mastery", p.mastery, prompt)
	_fill_card(&"relic", p.relic, prompt, p.reserve.size())
	_fill_count(&"discard", p.discard.size())
	_fill_count(&"removed", p.removed.size())


func _fill_card(zone: StringName, uid: int, prompt: PromptView, reserve: int = -1) -> void:
	var caption: Label = _captions[zone]
	caption.text = str(CAPTIONS[zone]) if reserve <= 0 else "%s · %d" % [str(CAPTIONS[zone]), reserve]
	caption.add_theme_color_override("font_color", ZenithTheme.TEXT if uid >= 0 else ZenithTheme.MUTED)
	_set_frame(zone, uid >= 0 and prompt != null and not prompt.options_for_card(uid).is_empty())
	(_frames[zone] as Panel).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _fill_count(zone: StringName, count: int) -> void:
	var caption: Label = _captions[zone]
	caption.text = "%s %d" % [str(CAPTIONS[zone]), count]
	caption.add_theme_color_override("font_color", ZenithTheme.MUTED if count == 0 else ZenithTheme.TEXT)
	_set_frame(zone, false)
	# With cards in it the stack answers the pointer itself; empty, the frame stands in for it.
	(_frames[zone] as Panel).mouse_filter = Control.MOUSE_FILTER_STOP if count == 0 else Control.MOUSE_FILTER_IGNORE


## An empty frame: a border and a dark well, so the card pinned behind it reads through.
func _set_frame(zone: StringName, usable: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.25)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2 if usable else 1)
	style.border_color = ZenithTheme.ACCENT if usable else ZenithTheme.BORDER
	(_frames[zone] as Panel).add_theme_stylebox_override("panel", style)


## Screen point the zone's cards are pinned to.
func row_anchor(zone: StringName) -> Vector2:
	var frame: Control = _frames.get(zone)
	return frame.get_global_rect().get_center() if frame != null else Vector2.ZERO


## How tall a card may be drawn in a well, in pixels.
func well_height() -> float:
	var frame: Control = _frames.get(&"mastery")
	return frame.size.y if frame != null and frame.size.y > 1.0 else 117.0
