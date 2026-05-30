class_name CockpitDisplay
extends Node3D

@onready var _speed_label: Label3D = %SpeedDisplay
@onready var _rot_label: Label3D = %RotDisplay
@onready var _timer_label: Label3D = %TimerDisplay
@onready var _checkpoint_label: Label3D = %CheckpointDisplay
@onready var _afterburner_label: Label3D = %AfterburnerDisplay
@onready var _rot_damp_light: MeshInstance3D = %RotDampLight
@onready var _trans_damp_light: MeshInstance3D = %TransDampLight

var _rot_damp_mat: StandardMaterial3D
var _trans_damp_mat: StandardMaterial3D


func _ready() -> void:
	_rot_damp_mat = _create_indicator_material(Color.GREEN)
	_rot_damp_light.material_override = _rot_damp_mat
	_trans_damp_mat = _create_indicator_material(Color.GREEN)
	_trans_damp_light.material_override = _trans_damp_mat

	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.angular_velocity_changed.connect(_on_angular_velocity_changed)
	EventBus.rotation_dampening_changed.connect(_on_rot_dampen_changed)
	EventBus.translation_dampening_changed.connect(_on_trans_dampen_changed)
	EventBus.race_time_updated.connect(_on_race_time_updated)
	EventBus.race_countdown_tick.connect(_on_countdown_tick)
	EventBus.race_started.connect(_on_race_started)
	EventBus.checkpoint_hit.connect(_on_checkpoint_hit)
	EventBus.afterburner_changed.connect(_on_afterburner_changed)


func _on_speed_changed(speed: float) -> void:
	_speed_label.text = "%5.1f" % speed


func _on_angular_velocity_changed(angular_vel: Vector3) -> void:
	var deg: float = rad_to_deg(angular_vel.length())
	_rot_label.text = "%4.1f" % deg


func _on_rot_dampen_changed(enabled: bool) -> void:
	var color: Color = Color.GREEN if enabled else Color.RED
	_rot_damp_mat.albedo_color = color
	_rot_damp_mat.emission = color


func _on_trans_dampen_changed(enabled: bool) -> void:
	var color: Color = Color.GREEN if enabled else Color.RED
	_trans_damp_mat.albedo_color = color
	_trans_damp_mat.emission = color


func _on_race_time_updated(time: float) -> void:
	_timer_label.text = _format_time(time)


func _on_countdown_tick(seconds_left: int) -> void:
	_timer_label.text = str(seconds_left)
	_checkpoint_label.text = "-- / --"


func _on_race_started() -> void:
	_timer_label.text = "0:00.00"


func _on_checkpoint_hit(index: int, total: int, _split_time: float) -> void:
	_checkpoint_label.text = "%d / %d" % [index + 1, total]


func _on_afterburner_changed(fuel: float, max_fuel: float, is_burning: bool) -> void:
	var bars: int = int(fuel / maxf(max_fuel, 0.01) * 10.0)
	var bar_text: String = "|".repeat(bars).rpad(10, ".")
	var color_hex: String = "ff8800" if is_burning else "44aaff"
	_afterburner_label.text = "[%s]" % bar_text
	_afterburner_label.modulate = Color(color_hex)


func _create_indicator_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	return mat


func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: float = fmod(seconds, 60.0)
	return "%d:%05.2f" % [mins, secs]
