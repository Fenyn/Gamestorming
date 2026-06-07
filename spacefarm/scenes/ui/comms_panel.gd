class_name CommsPanel
extends PanelContainer


func _ready() -> void:
	visible = false


func on_opened() -> void:
	EventBus.comms_opened.emit()


func on_closed() -> void:
	EventBus.comms_closed.emit()
