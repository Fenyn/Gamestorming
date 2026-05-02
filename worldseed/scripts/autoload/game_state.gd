extends Node

var elapsed_time: float = 0.0
var sandbox_mode: bool = false

# Delivery counts per terraform axis
var atmosphere_delivered: int = 0
var soil_delivered: int = 0
var hydro_delivered: int = 0

# Resource inventory (harvest crates held for spending)
var resource_crates: Dictionary = {
	"aerolume": 0,
	"loamspine": 0,
	"tidefern": 0,
}

# O2 tank tier (0 = basic, 1 = extended, 2 = advanced, 3 = retired)
var o2_tank_tier: int = 0

# Unlocked plants
var plants_unlocked: Array[String] = ["aerolume"]

# Autosave data
var _save_data: Dictionary = {}


func _process(delta: float) -> void:
	elapsed_time += delta


func get_delivery_count(axis: String) -> int:
	match axis:
		"atmosphere":
			return atmosphere_delivered
		"soil":
			return soil_delivered
		"hydrosphere":
			return hydro_delivered
	return 0


func add_delivery(axis: String, count: int = 1) -> void:
	match axis:
		"atmosphere":
			atmosphere_delivered += count
		"soil":
			soil_delivered += count
		"hydrosphere":
			hydro_delivered += count


func add_resource(plant_type: String, count: int = 1) -> void:
	if plant_type in resource_crates:
		resource_crates[plant_type] += count


func spend_resource(plant_type: String, count: int = 1) -> bool:
	if plant_type in resource_crates and resource_crates[plant_type] >= count:
		resource_crates[plant_type] -= count
		return true
	return false


func get_total_resources() -> int:
	var total: int = 0
	for key in resource_crates:
		total += resource_crates[key] as int
	return total


func is_plant_unlocked(plant_type: String) -> bool:
	return plant_type in plants_unlocked


func unlock_plant(plant_type: String) -> void:
	if plant_type not in plants_unlocked:
		plants_unlocked.append(plant_type)
		EventBus.plant_unlocked.emit(plant_type)


func autosave() -> void:
	_save_data = to_dict()
	EventBus.autosave_triggered.emit()


func load_autosave() -> void:
	if _save_data.is_empty():
		return
	from_dict(_save_data)


func to_dict() -> Dictionary:
	return {
		"elapsed_time": elapsed_time,
		"atmosphere_delivered": atmosphere_delivered,
		"soil_delivered": soil_delivered,
		"hydro_delivered": hydro_delivered,
		"resource_crates": resource_crates.duplicate(),
		"o2_tank_tier": o2_tank_tier,
		"plants_unlocked": plants_unlocked.duplicate(),
		"sandbox_mode": sandbox_mode,
	}


func from_dict(data: Dictionary) -> void:
	elapsed_time = data.get("elapsed_time", 0.0) as float
	atmosphere_delivered = data.get("atmosphere_delivered", 0) as int
	soil_delivered = data.get("soil_delivered", 0) as int
	hydro_delivered = data.get("hydro_delivered", 0) as int
	var crates: Dictionary = data.get("resource_crates", {})
	for key in resource_crates:
		resource_crates[key] = crates.get(key, 0) as int
	o2_tank_tier = data.get("o2_tank_tier", 0) as int
	plants_unlocked.clear()
	var unlocked: Array = data.get("plants_unlocked", ["aerolume"])
	for p in unlocked:
		plants_unlocked.append(str(p))
	sandbox_mode = data.get("sandbox_mode", false) as bool


func reset_to_defaults() -> void:
	elapsed_time = 0.0
	sandbox_mode = false
	atmosphere_delivered = 0
	soil_delivered = 0
	hydro_delivered = 0
	resource_crates = {"aerolume": 0, "loamspine": 0, "tidefern": 0}
	o2_tank_tier = 0
	plants_unlocked = ["aerolume"]
	_save_data = {}
