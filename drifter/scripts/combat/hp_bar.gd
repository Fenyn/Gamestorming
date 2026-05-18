class_name HPBar
extends HBoxContainer

@onready var _name_label: Label = %BarName
@onready var _bar: ProgressBar = %Bar
@onready var _ghost_bar: ProgressBar = %GhostBar
@onready var _bar_container: Control = %BarContainer
@onready var _value_label: Label = %BarValue
@onready var _delta_label: Label = %DeltaLabel

var _max_val: int = 1
var _current_val: int = 0
var _bar_color: Color = ThemeBuilder.HP_TEAL
var _bar_tween: Tween
var _ghost_tween: Tween
var _pulse_tween: Tween
var _delta_tween: Tween

const LOW_HP_THRESHOLD: float = 0.25
const GHOST_DELAY: float = 0.35
const GHOST_DURATION: float = 0.5
const BAR_DURATION: float = 0.25


func setup(display_name: String, max_hp: int, color: Color) -> void:
	_max_val = max_hp
	_current_val = max_hp
	_bar_color = color

	if _name_label:
		_name_label.text = display_name

	if _bar:
		_bar.max_value = max_hp
		_bar.value = max_hp
		var fill: StyleBoxFlat = ThemeBuilder.create_flat_style(color, color, 0, 1, 0)
		_bar.add_theme_stylebox_override("fill", fill)
		var bg: StyleBoxFlat = ThemeBuilder.create_flat_style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 1, 0)
		_bar.add_theme_stylebox_override("background", bg)

	if _ghost_bar:
		_ghost_bar.max_value = max_hp
		_ghost_bar.value = max_hp
		var ghost_bg: StyleBoxFlat = ThemeBuilder.create_flat_style(
			Color(0.08, 0.08, 0.12), ThemeBuilder.BORDER, 1, 1, 0
		)
		_ghost_bar.add_theme_stylebox_override("background", ghost_bg)
		var ghost_color: Color = color.lerp(Color(0.85, 0.15, 0.1), 0.6)
		var ghost_fill: StyleBoxFlat = ThemeBuilder.create_flat_style(ghost_color, ghost_color, 0, 1, 0)
		_ghost_bar.add_theme_stylebox_override("fill", ghost_fill)

	if _delta_label:
		_delta_label.text = ""
		_delta_label.modulate.a = 0.0

	_update_text(max_hp)


func set_value(new_val: int) -> void:
	var old_val: int = _current_val
	_current_val = new_val
	var delta: int = new_val - old_val

	if delta == 0:
		return

	if _bar_tween:
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_property(_bar, "value", float(new_val), BAR_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	if delta < 0:
		if _ghost_tween:
			_ghost_tween.kill()
		_ghost_tween = create_tween()
		_ghost_tween.tween_property(_ghost_bar, "value", float(new_val), GHOST_DURATION) \
			.set_delay(GHOST_DELAY).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	else:
		if _ghost_bar:
			_ghost_bar.value = new_val

	_flash(delta)
	_show_delta(delta)
	_check_low_hp()
	_update_text(new_val)


func set_shield(amount: int) -> void:
	if amount > 0:
		_value_label.text = str(_current_val) + "/" + str(_max_val) + " [" + str(amount) + "]"
		_value_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_SHIELD)
	else:
		_update_text(_current_val)
		_value_label.remove_theme_color_override("font_color")


func _flash(delta: int) -> void:
	if not _bar:
		return
	var flash_color: Color = Color(1.0, 0.3, 0.15) if delta < 0 else Color(0.2, 1.0, 0.4)
	var fill: StyleBoxFlat = _bar.get_theme_stylebox("fill") as StyleBoxFlat
	if not fill:
		return
	var tween: Tween = create_tween()
	tween.tween_property(fill, "bg_color", flash_color, 0.05)
	tween.tween_property(fill, "bg_color", _bar_color, 0.3).set_ease(Tween.EASE_OUT)


func _show_delta(delta: int) -> void:
	if not _delta_label:
		return
	if _delta_tween:
		_delta_tween.kill()

	if delta > 0:
		_delta_label.text = "+" + str(delta)
		_delta_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_HEAL)
	else:
		_delta_label.text = str(delta)
		_delta_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_DAMAGE)

	_delta_label.modulate.a = 1.0
	_delta_label.position.y = -18.0

	_delta_tween = create_tween()
	_delta_tween.set_parallel(true)
	_delta_tween.tween_property(_delta_label, "position:y", -34.0, 1.0).set_ease(Tween.EASE_OUT)
	_delta_tween.tween_property(_delta_label, "modulate:a", 0.0, 0.6).set_delay(0.4)


func _check_low_hp() -> void:
	var is_low: bool = float(_current_val) / float(_max_val) < LOW_HP_THRESHOLD and _current_val > 0
	if is_low and not _pulse_tween:
		_start_pulse()
	elif not is_low and _pulse_tween:
		_stop_pulse()


func _start_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_bar, "modulate", Color(1.4, 0.7, 0.7), 0.5)
	_pulse_tween.tween_property(_bar, "modulate", Color.WHITE, 0.5)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	if _bar:
		_bar.modulate = Color.WHITE


func _update_text(current: int) -> void:
	if _value_label:
		_value_label.text = str(current) + "/" + str(_max_val)
