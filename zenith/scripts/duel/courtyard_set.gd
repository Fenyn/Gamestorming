class_name CourtyardSet
extends Node3D
## The duel's ruined courtyard: a flagstone dais in a walled yard gone to moss, broken columns and
## rubble, grass and trees beyond the walls, under an overcast sky, with leaves drifting and a few
## shafts of light. Every texture and model is library art (assets/courtyard/SOURCES.md); the set
## only places and lights it. Decorative: it never reads the game.

const DIR: String = "res://assets/courtyard"
## Where the duel table's top sits, and its footprint.
const TABLE_TOP: float = 0.0
const TABLE_SIZE: Vector2 = Vector2(13.0, 8.2)
const TABLE_TINT: Color = Color(0.55, 0.52, 0.48)
## The yard's floor, a step below the dais.
const YARD_Y: float = -0.62
## Light shafts: pale warm daylight, faint.
const RAY_TINT: Color = Color(1.0, 0.95, 0.82)
const RAY_ALPHA: float = 0.065
## The set sits darker than the lit table so the play area holds the eye.
const SET_DIM: float = 0.65
## The enclosure, pulled in close enough that the camera sees its walls and columns.
const WALL_X: float = 11.5
const WALL_BACK_Z: float = -10.5
const WALL_FRONT_Z: float = 6.0

var reduced_motion: bool = false
var _leaves: Array[GPUParticles3D] = []
var _rays: Array[Node3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7351
	_build_ground()
	_build_walls()
	_build_columns()
	_scatter_nature()
	_build_air()


## Sets the duel's sky, light and fog to an overcast afternoon. The duel scene owns its
## WorldEnvironment and sun; the set only tunes them.
func apply_environment(env: Environment, sun: DirectionalLight3D) -> void:
	var sky_material: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
	sky_material.panorama = load(DIR + "/sky_overcast.png")
	sky_material.energy_multiplier = 0.9
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.25
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.62, 0.63, 0.62)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# Linear, so unshaded card faces show exactly the colours they are authored in.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	# Depth fog begins past the far table edge (about 11.9 m from the camera): only the yard recedes.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 13.0
	env.fog_depth_end = 45.0
	env.fog_depth_curve = 1.5
	env.fog_light_color = Color(0.42, 0.43, 0.41)
	env.fog_light_energy = 0.85
	env.fog_sky_affect = 0.25
	if sun != null:
		sun.light_color = Color(1.0, 0.97, 0.92)
		sun.light_energy = 0.55
		sun.shadow_enabled = true
		sun.rotation_degrees = Vector3(-52.0, 32.0, 0.0)


## The stone dais the board is printed on, top and sides: large grey slabs.
static func table_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = stone_material("dais", Vector3.ONE * 0.25, true)
	m.albedo_color = TABLE_TINT
	return m


func _build_ground() -> void:
	# A plinth one step below the table, the yard's flagstones around it, and grass beyond.
	var plinth: StandardMaterial3D = stone_material("brick", Vector3.ONE * 0.8, true)
	plinth.albedo_color = Color(0.7, 0.68, 0.64) * SET_DIM
	_box(Vector3(TABLE_SIZE.x + 1.2, 0.5, TABLE_SIZE.y + 1.2), Vector3(0, YARD_Y + 0.25, 0), plinth)
	var yard: StandardMaterial3D = stone_material("flagstone", Vector3(9.0, 9.0, 1.0))
	yard.albedo_color = Color(0.72, 0.72, 0.68) * SET_DIM
	_plane(Vector2(30, 26), Vector3(0, YARD_Y, -2), yard)
	var grass: StandardMaterial3D = stone_material("grass", Vector3(40.0, 40.0, 1.0))
	grass.albedo_color = Color(0.62, 0.66, 0.55) * SET_DIM
	_plane(Vector2(160, 160), Vector3(0, YARD_Y - 0.02, 0), grass)
	# Worn earth where the flagstones have broken up.
	var dirt: StandardMaterial3D = stone_material("dirt", Vector3(3.0, 3.0, 1.0))
	for spot: Vector3 in [Vector3(-9.5, 0, -7.5), Vector3(9.8, 0, -2.5), Vector3(-10.0, 0, 2.5), Vector3(7.5, 0, -9.0)]:
		_plane(Vector2(_rng.randf_range(3.0, 5.0), _rng.randf_range(2.5, 4.0)), Vector3(spot.x, YARD_Y + 0.005, spot.z), dirt)


func _build_walls() -> void:
	# Three sides of a broken enclosure: behind the far seat and down both flanks. Each run is
	# stones of varying height with gaps where it has fallen.
	var wall: StandardMaterial3D = stone_material("wall", Vector3.ONE * 0.55, true)
	var coping: StandardMaterial3D = stone_material("brick", Vector3.ONE * 0.9, true)
	coping.albedo_color = Color(0.66, 0.64, 0.6) * SET_DIM
	_wall_run(Vector3(-WALL_X, 0, WALL_BACK_Z), Vector3(WALL_X, 0, WALL_BACK_Z), wall, coping)
	_wall_run(Vector3(-WALL_X, 0, WALL_BACK_Z), Vector3(-WALL_X, 0, WALL_FRONT_Z), wall, coping)
	_wall_run(Vector3(WALL_X, 0, WALL_BACK_Z), Vector3(WALL_X, 0, WALL_FRONT_Z), wall, coping)


func _wall_run(from: Vector3, to: Vector3, wall: Material, coping: Material) -> void:
	var length: float = from.distance_to(to)
	var along: Vector3 = (to - from).normalized()
	var angle: float = atan2(along.x, along.z)
	var step: float = 2.4
	var count: int = int(length / step)
	for i in range(count):
		if _rng.randf() < 0.18:
			continue   # a breach
		var height: float = _rng.randf_range(1.2, 4.2)
		var at: Vector3 = from + along * (float(i) + 0.5) * step
		var block: MeshInstance3D = _box(Vector3(0.9, height, step + 0.05), Vector3(at.x, YARD_Y + height * 0.5, at.z), wall)
		block.rotation.y = angle
		if height > 2.6 and _rng.randf() < 0.6:
			var cap: MeshInstance3D = _box(Vector3(1.1, 0.22, step * _rng.randf_range(0.5, 1.0)), Vector3(at.x, YARD_Y + height + 0.11, at.z), coping)
			cap.rotation.y = angle
		if _rng.randf() < 0.35:
			# A fallen block at the foot of the wall.
			var fallen: MeshInstance3D = _box(Vector3(0.8, 0.5, 1.1), at + Vector3(_rng.randf_range(-1.2, 1.2), YARD_Y + 0.25, _rng.randf_range(-1.2, 1.2)), wall)
			fallen.rotation = Vector3(0, _rng.randf() * TAU, _rng.randf_range(-0.2, 0.2))


func _build_columns() -> void:
	# The yard's old colonnade: a few columns still standing, one broken short, one fallen.
	var stone: StandardMaterial3D = stone_material("brick", Vector3.ONE * 0.7, true)
	stone.albedo_color = Color(0.74, 0.72, 0.68) * SET_DIM
	var spots: Array[Vector3] = [Vector3(-8.2, 0, -7.6), Vector3(8.2, 0, -7.6), Vector3(-8.2, 0, -1.8), Vector3(8.2, 0, -1.8), Vector3(-8.2, 0, 3.6)]
	var heights: Array[float] = [5.2, 2.1, 4.4, 5.6, 1.4]
	for i in range(spots.size()):
		var h: float = heights[i]
		var base: MeshInstance3D = _box(Vector3(1.4, 0.4, 1.4), Vector3(spots[i].x, YARD_Y + 0.2, spots[i].z), stone)
		base.rotation.y = 0.0
		var shaft: CylinderMesh = CylinderMesh.new()
		shaft.top_radius = 0.42
		shaft.bottom_radius = 0.5
		shaft.height = h
		shaft.radial_segments = 10
		_mesh(shaft, Vector3(spots[i].x, YARD_Y + 0.4 + h * 0.5, spots[i].z), stone)
	var fallen: CylinderMesh = CylinderMesh.new()
	fallen.top_radius = 0.42
	fallen.bottom_radius = 0.48
	fallen.height = 4.2
	fallen.radial_segments = 10
	var log_node: MeshInstance3D = _mesh(fallen, Vector3(9.4, YARD_Y + 0.45, -4.6), stone)
	log_node.rotation = Vector3(0.0, 0.4, PI * 0.5)


func _scatter_nature() -> void:
	# Rubble and growth along the walls, trees past them. PSX Nature models, varied by scale and turn.
	var along_walls: Array[Vector3] = []
	for x in range(-10, 11, 3):
		along_walls.append(Vector3(x + _rng.randf_range(-1.0, 1.0), 0, WALL_BACK_Z + 1.1 + _rng.randf_range(-0.4, 0.4)))
	for z in range(-9, 6, 3):
		along_walls.append(Vector3(-WALL_X + 1.0 + _rng.randf_range(-0.3, 0.3), 0, z + _rng.randf_range(-1.0, 1.0)))
		along_walls.append(Vector3(WALL_X - 1.0 + _rng.randf_range(-0.3, 0.3), 0, z + _rng.randf_range(-1.0, 1.0)))
	var growth: Array[String] = ["fern_1", "fern_2", "grass_2", "grass_3", "grass_2", "fern_1"]
	for spot in along_walls:
		_model(growth[_rng.randi_range(0, growth.size() - 1)], Vector3(spot.x, YARD_Y, spot.z), _rng.randf_range(0.9, 1.6))
		if _rng.randf() < 0.45:
			_model(["stone_1", "stone_3"][_rng.randi_range(0, 1)], Vector3(spot.x + _rng.randf_range(-1, 1), YARD_Y, spot.z + _rng.randf_range(-1, 1)), _rng.randf_range(0.25, 0.55))
	_model("tree_stump_1", Vector3(-9.8, YARD_Y, -5.0), 1.2)
	_model("tree_log_1", Vector3(9.9, YARD_Y, 2.0), 1.1)
	# Trees stay behind the far wall and well out on the flanks, so no canopy hangs over the camera.
	for spot: Vector3 in [Vector3(-16, 0, -17), Vector3(-6, 0, -19), Vector3(4, 0, -20), Vector3(14, 0, -17), Vector3(21, 0, -10), Vector3(-21, 0, -9)]:
		_model(["tree_1", "tree_5"][_rng.randi_range(0, 1)], Vector3(spot.x, YARD_Y, spot.z), _rng.randf_range(1.8, 2.4))


func _build_air() -> void:
	# Leaves blowing across the yard, and two shafts of light where the cloud thins.
	for spot: Vector3 in [Vector3(-6, 5, -6), Vector3(6, 5, -3)]:
		var leaves: GPUParticles3D = EffectBlocks.make("other/falling_leaves") as GPUParticles3D
		leaves.name = "EffectBlocksCourtyardLeaves"
		leaves.position = spot
		leaves.amount = 18
		var material: ParticleProcessMaterial = leaves.process_material
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		material.emission_box_extents = Vector3(9, 1, 6)
		material.initial_velocity_min = 0.4
		material.initial_velocity_max = 1.0
		material.gravity = Vector3(0.6, -0.9, 0.3)
		add_child(leaves)
		_leaves.append(leaves)
	for spot: Vector3 in [Vector3(-6.5, 3.5, -8.5), Vector3(7.0, 3.5, -6.5)]:
		var rays: Node3D = EffectBlocks.make("other/god_rays")
		rays.name = "EffectBlocksCourtyardRays"
		rays.position = spot
		rays.scale = Vector3.ONE * 2.2
		_soften_rays(rays)
		add_child(rays)
		_rays.append(rays)


## The pack's rays are a saturated teal at full strength; here they are thin, pale daylight.
func _soften_rays(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node
		# The pack sets it as a per-surface override, so read whichever material is in use.
		var source: Material = mesh_node.get_active_material(0) if mesh_node.mesh != null else null
		if source is ShaderMaterial:
			var material: ShaderMaterial = (source as ShaderMaterial).duplicate()
			material.set_shader_parameter("tint_color", RAY_TINT)
			material.set_shader_parameter("alpha_factor", RAY_ALPHA)
			mesh_node.material_override = material
	for child in node.get_children():
		_soften_rays(child)


func _process(_delta: float) -> void:
	for leaves: GPUParticles3D in _leaves:
		leaves.visible = not reduced_motion
		leaves.emitting = not reduced_motion
	for rays: Node3D in _rays:
		EffectBlocks.motion(rays, not reduced_motion)


# --- Building blocks --------------------------------------------------------

## A lit, textured material from one of the courtyard textures and its normal map. `triplanar`
## wraps boxes and cylinders without stretching; `scale` repeats the texture.
static func stone_material(role: String, scale: Vector3, triplanar: bool = false) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = load("%s/textures/%s.png" % [DIR, role])
	m.normal_enabled = true
	m.normal_texture = load("%s/textures/%s_normal.png" % [DIR, role])
	m.roughness = 0.92
	m.albedo_color = Color(SET_DIM, SET_DIM, SET_DIM)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = scale
	m.uv1_triplanar = triplanar
	return m


func _box(size_value: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size_value
	return _mesh(shape, at, material)


func _plane(size_value: Vector2, at: Vector3, material: Material) -> MeshInstance3D:
	var shape: PlaneMesh = PlaneMesh.new()
	shape.size = size_value
	var node: MeshInstance3D = _mesh(shape, at, material)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _mesh(shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = shape
	node.position = at
	node.material_override = material
	add_child(node)
	return node


func _model(name_value: String, at: Vector3, scale_value: float) -> void:
	var path: String = "%s/models/%s.glb" % [DIR, name_value]
	if not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path)
	var node: Node3D = scene.instantiate()
	node.position = at
	node.scale = Vector3.ONE * scale_value
	node.rotation.y = _rng.randf() * TAU
	add_child(node)
