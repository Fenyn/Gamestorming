extends Node

const SAVE_VERSION := 1

var money: float = 50.0
var day: int = 1
var month: int = 1
var total_days: int = 0

# Survival needs (0.0 = critical, 1.0 = full)
var hunger: float = 0.8
var thirst: float = 0.9
var fatigue: float = 1.0

# Camaro rebuild: part_id -> bool
var camaro_parts: Dictionary = {}

# NPC relationships: npc_id -> int (0-5)
var npc_friendships: Dictionary = {}

# Inventory: item_id -> int count
var inventory: Dictionary = {}

# Materials: material_id -> int count
var materials: Dictionary = {}

# Homestead upgrades: upgrade_id -> bool
var completed_upgrades: Dictionary = {}

# Homestead upgrade progress: upgrade_id -> { deposited: {}, stages_done: int }
var upgrade_progress: Dictionary = {}

# Flags
var has_bicycle: bool = true
var has_cabriolet: bool = false
var bills_missed: int = 0
var game_over: bool = false
var roof_patched: bool = false
var well_repaired: bool = false
var stove_fixed: bool = false
var yard_cleared: bool = false


func get_friendship(npc_id: String) -> int:
	return npc_friendships.get(npc_id, 0) as int


func set_friendship(npc_id: String, level: int) -> void:
	var clamped: int = clampi(level, 0, 5)
	npc_friendships[npc_id] = clamped
	EventBus.friendship_changed.emit(npc_id, clamped)


func add_money(amount: float) -> void:
	money += amount
	EventBus.money_changed.emit(money, amount)


func spend_money(amount: float) -> bool:
	if money < amount:
		return false
	money -= amount
	EventBus.money_changed.emit(money, -amount)
	return true


func add_material(material_id: String, count: int = 1) -> void:
	var current: int = materials.get(material_id, 0) as int
	materials[material_id] = current + count


func get_material_count(material_id: String) -> int:
	return materials.get(material_id, 0) as int


func spend_material(material_id: String, count: int = 1) -> bool:
	var current: int = materials.get(material_id, 0) as int
	if current < count:
		return false
	materials[material_id] = current - count
	return true


func is_part_installed(part_id: String) -> bool:
	return camaro_parts.get(part_id, false) as bool


func install_part(part_id: String) -> void:
	camaro_parts[part_id] = true
	EventBus.part_installed.emit(part_id)
	var installed: int = 0
	var total: int = camaro_parts.size()
	for key: String in camaro_parts:
		if camaro_parts[key] as bool:
			installed += 1
	EventBus.camaro_progress_changed.emit(installed, total)
	if installed >= total:
		EventBus.camaro_complete.emit()


func is_upgrade_complete(upgrade_id: String) -> bool:
	return completed_upgrades.get(upgrade_id, false) as bool


func get_sleep_restore() -> float:
	if not roof_patched:
		return 0.6
	return 1.0


func get_food_cost_multiplier() -> float:
	if stove_fixed:
		return 0.5
	return 1.0


func to_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"money": money,
		"day": day,
		"month": month,
		"total_days": total_days,
		"hunger": hunger,
		"thirst": thirst,
		"fatigue": fatigue,
		"camaro_parts": camaro_parts.duplicate(),
		"npc_friendships": npc_friendships.duplicate(),
		"inventory": inventory.duplicate(),
		"materials": materials.duplicate(),
		"completed_upgrades": completed_upgrades.duplicate(),
		"upgrade_progress": upgrade_progress.duplicate(true),
		"has_bicycle": has_bicycle,
		"has_cabriolet": has_cabriolet,
		"bills_missed": bills_missed,
		"game_over": game_over,
		"roof_patched": roof_patched,
		"well_repaired": well_repaired,
		"stove_fixed": stove_fixed,
		"yard_cleared": yard_cleared,
	}


func from_dict(data: Dictionary) -> void:
	money = data.get("money", 50.0) as float
	day = data.get("day", 1) as int
	month = data.get("month", 1) as int
	total_days = data.get("total_days", 0) as int
	hunger = data.get("hunger", 0.8) as float
	thirst = data.get("thirst", 0.9) as float
	fatigue = data.get("fatigue", 1.0) as float
	camaro_parts = (data.get("camaro_parts", {}) as Dictionary).duplicate()
	npc_friendships = (data.get("npc_friendships", {}) as Dictionary).duplicate()
	inventory = (data.get("inventory", {}) as Dictionary).duplicate()
	materials = (data.get("materials", {}) as Dictionary).duplicate()
	completed_upgrades = (data.get("completed_upgrades", {}) as Dictionary).duplicate()
	upgrade_progress = (data.get("upgrade_progress", {}) as Dictionary).duplicate(true)
	has_bicycle = data.get("has_bicycle", true) as bool
	has_cabriolet = data.get("has_cabriolet", false) as bool
	bills_missed = data.get("bills_missed", 0) as int
	game_over = data.get("game_over", false) as bool
	roof_patched = data.get("roof_patched", false) as bool
	well_repaired = data.get("well_repaired", false) as bool
	stove_fixed = data.get("stove_fixed", false) as bool
	yard_cleared = data.get("yard_cleared", false) as bool
