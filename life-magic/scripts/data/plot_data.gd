class_name PlotData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var slot_count: int = 4
@export var plant_cost_base: float = 50.0
@export var plant_cost_mult: float = 2.5
@export var growth_ticks: int = 50
@export var tend_points: int = 3
@export var tend_options: PackedStringArray = []
@export var tend_power_base: float = 0.1
@export var full_bloom_bonus: Dictionary = {}
@export var unlock_total_mana: float = 0.0
