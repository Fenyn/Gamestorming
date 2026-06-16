extends Node

const TOOLBAR_SIZE: int = 10
const BACKPACK_SIZE: int = 20
const SAVE_PATH: String = "user://spacefarm_save.json"
const SAVE_VERSION: int = 1
const MAX_ENERGY: float = 100.0
const TIRED_WAKE_FRACTION: float = 0.75

# --- Time ---
var day: int = 1
var season: int = 1
var total_days: int = 0

# --- Unified Inventory ---
var items: Dictionary = {}
var toolbar: Array[String] = []
var active_slot: int = 0

# --- Directives ---
var active_directive_id: String = "directive_1"
var food_shipped_total: int = 0
var items_shipped: Dictionary = {}
var directives_completed: int = 0

# --- Progression ---
var unlocked_milestones: Dictionary = {}
var unlocked_sub_milestones: Dictionary = {}
var unlocked_crops: Array[String] = ["turnip", "cabbage", "wheat"]
var unlocked_modules: Array[String] = ["core"]
var unlocked_story_entries: Array[String] = []
var unlocked_contacts: Array[String] = []

# --- Titan AI ---
var titan_ai_awakened: bool = false

# --- Crew (managed by CrewManager, persisted here) ---

# --- Automation ---
var worm_count: int = 0
var bee_count: int = 0
var worm_assignments: Dictionary = {}
var bee_routes: Array[Dictionary] = []

# --- Energy ---
var energy: float = MAX_ENERGY

# --- Daily Stats (reset each morning, not saved) ---
var today_harvested: Dictionary = {}
var day_start_food_shipped: int = 0

# --- Crop tile snapshots, captured on save (key: room/bay/tile) ---
var crop_tile_states: Dictionary = {}


func _ready() -> void:
	toolbar.resize(TOOLBAR_SIZE)
	toolbar.fill("")
	toolbar[0] = "watering_can"
	toolbar[1] = "trowel"
	_init_starting_inventory()
	EventBus.day_started.connect(_on_day_started)
	EventBus.crop_harvested.connect(_on_crop_harvested)


func _on_day_started(_day: int) -> void:
	today_harvested = {}
	day_start_food_shipped = food_shipped_total


func _on_crop_harvested(_tile_pos: Vector2i, crop_id: String, _quality: float) -> void:
	today_harvested[crop_id] = today_harvested.get(crop_id, 0) + 1


# --- Energy ---

func spend_energy(amount: float) -> bool:
	if energy < amount:
		EventBus.notification_requested.emit("Too exhausted. Sleep to recover.")
		return false
	energy -= amount
	EventBus.energy_changed.emit(energy, MAX_ENERGY)
	return true


func wake_up(rested: bool) -> void:
	energy = MAX_ENERGY if rested else MAX_ENERGY * TIRED_WAKE_FRACTION
	EventBus.energy_changed.emit(energy, MAX_ENERGY)


func _init_starting_inventory() -> void:
	add_item("watering_can", 1)
	add_item("trowel", 1)
	add_item("turnip_seed", 8)
	add_item("cabbage_seed", 6)
	add_item("wheat_seed", 4)
	_auto_assign_toolbar("turnip_seed")
	_auto_assign_toolbar("cabbage_seed")
	_auto_assign_toolbar("wheat_seed")


func get_active_item_id() -> String:
	if active_slot < 0 or active_slot >= toolbar.size():
		return ""
	return toolbar[active_slot]


func set_active_slot(index: int) -> void:
	if index < 0 or index >= TOOLBAR_SIZE:
		return
	active_slot = index
	EventBus.tool_switched.emit(get_active_item_id())


func is_active_tool(tool_id: String) -> bool:
	return get_active_item_id() == tool_id


func is_active_seed() -> bool:
	return get_active_item_id().ends_with("_seed")


func get_active_seed_crop_id() -> String:
	var item_id: String = get_active_item_id()
	if item_id.ends_with("_seed"):
		return item_id.substr(0, item_id.length() - 5)
	return ""


func is_active_fertilizer() -> bool:
	var item_id: String = get_active_item_id()
	return item_id in ["growth_accelerant", "yield_booster", "quality_enhancer"]


# --- Item Management ---

func add_item(item_id: String, count: int) -> void:
	items[item_id] = items.get(item_id, 0) + count
	EventBus.inventory_changed.emit()


func remove_item(item_id: String, count: int) -> bool:
	var current: int = items.get(item_id, 0)
	if current < count:
		return false
	items[item_id] = current - count
	if items[item_id] <= 0:
		items.erase(item_id)
		_remove_from_toolbar(item_id)
	EventBus.inventory_changed.emit()
	return true


func get_item_count(item_id: String) -> int:
	return items.get(item_id, 0)


func has_item(item_id: String, count: int = 1) -> bool:
	return items.get(item_id, 0) >= count


func add_seeds(crop_id: String, count: int) -> void:
	var seed_id: String = crop_id + "_seed"
	add_item(seed_id, count)
	_auto_assign_toolbar(seed_id)


func add_harvested(crop_id: String, count: int) -> void:
	add_item(crop_id, count)


func add_processed(item_id: String, count: int) -> void:
	add_item(item_id, count)


func _auto_assign_toolbar(item_id: String) -> void:
	for i: int in range(toolbar.size()):
		if toolbar[i] == item_id:
			return
	for i: int in range(toolbar.size()):
		if toolbar[i] == "":
			toolbar[i] = item_id
			return


func _remove_from_toolbar(item_id: String) -> void:
	if item_id in ["watering_can", "trowel"]:
		return
	for i: int in range(toolbar.size()):
		if toolbar[i] == item_id and items.get(item_id, 0) <= 0:
			toolbar[i] = ""


# --- Compatibility helpers for shipping/inventory panels ---

func get_all_seeds() -> Dictionary:
	var result: Dictionary = {}
	for item_id: String in items:
		if item_id.ends_with("_seed") and items[item_id] > 0:
			result[item_id] = items[item_id]
	return result


func get_all_harvested() -> Dictionary:
	var result: Dictionary = {}
	for item_id: String in items:
		if items[item_id] <= 0:
			continue
		if item_id.ends_with("_seed"):
			continue
		if Database.get_crop(item_id) != null:
			result[item_id] = items[item_id]
	return result


func get_all_processed() -> Dictionary:
	var result: Dictionary = {}
	for item_id: String in items:
		if items[item_id] <= 0:
			continue
		if item_id.ends_with("_seed"):
			continue
		if Database.get_crop(item_id) != null:
			continue
		if Database.get_tool_data(item_id) != null:
			continue
		result[item_id] = items[item_id]
	return result


# --- Save/Load ---

func to_dict() -> Dictionary:
	return {
		"day": day,
		"season": season,
		"total_days": total_days,
		"items": items.duplicate(),
		"toolbar": toolbar.duplicate(),
		"active_slot": active_slot,
		"active_directive_id": active_directive_id,
		"food_shipped_total": food_shipped_total,
		"items_shipped": items_shipped.duplicate(),
		"directives_completed": directives_completed,
		"unlocked_milestones": unlocked_milestones.duplicate(),
		"unlocked_sub_milestones": unlocked_sub_milestones.duplicate(),
		"unlocked_crops": unlocked_crops.duplicate(),
		"unlocked_modules": unlocked_modules.duplicate(),
		"unlocked_story_entries": unlocked_story_entries.duplicate(),
		"unlocked_contacts": unlocked_contacts.duplicate(),
		"titan_ai_awakened": titan_ai_awakened,
		"crew": CrewManager.to_dict(),
		"worm_count": worm_count,
		"bee_count": bee_count,
		"worm_assignments": worm_assignments.duplicate(),
		"bee_routes": bee_routes.duplicate(),
		"energy": energy,
		"crop_tile_states": crop_tile_states.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	day = data.get("day", 1)
	season = data.get("season", 1)
	total_days = data.get("total_days", 0)
	items = data.get("items", {})
	toolbar = Array(data.get("toolbar", []), TYPE_STRING, &"", null)
	if toolbar.size() < TOOLBAR_SIZE:
		toolbar.resize(TOOLBAR_SIZE)
	active_slot = data.get("active_slot", 0)
	active_directive_id = data.get("active_directive_id", "directive_1")
	food_shipped_total = data.get("food_shipped_total", 0)
	items_shipped = data.get("items_shipped", {})
	directives_completed = data.get("directives_completed", 0)
	unlocked_milestones = data.get("unlocked_milestones", {})
	unlocked_sub_milestones = data.get("unlocked_sub_milestones", {})
	unlocked_crops = Array(data.get("unlocked_crops", []), TYPE_STRING, &"", null)
	unlocked_modules = Array(data.get("unlocked_modules", []), TYPE_STRING, &"", null)
	unlocked_story_entries = Array(data.get("unlocked_story_entries", []), TYPE_STRING, &"", null)
	unlocked_contacts = Array(data.get("unlocked_contacts", []), TYPE_STRING, &"", null)
	titan_ai_awakened = data.get("titan_ai_awakened", false)
	CrewManager.from_dict(data.get("crew", {}))
	worm_count = data.get("worm_count", 0)
	bee_count = data.get("bee_count", 0)
	worm_assignments = data.get("worm_assignments", {})
	bee_routes = data.get("bee_routes", [])
	energy = data.get("energy", MAX_ENERGY)
	crop_tile_states = data.get("crop_tile_states", {})

func save_game() -> void:
	crop_tile_states = {}
	for node: Node in get_tree().get_nodes_in_group("crop_tiles"):
		var tile: CropTile = node as CropTile
		if tile == null or tile.get_state_name() == "Empty":
			continue
		crop_tile_states[tile.get_save_key()] = tile.save_data()
	var handler: SaveFileHandler = SaveFileHandler.new(SAVE_PATH, SAVE_VERSION)
	handler.save_dict(to_dict())


func restore_crop_tiles() -> void:
	if crop_tile_states.is_empty():
		return
	for node: Node in get_tree().get_nodes_in_group("crop_tiles"):
		var tile: CropTile = node as CropTile
		if tile == null:
			continue
		var data: Variant = crop_tile_states.get(tile.get_save_key(), null)
		if data is Dictionary:
			tile.load_data(data)
