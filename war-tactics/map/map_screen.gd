class_name MapScreen
extends Control

@onready var _title: Label = %MapTitle
@onready var _node_container: HBoxContainer = %NodeContainer
@onready var _complete_label: Label = %CompleteLabel


func _ready() -> void:
	_complete_label.visible = false
	_build_nodes()


func _build_nodes() -> void:
	for child: Node in _node_container.get_children():
		child.queue_free()

	if RunState.current_map_node >= Constants.MAP_NODE_COUNT:
		_title.text = "Campaign Complete!"
		_complete_label.visible = true
		var btn: Button = Button.new()
		btn.text = "Return to Title"
		btn.pressed.connect(func() -> void:
			RunState.reset()
			Events.screen_transition_requested.emit("title")
		)
		_node_container.add_child(btn)
		return

	_title.text = "Campaign Map"
	for i: int in Constants.MAP_NODE_COUNT:
		if i > 0:
			var arrow: Label = Label.new()
			arrow.text = " → "
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_node_container.add_child(arrow)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var btn: Button = Button.new()
		btn.text = "Battle %d" % (i + 1)
		btn.custom_minimum_size = Vector2(140, 40)

		var desc: Label = Label.new()
		desc.text = Constants.LEVEL_DESCRIPTIONS[i] if i < Constants.LEVEL_DESCRIPTIONS.size() else ""
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.add_theme_font_size_override("font_size", 10)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if i < RunState.current_map_node:
			btn.text = "✓ Battle %d" % (i + 1)
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)
		elif i == RunState.current_map_node:
			btn.pressed.connect(_on_node_clicked.bind(i))
		else:
			btn.disabled = true
			btn.modulate = Color(0.4, 0.4, 0.4)

		vbox.add_child(btn)
		vbox.add_child(desc)
		_node_container.add_child(vbox)


func _on_node_clicked(_index: int) -> void:
	Events.screen_transition_requested.emit("battle")
