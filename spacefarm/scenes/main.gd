class_name Main
extends Node

const STATION_SCENE: PackedScene = preload("res://scenes/station/station.tscn")


func _ready() -> void:
	_apply_theme()
	_try_load_save()
	var station: Node = STATION_SCENE.instantiate()
	add_child(station)


func _apply_theme() -> void:
	var theme: Theme = FarmTheme.create_theme()
	get_tree().root.theme = theme


func _try_load_save() -> void:
	var handler: SaveFileHandler = SaveFileHandler.new(GameState.SAVE_PATH, GameState.SAVE_VERSION)
	if handler.save_exists():
		var data: Dictionary = handler.load_dict()
		if not data.is_empty():
			GameState.from_dict(data)
