class_name GrindMiniGame
extends BaseMiniGame

const BASE_GRIND_TARGET := 10.0
const CRANK_SPEED := 0.15

var grind_level: DrinkData.GrindLevel = DrinkData.GrindLevel.COARSE
var grind_progress := 0.0
var grind_target := BASE_GRIND_TARGET
var _last_mouse_angle := 0.0
var _total_rotation := 0.0
var _size_multiplier := 1.0

var _level_label: Label3D = null
var _bar_bg: CSGBox3D = null
var _bar_fill: CSGBox3D = null
const BAR_WIDTH := 0.2

func _ready() -> void:
	super._ready()
	station_name = "grinder"

	_level_label = Label3D.new()
	_level_label.text = "COARSE"
	_level_label.font_size = 24
	_level_label.position = Vector3(0, 0.15, 0.18)
	_level_label.pixel_size = 0.001
	_level_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_level_label)

	_bar_bg = CSGBox3D.new()
	_bar_bg.size = Vector3(BAR_WIDTH, 0.02, 0.02)
	_bar_bg.position = Vector3(0, 0.10, 0.18)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.2, 0.2, 0.2)
	_bar_bg.material = bg_mat
	_bar_bg.visible = false
	add_child(_bar_bg)

	_bar_fill = CSGBox3D.new()
	_bar_fill.size = Vector3(0.001, 0.02, 0.021)
	_bar_fill.position = Vector3(-BAR_WIDTH / 2.0, 0.10, 0.18)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.3, 0.8, 0.3)
	_bar_fill.material = fill_mat
	_bar_fill.visible = false
	add_child(_bar_fill)

func set_grind_level(level: DrinkData.GrindLevel) -> void:
	grind_level = level
	_update_label()

func toggle_grind_level() -> void:
	if grind_level == DrinkData.GrindLevel.COARSE:
		set_grind_level(DrinkData.GrindLevel.FINE)
	else:
		set_grind_level(DrinkData.GrindLevel.COARSE)

func set_size_multiplier(mult: float) -> void:
	_size_multiplier = mult
	grind_target = BASE_GRIND_TARGET * _size_multiplier

func _on_start() -> void:
	grind_progress = 0.0
	grind_target = BASE_GRIND_TARGET * _size_multiplier
	_last_mouse_angle = 0.0
	_total_rotation = 0.0
	_bar_bg.visible = true
	_bar_fill.visible = true
	_update_progress_bar()
	SoundManager.play_loop("grind_loop")

func _on_stop() -> void:
	SoundManager.stop_loop("grind_loop")
	_bar_bg.visible = false
	_bar_fill.visible = false

func _handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var angle := atan2(motion.relative.y, motion.relative.x)
		var delta_angle := angle - _last_mouse_angle
		while delta_angle > PI:
			delta_angle -= TAU
		while delta_angle < -PI:
			delta_angle += TAU
		_total_rotation += absf(delta_angle)
		_last_mouse_angle = angle

		grind_progress += absf(delta_angle) * CRANK_SPEED
		_update_label()
		_update_progress_bar()
		if grind_progress >= grind_target:
			grind_progress = grind_target
			_update_progress_bar()
			SoundManager.play("grind_complete")
			complete(1.0)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			toggle_grind_level()

func _update_mini_game(_delta: float) -> void:
	_update_label()

func _update_progress_bar() -> void:
	if not _bar_fill:
		return
	var ratio := get_grind_ratio()
	var fill_width := BAR_WIDTH * ratio
	_bar_fill.size.x = maxf(fill_width, 0.001)
	_bar_fill.position.x = -BAR_WIDTH / 2.0 + fill_width / 2.0
	var mat := _bar_fill.material as StandardMaterial3D
	if mat:
		mat.albedo_color = Color(0.3, 0.8, 0.3) if ratio < 1.0 else Color(0.2, 1.0, 0.4)

func _update_label() -> void:
	if _level_label:
		var level_str := "FINE" if grind_level == DrinkData.GrindLevel.FINE else "COARSE"
		var pct := get_grind_ratio() * 100
		if _active:
			_level_label.text = "%s  %.0f%%\nMove mouse to grind" % [level_str, pct]
		else:
			_level_label.text = level_str

func get_grind_ratio() -> float:
	if grind_target <= 0:
		return 1.0
	return clampf(grind_progress / grind_target, 0.0, 1.0)
