class_name TurnLost
extends State

signal battle_lost


func enter(_msg: Dictionary = {}) -> void:
	battle_lost.emit()
