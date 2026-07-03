extends SceneTree
## Builds TileSet resources and prop scenes from RPG-Maker-format sprite packs
## (Spaceship, Cyberpunk Interior, Cyberpunk Exterior).
##
## Tileset sheets (A1–A5, B–E) become TileSetAtlasSources in a shared TileSet
## per pack.  Character sheets become individual Sprite2D scenes (one per
## distinct prop slot) showing the center animation frame.
##
## RPG Maker character layout:
##   $  prefix → single character: 3 columns × 4 rows, frame = (w/3)×(h/4)
##   no $ prefix → 4×2 character grid, frame = (w/12)×(h/8)
##   !  prefix → non-walking (static prop / animated object, not a walk cycle)
##
## Run:  godot --headless --path . --script tools/asset_prep.gd

const TILE: int = 48

const PACKS: Array[Dictionary] = [
	{
		"name": "spaceship",
		"tilesets": "res://assets/Spaceship/tilesets/",
		"characters": "res://assets/Spaceship/characters/",
		"tileset_out": "res://resources/spaceship_tileset.tres",
		"props_out": "res://scenes/props/spaceship/",
	},
	{
		"name": "cyberpunk_interior",
		"tilesets": "res://assets/Cyberpunk Interior/tilesets/",
		"characters": "res://assets/Cyberpunk Interior/characters/",
		"tileset_out": "res://resources/cyberpunk_interior_tileset.tres",
		"props_out": "res://scenes/props/cyberpunk_interior/",
	},
	{
		"name": "cyberpunk_exterior",
		"tilesets": "res://assets/Cyberpunk Exterior/tilesets/",
		"characters": "res://assets/Cyberpunk Exterior/characters/",
		"tileset_out": "res://resources/cyberpunk_exterior_tileset.tres",
		"props_out": "res://scenes/props/cyberpunk_exterior/",
	},
]


func _initialize() -> void:
	for pack: Dictionary in PACKS:
		print("=== %s ===" % pack["name"])
		_build_tileset(pack)
		_build_props(pack)
	quit()


func _list_pngs(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("Cannot open directory: %s" % dir_path)
		return result
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".png"):
			result.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	result.sort()
	return result


# ---- TileSet construction ----

func _build_tileset(pack: Dictionary) -> void:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)

	var source_id: int = 0
	for png_path: String in _list_pngs(pack["tilesets"]):
		var tex: Texture2D = load(png_path) as Texture2D
		if tex == null:
			push_error("Cannot load texture: %s" % png_path)
			continue
		var source: TileSetAtlasSource = TileSetAtlasSource.new()
		source.texture = tex
		source.texture_region_size = Vector2i(TILE, TILE)
		tile_set.add_source(source, source_id)

		var cols: int = tex.get_width() / TILE
		var rows: int = tex.get_height() / TILE
		for y: int in range(rows):
			for x: int in range(cols):
				var at: Vector2i = Vector2i(x, y)
				if not source.has_tile(at):
					source.create_tile(at)
		print("  source %d: %s  %dx%d tiles" % [source_id, png_path.get_file(), cols, rows])
		source_id += 1

	var err: Error = ResourceSaver.save(tile_set, pack["tileset_out"])
	if err != OK:
		push_error("Failed to save tileset: %s  %s" % [pack["tileset_out"], error_string(err)])
	else:
		print("  -> %s  (%d sources)" % [pack["tileset_out"], source_id])


# ---- Prop scene construction ----

func _build_props(pack: Dictionary) -> void:
	var global_dir: String = ProjectSettings.globalize_path(pack["props_out"])
	DirAccess.make_dir_recursive_absolute(global_dir)

	var count: int = 0
	for png_path: String in _list_pngs(pack["characters"]):
		var tex: Texture2D = load(png_path) as Texture2D
		if tex == null:
			push_error("Cannot load texture: %s" % png_path)
			continue

		var file_name: String = png_path.get_file().get_basename()
		var is_single: bool = file_name.contains("$")
		var clean_name: String = file_name.lstrip("!$").to_lower()

		if is_single:
			var fw: int = tex.get_width() / 3
			var fh: int = tex.get_height() / 4
			var region: Rect2 = Rect2(fw, 0, fw, fh)
			count += _save_prop_scene(pack["props_out"], clean_name, tex, region)
		else:
			var fw: int = tex.get_width() / 12
			var fh: int = tex.get_height() / 8
			for cy: int in 2:
				for cx: int in 4:
					var idx: int = cy * 4 + cx
					var rx: int = (cx * 3 + 1) * fw
					var ry: int = cy * 4 * fh
					var region: Rect2 = Rect2(rx, ry, fw, fh)
					count += _save_prop_scene(
						pack["props_out"],
						"%s_%d" % [clean_name, idx],
						tex,
						region,
					)
	print("  -> %d prop scenes in %s" % [count, pack["props_out"]])


func _save_prop_scene(dir: String, prop_name: String, tex: Texture2D, region: Rect2) -> int:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = prop_name.to_pascal_case()
	sprite.texture = tex
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var scene: PackedScene = PackedScene.new()
	var pack_err: Error = scene.pack(sprite)
	sprite.free()
	if pack_err != OK:
		push_error("pack() failed for %s: %s" % [prop_name, error_string(pack_err)])
		return 0

	var path: String = dir.path_join(prop_name + ".tscn")
	var save_err: Error = ResourceSaver.save(scene, path)
	if save_err != OK:
		push_error("save() failed for %s: %s" % [path, error_string(save_err)])
		return 0
	return 1