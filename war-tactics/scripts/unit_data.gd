class_name UnitData
extends Resource

@export var unit_label: String = "R"
@export var unit_color: Color = Color(0.3, 0.5, 0.9)
@export var max_hp: int = 100
@export var max_ap: int = 3
@export var move_cost: int = 1
@export var is_enemy: bool = false
@export var weapon: WeaponData = null
@export var secondary_weapon: WeaponData = null
