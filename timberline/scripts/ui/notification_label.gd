extends Label
## HUD notification line. Anything may publish via
## EventBus.notification_requested; the message holds briefly and fades.

var _tween: Tween = null


func _ready() -> void:
	modulate.a = 0.0
	EventBus.notification_requested.connect(_on_notification)


func _on_notification(message: String) -> void:
	text = message
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(1.8)
	_tween.tween_property(self, "modulate:a", 0.0, 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
