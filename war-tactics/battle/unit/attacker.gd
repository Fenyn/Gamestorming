class_name Attacker
extends Node

var weapon: WeaponData = null
var secondary_weapon: WeaponData = null


func setup(p_weapon: WeaponData, p_secondary: WeaponData = null) -> void:
	weapon = p_weapon
	secondary_weapon = p_secondary


func can_attack(ap: int) -> bool:
	if weapon == null:
		return false
	return ap >= weapon.ap_cost


func can_use_secondary(ap: int) -> bool:
	if secondary_weapon == null:
		return false
	return ap >= secondary_weapon.ap_cost


func get_range() -> int:
	if weapon == null:
		return 0
	return weapon.attack_range


func get_ap_cost() -> int:
	if weapon == null:
		return 0
	return weapon.ap_cost


func get_secondary_range() -> int:
	if secondary_weapon == null:
		return 0
	if secondary_weapon.throw_range > 0:
		return secondary_weapon.throw_range
	return secondary_weapon.attack_range
