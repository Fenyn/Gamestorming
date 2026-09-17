class_name TypeIcon
extends Control
## One vector glyph per card type, drawn at any size in one colour. The same shapes mark the
## card face, the hand, the tray, and the deck legend, so a Strike looks like a Strike wherever
## it shows: sword for Strike, burst for Art, shield for Combat, scroll for Non-Combat, target
## for Drill, figure for Ally, crown for Duelist, gem for Seal, hills for Grounds, chevrons for
## Mastery, open book for Grimoire.

@export var type: CardDef.Type = CardDef.Type.COMBAT:
	set(v):
		type = v
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) * 0.5
	var w: float = maxf(2.0, s * 0.1)
	match type:
		CardDef.Type.STRIKE:
			draw_colored_polygon(_pts([Vector2(0.24, 0.7), Vector2(0.7, 0.2), Vector2(0.8, 0.3), Vector2(0.34, 0.8)], s, o), color)
			draw_line(_p(0.18, 0.62, s, o), _p(0.4, 0.84, s, o), color, w)
			draw_line(_p(0.29, 0.73, s, o), _p(0.12, 0.9, s, o), color, w)
		CardDef.Type.ART:
			draw_colored_polygon(_pts([
				Vector2(0.5, 0.06), Vector2(0.6, 0.4), Vector2(0.94, 0.5), Vector2(0.6, 0.6),
				Vector2(0.5, 0.94), Vector2(0.4, 0.6), Vector2(0.06, 0.5), Vector2(0.4, 0.4)], s, o), color)
		CardDef.Type.COMBAT:
			var shield: PackedVector2Array = _pts([Vector2(0.18, 0.14), Vector2(0.82, 0.14), Vector2(0.82, 0.5), Vector2(0.5, 0.9), Vector2(0.18, 0.5)], s, o)
			shield.append(shield[0])
			draw_polyline(shield, color, w)
			draw_line(_p(0.5, 0.26, s, o), _p(0.5, 0.74, s, o), color, w)
		CardDef.Type.NON_COMBAT:
			draw_rect(Rect2(_p(0.16, 0.14, s, o), Vector2(0.68, 0.72) * s), color, false, w)
			for y in [0.36, 0.5, 0.64]:
				draw_line(_p(0.3, y, s, o), _p(0.7, y, s, o), color, w * 0.8)
		CardDef.Type.DRILL:
			draw_arc(_p(0.5, 0.5, s, o), 0.42 * s, 0.0, TAU, 32, color, w)
			draw_arc(_p(0.5, 0.5, s, o), 0.24 * s, 0.0, TAU, 24, color, w)
			draw_circle(_p(0.5, 0.5, s, o), 0.09 * s, color)
		CardDef.Type.ALLY:
			draw_circle(_p(0.5, 0.3, s, o), 0.17 * s, color)
			var body: PackedVector2Array = PackedVector2Array()
			for i in range(17):
				var a: float = PI + PI * i / 16.0
				body.append(_p(0.5 + 0.36 * cos(a), 0.92 + 0.36 * sin(a), s, o))
			draw_colored_polygon(body, color)
		CardDef.Type.DUELIST:
			draw_colored_polygon(_pts([
				Vector2(0.12, 0.82), Vector2(0.12, 0.3), Vector2(0.33, 0.52), Vector2(0.5, 0.16),
				Vector2(0.67, 0.52), Vector2(0.88, 0.3), Vector2(0.88, 0.82)], s, o), color)
		CardDef.Type.SEAL:
			var gem: PackedVector2Array = _pts([Vector2(0.5, 0.08), Vector2(0.9, 0.4), Vector2(0.5, 0.92), Vector2(0.1, 0.4)], s, o)
			gem.append(gem[0])
			draw_polyline(gem, color, w)
			draw_line(_p(0.1, 0.4, s, o), _p(0.9, 0.4, s, o), color, w * 0.8)
			draw_line(_p(0.5, 0.4, s, o), _p(0.5, 0.92, s, o), color, w * 0.6)
		CardDef.Type.GROUNDS:
			draw_colored_polygon(_pts([
				Vector2(0.06, 0.86), Vector2(0.36, 0.28), Vector2(0.54, 0.6), Vector2(0.66, 0.44),
				Vector2(0.94, 0.86)], s, o), color)
		CardDef.Type.MASTERY:
			for y0 in [0.22, 0.46, 0.7]:
				draw_polyline(_pts([Vector2(0.18, y0 + 0.16), Vector2(0.5, y0 - 0.06), Vector2(0.82, y0 + 0.16)], s, o), color, w)
		CardDef.Type.GRIMOIRE:
			draw_polyline(_pts([Vector2(0.12, 0.2), Vector2(0.5, 0.3), Vector2(0.88, 0.2), Vector2(0.88, 0.8), Vector2(0.5, 0.9), Vector2(0.12, 0.8), Vector2(0.12, 0.2)], s, o), color, w)
			draw_line(_p(0.5, 0.3, s, o), _p(0.5, 0.9, s, o), color, w * 0.8)
		_:
			draw_circle(_p(0.5, 0.5, s, o), 0.3 * s, color)


func _p(x: float, y: float, s: float, o: Vector2) -> Vector2:
	return o + Vector2(x, y) * s


func _pts(unit: Array[Vector2], s: float, o: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for u in unit:
		out.append(o + u * s)
	return out
