extends ScrollContainer

@onready var row_container: VBoxContainer = %RowContainer

var _age_spin: SpinBox
var _cap_spin: SpinBox
var _stats_label: Label


func _ready() -> void:
	_build_ui()
	_update_stats()
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.05, 0.92))


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Player Profile"
	title.add_theme_font_size_override("font_size", 16)
	row_container.add_child(title)

	var desc := Label.new()
	desc.text = "These settings calibrate the heart rate system to your body."
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", ThemeBuilder.TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	row_container.add_child(desc)

	_add_separator()
	_build_how_it_works()
	_add_separator()

	_age_spin = _add_spin_row("Age", 10, 100, int(GameState.get_age()))
	_age_spin.value_changed.connect(func(val: float):
		GameState.settings["age"] = val
		_update_stats()
	)

	_add_separator()

	var cap_label := Label.new()
	cap_label.text = "HR Cap Override"
	cap_label.add_theme_font_size_override("font_size", 13)
	row_container.add_child(cap_label)

	var cap_desc := Label.new()
	cap_desc.text = "Maximum heart rate benefit as % of your estimated max. Higher = more reward from intense exercise, but the game won't encourage exceeding safe limits."
	cap_desc.add_theme_font_size_override("font_size", 10)
	cap_desc.add_theme_color_override("font_color", ThemeBuilder.TEXT_MUTED)
	cap_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	row_container.add_child(cap_desc)

	_cap_spin = _add_spin_row("Cap %", 70, 95, int(GameState.get_hr_cap_pct() * 100.0))
	_cap_spin.suffix = "%"
	_cap_spin.value_changed.connect(func(val: float):
		GameState.settings["hr_cap_pct"] = val / 100.0
		_update_stats()
	)

	_add_separator()

	var hr_source_label := Label.new()
	hr_source_label.text = "Heart Rate Source"
	hr_source_label.add_theme_font_size_override("font_size", 13)
	row_container.add_child(hr_source_label)

	var source_row := HBoxContainer.new()
	source_row.add_theme_constant_override("separation", 6)
	var _source_buttons: Array[Button] = []

	var sources := [
		{"id": "demo", "label": "Demo"},
		{"id": "simulated", "label": "Manual"},
		{"id": "websocket", "label": "Device"},
	]

	if HeartRateManager.is_health_connect_available():
		sources.append({"id": "health_connect", "label": "Health"})

	for src in sources:
		var btn := Button.new()
		btn.text = src["label"]
		btn.toggle_mode = true
		btn.button_pressed = HeartRateManager.source == src["id"]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_source_buttons.append(btn)
		source_row.add_child(btn)

		var src_id: String = src["id"]
		btn.pressed.connect(func():
			for b in _source_buttons:
				b.button_pressed = (b == btn)
			HeartRateManager.set_source(src_id)
		)

	row_container.add_child(source_row)

	var source_desc := Label.new()
	var desc_text := "Demo: simulated workout cycle. Manual: scroll wheel to set BPM. Device: connect a heart rate monitor via WebSocket."
	if HeartRateManager.is_health_connect_available():
		desc_text += " Health: reads your heart rate from Android Health Connect (Fitbit, Wear OS, etc.)."
	source_desc.text = desc_text
	source_desc.add_theme_font_size_override("font_size", 10)
	source_desc.add_theme_color_override("font_color", ThemeBuilder.TEXT_MUTED)
	source_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	row_container.add_child(source_desc)

	_add_separator()

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_color_override("font_color", ThemeBuilder.TEXT_GREEN)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	row_container.add_child(_stats_label)

	_add_separator()

	var reset_btn := Button.new()
	reset_btn.text = "Delete Save & Restart"
	reset_btn.custom_minimum_size.y = 40
	reset_btn.pressed.connect(_on_reset)
	row_container.add_child(reset_btn)


func _add_spin_row(label_text: String, min_val: int, max_val: int, initial: int) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)

	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = initial
	spin.step = 1
	spin.custom_minimum_size.x = 100
	row.add_child(spin)

	row_container.add_child(row)
	return spin


func _build_how_it_works() -> void:
	var header := Label.new()
	header.text = "How It Works"
	header.add_theme_font_size_override("font_size", 14)
	row_container.add_child(header)

	var lines := [
		"Your heartbeat fuels everything. Each beat of your heart produces resources.",
		"",
		"Higher heart rate = more beats per minute = faster resource flow. Your body is the engine.",
		"",
		"Spells form a chain. Heartmotes produce Mana directly. Higher spells (Pulse Glyphs, Familiars, etc.) produce the spell below them each beat, cascading down to Mana.",
		"",
		"Bought vs Bonus: The number you purchased plus bonus units conjured by higher spells. Both produce for you every heartbeat.",
		"",
		"Right-click a Buy button to cycle between x1, x10, x100, and Max.",
	]

	var body := Label.new()
	body.text = "\n".join(lines)
	body.add_theme_font_size_override("font_size", 10)
	body.add_theme_color_override("font_color", ThemeBuilder.TEXT_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	row_container.add_child(body)


func _add_separator() -> void:
	var sep := HSeparator.new()
	row_container.add_child(sep)


func _update_stats() -> void:
	var age := GameState.get_age()
	var cap_pct := GameState.get_hr_cap_pct()
	var max_hr := GameFormulas.max_heart_rate(age)
	var resting := GameFormulas.resting_heart_rate(age)
	var cap_bpm := max_hr * cap_pct

	_stats_label.text = "Estimated max HR: %d BPM\nEstimated resting HR: %d BPM\nBenefit cap: %d BPM (%.0f%%)\nSpeed range: 1.0x → 3.0x" % [
		int(max_hr), int(resting), int(cap_bpm), cap_pct * 100.0
	]


func _on_reset() -> void:
	SaveManager.delete_save()
	GameState.reset_to_defaults()
	get_tree().reload_current_scene()
