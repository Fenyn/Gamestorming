extends Node

var data_logs: int = 0
var total_expeditions: int = 0
var unlocked_module_ids: Array[String] = []
var unlocked_implant_ids: Array[String] = []


func add_data_logs(amount: int) -> void:
	data_logs += amount
	EventBus.data_logs_earned.emit(amount)


func record_expedition() -> void:
	total_expeditions += 1


func unlock_module(module_id: String) -> void:
	if module_id not in unlocked_module_ids:
		unlocked_module_ids.append(module_id)


func unlock_implant(implant_id: String) -> void:
	if implant_id not in unlocked_implant_ids:
		unlocked_implant_ids.append(implant_id)
