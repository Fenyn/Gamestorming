class_name TurnLost
extends BaseState

signal battle_lost


func enter(_msg: Dictionary = {}) -> void:
	battle_lost.emit()
