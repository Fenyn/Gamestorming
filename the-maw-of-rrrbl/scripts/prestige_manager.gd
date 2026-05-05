extends Node
class_name PrestigeManager

signal void_marbles_changed(total: int)
signal upgrade_purchased(upgrade_id: String)
signal build_space_changed(new_radius: float)
signal piece_category_unlocked(category: String)

var void_marbles: int = 0
var cycle: int = 0
var upgrade_levels: Dictionary = {}
var unlocked_categories: Dictionary = {}

const BASE_BUILD_RADIUS: float = 8.0
const BUILD_RADIUS_PER_LEVEL: float = 4.0
const BASE_MAW_THRESHOLD: float = 2000.0
const BASE_STARTING_SPARKS: float = 100.0

## Piece category unlock costs (Void Marbles)
const CATEGORY_UNLOCK_COSTS: Dictionary = {
	"STRAIGHT": 0,
	"CORNER": 0,
	"CURVE": 3,
	"TUNNEL": 3,
	"END_CAP": 3,
	"RAMP": 5,
	"BEND": 5,
	"S_CURVE": 8,
	"WAVE": 8,
	"SPLIT": 8,
	"BUMP": 12,
	"FUNNEL": 12,
	"HELIX": 20,
	"CROSS": 20,
	"portal_deep": 5,
	"portal_nightmare": 10,
	"portal_gilt": 15,
	"portal_void": 25,
}

## Passive upgrades (separate from piece unlocks)
var upgrades: Array[Dictionary] = [
	{
		"id": "build_space",
		"name": "Expand Build Space",
		"description": "Increases the building area",
		"base_cost": 3,
		"cost_scale": 2.0,
		"max_level": 5,
	},
	{
		"id": "starting_sparks",
		"name": "Starting Capital",
		"description": "Begin each cycle with more Sparks",
		"base_cost": 2,
		"cost_scale": 2.0,
		"max_level": 8,
	},
	{
		"id": "spark_multiplier",
		"name": "Spark Yield",
		"description": "Orbs earn more Sparks per distance",
		"base_cost": 5,
		"cost_scale": 3.0,
		"max_level": 5,
	},
	{
		"id": "maw_capacity",
		"name": "Maw Capacity",
		"description": "The Maw takes longer to fill",
		"base_cost": 4,
		"cost_scale": 2.5,
		"max_level": 4,
	},
	{
		"id": "blueprint_slots",
		"name": "Blueprint Slots",
		"description": "Save more track layouts",
		"base_cost": 2,
		"cost_scale": 2.0,
		"max_level": 3,
	},
]

# --- Category unlocks ---

func is_category_unlocked(category_name: String) -> bool:
	var cost: int = CATEGORY_UNLOCK_COSTS.get(category_name, -1) as int
	if cost == 0:
		return true
	return unlocked_categories.get(category_name, false) as bool

func get_category_cost(category_name: String) -> int:
	return CATEGORY_UNLOCK_COSTS.get(category_name, -1) as int

func unlock_category(category_name: String) -> bool:
	if is_category_unlocked(category_name):
		return false
	var cost: int = get_category_cost(category_name)
	if cost < 0 or void_marbles < cost:
		return false
	void_marbles -= cost
	unlocked_categories[category_name] = true
	void_marbles_changed.emit(void_marbles)
	piece_category_unlocked.emit(category_name)
	return true

# --- Passive upgrades ---

func get_level(upgrade_id: String) -> int:
	return upgrade_levels.get(upgrade_id, 0) as int

func get_upgrade_cost(upgrade_id: String) -> int:
	var data: Dictionary = _find_upgrade(upgrade_id)
	if data.is_empty():
		return 999
	var level: int = get_level(upgrade_id)
	if level >= (data["max_level"] as int):
		return -1
	return int((data["base_cost"] as int) * pow(data["cost_scale"] as float, level))

func can_purchase_upgrade(upgrade_id: String) -> bool:
	var cost: int = get_upgrade_cost(upgrade_id)
	if cost < 0:
		return false
	return void_marbles >= cost

func purchase_upgrade(upgrade_id: String) -> bool:
	if not can_purchase_upgrade(upgrade_id):
		return false
	var cost: int = get_upgrade_cost(upgrade_id)
	void_marbles -= cost
	upgrade_levels[upgrade_id] = get_level(upgrade_id) + 1
	void_marbles_changed.emit(void_marbles)
	upgrade_purchased.emit(upgrade_id)

	if upgrade_id == "build_space":
		build_space_changed.emit(get_build_radius())

	return true

# --- Prestige cycle ---

func complete_cycle(consumed_sparks: float) -> int:
	cycle += 1
	var earned: int = maxi(int(consumed_sparks / 1000.0), 1)
	void_marbles += earned
	void_marbles_changed.emit(void_marbles)
	return earned

# --- Computed values ---

func get_maw_threshold() -> float:
	return BASE_MAW_THRESHOLD * (1.0 + get_level("maw_capacity") * 0.4)

func get_build_radius() -> float:
	return BASE_BUILD_RADIUS + get_level("build_space") * BUILD_RADIUS_PER_LEVEL

func get_starting_sparks() -> float:
	return BASE_STARTING_SPARKS + get_level("starting_sparks") * 50.0

func get_spark_multiplier() -> float:
	return 1.0 + get_level("spark_multiplier") * 0.3

func get_blueprint_slot_count() -> int:
	return 1 + get_level("blueprint_slots")

# --- Internals ---

func _find_upgrade(upgrade_id: String) -> Dictionary:
	for u: Dictionary in upgrades:
		if (u["id"] as String) == upgrade_id:
			return u
	return {}

func to_save_data() -> Dictionary:
	return {
		"void_marbles": void_marbles,
		"cycle": cycle,
		"upgrade_levels": upgrade_levels.duplicate(),
		"unlocked_categories": unlocked_categories.duplicate(),
	}

func load_save_data(data: Dictionary) -> void:
	void_marbles = data.get("void_marbles", 0) as int
	cycle = data.get("cycle", 0) as int
	upgrade_levels = (data.get("upgrade_levels", {}) as Dictionary).duplicate()
	unlocked_categories = (data.get("unlocked_categories", {}) as Dictionary).duplicate()
	void_marbles_changed.emit(void_marbles)
	build_space_changed.emit(get_build_radius())
