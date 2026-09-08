class_name Firewood
extends RigidBody3D
## A split wedge of firewood from the splitting block. Light, carryable,
## walk-through debris; the sell bin pays a premium over raw logs.

static var _mesh: PrismMesh = null


static func create(p_mass: float) -> Firewood:
	var wood: Firewood = Firewood.new()
	wood.name = "Firewood"
	wood.mass = maxf(p_mass, 0.5)

	if _mesh == null:
		_mesh = PrismMesh.new()
		_mesh.size = Vector3(0.16, 0.14, 0.38)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = ConiferMeshBuilder.CUT_WOOD_COLOR.darkened(0.1)
		mat.roughness = 1.0
		_mesh.material = mat
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = _mesh
	wood.add_child(mesh_instance)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.16, 0.14, 0.38)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	wood.add_child(collision)
	return wood


func _ready() -> void:
	add_to_group("carryable")
	# Debris layer: never snags the player's feet.
	collision_layer = 0b100
	collision_mask = 0b101
	angular_damp = 3.0
	linear_damp = 0.2
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = 1.0
	mat.bounce = 0.0
	physics_material_override = mat


## Long axis of the wedge; CarrySystem holds it lying along this.
func carry_axis() -> Vector3:
	return Vector3(0.0, 0.0, 1.0)


func receive_chop(_damage: float, point: Vector3, normal: Vector3) -> void:
	apply_impulse(-normal * 4.0, point - global_position)
