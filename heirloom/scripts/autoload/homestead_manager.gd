extends Node

var _upgrade_catalog: Dictionary = {}


func _ready() -> void:
	_build_catalog()


func _build_catalog() -> void:
	_define("clear_yard", "Clear the Yard", 1, "general", 0.0,
		{}, [], "Access shed, garden area, and back acreage. Yields free materials.")
	_define("repair_well", "Repair the Well", 1, "water", 0.0,
		{"wood_plank": 2, "salvage_part": 1}, [], "Free drinking water.")
	_define("fix_stove", "Fix the Stove", 1, "food", 15.0,
		{"salvage_part": 1}, [], "Enables cooking. Halves food costs.")
	_define("patch_roof", "Patch the Roof", 1, "shelter", 20.0,
		{"wood_plank": 3}, [], "Full sleep recovery (100% vs 60%).")

	_define("garden_beds", "Garden Beds", 2, "food", 25.0,
		{"wood_plank": 4}, ["clear_yard", "repair_well"], "Grow free food.")
	_define("shed_repair", "Shed Repair", 2, "workshop", 10.0,
		{"wood_plank": 6, "salvage_part": 2}, ["clear_yard"], "Salvage station. Break down junk for free parts.")
	_define("chicken_coop", "Chicken Coop", 2, "food", 75.0,
		{"wood_plank": 6, "wire_pipe": 3}, ["garden_beds", "repair_well"], "Free eggs + passive income.")
	_define("root_cellar", "Root Cellar", 2, "food", 50.0,
		{"salvage_part": 3, "stone": 4}, ["garden_beds", "shed_repair"], "Food preservation. Produce lasts weeks.")

	_define("driveway_clearing", "Driveway Clearing", 3, "transport", 30.0,
		{"wood_plank": 4}, ["clear_yard", "shed_repair"], "Vehicle access. Town trips 3x faster.")
	_define("generator", "Generator", 3, "energy", 150.0,
		{"salvage_part": 3}, ["shed_repair", "driveway_clearing"], "Electricity. Work past sunset.")
	_define("workbench_upgrade", "Workbench Upgrade", 3, "workshop", 100.0,
		{"salvage_part": 4}, ["shed_repair"], "Fabricate and refurbish parts.")
	_define("irrigation", "Irrigation System", 3, "water", 80.0,
		{"wire_pipe": 4}, ["garden_beds"], "Automate garden watering.")

	_define("greenhouse", "Greenhouse", 4, "food", 200.0,
		{"wood_plank": 8, "wire_pipe": 4}, ["irrigation", "root_cellar"], "Year-round farming. Sell at market.")
	_define("smokehouse", "Smokehouse", 4, "food", 120.0,
		{"wood_plank": 6, "salvage_part": 2}, ["root_cellar", "generator"], "Smoke food for 2x sell value.")
	_define("solar_hot_water", "Solar Hot Water", 4, "shelter", 120.0,
		{"wire_pipe": 4, "salvage_part": 2}, ["patch_roof", "generator"], "Hot showers. +10% energy buff.")
	_define("porch_rebuild", "Porch Rebuild", 4, "social", 100.0,
		{"wood_plank": 8, "salvage_part": 2}, ["driveway_clearing", "patch_roof"], "NPCs visit your homestead.")


func _define(id: String, display_name: String, tier: int, category: String,
		money_cost: float, material_costs: Dictionary, prerequisites: Array,
		description: String) -> void:
	_upgrade_catalog[id] = {
		"id": id,
		"display_name": display_name,
		"tier": tier,
		"category": category,
		"money_cost": money_cost,
		"material_costs": material_costs,
		"prerequisites": prerequisites,
		"description": description,
	}


func get_upgrade(id: String) -> Dictionary:
	return _upgrade_catalog.get(id, {}) as Dictionary


func get_all_upgrades() -> Dictionary:
	return _upgrade_catalog


func can_build(upgrade_id: String) -> bool:
	if GameState.is_upgrade_complete(upgrade_id):
		return false
	var upgrade: Dictionary = get_upgrade(upgrade_id)
	if upgrade.is_empty():
		return false
	var prereqs: Array = upgrade["prerequisites"] as Array
	for prereq: String in prereqs:
		if not GameState.is_upgrade_complete(prereq):
			return false
	return true


func has_resources(upgrade_id: String) -> bool:
	var upgrade: Dictionary = get_upgrade(upgrade_id)
	if upgrade.is_empty():
		return false
	var cost: float = upgrade["money_cost"] as float
	if GameState.money < cost:
		return false
	var mat_costs: Dictionary = upgrade["material_costs"] as Dictionary
	for mat_id: String in mat_costs:
		var needed: int = mat_costs[mat_id] as int
		if GameState.get_material_count(mat_id) < needed:
			return false
	return true


func build_upgrade(upgrade_id: String) -> bool:
	if not can_build(upgrade_id):
		return false
	if not has_resources(upgrade_id):
		return false

	var upgrade: Dictionary = get_upgrade(upgrade_id)
	var cost: float = upgrade["money_cost"] as float
	if cost > 0.0:
		GameState.spend_money(cost)
	var mat_costs: Dictionary = upgrade["material_costs"] as Dictionary
	for mat_id: String in mat_costs:
		var needed: int = mat_costs[mat_id] as int
		GameState.spend_material(mat_id, needed)

	GameState.completed_upgrades[upgrade_id] = true
	_apply_upgrade_effects(upgrade_id)
	EventBus.upgrade_completed.emit(upgrade_id)
	return true


func _apply_upgrade_effects(upgrade_id: String) -> void:
	match upgrade_id:
		"repair_well":
			GameState.well_repaired = true
		"fix_stove":
			GameState.stove_fixed = true
		"patch_roof":
			GameState.roof_patched = true
		"clear_yard":
			GameState.yard_cleared = true
