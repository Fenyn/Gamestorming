extends Node3D
class_name DreamerPortal

signal orb_spawned(orb: Orb)

enum PortalType {
	SHALLOW,
	DEEP,
	NIGHTMARE,
	GILT,
	VOID,
}

const PORTAL_CONFIG: Dictionary = {
	PortalType.SHALLOW: {
		"name": "Shallow Dreamer",
		"orb_color": Color(0.6, 0.85, 0.75),
		"spark_multiplier": 1.0,
		"spawn_interval": 3.0,
		"vm_cost": 0,
	},
	PortalType.DEEP: {
		"name": "Deep Dreamer",
		"orb_color": Color(0.3, 0.3, 0.5),
		"spark_multiplier": 1.0,
		"spawn_interval": 4.0,
		"vm_cost": 5,
	},
	PortalType.NIGHTMARE: {
		"name": "Nightmare Rift",
		"orb_color": Color(0.9, 0.85, 1.0, 0.6),
		"spark_multiplier": 1.5,
		"spawn_interval": 3.5,
		"vm_cost": 10,
	},
	PortalType.GILT: {
		"name": "Gilt Dreamer",
		"orb_color": Color(1.0, 0.85, 0.3),
		"spark_multiplier": 3.0,
		"spawn_interval": 8.0,
		"vm_cost": 15,
	},
	PortalType.VOID: {
		"name": "Void Rift",
		"orb_color": Color(0.1, 0.05, 0.15),
		"spark_multiplier": 2.0,
		"spawn_interval": 2.0,
		"vm_cost": 25,
	},
}

@export var portal_type: PortalType = PortalType.SHALLOW
@export var orb_scene: PackedScene

var connected: bool = false
var connection_point: Vector3 = Vector3.ZERO
var connection_direction: Vector3 = Vector3(0, 0, -1)

var _spawn_timer: float = 0.0
var _mesh: MeshInstance3D

func _ready() -> void:
	_build_visual()

func _process(delta: float) -> void:
	if _mesh:
		var spin_speed: float = 2.0 if connected else 0.5
		_mesh.rotate_y(delta * spin_speed)

	if not connected or orb_scene == null:
		return

	var config: Dictionary = PORTAL_CONFIG[portal_type]
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = config["spawn_interval"] as float
		_spawn_orb(config)

func connect_to_track() -> void:
	connected = true
	if _mesh and _mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 4.0
		mat.albedo_color.a = 1.0

func disconnect_from_track() -> void:
	connected = false

func get_config() -> Dictionary:
	return PORTAL_CONFIG[portal_type]

func get_connection_world_position() -> Vector3:
	return to_global(connection_point)

func get_connection_world_direction() -> Vector3:
	return (global_transform.basis * connection_direction).normalized()

func _spawn_orb(config: Dictionary) -> void:
	var orb: Orb = orb_scene.instantiate() as Orb
	orb.global_position = to_global(connection_point) + Vector3(0, 0.35, 0)
	orb.spark_multiplier = config["spark_multiplier"] as float
	get_tree().current_scene.add_child(orb)
	orb.set_orb_color(config["orb_color"] as Color)
	var push_dir: Vector3 = -global_transform.basis.z
	orb.apply_central_impulse(push_dir * 3.0)
	orb_spawned.emit(orb)

func _build_visual() -> void:
	var config: Dictionary = PORTAL_CONFIG[portal_type]
	var color: Color = config["orb_color"] as Color

	_mesh = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.45
	_mesh.mesh = torus
	_mesh.rotation.x = deg_to_rad(90)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	_mesh.material_override = mat
	add_child(_mesh)

	var beam: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.03
	cylinder.bottom_radius = 0.1
	cylinder.height = 4.0
	beam.mesh = cylinder
	beam.position.y = 2.0

	var beam_mat: StandardMaterial3D = StandardMaterial3D.new()
	beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.2)
	beam_mat.emission_enabled = true
	beam_mat.emission = color
	beam_mat.emission_energy_multiplier = 0.8
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = beam_mat
	add_child(beam)

	var label: Label3D = Label3D.new()
	label.text = config["name"] as String
	label.position = Vector3(0, 0.8, 0)
	label.font_size = 24
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
