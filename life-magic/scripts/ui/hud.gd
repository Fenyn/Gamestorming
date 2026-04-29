extends PanelContainer

@onready var mana_label: Label = %ManaLabel
@onready var per_tick_label: Label = %PerTickLabel
@onready var per_sec_label: Label = %PerSecLabel
@onready var bpm_value: Label = %BPMValue
@onready var bpm_unit: Label = %BPMUnit
@onready var zone_label: Label = %ZoneLabel
@onready var phase_label: Label = %PhaseLabel
@onready var mult_label: Label = %MultLabel
@onready var tick_label: Label = %TickLabel
@onready var heart_icon: Label = %HeartIcon
@onready var tick_bar: ProgressBar = %TickBar

var _displayed_mana: float = 0.0
var _target_mana: float = 0.0
const MANA_LERP_SPEED := 10.0

var _heartbeat_accumulator: float = 0.0

const ZONE_RESTING := {"name": "RESTING", "color": Color(0.4, 0.6, 0.8)}
const ZONE_LIGHT := {"name": "LIGHT", "color": Color(0.3, 0.7, 0.4)}
const ZONE_MODERATE := {"name": "MODERATE", "color": Color(0.7, 0.8, 0.2)}
const ZONE_VIGOROUS := {"name": "VIGOROUS", "color": Color(0.9, 0.55, 0.1)}
const ZONE_PEAK := {"name": "PEAK", "color": Color(0.9, 0.15, 0.15)}


func _ready() -> void:
	EventBus.mana_changed.connect(_on_mana_changed)
	EventBus.heart_rate_updated.connect(_on_hr_updated)
	EventBus.tick_speed_changed.connect(_on_tick_speed_changed)
	EventBus.tick_fired.connect(_on_tick_fired)

	_target_mana = GameState.mana
	_displayed_mana = _target_mana
	_update_mana_display()
	_update_income_display()
	_update_hr_display(HeartRateManager.smoothed_bpm, HeartRateManager.get_hr_factor())


func _process(delta: float) -> void:
	tick_bar.value = TickEngine.get_progress()

	var bpm := HeartRateManager.smoothed_bpm
	if bpm > 0.0:
		var beat_interval := 60.0 / bpm
		_heartbeat_accumulator += delta
		if _heartbeat_accumulator >= beat_interval:
			_heartbeat_accumulator -= beat_interval
			_pulse_heart()

	if not is_equal_approx(_displayed_mana, _target_mana):
		_displayed_mana = lerpf(_displayed_mana, _target_mana, MANA_LERP_SPEED * delta)
		if absf(_displayed_mana - _target_mana) < 0.5:
			_displayed_mana = _target_mana
		_update_mana_display()


func _on_mana_changed(new_amount: float, _delta: float) -> void:
	_target_mana = new_amount
	_update_income_display()


func _on_hr_updated(bpm: float, hr_factor: float) -> void:
	_update_hr_display(bpm, hr_factor)


func _on_tick_speed_changed(interval: float) -> void:
	tick_label.text = "%.1fs" % interval


func _on_tick_fired(_tick_number: int) -> void:
	_flash_tick_bar()
	_update_income_display()


func _pulse_heart() -> void:
	var tween := create_tween()
	tween.tween_property(heart_icon, "scale", Vector2(1.4, 1.4), 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(heart_icon, "scale", Vector2(0.9, 0.9), 0.1).set_ease(Tween.EASE_IN)
	tween.tween_property(heart_icon, "scale", Vector2(1.15, 1.15), 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(heart_icon, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN_OUT)


func _flash_tick_bar() -> void:
	tick_bar.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween := create_tween()
	tween.tween_property(tick_bar, "modulate", Color.WHITE, 0.3)


func _update_mana_display() -> void:
	mana_label.text = GameFormulas.format_number(_displayed_mana)


func _update_income_display() -> void:
	var mana_per_tick := GeneratorManager.get_total_mana_per_tick()
	var interval := TickEngine.get_current_interval()
	var per_second := mana_per_tick / interval if interval > 0.0 else 0.0
	per_tick_label.text = "+%s/tick" % GameFormulas.format_number(mana_per_tick)
	per_sec_label.text = "+%s/s" % GameFormulas.format_number(per_second)


func _update_hr_display(bpm: float, hr_factor: float) -> void:
	bpm_value.text = "%d" % int(bpm)

	if HeartRateManager.current_phase != "":
		phase_label.text = HeartRateManager.current_phase
	else:
		phase_label.text = ""
	mult_label.text = "%.1fx" % hr_factor

	var zone := _get_hr_zone(bpm)
	zone_label.text = zone["name"]
	zone_label.add_theme_color_override("font_color", zone["color"])
	bpm_value.add_theme_color_override("font_color", zone["color"])
	bpm_unit.add_theme_color_override("font_color", zone["color"].darkened(0.3))
	mult_label.add_theme_color_override("font_color", zone["color"])


func _get_hr_zone(bpm: float) -> Dictionary:
	var age: float = GameState.settings.get("age", 30.0)
	var max_hr := GameFormulas.max_heart_rate(age)
	var pct := bpm / max_hr if max_hr > 0.0 else 0.0

	if pct >= 0.85:
		return ZONE_PEAK
	elif pct >= 0.70:
		return ZONE_VIGOROUS
	elif pct >= 0.55:
		return ZONE_MODERATE
	elif pct >= 0.40:
		return ZONE_LIGHT
	return ZONE_RESTING
