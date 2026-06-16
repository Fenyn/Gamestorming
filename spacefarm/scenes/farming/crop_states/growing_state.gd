class_name CropGrowingState
extends BaseState


func enter(_msg: Dictionary = {}) -> void:
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	var tile: CropTile = owner as CropTile
	tile.update_growth_visual()


func exit() -> void:
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


func interact(_player: Node2D) -> void:
	if GameState.is_active_tool("watering_can"):
		_water()


func _water() -> void:
	var tile: CropTile = owner as CropTile
	if not GameState.spend_energy(CropTile.ENERGY_WATER):
		return

	if tile.crop_data.water_schedule == CropData.WaterSchedule.NIGHT_ONLY:
		if not TimeManager.is_night():
			tile.quality -= 0.3
			EventBus.notification_requested.emit("%s damaged by day watering!" % tile.crop_data.get_active_name())
			return

	if tile.crop_data.water_schedule == CropData.WaterSchedule.ALTERNATE_DAYS:
		var needed: int = tile.get_required_water_count()
		if needed == 0:
			EventBus.notification_requested.emit("%s is wilting from overwatering!" % tile.crop_data.get_active_name())
			state_machine.transition_to(&"Wilting")
			return

	var needed: int = tile.get_required_water_count()
	if tile.water_count >= needed:
		return
	tile.water_count += 1
	tile.show_watered()
	EventBus.crop_watered.emit(tile.grid_position)


func _on_day_started(_day: int) -> void:
	var tile: CropTile = owner as CropTile
	if tile.crop_data == null:
		return

	var needed: int = tile.get_required_water_count()
	if needed == 0:
		tile.days_grown += 1
		tile.quality += 0.05
		tile.missed_water_days = 0
	elif tile.water_count >= needed:
		tile.days_grown += 1
		tile.quality += 0.05
		tile.missed_water_days = 0
	elif tile.water_count > 0 and needed > 1:
		tile.days_grown += 1
		tile.quality -= 0.05
		tile.missed_water_days = 0
	else:
		tile.quality -= 0.10
		tile.missed_water_days += 1

	if tile.crop_data.requires_adjacency == CropData.AdjacencyRequirement.WINDOW:
		if tile.is_near_window:
			tile.quality += 0.03
		else:
			tile.quality -= 0.05

	if tile.crop_data.crop_id == "cotton":
		_try_spread_moss(tile)

	tile.quality = clampf(tile.quality, 0.5, 1.5)
	tile.water_count = 0

	if tile.missed_water_days >= tile.WILT_THRESHOLD:
		EventBus.notification_requested.emit("%s is wilting from neglect!" % tile.crop_data.get_active_name())
		state_machine.transition_to(&"Wilting")
		return

	tile.update_growth_visual()

	if tile.days_grown >= tile.get_effective_growth_days():
		state_machine.transition_to(&"Harvestable")


func _try_spread_moss(tile: CropTile) -> void:
	if tile.days_grown % 2 != 0:
		return
	var bay: GrowBay = tile.get_grow_bay()
	if bay == null:
		return
	var offsets: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(0, 1),
	]
	for offset: Vector2i in offsets:
		var neighbor: CropTile = bay.get_tile_at(tile.grid_position + offset)
		if neighbor == null:
			continue
		if neighbor.crop_data != null:
			continue
		if neighbor.get_state_name() == &"Tilled":
			var moss_data: CropData = Database.get_crop("cotton")
			if moss_data:
				neighbor.set_crop(moss_data)
				neighbor.force_transition(&"Planted")
				neighbor.force_transition(&"Growing")
				EventBus.notification_requested.emit("Cotton spreading...")
			return
