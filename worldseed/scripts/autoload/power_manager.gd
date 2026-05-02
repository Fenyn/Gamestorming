extends Node

var supply: float = 10.0
var _demand_sources: Dictionary = {}
var is_brownout: bool = false


func add_supply(watts: float) -> void:
	supply += watts
	_update()


func remove_supply(watts: float) -> void:
	supply -= watts
	_update()


func register_demand(source_id: String, watts: float) -> void:
	_demand_sources[source_id] = watts
	_update()


func unregister_demand(source_id: String) -> void:
	_demand_sources.erase(source_id)
	_update()


func get_total_demand() -> float:
	var total: float = 0.0
	for key in _demand_sources:
		total += _demand_sources[key] as float
	return total


func get_available() -> float:
	return supply - get_total_demand()


func _update() -> void:
	var demand: float = get_total_demand()
	var was_brownout: bool = is_brownout
	is_brownout = demand > supply
	EventBus.power_changed.emit(supply, demand)
	if is_brownout and not was_brownout:
		EventBus.brownout_started.emit()
	elif not is_brownout and was_brownout:
		EventBus.brownout_ended.emit()


func reset_to_defaults() -> void:
	supply = 10.0
	_demand_sources.clear()
	is_brownout = false
