class_name RecipeData
extends Resource

@export_group("Identity")
@export var recipe_id: String = ""
@export var display_name: String = ""

@export_group("Processing")
@export var machine_type: String = ""
@export var input_items: Array[Dictionary] = []
@export var output_item_id: String = ""
@export var output_count: int = 1
@export var process_time: float = 3.0
