class_name WeaponData
extends Resource

enum MinigameType { WOBBLE, TIMING }
enum WeaponType { STANDARD, GRENADE }

@export var weapon_name: String = ""
@export var weapon_type: WeaponType = WeaponType.STANDARD
@export var attack_range: int = 4
@export var damage: int = 30
@export var minigame_type: MinigameType = MinigameType.WOBBLE
@export var ap_cost: int = 2
@export var aoe_radius: int = 0
@export var throw_range: int = 0
