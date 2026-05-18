class_name Attacker
extends Node

var weapon: WeaponData = null


func setup(p_weapon: WeaponData) -> void:
	weapon = p_weapon


func can_attack(ap: int) -> bool:
	if weapon == null:
		return false
	return ap >= weapon.ap_cost


func get_range() -> int:
	if weapon == null:
		return 0
	return weapon.attack_range


func get_ap_cost() -> int:
	if weapon == null:
		return 0
	return weapon.ap_cost
