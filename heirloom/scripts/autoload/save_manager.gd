extends Node

const SAVE_PATH: String = "user://heirloom_save.json"
const CURRENT_VERSION: int = 1

var _handler: SaveFileHandler


func _ready() -> void:
	_handler = SaveFileHandler.new(SAVE_PATH, CURRENT_VERSION)
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func save_game() -> void:
	var data: Dictionary = GameState.to_dict()
	data["current_hour"] = TimeManager.current_hour
	data["current_minute"] = TimeManager.current_minute
	if _handler.save_dict(data):
		EventBus.save_completed.emit()


func load_game() -> bool:
	var data: Dictionary = _handler.load_dict()
	if data.is_empty():
		return false

	data = _handler.migrate(data, {})
	GameState.from_dict(data)

	TimeManager.current_hour = data.get("current_hour", 6) as int
	TimeManager.current_minute = data.get("current_minute", 0.0) as float

	EventBus.load_completed.emit()
	return true


func delete_save() -> void:
	_handler.delete_save()
