class_name SaveFileHandler
extends RefCounted

signal save_completed()
signal load_completed()

var save_path: String
var current_version: int


func _init(p_save_path: String, p_current_version: int = 1) -> void:
	save_path = p_save_path
	current_version = p_current_version


func save_dict(data: Dictionary) -> bool:
	data["save_version"] = current_version
	data["timestamp"] = int(Time.get_unix_time_from_system())
	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_warning("SaveFileHandler: Could not open '%s' for writing" % save_path)
		return false
	file.store_string(json_string)
	file.close()
	save_completed.emit()
	return true


func load_dict() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_warning("SaveFileHandler: Could not open '%s' for reading" % save_path)
		return {}
	var json_string: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(json_string)
	if parse_result != OK:
		push_warning("SaveFileHandler: Failed to parse '%s'" % save_path)
		return {}
	var data: Dictionary = json.data as Dictionary
	if data.is_empty():
		return {}
	load_completed.emit()
	return data


func migrate(data: Dictionary, migrations: Dictionary) -> Dictionary:
	var version: int = data.get("save_version", 1) as int
	while version < current_version:
		if migrations.has(version):
			var migration: Callable = migrations[version] as Callable
			data = migration.call(data)
		version += 1
		data["save_version"] = version
	return data


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


func save_exists() -> bool:
	return FileAccess.file_exists(save_path)
