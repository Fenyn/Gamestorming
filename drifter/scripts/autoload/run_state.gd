extends Node

const STARTING_HP: int = 50
const STARTING_REROLLS: int = 2
const MAX_MODULES: int = 6
const MAX_IMPLANTS: int = 3
const MAX_STIMS: int = 3

var drifter_hp: int = STARTING_HP
var drifter_max_hp: int = STARTING_HP
var scrap: int = 0
var rerolls_per_turn: int = STARTING_REROLLS

var modules: Array[ModuleData] = []
var implants: Array[ImplantData] = []
var stims: Array[Dictionary] = []

# Expedition map state
var map_nodes: Array[Array] = []
var map_connections: Dictionary = {}
var visited_nodes: Array[Vector2i] = []
var current_row: int = 0

# Current encounter
var current_creature: CreatureData


func reset_for_new_expedition() -> void:
	drifter_hp = STARTING_HP
	drifter_max_hp = STARTING_HP
	scrap = 0
	rerolls_per_turn = STARTING_REROLLS
	modules.clear()
	implants.clear()
	stims.clear()
	map_nodes.clear()
	map_connections.clear()
	visited_nodes.clear()
	current_row = 0
	current_creature = null


func set_starting_modules(starting: Array[ModuleData]) -> void:
	modules = starting.duplicate()


func add_module(module: ModuleData) -> bool:
	if modules.size() >= MAX_MODULES:
		return false
	modules.append(module)
	return true


func remove_module(index: int) -> void:
	if index >= 0 and index < modules.size():
		modules.remove_at(index)


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
