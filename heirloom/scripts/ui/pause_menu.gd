extends CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _resume_btn: Button = $Panel/Margin/VBox/ResumeBtn
@onready var _save_btn: Button = $Panel/Margin/VBox/SaveBtn
@onready var _quit_btn: Button = $Panel/Margin/VBox/QuitBtn

var _paused := false


func _ready() -> void:
	_panel.visible = false
	_resume_btn.pressed.connect(_resume)
	_save_btn.pressed.connect(_save)
	_quit_btn.pressed.connect(_quit)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		if _paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	_paused = true
	_panel.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _resume() -> void:
	_paused = false
	_panel.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _save() -> void:
	SaveManager.save_game()
	_save_btn.text = "Saved!"
	var tween: Tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void: _save_btn.text = "Save Game")


func _quit() -> void:
	SaveManager.save_game()
	get_tree().paused = false
	get_tree().quit()
