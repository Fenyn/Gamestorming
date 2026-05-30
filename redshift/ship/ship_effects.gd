class_name ShipEffects
extends Node3D

var _engine_particles: GPUParticles3D
var _afterburner_particles: GPUParticles3D
var _speed_lines: GPUParticles3D
var _rcs_left: GPUParticles3D
var _rcs_right: GPUParticles3D
var _rcs_top: GPUParticles3D
var _rcs_bottom: GPUParticles3D

var _ship: RigidBody3D


func _ready() -> void:
	_ship = get_parent() as RigidBody3D

	_engine_particles = _create_engine()
	_afterburner_particles = _create_afterburner()
	_speed_lines = _create_speed_lines()
	_rcs_left = _create_rcs(Vector3(-0.9, 0.0, 0.0))
	_rcs_right = _create_rcs(Vector3(0.9, 0.0, 0.0))
	_rcs_top = _create_rcs(Vector3(0.0, 0.5, 0.0))
	_rcs_bottom = _create_rcs(Vector3(0.0, -0.5, 0.0))


func update_effects(thrust_ratio: float, is_afterburning: bool, rcs_active: Vector3) -> void:
	_engine_particles.emitting = thrust_ratio > 0.05
	_engine_particles.amount_ratio = clampf(thrust_ratio, 0.1, 1.0)

	_afterburner_particles.emitting = is_afterburning
	if is_afterburning:
		_afterburner_particles.amount_ratio = 1.0

	var speed: float = _ship.linear_velocity.length() if _ship else 0.0
	var speed_ratio: float = clampf(speed / 100.0, 0.0, 1.0)
	_speed_lines.emitting = speed_ratio > 0.3
	_speed_lines.amount_ratio = speed_ratio

	_rcs_left.emitting = rcs_active.x < -0.1
	_rcs_right.emitting = rcs_active.x > 0.1
	_rcs_top.emitting = rcs_active.y > 0.1
	_rcs_bottom.emitting = rcs_active.y < -0.1


func _create_engine() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.position = Vector3(0.0, 0.0, 1.2)
	particles.amount = 64
	particles.lifetime = 0.4
	particles.emitting = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 1.0)
	mat.spread = 8.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 15.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.08
	mat.scale_max = 0.15
	mat.color = Color(1.0, 0.6, 0.2, 0.8)

	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.8, 0.3, 1.0))
	gradient.set_color(1, Color(1.0, 0.2, 0.05, 0.0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	particles.process_material = mat
	particles.draw_pass_1 = _quad_mesh()
	add_child(particles)
	return particles


func _create_afterburner() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.position = Vector3(0.0, 0.0, 1.2)
	particles.amount = 96
	particles.lifetime = 0.6
	particles.emitting = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 1.0)
	mat.spread = 5.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.12
	mat.scale_max = 0.25
	mat.color = Color(0.5, 0.7, 1.0, 0.9)

	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.6, 0.8, 1.0, 1.0))
	gradient.set_color(1, Color(0.2, 0.3, 1.0, 0.0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	particles.process_material = mat
	particles.draw_pass_1 = _quad_mesh()
	add_child(particles)
	return particles


func _create_speed_lines() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.position = Vector3(0.0, 0.0, -2.0)
	particles.amount = 40
	particles.lifetime = 0.3
	particles.emitting = false

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 1.0)
	mat.spread = 60.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.01
	mat.scale_max = 0.03
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(3.0, 2.0, 0.5)
	mat.color = Color(0.7, 0.8, 1.0, 0.4)

	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.8, 0.9, 1.0, 0.5))
	gradient.set_color(1, Color(0.8, 0.9, 1.0, 0.0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	particles.process_material = mat

	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.02, 0.3)
	var line_mat: StandardMaterial3D = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.vertex_color_use_as_albedo = true
	line_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = line_mat
	particles.draw_pass_1 = mesh

	add_child(particles)
	return particles


func _create_rcs(pos: Vector3) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.position = pos + Vector3(0.0, 0.0, 0.5)
	particles.amount = 16
	particles.lifetime = 0.15
	particles.emitting = false

	var dir: Vector3 = pos.normalized()
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = dir
	mat.spread = 25.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.03
	mat.scale_max = 0.06
	mat.color = Color(0.8, 0.9, 1.0, 0.6)

	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.9, 0.95, 1.0, 0.7))
	gradient.set_color(1, Color(0.7, 0.8, 1.0, 0.0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	particles.process_material = mat
	particles.draw_pass_1 = _quad_mesh()
	add_child(particles)
	return particles


func _quad_mesh() -> QuadMesh:
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mat
	return mesh
