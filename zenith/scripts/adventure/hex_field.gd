class_name HexField
extends Control
## A field of pointy hex terrain tiles covering the control, in horizontal bands, one act's terrain
## per band. Tiles are picked from the seed, so a run always shows the same land. Drawn once per
## resize; nothing here animates.

## On-screen width of one hex.
@export var hex_width: float = 72.0
var seed_value: int = 1
## Each band: {top: float, bottom: float, act: int, shade: float} and, optionally, `base` (a Color
## the band is filled with first) and `alpha` (how strongly the tiles show over it, 1.0 when
## absent). A row whose centre falls in no band takes the nearest one.
var bands: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_bands(value: Array[Dictionary], seed_in: int) -> void:
	bands = value
	seed_value = seed_in
	queue_redraw()


func _band_at(y: float) -> Dictionary:
	if bands.is_empty():
		return {"act": 1, "shade": 1.0}
	var best: Dictionary = bands[0]
	var best_gap: float = INF
	for band in bands:
		var top: float = float(band["top"])
		var bottom: float = float(band["bottom"])
		if y >= top and y < bottom:
			return band
		var gap: float = minf(absf(y - top), absf(y - bottom))
		if gap < best_gap:
			best_gap = gap
			best = band
	return best


func _draw() -> void:
	var canvas: float = hex_width / MapArt.HEX_WIDTH_OF_CANVAS
	var hex_height: float = canvas * MapArt.HEX_HEIGHT_OF_CANVAS
	var step_y: float = hex_height * 0.75
	for band in bands:
		if band.has("base"):
			var top: float = maxf(0.0, float(band["top"]))
			var bottom: float = minf(size.y, float(band["bottom"]))
			if bottom > top:
				draw_rect(Rect2(0.0, top, size.x, bottom - top), band["base"])
	var rows: int = int(ceil(size.y / step_y)) + 2
	var cols: int = int(ceil(size.x / hex_width)) + 2
	# Top row first, so each lower row's trees overlap the row behind it.
	for r in range(-1, rows):
		var cy: float = float(r) * step_y
		var band: Dictionary = _band_at(cy)
		var tiles: Array[Texture2D] = MapArt.terrain(int(band.get("act", 1)))
		if tiles.is_empty():
			continue
		var shade: float = float(band.get("shade", 1.0))
		var tint: Color = Color(shade, shade, shade, float(band.get("alpha", 1.0)))
		var offset: float = hex_width * 0.5 if posmod(r, 2) == 1 else 0.0
		for c in range(-1, cols):
			var cx: float = float(c) * hex_width + offset
			var pick: int = posmod(hash(Vector3i(seed_value, r, c)), tiles.size())
			var rect: Rect2 = Rect2(Vector2(cx, cy) - Vector2.ONE * canvas * 0.5, Vector2.ONE * canvas)
			draw_texture_rect(tiles[pick], rect, false, tint)
