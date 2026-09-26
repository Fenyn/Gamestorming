class_name GearButton
extends Button
## A flat button that draws a cog in its own rect, for opening an options menu. The pixel fonts
## carry no cog glyph, so it is drawn.

const TEETH: int = 8
const OUTER: float = 0.40   # tooth tip radius, as a fraction of the shorter side
const INNER: float = 0.30   # root radius between the teeth
const HOLE: float = 0.12


func _ready() -> void:
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool) -> void: queue_redraw())


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var centre: Vector2 = size * 0.5
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = TEETH * 4
	for i in range(steps):
		var angle: float = TAU * float(i) / float(steps)
		var tip: bool = i % 4 == 1 or i % 4 == 2
		points.append(centre + Vector2.from_angle(angle) * side * (OUTER if tip else INNER))
	var lit: bool = is_hovered() or button_pressed
	var color: Color = ZenithTheme.TEXT if lit else ZenithTheme.FRAME
	draw_colored_polygon(points, color)
	draw_circle(centre, side * HOLE, ZenithTheme.BG)
