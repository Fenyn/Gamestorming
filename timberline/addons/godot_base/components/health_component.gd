class_name HealthComponent
extends Node

signal hp_changed(current: int, max_val: int)
signal damage_taken(amount: int)
signal healed(amount: int)
signal died

@export var max_hp: int = 100

var current_hp: int = 0


func _ready() -> void:
	current_hp = max_hp


func setup(p_max_hp: int, p_current_hp: int = -1) -> void:
	max_hp = p_max_hp
	current_hp = p_current_hp if p_current_hp >= 0 else p_max_hp
	hp_changed.emit(current_hp, max_hp)


func take_damage(amount: int) -> void:
	var actual: int = mini(amount, current_hp)
	current_hp = maxi(current_hp - amount, 0)
	damage_taken.emit(actual)
	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		died.emit()


func heal(amount: int) -> void:
	var actual: int = mini(amount, max_hp - current_hp)
	current_hp = mini(current_hp + amount, max_hp)
	healed.emit(actual)
	hp_changed.emit(current_hp, max_hp)


func is_alive() -> bool:
	return current_hp > 0


func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)
