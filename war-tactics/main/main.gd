class_name Main
extends Node2D

const BATTLE_SCENE: PackedScene = preload("res://battle/battle.tscn")


func _ready() -> void:
	var battle: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child(battle)
