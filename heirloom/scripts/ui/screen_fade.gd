extends CanvasLayer

signal fade_finished

@onready var _rect: ColorRect = $ColorRect
@onready var _label: Label = $DayLabel

var _tween: Tween = null


func _ready() -> void:
	add_to_group("screen_fade")
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false


func fade_to_black(duration: float = 0.8) -> void:
	_kill_tween()
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween()
	_tween.tween_property(_rect, "color:a", 1.0, duration)
	await _tween.finished


func fade_from_black(duration: float = 0.8) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_rect, "color:a", 0.0, duration)
	await _tween.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_day_text(text: String, hold_time: float = 1.5) -> void:
	_label.text = text
	_label.visible = true
	_label.modulate.a = 0.0
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, 0.3)
	_tween.tween_interval(hold_time)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.3)
	await _tween.finished
	_label.visible = false


func sleep_transition() -> void:
	await fade_to_black(0.8)
	show_day_text("Day %d" % GameState.day, 1.5)
	await fade_from_black(0.8)


func collapse_transition() -> void:
	await fade_to_black(0.5)
	show_day_text("You passed out...", 2.0)
	await fade_from_black(1.0)


func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
