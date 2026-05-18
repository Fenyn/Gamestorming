class_name LevelData
extends Resource

var grid_size: Vector2i = Vector2i(12, 12)
var solid_tiles: Array[Vector2i] = []
var cover_tiles: Array[Vector2i] = []
var elevation: Dictionary = {} # Vector2i -> int
var player_spawns: Array[Vector2i] = []
var enemy_spawns: Array[Vector2i] = []
var enemy_ids: Array[String] = []
var description: String = ""


func get_blocked_tiles() -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	blocked.append_array(solid_tiles)
	blocked.append_array(cover_tiles)
	return blocked


func validate() -> bool:
	var blocked: Array[Vector2i] = get_blocked_tiles()
	var all_spawns: Array[Vector2i] = []
	all_spawns.append_array(player_spawns)
	all_spawns.append_array(enemy_spawns)
	var valid: bool = true
	for spawn: Vector2i in all_spawns:
		if blocked.has(spawn):
			push_error("LevelData: spawn %s is on a blocked tile" % str(spawn))
			valid = false
	for i: int in all_spawns.size():
		for j: int in range(i + 1, all_spawns.size()):
			if all_spawns[i] == all_spawns[j]:
				push_error("LevelData: duplicate spawn at %s" % str(all_spawns[i]))
				valid = false
	if enemy_spawns.size() < enemy_ids.size():
		push_warning("LevelData: only %d enemy spawns for %d enemy IDs" % [enemy_spawns.size(), enemy_ids.size()])
	return valid


static func build_for_node(node_index: int) -> LevelData:
	match node_index:
		0: return _build_open_field()
		1: return _build_urban_ruins()
		2: return _build_hilltop_siege()
	return _build_open_field()


static func _build_open_field() -> LevelData:
	var level: LevelData = LevelData.new()
	level.grid_size = Vector2i(14, 14)
	level.description = "Open Field"
	var placed: Array[Vector2i] = []

	level.player_spawns = _random_tiles_in_zone(Rect2i(1, 9, 3, 4), 3, placed)
	placed.append_array(level.player_spawns)
	level.enemy_spawns = _random_tiles_in_zone(Rect2i(10, 1, 3, 4), 3, placed)
	placed.append_array(level.enemy_spawns)
	level.enemy_ids = ["enemy_rifleman", "enemy_rifleman", "enemy_rifleman"]

	level.solid_tiles = [Vector2i(6, 4)]
	placed.append_array(level.solid_tiles)

	level.cover_tiles = _random_tiles_in_zone(Rect2i(3, 3, 8, 8), 8, placed)
	placed.append_array(level.cover_tiles)

	level.elevation[Vector2i(7, 7)] = 1

	level.validate()
	return level


static func _build_urban_ruins() -> LevelData:
	var level: LevelData = LevelData.new()
	level.grid_size = Vector2i(14, 14)
	level.description = "Urban Ruins"
	var placed: Array[Vector2i] = []

	# L-shaped ruin
	level.solid_tiles.append_array([
		Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5),
		Vector2i(6, 5), Vector2i(7, 5),
	])
	# U-shaped ruin
	level.solid_tiles.append_array([
		Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 10),
		Vector2i(9, 10), Vector2i(10, 10),
		Vector2i(10, 9), Vector2i(10, 8),
	])
	# Wall fragment
	level.solid_tiles.append(Vector2i(3, 8))
	placed.append_array(level.solid_tiles)

	level.player_spawns = _random_tiles_in_zone(Rect2i(1, 9, 3, 4), 3, placed)
	placed.append_array(level.player_spawns)
	level.enemy_spawns = _random_tiles_in_zone(Rect2i(10, 1, 3, 4), 4, placed)
	placed.append_array(level.enemy_spawns)
	level.enemy_ids = ["enemy_rifleman", "enemy_rifleman", "enemy_rifleman", "enemy_rifleman"]

	level.cover_tiles = _random_tiles_in_zone(Rect2i(2, 2, 10, 10), 10, placed)
	placed.append_array(level.cover_tiles)

	level.elevation[Vector2i(9, 9)] = 1

	level.validate()
	return level


static func _build_hilltop_siege() -> LevelData:
	var level: LevelData = LevelData.new()
	level.grid_size = Vector2i(16, 16)
	level.description = "Hilltop Siege"
	var placed: Array[Vector2i] = []

	# Large central hill
	for tile: Vector2i in [
		Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5),
		Vector2i(6, 6), Vector2i(9, 6),
		Vector2i(6, 7), Vector2i(9, 7),
		Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8), Vector2i(9, 8),
	]:
		level.elevation[tile] = 1
	for tile: Vector2i in [
		Vector2i(7, 6), Vector2i(8, 6),
		Vector2i(7, 7), Vector2i(8, 7),
	]:
		level.elevation[tile] = 2

	# Walls on the hill
	level.solid_tiles.append_array([
		Vector2i(7, 5), Vector2i(8, 5),
	])
	placed.append_array(level.solid_tiles)

	# Enemies start ON the hill
	level.enemy_spawns = _random_tiles_in_zone(Rect2i(7, 6, 2, 2), 3, placed)
	if level.enemy_spawns.size() < 5:
		var extra: Array[Vector2i] = _random_tiles_in_zone(Rect2i(6, 5, 4, 4), 5 - level.enemy_spawns.size(), placed)
		level.enemy_spawns.append_array(extra)
	placed.append_array(level.enemy_spawns)
	level.enemy_ids = ["enemy_rifleman", "enemy_rifleman", "enemy_rifleman", "enemy_rifleman", "enemy_rifleman"]

	# Players start at the bottom
	level.player_spawns = _random_tiles_in_zone(Rect2i(1, 12, 4, 3), 3, placed)
	placed.append_array(level.player_spawns)

	level.cover_tiles = _random_tiles_in_zone(Rect2i(2, 2, 12, 12), 12, placed)
	placed.append_array(level.cover_tiles)

	level.validate()
	return level


static func _random_tiles_in_zone(zone: Rect2i, count: int, blocked: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var attempts: int = 0
	while result.size() < count and attempts < 200:
		var tile: Vector2i = Vector2i(
			randi_range(zone.position.x, zone.position.x + zone.size.x - 1),
			randi_range(zone.position.y, zone.position.y + zone.size.y - 1),
		)
		if not blocked.has(tile) and not result.has(tile):
			result.append(tile)
		attempts += 1
	if result.size() < count:
		push_warning("LevelData: only placed %d/%d tiles in zone %s" % [result.size(), count, str(zone)])
	return result
