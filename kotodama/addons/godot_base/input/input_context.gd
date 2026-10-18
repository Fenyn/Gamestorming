class_name InputContext
extends RefCounted

enum Mode {
	GAMEPLAY,
	MENU,
	CUTSCENE,
	DISABLED,
}

var _action_map: Dictionary = {}
var current_mode: Mode = Mode.GAMEPLAY


func register_mode(mode: Mode, actions: PackedStringArray) -> void:
	_action_map[mode] = actions


func set_mode(mode: Mode) -> void:
	current_mode = mode


func is_action_active(action: StringName) -> bool:
	if current_mode == Mode.DISABLED:
		return false
	if not _action_map.has(current_mode):
		return true
	var actions: PackedStringArray = _action_map[current_mode] as PackedStringArray
	return action in actions


func get_active_actions() -> PackedStringArray:
	if current_mode == Mode.DISABLED:
		return PackedStringArray()
	if not _action_map.has(current_mode):
		return PackedStringArray()
	return _action_map[current_mode] as PackedStringArray
