class_name TutorialPanel
extends Control
## The tutorial's voices over the table. Vale coaches from a small box that docks beside what he
## means, with a glowing thread from the box and a ring round the spot. Narration runs in a ribbon
## at the top; Emrys, and Caedan once he fights, shout in bubbles at their own duelist cards; Vale's
## passing notes sit in a bubble beside what they are about. A stop plays its lines on a
## `TutorialPacing` clock and goes on by itself: a click on the box, Space or Enter skips ahead, and
## the pointer on the box pauses it. An instruction stays up until its move is made. While the
## pointer rests on a greyed option, the reason it is greyed takes the instruction's place.

signal advanced

enum Mode { IDLE, STOP, MOVE }
enum Slot { ABOVE, ABOVE_LEFT, ABOVE_RIGHT, LEFT, RIGHT, BELOW }

const COACH_WIDTH: float = 440.0
const TEXT_MIN: float = 120.0
const COACH_CHROME: float = 44.0 + 12.0 + 32.0   # face chip, row gap, frame padding
const HINT_ROOM: float = 24.0                      # the hint stays clear of the frame's corner
const GAP: float = 16.0
const SAFE_INSET: float = 16.0
const SAFE_TOP: float = 60.0
const SAFE_LEFT: float = 100.0
const HOME: Vector2 = Vector2(100.0, 64.0)
const SIDE_REACH: float = 16.0      # a box beside its target may also start this far below it or end this far above
const RESLOT: float = 24.0
const SMOOTHING: float = 12.0
const SLIDE_RANGE: float = 200.0
const TETHER_MIN: float = 48.0
const TETHER_BOW: float = 0.12
const TETHER_GROW: float = 6.0
const TETHER_CHEVRON: Vector2 = Vector2(14.0, 8.0)
const NOTCH: Vector2 = Vector2(14.0, 18.0)          # reach out of the box, width at the box
const ENTER_TIME: float = 0.16
const ENTER_SCALE: float = 0.92
const TETHER_DELAY: float = 0.08
const TETHER_TIME: float = 0.22
const RING_DELAY: float = 0.22
const RING_TIME: float = 0.12
const LEAVE_TIME: float = 0.12
const LEAVE_DROP: float = 6.0
const CROSSFADE: float = 0.1
const SWAP_TIME: float = 0.09
const REASON_LINGER: float = 0.4
const REFUSE_TIME: float = 0.24
const REFUSE_SHAKE: float = 6.0
const REFUSE_PULSE: float = 1.06
const PREVIEW_ALPHA: float = 0.35
const CAPTION_FADE: float = 0.15
## A bubble in a stop outlasts its line by this much, so the reply pops beside it.
const LINGER: float = 1.0
const CAPTION_PAD: float = 220.0
const RING_GROW: float = 6.0
const RING_WIDTH: int = 4
const SMALL_RING: float = 44.0
const PULSE_SPEED: float = 3.2
const NUDGE: float = 4.0
const TETHER_COLOR: Color = Color(ZenithTheme.TEXT, 0.8)
const DEFAULT_SLOTS: Array[int] = [Slot.ABOVE, Slot.ABOVE_LEFT, Slot.ABOVE_RIGHT, Slot.LEFT, Slot.RIGHT, Slot.BELOW]
## The box's preferred sides of each kind of target, best first.
const SLOTS: Dictionary = {
	"hand": [Slot.ABOVE_LEFT, Slot.ABOVE, Slot.ABOVE_RIGHT, Slot.LEFT, Slot.RIGHT],
	"number": [Slot.ABOVE_LEFT, Slot.ABOVE, Slot.ABOVE_RIGHT, Slot.LEFT, Slot.RIGHT],
	"text": [Slot.ABOVE_LEFT, Slot.ABOVE, Slot.ABOVE_RIGHT, Slot.LEFT, Slot.RIGHT],
	"ladder": [Slot.RIGHT, Slot.LEFT, Slot.ABOVE, Slot.BELOW],
	"fervor": [Slot.LEFT, Slot.RIGHT, Slot.ABOVE_LEFT, Slot.ABOVE],
	"aspect": [Slot.LEFT, Slot.RIGHT, Slot.ABOVE_LEFT, Slot.ABOVE],
	"power": [Slot.LEFT, Slot.RIGHT, Slot.BELOW, Slot.ABOVE],
	"duelist": [Slot.LEFT, Slot.RIGHT, Slot.BELOW, Slot.ABOVE],
	"prompt": [Slot.LEFT, Slot.ABOVE, Slot.BELOW],
	"drill": [Slot.ABOVE, Slot.LEFT, Slot.RIGHT, Slot.BELOW],
}
## Emrys' bubble stands beside the top of his card and the rival's over theirs, so the two read as
## an exchange across the table.
const YOU_SLOTS: Array[int] = [Slot.RIGHT, Slot.LEFT, Slot.ABOVE]
const RIVAL_SLOTS: Array[int] = [Slot.ABOVE, Slot.LEFT, Slot.RIGHT, Slot.BELOW]
const YOU_LEVEL: float = 0.3
const RIVAL_LEVEL: float = 0.5
const NOTE_SLOTS: Array[int] = [Slot.ABOVE, Slot.RIGHT, Slot.LEFT, Slot.BELOW]

@onready var lesson_label: Label = $LessonTag
@onready var thread: Line2D = $Tether/Thread
@onready var head: Line2D = $Tether/Head
@onready var caption: Control = $Caption
@onready var caption_text: Label = $Caption/Text
@onready var coach: PanelContainer = $Coach
@onready var face_frame: PanelContainer = $Coach/Row/Face
@onready var portrait: TextureRect = $Coach/Row/Face/Portrait
@onready var column: VBoxContainer = $Coach/Row/Column
@onready var text: Label = $Coach/Row/Column/Text
@onready var reason_label: Label = $Coach/Row/Column/Reason
@onready var hint: Label = $Coach/Row/Column/Hint
@onready var timer: Control = $Coach/Row/Column/Timer
@onready var timer_fill: ColorRect = $Coach/Row/Column/Timer/Fill
@onready var bark_you: BarkBubble = $Barks/BarkYou
@onready var bark_rival: BarkBubble = $Barks/BarkRival
@onready var bark_note: BarkBubble = $Barks/BarkNote

## Where a target is on screen, from its name: {"ring": the Rect2 to ring, "body": the Rect2 to stand
## clear of}. Read every frame, so everything follows the camera and the cards.
var locate: Callable = Callable()
## Screen rectangles the box and the bubbles keep off: the decision panel, the rail, the duelist
## cards and their piles, the hand.
var keepouts: Callable = Callable()
## The hand's enlarged preview card, Rect2() when none: the box fades while under it.
var preview: Callable = Callable()
## The open tray's panel, Rect2() when none is open: the box docks above its top left corner.
var modal: Callable = Callable()
## True while the table wants the clock stopped (the inspect overlay is up).
var holding: Callable = Callable()
## True while the table's own attack filament shows, so the thread bows the other way.
var filament_shown: Callable = Callable()
var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if is_node_ready():
			for b: BarkBubble in [bark_you, bark_rival, bark_note]:
				b.reduced_motion = value

var _mode: Mode = Mode.IDLE
var _rings: Array[String] = []
var _pacing: TutorialPacing = null
var _lines: Array[Dictionary] = []
var _shown_line: int = -1
var _reason: String = ""
var _reason_linger: float = 0.0
var _idle: float = 0.0
var _time: float = 0.0
var _coach_on: bool = false
var _coach_alpha: float = 0.0
var _coach_pos: Vector2 = HOME
var _drop: float = 0.0
var _shake: float = 0.0
var _ring_alpha: float = 0.0
var _ring_scale: float = 1.0
var _reveal: float = 1.0
var _caption_left: float = 0.0
var _goal: Vector2 = HOME
var _slot_key: String = ""
var _slot_at: Vector2 = Vector2(-9999.0, -9999.0)
var _slot_size: Vector2 = Vector2.ZERO
var _slot_outs: int = -1
var _notch: PackedVector2Array = PackedVector2Array()
var _coach_tween: Tween = null
var _text_tween: Tween = null
var _caption_tween: Tween = null
var _pulse_tween: Tween = null


func _ready() -> void:
	theme = SanctumUI.theme()
	coach.add_theme_stylebox_override("panel", MapArt.panel_box(12, ZenithTheme.FRAME))
	face_frame.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.BORDER, ZenithTheme.RADIUS, 1, 0, 0))
	lesson_label.add_theme_color_override("font_color", ZenithTheme.MUTED)
	text.add_theme_color_override("font_color", ZenithTheme.TEXT)
	reason_label.add_theme_color_override("font_color", ZenithTheme.WARN)
	hint.add_theme_color_override("font_color", ZenithTheme.MUTED)
	caption_text.add_theme_color_override("font_color", ZenithTheme.TEXT_SOFT)
	timer_fill.color = Color(ZenithTheme.ACCENT, 0.55)
	head.default_color = TETHER_COLOR
	(thread.material as ShaderMaterial).set_shader_parameter("tint", TETHER_COLOR)
	coach.gui_input.connect(_on_coach_input)
	visible = false


func set_lesson(line: String) -> void:
	lesson_label.text = line


## One line from the coach box. `click` makes it a stop the table waits on; otherwise it is the
## instruction for the move now asked, over the rings already set.
func say(_who: String, face: Texture2D, line: String, click: bool) -> void:
	if click:
		var one: Array[Dictionary] = [{"at": "coach", "text": line, "face": face, "rings": _rings.duplicate()}]
		play_stop(one, false)
	else:
		instruct(line, face, _rings.duplicate())


## The words for the move the player is asked to make, beside `rings`, until the move is made.
## "" takes the box down and leaves the rings.
func instruct(line: String, face: Texture2D, rings: Array[String]) -> void:
	visible = true
	_mode = Mode.MOVE
	_pacing = null
	_idle = 0.0
	# Nothing to skip in an instruction, so the box never takes a click meant for the table.
	coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_rings(rings)
	hint.visible = false
	timer.visible = false
	_clear_reason()
	if line == "":
		_coach_leave()
		return
	_coach_show(line, face)
	_reveal_text(TutorialPacing.reveal_time(line))


## Lines said while the table waits, each {at, text, face, rings}: `coach` in the box, `caption`
## in the ribbon, `you` and `rival` in bubbles at the duelist cards. `advanced` fires once the last
## is done, or on the click that ends a stop that `hold`s.
func play_stop(lines: Array[Dictionary], hold: bool) -> void:
	visible = true
	_mode = Mode.STOP
	coach.mouse_filter = Control.MOUSE_FILTER_STOP
	_lines = lines
	_clear_reason()
	var times: Array[float] = []
	var reveals: Array[float] = []
	for l in lines:
		var at: String = str(l.get("at", "coach"))
		times.append(TutorialPacing.line_time(at, str(l.get("text", ""))))
		reveals.append(TutorialPacing.reveal_time(str(l.get("text", ""))) if at == "coach" else 0.0)
	_pacing = TutorialPacing.new(times, reveals, hold)
	_shown_line = -1
	if lines.is_empty() or str(lines[0].get("at", "")) != "coach":
		_set_rings([])
		_coach_leave()
	_show_line()


## A line said in passing, which shows and fades by itself while play goes on. `at` as in
## `play_stop`; a `coach` line is a note in a bubble beside the first of `rings`.
func bark(at: String, line: String, face: Texture2D, rings: Array[String]) -> void:
	visible = true
	match at:
		"you":
			bark_you.pop(line, null, TutorialPacing.bark_time(line), "bark:you")
		"rival":
			bark_rival.pop(line, null, TutorialPacing.bark_time(line), "bark:rival")
		"caption":
			_caption_show(line)
			_caption_left = TutorialPacing.read_time(line)
		_:
			if not rings.is_empty():
				bark_note.pop(line, face, TutorialPacing.read_time(line), rings[0])


## The move was made: the box drops away before the move plays.
func leave() -> void:
	_mode = Mode.IDLE
	_clear_reason()
	_set_rings([])
	_coach_leave()


## Everything down, for the end of the session.
func clear() -> void:
	leave()
	_caption_hide()
	for b: BarkBubble in [bark_you, bark_rival, bark_note]:
		b.dismiss()


## The reason a greyed option is greyed, in place of the instruction; "" puts the instruction back
## a moment later.
func show_reason(line: String) -> void:
	if line == "":
		if _reason != "":
			_reason_linger = REASON_LINGER
		return
	_reason_linger = 0.0
	if line == _reason:
		return
	_reason = line
	_swap_reason()


## A greyed option was clicked: the box shakes, says why, and the ring pulses on the right move.
func refuse(line: String) -> void:
	show_reason(line)
	_idle = 0.0
	if reduced_motion:
		return
	_shake = REFUSE_TIME
	if _pulse_tween != null:
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "_ring_scale", REFUSE_PULSE, 0.06)
	_pulse_tween.tween_property(self, "_ring_scale", 1.0, 0.06)


func waiting_for_click() -> bool:
	return visible and _mode == Mode.STOP


## Ends the stop now, as a stand-in player without a pointer would (the dev flags and the tests).
func advance() -> void:
	if _mode != Mode.STOP:
		return
	_end_stop()


# --- A stop, line by line ---------------------------------------------------------

func _show_line() -> void:
	if _pacing == null:
		return
	if _pacing.finished():
		_end_stop()
		return
	var i: int = _pacing.line
	if i == _shown_line:
		return
	_shown_line = i
	var l: Dictionary = _lines[i]
	var line: String = str(l.get("text", ""))
	var face: Texture2D = l.get("face") as Texture2D
	var last: bool = i == _lines.size() - 1
	match str(l.get("at", "coach")):
		"coach":
			var rings: Array[String] = []
			for r in l.get("rings", []):
				rings.append(str(r))
			_set_rings(rings)
			hint.visible = _pacing.hold and last
			_coach_show(line, face)
			text.visible_ratio = 0.0
			timer.visible = not (_pacing.hold and last)
		"caption":
			_caption_show(line)
		"you":
			bark_you.pop(line, null, _pacing.times[i] + LINGER, "bark:you")
		"rival":
			bark_rival.pop(line, null, _pacing.times[i] + LINGER, "bark:rival")


func _end_stop() -> void:
	_mode = Mode.IDLE
	_pacing = null
	_caption_hide()
	_set_rings([])
	_coach_leave()
	advanced.emit()


func _skip() -> void:
	if _mode != Mode.STOP or _pacing == null:
		return
	if _pacing.skip():
		_show_line()
	elif _pacing.finished():
		_end_stop()


func _on_coach_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	_skip()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _mode != Mode.STOP:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_skip()


## Any input resets the idle nudge; a click or a key sends a passing note away.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		_idle = 0.0
	var press: InputEventMouseButton = event as InputEventMouseButton
	if (press != null and press.pressed) or (event is InputEventKey and (event as InputEventKey).pressed):
		bark_note.dismiss()


# --- The coach box -------------------------------------------------------------------

func _coach_show(line: String, face: Texture2D) -> void:
	portrait.texture = face
	face_frame.visible = face != null
	var slide: bool = coach.visible and _coach_alpha > 0.5
	_fit_text(line)
	_coach_on = true
	_drop = 0.0
	var goal: Vector2 = _choose_slot(true, _keepouts())
	if slide and goal.distance_to(_coach_pos) <= SLIDE_RANGE:
		_kill(_coach_tween)
		_coach_alpha = 1.0
		coach.scale = Vector2.ONE
		text.text = line
		if not reduced_motion:
			column.modulate.a = 0.0
			_coach_tween = create_tween()
			_coach_tween.tween_property(column, "modulate:a", 1.0, CROSSFADE)
		_ring_alpha = maxf(_ring_alpha, 0.0)
		if _ring_alpha < 1.0:
			_fade_rings_in(0.0)
		return
	text.text = line
	_coach_pos = goal
	coach.visible = true
	column.modulate.a = 1.0
	_enter()


func _enter() -> void:
	_kill(_coach_tween)
	if reduced_motion:
		_coach_alpha = 1.0
		coach.scale = Vector2.ONE
		_set_reveal(1.0)
		_ring_alpha = 1.0
		return
	coach.pivot_offset = _pivot_toward(_ring_union().get_center())
	_coach_alpha = 0.0
	coach.scale = Vector2.ONE * ENTER_SCALE
	_set_reveal(0.0)
	_ring_alpha = 0.0
	_coach_tween = create_tween().set_parallel()
	_coach_tween.tween_property(self, "_coach_alpha", 1.0, ENTER_TIME)
	_coach_tween.tween_property(coach, "scale", Vector2.ONE, ENTER_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_coach_tween.tween_method(_set_reveal, 0.0, 1.0, TETHER_TIME).set_delay(TETHER_DELAY)
	_coach_tween.tween_property(self, "_ring_alpha", 1.0, RING_TIME).set_delay(RING_DELAY)


func _fade_rings_in(delay: float) -> void:
	if reduced_motion:
		_ring_alpha = 1.0
		_set_reveal(1.0)
		return
	var t: Tween = create_tween().set_parallel()
	t.tween_method(_set_reveal, 0.0, 1.0, TETHER_TIME).set_delay(delay)
	t.tween_property(self, "_ring_alpha", 1.0, RING_TIME).set_delay(delay + RING_DELAY - TETHER_DELAY)


func _coach_leave() -> void:
	if not _coach_on:
		return
	_coach_on = false
	_kill(_coach_tween)
	if reduced_motion:
		_coach_alpha = 0.0
		coach.visible = false
		return
	_coach_tween = create_tween().set_parallel()
	_coach_tween.tween_property(self, "_coach_alpha", 0.0, LEAVE_TIME)
	_coach_tween.tween_property(self, "_drop", LEAVE_DROP, LEAVE_TIME)
	_coach_tween.chain().tween_callback(func() -> void:
		if not _coach_on:
			coach.visible = false)


## Sizes the box to its line: as narrow as the words, never wider than COACH_WIDTH.
func _fit_text(line: String) -> void:
	var font: Font = text.get_theme_font("font")
	var font_size: int = text.get_theme_font_size("font_size")
	var room: float = COACH_WIDTH - (COACH_CHROME if face_frame.visible else COACH_CHROME - 56.0)
	var width: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 4.0
	if hint.visible:
		width = maxf(width, hint.get_theme_font("font").get_string_size(hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint.get_theme_font_size("font_size")).x + HINT_ROOM)
	text.custom_minimum_size.x = clampf(width, TEXT_MIN, room)
	reason_label.custom_minimum_size.x = text.custom_minimum_size.x
	coach.reset_size()


func _reveal_text(time: float) -> void:
	_kill(_text_tween)
	if reduced_motion or time <= 0.0:
		text.visible_ratio = 1.0
		return
	text.visible_ratio = 0.0
	_text_tween = create_tween()
	_text_tween.tween_property(text, "visible_ratio", 1.0, time)


func _swap_reason() -> void:
	var on: bool = _reason != ""
	reason_label.text = _reason
	text.visible = not on
	reason_label.visible = on
	if not reduced_motion and coach.visible:
		column.modulate.a = 0.35
		var t: Tween = create_tween()
		t.tween_property(column, "modulate:a", 1.0, SWAP_TIME)


func _clear_reason() -> void:
	_reason_linger = 0.0
	if _reason == "":
		return
	_reason = ""
	_swap_reason()


func _set_reveal(value: float) -> void:
	_reveal = value
	(thread.material as ShaderMaterial).set_shader_parameter("reveal", value)


func _set_rings(rings: Array[String]) -> void:
	_rings = rings


func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()


# --- The caption ---------------------------------------------------------------------

func _caption_show(line: String) -> void:
	caption_text.text = line
	var font: Font = caption_text.get_theme_font("font")
	var width: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_text.get_theme_font_size("font_size")).x
	var half: float = minf(width + CAPTION_PAD, size.x - 200.0) * 0.5
	caption.offset_left = -half
	caption.offset_right = half
	caption.visible = true
	_caption_left = 0.0
	_kill(_caption_tween)
	if reduced_motion:
		caption.modulate.a = 1.0
		return
	caption.modulate.a = 0.0
	_caption_tween = create_tween()
	_caption_tween.tween_property(caption, "modulate:a", 1.0, CAPTION_FADE)


func _caption_hide() -> void:
	if not caption.visible:
		return
	_kill(_caption_tween)
	if reduced_motion:
		caption.visible = false
		return
	_caption_tween = create_tween()
	_caption_tween.tween_property(caption, "modulate:a", 0.0, CAPTION_FADE)
	_caption_tween.tween_callback(caption.hide)


# --- Every frame ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _mode == Mode.STOP and _pacing != null:
		var over_box: bool = coach.visible and coach.get_global_rect().has_point(get_global_mouse_position())
		var hold: bool = holding.is_valid() and bool(holding.call())
		if _pacing.tick(delta, over_box or hold):
			_show_line()
		if _mode == Mode.STOP and _pacing != null:
			if str(_lines[_pacing.line].get("at", "")) == "coach":
				text.visible_ratio = _pacing.revealed()
				timer_fill.size = Vector2(timer.size.x * _pacing.left(), timer.size.y)
	elif _mode == Mode.MOVE:
		_idle += delta
	if _reason_linger > 0.0:
		_reason_linger -= delta
		if _reason_linger <= 0.0:
			_reason = ""
			_swap_reason()
	if _caption_left > 0.0:
		_caption_left -= delta
		if _caption_left <= 0.0 and _mode != Mode.STOP:
			_caption_hide()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
	_layout(delta)
	queue_redraw()


func _layout(delta: float) -> void:
	var outs: Array[Rect2] = _keepouts()
	var placed: Array[Rect2] = []
	if coach.visible:
		coach.reset_size()
		var goal: Vector2 = _choose_slot(false, outs)
		_coach_pos = goal if reduced_motion else _coach_pos.lerp(goal, 1.0 - exp(-SMOOTHING * delta))
		var shake: float = 0.0
		if _shake > 0.0:
			var progress: float = 1.0 - _shake / REFUSE_TIME
			shake = sin(progress * TAU * 3.0) * REFUSE_SHAKE * (1.0 - progress)
		coach.position = _coach_pos + Vector2(shake, _drop)
		var under: Rect2 = preview.call() if preview.is_valid() else Rect2()
		var covered: bool = under.has_area() and under.intersects(coach.get_global_rect())
		coach.modulate.a = _coach_alpha * (PREVIEW_ALPHA if covered else 1.0)
		placed.append(coach.get_global_rect())
	_place_bubble(bark_you, YOU_SLOTS, YOU_LEVEL, outs, placed)
	_place_bubble(bark_rival, RIVAL_SLOTS, RIVAL_LEVEL, outs, placed)
	_place_bubble(bark_note, NOTE_SLOTS, 0.5, outs, placed)
	_draw_tether()


func _keepouts() -> Array[Rect2]:
	var outs: Array[Rect2] = []
	if keepouts.is_valid():
		for r in keepouts.call():
			outs.append(r as Rect2)
	if caption.visible:
		outs.append(caption.get_global_rect())
	return outs


func _safe() -> Rect2:
	return Rect2(SAFE_LEFT, SAFE_TOP, size.x - SAFE_LEFT - SAFE_INSET, size.y - SAFE_TOP - SAFE_INSET)


func _where(target: String) -> Dictionary:
	if not locate.is_valid() or target == "":
		return {"ring": Rect2(), "body": Rect2()}
	return locate.call(target)


func _ring_union() -> Rect2:
	var out: Rect2 = Rect2()
	for target in _rings:
		var r: Rect2 = _where(target)["ring"]
		if r.has_area():
			out = r if not out.has_area() else out.merge(r)
	return out


func _body_union() -> Rect2:
	var out: Rect2 = Rect2()
	for target in _rings:
		var r: Rect2 = _where(target)["body"]
		if r.has_area():
			out = r if not out.has_area() else out.merge(r)
	return out


## Where the box goes: docked above an open tray, else the first free side of what it is about,
## else home. The side is chosen again only when the target moves RESLOT or the table changes.
func _choose_slot(force: bool, outs: Array[Rect2] = []) -> Vector2:
	var box: Vector2 = coach.get_combined_minimum_size()
	var dock: Rect2 = modal.call() if modal.is_valid() else Rect2()
	if dock.has_area():
		return Vector2(clampf(dock.position.x, SAFE_INSET, size.x - SAFE_INSET - box.x), maxf(SAFE_INSET, dock.position.y - GAP - box.y))
	var ring: Rect2 = _ring_union()
	var body: Rect2 = _body_union()
	if not body.has_area():
		body = ring
	if not ring.has_area():
		return HOME
	var key: String = ",".join(_rings)
	var anchor: Vector2 = body.get_center()
	if force or key != _slot_key or anchor.distance_to(_slot_at) > RESLOT or box != _slot_size or outs.size() != _slot_outs:
		_slot_key = key
		_slot_at = anchor
		_slot_size = box
		_slot_outs = outs.size()
		var kind: String = _rings[0].get_slice(":", 0) if not _rings.is_empty() else ""
		var order: Array = SLOTS.get(kind, DEFAULT_SLOTS)
		if kind in ["life_deck", "discard"] and ring.get_center().x > size.x * 0.5:
			order = [Slot.RIGHT, Slot.LEFT, Slot.ABOVE, Slot.BELOW]
		_goal = _best(body, ring.get_center(), box, order, outs, [ring.grow(12.0)])
	return _goal


## The first slot that sits in the safe rect clear of every rectangle in `outs` and `own`, or the one
## that covers least.
func _best(body: Rect2, focus: Vector2, box: Vector2, order: Array, outs: Array[Rect2], own: Array[Rect2]) -> Vector2:
	var safe: Rect2 = _safe()
	var best: Vector2 = Vector2.ZERO
	var best_cost: float = INF
	for slot in order:
		var centred: Vector2 = _slot_position(int(slot), body, focus, box)
		var tries: Array[Vector2] = [centred]
		# Beside a target the box may also hang down from it or stand up on it.
		if int(slot) == Slot.LEFT or int(slot) == Slot.RIGHT:
			tries.append(Vector2(centred.x, focus.y + SIDE_REACH))
			tries.append(Vector2(centred.x, focus.y - SIDE_REACH - box.y))
		for candidate in tries:
			var at: Vector2 = Vector2(clampf(candidate.x, safe.position.x, maxf(safe.position.x, safe.end.x - box.x)), clampf(candidate.y, safe.position.y, maxf(safe.position.y, safe.end.y - box.y)))
			var r: Rect2 = Rect2(at, box)
			var cost: float = _cover(r, outs) + _cover(r, own) * 4.0 + _cover(r, [body.grow(4.0)]) * 4.0
			if cost <= 0.0:
				return at
			if cost < best_cost:
				best_cost = cost
				best = at
	return best


static func _slot_position(slot: int, body: Rect2, focus: Vector2, box: Vector2) -> Vector2:
	match slot:
		Slot.ABOVE:
			return Vector2(focus.x - box.x * 0.5, body.position.y - GAP - box.y)
		Slot.ABOVE_LEFT:
			return Vector2(focus.x + 40.0 - box.x, body.position.y - GAP - box.y)
		Slot.ABOVE_RIGHT:
			return Vector2(focus.x - 40.0, body.position.y - GAP - box.y)
		Slot.LEFT:
			return Vector2(body.position.x - GAP - box.x, focus.y - box.y * 0.5)
		Slot.RIGHT:
			return Vector2(body.end.x + GAP, focus.y - box.y * 0.5)
	return Vector2(focus.x - box.x * 0.5, body.end.y + GAP)


static func _cover(r: Rect2, outs: Array) -> float:
	var total: float = 0.0
	for o in outs:
		var clip: Rect2 = r.intersection(o as Rect2)
		total += clip.get_area()
	return total


func _place_bubble(b: BarkBubble, order: Array, level: float, outs: Array[Rect2], placed: Array[Rect2]) -> void:
	if not b.visible:
		return
	var where: Dictionary = _where(b.anchor) if b.anchor != "" else {}
	var body: Rect2 = where.get("body", Rect2())
	var ring: Rect2 = where.get("ring", Rect2())
	if not body.has_area():
		body = ring
	if not body.has_area():
		placed.append(Rect2(b.home, b.size))
		return
	var focus: Vector2 = ring.get_center() if b == bark_note else Vector2(body.get_center().x, body.position.y + body.size.y * level)
	var all: Array[Rect2] = outs.duplicate()
	all.append_array(placed)
	b.home = _best(body, focus, b.size, order, all, [])
	var aim_at: Rect2 = ring if ring.has_area() else body
	b.aim = Vector2(clampf(b.home.x + b.size.x * 0.5, aim_at.position.x, aim_at.end.x), clampf(b.home.y + b.size.y * 0.5, aim_at.position.y, aim_at.end.y))
	placed.append(Rect2(b.home, b.size))


func _pivot_toward(point: Vector2) -> Vector2:
	var box: Vector2 = coach.get_combined_minimum_size()
	if point == Vector2.ZERO:
		return box * 0.5
	var local: Vector2 = point - _coach_pos
	return Vector2(clampf(local.x, 0.0, box.x), clampf(local.y, 0.0, box.y))


# --- The thread and the rings ---------------------------------------------------------

## From the middle of the box's edge nearest the target to the nearest point of the ring. Close by,
## a notch on the box's edge points instead.
func _draw_tether() -> void:
	_notch = PackedVector2Array()
	var target: Rect2 = _ring_union()
	if not _coach_on or not coach.visible or not target.has_area():
		thread.visible = false
		head.visible = false
		return
	var box: Rect2 = coach.get_global_rect()
	var aim: Rect2 = target.grow(TETHER_GROW)
	var centre: Vector2 = box.get_center()
	var end: Vector2 = Vector2(clampf(centre.x, aim.position.x, aim.end.x), clampf(centre.y, aim.position.y, aim.end.y))
	if box.has_point(end):
		thread.visible = false
		head.visible = false
		return
	var start: Vector2 = _edge_middle(box, end)
	var gap: float = start.distance_to(end)
	var alpha: float = coach.modulate.a
	if gap < TETHER_MIN:
		thread.visible = false
		head.visible = false
		var out: Vector2 = (end - start).normalized()
		var side: Vector2 = Vector2(-out.y, out.x)
		_notch = PackedVector2Array([start - side * NOTCH.y * 0.5, start + side * NOTCH.y * 0.5, start + out * minf(NOTCH.x, gap)])
		return
	var direction: Vector2 = (end - start) / gap
	var flip: bool = filament_shown.is_valid() and bool(filament_shown.call())
	var bend: Vector2 = Vector2(-direction.y, direction.x) * gap * TETHER_BOW * (-1.0 if flip else 1.0)
	var points: PackedVector2Array = DuelHud.bezier(start, end, bend)
	thread.points = points
	thread.modulate.a = alpha
	thread.visible = true
	var tip: Vector2 = points[points.size() - 1]
	head.points = DuelHud.chevron(tip, (tip - points[points.size() - 3]).normalized(), TETHER_CHEVRON)
	head.modulate.a = alpha
	head.visible = _reveal >= 0.99


static func _edge_middle(box: Rect2, toward: Vector2) -> Vector2:
	var centre: Vector2 = box.get_center()
	var d: Vector2 = toward - centre
	if absf(d.x) * box.size.y >= absf(d.y) * box.size.x:
		return Vector2(box.end.x if d.x > 0.0 else box.position.x, centre.y)
	return Vector2(centre.x, box.end.y if d.y > 0.0 else box.position.y)


func _draw() -> void:
	if _notch.size() == 3:
		draw_colored_polygon(_notch, Color(ZenithTheme.FRAME, coach.modulate.a))
	if _ring_alpha <= 0.0 or _rings.is_empty():
		return
	var nudging: bool = _mode == Mode.MOVE and _idle >= TutorialPacing.IDLE_NUDGE and not reduced_motion
	var glow: float = 0.8 + 0.2 * sin(_time * PULSE_SPEED * (2.0 if nudging else 1.0))
	var bob: float = -NUDGE * absf(sin(_time * 5.0)) if nudging else 0.0
	for target in _rings:
		var r: Rect2 = _where(target)["ring"]
		if not r.has_area():
			continue
		var small: bool = minf(r.size.x, r.size.y) < SMALL_RING
		var width: int = 2 if small else RING_WIDTH
		r = r.grow(2.0 if small else RING_GROW)
		if not is_equal_approx(_ring_scale, 1.0):
			var centre: Vector2 = r.get_center()
			r = Rect2(centre - r.size * 0.5 * _ring_scale, r.size * _ring_scale)
		r.position.y += bob
		var radius: int = 8 if small else 14
		if not small:
			var halo: StyleBoxFlat = ZenithTheme.box(Color(0, 0, 0, 0), Color(ZenithTheme.ACCENT, glow * 0.3 * _ring_alpha), 18, width * 2, 0, 0)
			draw_style_box(halo, r.grow(width * 2))
		# A hairline of shadow either side of the bright line, so it reads on a pale card face too.
		var shadow: StyleBoxFlat = ZenithTheme.box(Color(0, 0, 0, 0), Color(ZenithTheme.BG_SCREEN, 0.6 * _ring_alpha), radius + 1, width + 2, 0, 0)
		draw_style_box(shadow, r.grow(1.0))
		var edge: StyleBoxFlat = ZenithTheme.box(Color(0, 0, 0, 0), Color(ZenithTheme.ACCENT, glow * _ring_alpha), radius, width, 0, 0)
		draw_style_box(edge, r)
