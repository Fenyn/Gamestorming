extends CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _restart_btn: Button = $Panel/Margin/VBox/RestartBtn


func _ready() -> void:
	_panel.visible = false
	_restart_btn.pressed.connect(_restart)
	EventBus.bill_missed.connect(_on_bill_missed)


func _on_bill_missed(consecutive: int) -> void:
	if consecutive >= 2:
		_show()


func _show() -> void:
	_panel.visible = true
	_panel.modulate.a = 0.0
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_panel, "modulate:a", 1.0, 1.0)


func _restart() -> void:
	SaveManager.delete_save()
	get_tree().paused = false
	get_tree().reload_current_scene()
