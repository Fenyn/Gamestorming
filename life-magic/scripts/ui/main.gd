extends Control

@onready var bpm_value: Label = %BPMValue
@onready var bpm_unit: Label = %BPMUnit
@onready var zone_label: Label = %ZoneLabel
@onready var mana_label: Label = %ManaLabel
@onready var per_beat_label: Label = %PerBeatLabel
@onready var mult_label: Label = %MultLabel
@onready var top_bar: PanelContainer = %TopBar

@onready var buff_row: HBoxContainer = %BuffRow
@onready var sub_panel_bar: HBoxContainer = %SubPanelBar
@onready var back_btn: Button = %BackBtn
@onready var sub_panel_title: Label = %SubPanelTitle

@onready var generator_panel: ScrollContainer = %GeneratorPanel
@onready var grimoire_hub: ScrollContainer = %GrimoireHub
@onready var plot_panel: ScrollContainer = %PlotPanel
@onready var upgrade_panel: ScrollContainer = %UpgradePanel
@onready var milestone_panel: ScrollContainer = %MilestonePanel
@onready var essence_tree_panel: ScrollContainer = %EssenceTreePanel
@onready var settings_panel: ScrollContainer = %SettingsPanel

@onready var spells_tab: Button = %SpellsTab
@onready var grimoire_tab: Button = %GrimoireTab
@onready var profile_tab: Button = %ProfileTab

@onready var tap_hint: Label = %TapHint
@onready var notification_label: Label = %NotificationLabel
@onready var notification_panel: PanelContainer = %NotificationPanel
@onready var bpm_debug_label: Label = %BPMDebugLabel

var _displayed_mana: float = 0.0
var _target_mana: float = 0.0
const MANA_LERP_SPEED := 10.0

var _surge_pill: PanelContainer
var _surge_text: Label
var _surge_progress: ProgressBar
var _surge_timer: Label
var _vital_pill: PanelContainer
var _vital_text: Label
var _charge_btn: Button

var _notification_tween: Tween
var _notification_is_tutorial: bool = false
var _bpm_label_tween: Tween
const BPM_STEP := 5.0
const BPM_MIN := 40.0
const BPM_MAX := 200.0

var _tabs: Array[Button] = []
var _panels: Array[Control] = []
var _active_sub_panel: Control = null
var _sub_panel_map: Dictionary = {}


func _ready() -> void:
	theme = ThemeBuilder.build()
	_style_bars()
	_build_buff_pills()

	_tabs = [spells_tab, grimoire_tab, profile_tab]
	_panels = [generator_panel, grimoire_hub, settings_panel]

	_sub_panel_map = {
		"upgrades": upgrade_panel,
		"sanctums": plot_panel,
		"chronicle": milestone_panel,
		"blessings": essence_tree_panel,
	}

	for i in _tabs.size():
		var idx := i
		_tabs[i].pressed.connect(func(): _switch_tab(idx))

	grimoire_hub.tile_pressed.connect(_open_sub_panel)
	back_btn.pressed.connect(_close_sub_panel)

	EventBus.milestone_earned.connect(_on_milestone_earned)
	EventBus.loop_completed.connect(_on_prestige_completed)
	EventBus.mana_changed.connect(_on_mana_changed)
	EventBus.heart_rate_updated.connect(_on_hr_updated)
	EventBus.heartbeat_fired.connect(_on_heartbeat)
	EventBus.tick_fired.connect(func(_t): _update_income_display())
	EventBus.notification.connect(_on_notification)

	notification_panel.visible = false
	notification_panel.gui_input.connect(_on_notification_input)
	bpm_debug_label.visible = false

	_target_mana = GameState.mana
	_displayed_mana = _target_mana
	_update_mana_display()
	_update_income_display()
	_update_hr_display(HeartRateManager.smoothed_bpm, HeartRateManager.get_hr_factor())
	tap_hint.visible = HeartRateManager.source == "demo"
	EventBus.heart_rate_source_changed.connect(func(_s): tap_hint.visible = HeartRateManager.source == "demo")

	_switch_tab(0)


func _style_bars() -> void:
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.04, 0.06, 0.04, 0.92)
	top_style.border_color = ThemeBuilder.BORDER
	top_style.border_width_bottom = 1
	top_bar.add_theme_stylebox_override("panel", top_style)

	var notif_style := StyleBoxFlat.new()
	notif_style.bg_color = Color(0.08, 0.12, 0.08, 0.95)
	notif_style.corner_radius_top_left = 8
	notif_style.corner_radius_top_right = 8
	notif_style.corner_radius_bottom_left = 8
	notif_style.corner_radius_bottom_right = 8
	notif_style.border_color = ThemeBuilder.BORDER
	notif_style.border_width_bottom = 1
	notification_panel.add_theme_stylebox_override("panel", notif_style)


func _build_buff_pills() -> void:
	_surge_pill = PanelContainer.new()
	_surge_pill.visible = false
	_surge_pill.add_theme_stylebox_override("panel", ThemeBuilder.create_pill_style(ThemeBuilder.TEXT_GOLD))
	var surge_hbox := HBoxContainer.new()
	surge_hbox.add_theme_constant_override("separation", 6)
	_surge_pill.add_child(surge_hbox)
	_surge_text = Label.new()
	_surge_text.add_theme_font_size_override("font_size", 10)
	surge_hbox.add_child(_surge_text)
	_surge_progress = ProgressBar.new()
	_surge_progress.custom_minimum_size = Vector2(40, 8)
	_surge_progress.max_value = 100.0
	_surge_progress.show_percentage = false
	surge_hbox.add_child(_surge_progress)
	_surge_timer = Label.new()
	_surge_timer.add_theme_font_size_override("font_size", 10)
	surge_hbox.add_child(_surge_timer)
	buff_row.add_child(_surge_pill)

	_vital_pill = PanelContainer.new()
	_vital_pill.visible = false
	_vital_pill.add_theme_stylebox_override("panel", ThemeBuilder.create_pill_style(Color(0.3, 0.7, 0.9)))
	var vital_hbox := HBoxContainer.new()
	vital_hbox.add_theme_constant_override("separation", 6)
	_vital_pill.add_child(vital_hbox)
	_vital_text = Label.new()
	_vital_text.add_theme_font_size_override("font_size", 10)
	vital_hbox.add_child(_vital_text)
	_charge_btn = Button.new()
	_charge_btn.text = "Charge"
	_charge_btn.add_theme_font_size_override("font_size", 9)
	_charge_btn.custom_minimum_size = Vector2(50, 22)
	_charge_btn.pressed.connect(_on_vital_charge_pressed)
	vital_hbox.add_child(_charge_btn)
	buff_row.add_child(_vital_pill)


func _process(delta: float) -> void:
	if not is_equal_approx(_displayed_mana, _target_mana):
		_displayed_mana = lerpf(_displayed_mana, _target_mana, MANA_LERP_SPEED * delta)
		if absf(_displayed_mana - _target_mana) < 0.5:
			_displayed_mana = _target_mana
		_update_mana_display()
	_update_buff_display()


# --- Top Bar ---


func _on_mana_changed(new_amount: float, _delta: float) -> void:
	_target_mana = new_amount
	_update_income_display()


func _on_hr_updated(bpm: float, hr_factor: float) -> void:
	_update_hr_display(bpm, hr_factor)


func _on_heartbeat() -> void:
	var flash := Color(1.8, 1.8, 1.8)
	bpm_value.modulate = flash
	mana_label.modulate = flash
	per_beat_label.modulate = flash

	bpm_value.pivot_offset = bpm_value.size / 2.0
	mana_label.pivot_offset = mana_label.size / 2.0
	bpm_value.scale = Vector2(1.12, 1.12)
	mana_label.scale = Vector2(1.08, 1.08)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(bpm_value, "modulate", Color.WHITE, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(mana_label, "modulate", Color.WHITE, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(per_beat_label, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(bpm_value, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(mana_label, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


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


# --- Buff Row ---


func _update_buff_display() -> void:
	var any_visible := false

	match SurgeManager.state:
		SurgeManager.State.OFFERING, SurgeManager.State.TRACKING:
			_surge_pill.visible = true
			_surge_progress.value = SurgeManager.get_hold_progress() * 100.0
			var remaining := int(SurgeManager.get_offer_time_remaining())
			_surge_timer.text = "%d:%02d" % [remaining / 60, remaining % 60]
			if SurgeManager.state == SurgeManager.State.TRACKING:
				_surge_text.text = "Tracking"
				_surge_text.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)
			else:
				_surge_text.text = "Surge!"
				_surge_text.add_theme_color_override("font_color", ThemeBuilder.TEXT_GOLD)
			any_visible = true
		SurgeManager.State.ACTIVE:
			_surge_pill.visible = true
			var remaining := int(SurgeManager.get_effect_time_remaining())
			_surge_timer.text = "%d:%02d" % [remaining / 60, remaining % 60]
			var total_dur: float = SurgeManager.current_surge.get("effect_duration", 1.0)
			if total_dur > 0.0:
				_surge_progress.value = (SurgeManager.get_effect_time_remaining() / total_dur) * 100.0
			_surge_text.text = SurgeManager.current_surge.get("name", "Surge")
			_surge_text.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)
			any_visible = true
		_:
			_surge_pill.visible = false

	if SurgeManager.vital_charge_active():
		var remaining := int(SurgeManager.get_vital_charge_remaining())
		_vital_text.text = "2x %d:%02d" % [remaining / 60, remaining % 60]
		_vital_text.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)
		_charge_btn.visible = false
		_vital_pill.visible = true
		any_visible = true
	elif GameState.vitality > 0.0:
		_vital_text.text = "%s Vit" % GameFormulas.format_number(GameState.vitality)
		_vital_text.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))
		_charge_btn.visible = GameState.vitality >= 3.0
		_vital_pill.visible = true
		any_visible = true
	else:
		_vital_pill.visible = false

	buff_row.visible = any_visible


func _on_vital_charge_pressed() -> void:
	if SurgeManager.vital_charge_active():
		return
	if GameState.spend_vitality(3.0):
		SurgeManager.activate_vital_charge()
		EventBus.notification.emit(
			"Vital Charge! 2x production for 3 minutes. Time to move!",
			"surge"
		)


# --- Navigation ---


func _switch_tab(index: int) -> void:
	_close_sub_panel()
	for i in _tabs.size():
		var is_active := i == index
		_tabs[i].button_pressed = is_active
		_panels[i].visible = is_active
		_style_tab(_tabs[i], is_active)


func _open_sub_panel(panel_id: String) -> void:
	var panel: Control = _sub_panel_map.get(panel_id)
	if not panel:
		return
	_active_sub_panel = panel
	grimoire_hub.visible = false
	panel.visible = true
	sub_panel_bar.visible = true
	sub_panel_title.text = _get_panel_title(panel_id)


func _close_sub_panel() -> void:
	if _active_sub_panel:
		_active_sub_panel.visible = false
		_active_sub_panel = null
	sub_panel_bar.visible = false
	if grimoire_tab.button_pressed:
		grimoire_hub.visible = true


func _get_panel_title(panel_id: String) -> String:
	match panel_id:
		"upgrades": return "Upgrades"
		"sanctums": return "Sanctums"
		"chronicle": return "Chronicle"
		"blessings": return "Essence Tree"
		"research": return "Arcanum"
	return ""


func _style_tab(btn: Button, active: bool) -> void:
	var style := ThemeBuilder.create_bottom_tab_style(active)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", ThemeBuilder.TEXT_PRIMARY if active else ThemeBuilder.TEXT_MUTED)
	btn.add_theme_font_size_override("font_size", 12)


func _on_milestone_earned(_milestone_id: String) -> void:
	if MilestoneManager.get_earned_count() == 1:
		EventBus.notification.emit("A new page has appeared in the Grimoire!", "tutorial")


func _on_prestige_completed(_total_cycles: int) -> void:
	EventBus.notification.emit("A new page has appeared in the Grimoire!", "tutorial")


# --- Notifications ---


func _on_notification(message: String, type: String) -> void:
	notification_label.text = message
	notification_panel.visible = true
	notification_panel.modulate.a = 1.0

	var is_tutorial := type == "tutorial"
	notification_label.add_theme_color_override("font_color",
		ThemeBuilder.TEXT_GOLD if is_tutorial else ThemeBuilder.TEXT_PRIMARY)

	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()

	if is_tutorial:
		_notification_is_tutorial = true
		notification_label.text += "\n(tap to dismiss)"
	else:
		_notification_is_tutorial = false
		_notification_tween = create_tween()
		_notification_tween.tween_interval(5.0)
		_notification_tween.tween_property(notification_panel, "modulate:a", 0.0, 1.0)
		_notification_tween.tween_callback(func():
			notification_panel.visible = false
			notification_panel.modulate.a = 1.0
		)


func _on_notification_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_notification()


func _dismiss_notification() -> void:
	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()
	notification_panel.visible = false
	notification_panel.modulate.a = 1.0
	_notification_is_tutorial = false


# --- Tap Ripple ---


func _spawn_ripple(pos: Vector2) -> void:
	var ripple := ColorRect.new()
	ripple.color = Color(0.4, 0.9, 0.4, 0.35)
	ripple.size = Vector2(8, 8)
	ripple.position = pos - Vector2(4, 4)
	ripple.pivot_offset = Vector2(4, 4)
	ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ripple)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(ripple, "scale", Vector2(8, 8), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	tween.tween_property(ripple, "color:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ripple.queue_free)


# --- Demo Tap + Debug ---


func _input(event: InputEvent) -> void:
	if HeartRateManager.source == "demo":
		var pos := Vector2.ZERO
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pos = event.position
		elif event is InputEventScreenTouch and event.pressed:
			pos = event.position
		if pos != Vector2.ZERO and not _is_tap_on_button():
			_spawn_ripple(pos)
			HeartRateManager.demo_tap()


func _is_tap_on_button() -> bool:
	var ctrl := get_viewport().gui_get_hovered_control()
	while ctrl:
		if ctrl is Button or ctrl is SpinBox:
			return true
		ctrl = ctrl.get_parent() as Control
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_M:
				GameState.add_mana(1000.0)
				_show_debug("+1K Mana")
			KEY_N:
				GameState.add_mana(1000000.0)
				_show_debug("+1M Mana")
			KEY_S:
				SurgeManager.cooldown_timer = 0.0
				_show_debug("Surge forced")
			KEY_P:
				GameState.add_mana(50000000.0)
				_show_debug("+50M Mana (prestige test)")
			KEY_V:
				GameState.add_vitality(5.0)
				_show_debug("+5 Vitality")
	if event is InputEventMouseButton and event.pressed:
		var delta := 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			delta = BPM_STEP
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			delta = -BPM_STEP
		if delta != 0.0:
			var current := GameState.get_simulated_bpm()
			var new_bpm := clampf(current + delta, BPM_MIN, BPM_MAX)
			HeartRateManager.set_simulated_bpm(new_bpm)
			_show_debug("SIM: %d BPM" % int(new_bpm))
			get_viewport().set_input_as_handled()


func _show_debug(msg: String) -> void:
	bpm_debug_label.text = msg
	bpm_debug_label.visible = true
	bpm_debug_label.modulate.a = 1.0
	if _bpm_label_tween and _bpm_label_tween.is_valid():
		_bpm_label_tween.kill()
	_bpm_label_tween = create_tween()
	_bpm_label_tween.tween_interval(2.0)
	_bpm_label_tween.tween_property(bpm_debug_label, "modulate:a", 0.0, 0.5)
	_bpm_label_tween.tween_callback(func(): bpm_debug_label.visible = false)
