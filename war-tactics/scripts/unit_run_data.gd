class_name UnitRunData
extends Resource

@export var unit_id: String = ""
@export var current_hp: int = 100
@export var max_hp: int = 100
@export var medals: Array[MedalData] = []


func is_alive() -> bool:
	return current_hp > 0


func get_bonus(medal_type: MedalData.MedalType) -> int:
	var total: int = 0
	for medal: MedalData in medals:
		if medal.medal_type == medal_type:
			total += medal.buff_value
	return total
