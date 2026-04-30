extends VBoxContainer

@onready var bpm_value: Label = %BPMValue
@onready var bpm_unit: Label = %BPMUnit
@onready var zone_label: Label = %ZoneLabel
@onready var mana_label: Label = %ManaLabel
@onready var per_tick_label: Label = %PerTickLabel
@onready var mult_label: Label = %MultLabel
@onready var wizard_view: SubViewportContainer = %WizardView
@onready var tick_bar: ProgressBar = %TickBar
@onready var tick_label: Label = %TickLabel

var _displayed_mana: float = 0.0
var _target_mana: float = 0.0
const MANA_LERP_SPEED := 10.0

var _heartbeat_accumulator: float = 0.0
var _tick_fill_style: StyleBoxFlat

const ZONE_RESTING := {"name": "RESTING", "color": Color(0.4, 0.6, 0.8)}
const ZONE_LIGHT := {"name": "LIGHT", "color": Color(0.3, 0.7, 0.4)}
const ZONE_MODERATE := {"name": "MODERATE", "color": Color(0.7, 0.8, 0.2)}
const ZONE_VIGOROUS := {"name": "VIGOROUS", "color": Color(0.9, 0.55, 0.1)}
const ZONE_PEAK := {"name": "PEAK", "color": Color(0.9, 0.15, 0.15)}


func _ready() -> void:
	resized.connect(queue_redraw)

	_tick_fill_style = StyleBoxFlat.new()
	_tick_fill_style.bg_color = ThemeBuilder.BAR_FILL
	_tick_fill_style.corner_radius_top_left = 4
	_tick_fill_style.corner_radius_top_right = 4
	_tick_fill_style.corner_radius_bottom_left = 4
	_tick_fill_style.corner_radius_bottom_right = 4
	tick_bar.add_theme_stylebox_override("fill", _tick_fill_style)

	EventBus.mana_changed.connect(_on_mana_changed)
	EventBus.heart_rate_updated.connect(_on_hr_updated)
	EventBus.tick_speed_changed.connect(_on_tick_speed_changed)
	EventBus.tick_fired.connect(_on_tick_fired)

	_target_mana = GameState.mana
	_displayed_mana = _target_mana
	_update_mana_display()
	_update_income_display()
	_update_hr_display(HeartRateManager.smoothed_bpm, HeartRateManager.get_hr_factor())


func _draw() -> void:
	var top := ThemeBuilder.BG_VITALS
	var bottom := ThemeBuilder.BG_VITALS_BOTTOM
	var strips := 20
	var strip_h := size.y / strips
	for i in strips:
		var t := float(i) / float(strips - 1)
		draw_rect(Rect2(0, i * strip_h, size.x, strip_h + 1), top.lerp(bottom, t))

	var grid_color := Color(1.0, 1.0, 1.0, 0.03)
	var y := 12.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
		y += 12.0


func _process(delta: float) -> void:
	tick_bar.value = TickEngine.get_progress()

	var bpm := HeartRateManager.smoothed_bpm
	if bpm > 0.0:
		var beat_interval := 60.0 / bpm
		_heartbeat_accumulator += delta
		if _heartbeat_accumulator >= beat_interval:
			_heartbeat_accumulator -= beat_interval
			_on_heartbeat()

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
	tick_label.text = "Tick: %.1fs" % interval


func _on_tick_fired(_tick_number: int) -> void:
	_flash_tick_bar()
	_update_income_display()


func _on_heartbeat() -> void:
	bpm_value.modulate = Color(1.3, 1.3, 1.3)
	var tween := create_tween()
	tween.tween_property(bpm_value, "modulate", Color.WHITE, 0.2)


func _flash_tick_bar() -> void:
	tick_bar.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween := create_tween()
	tween.tween_property(tick_bar, "modulate", Color.WHITE, 0.3)


func _update_mana_display() -> void:
	mana_label.text = GameFormulas.format_number(_displayed_mana)


func _update_income_display() -> void:
	var mana_per_tick := GeneratorManager.get_total_mana_per_tick()
	per_tick_label.text = "+%s/tick" % GameFormulas.format_number(mana_per_tick)


func _update_hr_display(bpm: float, hr_factor: float) -> void:
	bpm_value.text = "%d" % int(bpm)
	mult_label.text = "%.1fx" % hr_factor

	var zone := _get_hr_zone(bpm)
	zone_label.text = zone["name"]
	zone_label.add_theme_color_override("font_color", zone["color"])
	bpm_value.add_theme_color_override("font_color", zone["color"])
	bpm_unit.add_theme_color_override("font_color", zone["color"].darkened(0.3))
	mult_label.add_theme_color_override("font_color", zone["color"])

	_tick_fill_style.bg_color = zone["color"].darkened(0.15)
	wizard_view.set_zone_color(zone["color"])


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
