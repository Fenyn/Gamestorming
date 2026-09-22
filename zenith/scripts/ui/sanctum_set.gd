class_name SanctumSet
extends Node3D
## A real Godot environment: textured stone, architectural meshes, light and particles.

@export var menu_mode: bool = true
var _portal: Node3D
var _camera: Camera3D
var _clock: float = 0.0
var _dust: GPUParticles3D
var _flames: Array[Node3D] = []
var _last_school: Color = Color.TRANSPARENT
var _school: Color = Color(0.24, 0.70, 0.68)
var _pointer: Vector2 = Vector2.ZERO


func _ready() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var settings: Environment = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.008, 0.014, 0.028)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.30, 0.46, 0.62)
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.glow_enabled = true
	settings.glow_intensity = 0.8
	settings.fog_enabled = true
	settings.fog_light_color = Color(0.055, 0.10, 0.16)
	settings.fog_density = 0.008
	env.environment = settings
	if menu_mode:
		add_child(env)
	else:
		env.free()
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 4.8, 12.5)
	_camera.fov = 58
	if menu_mode:
		add_child(_camera)
		_camera.current = true
		_camera.look_at(Vector3(0, 2.3, -5))
	else:
		_camera.free()
		_camera = null
	var stone: StandardMaterial3D = StandardMaterial3D.new()
	stone.albedo_texture = load("res://assets/materials/sanctum_rock.png")
	stone.normal_enabled = true
	stone.normal_texture = load("res://assets/materials/sanctum_rock_normal.png")
	stone.albedo_color = Color(0.36, 0.43, 0.49)
	stone.roughness = 0.86
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3.ONE * 0.45
	var floor_material: StandardMaterial3D = stone.duplicate()
	floor_material.albedo_texture = load("res://assets/materials/sanctum_stone.jpg")
	floor_material.normal_texture = load("res://assets/materials/sanctum_stone_normal.jpg")
	floor_material.albedo_color = Color(0.25, 0.35, 0.43)
	floor_material.uv1_scale = Vector3.ONE * 0.18
	var bronze: StandardMaterial3D = StandardMaterial3D.new()
	bronze.albedo_color = Color(0.40, 0.27, 0.11)
	bronze.metallic = 0.7
	bronze.roughness = 0.42
	_box(Vector3(32, 0.3, 42), Vector3(0, -0.2, -4), floor_material)
	for z: float in [-11.0, -5.0, 1.0, 7.0]:
		for x: float in [-7.2, 7.2]:
			_box(Vector3(1.65, 0.35, 1.65), Vector3(x, 0.16, z), stone)
			var shaft: CylinderMesh = CylinderMesh.new()
			shaft.top_radius = 0.43
			shaft.bottom_radius = 0.65
			shaft.height = 8.0
			shaft.radial_segments = 8
			_mesh(shaft, Vector3(x, 4.2, z), stone)
			for y: float in [0.7, 6.8, 7.9]:
				_box(Vector3(1.25, 0.18, 1.25), Vector3(x, y, z), bronze)
			_box(Vector3(1.6, 0.4, 1.6), Vector3(x, 8.2, z), stone)
	for i in range(4):
		_box(Vector3(9.0 - i * 0.65, 0.25, 4.0 - i * 0.55), Vector3(0, i * 0.25, -9.0), stone)
	for radius: float in [2.7, 3.0, 5.0, 5.12]:
		var circle: TorusMesh = TorusMesh.new()
		circle.inner_radius = radius
		circle.outer_radius = radius + 0.028
		circle.rings = 80
		circle.ring_segments = 6
		_mesh(circle, Vector3(0, 0.01, -0.5), bronze)
	var arch: TorusMesh = TorusMesh.new()
	arch.inner_radius = 2.35
	arch.outer_radius = 2.68
	arch.rings = 64
	arch.ring_segments = 8
	var gate: MeshInstance3D = _mesh(arch, Vector3(0, 3.4, -9.3), stone)
	gate.rotation.x = PI * 0.5
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 2.33
	rim.outer_radius = 2.38
	rim.rings = 64
	_mesh(rim, Vector3(0, 3.4, -9.12), bronze).rotation.x = PI * 0.5
	_portal = EffectBlocks.make("other/portal_magic")
	_portal.name = "EffectBlocksPortal"
	_portal.position = Vector3(0, 3.4, -9.05)
	_portal.scale = Vector3.ONE * 2.3
	add_child(_portal)
	_light(Vector3(0, 4, -6), Color(0.23, 0.76, 0.77), 8.0, 14)
	for side: float in [-1.0, 1.0]:
		_light(Vector3(side * 5.5, 3, 2), Color(1.0, 0.52, 0.18), 4.0, 10)
		_box(Vector3(0.65, 1.5, 0.65), Vector3(side * 5.5, 0.75, 2), stone)
		_flame(Vector3(side * 5.5, 1.55, 2))
	_dust = EffectBlocks.make("other/dust") as GPUParticles3D
	_dust.name = "EffectBlocksHallDust"
	_dust.amount = 56
	_dust.position = Vector3(0, 3, 0)
	var dust_material: ParticleProcessMaterial = _dust.process_material
	dust_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_material.emission_box_extents = Vector3(8, 3.5, 9)
	dust_material.initial_velocity_min = 0.08
	dust_material.initial_velocity_max = 0.2
	dust_material.color = Color(0.6, 0.56, 0.48, 0.3)
	add_child(_dust)


func _process(delta: float) -> void:
	var reduced: bool = ArcaneBackdrop.motion_reduced()
	EffectBlocks.motion(_dust, not reduced)
	EffectBlocks.motion(_portal, not reduced)
	for flame: Node3D in _flames:
		EffectBlocks.motion(flame, not reduced)
	if not reduced:
		_clock += delta
	if not _school.is_equal_approx(_last_school):
		EffectBlocks.tint(_portal, _school)
		_last_school = _school
	if menu_mode:
		var target: float = 0.0 if reduced else _pointer.x * 0.24
		_camera.position.x = lerpf(_camera.position.x, target, 1.0 - exp(-delta * 2.0))


func _mesh(shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = material
	add_child(mesh)
	return mesh


func _flame(at: Vector3) -> void:
	var fire: Node3D = EffectBlocks.make("fire/fire_light")
	fire.name = "EffectBlocksBrazier"
	fire.position = at
	fire.scale = Vector3.ONE * 0.65
	add_child(fire)
	_flames.append(fire)


func _box(size_value: Vector3, at: Vector3, material: Material) -> void:
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size_value
	_mesh(shape, at, material)


func _light(at: Vector3, tint: Color, energy: float, reach: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = at
	light.light_color = tint
	light.light_energy = energy
	light.omni_range = reach
	add_child(light)
