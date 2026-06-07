class_name MilestoneData
extends Resource

@export_group("Identity")
@export var milestone_id: String = ""
@export var directive_number: int = 1
@export var display_name: String = ""
@export var ai_message: String = ""

@export_group("Requirements")
@export var required_food_units: int = 0
@export var required_items: Dictionary = {}

@export_group("Rewards")
@export var unlocked_crops: Array[String] = []
@export var unlocked_modules: Array[String] = []
@export var unlocked_story_entries: Array[String] = []
@export var lore_hint: String = ""
