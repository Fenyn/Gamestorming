class_name UpgradeData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var base_cost: float = 100.0
@export var cost_multiplier: float = 1.5
@export var max_level: int = -1
@export var effect_type: String = "generator_mult"
@export var effect_target: String = "all"
@export var effect_per_level: float = 0.5
@export var unlock_total_mana: float = 0.0
