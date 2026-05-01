class_name GamePopup
extends PanelContainer

var _title_label: Label
var _close_btn: Button
var _content_container: VBoxContainer
var _scroll: ScrollContainer

signal closed


static func create(title: String) -> GamePopup:
	var popup := GamePopup.new()

	popup.anchor_left = 0.02
	popup.anchor_top = 0.02
	popup.anchor_right = 0.98
	popup.anchor_bottom = 0.98
	popup.offset_left = 0
	popup.offset_top = 0
	popup.offset_right = 0
	popup.offset_bottom = 0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.06, 0.97)
	style.border_color = ThemeBuilder.ACCENT_GREEN
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	popup.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	popup.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	popup._title_label = Label.new()
	popup._title_label.text = title
	popup._title_label.add_theme_font_size_override("font_size", 16)
	popup._title_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GOLD)
	popup._title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(popup._title_label)

	popup._close_btn = Button.new()
	popup._close_btn.text = "X"
	popup._close_btn.custom_minimum_size = Vector2(32, 32)
	popup._close_btn.pressed.connect(popup._on_close)
	header.add_child(popup._close_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	popup._scroll = ScrollContainer.new()
	popup._scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup._scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(popup._scroll)

	popup._content_container = VBoxContainer.new()
	popup._content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup._content_container.add_theme_constant_override("separation", 6)
	popup._scroll.add_child(popup._content_container)

	return popup


func get_content() -> VBoxContainer:
	return _content_container


func _on_close() -> void:
	closed.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
