class_name CoverProp
extends Node2D


func setup(tile: Vector2i) -> void:
	position = Grid.tile_to_world_elevated(tile)


func _draw() -> void:
	var hw: float = Grid.TILE_W / 4.0
	var hh: float = Grid.TILE_H / 4.0
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-hw, -hh - 4),
		Vector2(hw, -hh - 4),
		Vector2(hw, -2),
		Vector2(-hw, -2),
	])
	draw_colored_polygon(points, Color(0.45, 0.35, 0.25, 0.9))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.3, 0.2, 0.15), 1.0)
