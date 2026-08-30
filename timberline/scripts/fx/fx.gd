class_name Fx
extends RefCounted
## One-shot particle bursts for gameplay juice, built in code and freed
## via the GPUParticles3D finished signal. Bursts are parented to the
## current scene so they outlive whatever spawned them. Draw meshes are
## cached statics shared across bursts.

const CHIP_COLOR: Color = Color(0.6, 0.45, 0.28)
const DUST_COLOR: Color = Color(0.55, 0.5, 0.42, 0.45)
const NEEDLE_COLOR: Color = Color(0.2, 0.34, 0.22)

static var _chip_mesh: BoxMesh = null
static var _dust_mesh: QuadMesh = null
static var _needle_mesh: BoxMesh = null


## Axe bite: wood chips flying off along the surface normal.
static func wood_chips(anchor: Node, global_pos: Vector3, normal: Vector3) -> void:
	_burst(anchor, global_pos, _get_chip_mesh(), 14, 0.6,
		normal, 2.6, 35.0, Vector3(0.0, -9.8, 0.0), 0.05, 0.0)


## Soft ground dust, e.g. a trunk slamming down.
static func dust_puff(anchor: Node, global_pos: Vector3, radius: float = 0.5) -> void:
	_burst(anchor, global_pos, _get_dust_mesh(), 12, 1.0,
		Vector3.UP, 0.9, 75.0, Vector3(0.0, -0.6, 0.0), radius, 2.5)


## Needles and twig bits shaken out of foliage.
static func needle_burst(anchor: Node, global_pos: Vector3, radius: float = 0.6) -> void:
	_burst(anchor, global_pos, _get_needle_mesh(), 18, 0.8,
		Vector3.UP, 1.6, 65.0, Vector3(0.0, -6.0, 0.0), radius, 0.5)


static func _burst(anchor: Node, global_pos: Vector3, mesh: Mesh, amount: int,
		lifetime: float, dir: Vector3, speed: float, spread_deg: float,
		gravity: Vector3, radius: float, damping: float) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var parent: Node = anchor.get_tree().current_scene
	if parent == null:
		return

	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = dir.normalized() if dir != Vector3.ZERO else Vector3.UP
	pm.spread = spread_deg
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed
	pm.gravity = gravity
	pm.damping_min = damping
	pm.damping_max = damping
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(radius, 0.01)

	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.process_material = pm
	particles.draw_pass_1 = mesh
	parent.add_child(particles)
	particles.global_position = global_pos
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


static func _get_chip_mesh() -> BoxMesh:
	if _chip_mesh == null:
		_chip_mesh = BoxMesh.new()
		_chip_mesh.size = Vector3(0.07, 0.02, 0.035)
		_chip_mesh.material = _flat_material(CHIP_COLOR, false)
	return _chip_mesh


static func _get_dust_mesh() -> QuadMesh:
	if _dust_mesh == null:
		_dust_mesh = QuadMesh.new()
		_dust_mesh.size = Vector2(0.35, 0.35)
		_dust_mesh.material = _flat_material(DUST_COLOR, true)
	return _dust_mesh


static func _get_needle_mesh() -> BoxMesh:
	if _needle_mesh == null:
		_needle_mesh = BoxMesh.new()
		_needle_mesh.size = Vector3(0.02, 0.1, 0.02)
		_needle_mesh.material = _flat_material(NEEDLE_COLOR, false)
	return _needle_mesh


static func _flat_material(color: Color, billboard: bool) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
