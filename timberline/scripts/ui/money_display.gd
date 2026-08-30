extends Label
## HUD money readout. Tracks GameManager.money via money_changed and
## flashes green on a change.

var _pulse_tween: Tween = null


func _ready() -> void:
	text = "$ %d" % GameManager.money
	EventBus.money_changed.connect(_on_money_changed)


func _on_money_changed(new_amount: int) -> void:
	text = "$ %d" % new_amount
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	modulate = Color(0.65, 1.0, 0.6)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "modulate", Color.WHITE, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
