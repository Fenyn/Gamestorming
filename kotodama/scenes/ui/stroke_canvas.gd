class_name StrokeCanvas
extends Control
## Square paper. Strokes drawn with the mouse are checked in order against KanjiVG strokes.

signal stroke_done(index: int, ok: bool)
signal finished(passed: bool)
signal order_played

enum Guide { NONE, FIRST_START, FULL }

const SIZE: float = 256.0
const PAPER: Color = Color("f4ecd8")
const PAPER_LINE: Color = Color("d8ccb0")
const INK: Color = Color("1e1928")
const GUIDE_COLOR: Color = Color(0.45, 0.4, 0.5, 0.35)
const WRONG: Color = Color("c0392b")
const PLAY: Color = Color("2a6fb0")
const START_DOT: float = 6.0
const INK_WIDTH: float = 7.0
const GUIDE_WIDTH: float = 5.0

@export var start_tolerance: float = 0.22
@export var end_tolerance: float = 0.22
@export var angle_tolerance_deg: float = 50.0
@export var min_length_ratio: float = 0.4
@export var wrong_limit: int = 2
@export var retries_per_stroke: int = 1
@export var play_seconds_per_stroke: float = 0.6

var expected: Array[PackedVector2Array] = []
var drawn: Array[PackedVector2Array] = []
var guide: int = Guide.NONE
var active: bool = false

var _checker: StrokeCheck
var _current: PackedVector2Array = PackedVector2Array()
var _index: int = 0
var _retries: int = 0
var _wrong: int = 0
var _show_wrong_guide: bool = false
var _playing: bool = false
var _play_progress: float = -1.0
var _play_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_checker = StrokeCheck.new(start_tolerance, end_tolerance, angle_tolerance_deg, min_length_ratio)


## Starts a drawing attempt.
func begin(p_expected: Array[PackedVector2Array], p_guide: int) -> void:
	_reset(p_expected, p_guide)
	active = expected.size() > 0
	queue_redraw()


## Shows the strokes as a faint guide with no drawing.
func show_only(p_expected: Array[PackedVector2Array]) -> void:
	_reset(p_expected, Guide.FULL)
	queue_redraw()


## Animates the expected strokes in order. Emits [signal order_played] at the end.
func play_order() -> void:
	active = false
	_playing = true
	_play_progress = 0.0
	if _play_tween:
		_play_tween.kill()
	_play_tween = create_tween()
	_play_tween.tween_method(_set_play_progress, 0.0, float(expected.size()), play_seconds_per_stroke * expected.size())
	_play_tween.tween_callback(_on_play_done)


func _reset(p_expected: Array[PackedVector2Array], p_guide: int) -> void:
	expected = p_expected
	guide = p_guide
	drawn.clear()
	_current = PackedVector2Array()
	_index = 0
	_retries = 0
	_wrong = 0
	_show_wrong_guide = false
	_playing = false
	_play_progress = -1.0
	active = false
	if _play_tween:
		_play_tween.kill()


func _set_play_progress(value: float) -> void:
	_play_progress = value
	queue_redraw()


func _on_play_done() -> void:
	_playing = false
	order_played.emit()


func _gui_input(event: InputEvent) -> void:
	if not active or _playing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_current = PackedVector2Array([event.position])
		else:
			_finish_stroke()
		accept_event()
		queue_redraw()
	elif event is InputEventMouseMotion and _current.size() > 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_current.append(event.position)
		queue_redraw()


## Feeds a whole stroke in canvas pixels, for tests.
func submit_stroke(points: PackedVector2Array) -> void:
	_current = points
	_finish_stroke()
	queue_redraw()


func _finish_stroke() -> void:
	var stroke: PackedVector2Array = _current
	_current = PackedVector2Array()
	if stroke.size() < 2 or _index >= expected.size():
		return
	var problem: String = _checker.check(StrokeCheck.to_box(stroke, SIZE), expected[_index])
	if problem == "":
		drawn.append(stroke)
		_advance(true)
		return
	_retries += 1
	_show_wrong_guide = true
	if _retries > retries_per_stroke:
		_wrong += 1
		drawn.append(_to_canvas(expected[_index]))
		_advance(false)


func _advance(ok: bool) -> void:
	stroke_done.emit(_index, ok)
	_index += 1
	_retries = 0
	_show_wrong_guide = false
	if _wrong >= effective_wrong_limit():
		active = false
		finished.emit(false)
	elif _index >= expected.size():
		active = false
		finished.emit(true)
	queue_redraw()


## Short kanji fail on one wrong stroke: one per three strokes, capped by [member wrong_limit].
func effective_wrong_limit() -> int:
	return mini(wrong_limit, maxi(1, ceili(expected.size() / 3.0)))


func _to_canvas(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var scale: float = SIZE / StrokeCheck.BOX
	for p in points:
		out.append(p * scale)
	return out


func _draw() -> void:
	draw_rect(Rect2(0, 0, SIZE, SIZE), PAPER)
	draw_line(Vector2(SIZE * 0.5, 0), Vector2(SIZE * 0.5, SIZE), PAPER_LINE)
	draw_line(Vector2(0, SIZE * 0.5), Vector2(SIZE, SIZE * 0.5), PAPER_LINE)
	draw_rect(Rect2(0, 0, SIZE, SIZE), PAPER_LINE, false, 2.0)
	if guide == Guide.FULL:
		for s in expected:
			_draw_stroke(_to_canvas(s), GUIDE_COLOR, GUIDE_WIDTH)
	elif guide == Guide.FIRST_START and _index == 0 and expected.size() > 0:
		draw_circle(_to_canvas(expected[0])[0], START_DOT, GUIDE_COLOR)
	if _show_wrong_guide and _index < expected.size():
		var e: PackedVector2Array = _to_canvas(expected[_index])
		_draw_stroke(e, WRONG, GUIDE_WIDTH)
		draw_circle(e[0], START_DOT, WRONG)
	if _play_progress >= 0.0:
		var whole: int = int(floor(_play_progress))
		for i in range(mini(whole, expected.size())):
			_draw_stroke(_to_canvas(expected[i]), INK, INK_WIDTH)
		if whole < expected.size():
			var pts: PackedVector2Array = _to_canvas(expected[whole])
			var n: int = int(ceil(pts.size() * (_play_progress - float(whole))))
			if n >= 2:
				_draw_stroke(pts.slice(0, n), PLAY, INK_WIDTH)
	for s in drawn:
		_draw_stroke(s, INK, INK_WIDTH)
	if _current.size() >= 2:
		_draw_stroke(_current, INK, INK_WIDTH)
	elif _current.size() == 1:
		draw_circle(_current[0], INK_WIDTH * 0.5, INK)


func _draw_stroke(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() >= 2:
		draw_polyline(points, color, width)
	elif points.size() == 1:
		draw_circle(points[0], width * 0.5, color)
