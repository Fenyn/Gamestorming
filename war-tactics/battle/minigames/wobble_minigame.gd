class_name WobbleMinigame
extends BaseMinigame

@export var sway_speed: float = 2.5
@export var sway_strength: float = 30.0
@export var mouse_sensitivity: float = 1.0
@export var target_radius: float = 28.0
@export var drift_pull: float = 10.0
@export var burst_duration: float = 1.5
@export var shot_interval: float = 0.18
@export var shot_kick_strength: float = 50.0
@export var recoil_decay: float = 7.0
@export var accuracy_threshold: float = 0.4

var _dot_offset: Vector2 = Vector2.ZERO
var _recoil_velocity: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _burst_timer: float = 0.0
var _shot_timer: float = 0.0
var _shots_fired: int = 0
var _shots_on_target: int = 0
var _aim_area_center: Vector2 = Vector2.ZERO

@onready var _crosshair: ColorRect = %Crosshair
@onready var _target_zone: ColorRect = %TargetZone
@onready var _accuracy_bar_bg: ColorRect = %AccuracyBarBG
@onready var _accuracy_bar_fill: ColorRect = %AccuracyBarFill
@onready var _burst_bar_fill: ColorRect = %BurstBarFill


func _on_start() -> void:
	_dot_offset = Vector2.ZERO
	_recoil_velocity = Vector2.ZERO
	_time = 0.0
	_burst_timer = 0.0
	_shot_timer = 0.0
	_shots_fired = 0
	_shots_on_target = 0
	_aim_area_center = _target_zone.position + _target_zone.size / 2.0
	_accuracy_bar_fill.scale.x = 0.0
	_burst_bar_fill.scale.x = 1.0


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_burst_timer += delta

	var sway: Vector2 = Vector2(
		sin(_time * sway_speed) + sin(_time * sway_speed * 1.7) * 0.5,
		cos(_time * sway_speed * 0.9) + cos(_time * sway_speed * 2.1) * 0.4,
	) * sway_strength * delta
	_dot_offset += sway

	_dot_offset += _recoil_velocity * delta
	_recoil_velocity = _recoil_velocity.lerp(Vector2.ZERO, recoil_decay * delta)

	if _dot_offset.length() > 5.0:
		_dot_offset += _dot_offset.normalized() * drift_pull * delta

	var max_dist: float = 120.0
	if _dot_offset.length() > max_dist:
		_dot_offset = _dot_offset.normalized() * max_dist

	_crosshair.position = _aim_area_center + _dot_offset - _crosshair.size / 2.0

	_shot_timer += delta
	if _shot_timer >= shot_interval:
		_shot_timer -= shot_interval
		_fire_shot()

	var burst_ratio: float = clampf(_burst_timer / burst_duration, 0.0, 1.0)
	_burst_bar_fill.scale.x = 1.0 - burst_ratio

	if _burst_timer >= burst_duration:
		_resolve_burst()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if Engine.get_process_frames() == _start_frame:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_dot_offset += motion.relative * mouse_sensitivity
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _fire_shot() -> void:
	_shots_fired += 1
	var on_target: bool = _dot_offset.length() <= target_radius
	if on_target:
		_shots_on_target += 1
		_crosshair.color = Color(0.3, 1.0, 0.3, 1.0)
	else:
		_crosshair.color = Color(1.0, 0.3, 0.3, 1.0)

	var kick_dir: Vector2 = Vector2(
		randf_range(-0.5, 0.5),
		randf_range(-1.0, -0.3),
	).normalized()
	_recoil_velocity += kick_dir * shot_kick_strength

	if _shots_fired > 0:
		var acc: float = float(_shots_on_target) / float(_shots_fired)
		_accuracy_bar_fill.scale.x = acc
		if acc >= accuracy_threshold:
			_accuracy_bar_fill.color = Color(0.2, 0.8, 0.2, 1.0)
		else:
			_accuracy_bar_fill.color = Color(0.8, 0.6, 0.2, 1.0)


func _resolve_burst() -> void:
	var accuracy: float = float(_shots_on_target) / float(maxi(_shots_fired, 1))
	var hit: bool = accuracy >= accuracy_threshold
	_finish(hit)


func _evaluate_hit() -> bool:
	return false
