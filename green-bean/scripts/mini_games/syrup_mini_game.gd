class_name SyrupMiniGame
extends BaseMiniGame

const FULL_PUMP_DURATION := 0.8
const MIN_PUMP_DURATION := 0.15
## A dosing pump's stroke.
const PUMP_PUSH_DISTANCE := 0.025

var target_pumps := 3.0
var current_pumps := 0.0
var _holding := false
var _hold_time := 0.0

## The station's pump head, pushed down while the button is held.
var _pump_stem: Node3D = null
var _pump_rest_y := 0.0
var _count_label: Label3D = null
var _bar_bg: CSGBox3D = null
var _bar_fill: CSGBox3D = null
const BAR_WIDTH := 0.18

func _ready() -> void:
	super._ready()
	station_name = "syrup"
	_build_visuals()

func _build_visuals() -> void:
	_count_label = Label3D.new()
	_count_label.text = ""
	_count_label.font_size = 18
	_count_label.pixel_size = 0.001
	_count_label.position = Vector3(0, 0.45, 0.06)
	_count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_count_label)

	_bar_bg = CSGBox3D.new()
	_bar_bg.size = Vector3(BAR_WIDTH, 0.015, 0.015)
	_bar_bg.position = Vector3(0, 0.42, 0.06)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.2, 0.2, 0.2)
	_bar_bg.material = bg_mat
	add_child(_bar_bg)

	_bar_fill = CSGBox3D.new()
	_bar_fill.size = Vector3(0.001, 0.015, 0.016)
	_bar_fill.position = Vector3(-BAR_WIDTH / 2.0, 0.42, 0.06)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.85, 0.75, 0.4)
	_bar_fill.material = fill_mat
	add_child(_bar_fill)

func _on_start() -> void:
	_holding = false
	_hold_time = 0.0
	_update_display()

func _on_stop() -> void:
	_holding = false
	_hold_time = 0.0
	if _pump_stem:
		_pump_stem.position.y = _pump_rest_y
	if target_pumps > 0.0:
		var diff := absf(current_pumps - target_pumps)
		_quality = clampf(1.0 - diff / target_pumps, 0.0, 1.0)
	else:
		_quality = 1.0
	mini_game_completed.emit(_quality)

func _handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_holding = true
			_hold_time = 0.0
		elif _holding:
			_register_pump()
			_holding = false
			_hold_time = 0.0

func _register_pump() -> void:
	if _hold_time < MIN_PUMP_DURATION:
		return
	var pump_amount := minf(_hold_time / FULL_PUMP_DURATION, 1.0)
	current_pumps += pump_amount
	SoundManager.play("syrup_pump")
	_update_display()

func _update_mini_game(delta: float) -> void:
	if _pump_stem == null:
		if _holding:
			_hold_time += delta
			_update_display()
		return
	if _holding:
		_hold_time += delta
		var ratio := clampf(_hold_time / FULL_PUMP_DURATION, 0.0, 1.0)
		_pump_stem.position.y = _pump_rest_y - (PUMP_PUSH_DISTANCE * ratio)
		_update_display()
	else:
		_pump_stem.position.y = lerpf(_pump_stem.position.y, _pump_rest_y, 0.25)

func _update_display() -> void:
	if not _count_label:
		return
	var target_int := int(target_pumps)
	if _holding:
		var in_progress := minf(_hold_time / FULL_PUMP_DURATION, 1.0)
		_count_label.text = "%.1f (+%.1f) / %d pumps\nHold click to pump" % [current_pumps, in_progress, target_int]
	else:
		_count_label.text = "%.1f / %d pumps\nHold click to pump" % [current_pumps, target_int]
	_update_bar()

func _update_bar() -> void:
	if not _bar_fill or target_pumps <= 0.0:
		return
	var ratio := clampf(current_pumps / target_pumps, 0.0, 1.5)
	var fill_width := BAR_WIDTH * minf(ratio, 1.0)
	_bar_fill.size.x = maxf(fill_width, 0.001)
	_bar_fill.position.x = -BAR_WIDTH / 2.0 + fill_width / 2.0
	var mat := _bar_fill.material as StandardMaterial3D
	if mat:
		if ratio < 0.9:
			mat.albedo_color = Color(0.85, 0.75, 0.4)
		elif ratio <= 1.1:
			mat.albedo_color = Color(0.3, 0.9, 0.3)
		else:
			mat.albedo_color = Color(0.9, 0.3, 0.3)

func set_target(pumps: float) -> void:
	target_pumps = pumps
	_update_display()

func set_current(pumps: float) -> void:
	current_pumps = pumps
	_update_display()

func set_pump(head: Node3D) -> void:
	_pump_stem = head
	_pump_rest_y = head.position.y

func set_bottle_color(color: Color) -> void:
	if _bar_fill:
		var mat := _bar_fill.material as StandardMaterial3D
		if mat and current_pumps / target_pumps < 0.9:
			mat.albedo_color = color
