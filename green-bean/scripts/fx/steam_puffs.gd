class_name SteamPuffs
extends GPUParticles3D

## Soft rising steam. Call set_level() whenever the source gets hotter or colder.
## level 0 stops emitting. harsh = true is the scald look: faster, thicker, greyer.

var _process_mat: ParticleProcessMaterial = null
var _draw_mat: StandardMaterial3D = null
var _rise := 0.12
var _level := -1.0
var _harsh := false

func _init(base_amount: int = 24, puff_size: float = 0.05, rise: float = 0.12) -> void:
	_rise = rise
	amount = base_amount
	lifetime = 1.4
	local_coords = false
	emitting = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_process_mat = ParticleProcessMaterial.new()
	_process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_process_mat.emission_sphere_radius = puff_size * 0.3
	_process_mat.direction = Vector3.UP
	_process_mat.spread = 12.0
	_process_mat.gravity = Vector3(0, 0.04, 0)
	_process_mat.scale_min = 0.6
	_process_mat.scale_max = 1.0
	_process_mat.scale_curve = Fx.curve_texture([Vector2(0.0, 0.4), Vector2(1.0, 1.6)])
	_process_mat.color_ramp = Fx.alpha_ramp(Color(1, 1, 1), 0.45)
	_process_mat.angle_min = -180.0
	_process_mat.angle_max = 180.0
	_process_mat.angular_velocity_min = -40.0
	_process_mat.angular_velocity_max = 40.0
	_process_mat.turbulence_enabled = true
	_process_mat.turbulence_noise_strength = 0.6
	_process_mat.turbulence_noise_scale = 4.0
	process_material = _process_mat

	var quad := QuadMesh.new()
	quad.size = Vector2(puff_size, puff_size)
	_draw_mat = Fx.particle_material(Color(1, 1, 1, 1))
	quad.material = _draw_mat
	draw_pass_1 = quad

	set_level(0.0)

func set_level(level: float, harsh: bool = false) -> void:
	level = clampf(level, 0.0, 1.0)
	if is_equal_approx(level, _level) and harsh == _harsh:
		return
	_level = level
	_harsh = harsh
	emitting = level > 0.01
	amount_ratio = maxf(level, 0.01)
	var speed := _rise * (2.2 if harsh else 1.0)
	_process_mat.initial_velocity_min = speed * 0.6
	_process_mat.initial_velocity_max = speed
	_process_mat.spread = 30.0 if harsh else 12.0
	_process_mat.scale_max = 1.6 if harsh else 1.0
	_draw_mat.albedo_color = Color(0.88, 0.86, 0.84, 1.0) if harsh else Color(1, 1, 1, 0.8)
