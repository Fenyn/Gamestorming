class_name TurnPlayer
extends State

signal player_turn_started


func enter(_msg: Dictionary = {}) -> void:
	player_turn_started.emit()
