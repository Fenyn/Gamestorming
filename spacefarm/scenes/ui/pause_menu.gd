class_name PauseMenu
extends PanelContainer

@onready var _resume_btn: Button = %ResumeButton
@onready var _save_btn: Button = %SaveButton


func _ready() -> void:
	visible = false
	_resume_btn.pressed.connect(_on_resume)
	_save_btn.pressed.connect(_on_save)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	InputManager.set_mode(InputContext.Mode.MENU)


func close() -> void:
	visible = false
	get_tree().paused = false
	InputManager.set_mode(InputContext.Mode.GAMEPLAY)


func _on_resume() -> void:
	close()


func _on_save() -> void:
	var handler: SaveFileHandler = SaveFileHandler.new(GameState.SAVE_PATH, GameState.SAVE_VERSION)
	handler.save_dict(GameState.to_dict())
	_save_btn.text = "SAVED!"
	await get_tree().create_timer(1.0).timeout
	_save_btn.text = "SAVE GAME"
