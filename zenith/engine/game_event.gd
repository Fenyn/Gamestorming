class_name GameEvent
extends RefCounted
## Something that happened in the engine. Clients replay these into animations and log lines.

var type: StringName = &""
var data: Dictionary = {}


func _init(p_type: StringName = &"", p_data: Dictionary = {}) -> void:
	type = p_type
	data = p_data


func _to_string() -> String:
	return "%s %s" % [type, JSON.stringify(data)]
