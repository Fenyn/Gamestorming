class_name TurnPlayer
extends BaseState

signal player_turn_started


func enter(_msg: Dictionary = {}) -> void:
	player_turn_started.emit()
