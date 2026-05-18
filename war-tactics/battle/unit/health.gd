class_name Health
extends Node

signal hp_changed(current: int, max_val: int)
signal died

var max_hp: int = 100
var current_hp: int = 100


func setup(p_max_hp: int) -> void:
	max_hp = p_max_hp
	current_hp = p_max_hp
	hp_changed.emit(current_hp, max_hp)


func take_damage(amount: int) -> void:
	current_hp = maxi(current_hp - amount, 0)
	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		died.emit()


func is_alive() -> bool:
	return current_hp > 0
