## Timberline game state: money and (later) upgrades, unlocks, save/load.
## Autoload — no class_name; the autoload name "GameManager" is the global ID.

extends Node

## The cabin's upgrade catalog. One entry per purchasable upgrade;
## effects live with the systems they touch (UpgradeUnlocks spawns
## stations, Axe reads its own damage upgrade).
const CATALOG: Array[Dictionary] = [
	{
		"id": "splitting_block",
		"title": "Splitting block",
		"desc": "A chopping block for the yard. Split logs into firewood worth double per kilo.",
		"cost": 60,
	},
	{
		"id": "sharp_axe",
		"title": "Sharpened axe",
		"desc": "Twice the chop damage. Fell, buck, and split in half the swings.",
		"cost": 200,
	},
	{
		"id": "plot_west",
		"title": "West forest plot",
		"desc": "Logging rights to the woods west of the cabin.",
		"cost": 120,
	},
	{
		"id": "plot_east",
		"title": "East forest plot",
		"desc": "Logging rights to the woods east of the cabin.",
		"cost": 180,
	},
	{
		"id": "plot_north",
		"title": "North forest plot",
		"desc": "Logging rights to the deep woods behind the cabin.",
		"cost": 300,
	},
]

const SAVE_PATH: String = "user://save.json"

var money: int = 0
var upgrades: Array[String] = []


func _ready() -> void:
	load_game()
	EventBus.item_sold.connect(_on_item_sold)


## Money and upgrades persist; world state (downed wood, regrowth
## timers) does not yet. Called after every money or upgrade change.
func save_game() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameManager: could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"money": money,
		"upgrades": upgrades,
	}))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is not Dictionary:
		push_warning("GameManager: unreadable save, starting fresh")
		return
	var dict: Dictionary = data
	money = int(dict.get("money", 0))
	upgrades.clear()
	for upgrade_id in dict.get("upgrades", []):
		upgrades.append(String(upgrade_id))


func has_upgrade(upgrade_id: String) -> bool:
	return upgrades.has(upgrade_id)


func upgrade_def(upgrade_id: String) -> Dictionary:
	for def in CATALOG:
		if String(def["id"]) == upgrade_id:
			return def
	return {}


## Buys an upgrade if it exists, isn't owned, and the money is there.
func purchase_upgrade(upgrade_id: String) -> bool:
	var def: Dictionary = upgrade_def(upgrade_id)
	if def.is_empty() or has_upgrade(upgrade_id):
		return false
	if not spend_money(int(def["cost"])):
		return false
	upgrades.append(upgrade_id)
	save_game()
	EventBus.upgrade_purchased.emit(upgrade_id)
	return true


func add_money(amount: int) -> void:
	money += amount
	EventBus.money_changed.emit(money)
	save_game()


func spend_money(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	EventBus.money_changed.emit(money)
	save_game()
	return true


func _on_item_sold(_product_id: String, value: int) -> void:
	add_money(value)
