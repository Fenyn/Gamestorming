extends SceneTree
## One-off analysis: finds the seamless repeat unit (single tile vs 2x2 block)
## for each candidate floor pattern in the Room Builder floors sheet.

const SHEET_PATH: String = "res://assets/ModernInteriors/1_Interiors/48x48/Room_Builder_subfiles_48x48/Room_Builder_Floors_48x48.png"
const TILE: int = 48
const FLOOR_ROWS: Array[int] = [2, 16, 20, 24, 26, 28, 30, 32]


func _initialize() -> void:
	var image: Image = (load(SHEET_PATH) as Texture2D).get_image()
	for row: int in FLOOR_ROWS:
		var results: Array[Dictionary] = []
		for col: int in [12, 13, 14]:
			for dy: int in [0, 1]:
				var err: float = _self_wrap_error(image, col, row + dy)
				results.append({"kind": "single(%d,%d)" % [col, row + dy], "err": err})
		for start_col: int in [12, 13]:
			results.append({"kind": "block2x2(col%d)" % start_col, "err": _block_error(image, start_col, row)})
		results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["err"] < b["err"])
		var parts: Array[String] = []
		for i: int in 3:
			parts.append("%s=%.1f" % [results[i]["kind"], results[i]["err"]])
		print("row %d: %s" % [row, " | ".join(parts)])
	quit()


func _edge_error(image: Image, ax: int, ay: int, bx: int, by: int, horizontal: bool) -> float:
	# horizontal: right edge of tile A against left edge of tile B
	var total: float = 0.0
	for i: int in TILE:
		var pa: Color
		var pb: Color
		if horizontal:
			pa = image.get_pixel(ax * TILE + TILE - 1, ay * TILE + i)
			pb = image.get_pixel(bx * TILE, by * TILE + i)
		else:
			pa = image.get_pixel(ax * TILE + i, ay * TILE + TILE - 1)
			pb = image.get_pixel(bx * TILE + i, by * TILE)
		total += absf(pa.r - pb.r) + absf(pa.g - pb.g) + absf(pa.b - pb.b)
	return total * 255.0 / float(TILE)


func _self_wrap_error(image: Image, col: int, row: int) -> float:
	return _edge_error(image, col, row, col, row, true) + _edge_error(image, col, row, col, row, false)


func _block_error(image: Image, start_col: int, row: int) -> float:
	# 2x2 block [A B / C D]: internal seams + wrap seams, averaged
	var a: Vector2i = Vector2i(start_col, row)
	var b: Vector2i = Vector2i(start_col + 1, row)
	var c: Vector2i = Vector2i(start_col, row + 1)
	var d: Vector2i = Vector2i(start_col + 1, row + 1)
	var total: float = 0.0
	total += _edge_error(image, a.x, a.y, b.x, b.y, true) + _edge_error(image, b.x, b.y, a.x, a.y, true)
	total += _edge_error(image, c.x, c.y, d.x, d.y, true) + _edge_error(image, d.x, d.y, c.x, c.y, true)
	total += _edge_error(image, a.x, a.y, c.x, c.y, false) + _edge_error(image, c.x, c.y, a.x, a.y, false)
	total += _edge_error(image, b.x, b.y, d.x, d.y, false) + _edge_error(image, d.x, d.y, b.x, b.y, false)
	return total / 4.0
