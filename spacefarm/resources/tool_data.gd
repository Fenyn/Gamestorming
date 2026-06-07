class_name ToolData
extends Resource

enum ToolType { WATERING_CAN, TROWEL, HARVESTER, SEED_PLANTER }

@export_group("Identity")
@export var tool_id: String = ""
@export var display_name: String = ""
@export var tool_type: ToolType = ToolType.WATERING_CAN

@export_group("Stats")
@export var tier: int = 1
@export var area_width: int = 1
@export var area_height: int = 1
@export var efficiency: float = 1.0

@export_group("Visuals")
@export var tool_color: Color = Color.STEEL_BLUE
