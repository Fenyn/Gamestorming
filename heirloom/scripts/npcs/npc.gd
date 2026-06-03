extends CharacterBody3D

@export var npc_id: String = ""
@export var display_name: String = ""
@export var dialogue_by_level: Array[PackedStringArray] = []

var _in_dialogue := false
var _dialogue_index: int = 0
var _current_lines: PackedStringArray = PackedStringArray()


func interact(player: Node3D) -> void:
	if _in_dialogue:
		_advance_dialogue()
		return

	_start_dialogue()


func _start_dialogue() -> void:
	var level: int = GameState.get_friendship(npc_id)
	level = mini(level, dialogue_by_level.size() - 1)
	if level < 0 or dialogue_by_level.is_empty():
		return

	_current_lines = dialogue_by_level[level]
	if _current_lines.is_empty():
		return

	_in_dialogue = true
	_dialogue_index = 0
	EventBus.dialogue_started.emit(npc_id)
	_show_line()


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= _current_lines.size():
		_end_dialogue()
		return
	_show_line()


func _show_line() -> void:
	var line: String = _current_lines[_dialogue_index]
	var dialogue_ui: Node = get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui and dialogue_ui.has_method("show_dialogue"):
		dialogue_ui.show_dialogue(display_name, line)


func _end_dialogue() -> void:
	_in_dialogue = false
	_dialogue_index = 0

	var friendship: int = GameState.get_friendship(npc_id)
	if friendship < 5:
		GameState.set_friendship(npc_id, friendship + 1)

	var dialogue_ui: Node = get_tree().get_first_node_in_group("dialogue_ui")
	if dialogue_ui and dialogue_ui.has_method("hide_dialogue"):
		dialogue_ui.hide_dialogue()

	EventBus.dialogue_ended.emit(npc_id)
