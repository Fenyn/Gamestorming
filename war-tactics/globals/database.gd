extends Node

var _weapon_data: Dictionary = {}
var _unit_data: Dictionary = {}


func _ready() -> void:
	_register_weapon("rifle", "res://data/weapons/rifle.tres")
	_register_weapon("sniper_rifle", "res://data/weapons/sniper_rifle.tres")
	_register_weapon("enemy_rifle", "res://data/weapons/enemy_rifle.tres")

	_register_unit("rifleman", "res://data/units/rifleman.tres")
	_register_unit("sniper", "res://data/units/sniper.tres")
	_register_unit("grenadier", "res://data/units/grenadier.tres")
	_register_unit("dummy", "res://data/units/dummy.tres")


func get_weapon_data(id: String) -> WeaponData:
	return _weapon_data.get(id, null) as WeaponData


func get_unit_data(id: String) -> UnitData:
	return _unit_data.get(id, null) as UnitData


func _register_weapon(id: String, path: String) -> void:
	var resource: Resource = load(path)
	if resource:
		_weapon_data[id] = resource


func _register_unit(id: String, path: String) -> void:
	var resource: Resource = load(path)
	if resource:
		_unit_data[id] = resource
