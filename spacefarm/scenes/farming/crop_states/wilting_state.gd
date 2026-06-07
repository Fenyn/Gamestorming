class_name CropWiltingState
extends BaseState

var _tended: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_tended = false
	var tile: CropTile = owner as CropTile
	tile.show_wilting()
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)


func exit() -> void:
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


func interact(_player: Node2D) -> void:
	if not GameState.is_active_tool("watering_can"):
		return
	if _tended:
		return

	var tile: CropTile = owner as CropTile

	if tile.crop_data.water_schedule == CropData.WaterSchedule.ALTERNATE_DAYS:
		EventBus.notification_requested.emit("%s weakened by watering while wilting!" % tile.crop_data.get_active_name())
		tile.quality -= 0.2
		if tile.quality <= 0.5:
			EventBus.notification_requested.emit("%s died!" % tile.crop_data.get_active_name())
			state_machine.transition_to(&"Empty")
		return

	if tile.crop_data.water_schedule == CropData.WaterSchedule.NIGHT_ONLY:
		if not TimeManager.is_night():
			EventBus.notification_requested.emit("%s weakened by day watering!" % tile.crop_data.get_active_name())
			tile.quality -= 0.2
			if tile.quality <= 0.5:
				EventBus.notification_requested.emit("%s died!" % tile.crop_data.get_active_name())
				state_machine.transition_to(&"Empty")
			return

	_tended = true
	tile.show_watered()
	EventBus.notification_requested.emit("%s tended — will recover tomorrow" % tile.crop_data.get_active_name())


func _on_day_started(_day: int) -> void:
	var tile: CropTile = owner as CropTile
	if tile.crop_data == null:
		state_machine.transition_to(&"Empty")
		return

	if _tended:
		tile.missed_water_days = 0
		tile.water_count = 0
		_tended = false
		EventBus.notification_requested.emit("%s recovered!" % tile.crop_data.get_active_name())
		state_machine.transition_to(&"Growing")
		return

	tile.quality -= 0.15
	if tile.quality <= 0.5:
		EventBus.notification_requested.emit("%s died from neglect!" % tile.crop_data.get_active_name())
		state_machine.transition_to(&"Empty")
	else:
		tile.show_wilting()
