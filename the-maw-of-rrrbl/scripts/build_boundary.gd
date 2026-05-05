extends Node3D
class_name BuildBoundary

var _mesh_instance: MeshInstance3D
var _radius: float = 8.0

func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	set_radius(_radius)

func set_radius(radius: float) -> void:
	_radius = radius
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 64
	mesh.rings = 0

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.4, 0.2, 0.6, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.2, 0.6)
	mat.emission_energy_multiplier = 0.3
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat

	_mesh_instance.mesh = mesh

func get_radius() -> float:
	return _radius

func is_within_bounds(pos: Vector3) -> bool:
	var flat_pos: Vector2 = Vector2(pos.x, pos.z)
	return flat_pos.length() <= _radius
