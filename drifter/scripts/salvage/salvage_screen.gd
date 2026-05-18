class_name SalvageScreen
extends Control

@onready var _title_label: Label = %TitleLabel
@onready var _choices_row: HBoxContainer = %ChoicesRow
@onready var _scrap_label: Label = %ScrapLabel

var _choices: Array[Dictionary] = []
var _node_type: MapNodeData.NodeType


func _ready() -> void:
	theme = ThemeBuilder.build()
	_node_type = _get_node_type()
	_choices = RewardPool.generate_choices(_node_type)

	var base_scrap: int = _get_base_scrap()
	if base_scrap > 0:
		RunState.scrap += base_scrap

	_scrap_label.text = "Scrap: " + str(RunState.scrap)
	_title_label.text = _get_title()
	_build_choice_buttons()


func _get_node_type() -> MapNodeData.NodeType:
	if RunState.map_nodes.is_empty():
		return MapNodeData.NodeType.ENCOUNTER
	var row: int = RunState.current_row
	if row < 0 or row >= RunState.map_nodes.size():
		return MapNodeData.NodeType.ENCOUNTER
	for coord: Vector2i in RunState.visited_nodes:
		if coord.x == row:
			var node_data: MapNodeData = RunState.map_nodes[row][coord.y] as MapNodeData
			return node_data.type
	return MapNodeData.NodeType.ENCOUNTER


func _get_base_scrap() -> int:
	match _node_type:
		MapNodeData.NodeType.ENCOUNTER:
			return RewardPool.SCRAP_ENCOUNTER / 2
		MapNodeData.NodeType.ELITE:
			return RewardPool.SCRAP_ELITE / 2
		MapNodeData.NodeType.APEX:
			return RewardPool.SCRAP_APEX / 2
	return 0


func _get_title() -> String:
	match _node_type:
		MapNodeData.NodeType.ELITE:
			return "ELITE SALVAGE"
		MapNodeData.NodeType.APEX:
			return "APEX SALVAGE"
	return "SALVAGE"


func _build_choice_buttons() -> void:
	for i: int in _choices.size():
		var choice: Dictionary = _choices[i]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(200, 160)
		panel.add_theme_stylebox_override("panel", ThemeBuilder.create_flat_style(
			ThemeBuilder.BG_MODULE, ThemeBuilder.BORDER, 1, 4, 12
		))

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 8)
		panel.add_child(vbox)

		var type_label := Label.new()
		var reward_type: int = choice["type"] as int
		match reward_type:
			RewardPool.RewardType.MODULE:
				type_label.text = "MODULE"
				type_label.add_theme_color_override("font_color", ThemeBuilder.ACCENT_GLOW)
			RewardPool.RewardType.IMPLANT:
				type_label.text = "IMPLANT"
				type_label.add_theme_color_override("font_color", Color(0.90, 0.70, 0.20))
			RewardPool.RewardType.SCRAP:
				type_label.text = "SCRAP"
				type_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.30))
			RewardPool.RewardType.CELL:
				type_label.text = "CELL"
				type_label.add_theme_color_override("font_color", Color(0.50, 0.90, 0.90))
		type_label.add_theme_font_size_override("font_size", 11)
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(type_label)

		var name_label := Label.new()
		name_label.text = choice["label"] as String
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = choice["description"] as String
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(desc_label)

		var btn := Button.new()
		btn.text = "Take"
		btn.custom_minimum_size = Vector2(80, 32)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_on_choice_selected.bind(i))
		vbox.add_child(btn)

		_choices_row.add_child(panel)


func _on_choice_selected(index: int) -> void:
	var choice: Dictionary = _choices[index]
	var reward_type: int = choice["type"] as int

	match reward_type:
		RewardPool.RewardType.MODULE:
			var module: ModuleData = choice["data"] as ModuleData
			if module:
				RunState.collect_module(module)
		RewardPool.RewardType.IMPLANT:
			var implant: ImplantData = choice["data"] as ImplantData
			if implant:
				RunState.add_implant(implant)
		RewardPool.RewardType.SCRAP:
			var value: int = choice["value"] as int
			RunState.scrap += value
		RewardPool.RewardType.CELL:
			var cell: CellData = choice["data"] as CellData
			if cell:
				RunState.dice_bag.add_die(cell)

	EventBus.salvage_chosen.emit(
		str(reward_type),
		choice["label"] as String,
	)

	_scrap_label.text = "Scrap: " + str(RunState.scrap)
	var chosen_panel: PanelContainer = _choices_row.get_child(index) as PanelContainer
	if chosen_panel:
		var flash: Tween = create_tween()
		chosen_panel.modulate = Color(1.5, 2.0, 1.5)
		flash.tween_property(chosen_panel, "modulate", Color.WHITE, 0.3)
		flash.tween_callback(EventBus.screen_transition_requested.emit.bind("map")).set_delay(0.4)
	else:
		EventBus.screen_transition_requested.emit("map")
