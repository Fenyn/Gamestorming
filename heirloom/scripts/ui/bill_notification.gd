extends CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _text_label: Label = $Panel/Margin/TextLabel

var _tween: Tween = null


func _ready() -> void:
	_panel.visible = false
	EventBus.bill_paid.connect(_on_bill_paid)
	EventBus.bill_missed.connect(_on_bill_missed)


func _on_bill_paid(amount: float) -> void:
	_show("Land payment: -$%.0f\nPaid in full." % amount, Color(0.5, 0.9, 0.5))


func _on_bill_missed(consecutive: int) -> void:
	if consecutive >= 2:
		_show("FORECLOSED\nYou missed 2 consecutive payments.\nGame Over.", Color(0.9, 0.2, 0.2))
	else:
		_show("PAYMENT MISSED!\nYou couldn't cover the $200 land payment.\nMiss one more and you lose the homestead.", Color(0.9, 0.6, 0.2))


func _show(text: String, color: Color) -> void:
	_text_label.text = text
	_text_label.add_theme_color_override("font_color", color)
	_panel.visible = true
	_panel.modulate.a = 0.0

	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.3)
	_tween.tween_interval(4.0)
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(func() -> void: _panel.visible = false)
