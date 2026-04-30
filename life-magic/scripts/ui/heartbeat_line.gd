class_name HeartbeatLine
extends Control

var _points: PackedFloat32Array
var _scroll_accum: float = 0.0
var line_color: Color = Color(0.4, 0.6, 0.8)

const POINT_COUNT := 160
const SCROLL_SPEED := 60.0
const BASELINE := 0.5
const BEAT_SCALE := 0.45

const BEAT_SHAPE := [
	0.0, 0.04, 0.07, 0.04, 0.0,
	-0.1, 0.85, -0.3, 0.0,
	0.0, 0.05, 0.1, 0.07, 0.03, 0.0
]

var _beat_active: bool = false
var _beat_pos: int = 0


func _ready() -> void:
	_points.resize(POINT_COUNT)
	_points.fill(BASELINE)


func _process(delta: float) -> void:
	_scroll_accum += delta * SCROLL_SPEED
	while _scroll_accum >= 1.0:
		_scroll_accum -= 1.0
		_advance()
	queue_redraw()


func trigger_beat() -> void:
	_beat_active = true
	_beat_pos = 0


func set_line_color(color: Color) -> void:
	line_color = color


func _advance() -> void:
	for i in range(POINT_COUNT - 1):
		_points[i] = _points[i + 1]

	var new_val := BASELINE
	if _beat_active:
		if _beat_pos < BEAT_SHAPE.size():
			new_val = BASELINE - BEAT_SHAPE[_beat_pos] * BEAT_SCALE
			_beat_pos += 1
		else:
			_beat_active = false

	if not _beat_active:
		new_val = BASELINE + (randf() - 0.5) * 0.008

	_points[POINT_COUNT - 1] = new_val


func _draw() -> void:
	var w := size.x
	var h := size.y

	var polyline := PackedVector2Array()
	polyline.resize(POINT_COUNT)
	for i in POINT_COUNT:
		polyline[i] = Vector2(float(i) / float(POINT_COUNT - 1) * w, _points[i] * h)

	var bloom := Color(line_color.r, line_color.g, line_color.b, 0.08)
	draw_polyline(polyline, bloom, 14.0, true)
	var glow := Color(line_color.r, line_color.g, line_color.b, 0.2)
	draw_polyline(polyline, glow, 8.0, true)
	draw_polyline(polyline, line_color, 2.0, true)
