extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.1)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "GREEN BEAN"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Barista Simulator"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	vbox.add_child(spacer)

	var new_btn := _make_button("New Game")
	new_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_btn)

	var cont_btn := _make_button("Continue")
	cont_btn.pressed.connect(_on_continue)
	if not UnlockManager.has_save_file():
		cont_btn.disabled = true
		cont_btn.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(cont_btn)

func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 60)
	btn.add_theme_font_size_override("font_size", 24)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.2, 0.15)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.3, 0.2)
	hover.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", hover)
	return btn

func _on_new_game() -> void:
	UnlockManager.init_new_game()
	UnlockManager.save_to_file()
	get_tree().change_scene_to_file("res://scenes/shops/espresso_stand.tscn")

func _on_continue() -> void:
	if UnlockManager.load_from_file():
		get_tree().change_scene_to_file("res://scenes/shops/espresso_stand.tscn")
