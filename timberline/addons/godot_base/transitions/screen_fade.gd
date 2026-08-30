class_name ScreenFade
extends ColorRect

var _tween: Tween = null


func _ready() -> void:
	color = Color(0.0, 0.0, 0.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = Control.PRESET_FULL_RECT
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func fade_to_black(duration: float = 0.5) -> void:
	_kill_tween()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween()
	_tween.tween_property(self, "color:a", 1.0, duration)
	await _tween.finished


func fade_from_black(duration: float = 0.5) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "color:a", 0.0, duration)
	await _tween.finished
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func fade_to(alpha: float, duration: float = 0.5) -> void:
	_kill_tween()
	if alpha > 0.0:
		mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween()
	_tween.tween_property(self, "color:a", alpha, duration)
	await _tween.finished
	if alpha <= 0.0:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func snap_to_black() -> void:
	_kill_tween()
	color.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func snap_to_clear() -> void:
	_kill_tween()
	color.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
