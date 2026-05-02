@tool
extends MeshInstance3D

@export_group("Terrain Shape")
@export var terrain_scale: float = 0.015:
	set(v):
		terrain_scale = v
		_sync_shader()
@export var terrain_height: float = 25.0:
	set(v):
		terrain_height = v
		_sync_shader()
@export var ridge_sharpness: float = 1.2:
	set(v):
		ridge_sharpness = v
		_sync_shader()
@export var octaves: int = 5:
	set(v):
		octaves = v
		_sync_shader()
@export var lacunarity: float = 2.2:
	set(v):
		lacunarity = v
		_sync_shader()
@export var persistence: float = 0.45:
	set(v):
		persistence = v
		_sync_shader()
@export var offset: Vector2 = Vector2.ZERO:
	set(v):
		offset = v
		_sync_shader()

@export_group("Flat Zone")
@export var flat_radius: float = 30.0:
	set(v):
		flat_radius = v
		_sync_shader()
@export var flat_falloff: float = 15.0:
	set(v):
		flat_falloff = v
		_sync_shader()
@export var flat_center: Vector2 = Vector2.ZERO:
	set(v):
		flat_center = v
		_sync_shader()

@export_group("Colors")
@export var color_low: Color = Color(0.12, 0.08, 0.06):
	set(v):
		color_low = v
		_sync_shader()
@export var color_mid: Color = Color(0.28, 0.2, 0.14):
	set(v):
		color_mid = v
		_sync_shader()
@export var color_high: Color = Color(0.45, 0.35, 0.25):
	set(v):
		color_high = v
		_sync_shader()
@export var color_peak: Color = Color(0.55, 0.45, 0.35):
	set(v):
		color_peak = v
		_sync_shader()
@export var roughness_val: float = 0.92:
	set(v):
		roughness_val = v
		_sync_shader()

@export_group("Collision")
@export var collision_resolution: int = 128

var _collision_body: StaticBody3D = null


func _ready() -> void:
	_sync_shader()
	if not Engine.is_editor_hint():
		_generate_collision()


func _sync_shader() -> void:
	var mat: ShaderMaterial = get_surface_override_material(0) as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("terrain_scale", terrain_scale)
	mat.set_shader_parameter("terrain_height", terrain_height)
	mat.set_shader_parameter("ridge_sharpness", ridge_sharpness)
	mat.set_shader_parameter("octaves", octaves)
	mat.set_shader_parameter("lacunarity", lacunarity)
	mat.set_shader_parameter("persistence", persistence)
	mat.set_shader_parameter("offset", offset)
	mat.set_shader_parameter("flat_radius", flat_radius)
	mat.set_shader_parameter("flat_falloff", flat_falloff)
	mat.set_shader_parameter("flat_center", flat_center)
	mat.set_shader_parameter("color_low", Vector3(color_low.r, color_low.g, color_low.b))
	mat.set_shader_parameter("color_mid", Vector3(color_mid.r, color_mid.g, color_mid.b))
	mat.set_shader_parameter("color_high", Vector3(color_high.r, color_high.g, color_high.b))
	mat.set_shader_parameter("color_peak", Vector3(color_peak.r, color_peak.g, color_peak.b))
	mat.set_shader_parameter("roughness_val", roughness_val)


func _hash2(p: Vector2) -> Vector2:
	var x: float = sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453123
	var y: float = sin(p.dot(Vector2(269.5, 183.3))) * 43758.5453123
	return Vector2((x - floorf(x)) * 2.0 - 1.0, (y - floorf(y)) * 2.0 - 1.0)


func _gradient_noise(p: Vector2) -> float:
	var i: Vector2 = Vector2(floorf(p.x), floorf(p.y))
	var f: Vector2 = Vector2(p.x - floorf(p.x), p.y - floorf(p.y))
	var u: Vector2 = f * f * (Vector2(3.0, 3.0) - 2.0 * f)

	var d00: float = _hash2(i).dot(f)
	var d10: float = _hash2(i + Vector2(1, 0)).dot(f - Vector2(1, 0))
	var d01: float = _hash2(i + Vector2(0, 1)).dot(f - Vector2(0, 1))
	var d11: float = _hash2(i + Vector2(1, 1)).dot(f - Vector2(1, 1))

	return lerpf(lerpf(d00, d10, u.x), lerpf(d01, d11, u.x), u.y)


func _ridged_noise(p: Vector2) -> float:
	var n: float = _gradient_noise(p)
	n = absf(n)
	n = 1.0 - n
	n = pow(n, ridge_sharpness)
	return n


func _fbm_ridged(p: Vector2) -> float:
	var value: float = 0.0
	var amplitude: float = 0.5
	var frequency: float = 1.0
	for i in range(octaves):
		value += _ridged_noise(p * frequency) * amplitude
		frequency *= lacunarity
		amplitude *= persistence
	return value


func _get_height(world_xz: Vector2) -> float:
	var p: Vector2 = (world_xz + offset) * terrain_scale
	var h: float = _fbm_ridged(p)
	var broad: float = _gradient_noise(p * 0.3) * 0.5 + 0.5
	h = lerpf(h, h * broad, 0.4)
	h *= terrain_height
	var dist: float = (world_xz - flat_center).length()
	var flatten: float = _smoothstepf(flat_radius - flat_falloff, flat_radius, dist)
	return h * flatten


func _smoothstepf(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _generate_collision() -> void:
	var plane_mesh: PlaneMesh = mesh as PlaneMesh
	if plane_mesh == null:
		return

	var size_x: float = plane_mesh.size.x
	var size_z: float = plane_mesh.size.y
	var res: int = collision_resolution
	var step_x: float = size_x / float(res)
	var step_z: float = size_z / float(res)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var world_origin: Vector3 = global_position

	for z in range(res):
		for x in range(res):
			var x0: float = -size_x * 0.5 + float(x) * step_x
			var z0: float = -size_z * 0.5 + float(z) * step_z
			var x1: float = x0 + step_x
			var z1: float = z0 + step_z

			var h00: float = _get_height(Vector2(world_origin.x + x0, world_origin.z + z0))
			var h10: float = _get_height(Vector2(world_origin.x + x1, world_origin.z + z0))
			var h01: float = _get_height(Vector2(world_origin.x + x0, world_origin.z + z1))
			var h11: float = _get_height(Vector2(world_origin.x + x1, world_origin.z + z1))

			var v00 := Vector3(x0, h00, z0)
			var v10 := Vector3(x1, h10, z0)
			var v01 := Vector3(x0, h01, z1)
			var v11 := Vector3(x1, h11, z1)

			st.add_vertex(v00)
			st.add_vertex(v10)
			st.add_vertex(v11)

			st.add_vertex(v00)
			st.add_vertex(v11)
			st.add_vertex(v01)

	var collision_mesh: ArrayMesh = st.commit()

	_collision_body = StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision_mesh.get_faces())
	var col_shape := CollisionShape3D.new()
	col_shape.shape = shape
	_collision_body.add_child(col_shape)
	add_child(_collision_body)
