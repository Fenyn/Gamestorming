extends SceneTree
## Rebuilds resources/room_tileset.tres and repaints every station room scene.
## Wall tiles carry full-tile collision via the tileset physics layer, so the
## painted walls are also the room collision. Exit zones and entrance markers
## are baked into the scenes for every open exit (sealed airlocks stay solid;
## BaseRoom.unlock_airlock opens them at runtime).
##
## Grow-ring rooms have a "biome" interior: a 1-tile station-floor walkway
## ring runs inside the walls, and the inner field is a biome terrain tile
## with an occasional scatter variant.
##
## Run:  godot --headless --path . --script tools/room_painter.gd
##
## Floor/biome tiles were chosen with tools/floor_seam_analysis.gd and
## tools/tile_hue_scan.gd (lowest wrap-seam error, uniform, on-hue).

const TILE: int = 48
const TILESET_PATH: String = "res://resources/room_tileset.tres"
const ROOMS_DIR: String = "res://scenes/station/rooms/"

const TEX_FLOORS: String = "res://assets/ModernInteriors/1_Interiors/48x48/Room_Builder_subfiles_48x48/Room_Builder_Floors_48x48.png"
const TEX_WALLS: String = "res://assets/ModernInteriors/1_Interiors/48x48/Room_Builder_subfiles_48x48/Room_Builder_Walls_48x48.png"
const TEX_FUNGUS: String = "res://assets/FungusCave/Tileset - Complete 48x48.png"
const TEX_GRASS: String = "res://assets/ModernExteriors/ME_Theme_Sorter_48x48/1_Terrains_and_Fences_Singles_48x48/ME_Singles_Terrains_and_Fences_48x48_Grass_1_22.png"
const TEX_GRASS_VAR: String = "res://assets/ModernExteriors/ME_Theme_Sorter_48x48/1_Terrains_and_Fences_Singles_48x48/ME_Singles_Terrains_and_Fences_48x48_Grass_1_9.png"
const TEX_TOPSOIL: String = "res://assets/ModernFarm/Single_Files_48x48/0_Complete_Tileset_48x48/Topsoil_48x48.png"

## Wall band anatomy (LimeZu Room Builder walls sheet): each style is a
## 2-row band at column base `b`, trim row `t`, face row `t + 1`.
## b+0 / b+1 / b+2 = left-edge / middle / right-edge of a horizontal run;
## b+5 face row = full-tile vertical wall slab for east/west walls.
const ROOMS: Array[Dictionary] = [
	{"file": "hub", "cols": 16, "rows": 12, "floor": Vector2i(12, 30), "wall_base": 0, "wall_trim": 2},
	{"file": "living_quarters", "cols": 12, "rows": 8, "floor": Vector2i(14, 27), "wall_base": 22, "wall_trim": 8},
	{"file": "cargo_bay", "cols": 16, "rows": 12, "floor": Vector2i(14, 21), "wall_base": 0, "wall_trim": 34},
	{"file": "service_tunnel", "cols": 6, "rows": 16, "floor": Vector2i(14, 17), "wall_base": 0, "wall_trim": 30},
	{"file": "processing_lab", "cols": 16, "rows": 10, "floor": Vector2i(14, 2), "wall_base": 22, "wall_trim": 6},
	{"file": "advanced_processing", "cols": 14, "rows": 10, "floor": Vector2i(14, 25), "wall_base": 22, "wall_trim": 4},
	{"file": "hybridization_lab", "cols": 12, "rows": 8, "floor": Vector2i(13, 29), "wall_base": 22, "wall_trim": 10},
	{
		"file": "grow_bay_room", "cols": 30, "rows": 20,
		"floor": Vector2i(12, 32), "wall_base": 22, "wall_trim": 12,
		"biome": {"tex": TEX_GRASS, "at": Vector2i(0, 0), "variant_tex": TEX_GRASS_VAR, "variant_at": Vector2i(0, 0), "variant_every": 7},
	},
	{
		"file": "grow_bay_b", "cols": 22, "rows": 14,
		"floor": Vector2i(14, 25), "wall_base": 0, "wall_trim": 24,
		"biome": {"tex": TEX_TOPSOIL, "at": Vector2i(0, 0)},
	},
	{
		"file": "grow_bay_c", "cols": 22, "rows": 14,
		"floor": Vector2i(14, 17), "wall_base": 0, "wall_trim": 32,
		"biome": {"tex": TEX_FUNGUS, "at": Vector2i(1, 18), "variant_tex": TEX_FUNGUS, "variant_at": Vector2i(1, 19), "variant_every": 5},
	},
	{
		"file": "grow_bay_d", "cols": 22, "rows": 14,
		"floor": Vector2i(12, 30), "wall_base": 22, "wall_trim": 14,
		"biome": {"tex": TEX_FLOORS, "at": Vector2i(9, 17)},
	},
]

var _tile_set: TileSet
var _source_ids: Dictionary = {}


func _initialize() -> void:
	_tile_set = TileSet.new()
	_tile_set.tile_size = Vector2i(TILE, TILE)
	_tile_set.add_physics_layer()
	_tile_set.set_physics_layer_collision_layer(0, 1)
	for spec: Dictionary in ROOMS:
		_register_tiles(spec)

	var err: Error = ResourceSaver.save(_tile_set, TILESET_PATH)
	if err != OK:
		push_error("Failed to save tileset: %s" % error_string(err))
		quit(1)
		return
	_tile_set.take_over_path(TILESET_PATH)
	print("saved %s" % TILESET_PATH)

	for spec: Dictionary in ROOMS:
		_paint_room(spec)
	quit()


# --- TileSet construction ---

func _source_for(path: String) -> int:
	if _source_ids.has(path):
		return _source_ids[path]
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = load(path) as Texture2D
	source.texture_region_size = Vector2i(TILE, TILE)
	var id: int = _source_ids.size()
	_tile_set.add_source(source, id)
	_source_ids[path] = id
	return id


func _ensure_tile(path: String, at: Vector2i, collide: bool = false) -> void:
	var source: TileSetAtlasSource = _tile_set.get_source(_source_for(path)) as TileSetAtlasSource
	if source.has_tile(at):
		return
	source.create_tile(at)
	if collide:
		var tile_data: TileData = source.get_tile_data(at, 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-TILE / 2.0, -TILE / 2.0), Vector2(TILE / 2.0, -TILE / 2.0),
			Vector2(TILE / 2.0, TILE / 2.0), Vector2(-TILE / 2.0, TILE / 2.0),
		]))


func _register_tiles(spec: Dictionary) -> void:
	_ensure_tile(TEX_FLOORS, spec["floor"])
	var biome: Dictionary = spec.get("biome", {})
	if not biome.is_empty():
		_ensure_tile(biome["tex"], biome["at"])
		if biome.has("variant_tex"):
			_ensure_tile(biome["variant_tex"], biome["variant_at"])
	var b: int = spec["wall_base"]
	var t: int = spec["wall_trim"]
	for dx: int in [0, 1, 2]:
		_ensure_tile(TEX_WALLS, Vector2i(b + dx, t), true)
		_ensure_tile(TEX_WALLS, Vector2i(b + dx, t + 1), true)
	_ensure_tile(TEX_WALLS, Vector2i(b + 5, t + 1), true)


# --- Room painting ---

func _paint_room(spec: Dictionary) -> void:
	var scene_path: String = ROOMS_DIR + spec["file"] + ".tscn"
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("Cannot load %s" % scene_path)
		return
	var room: BaseRoom = packed.instantiate() as BaseRoom
	if room == null:
		push_error("%s root is not a BaseRoom" % scene_path)
		return

	var cols: int = spec["cols"]
	var rows: int = spec["rows"]
	room.room_width = float(cols * TILE)
	room.room_height = float(rows * TILE)

	var gaps: Dictionary = {}
	for direction: String in ["north", "south", "east", "west"]:
		gaps[direction] = room.get_exit_target(direction) != ""

	_paint_floor(room.get_node("FloorLayer") as TileMapLayer, spec, gaps)
	_paint_walls(room.get_node("WallLayer") as TileMapLayer, spec, gaps)
	_reposition_labels(room)

	for child: Node in room.get_children():
		var child_name: String = String(child.name)
		if child_name.begins_with("Exit_") or child_name.begins_with("Entrance_"):
			room.remove_child(child)
			child.free()
	for direction: String in ["north", "south", "east", "west"]:
		var target: String = room.get_exit_target(direction)
		if target == "":
			continue
		for node: Node in room.create_exit(direction, target):
			node.owner = room
			for sub: Node in node.get_children():
				sub.owner = room

	var out: PackedScene = PackedScene.new()
	var err: Error = out.pack(room)
	if err == OK:
		err = ResourceSaver.save(out, scene_path)
	if err != OK:
		push_error("Failed to save %s: %s" % [scene_path, error_string(err)])
	else:
		print("painted %s (%dx%d)" % [spec["file"], cols, rows])
	room.free()


func _paint_floor(layer: TileMapLayer, spec: Dictionary, gaps: Dictionary) -> void:
	layer.tile_set = _tile_set
	layer.clear()
	var cols: int = spec["cols"]
	var rows: int = spec["rows"]
	var hx: int = cols / 2
	var hy: int = rows / 2
	var floor_at: Vector2i = spec["floor"]
	var floor_src: int = _source_for(TEX_FLOORS)
	var biome: Dictionary = spec.get("biome", {})

	# interior plus one tile under the east/west wall slabs; biome rooms get
	# a station-floor walkway ring with the biome field inside it
	for y: int in range(-hy, hy):
		for x: int in range(-hx - 1, hx + 1):
			var in_field: bool = not biome.is_empty() \
				and x >= -hx + 1 and x <= hx - 2 and y >= -hy + 1 and y <= hy - 2
			if in_field:
				var use_variant: bool = biome.has("variant_tex") \
					and posmod(x * 31 + y * 17, int(biome.get("variant_every", 7))) == 0
				if use_variant:
					layer.set_cell(Vector2i(x, y), _source_for(biome["variant_tex"]), biome["variant_at"])
				else:
					layer.set_cell(Vector2i(x, y), _source_for(biome["tex"]), biome["at"])
			else:
				layer.set_cell(Vector2i(x, y), floor_src, floor_at)

	# floor running through north/south doorways
	if gaps["north"]:
		for x: int in [-1, 0]:
			layer.set_cell(Vector2i(x, -hy - 1), floor_src, floor_at)
			layer.set_cell(Vector2i(x, -hy - 2), floor_src, floor_at)
	if gaps["south"]:
		for x: int in [-1, 0]:
			layer.set_cell(Vector2i(x, hy), floor_src, floor_at)
			layer.set_cell(Vector2i(x, hy + 1), floor_src, floor_at)


func _paint_walls(layer: TileMapLayer, spec: Dictionary, gaps: Dictionary) -> void:
	layer.tile_set = _tile_set
	layer.clear()
	var cols: int = spec["cols"]
	var rows: int = spec["rows"]
	var hx: int = cols / 2
	var hy: int = rows / 2
	var b: int = spec["wall_base"]
	var t: int = spec["wall_trim"]
	var wall_src: int = _source_for(TEX_WALLS)

	for side: String in ["north", "south"]:
		var y_trim: int = -hy - 2 if side == "north" else hy
		var gap: bool = gaps[side]
		for x: int in range(-hx - 1, hx + 1):
			if gap and (x == -1 or x == 0):
				continue
			var col: int = b + 1
			if x == -hx - 1:
				col = b
			elif x == hx:
				col = b + 2
			elif gap and x == -2:
				col = b + 2
			elif gap and x == 1:
				col = b
			layer.set_cell(Vector2i(x, y_trim), wall_src, Vector2i(col, t))
			layer.set_cell(Vector2i(x, y_trim + 1), wall_src, Vector2i(col, t + 1))

	for side: String in ["west", "east"]:
		var wx: int = -hx - 1 if side == "west" else hx
		var gap: bool = gaps[side]
		for y: int in range(-hy, hy):
			if gap and (y == -1 or y == 0):
				continue
			layer.set_cell(Vector2i(wx, y), wall_src, Vector2i(b + 5, t + 1))


# --- Cosmetic node placement ---

func _reposition_labels(room: BaseRoom) -> void:
	var hw: float = room.room_width / 2.0
	var hh: float = room.room_height / 2.0
	_center_control(room.get_node_or_null("RoomLabel") as Control, Vector2(0, -hh + 28))
	_center_control(room.get_node_or_null("SignNorth") as Control, Vector2(0, -hh + 64))
	_center_control(room.get_node_or_null("SignSouth") as Control, Vector2(0, hh - 64))
	_center_control(room.get_node_or_null("SignEast") as Control, Vector2(hw - 88, 0))
	_center_control(room.get_node_or_null("SignWest") as Control, Vector2(-hw + 88, 0))


func _center_control(control: Control, center: Vector2) -> void:
	if control == null:
		return
	var half_w: float = (control.offset_right - control.offset_left) / 2.0
	var half_h: float = (control.offset_bottom - control.offset_top) / 2.0
	control.offset_left = center.x - half_w
	control.offset_right = center.x + half_w
	control.offset_top = center.y - half_h
	control.offset_bottom = center.y + half_h
