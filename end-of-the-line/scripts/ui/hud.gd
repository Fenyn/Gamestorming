extends CanvasLayer

var _gold_label: Label
var _timer_label: Label
var _day_label: Label
var _income_label: Label
var _tickets_label: Label
var _notification_label: Label

var _displayed_gold: float = 0.0
var _gold_per_second: float = 0.0
var _last_gold_sample: float = 0.0
var _sample_timer: float = 0.0

const GOLD_LERP_SPEED: float = 10.0


func _ready() -> void:
	_build_ui()
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.delivery_completed.connect(_on_delivery)
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.tickets_changed.connect(_on_tickets_changed)
	EventBus.notification.connect(_show_notification)
	EventBus.purchase_failed.connect(_show_error)


func _process(delta: float) -> void:
	_update_timer()
	_update_gold_lerp(delta)
	_update_income_tracking(delta)


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var top_left: VBoxContainer = VBoxContainer.new()
	top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_child(top_left)

	_day_label = Label.new()
	_day_label.text = "Day 1"
	_day_label.add_theme_font_size_override("font_size", 32)
	top_left.add_child(_day_label)

	_timer_label = Label.new()
	_timer_label.text = "5:00"
	_timer_label.add_theme_font_size_override("font_size", 28)
	_timer_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	top_left.add_child(_timer_label)

	_gold_label = Label.new()
	_gold_label.text = "Gold: 0"
	_gold_label.add_theme_font_size_override("font_size", 28)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	top_left.add_child(_gold_label)

	_income_label = Label.new()
	_income_label.text = "+0/s"
	_income_label.add_theme_font_size_override("font_size", 20)
	_income_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	top_left.add_child(_income_label)

	_tickets_label = Label.new()
	_tickets_label.text = "Tickets: 0"
	_tickets_label.add_theme_font_size_override("font_size", 22)
	_tickets_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	top_left.add_child(_tickets_label)

	_notification_label = Label.new()
	_notification_label.add_theme_font_size_override("font_size", 22)
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notification_label.position.y = 20.0
	_notification_label.visible = false
	add_child(_notification_label)


func _update_timer() -> void:
	var time: float = GameState.loop_time_remaining
	var minutes: int = int(time) / 60
	var seconds: int = int(time) % 60
	_timer_label.text = "%d:%02d" % [minutes, seconds]

	if time < 30.0:
		_timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	elif time < 60.0:
		_timer_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	else:
		_timer_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))


func _update_gold_lerp(delta: float) -> void:
	if not is_equal_approx(_displayed_gold, GameState.gold):
		_displayed_gold = lerpf(_displayed_gold, GameState.gold, GOLD_LERP_SPEED * delta)
		if absf(_displayed_gold - GameState.gold) < 0.5:
			_displayed_gold = GameState.gold
		_gold_label.text = "Gold: %s" % GameFormulas.format_gold(_displayed_gold)


func _update_income_tracking(delta: float) -> void:
	_sample_timer += delta
	if _sample_timer >= 2.0:
		_gold_per_second = (GameState.total_gold_this_loop - _last_gold_sample) / _sample_timer
		_last_gold_sample = GameState.total_gold_this_loop
		_sample_timer = 0.0
		_income_label.text = "+%s/s" % GameFormulas.format_gold(_gold_per_second)


func _on_gold_changed(_amount: float) -> void:
	pass


func _on_delivery(_gold_earned: float) -> void:
	_gold_label.modulate = Color(1.3, 1.3, 1.0)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_gold_label, "modulate", Color.WHITE, 0.4)


func _on_day_changed(day: int) -> void:
	_day_label.text = "Day %d" % day


func _on_tickets_changed(amount: int) -> void:
	_tickets_label.text = "Tickets: %d" % amount


func _show_notification(message: String) -> void:
	_notification_label.text = message
	_notification_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
	_notification_label.visible = true
	var tween: Tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_notification_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: _notification_label.visible = false)


func _show_error(message: String) -> void:
	_notification_label.text = message
	_notification_label.modulate = Color(1.0, 0.4, 0.3, 1.0)
	_notification_label.visible = true
	var tween: Tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_notification_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: _notification_label.visible = false)
