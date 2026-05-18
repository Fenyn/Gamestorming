extends Node

var squad_ids: Array[String] = []
var current_xp: int = 0


func reset() -> void:
	squad_ids = ["rifleman", "sniper", "grenadier"]
	current_xp = 0
