extends Node

var _crops: Dictionary = {
	"turnip": preload("res://data/crops/turnip.tres"),
	"cabbage": preload("res://data/crops/cabbage.tres"),
	"wheat": preload("res://data/crops/wheat.tres"),
	"tomato": preload("res://data/crops/tomato.tres"),
	"pepper": preload("res://data/crops/pepper.tres"),
	"grapevine": preload("res://data/crops/grapevine.tres"),
	"prickly_pear": preload("res://data/crops/prickly_pear.tres"),
	"cotton": preload("res://data/crops/cotton.tres"),
	"corn": preload("res://data/crops/corn.tres"),
	"watermelon": preload("res://data/crops/watermelon.tres"),
}

var _tools: Dictionary = {
	"watering_can": preload("res://data/tools/watering_can.tres"),
	"trowel": preload("res://data/tools/trowel.tres"),
}

var _milestones: Dictionary = {
	"directive_1": preload("res://data/milestones/directive_1.tres"),
	"directive_2": preload("res://data/milestones/directive_2.tres"),
}

var _recipes: Dictionary = {
	"nutrient_starch": preload("res://data/recipes/nutrient_starch.tres"),
	"dried_greens": preload("res://data/recipes/dried_greens.tres"),
	"flour": preload("res://data/recipes/flour.tres"),
	"ration_pack": preload("res://data/recipes/ration_pack.tres"),
	"nutrient_paste": preload("res://data/recipes/nutrient_paste.tres"),
	"protein_concentrate": preload("res://data/recipes/protein_concentrate.tres"),
	"supplement_pack": preload("res://data/recipes/supplement_pack.tres"),
	"growth_accelerant": preload("res://data/recipes/fertilizer.tres"),
	"yield_booster": preload("res://data/recipes/yield_booster.tres"),
	"quality_enhancer": preload("res://data/recipes/quality_enhancer.tres"),
}

var _story_entries: Dictionary = {}
var _contacts: Dictionary = {}


func get_crop(id: String) -> CropData:
	return _crops.get(id, null) as CropData


func get_all_crops() -> Array:
	return _crops.values()


func get_crop_ids() -> Array:
	return _crops.keys()


func get_tool_data(id: String) -> ToolData:
	return _tools.get(id, null) as ToolData


func get_all_tools() -> Array:
	return _tools.values()


func get_milestone(id: String) -> MilestoneData:
	return _milestones.get(id, null) as MilestoneData


func get_all_milestones() -> Array:
	return _milestones.values()


func get_recipe(id: String) -> RecipeData:
	return _recipes.get(id, null) as RecipeData


func get_all_recipes() -> Array:
	return _recipes.values()


func get_story_entry(id: String) -> Resource:
	return _story_entries.get(id, null)


func get_all_story_entries() -> Array:
	return _story_entries.values()


func get_contact(id: String) -> Resource:
	return _contacts.get(id, null)


func get_all_contacts() -> Array:
	return _contacts.values()
