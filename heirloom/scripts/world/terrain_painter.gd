@tool
extends Node

@export var terrain: Terrain3D = null
@export var paint_textures: bool = false:
	set(value):
		if value and terrain:
			_paint()
		paint_textures = false

# Texture IDs must match the order in Terrain3D's asset dock
# 0 = grass, 1 = dirt, 2 = dirt_path, 3 = rock, 4 = grass_dry
const TEX_GRASS := 0
const TEX_DIRT := 1
const TEX_PATH := 2
const TEX_ROCK := 3
const TEX_DRY := 4


func _paint() -> void:
	var data: Object = terrain.data
	if not data:
		push_warning("TerrainPainter: No terrain data")
		return

	var elev_file: FileAccess = FileAccess.open("res://terrain_data/real_elevation.json", FileAccess.READ)
	if not elev_file:
		push_warning("TerrainPainter: No elevation data")
		return

	var json := JSON.new()
	json.parse(elev_file.get_as_text())
	elev_file.close()
	var elev_data: Dictionary = json.data as Dictionary
	var grid_size: int = elev_data["grid_size"] as int
	var spacing: int = elev_data["spacing_m"] as int
	var elevations: Array = elev_data["elevations"] as Array

	# Load water features
	var water_points: Array[Vector2] = _load_water_points(elev_data)

	var min_elev: float = INF
	var max_elev: float = -INF
	for e: Variant in elevations:
		var ef: float = float(e)
		if ef < min_elev: min_elev = ef
		if ef > max_elev: max_elev = ef

	var half_grid: int = grid_size / 2
	var world_half: int = half_grid * spacing
	var elev_range: float = max_elev - min_elev

	for wz: int in range(-world_half, world_half):
		for wx: int in range(-world_half, world_half):
			var slope: float = _get_slope(elevations, grid_size, spacing, half_grid, min_elev, wx, wz)
			var height: float = _sample_height(elevations, grid_size, spacing, half_grid, min_elev, wx, wz)
			var norm_height: float = height / elev_range if elev_range > 0.0 else 0.0

			var near_water: float = _distance_to_water(water_points, wx, wz)

			var tex_id: int = _pick_texture(norm_height, slope, near_water)

			var pos := Vector3(float(wx), 0.0, float(wz))
			var bits: int = Terrain3DUtil.enc_base(tex_id)
			var control_color := Color(Terrain3DUtil.as_float(bits), 0.0, 0.0, 1.0)
			data.set_pixel(Terrain3D.TYPE_CONTROL, pos, control_color)

	data.update_maps()
	print("TerrainPainter: Painted %dx%d terrain" % [world_half * 2, world_half * 2])


func _pick_texture(norm_height: float, slope: float, water_dist: float) -> int:
	# Water: river bank and riverbed
	if water_dist < 5.0:
		return TEX_ROCK
	if water_dist < 15.0:
		return TEX_DIRT

	# Steep slopes get rock
	if slope > 0.6:
		return TEX_ROCK
	if slope > 0.4:
		return TEX_DRY

	# Valley floor
	if norm_height < 0.1:
		return TEX_DIRT

	# Low areas near water
	if norm_height < 0.2 and water_dist < 40.0:
		return TEX_DRY

	# Mid slopes
	if slope > 0.2:
		return TEX_DRY

	# Default: grass
	return TEX_GRASS


func _get_slope(elevations: Array, grid_size: int, spacing: int, half_grid: int, min_elev: float, wx: int, wz: int) -> float:
	var h: float = _sample_height(elevations, grid_size, spacing, half_grid, min_elev, wx, wz)
	var hx: float = _sample_height(elevations, grid_size, spacing, half_grid, min_elev, wx + 2, wz)
	var hz: float = _sample_height(elevations, grid_size, spacing, half_grid, min_elev, wx, wz + 2)
	var dx: float = (hx - h) / 2.0
	var dz: float = (hz - h) / 2.0
	return sqrt(dx * dx + dz * dz)


func _sample_height(elevations: Array, grid_size: int, spacing: int, half_grid: int, min_elev: float, wx: int, wz: int) -> float:
	var gx: float = float(wx) / float(spacing) + float(half_grid)
	var gz: float = float(wz) / float(spacing) + float(half_grid)
	var x0: int = clampi(int(gx), 0, grid_size - 1)
	var z0: int = clampi(int(gz), 0, grid_size - 1)
	return float(elevations[z0 * grid_size + x0]) - min_elev


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

	print("TerrainPainter: Loaded %d water points" % points.size())
	return points


func _distance_to_water(water_points: Array[Vector2], wx: int, wz: int) -> float:
	if water_points.is_empty():
		return 9999.0

	var pos := Vector2(float(wx), float(wz))
	var min_dist: float = 9999.0

	# Check every Nth point for speed (river has 323 points, checking all for each pixel is slow)
	var step: int = maxi(1, water_points.size() / 50)
	for i: int in range(0, water_points.size(), step):
		var dist: float = pos.distance_to(water_points[i])
		if dist < min_dist:
			min_dist = dist

	return min_dist
