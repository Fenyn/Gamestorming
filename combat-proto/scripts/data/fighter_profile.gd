class_name FighterProfile
extends Resource

@export var display_name: String = "Fighter"
@export var stats: FighterStats = null
@export var attacks: Dictionary = {}
@export var available_perilous: Array[AttackData] = []


func get_attack(attack_key: String) -> AttackData:
	return attacks.get(attack_key, null) as AttackData


func get_directional_attack(type: String, direction: StanceDirection.Direction) -> AttackData:
	var dir_name: String = StanceDirection.to_display_name(direction).to_lower().replace("-", "_").replace(" ", "_")
	var key: String = type + "_" + dir_name
	return get_attack(key)
