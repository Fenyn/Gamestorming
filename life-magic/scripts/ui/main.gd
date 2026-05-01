extends Control

@onready var notification_label: Label = %NotificationLabel
@onready var notification_panel: PanelContainer = %NotificationPanel
@onready var bpm_debug_label: Label = %BPMDebugLabel
@onready var garden_tab: Button = %GardenTab
@onready var plots_tab: Button = %PlotsTab
@onready var upgrades_tab: Button = %UpgradesTab
@onready var chronicle_tab: Button = %ChronicleTab
@onready var blessings_tab: Button = %BlessingsTab
@onready var settings_tab: Button = %SettingsTab
@onready var generator_panel: ScrollContainer = %GeneratorPanel
@onready var plot_panel: ScrollContainer = %PlotPanel
@onready var upgrade_panel: ScrollContainer = %UpgradePanel
@onready var milestone_panel: ScrollContainer = %MilestonePanel
@onready var blessing_panel: ScrollContainer = %BlessingPanel
@onready var settings_panel: ScrollContainer = %SettingsPanel

var _notification_tween: Tween
var _notification_is_tutorial: bool = false
var _bpm_label_tween: Tween
const BPM_STEP := 5.0
const BPM_MIN := 40.0
const BPM_MAX := 200.0

var _tabs: Array[Button] = []
var _panels: Array[Control] = []


func _ready() -> void:
	theme = ThemeBuilder.build()

	EventBus.notification.connect(_on_notification)
	notification_panel.visible = false
	notification_panel.gui_input.connect(_on_notification_input)
	bpm_debug_label.visible = false

	_tabs = [garden_tab, plots_tab, upgrades_tab, chronicle_tab, blessings_tab, settings_tab]
	_panels = [generator_panel, plot_panel, upgrade_panel, milestone_panel, blessing_panel, settings_panel]

	for i in _tabs.size():
		var idx := i
		_tabs[i].pressed.connect(func(): _switch_tab(idx))

	EventBus.milestone_earned.connect(_on_first_milestone)
	EventBus.loop_completed.connect(_on_first_prestige)

	if MilestoneManager.get_earned_count() > 0:
		chronicle_tab.visible = true
	if GameState.life_cycles > 0 or MilestoneManager.is_prestige_unlocked():
		blessings_tab.visible = true

	EventBus.milestone_earned.connect(_check_prestige_unlock)
	_switch_tab(0)


func _switch_tab(index: int) -> void:
	if not _tabs[index].visible:
		return
	for i in _tabs.size():
		var is_active := i == index
		_tabs[i].button_pressed = is_active
		_panels[i].visible = is_active
		_style_tab(_tabs[i], is_active)


func _style_tab(btn: Button, active: bool) -> void:
	var style := ThemeBuilder.create_tab_style(active)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", ThemeBuilder.TEXT_PRIMARY if active else ThemeBuilder.TEXT_MUTED)


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


func _on_notification_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_dismiss_notification()


func _dismiss_notification() -> void:
	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()
	notification_panel.visible = false
	notification_panel.modulate.a = 1.0
	_notification_is_tutorial = false


func _on_first_milestone(_milestone_id: String) -> void:
	if not chronicle_tab.visible:
		chronicle_tab.visible = true
		EventBus.notification.emit("The Chronicle of Power has been revealed!", "tutorial")


func _check_prestige_unlock(milestone_id: String) -> void:
	if milestone_id == "full_spectrum" and not blessings_tab.visible:
		blessings_tab.visible = true


func _on_first_prestige(_total_cycles: int) -> void:
	if not blessings_tab.visible:
		blessings_tab.visible = true


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
