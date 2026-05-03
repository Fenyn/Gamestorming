class_name BuildingInstance
extends RefCounted

var data: BuildingData
var current_health: int = 0
var max_health: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var owner_index: int = 0

func take_damage(amount: int) -> int:
	current_health -= amount
	return amount

func is_destroyed() -> bool:
	return current_health <= 0
