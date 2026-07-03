class_name StanceDirection
extends RefCounted

enum Direction { TOP, BOTTOM_LEFT, BOTTOM_RIGHT }

const ZONE_COUNT: int = 3
const ZONE_ARC: float = TAU / ZONE_COUNT


static func from_angle(angle_rad: float) -> Direction:
	var normalized: float = fmod(angle_rad + TAU, TAU)
	# Inverted triangle: TOP is centered at 270° (straight up / -Y on screen)
	# BL is centered at 150° (lower-left)
	# BR is centered at 30° (lower-right)
	# Zone boundaries at 90°, 210°, 330° (each zone is 120°)
	if normalized >= deg_to_rad(210.0) or normalized < deg_to_rad(330.0):
		if normalized >= deg_to_rad(210.0) and normalized < deg_to_rad(330.0):
			return Direction.TOP
	if normalized >= deg_to_rad(90.0) and normalized < deg_to_rad(210.0):
		return Direction.BOTTOM_LEFT
	return Direction.BOTTOM_RIGHT


static func from_vector(vec: Vector2) -> Direction:
	if vec.length_squared() < 0.01:
		return Direction.TOP
	return from_angle(vec.angle())


static func to_display_name(dir: Direction) -> String:
	match dir:
		Direction.TOP:
			return "Top"
		Direction.BOTTOM_LEFT:
			return "Bottom-Left"
		Direction.BOTTOM_RIGHT:
			return "Bottom-Right"
	return "Unknown"


static func to_widget_position(dir: Direction) -> Vector2:
	match dir:
		Direction.TOP:
			return Vector2(0.0, -1.0)
		Direction.BOTTOM_LEFT:
			return Vector2(-0.866, 0.5)
		Direction.BOTTOM_RIGHT:
			return Vector2(0.866, 0.5)
	return Vector2.ZERO
