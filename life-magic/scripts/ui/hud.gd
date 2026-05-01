extends VBoxContainer

@onready var bpm_value: Label = %BPMValue
@onready var bpm_unit: Label = %BPMUnit
@onready var zone_label: Label = %ZoneLabel
@onready var mana_label: Label = %ManaLabel
@onready var per_beat_label: Label = %PerTickLabel
@onready var mult_label: Label = %MultLabel
@onready var wizard_view: SubViewportContainer = %WizardView
@onready var vitality_label: Label = %VitalityLabel
@onready var vital_charge_btn: Button = %VitalChargeBtn
@onready var surge_bar: HBoxContainer = %SurgeBar
@onready var surge_label: Label = %SurgeLabel
@onready var surge_progress: ProgressBar = %SurgeProgress
@onready var surge_timer_label: Label = %SurgeTimerLabel

var _displayed_mana: float = 0.0
var _target_mana: float = 0.0
const MANA_LERP_SPEED := 10.0

func _ready() -> void:
	resized.connect(queue_redraw)

	EventBus.mana_changed.connect(_on_mana_changed)
	EventBus.heart_rate_updated.connect(_on_hr_updated)
	EventBus.heartbeat_fired.connect(_on_heartbeat)
	EventBus.tick_fired.connect(_on_tick_fired)
	EventBus.vitality_changed.connect(_on_vitality_changed)
	EventBus.surge_opportunity.connect(_on_surge_opportunity)
	EventBus.surge_completed.connect(_on_surge_completed)
	EventBus.surge_expired.connect(_on_surge_expired)
	EventBus.surge_effect_started.connect(_on_surge_effect_started)
	EventBus.surge_effect_ended.connect(_on_surge_effect_ended)

	_target_mana = GameState.mana
	_displayed_mana = _target_mana
	_update_mana_display()
	_update_income_display()
	_update_hr_display(HeartRateManager.smoothed_bpm, HeartRateManager.get_hr_factor())
	_update_vitality_display()
	vital_charge_btn.pressed.connect(_on_vital_charge_pressed)
	surge_bar.visible = false


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
	if not is_equal_approx(_displayed_mana, _target_mana):
		_displayed_mana = lerpf(_displayed_mana, _target_mana, MANA_LERP_SPEED * delta)
		if absf(_displayed_mana - _target_mana) < 0.5:
			_displayed_mana = _target_mana
		_update_mana_display()
	_update_surge_display()


func _on_mana_changed(new_amount: float, _delta: float) -> void:
	_target_mana = new_amount
	_update_income_display()


func _on_hr_updated(bpm: float, hr_factor: float) -> void:
	_update_hr_display(bpm, hr_factor)


func _on_tick_fired(_beat_number: int) -> void:
	_update_income_display()


func _on_heartbeat() -> void:
	bpm_value.modulate = Color(1.3, 1.3, 1.3)
	var tween := create_tween()
	tween.tween_property(bpm_value, "modulate", Color.WHITE, 0.2)


func _update_mana_display() -> void:
	mana_label.text = GameFormulas.format_number(_displayed_mana)


func _update_income_display() -> void:
	var mana_per_beat := GeneratorManager.get_total_mana_per_beat()
	per_beat_label.text = "+%s/beat" % GameFormulas.format_number(mana_per_beat)


func _update_hr_display(bpm: float, hr_factor: float) -> void:
	bpm_value.text = "%d" % int(bpm)
	mult_label.text = "%.1fx" % hr_factor

	var zone := GameFormulas.get_hr_zone(bpm, GameState.get_age())
	var zone_color: Color = zone["color"]
	zone_label.text = zone["name"]
	zone_label.add_theme_color_override("font_color", zone_color)
	bpm_value.add_theme_color_override("font_color", zone_color)
	bpm_unit.add_theme_color_override("font_color", zone_color.darkened(0.3))
	mult_label.add_theme_color_override("font_color", zone_color)

	wizard_view.set_zone_color(zone_color)


func _on_vitality_changed(_amount: float) -> void:
	_update_vitality_display()


func _update_vitality_display() -> void:
	if SurgeManager.vital_charge_active():
		var remaining := int(SurgeManager.get_vital_charge_remaining())
		vitality_label.text = "2x Production %d:%02d" % [remaining / 60, remaining % 60]
		vitality_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)
		vitality_label.visible = true
		vital_charge_btn.visible = false
	elif GameState.vitality > 0.0:
		vitality_label.text = "%s Vit" % GameFormulas.format_number(GameState.vitality)
		vitality_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))
		vitality_label.visible = true
		vital_charge_btn.visible = GameState.vitality >= 3.0
		vital_charge_btn.disabled = GameState.vitality < 3.0
	else:
		vitality_label.visible = false
		vital_charge_btn.visible = false


func _on_vital_charge_pressed() -> void:
	if SurgeManager.vital_charge_active():
		return
	if GameState.spend_vitality(3.0):
		SurgeManager.activate_vital_charge()
		EventBus.notification.emit(
			"Vital Charge! 2x production for 3 minutes. Time to move!",
			"surge"
		)
		_update_vitality_display()


func _on_surge_opportunity(_surge_id: String) -> void:
	surge_bar.visible = true
	surge_label.text = SurgeManager.get_surge_message()
	surge_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GOLD)
	surge_progress.value = 0.0
	EventBus.notification.emit("A surge opportunity has appeared!", "surge")


func _on_surge_completed(_surge_id: String) -> void:
	if SurgeManager.state == SurgeManager.State.IDLE:
		surge_bar.visible = false


func _on_surge_expired(_surge_id: String) -> void:
	surge_bar.visible = false


func _on_surge_effect_started(surge_id: String, _duration: float) -> void:
	surge_bar.visible = true
	var surge_name := surge_id.replace("_", " ").capitalize()
	surge_label.text = "%s active!" % surge_name
	surge_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)
	surge_progress.value = 100.0


func _on_surge_effect_ended(_surge_id: String) -> void:
	surge_bar.visible = false


func _update_surge_display() -> void:
	if not surge_bar.visible:
		return

	match SurgeManager.state:
		SurgeManager.State.OFFERING, SurgeManager.State.TRACKING:
			var progress := SurgeManager.get_hold_progress() * 100.0
			surge_progress.value = progress
			var remaining := int(SurgeManager.get_offer_time_remaining())
			var mins := remaining / 60
			var secs := remaining % 60
			surge_timer_label.text = "%d:%02d" % [mins, secs]
			if SurgeManager.state == SurgeManager.State.TRACKING:
				surge_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)
			else:
				surge_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GOLD)
		SurgeManager.State.ACTIVE:
			var remaining := int(SurgeManager.get_effect_time_remaining())
			var secs := remaining % 60
			var mins := remaining / 60
			surge_timer_label.text = "%d:%02d" % [mins, secs]
			var total_duration: float = SurgeManager.current_surge.get("effect_duration", 1.0)
			if total_duration > 0.0:
				surge_progress.value = (SurgeManager.get_effect_time_remaining() / total_duration) * 100.0
		_:
			surge_bar.visible = false
