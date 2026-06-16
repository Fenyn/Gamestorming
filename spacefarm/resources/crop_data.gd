class_name CropData
extends Resource

enum WaterSchedule { ONCE_DAILY, TWICE_DAILY, ALTERNATE_DAYS, NIGHT_ONLY, NEVER }
enum AdjacencyRequirement { NONE, WINDOW, WALL, GROUP_3, THERMAL_REG }

@export_group("Identity")
@export var crop_id: String = ""
@export var display_name: String = ""
@export var designation: String = ""
@export var description: String = ""

@export_group("Growth")
## Which grow-ring bay this crop accepts: verdant, arid, fungal, or cryo.
@export var biome: String = "verdant"
@export var growth_days: int = 5
@export var water_schedule: WaterSchedule = WaterSchedule.ONCE_DAILY
@export var requires_adjacency: AdjacencyRequirement = AdjacencyRequirement.NONE
@export var base_quality: float = 1.0

@export_group("Economy")
@export var food_units: int = 1
@export var secondary_output_id: String = ""
@export var secondary_output_count: int = 0
@export var group_bonus_threshold: int = 0
@export var group_bonus_food: int = 0

@export_group("Visuals")
@export var growth_sprite: Texture2D = null
@export var sprite_row: int = 0
@export var crop_color: Color = Color.GREEN
@export var seed_color: Color = Color.DARK_GREEN


func get_active_name() -> String:
	if GameState.titan_ai_awakened and designation != "":
		return designation
	return display_name
