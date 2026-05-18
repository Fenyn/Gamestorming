extends Node

const STARTING_HP: int = 50
const STARTING_REROLLS: int = 2
const BASE_DRAW: int = 3
const DRIFTER_DRAW_BONUS: int = 1
const STARTING_BAG_SIZE: int = 8
const MAX_IMPLANTS: int = 3
const MAX_STIMS: int = 3

const DEFAULT_MODULES: Array[String] = [
	"res://resources/modules/plasma_jab.tres",
	"res://resources/modules/barrier.tres",
	"res://resources/modules/arc_sweep.tres",
]

var drifter_hp: int = STARTING_HP
var drifter_max_hp: int = STARTING_HP
var scrap: int = 0
var rerolls_per_turn: int = STARTING_REROLLS

var loadout_grid: LoadoutGrid = LoadoutGrid.new()
var module_inventory: Array[ModuleData] = []
var modules: Array[ModuleData]:
	get:
		return loadout_grid.get_all_modules()
var dice_bag: DiceBag = DiceBag.new()
var implants: Array[ImplantData] = []
var stims: Array[Dictionary] = []

var map_nodes: Array[Array] = []
var visited_nodes: Array[Vector2i] = []
var current_row: int = 0
var current_creature: CreatureData
var pending_cell_unlock: bool = false
var active_shop: Array[Dictionary] = []
var _initialized: bool = false


func _ready() -> void:
	ensure_initialized()


func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_init_dice_bag()
	_init_starting_modules()


func reset_for_new_expedition() -> void:
	drifter_hp = STARTING_HP
	drifter_max_hp = STARTING_HP
	scrap = 0
	rerolls_per_turn = STARTING_REROLLS
	loadout_grid = LoadoutGrid.new()
	module_inventory.clear()
	implants.clear()
	stims.clear()
	map_nodes.clear()
	visited_nodes.clear()
	current_row = 0
	current_creature = null
	pending_cell_unlock = false
	active_shop.clear()
	_init_dice_bag()
	_init_starting_modules()


func _init_dice_bag() -> void:
	var standard: CellData = load("res://resources/cells/standard_d6.tres") as CellData
	var starting: Array[CellData] = []
	for i: int in STARTING_BAG_SIZE:
		starting.append(standard)
	dice_bag.setup(starting, BASE_DRAW, DRIFTER_DRAW_BONUS)


func _init_starting_modules() -> void:
	loadout_grid.clear()
	for path: String in DEFAULT_MODULES:
		var module: ModuleData = load(path) as ModuleData
		if module:
			var result: Dictionary = loadout_grid.find_any_valid_placement(module)
			if not result.is_empty():
				var pos: Vector2i = result["position"] as Vector2i
				loadout_grid.place(module, pos.x, pos.y, result["rotation"] as int)


func collect_module(module: ModuleData) -> void:
	module_inventory.append(module)


func place_module_from_inventory(index: int, col: int, row: int, rotation: int = 0) -> bool:
	if index < 0 or index >= module_inventory.size():
		return false
	var module: ModuleData = module_inventory[index]
	if not loadout_grid.place(module, col, row, rotation):
		return false
	module_inventory.remove_at(index)
	return true


func unplace_module(col: int, row: int) -> void:
	var module: ModuleData = loadout_grid.remove_at(col, row)
	if module:
		module_inventory.append(module)


func add_implant(implant: ImplantData) -> bool:
	if implants.size() >= MAX_IMPLANTS:
		return false
	implants.append(implant)
	return true


func heal(amount: int) -> void:
	drifter_hp = mini(drifter_hp + amount, drifter_max_hp)
	EventBus.drifter_hp_changed.emit(drifter_hp, drifter_max_hp)


func take_damage(amount: int) -> void:
	drifter_hp = maxi(drifter_hp - amount, 0)
	EventBus.drifter_hp_changed.emit(drifter_hp, drifter_max_hp)
