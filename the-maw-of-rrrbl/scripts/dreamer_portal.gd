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

const UPGRADE_DEFS: Dictionary = {
	"flow":     { "base": 10, "scale": 1.8, "max": 5 },
	"yield":    { "base": 10, "scale": 1.8, "max": 5 },
	"burst":    { "base": 25, "scale": 2.2, "max": 3 },
	"momentum": { "base": 10, "scale": 1.8, "max": 5 },
	"mass":     { "base": 15, "scale": 2.0, "max": 4 },
	"bounce":   { "base": 20, "scale": 2.5, "max": 3 },
	"gravity":  { "base": 12, "scale": 1.8, "max": 4 },
	"scatter":  { "base": 18, "scale": 2.0, "max": 3 },
	"magnet":   { "base": 20, "scale": 2.0, "max": 3 },
	"lucky":    { "base": 15, "scale": 2.0, "max": 4 },
}

@export var portal_type: PortalType = PortalType.SHALLOW
@export var orb_scene: PackedScene

var connected: bool = false
var connection_point: Vector3 = Vector3.ZERO
var connection_direction: Vector3 = Vector3(0, 0, -1)

var flow_level: int = 0
var yield_level: int = 0
var burst_level: int = 0
var momentum_level: int = 0
var mass_level: int = 0
var bounce_level: int = 0
var gravity_level: int = 0
var scatter_level: int = 0
var magnet_level: int = 0
var lucky_level: int = 0

var _spawn_timer: float = 0.0
var _mesh: MeshInstance3D
var _label: Label3D

func _ready() -> void:
	_build_visual()

func _process(delta: float) -> void:
	if _mesh:
		var spin_speed: float = 2.0 if connected else 0.5
		_mesh.rotate_y(delta * spin_speed)

	if not connected or orb_scene == null:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = get_spawn_interval()
		_spawn_orb()

func connect_to_track() -> void:
	connected = true
	if _mesh and _mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 4.0
		mat.albedo_color.a = 1.0
	_refresh_label()

func disconnect_from_track() -> void:
	connected = false

func get_config() -> Dictionary:
	return PORTAL_CONFIG[portal_type]

func get_connection_world_position() -> Vector3:
	return to_global(connection_point)

func get_connection_world_direction() -> Vector3:
	return (global_transform.basis * connection_direction).normalized()

# --- Upgrade costs & levels ---

func get_stat_level(stat: String) -> int:
	match stat:
		"flow": return flow_level
		"yield": return yield_level
		"burst": return burst_level
		"momentum": return momentum_level
		"mass": return mass_level
		"bounce": return bounce_level
		"gravity": return gravity_level
		"scatter": return scatter_level
		"magnet": return magnet_level
		"lucky": return lucky_level
	return 0

func get_stat_max(stat: String) -> int:
	var def: Dictionary = UPGRADE_DEFS.get(stat, {})
	return def.get("max", 0) as int

func get_upgrade_cost(stat: String) -> int:
	var def: Dictionary = UPGRADE_DEFS.get(stat, {})
	if def.is_empty():
		return -1
	var level: int = get_stat_level(stat)
	if level >= (def["max"] as int):
		return -1
	return int((def["base"] as int) * pow(def["scale"] as float, level))

func apply_upgrade(stat: String) -> bool:
	var def: Dictionary = UPGRADE_DEFS.get(stat, {})
	if def.is_empty():
		return false
	var level: int = get_stat_level(stat)
	if level >= (def["max"] as int):
		return false
	match stat:
		"flow": flow_level += 1
		"yield": yield_level += 1
		"burst": burst_level += 1
		"momentum": momentum_level += 1
		"mass": mass_level += 1
		"bounce": bounce_level += 1
		"gravity": gravity_level += 1
		"scatter": scatter_level += 1
		"magnet": magnet_level += 1
		"lucky": lucky_level += 1
	_refresh_visual()
	return true

# --- Computed values ---

func get_spawn_interval() -> float:
	var base: float = (PORTAL_CONFIG[portal_type]["spawn_interval"] as float)
	return base * pow(0.78, flow_level)

func get_orb_multiplier() -> float:
	var base: float = (PORTAL_CONFIG[portal_type]["spark_multiplier"] as float)
	return base * (1.0 + yield_level * 0.5)

func get_burst_count() -> int:
	return 1 + burst_level

func get_orb_impulse() -> float:
	return 3.0 + momentum_level * 1.5

func get_orb_mass() -> float:
	return 0.5 + mass_level * 0.4

func get_orb_bounce() -> float:
	return bounce_level * 0.3

func get_orb_gravity_scale() -> float:
	return 1.0 + gravity_level * 0.5

func get_scatter_angle() -> float:
	return scatter_level * 12.0

func get_magnet_strength() -> float:
	return magnet_level * 1.5

func get_lucky_chance() -> float:
	return lucky_level * 0.08

func get_total_level() -> int:
	return (flow_level + yield_level + burst_level + momentum_level
		+ mass_level + bounce_level + gravity_level
		+ scatter_level + magnet_level + lucky_level)

# --- Spawning ---

func _spawn_orb() -> void:
	var count: int = get_burst_count()
	for i: int in count:
		_spawn_single_orb(i, count)

func _spawn_single_orb(index: int, total: int) -> void:
	var config: Dictionary = PORTAL_CONFIG[portal_type]
	var orb: Orb = orb_scene.instantiate() as Orb

	var spread: float = 0.0
	if total > 1:
		spread = (index - (total - 1) / 2.0) * 0.15
	var spawn_offset: Vector3 = global_transform.basis.x * spread
	orb.global_position = to_global(connection_point) + Vector3(0, 0.35, 0) + spawn_offset

	orb.spark_multiplier = get_orb_multiplier()
	orb.mass = get_orb_mass()
	orb.gravity_scale = get_orb_gravity_scale()
	orb.maw_pull = get_magnet_strength()

	if get_orb_bounce() > 0.0:
		var phys_mat: PhysicsMaterial = PhysicsMaterial.new()
		phys_mat.bounce = get_orb_bounce()
		orb.physics_material_override = phys_mat

	var is_golden: bool = get_lucky_chance() > 0.0 and randf() < get_lucky_chance()

	get_tree().current_scene.add_child(orb)

	if is_golden:
		orb.apply_golden()
	else:
		orb.set_orb_color(config["orb_color"] as Color)

	orb.apply_mass_visual()

	var push_dir: Vector3 = -global_transform.basis.z
	var scatter_deg: float = get_scatter_angle()
	if scatter_deg > 0.0:
		var angle_offset: float = deg_to_rad(randf_range(-scatter_deg, scatter_deg))
		push_dir = push_dir.rotated(Vector3.UP, angle_offset)
	orb.apply_central_impulse(push_dir * get_orb_impulse())

	orb_spawned.emit(orb)

# --- Visuals ---

func _refresh_visual() -> void:
	var total: int = get_total_level()
	if _mesh and _mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 2.5 + total * 0.5
	_refresh_label()

func _refresh_label() -> void:
	if _label == null:
		return
	var config: Dictionary = PORTAL_CONFIG[portal_type]
	var base_name: String = config["name"] as String
	var total: int = get_total_level()
	if total > 0:
		_label.text = "%s  +%d" % [base_name, total]
	else:
		_label.text = base_name

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

	_label = Label3D.new()
	_label.text = config["name"] as String
	_label.position = Vector3(0, 0.8, 0)
	_label.font_size = 24
	_label.modulate = color
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
