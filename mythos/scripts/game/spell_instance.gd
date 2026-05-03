class_name SpellInstance
extends RefCounted

var data: SpellData
var current_position: int = 0
var target_lane: int = -1
var owner_index: int = 0

func advance() -> void:
	current_position -= 1

func is_resolved() -> bool:
	return current_position <= 0
