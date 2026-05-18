class_name TurnWon
extends State

signal battle_won


func enter(_msg: Dictionary = {}) -> void:
	battle_won.emit()
