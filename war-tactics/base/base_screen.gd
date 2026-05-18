class_name BaseScreen
extends Control

@onready var _squad_list: VBoxContainer = %SquadList
@onready var _xp_label: Label = %XPLabel
@onready var _heal_button: Button = %HealButton
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	_heal_button.pressed.connect(_on_heal_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_refresh_display()


func _refresh_display() -> void:
	for child: Node in _squad_list.get_children():
		child.queue_free()

	for i: int in RunState.squad.size():
		var entry: UnitRunData = RunState.squad[i]
		var data: UnitData = Database.get_unit_data(entry.unit_id)
		var label_text: String = ""
		if data:
			label_text = "%s  HP: %d / %d" % [data.unit_label, entry.current_hp, entry.max_hp]
		else:
			label_text = "%s  HP: %d / %d" % [entry.unit_id, entry.current_hp, entry.max_hp]
		if not entry.is_alive():
			label_text += "  [KIA]"
		if not entry.medals.is_empty():
			var medal_strs: Array[String] = []
			for medal: MedalData in entry.medals:
				medal_strs.append(medal.label)
			label_text += "  Medals: " + ", ".join(medal_strs)

		var row: Label = Label.new()
		row.text = label_text
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not entry.is_alive():
			row.modulate = Color(0.5, 0.5, 0.5)
		_squad_list.add_child(row)

	_xp_label.text = "XP: %d" % RunState.current_xp

	var all_full: bool = true
	for entry: UnitRunData in RunState.squad:
		if entry.is_alive() and entry.current_hp < entry.max_hp:
			all_full = false
			break
	_heal_button.text = "Heal All (%d XP)" % Constants.HEAL_ALL_XP_COST
	_heal_button.disabled = RunState.current_xp < Constants.HEAL_ALL_XP_COST or all_full


func _on_heal_pressed() -> void:
	if RunState.spend_xp(Constants.HEAL_ALL_XP_COST):
		RunState.heal_all()
		_refresh_display()


func _on_continue_pressed() -> void:
	RunState.advance_map_node()
	Events.screen_transition_requested.emit("map")
