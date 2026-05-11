extends CanvasLayer

@onready var _label: RichTextLabel = $Panel/RichTextLabel

const HOTKEYS: Dictionary = {
	InputContext.Mode.PLAYER: [
		["WASD", "Move"],
		["Mouse", "Look"],
		["Space", "Jump"],
		["E", "Interact"],
		["B", "Mag Boots"],
		["Tab", "Wrist Display"],
		["Esc", "Release Mouse"],
		["F3", "Debug"],
	],
	InputContext.Mode.HELM: [
		["Mouse", "Yaw / Pitch"],
		["W / S", "Throttle"],
		["A / D", "Strafe"],
		["Q / E", "Roll"],
		["Space", "Thrust Up"],
		["Ctrl", "Thrust Down"],
		["Shift", "Afterburner"],
		["F", "Flight Assist"],
		["Esc", "Exit Helm"],
	],
	InputContext.Mode.TURRET: [
		["Mouse", "Aim"],
		["LMB", "Fire"],
		["Esc", "Exit Turret"],
	],
	InputContext.Mode.TERMINAL: [
		["W / S", "Adjust Up / Down"],
		["A / D", "Select System"],
		["Esc", "Exit Terminal"],
	],
	InputContext.Mode.DISABLED: [
		["", "Controls Disabled"],
	],
}

var _current_context: InputContext.Mode = InputContext.Mode.PLAYER


func _ready() -> void:
	_update_display(InputContext.Mode.PLAYER)


func _process(_delta: float) -> void:
	var player: Node = _find_local_player()
	if not player:
		return
	var context: int = player.get(&"_input_context") as int
	var mode: InputContext.Mode = context as InputContext.Mode
	if mode != _current_context:
		_current_context = mode
		_update_display(mode)


func _update_display(mode: InputContext.Mode) -> void:
	var entries: Array = HOTKEYS.get(mode, []) as Array
	var text: String = ""

	var title: String = _get_title(mode)
	text += "[b]" + title + "[/b]\n"

	for entry: Array in entries:
		var key: String = entry[0] as String
		var action: String = entry[1] as String
		if key.length() > 0:
			text += "[color=yellow]" + key + "[/color]  " + action + "\n"
		else:
			text += action + "\n"

	_label.text = text


func _get_title(mode: InputContext.Mode) -> String:
	match mode:
		InputContext.Mode.PLAYER:
			return "WALKING"
		InputContext.Mode.HELM:
			return "HELM"
		InputContext.Mode.TURRET:
			return "TURRET"
		InputContext.Mode.TERMINAL:
			return "TERMINAL"
		_:
			return ""


func _find_local_player() -> Node:
	var players_node: Node = get_tree().get_first_node_in_group(&"players_container")
	if not players_node:
		return null
	for child: Node in players_node.get_children():
		if child is Player and child.is_multiplayer_authority():
			return child
	return null
