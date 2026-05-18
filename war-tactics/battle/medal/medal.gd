class_name Medal
extends Node2D

var medal_data: MedalData = null
var tile: Vector2i = Vector2i.ZERO


func setup(p_tile: Vector2i, p_data: MedalData) -> void:
	tile = p_tile
	medal_data = p_data
	position = Grid.tile_to_world_elevated(p_tile)


func _draw() -> void:
	if medal_data == null:
		return
	var hw: float = 8.0
	var hh: float = 5.0
	var diamond: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -hh - 2.0), Vector2(hw, -2.0),
		Vector2(0.0, hh - 2.0), Vector2(-hw, -2.0),
	])
	draw_colored_polygon(diamond, medal_data.color)
	var outline: PackedVector2Array = diamond.duplicate()
	outline.append(diamond[0])
	draw_polyline(outline, Color.WHITE, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(-10.0, -hh - 6.0), medal_data.label, HORIZONTAL_ALIGNMENT_CENTER, 20, 8, medal_data.color)
