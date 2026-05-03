class_name TurnTransition
extends Control

signal continue_pressed()

var _label: Label
var _click_label: Label
var _waiting: bool = false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("turn_transition")
	_build_ui()

func show_transition(next_player: int) -> void:
	_label.text = "Player " + str(next_player + 1) + "'s Turn"
	visible = true
	_waiting = true

func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.08, 0.08, 0.12, 0.95)
	add_child(bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -200
	vbox.offset_right = 200
	vbox.offset_top = -60
	vbox.offset_bottom = 60
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(_label)

	_click_label = Label.new()
	_click_label.text = "Click to continue"
	_click_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click_label.add_theme_font_size_override("font_size", 16)
	_click_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(_click_label)

func _gui_input(event: InputEvent) -> void:
	if _waiting and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_waiting = false
			visible = false
			continue_pressed.emit()
