extends Node

var squad_ids: Array[String] = []
var squad: Array[UnitRunData] = []
var current_xp: int = 0
var current_map_node: int = 0


func reset() -> void:
	squad_ids = ["rifleman", "sniper", "grenadier"]
	current_xp = 0
	current_map_node = 0
	squad.clear()
	for unit_id: String in squad_ids:
		var run_data: UnitRunData = UnitRunData.new()
		run_data.unit_id = unit_id
		var data: UnitData = Database.get_unit_data(unit_id)
		if data:
			run_data.current_hp = data.max_hp
			run_data.max_hp = data.max_hp
		else:
			push_warning("RunState: unit data not found for '%s'" % unit_id)
		squad.append(run_data)


func is_unit_alive(index: int) -> bool:
	if index < 0 or index >= squad.size():
		return false
	return squad[index].is_alive()


func get_living_indices() -> Array[int]:
	var result: Array[int] = []
	for i: int in squad.size():
		if squad[i].is_alive():
			result.append(i)
	return result


func add_medal(index: int, medal: MedalData) -> void:
	if index >= 0 and index < squad.size():
		squad[index].medals.append(medal)


func get_bonus(index: int, medal_type: MedalData.MedalType) -> int:
	if index < 0 or index >= squad.size():
		return 0
	return squad[index].get_bonus(medal_type)


func add_xp(amount: int) -> void:
	current_xp += amount


func spend_xp(amount: int) -> bool:
	if current_xp < amount:
		return false
	current_xp -= amount
	return true


func advance_map_node() -> void:
	current_map_node += 1


func heal_all() -> void:
	for entry: UnitRunData in squad:
		if entry.is_alive():
			entry.current_hp = entry.max_hp
