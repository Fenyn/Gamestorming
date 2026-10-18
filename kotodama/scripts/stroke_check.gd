class_name StrokeCheck
extends RefCounted
## Compares one drawn stroke to one expected KanjiVG stroke. Both in the same box.

const BOX: float = 109.0

var start_tolerance: float = 0.22
var end_tolerance: float = 0.22
var angle_tolerance_deg: float = 50.0
var min_length_ratio: float = 0.4


func _init(p_start: float = 0.22, p_end: float = 0.22, p_angle: float = 50.0, p_length: float = 0.4) -> void:
	start_tolerance = p_start
	end_tolerance = p_end
	angle_tolerance_deg = p_angle
	min_length_ratio = p_length


## Returns "" when the stroke passes, else the name of the first failed check.
func check(drawn: PackedVector2Array, expected: PackedVector2Array) -> String:
	if drawn.size() < 2 or expected.size() < 2:
		return "empty"
	var diagonal: float = BOX * sqrt(2.0)
	var d_start: Vector2 = drawn[0]
	var d_end: Vector2 = drawn[drawn.size() - 1]
	var e_start: Vector2 = expected[0]
	var e_end: Vector2 = expected[expected.size() - 1]
	if d_start.distance_to(e_start) > start_tolerance * diagonal:
		return "start"
	if d_end.distance_to(e_end) > end_tolerance * diagonal:
		return "end"
	var e_len: float = polyline_length(expected)
	var d_len: float = polyline_length(drawn)
	if d_len < min_length_ratio * e_len:
		return "length"
	var e_dir: Vector2 = e_end - e_start
	var d_dir: Vector2 = d_end - d_start
	if e_dir.length() > diagonal * 0.05 and d_dir.length() > 0.0:
		var angle: float = rad_to_deg(absf(e_dir.angle_to(d_dir)))
		if angle > angle_tolerance_deg:
			return "direction"
	return ""


static func polyline_length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## Converts a stroke from a square canvas of [param canvas_size] pixels into the KanjiVG box.
static func to_box(points: PackedVector2Array, canvas_size: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var scale: float = BOX / canvas_size
	for p in points:
		out.append(p * scale)
	return out


static func from_json(stroke: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for pt in stroke:
		var pair: Array = pt
		out.append(Vector2(float(pair[0]), float(pair[1])))
	return out
