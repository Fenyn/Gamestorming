extends Node

const AXIS_MAP: Dictionary = {
	"aerolume": "atmosphere",
	"loamspine": "soil",
	"tidefern": "hydrosphere",
}


func deliver(plant_type: String) -> void:
	var axis: String = AXIS_MAP.get(plant_type, "")
	if axis.is_empty():
		return
	GameState.add_delivery(axis)
	EventBus.delivery_received.emit(plant_type, axis)
	MilestoneManager.check_milestones()


func get_atmosphere_percent() -> float:
	return clampf(float(GameState.atmosphere_delivered) / 12.0, 0.0, 1.0)


func get_soil_percent() -> float:
	return clampf(float(GameState.soil_delivered) / 6.0, 0.0, 1.0)


func get_hydro_percent() -> float:
	return clampf(float(GameState.hydro_delivered) / 3.0, 0.0, 1.0)


func is_all_complete() -> bool:
	return get_atmosphere_percent() >= 1.0 and get_soil_percent() >= 1.0 and get_hydro_percent() >= 1.0
