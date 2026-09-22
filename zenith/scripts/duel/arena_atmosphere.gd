class_name ArenaAtmosphere
extends Node3D
## Decorative, public school identity only. Never reads decks or private cards.

var reduced_motion: bool = false
var _clock: float = 24.0
var _surface: ShaderMaterial
var _mist: ShaderMaterial
var _embers: Array[GPUParticles3D] = []
var _crystals: Array[StandardMaterial3D] = []
var _colors: Array[Color] = [Color(0.34, 0.74, 0.82), Color(0.62, 0.56, 0.96)]
var _sanctum: Node3D


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_sanctum = load("res://scripts/ui/sanctum_set.gd").new()
		_sanctum.set("menu_mode", false)
		_sanctum.position = Vector3(0, -0.8, -4)
		add_child(_sanctum)
	var inlay: MeshInstance3D = get_parent().get_node("Table/Inlay")
	_surface = inlay.material_override.duplicate() as ShaderMaterial
	_surface.set_shader_parameter("stone_texture", load("res://assets/materials/sanctum_stone.jpg"))
	inlay.material_override = _surface
	_mist = ShaderMaterial.new()
	_mist.shader = preload("res://assets/arena_mist.gdshader")
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(100, 100)
	_mesh(floor_mesh, _mist, Vector3(0, -0.65, 0))
	for seat in range(2):
		var side: float = 1.0 if seat == 0 else -1.0
		for x: float in [-5.75, 5.75]:
			_obelisk(Vector3(x, -0.5, side * 3.5), seat)
		_embers.append(_motes(Vector3(0, 0.4, side * 4.15), _colors[seat]))


func set_schools(first: Color, second: Color) -> void:
	if _colors[0].is_equal_approx(first) and _colors[1].is_equal_approx(second):
		return
	_colors = [first, second]
	if _sanctum != null:
		_sanctum.set("_school", first.lerp(second, 0.5))
	for material: ShaderMaterial in [_surface, _mist]:
		material.set_shader_parameter("seat_zero", first)
		material.set_shader_parameter("seat_one", second)
	for i in range(_crystals.size()):
		var tint: Color = _colors[i / 2]
		_crystals[i].albedo_color = tint
		_crystals[i].emission = tint
	for i in range(_embers.size()):
		EffectBlocks.tint(_embers[i], _colors[i].lightened(0.2))


func _process(delta: float) -> void:
	if not reduced_motion:
		_clock += delta
	_surface.set_shader_parameter("clock", _clock)
	_mist.set_shader_parameter("clock", _clock)
	for particles: GPUParticles3D in _embers:
		particles.visible = not reduced_motion
		particles.emitting = not reduced_motion


func _mesh(shape: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _obelisk(at: Vector3, seat: int) -> void:
	var stone: StandardMaterial3D = StandardMaterial3D.new()
	stone.albedo_color = Color(0.10, 0.15, 0.18)
	stone.roughness = 0.85
	var foot: CylinderMesh = CylinderMesh.new()
	foot.top_radius = 0.29
	foot.bottom_radius = 0.43
	foot.height = 0.24
	foot.radial_segments = 6
	_mesh(foot, stone, at)
	var shaft: CylinderMesh = CylinderMesh.new()
	shaft.top_radius = 0.16
	shaft.bottom_radius = 0.26
	shaft.height = 0.7
	shaft.radial_segments = 6
	_mesh(shaft, stone, at + Vector3.UP * 0.44)
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = Color(0.34, 0.25, 0.12)
	metal.metallic = 0.7
	metal.roughness = 0.45
	var collar: TorusMesh = TorusMesh.new()
	collar.inner_radius = 0.16
	collar.outer_radius = 0.23
	collar.rings = 12
	collar.ring_segments = 6
	_mesh(collar, metal, at + Vector3.UP * 0.76)
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = _colors[seat]
	glow.emission_enabled = true
	glow.emission = _colors[seat]
	glow.emission_energy_multiplier = 1.6
	_crystals.append(glow)
	var crystal: PrismMesh = PrismMesh.new()
	crystal.size = Vector3(0.20, 0.46, 0.20)
	var gem: MeshInstance3D = _mesh(crystal, glow, at + Vector3.UP * 1.02)
	gem.rotation.y = PI * 0.25


func _motes(at: Vector3, tint: Color) -> GPUParticles3D:
	var particles: GPUParticles3D = EffectBlocks.make("other/fireflies") as GPUParticles3D
	particles.name = "EffectBlocksSeatMotes"
	particles.amount = 24
	particles.position = at
	var material: ParticleProcessMaterial = particles.process_material
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(5.8, 0.25, 0.6)
	material.initial_velocity_min = 0.04
	material.initial_velocity_max = 0.12
	material.scale_min = 0.008
	material.scale_max = 0.016
	EffectBlocks.tint(particles, tint.lightened(0.2))
	add_child(particles)
	return particles
