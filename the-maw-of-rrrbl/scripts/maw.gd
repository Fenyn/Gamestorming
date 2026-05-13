extends Node3D
class_name Maw

signal orb_consumed(sparks: float)
signal implosion_started()
signal implosion_finished()

@export var consumption_threshold: float = 2000.0

var consumed_sparks: float = 0.0

@onready var _consume_area: Area3D = $ConsumeArea

var _pool_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
var _vortex_ring: MeshInstance3D
var _vortex_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _pulse_timer: float = 0.0
var _imploding: bool = false

func _ready() -> void:
	_consume_area.body_entered.connect(_on_body_entered)
	_build_visual()

func _process(delta: float) -> void:
	_pulse_timer += delta

	if _vortex_ring:
		var fill: float = get_fill_percentage()
		var spin: float = 0.4 + fill * 2.0
		_vortex_ring.rotate_y(delta * spin)

	if not _imploding:
		var fill: float = get_fill_percentage()
		var pulse_speed: float = 1.0 + fill * 3.0
		var pulse: float = 0.5 + 0.5 * sin(_pulse_timer * pulse_speed)
		if _rim_mat:
			var base_energy: float = 1.5 + fill * 4.0
			_rim_mat.emission_energy_multiplier = base_energy * (0.8 + 0.4 * pulse)
		if _vortex_mat:
			_vortex_mat.emission_energy_multiplier = 1.0 + fill * 3.0 + pulse * 0.5
		if _core_mat:
			_core_mat.emission_energy_multiplier = 0.8 + fill * 5.0

func _on_body_entered(body: Node3D) -> void:
	if body is Orb:
		_consume_orb(body as Orb)

func _consume_orb(orb: Orb) -> void:
	var sparks: float = orb.get_sparks()
	consumed_sparks += sparks
	orb_consumed.emit(sparks)
	orb.consume()
	_update_fill_visual()

	if consumed_sparks >= consumption_threshold:
		_trigger_implosion()

func _trigger_implosion() -> void:
	_imploding = true
	implosion_started.emit()
	if _rim_mat:
		_rim_mat.emission_energy_multiplier = 12.0
	if _vortex_mat:
		_vortex_mat.emission_energy_multiplier = 8.0
	if _core_mat:
		_core_mat.emission_energy_multiplier = 10.0
	if _pool_mat:
		_pool_mat.emission_energy_multiplier = 3.0
	await get_tree().create_timer(2.0).timeout
	_imploding = false
	implosion_finished.emit()

func get_fill_percentage() -> float:
	return clampf(consumed_sparks / consumption_threshold, 0.0, 1.0)

func reset() -> void:
	consumed_sparks = 0.0
	_imploding = false
	_update_fill_visual()

func _build_visual() -> void:
	_add_outer_rim()
	_add_pool()
	_add_vortex_ring()
	_add_inner_ring()
	_add_core()
	_add_label()

func _add_outer_rim() -> void:
	var rim: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 1.65
	mesh.bottom_radius = 1.65
	mesh.height = 0.06
	mesh.radial_segments = 48
	rim.mesh = mesh
	rim.position.y = 0.02

	_rim_mat = StandardMaterial3D.new()
	_rim_mat.albedo_color = Color(0.35, 0.05, 0.55, 0.9)
	_rim_mat.emission_enabled = true
	_rim_mat.emission = Color(0.6, 0.15, 0.9)
	_rim_mat.emission_energy_multiplier = 1.5
	_rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rim.material_override = _rim_mat
	add_child(rim)

func _add_pool() -> void:
	var pool: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 1.5
	mesh.bottom_radius = 1.5
	mesh.height = 0.05
	mesh.radial_segments = 48
	pool.mesh = mesh
	pool.position.y = 0.03

	_pool_mat = StandardMaterial3D.new()
	_pool_mat.albedo_color = Color(0.02, 0.005, 0.04, 0.97)
	_pool_mat.emission_enabled = true
	_pool_mat.emission = Color(0.06, 0.01, 0.1)
	_pool_mat.emission_energy_multiplier = 0.3
	_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pool_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pool.material_override = _pool_mat
	add_child(pool)

func _add_vortex_ring() -> void:
	_vortex_ring = MeshInstance3D.new()
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.05
	_vortex_ring.mesh = mesh
	_vortex_ring.rotation.x = deg_to_rad(90)
	_vortex_ring.position.y = 0.04

	_vortex_mat = StandardMaterial3D.new()
	_vortex_mat.albedo_color = Color(0.25, 0.05, 0.45, 0.5)
	_vortex_mat.emission_enabled = true
	_vortex_mat.emission = Color(0.4, 0.08, 0.7)
	_vortex_mat.emission_energy_multiplier = 1.0
	_vortex_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vortex_ring.material_override = _vortex_mat
	add_child(_vortex_ring)

func _add_inner_ring() -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 0.4
	mesh.outer_radius = 0.55
	ring.mesh = mesh
	ring.rotation.x = deg_to_rad(90)
	ring.position.y = 0.05

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.02, 0.3, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.05, 0.5)
	mat.emission_energy_multiplier = 0.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	add_child(ring)

func _add_core() -> void:
	var core: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.25
	mesh.bottom_radius = 0.25
	mesh.height = 0.04
	mesh.radial_segments = 24
	core.mesh = mesh
	core.position.y = 0.06

	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(0.5, 0.1, 0.8, 0.9)
	_core_mat.emission_enabled = true
	_core_mat.emission = Color(0.7, 0.2, 1.0)
	_core_mat.emission_energy_multiplier = 0.8
	_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	core.material_override = _core_mat
	add_child(core)

func _add_label() -> void:
	var label: Label3D = Label3D.new()
	label.text = "THE MAW"
	label.position = Vector3(0, 1.2, 0)
	label.font_size = 28
	label.modulate = Color(1.0, 1.0, 1.0, 0.9)
	label.outline_modulate = Color(0.15, 0.0, 0.25, 1.0)
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _update_fill_visual() -> void:
	var fill: float = get_fill_percentage()
	if _pool_mat:
		_pool_mat.emission_energy_multiplier = 0.3 + fill * 2.0
