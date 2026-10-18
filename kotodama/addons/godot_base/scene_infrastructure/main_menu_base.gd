class_name MainMenuBase
extends Control

@export var title_text: String = "Game Title"
@export var version_text: String = "v0.1.0"
@export var button_width: float = 200.0
@export var button_height: float = 40.0

var _title_label: Label = null
var _button_container: VBoxContainer = null
var _version_label: Label = null


func _ready() -> void:
	_build_layout()
	_add_default_buttons()
	_on_menu_ready()


func _build_layout() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = title_text
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(_title_label)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	_button_container = VBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_button_container)

	_version_label = Label.new()
	_version_label.text = version_text
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version_label.add_theme_font_size_override("font_size", 14)
	_version_label.modulate = Color(1, 1, 1, 0.5)
	var version_anchor: Control = Control.new()
	version_anchor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	version_anchor.custom_minimum_size = Vector2(0, 40)
	add_child(version_anchor)
	version_anchor.add_child(_version_label)
	_version_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)


func _add_default_buttons() -> void:
	add_menu_button("Play", _on_play_pressed)
	add_menu_button("Settings", _on_settings_pressed)
	add_menu_button("Quit", _on_quit_pressed)


func add_menu_button(label: String, callback: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(button_width, button_height)
	btn.pressed.connect(callback)
	_button_container.add_child(btn)
	return btn


func get_button_container() -> VBoxContainer:
	return _button_container


func get_title_label() -> Label:
	return _title_label


func _on_menu_ready() -> void:
	pass


func _on_play_pressed() -> void:
	pass


func _on_settings_pressed() -> void:
	pass


func _on_quit_pressed() -> void:
	get_tree().quit()
