extends SceneTree
## One-off analysis: scans tile sheets for uniform, seamlessly-wrapping tiles
## near a target hue. Used to pick biome floor tiles without eyeballing sheets.

const TILE: int = 48

const TARGETS: Array[Dictionary] = [
	{
		"name": "cryo (pale blue)",
		"sheet": "res://assets/ModernInteriors/1_Interiors/48x48/Room_Builder_subfiles_48x48/Room_Builder_Floors_48x48.png",
		"hue_min": 0.52, "hue_max": 0.65, "sat_min": 0.04, "sat_max": 0.5, "val_min": 0.55,
	},
	{
		"name": "fungal (dark violet)",
		"sheet": "res://assets/FungusCave/Tileset - Complete 48x48.png",
		"hue_min": 0.0, "hue_max": 1.0, "sat_min": 0.0, "sat_max": 1.0, "val_min": 0.0,
	},
]


func _initialize() -> void:
	for target: Dictionary in TARGETS:
		_scan(target)
	quit()


func _scan(target: Dictionary) -> void:
	var image: Image = (load(target["sheet"]) as Texture2D).get_image()
	var cols: int = image.get_width() / TILE
	var rows: int = image.get_height() / TILE
	var candidates: Array[Dictionary] = []
	for ty: int in rows:
		for tx: int in cols:
			var stats: Dictionary = _tile_stats(image, tx, ty)
			if stats["alpha"] < 0.999:
				continue
			var avg: Color = stats["avg"]
			if avg.v < target["val_min"] or avg.s < target["sat_min"] or avg.s > target["sat_max"]:
				continue
			if avg.h < target["hue_min"] or avg.h > target["hue_max"]:
				continue
			var score: float = stats["wrap_err"] + stats["stddev"] * 0.5
			candidates.append({"at": Vector2i(tx, ty), "score": score, "avg": avg, "wrap": stats["wrap_err"], "sd": stats["stddev"]})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] < b["score"])
	print("--- %s ---" % target["name"])
	for i: int in mini(12, candidates.size()):
		var c: Dictionary = candidates[i]
		var avg: Color = c["avg"]
		print("  tile %s score=%.1f wrap=%.1f sd=%.1f rgb=(%d,%d,%d)" % [
			c["at"], c["score"], c["wrap"], c["sd"],
			int(avg.r * 255.0), int(avg.g * 255.0), int(avg.b * 255.0)])


func _tile_stats(image: Image, tx: int, ty: int) -> Dictionary:
	var sum_r: float = 0.0
	var sum_g: float = 0.0
	var sum_b: float = 0.0
	var sum_a: float = 0.0
	var values: Array[float] = []
	for y: int in TILE:
		for x: int in TILE:
			var p: Color = image.get_pixel(tx * TILE + x, ty * TILE + y)
			sum_r += p.r
			sum_g += p.g
			sum_b += p.b
			sum_a += p.a
			values.append(p.v)
	var n: float = float(TILE * TILE)
	var mean_v: float = 0.0
	for v: float in values:
		mean_v += v
	mean_v /= n
	var variance: float = 0.0
	for v: float in values:
		variance += (v - mean_v) * (v - mean_v)
	var stddev: float = sqrt(variance / n) * 255.0

	var wrap: float = 0.0
	for i: int in TILE:
		var right: Color = image.get_pixel(tx * TILE + TILE - 1, ty * TILE + i)
		var left: Color = image.get_pixel(tx * TILE, ty * TILE + i)
		var bottom: Color = image.get_pixel(tx * TILE + i, ty * TILE + TILE - 1)
		var top: Color = image.get_pixel(tx * TILE + i, ty * TILE)
		wrap += absf(right.r - left.r) + absf(right.g - left.g) + absf(right.b - left.b)
		wrap += absf(bottom.r - top.r) + absf(bottom.g - top.g) + absf(bottom.b - top.b)
	wrap = wrap * 255.0 / float(TILE * 2)

	return {
		"avg": Color(sum_r / n, sum_g / n, sum_b / n),
		"alpha": sum_a / n,
		"stddev": stddev,
		"wrap_err": wrap,
	}