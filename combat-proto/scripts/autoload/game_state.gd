extends Node

enum MatchMode { TRAINING, PVP }

var match_mode: MatchMode = MatchMode.TRAINING
var round_count: int = 0
var player_wins: int = 0
var enemy_wins: int = 0
var is_round_active: bool = false


func _ready() -> void:
	EventBus.fighter_died.connect(_on_fighter_died)
	EventBus.round_reset.connect(_on_round_reset)


func start_match(mode: MatchMode) -> void:
	match_mode = mode
	round_count = 0
	player_wins = 0
	enemy_wins = 0
	is_round_active = true
	EventBus.match_started.emit(mode)


func _on_fighter_died(fighter: Node) -> void:
	if not is_round_active:
		return
	is_round_active = false
	round_count += 1
	var winner: Node = _get_opponent(fighter)
	EventBus.match_ended.emit(winner)


func _on_round_reset() -> void:
	is_round_active = true


func _get_opponent(_dead_fighter: Node) -> Node:
	return null
