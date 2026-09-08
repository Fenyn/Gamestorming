@tool
class_name GroundCover
extends Node3D
## Scatters pebbles over the ground as a MultiMesh with per-instance
## color and scale variation. Placement is deterministic from
## cover_seed and skips the road band and the circular clearings
## (pond, cabin, yard). Tool script: regenerates live in the editor on
## any export change.

@export var cover_seed: int = 3:
	set(value):
		cover_seed = value
		_request_regenerate()
@export_range(0, 600) var rock_count: int = 110:
	set(value):
		rock_count = value
		_request_regenerate()
@export var area_half_extents: Vector2 = Vector2(52.0, 52.0):
	set(value):
		area_half_extents = value
		_request_regenerate()
## Kept clear of cover (the road corridor), world Z.
@export var road_z_range: Vector2 = Vector2(26.0, 33.0):
	set(value):
		road_z_range = value
		_request_regenerate()
## Circular cover-free zones: x/y = XZ position, z = radius.
@export var clearings: Array[Vector3] = []:
	set(value):
		clearings = value
		_request_regenerate()

static var _rock_mesh: SphereMesh = null

var _rock_instance: MultiMeshInstance3D = null


func _ready() -> void:
	generate()


func generate() -> void:
	if is_instance_valid(_rock_instance):
		_rock_instance.queue_free()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = cover_seed

	_rock_instance = MultiMeshInstance3D.new()
	_rock_instance.name = "Rocks"
	_rock_instance.multimesh = _scatter(
		rng, _get_rock_mesh(), rock_count,
		Color(0.42, 0.41, 0.39), Color(0.55, 0.53, 0.49),
		Vector2(0.4, 1.4), 0.5
	)
	add_child(_rock_instance)


## Builds one scattered MultiMesh; instances vary in yaw, scale, and a
## color lerped between color_a and color_b. squash flattens Y so
## pebbles sit low.
func _scatter(
	rng: RandomNumberGenerator, mesh: Mesh, count: int,
	color_a: Color, color_b: Color, scale_range: Vector2, squash: float
) -> MultiMesh:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	var transforms: Array[Transform3D] = []
	var attempts: int = count * 6
	while transforms.size() < count and attempts > 0:
		attempts -= 1
		var pos: Vector2 = Vector2(
			rng.randf_range(-area_half_extents.x, area_half_extents.x),
			rng.randf_range(-area_half_extents.y, area_half_extents.y)
		)
		if pos.y > road_z_range.x and pos.y < road_z_range.y:
			continue
		if _in_clearing(pos):
			continue
		var s: float = rng.randf_range(scale_range.x, scale_range.y)
		var basis: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
			.scaled(Vector3(s, lerpf(s, 1.0, squash * rng.randf()), s))
		transforms.append(Transform3D(basis, Vector3(pos.x, 0.0, pos.y)))
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, color_a.lerp(color_b, rng.randf()))
	return multimesh


func _in_clearing(pos: Vector2) -> bool:
	for clearing in clearings:
		if pos.distance_to(Vector2(clearing.x, clearing.y)) < clearing.z:
			return true
	return false


static func _get_rock_mesh() -> SphereMesh:
	if _rock_mesh != null:
		return _rock_mesh
	_rock_mesh = SphereMesh.new()
	_rock_mesh.radius = 0.16
	_rock_mesh.height = 0.2
	_rock_mesh.radial_segments = 7
	_rock_mesh.rings = 4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	_rock_mesh.material = mat
	return _rock_mesh


func _request_regenerate() -> void:
	if is_node_ready():
		generate()
