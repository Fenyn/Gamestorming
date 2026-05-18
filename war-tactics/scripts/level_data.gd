class_name LevelData
extends Resource

var grid_size: Vector2i = Vector2i(12, 12)
var solid_tiles: Array[Vector2i] = []
var cover_tiles: Array[Vector2i] = []
var elevation: Dictionary = {} # Vector2i -> int
var player_spawns: Array[Vector2i] = []
var enemy_spawns: Array[Vector2i] = []
var enemy_ids: Array[String] = []


func get_blocked_tiles() -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	blocked.append_array(solid_tiles)
	blocked.append_array(cover_tiles)
	return blocked


func validate() -> bool:
	var blocked: Array[Vector2i] = get_blocked_tiles()
	var valid: bool = true
	for spawn: Vector2i in player_spawns:
		if blocked.has(spawn):
			push_error("LevelData: player spawn %s is on a blocked tile" % str(spawn))
			valid = false
	for spawn: Vector2i in enemy_spawns:
		if blocked.has(spawn):
			push_error("LevelData: enemy spawn %s is on a blocked tile" % str(spawn))
			valid = false
	return valid


static func build_level_01() -> LevelData:
	var level: LevelData = LevelData.new()
	level.grid_size = Vector2i(16, 16)

	# Player squad starts SW on open ground
	level.player_spawns = [Vector2i(1, 10), Vector2i(2, 12), Vector2i(1, 14)]
	# Enemies start NE on open ground
	level.enemy_spawns = [Vector2i(14, 2), Vector2i(13, 4), Vector2i(14, 6)]
	level.enemy_ids = ["enemy_rifleman", "enemy_rifleman", "enemy_rifleman"]

	# --- Central hill ---
	for tile: Vector2i in [
		Vector2i(7, 6), Vector2i(8, 6), Vector2i(9, 6),
		Vector2i(6, 7), Vector2i(9, 7),
		Vector2i(6, 8), Vector2i(9, 8),
		Vector2i(7, 9), Vector2i(8, 9), Vector2i(9, 9),
	]:
		level.elevation[tile] = 1
	for tile: Vector2i in [
		Vector2i(7, 7), Vector2i(8, 7), Vector2i(7, 8), Vector2i(8, 8),
	]:
		level.elevation[tile] = 2

	# --- Ruined structure NE (L-shape, enemy side) ---
	level.solid_tiles.append_array([
		Vector2i(11, 2), Vector2i(11, 3), Vector2i(11, 4),
		Vector2i(12, 4), Vector2i(13, 4),
	])

	# --- Ruined structure SW (small room, player side) ---
	level.solid_tiles.append_array([
		Vector2i(3, 11), Vector2i(4, 11),
		Vector2i(3, 12),
	])

	# --- Standalone wall fragments ---
	level.solid_tiles.append_array([
		Vector2i(7, 4),
		Vector2i(10, 12),
	])

	# --- Cover near player spawn ---
	level.cover_tiles.append_array([
		Vector2i(2, 11),  # rock
		Vector2i(1, 13),  # tree
		Vector2i(3, 14),  # rock
	])

	# --- Cover west approach ---
	level.cover_tiles.append_array([
		Vector2i(4, 7),   # tree
		Vector2i(5, 9),   # rock
		Vector2i(3, 8),   # tree
	])

	# --- Cover on hill ---
	level.cover_tiles.append_array([
		Vector2i(6, 6),   # rock
		Vector2i(10, 7),  # tree
	])

	# --- Cover east approach ---
	level.cover_tiles.append_array([
		Vector2i(11, 8),  # tree
		Vector2i(12, 7),  # rock
		Vector2i(10, 9),  # tree
	])

	# --- Cover near enemy spawn ---
	level.cover_tiles.append_array([
		Vector2i(13, 2),  # tree
		Vector2i(14, 4),  # rock
		Vector2i(12, 6),  # rock
	])

	# --- Cover flanks ---
	level.cover_tiles.append_array([
		Vector2i(6, 13),  # rock
		Vector2i(8, 14),  # tree
		Vector2i(9, 11),  # rock
		Vector2i(5, 3),   # rock
		Vector2i(9, 2),   # tree
		Vector2i(8, 4),   # rock
	])

	# --- Small elevation bumps ---
	level.elevation[Vector2i(3, 5)] = 1
	level.elevation[Vector2i(12, 11)] = 1
	level.elevation[Vector2i(13, 12)] = 1

	level.validate()
	return level
