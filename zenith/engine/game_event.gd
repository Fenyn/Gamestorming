class_name GameEvent
extends RefCounted
## Something that happened in the engine. Clients replay these into animations and log lines.

var type: StringName = &""
var data: Dictionary = {}
## The handful of numbers a client draws on the table, as they stood when this event fired:
## `energy` per personality uid, `fervor` per player, `zones` as [life deck, hand, discard,
## removed] per player. Filled only on the engine a Referee owns, so a client can replay the
## events one at a time and show the table as it was at each beat instead of the end state.
var state: Dictionary = {}


func _init(p_type: StringName = &"", p_data: Dictionary = {}) -> void:
	type = p_type
	data = p_data


func _to_string() -> String:
	return "%s %s" % [type, JSON.stringify(data)]
