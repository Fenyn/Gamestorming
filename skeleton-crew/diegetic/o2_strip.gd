class_name O2Strip
extends MeshInstance3D

var _material: StandardMaterial3D
var _o2_level: float = 1.0
var _pulse_time: float = 0.0

const COLOR_SAFE: Color = Color(0.4, 0.6, 0.9)
const COLOR_WARNING: Color = Color(0.9, 0.7, 0.1)
const COLOR_DANGER: Color = Color(0.9, 0.15, 0.1)
const COLOR_CRITICAL: Color = Color(0.6, 0.05, 0.05)
const COLOR_DEAD: Color = Color(0.05, 0.05, 0.05)


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.emission_enabled = true
	_material.emission = COLOR_SAFE
	_material.emission_energy_multiplier = 1.5
	_material.albedo_color = Color(0.1, 0.1, 0.1)
	material_override = _material


func _process(delta: float) -> void:
	_pulse_time += delta
	var emission_strength: float = _get_emission_strength()
	_material.emission_energy_multiplier = emission_strength


func set_o2_level(level: float) -> void:
	_o2_level = clampf(level, 0.0, 1.0)
	_material.emission = _get_color_for_level(_o2_level)


func _get_color_for_level(level: float) -> Color:
	if level <= 0.0:
		return COLOR_DEAD
	elif level < 0.1:
		return COLOR_CRITICAL
	elif level < 0.4:
		return COLOR_DANGER
	elif level < 0.7:
		return COLOR_WARNING
	else:
		return COLOR_SAFE


func _get_emission_strength() -> float:
	if _o2_level >= 0.7:
		return 1.5
	elif _o2_level >= 0.4:
		var pulse: float = (sin(_pulse_time * 2.0) + 1.0) * 0.5
		return lerpf(1.0, 2.0, pulse)
	elif _o2_level >= 0.1:
		var pulse: float = (sin(_pulse_time * 4.0) + 1.0) * 0.5
		return lerpf(0.5, 2.5, pulse)
	elif _o2_level > 0.0:
		var pulse: float = (sin(_pulse_time * 8.0) + 1.0) * 0.5
		return lerpf(0.2, 3.0, pulse)
	else:
		return 0.0
