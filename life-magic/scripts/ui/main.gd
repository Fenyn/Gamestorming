extends Control

@onready var notification_label: Label = %NotificationLabel
@onready var notification_panel: PanelContainer = %NotificationPanel
@onready var bpm_debug_label: Label = %BPMDebugLabel
@onready var garden_tab: Button = %GardenTab
@onready var plots_tab: Button = %PlotsTab
@onready var upgrades_tab: Button = %UpgradesTab
@onready var settings_tab: Button = %SettingsTab
@onready var generator_panel: ScrollContainer = %GeneratorPanel
@onready var plot_panel: ScrollContainer = %PlotPanel
@onready var upgrade_panel: ScrollContainer = %UpgradePanel
@onready var settings_panel: ScrollContainer = %SettingsPanel

var _notification_tween: Tween
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
	bpm_debug_label.visible = false

	_tabs = [garden_tab, plots_tab, upgrades_tab, settings_tab]
	_panels = [generator_panel, plot_panel, upgrade_panel, settings_panel]

	for i in _tabs.size():
		var idx := i
		_tabs[i].pressed.connect(func(): _switch_tab(idx))

	_switch_tab(0)


func _switch_tab(index: int) -> void:
	for i in _tabs.size():
		_tabs[i].button_pressed = (i == index)
		_panels[i].visible = (i == index)
		_style_tab(_tabs[i], i == index)


func _style_tab(btn: Button, active: bool) -> void:
	if active:
		var style := StyleBoxFlat.new()
		style.bg_color = ThemeBuilder.BG_TAB_ACTIVE
		style.border_color = ThemeBuilder.ACCENT_GREEN
		style.border_width_bottom = 3
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_color_override("font_color", ThemeBuilder.TEXT_PRIMARY)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = ThemeBuilder.BG_TAB_INACTIVE
		style.border_color = ThemeBuilder.BORDER
		style.border_width_bottom = 1
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_color_override("font_color", ThemeBuilder.TEXT_MUTED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_M:
				GameState.add_mana(1000.0)
				_show_debug("+1K Mana")
			KEY_N:
				GameState.add_mana(1000000.0)
				_show_debug("+1M Mana")
	if event is InputEventMouseButton and event.pressed:
		var delta := 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			delta = BPM_STEP
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			delta = -BPM_STEP
		if delta != 0.0:
			var current: float = GameState.settings.get("simulated_bpm", 80.0)
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


func _on_notification(message: String, _type: String) -> void:
	notification_label.text = message
	notification_panel.visible = true
	notification_panel.modulate.a = 1.0

	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()

	_notification_tween = create_tween()
	_notification_tween.tween_interval(5.0)
	_notification_tween.tween_property(notification_panel, "modulate:a", 0.0, 1.0)
	_notification_tween.tween_callback(func():
		notification_panel.visible = false
		notification_panel.modulate.a = 1.0
	)
