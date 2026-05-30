class_name Checkpoint
extends Area3D

signal checkpoint_reached(index: int)

const COLOR_INACTIVE: Color = Color(0.3, 0.3, 0.5, 0.6)
const COLOR_ACTIVE: Color = Color(0.2, 0.8, 1.0, 0.9)
const COLOR_PASSED: Color = Color(0.15, 0.4, 0.15, 0.4)

var index: int = 0

@onready var _mesh: MeshInstance3D = %RingMesh
var _material: StandardMaterial3D
var _burst: GPUParticles3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_burst = _create_burst_particles()
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = COLOR_INACTIVE
	_material.emission_enabled = true
	_material.emission = COLOR_INACTIVE
	_material.emission_energy_multiplier = 1.0
	_mesh.material_override = _material


func set_active() -> void:
	_material.albedo_color = COLOR_ACTIVE
	_material.emission = COLOR_ACTIVE
	_material.emission_energy_multiplier = 2.5


func set_passed() -> void:
	_flash()
	_material.albedo_color = COLOR_PASSED
	_material.emission = COLOR_PASSED
	_material.emission_energy_multiplier = 0.5


func _flash() -> void:
	_material.albedo_color = Color.WHITE
	_material.emission = Color.WHITE
	_material.emission_energy_multiplier = 6.0
	_mesh.scale = Vector3.ONE * 1.3
	_burst.restart()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_mesh, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(_material, "emission_energy_multiplier", 0.5, 0.4)


func _create_burst_particles() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = 48
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.emitting = false
	particles.explosiveness = 1.0

	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 25.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.1
	mat.scale_max = 0.25
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 9.0
	mat.emission_ring_inner_radius = 7.0
	mat.emission_ring_height = 0.5

	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.3, 0.9, 1.0, 1.0))
	gradient.set_color(1, Color(0.1, 0.5, 1.0, 0.0))
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	particles.process_material = mat

	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.15, 0.15)
	var mesh_mat: StandardMaterial3D = StandardMaterial3D.new()
	mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.vertex_color_use_as_albedo = true
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mesh_mat
	particles.draw_pass_1 = mesh

	add_child(particles)
	return particles


func set_inactive() -> void:
	_material.albedo_color = COLOR_INACTIVE
	_material.emission = COLOR_INACTIVE
	_material.emission_energy_multiplier = 1.0


func _on_body_entered(body: Node3D) -> void:
	if body is Ship:
		checkpoint_reached.emit(index)
