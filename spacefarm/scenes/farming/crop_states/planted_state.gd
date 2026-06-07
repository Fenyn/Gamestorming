class_name CropPlantedState
extends BaseState


func enter(_msg: Dictionary = {}) -> void:
	var tile: CropTile = owner as CropTile
	tile.show_planted()
	tile.days_grown = 0
	tile.water_count = 0
	tile.quality = tile.crop_data.base_quality


func interact(_player: Node2D) -> void:
	if GameState.is_active_tool("watering_can"):
		_water()


func _water() -> void:
	var tile: CropTile = owner as CropTile

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
	if tile.water_count >= needed:
		state_machine.transition_to(&"Growing")
