@tool
extends Node

@export var terrain: Terrain3D = null

@export_group("Real World Terrain")
@export var load_real_terrain: bool = false:
	set(value):
		if value and terrain:
			_load_real()
		load_real_terrain = false
@export var height_scale: float = 1.0
@export var flatten_center_radius: float = 20.0
@export var flatten_blend: float = 10.0

@export_group("Texture Painting")
@export var paint_textures: bool = false:
	set(value):
		if value and terrain:
			_paint_textures()
		paint_textures = false

@export_group("Noise Terrain")
@export var generate_noise: bool = false:
	set(value):
		if value and terrain:
			_generate_noise()
		generate_noise = false
@export var noise_size: int = 128
@export var hill_height: float = 12.0
@export var hill_scale: float = 0.015

# Texture IDs — must match order in Terrain3D asset dock
const TEX_GRASS := 0
const TEX_DIRT := 1
const TEX_PATH := 2
const TEX_ROCK := 3
const TEX_DRY := 4


# ── Real World Height ────────────────────────────────────────────────

func _load_real() -> void:
	var data: Object = terrain.data
	if not data:
		push_warning("TerrainGenerator: No terrain data")
		return

	var elev_data: Dictionary = _read_elevation()
	if elev_data.is_empty():
		return

	var grid_size: int = elev_data["grid_size"] as int
	var spacing: int = elev_data["spacing_m"] as int
	var elevations: Array = elev_data["elevations"] as Array

	var min_elev: float = INF
	for e: Variant in elevations:
		var ef: float = float(e)
		if ef < min_elev:
			min_elev = ef

	var half_grid: int = grid_size / 2

	# Only write within the terrain's actual region bounds
	var region_size: int = terrain.get_region_size()
	var regions: Array = data.get_region_locations()
	if regions.is_empty():
		push_warning("TerrainGenerator: No terrain regions exist. Add regions in the editor first.")
		return

	# Find the bounding box of existing regions
	var min_rx: int = 9999
	var max_rx: int = -9999
	var min_rz: int = 9999
	var max_rz: int = -9999
	for loc: Variant in regions:
		var v: Vector2i = loc as Vector2i
		if v.x < min_rx: min_rx = v.x
		if v.x > max_rx: max_rx = v.x
		if v.y < min_rz: min_rz = v.y
		if v.y > max_rz: max_rz = v.y

	var world_min_x: int = min_rx * region_size
	var world_max_x: int = (max_rx + 1) * region_size
	var world_min_z: int = min_rz * region_size
	var world_max_z: int = (max_rz + 1) * region_size

	var pixel_count: int = (world_max_x - world_min_x) * (world_max_z - world_min_z)
	print("TerrainGenerator: Writing heights. Bounds: (%d,%d)-(%d,%d), %d pixels" % [
		world_min_x, world_min_z, world_max_x, world_max_z, pixel_count])

	var total: int = 0
	for wz: int in range(world_min_z, world_max_z):
		for wx: int in range(world_min_x, world_max_x):
			var h: float = _sample_bilinear(elevations, grid_size, spacing, half_grid, min_elev, wx, wz)

			var dist: float = Vector2(float(wx), float(wz)).length()
			if dist < flatten_center_radius + flatten_blend:
				var center_h: float = _sample_bilinear(elevations, grid_size, spacing, half_grid, min_elev, 0, 0)
				if dist < flatten_center_radius:
					h = lerpf(center_h, h, dist / flatten_center_radius)
				else:
					var t: float = (dist - flatten_center_radius) / flatten_blend
					h = lerpf(center_h, h, t)

			data.set_height(Vector3(float(wx), 0.0, float(wz)), h)
			total += 1

	data.update_maps()
	print("TerrainGenerator: Height loaded. %d points written." % total)


# ── Texture Painting ─────────────────────────────────────────────────

func _paint_textures() -> void:
	var data: Object = terrain.data
	if not data:
		push_warning("TerrainGenerator: No terrain data")
		return

	var elev_data: Dictionary = _read_elevation()
	if elev_data.is_empty():
		return

	var water_pts: Array[Vector2] = _load_water_points(elev_data)
	print("TerrainGenerator: Loaded %d water points" % water_pts.size())

	var spacing: int = elev_data["spacing_m"] as int

	var region_size: int = terrain.get_region_size()
	var regions: Array = data.get_region_locations()
	if regions.is_empty():
		push_warning("TerrainGenerator: No terrain regions")
		return

	var min_rx: int = 9999
	var max_rx: int = -9999
	var min_rz: int = 9999
	var max_rz: int = -9999
	for loc: Variant in regions:
		var v: Vector2i = loc as Vector2i
		if v.x < min_rx: min_rx = v.x
		if v.x > max_rx: max_rx = v.x
		if v.y < min_rz: min_rz = v.y
		if v.y > max_rz: max_rz = v.y

	var world_min_x: int = min_rx * region_size
	var world_max_x: int = (max_rx + 1) * region_size
	var world_min_z: int = min_rz * region_size
	var world_max_z: int = (max_rz + 1) * region_size

	# First pass: find actual height range
	var min_h: float = INF
	var max_h: float = -INF
	var sample_step: int = 10
	for sz: int in range(world_min_z, world_max_z, sample_step):
		for sx: int in range(world_min_x, world_max_x, sample_step):
			var h: float = data.get_height(Vector3(float(sx), 0.0, float(sz)))
			if is_finite(h):
				if h < min_h: min_h = h
				if h > max_h: max_h = h

	var h_range: float = max_h - min_h
	print("TerrainGenerator: Height range on terrain: %.1f to %.1f (%.1fm)" % [min_h, max_h, h_range])

	if h_range <= 0.0:
		push_warning("TerrainGenerator: No height variation found — run Load Real Terrain first")
		return

	# Second pass: paint textures
	var counts: Dictionary = {TEX_GRASS: 0, TEX_DIRT: 0, TEX_PATH: 0, TEX_ROCK: 0, TEX_DRY: 0}
	var painted: int = 0
	var step: int = maxi(spacing / 2, 3)

	print("TerrainGenerator: Painting bounds (%d,%d)-(%d,%d) step %d" % [world_min_x, world_min_z, world_max_x, world_max_z, step])

	for wz: int in range(world_min_z, world_max_z, step):
		for wx: int in range(world_min_x, world_max_x, step):
			var pos := Vector3(float(wx), 0.0, float(wz))
			var h: float = data.get_height(pos)
			if not is_finite(h):
				continue

			var norm_h: float = (h - min_h) / h_range

			# Calculate slope from neighboring terrain heights
			var hx: float = data.get_height(Vector3(float(wx + step), 0.0, float(wz)))
			var hz: float = data.get_height(Vector3(float(wx), 0.0, float(wz + step)))
			if not is_finite(hx): hx = h
			if not is_finite(hz): hz = h
			var dx: float = (hx - h) / float(step)
			var dz: float = (hz - h) / float(step)
			var slope: float = sqrt(dx * dx + dz * dz)

			var water_dist: float = _dist_to_water(water_pts, wx, wz)
			var tex: int = _pick_texture(norm_h, slope, water_dist)

			var bits: int = Terrain3DUtil.enc_base(tex)
			var pixel := Color(Terrain3DUtil.as_float(bits), 0.0, 0.0, 1.0)
			data.set_pixel(Terrain3DRegion.TYPE_CONTROL, pos, pixel)

			counts[tex] = (counts[tex] as int) + 1
			painted += 1

	data.update_maps()
	print("TerrainGenerator: Painted %d pixels" % painted)
	print("  Grass: %d, Dirt: %d, Path: %d, Rock: %d, Dry: %d" % [
		counts[TEX_GRASS], counts[TEX_DIRT], counts[TEX_PATH], counts[TEX_ROCK], counts[TEX_DRY]])


func _pick_texture(norm_h: float, slope: float, water_dist: float) -> int:
	# River and banks
	if water_dist < 8.0:
		return TEX_ROCK
	if water_dist < 20.0:
		return TEX_DIRT
	if water_dist < 40.0 and norm_h < 0.12:
		return TEX_DRY

	# Steep = top 10% of slopes (>0.51)
	if slope > 0.55:
		return TEX_ROCK
	# Moderately steep = top 25% (>0.36)
	if slope > 0.40:
		return TEX_DRY

	# Valley floor (lowest 5%)
	if norm_h < 0.05:
		return TEX_DIRT

	# Low ground (5-12%)
	if norm_h < 0.12:
		return TEX_DRY

	# Upper slopes — above median slope on high ground
	if slope > 0.25 and norm_h > 0.7:
		return TEX_DRY

	# High ridge tops
	if norm_h > 0.92:
		return TEX_DRY

	# Everything else = grass (should be ~50-60%)
	return TEX_GRASS


# ── Water ────────────────────────────────────────────────────────────

func _load_water_points(elev_data: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var water_file: FileAccess = FileAccess.open("res://terrain_data/water_features.json", FileAccess.READ)
	if not water_file:
		return points

	var wjson := JSON.new()
	wjson.parse(water_file.get_as_text())
	water_file.close()

	var features: Array = wjson.data as Array
	var center_lat: float = elev_data["center_lat"] as float
	var center_lon: float = elev_data["center_lon"] as float

	for feature: Variant in features:
		var feat: Dictionary = feature as Dictionary
		var coords: Array = feat.get("coords", []) as Array
		for coord: Variant in coords:
			var c: Array = coord as Array
			var lat: float = float(c[0])
			var lon: float = float(c[1])
			var wx: float = (lon - center_lon) * 111000.0 * 0.7
			var wz: float = -(lat - center_lat) * 111000.0
			points.append(Vector2(wx, wz))

	return points


func _dist_to_water(water_pts: Array[Vector2], wx: int, wz: int) -> float:
	if water_pts.is_empty():
		return 9999.0
	var pos := Vector2(float(wx), float(wz))
	var best: float = 9999.0
	var step: int = maxi(1, water_pts.size() / 60)
	for i: int in range(0, water_pts.size(), step):
		var d: float = pos.distance_to(water_pts[i])
		if d < best:
			best = d
	return best


# ── Noise Terrain ────────────────────────────────────────────────────

func _generate_noise() -> void:
	var data: Object = terrain.data
	if not data:
		push_warning("TerrainGenerator: No terrain data")
		return

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = hill_scale
	noise.seed = 42

	var noise2 := FastNoiseLite.new()
	noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise2.frequency = hill_scale * 2.5
	noise2.seed = 137

	for x: int in range(-noise_size, noise_size):
		for z: int in range(-noise_size, noise_size):
			var xf: float = float(x)
			var zf: float = float(z)
			var h: float = noise.get_noise_2d(xf, zf) * hill_height
			h += noise2.get_noise_2d(xf, zf) * (hill_height * 0.3)
			data.set_height(Vector3(xf, 0.0, zf), h)

	data.update_maps()
	print("TerrainGenerator: Generated noise terrain %dx%d" % [noise_size * 2, noise_size * 2])


# ── Shared Helpers ───────────────────────────────────────────────────

func _read_elevation() -> Dictionary:
	var file: FileAccess = FileAccess.open("res://terrain_data/real_elevation.json", FileAccess.READ)
	if not file:
		push_warning("TerrainGenerator: Could not open real_elevation.json")
		return {}
	var json := JSON.new()
	var err: int = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("TerrainGenerator: Failed to parse elevation JSON")
		return {}
	return json.data as Dictionary


func _sample_bilinear(elevations: Array, grid_size: int, spacing: int, half_grid: int, min_elev: float, wx: int, wz: int) -> float:
	var gx: float = float(wx) / float(spacing) + float(half_grid)
	var gz: float = float(wz) / float(spacing) + float(half_grid)
	var x0: int = clampi(int(floorf(gx)), 0, grid_size - 1)
	var z0: int = clampi(int(floorf(gz)), 0, grid_size - 1)
	var x1: int = clampi(x0 + 1, 0, grid_size - 1)
	var z1: int = clampi(z0 + 1, 0, grid_size - 1)
	var fx: float = gx - floorf(gx)
	var fz: float = gz - floorf(gz)
	var e00: float = (float(elevations[z0 * grid_size + x0]) - min_elev) * height_scale
	var e10: float = (float(elevations[z0 * grid_size + x1]) - min_elev) * height_scale
	var e01: float = (float(elevations[z1 * grid_size + x0]) - min_elev) * height_scale
	var e11: float = (float(elevations[z1 * grid_size + x1]) - min_elev) * height_scale
	return lerpf(lerpf(e00, e10, fx), lerpf(e01, e11, fx), fz)


func _sample_nearest(elevations: Array, grid_size: int, spacing: int, half_grid: int, min_elev: float, wx: int, wz: int) -> float:
	var gx: int = clampi(int(float(wx) / float(spacing) + float(half_grid)), 0, grid_size - 1)
	var gz: int = clampi(int(float(wz) / float(spacing) + float(half_grid)), 0, grid_size - 1)
	return float(elevations[gz * grid_size + gx]) - min_elev


func _get_max_relative(elevations: Array, min_elev: float) -> float:
	var max_rel: float = 0.0
	for e: Variant in elevations:
		var rel: float = float(e) - min_elev
		if rel > max_rel:
			max_rel = rel
	return max_rel
