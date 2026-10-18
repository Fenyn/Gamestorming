extends MainMenuBase

## Title screen on godot_base's MainMenuBase: the bean and name, then
## New game, Continue (only with a save) and Quit.

func _ready() -> void:
	title_text = "Green Bean"
	version_text = ""
	button_width = 320.0
	button_height = 58.0
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var bg := ColorRect.new()
	bg.color = UiStyle.ROAST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	super._ready()

func _on_menu_ready() -> void:
	var title := get_title_label()
	title.remove_theme_font_size_override("font_size")
	title.theme_type_variation = UiStyle.TITLE
	var box := title.get_parent()
	var bean := UiIcon.make(UiIcon.Kind.BEAN, UiStyle.SAGE, 88)
	bean.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(bean)
	box.move_child(bean, title.get_index())

func _add_default_buttons() -> void:
	add_menu_button("New game", _on_play_pressed)
	var cont := add_menu_button("Continue", _on_continue)
	cont.disabled = not UnlockManager.has_save_file()
	add_menu_button("Quit", _on_quit_pressed)

func _on_play_pressed() -> void:
	UnlockManager.init_new_game()
	UnlockManager.save_to_file()
	get_tree().change_scene_to_file("res://scenes/shops/espresso_stand.tscn")

func _on_continue() -> void:
	if UnlockManager.load_from_file():
		get_tree().change_scene_to_file("res://scenes/shops/espresso_stand.tscn")
