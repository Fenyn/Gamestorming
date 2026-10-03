class_name RankEmblem
extends Control
## A rank's emblem (`Ranks`), drawn to fit the control: the rank's Kenney icon on a dark disc in a
## ring of its colour, an inner ring from the second rank, points round the ring from the third
## (4, 6, 8, then 12 for the top), and a glow that grows from the third rank up. Novice stays bare,
## as approved.

const POINTS: Array[int] = [0, 0, 4, 6, 8, 12]
const DISC_SHARE: float = 0.40        # the disc's radius, of the control's side
const ICON_SHARE: float = 0.58        # the icon, of the disc's diameter
const RING_SHARE: float = 0.04
const RING_MIN: float = 2.0
const GLOW_REACH: float = 0.10        # past the disc, of the side
const GLOW_STEPS: int = 6

@export var rank: int = 0:
	set(value):
		var clamped: int = Ranks.clamp_index(value)
		if clamped == rank and _icon != null:
			return
		rank = clamped
		_icon = load(Ranks.icon_path(rank)) as Texture2D
		queue_redraw()

var _icon: Texture2D = null


func _ready() -> void:
	if _icon == null:
		_icon = load(Ranks.icon_path(rank)) as Texture2D


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	if side <= 0.0:
		return
	var color: Color = Ranks.color(rank)
	var center: Vector2 = size * 0.5
	var radius: float = side * DISC_SHARE
	var ring: float = maxf(RING_MIN, side * RING_SHARE)
	if rank >= 2:
		for i in GLOW_STEPS:
			var t: float = float(i + 1) / GLOW_STEPS
			draw_circle(center, radius + side * GLOW_REACH * t, Color(color, (0.10 + 0.03 * (rank - 2)) * (1.0 - t)), true, -1.0, true)
	var points: int = POINTS[rank]
	for i in points:
		var a: float = -PI * 0.5 + TAU * float(i) / points
		var reach: float = radius + side * (0.09 if rank < 5 or i % 2 == 0 else 0.06)
		var tip: Vector2 = center + Vector2.from_angle(a) * reach
		var left: Vector2 = center + Vector2.from_angle(a - 0.22) * (radius - ring)
		var right: Vector2 = center + Vector2.from_angle(a + 0.22) * (radius - ring)
		draw_colored_polygon(PackedVector2Array([left, tip, right]), color)
	draw_circle(center, radius, Color(ZenithTheme.BG, 1.0), true, -1.0, true)
	draw_arc(center, radius - ring * 0.5, 0.0, TAU, 64, color, ring, true)
	if rank >= 1:
		draw_arc(center, radius - ring * 2.6, 0.0, TAU, 64, Color(color, 0.55), maxf(1.0, ring * 0.4), true)
	if _icon != null:
		var icon_side: float = radius * 2.0 * ICON_SHARE
		draw_texture_rect(_icon, Rect2(center - Vector2.ONE * icon_side * 0.5, Vector2.ONE * icon_side), false, color)
