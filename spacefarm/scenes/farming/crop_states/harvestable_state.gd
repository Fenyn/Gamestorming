class_name CropHarvestableState
extends BaseState


func enter(_msg: Dictionary = {}) -> void:
	var tile: CropTile = owner as CropTile
	tile.show_harvestable()


func interact(_player: Node2D) -> void:
	_harvest()


func _harvest() -> void:
	var tile: CropTile = owner as CropTile
	if tile.crop_data == null:
		return

	var crop_id: String = tile.crop_data.crop_id
	var crop_name: String = tile.crop_data.get_active_name()
	var food: int = tile.crop_data.food_units + tile.get_yield_bonus()

	food = _apply_adjacency_modifiers(tile, food)

	GameState.add_harvested(crop_id, 1)
	GameState.add_seeds(crop_id, 1)

	if tile.crop_data.secondary_output_id != "":
		GameState.add_processed(tile.crop_data.secondary_output_id, tile.crop_data.secondary_output_count)
		GameState._auto_assign_toolbar(tile.crop_data.secondary_output_id)

	EventBus.crop_harvested.emit(tile.grid_position, crop_id, tile.quality)
	if food > 0:
		EventBus.food_added.emit(food)
		tile.show_harvest_result(food, crop_name)
	else:
		tile._spawn_float_text("No yield (needs group)", Color(1.0, 0.4, 0.3, 1))

	state_machine.transition_to(&"Empty")


func _apply_adjacency_modifiers(tile: CropTile, base_food: int) -> int:
	if tile.crop_data.requires_adjacency != CropData.AdjacencyRequirement.GROUP_3:
		return base_food

	var bay: GrowBay = tile.get_grow_bay()
	if bay == null:
		return base_food

	var adjacent: int = bay.get_adjacent_crop_count(tile.grid_position, tile.crop_data.crop_id)
	if adjacent < 2:
		return 0

	if tile.crop_data.group_bonus_threshold > 0 and adjacent >= tile.crop_data.group_bonus_threshold - 1:
		return base_food + tile.crop_data.group_bonus_food

	return base_food
