@tool
class_name UiIcon
extends Control

## Small drawn icons for glyphs Nunito lacks: a tick, the next-step arrow, a
## bullet, full, half or empty stars, the coffee bean from the roof sign, and
## the crosshair dot (crema with a dark ring so it shows on any surface).

enum Kind { CHECK, NEXT, DOT, STAR_FULL, STAR_HALF, STAR_EMPTY, BEAN, CROSSHAIR }

@export var kind: Kind = Kind.DOT:
	set(v):
		kind = v
		queue_redraw()
@export var color := UiStyle.INK:
	set(v):
		color = v
		queue_redraw()

static func make(icon_kind: Kind, icon_color: Color, px: float) -> UiIcon:
	var icon := UiIcon.new()
	icon.kind = icon_kind
	icon.color = icon_color
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	match kind:
		Kind.CHECK:
			var pts := PackedVector2Array([c + Vector2(-0.32, 0.02) * s, c + Vector2(-0.08, 0.26) * s, c + Vector2(0.34, -0.24) * s])
			draw_polyline(pts, color, maxf(s * 0.14, 2.0), true)
		Kind.NEXT:
			var pts := PackedVector2Array([c + Vector2(-0.12, -0.28) * s, c + Vector2(0.18, 0.0) * s, c + Vector2(-0.12, 0.28) * s])
			draw_polyline(pts, color, maxf(s * 0.16, 2.0), true)
		Kind.DOT:
			draw_circle(c, s * 0.12, color)
		Kind.CROSSHAIR:
			draw_circle(c, s * 0.5, Color(UiStyle.ROAST, 0.55))
			draw_circle(c, s * 0.3, color)
		Kind.BEAN:
			# Tilted oval with an S-shaped crease, as on the roof sign.
			var xf := Transform2D(-0.35, c)
			var oval := PackedVector2Array()
			for i in range(32):
				var a := TAU * float(i) / 32.0
				oval.append(xf * (Vector2(cos(a) * 0.3, sin(a) * 0.42) * s))
			draw_colored_polygon(oval, color)
			var crease := PackedVector2Array()
			for i in range(9):
				var t := float(i) / 8.0
				crease.append(xf * (Vector2(sin(t * PI * 2.0) * 0.07, lerpf(-0.34, 0.34, t)) * s))
			draw_polyline(crease, UiStyle.ROAST, maxf(s * 0.06, 2.0), true)
		Kind.STAR_FULL, Kind.STAR_HALF, Kind.STAR_EMPTY:
			var star := _star(c, s * 0.48, s * 0.2)
			if kind == Kind.STAR_EMPTY:
				draw_colored_polygon(star, Color(color, 0.22))
			elif kind == Kind.STAR_FULL:
				draw_colored_polygon(star, color)
			else:
				draw_colored_polygon(star, Color(color, 0.22))
				draw_colored_polygon(Geometry2D.clip_polygons(star, _right_half(c, s))[0], color)

static func _star(c: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(10):
		var a := -PI * 0.5 + PI * float(i) / 5.0
		var r := outer if i % 2 == 0 else inner
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

static func _right_half(c: Vector2, s: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, -s), c + Vector2(s, s), c + Vector2(0, s)])
