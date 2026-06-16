extends Node
## Smoke test that runs inside the game tree (autoloads available).
## Launch:  godot --headless --path . -s tools/test_sleep_loop.gd

var _failed: bool = false


func _ready() -> void:
	await get_tree().process_frame

	# --- Energy system ---
	print("--- energy ---")
	GameState.wake_up(true)
	_expect(GameState.energy == GameState.MAX_ENERGY, "wake rested = full energy")

	_expect(GameState.spend_energy(2.0), "spend 2 succeeds")
	_expect(absf(GameState.energy - 98.0) < 0.01, "energy is 98 after spending 2")

	GameState.energy = 0.5
	_expect(not GameState.spend_energy(2.0), "spend 2 fails when energy=0.5")

	GameState.wake_up(false)
	var expected: float = GameState.MAX_ENERGY * GameState.TIRED_WAKE_FRACTION
	_expect(absf(GameState.energy - expected) < 0.01, "wake tired = 75%%")

	# --- Biome gating ---
	print("--- biome gating ---")
	var turnip: CropData = Database.get_crop("turnip")
	_expect(turnip != null, "turnip exists in database")
	if turnip:
		_expect(turnip.biome == "verdant", "turnip biome is verdant (default)")

	var cotton: CropData = Database.get_crop("cotton")
	if cotton:
		_expect(cotton.biome == "arid", "cotton biome is arid")

	# --- Crop tile save/load round-trip ---
	print("--- crop save/load ---")
	var room: BaseRoom = (load("res://scenes/station/rooms/grow_bay_room.tscn") as PackedScene).instantiate() as BaseRoom
	add_child(room)
	await get_tree().process_frame
	await get_tree().process_frame

	var tiles: Array[Node] = get_tree().get_nodes_in_group("crop_tiles")
	_expect(tiles.size() > 0, "crop tiles found in group (%d)" % tiles.size())

	if tiles.size() > 0 and turnip:
		var tile: CropTile = tiles[0] as CropTile
		_expect(tile.get_state_name() == "Empty", "tile starts empty")

		tile.force_transition(&"Tilled")
		await get_tree().process_frame
		tile.set_crop(turnip)
		tile.force_transition(&"Planted")
		await get_tree().process_frame
		_expect(tile.get_state_name() == "Planted", "tile is planted")

		var save_data: Dictionary = tile.save_data()
		_expect(save_data["crop_id"] == "turnip", "save_data has turnip")
		_expect(save_data["state"] == "Planted", "save_data state is Planted")

		tile.force_transition(&"Empty")
		await get_tree().process_frame
		_expect(tile.get_state_name() == "Empty", "tile reset to empty")

		tile.load_data(save_data)
		await get_tree().process_frame
		_expect(tile.get_state_name() == "Planted", "tile restored to Planted")
		_expect(tile.crop_data != null and tile.crop_data.crop_id == "turnip", "crop data restored")

	room.free()

	# --- GameState save/load round-trip ---
	print("--- game state save/load ---")
	GameState.energy = 42.0
	GameState.day = 5
	GameState.food_shipped_total = 23
	var dict: Dictionary = GameState.to_dict()
	_expect(dict["energy"] == 42.0, "to_dict has energy")
	_expect(dict["day"] == 5, "to_dict has day 5")
	_expect(dict.has("crop_tile_states"), "to_dict has crop_tile_states")

	GameState.energy = 100.0
	GameState.day = 1
	GameState.from_dict(dict)
	_expect(absf(GameState.energy - 42.0) < 0.01, "from_dict restored energy")
	_expect(GameState.day == 5, "from_dict restored day")

	# --- Module doors ---
	print("--- module doors ---")
	_expect(Station.MODULE_DOORS.has("grow_ring_b"), "MODULE_DOORS has grow_ring_b")
	_expect(Station.MODULE_DOORS.has("grow_ring_c"), "MODULE_DOORS has grow_ring_c")
	_expect(Station.MODULE_DOORS.has("grow_ring_d"), "MODULE_DOORS has grow_ring_d")

	print("RESULT: " + ("FAIL" if _failed else "ALL OK"))
	get_tree().quit(1 if _failed else 0)


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		print("FAIL: " + label)
		_failed = true
	return condition
