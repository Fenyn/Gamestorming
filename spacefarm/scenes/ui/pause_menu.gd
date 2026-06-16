class_name PauseMenu
extends PanelContainer

@onready var _resume_btn: Button = %ResumeButton
@onready var _save_btn: Button = %SaveButton


func _ready() -> void:
	visible = false
	_resume_btn.pressed.connect(_on_resume)
	_save_btn.pressed.connect(_on_save)


func on_opened() -> void:
	pass


func on_closed() -> void:
	pass


func _on_resume() -> void:
	EventBus.notification_requested.emit("")
	visible = false
	get_tree().paused = false
	InputManager.set_mode(InputContext.Mode.GAMEPLAY)


func _on_save() -> void:
	GameState.save_game()
	_save_btn.text = "SAVED!"
