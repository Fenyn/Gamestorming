extends Node

const SAVE_PATH := "user://save_data.json"

const STARTER_EQUIPMENT := [
	"grinder", "pour_over_station", "kettle", "hot_water_station", "cup_stack",
	"lid_dispenser", "register", "hand_off", "counter_pad",
]

const EQUIPMENT_SHOP := {
	"aeropress": {"price": 100.0, "name": "Aeropress"},
	"fridge": {"price": 75.0, "name": "Fridge"},
	"steam_station": {"price": 125.0, "name": "Steam Station"},
	"syrup_rack": {"price": 100.0, "name": "Syrup Rack"},
	"sauce_station": {"price": 125.0, "name": "Sauce Station"},
	"mocha_prep": {"price": 150.0, "name": "Mocha Prep"},
	"caramel_prep": {"price": 100.0, "name": "Caramel Prep"},
	"bottle_rack": {"price": 50.0, "name": "Bottle Rack"},
}

const UPGRADE_SHOP := {
	"shot_timer": {"stars": 15, "name": "Shot Timer"},
	"temp_gauge": {"stars": 15, "name": "Temp Gauge"},
	"large_kettle": {"stars": 20, "name": "Large Kettle"},
	"electric_kettle": {"stars": 30, "name": "Electric Kettle"},
	"electric_grinder": {"stars": 40, "name": "Electric Grinder"},
	"auto_shutoff_wand": {"stars": 60, "name": "Auto-Shutoff Wand"},
	"plumbed_hot_water": {"stars": 75, "name": "Plumbed Hot Water"},
	"semi_auto_espresso": {"stars": 80, "name": "Semi-Auto Espresso"},
	"batch_brewer": {"stars": 100, "name": "Batch Brewer"},
	"auto_grinder": {"stars": 120, "name": "Auto Grinder"},
	"auto_steamer": {"stars": 150, "name": "Auto Steamer"},
	"full_espresso": {"stars": 200, "name": "Full Espresso Machine"},
}

const SIZE_SHOP := {
	2: {"price": 60.0, "name": "Large"},
	3: {"price": 120.0, "name": "Extra Large"},
}

const SYRUP_SHOP := {
	0: {"price": 40.0, "name": "Vanilla"},
	1: {"price": 40.0, "name": "Caramel"},
	2: {"price": 50.0, "name": "Hazelnut"},
	3: {"price": 50.0, "name": "Toffee Nut"},
}

const SAUCE_SHOP := {
	0: {"price": 0.0, "name": "Mocha", "bundled": "mocha_prep"},
	1: {"price": 60.0, "name": "Caramel Sauce"},
	2: {"price": 75.0, "name": "White Mocha"},
}

const DRINK_PREREQUISITES := {
	0: [],
	1: ["aeropress"],
	2: ["aeropress", "fridge", "steam_station"],
	3: ["aeropress", "fridge", "steam_station"],
	4: ["aeropress"],
	5: ["aeropress"],
	6: ["aeropress", "fridge", "steam_station", "sauce_station", "mocha_prep"],
}

var owned_equipment: Array = []
var owned_sizes: Array = []
var owned_syrups: Array = []
var owned_sauces: Array = []
var owned_upgrades: Array = []
var active_menu: Array = []
var money := 0.0
var stars := 0
var lifetime_stars := 0

func init_new_game() -> void:
	owned_equipment = STARTER_EQUIPMENT.duplicate()
	owned_sizes = [0, 1]
	owned_syrups = []
	owned_sauces = []
	owned_upgrades = []
	active_menu = []
	money = 0.0
	stars = 0
	lifetime_stars = 0
	_auto_activate_new_drinks()

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_to_file() -> void:
	var data := {
		"owned_equipment": owned_equipment,
		"owned_sizes": owned_sizes,
		"owned_syrups": owned_syrups,
		"owned_sauces": owned_sauces,
		"owned_upgrades": owned_upgrades,
		"active_menu": active_menu,
		"money": money,
		"stars": stars,
		"lifetime_stars": lifetime_stars,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func load_from_file() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	var data: Dictionary = json.data
	owned_equipment = Array(data.get("owned_equipment", []))
	owned_sizes = _parse_int_array(data.get("owned_sizes", []))
	owned_syrups = _parse_int_array(data.get("owned_syrups", []))
	owned_sauces = _parse_int_array(data.get("owned_sauces", []))
	owned_upgrades = Array(data.get("owned_upgrades", []))
	active_menu = _parse_int_array(data.get("active_menu", []))
	money = float(data.get("money", 0.0))
	stars = int(data.get("stars", 0))
	lifetime_stars = int(data.get("lifetime_stars", 0))
	return true

func _parse_int_array(src: Array) -> Array:
	var result: Array = []
	for v in src:
		result.append(int(v))
	return result

func buy_equipment(id: String) -> bool:
	if id in owned_equipment or id not in EQUIPMENT_SHOP:
		return false
	var entry: Dictionary = EQUIPMENT_SHOP[id]
	if money < entry["price"]:
		return false
	money -= entry["price"]
	owned_equipment.append(id)
	if id == "mocha_prep" and 0 not in owned_sauces:
		owned_sauces.append(0)
	_auto_activate_new_drinks()
	save_to_file()
	return true

func buy_size(size: int) -> bool:
	if size in owned_sizes or size not in SIZE_SHOP:
		return false
	var entry: Dictionary = SIZE_SHOP[size]
	if money < entry["price"]:
		return false
	money -= entry["price"]
	owned_sizes.append(size)
	owned_sizes.sort()
	save_to_file()
	return true

func buy_syrup(syrup: int) -> bool:
	if syrup in owned_syrups or syrup not in SYRUP_SHOP:
		return false
	if "syrup_rack" not in owned_equipment:
		return false
	var entry: Dictionary = SYRUP_SHOP[syrup]
	if money < entry["price"]:
		return false
	money -= entry["price"]
	owned_syrups.append(syrup)
	save_to_file()
	return true

func buy_sauce(sauce: int) -> bool:
	if sauce in owned_sauces or sauce not in SAUCE_SHOP:
		return false
	if "sauce_station" not in owned_equipment:
		return false
	var entry: Dictionary = SAUCE_SHOP[sauce]
	if entry.get("bundled", "") != "":
		return false
	if money < entry["price"]:
		return false
	money -= entry["price"]
	owned_sauces.append(sauce)
	save_to_file()
	return true

func buy_upgrade(id: String) -> bool:
	if id in owned_upgrades or id not in UPGRADE_SHOP:
		return false
	var entry: Dictionary = UPGRADE_SHOP[id]
	if stars < entry["stars"]:
		return false
	stars -= entry["stars"]
	owned_upgrades.append(id)
	save_to_file()
	return true

func toggle_menu_drink(drink: int) -> void:
	if drink in active_menu:
		active_menu.erase(drink)
	elif drink in get_unlocked_drinks():
		active_menu.append(drink)
	save_to_file()

func get_unlocked_drinks() -> Array:
	var result: Array = []
	for drink in DRINK_PREREQUISITES:
		var prereqs: Array = DRINK_PREREQUISITES[drink]
		var has_all := true
		for equip in prereqs:
			if equip not in owned_equipment:
				has_all = false
				break
		if has_all:
			result.append(drink)
	return result

func is_drink_active(drink: int) -> bool:
	return drink in active_menu

func get_menu_drinks() -> Array:
	return active_menu.duplicate()

func _auto_activate_new_drinks() -> void:
	for drink in get_unlocked_drinks():
		if drink not in active_menu:
			active_menu.append(drink)
