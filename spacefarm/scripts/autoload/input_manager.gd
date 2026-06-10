extends Node

var move_input: Vector2 = Vector2.ZERO

var _context: InputContext = InputContext.new()


func _ready() -> void:
	_context.register_mode(InputContext.Mode.GAMEPLAY, PackedStringArray([
		"move_up", "move_down", "move_left", "move_right",
		"interact", "tool_1", "tool_2", "tool_3", "tool_4", "tool_5",
		"open_inventory", "open_map", "pause",
	]))
	_context.register_mode(InputContext.Mode.MENU, PackedStringArray([
		"ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right",
		"pause",
	]))
	_context.register_mode(InputContext.Mode.CUTSCENE, PackedStringArray([
		"ui_accept", "ui_cancel",
		"pause",
	]))


func _process(_delta: float) -> void:
	if _context.current_mode == InputContext.Mode.DISABLED:
		move_input = Vector2.ZERO
		return

	move_input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"),
	)
	if move_input.length() > 1.0:
		move_input = move_input.normalized()


func get_context() -> InputContext:
	return _context


func set_mode(mode: InputContext.Mode) -> void:
	_context.set_mode(mode)


func is_action_active(action: StringName) -> bool:
	return _context.is_action_active(action)
