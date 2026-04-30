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

var _progress_bar: ColorRect = null
var _progress_bg: ColorRect = null
var _level_label: Label3D = null

func _ready() -> void:
	super._ready()
	station_name = "grinder"

	_level_label = Label3D.new()
	_level_label.text = "COARSE"
	_level_label.font_size = 12
	_level_label.position = Vector3(0, 0.3, 0.01)
	_level_label.pixel_size = 0.002
	add_child(_level_label)

func set_grind_level(level: DrinkData.GrindLevel) -> void:
	grind_level = level
	if _level_label:
		_level_label.text = "FINE" if level == DrinkData.GrindLevel.FINE else "COARSE"

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
		if grind_progress >= grind_target:
			grind_progress = grind_target
			complete(1.0)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			toggle_grind_level()

func _update_mini_game(_delta: float) -> void:
	_update_label()

func _update_label() -> void:
	if _level_label:
		var level_str := "FINE" if grind_level == DrinkData.GrindLevel.FINE else "COARSE"
		var pct := get_grind_ratio() * 100
		if _active:
			_level_label.text = "%s  %.0f%%\nRClick:toggle  E:exit" % [level_str, pct]
		else:
			_level_label.text = level_str

func get_grind_ratio() -> float:
	if grind_target <= 0:
		return 1.0
	return clampf(grind_progress / grind_target, 0.0, 1.0)
