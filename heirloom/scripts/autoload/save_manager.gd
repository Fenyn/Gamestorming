extends Node

const SAVE_PATH := "user://heirloom_save.json"
const CURRENT_VERSION := 1


func _ready() -> void:
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func save_game() -> void:
	var data: Dictionary = GameState.to_dict()
	data["timestamp"] = int(Time.get_unix_time_from_system())
	data["current_hour"] = TimeManager.current_hour
	data["current_minute"] = TimeManager.current_minute

	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("SaveManager: Could not open save file for writing")
		return
	file.store_string(json_string)
	file.close()
	EventBus.save_completed.emit()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("SaveManager: Could not open save file for reading")
		return false

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result: int = json.parse(json_string)
	if parse_result != OK:
		push_warning("SaveManager: Failed to parse save file")
		return false

	var data: Dictionary = json.data as Dictionary
	if data.is_empty():
		return false

	data = _migrate(data)
	GameState.from_dict(data)

	TimeManager.current_hour = data.get("current_hour", 6) as int
	TimeManager.current_minute = data.get("current_minute", 0.0) as float

	EventBus.load_completed.emit()
	return true


func _migrate(data: Dictionary) -> Dictionary:
	var version: int = data.get("save_version", 1) as int
	while version < CURRENT_VERSION:
		match version:
			_:
				pass
		version += 1
		data["save_version"] = version
	return data


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
