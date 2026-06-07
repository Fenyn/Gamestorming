class_name CommsPanel
extends PanelContainer


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	InputManager.set_mode(InputContext.Mode.CUTSCENE)
	EventBus.comms_opened.emit()


func close() -> void:
	visible = false
	InputManager.set_mode(InputContext.Mode.GAMEPLAY)
	EventBus.comms_closed.emit()
