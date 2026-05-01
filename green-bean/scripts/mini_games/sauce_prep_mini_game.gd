class_name SaucePrepMiniGame
extends BaseMiniGame

enum PrepMode { STIR_MIX, SLEEVE_FILL }

const MIX_TARGET := 8.0
const MIN_MOTION := 3.0
const ANGLE_SCALE := 0.5
const FILL_RATE := 0.35
const BAR_WIDTH := 0.2

var prep_mode := PrepMode.STIR_MIX
var _mix_progress := 0.0
var _fill_progress := 0.0
var _prev_angle := 0.0
var _has_prev := false
var _holding := false

var _bar_bg: CSGBox3D = null
var _bar_fill: CSGBox3D = null
var _liquid_visual: CSGCylinder3D = null
var _status_label: Label3D = null
var _sauce_color := Color(0.25, 0.15, 0.08)
var _powder_color := Color(0.45, 0.3, 0.15)

func _ready() -> void:
	super._ready()
	station_name = "sauce_prep"

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 16
	_status_label.pixel_size = 0.001
	_status_label.position = Vector3(0, 0.28, 0.15)
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_status_label)

	_bar_bg = _make_bar(Vector3(0, 0.22, 0.15), Color(0.2, 0.2, 0.2))
	_bar_fill = _make_bar(Vector3(-BAR_WIDTH / 2.0, 0.22, 0.15), _sauce_color)

	_liquid_visual = CSGCylinder3D.new()
	_liquid_visual.radius = 0.06
	_liquid_visual.height = 0.04
	_liquid_visual.position = Vector3(0, 0.1, 0)
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = _powder_color
	_liquid_visual.material = lmat
	add_child(_liquid_visual)

func _make_bar(pos: Vector3, color: Color) -> CSGBox3D:
	var bar := CSGBox3D.new()
	bar.size = Vector3(BAR_WIDTH if pos.x == 0 else 0.001, 0.012, 0.012 if pos.x == 0 else 0.013)
	bar.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bar.material = mat
	add_child(bar)
	return bar

func _on_start() -> void:
	_mix_progress = 0.0
	_fill_progress = 0.0
	_prev_angle = 0.0
	_has_prev = false
	_holding = false
	SoundManager.play_loop("sauce_prep_loop")

func _on_stop() -> void:
	_holding = false
	SoundManager.stop_loop("sauce_prep_loop")

func _handle_input(event: InputEvent) -> void:
	match prep_mode:
		PrepMode.STIR_MIX:
			_handle_stir_input(event)
		PrepMode.SLEEVE_FILL:
			_handle_fill_input(event)

func _handle_stir_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var motion := event as InputEventMouseMotion
	if motion.relative.length() < MIN_MOTION:
		return
	var angle := atan2(motion.relative.y, motion.relative.x)
	if _has_prev:
		var delta := angle - _prev_angle
		while delta > PI: delta -= TAU
		while delta < -PI: delta += TAU
		_mix_progress += absf(delta) * ANGLE_SCALE / TAU
	_prev_angle = angle
	_has_prev = true

func _handle_fill_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_holding = event.pressed

func _update_mini_game(delta: float) -> void:
	match prep_mode:
		PrepMode.STIR_MIX:
			_update_stir(delta)
		PrepMode.SLEEVE_FILL:
			_update_fill(delta)

func _update_stir(_delta: float) -> void:
	var ratio := clampf(_mix_progress / MIX_TARGET, 0.0, 1.0)
	_fill_bar(_bar_fill, ratio)
	if _liquid_visual:
		var mat := _liquid_visual.material as StandardMaterial3D
		if mat:
			mat.albedo_color = _powder_color.lerp(_sauce_color, ratio)
	if _status_label:
		_status_label.text = "Mixing powder... %.0f%%\nMove mouse in circles" % (ratio * 100)
	if ratio >= 1.0:
		SoundManager.play("sauce_batch_done")
		complete(1.0)

func _update_fill(delta: float) -> void:
	if _holding:
		_fill_progress += FILL_RATE * delta
	var ratio := clampf(_fill_progress, 0.0, 1.0)
	_fill_bar(_bar_fill, ratio)
	if _liquid_visual:
		var mat := _liquid_visual.material as StandardMaterial3D
		if mat:
			mat.albedo_color = _sauce_color
		_liquid_visual.height = 0.01 + 0.05 * ratio
		_liquid_visual.position.y = 0.08 + 0.025 * ratio
	if _status_label:
		if _holding:
			_status_label.text = "Filling... %.0f%%\nHold click to squeeze" % (ratio * 100)
		else:
			_status_label.text = "%.0f%%\nHold click to squeeze sleeve" % (ratio * 100)
	if ratio >= 1.0:
		SoundManager.play("sauce_batch_done")
		complete(1.0)

func _fill_bar(bar: CSGBox3D, ratio: float) -> void:
	if not bar:
		return
	var w := BAR_WIDTH * ratio
	bar.size.x = maxf(w, 0.001)
	bar.position.x = -BAR_WIDTH / 2.0 + w / 2.0

func set_sauce_color(color: Color) -> void:
	_sauce_color = color
	_powder_color = color.lightened(0.4)
