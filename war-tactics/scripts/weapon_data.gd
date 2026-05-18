class_name WeaponData
extends Resource

enum MinigameType { WOBBLE, TIMING }

@export var weapon_name: String = ""
@export var attack_range: int = 4
@export var damage: int = 30
@export var minigame_type: MinigameType = MinigameType.WOBBLE
@export var ap_cost: int = 2
