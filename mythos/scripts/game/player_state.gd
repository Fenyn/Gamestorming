class_name PlayerState
extends RefCounted

var player_index: int = 0
var peer_id: int = 0
var deck: Array[CardData] = []
var hand: Array[CardData] = []
var graveyard: Array[CardData] = []
var resources: int = 0
var city_grid: Array = []  # 5x5, null or BuildingInstance
var lane_units: Array = []  # 5 slots, null or UnitInstance

func _init(index: int) -> void:
	player_index = index
	city_grid.resize(25)
	lane_units.resize(5)

func get_grid_cell(pos: Vector2i) -> Variant:
	return city_grid[pos.y * 5 + pos.x]

func set_grid_cell(pos: Vector2i, value: Variant) -> void:
	city_grid[pos.y * 5 + pos.x] = value

func get_lane_unit(lane: int) -> Variant:
	return lane_units[lane]

func set_lane_unit(lane: int, value: Variant) -> void:
	lane_units[lane] = value
