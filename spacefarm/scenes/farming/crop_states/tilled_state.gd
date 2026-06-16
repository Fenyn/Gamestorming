class_name CropTilledState
extends BaseState


func enter(_msg: Dictionary = {}) -> void:
	var tile: CropTile = owner as CropTile
	tile.show_tilled()


func interact(_player: Node2D) -> void:
	if GameState.is_active_seed():
		_try_plant()
	elif GameState.is_active_fertilizer():
		_try_fertilize()
	elif GameState.is_active_tool("watering_can"):
		EventBus.notification_requested.emit("Plant seeds first")
	elif GameState.is_active_tool("trowel"):
		EventBus.notification_requested.emit("Already tilled")


func _try_plant() -> void:
	var tile: CropTile = owner as CropTile
	var crop_id: String = GameState.get_active_seed_crop_id()
	if crop_id == "":
		return
	var crop_data: CropData = Database.get_crop(crop_id)
	if crop_data == null:
		return
	var bay: GrowBay = tile.get_grow_bay()
	var bay_biome: String = bay.get_biome() if bay else "verdant"
	if crop_data.biome != bay_biome:
		EventBus.notification_requested.emit("%s only grows in the %s bay" % [crop_data.get_active_name(), crop_data.biome.capitalize()])
		return
	var seed_id: String = crop_id + "_seed"
	if not GameState.remove_item(seed_id, 1):
		EventBus.notification_requested.emit("No seeds left")
		return
	tile.set_crop(crop_data)
	state_machine.transition_to(&"Planted")
	EventBus.crop_planted.emit(tile.grid_position, crop_id)


func _try_fertilize() -> void:
	var tile: CropTile = owner as CropTile
	var fert_id: String = GameState.get_active_item_id()
	var fert_type: String = _fertilizer_id_to_type(fert_id)
	if fert_type == "":
		return
	if tile.fertility_type == fert_type and tile.fertility_stacks >= 3:
		EventBus.notification_requested.emit("Fertility maxed for %s" % fert_type)
		return
	if not GameState.remove_item(fert_id, 1):
		EventBus.notification_requested.emit("No %s left" % fert_id.replace("_", " "))
		return
	tile.apply_fertilizer(fert_type)
	tile.show_tilled()
	EventBus.notification_requested.emit("Applied %s (x%d)" % [fert_type, tile.fertility_stacks])


func _fertilizer_id_to_type(fert_id: String) -> String:
	match fert_id:
		"growth_accelerant": return "growth"
		"yield_booster": return "yield"
		"quality_enhancer": return "quality"
	return ""
