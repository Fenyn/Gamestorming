@tool
extends Control

## Torn bottom edge of the cup ticket: a row of paper teeth.

const TOOTH := 12.0

func _draw() -> void:
	var pts := PackedVector2Array([Vector2(0, 0)])
	var n := maxi(int(size.x / TOOTH), 1)
	var w := size.x / float(n)
	for i in range(n):
		pts.append(Vector2(w * (float(i) + 0.5), size.y))
		pts.append(Vector2(w * float(i + 1), 0))
	draw_colored_polygon(pts, UiStyle.PAPER)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
