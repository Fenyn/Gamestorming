class_name PowerCell
extends RigidBody3D

signal settled(cell_index: int, face_value: int)
signal picked_up(cell_index: int)

const SETTLE_VELOCITY_THRESHOLD: float = 0.15
const SETTLE_TIME_REQUIRED: float = 0.3
const FORCE_SETTLE_TIMEOUT: float = 4.0
const ROLL_ANGULAR_MIN: float = 8.0
const ROLL_ANGULAR_MAX: float = 18.0
const ROLL_UPWARD_FORCE: float = 1.5

@export var cell_index: int = 0

var face_value: int = 0
var is_settled: bool = false
var is_socketed: bool = false
var cell_data: CellData

var _settle_timer: float = 0.0
var _total_roll_time: float = 0.0
var _is_rolling: bool = false
var _mesh: MeshInstance3D


func _ready() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = true
	max_contacts_reported = 1
	mass = 0.3
	linear_damp = 3.0
	angular_damp = 6.0
	_build_collision()
	_build_mesh()


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.38, 0.38, 0.38)
	shape.shape = box
	add_child(shape)


func _build_mesh() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.35, 0.35)
	_mesh.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.24, 0.32)
	mat.metallic = 0.4
	mat.roughness = 0.5
	_mesh.set_surface_override_material(0, mat)
	add_child(_mesh)


func apply_cell_data(data: CellData) -> void:
	cell_data = data
	if _mesh and cell_data:
		var mat: StandardMaterial3D = _mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.emission_enabled = true
			mat.emission = cell_data.glow_color
			mat.emission_energy_multiplier = 0.3


func roll() -> void:
	if is_socketed:
		return
	is_settled = false
	face_value = 0
	_settle_timer = 0.0
	_total_roll_time = 0.0
	_is_rolling = true
	freeze = false
	visible = true

	var rand_angular := Vector3(
		randf_range(-ROLL_ANGULAR_MAX, ROLL_ANGULAR_MAX),
		randf_range(-ROLL_ANGULAR_MAX, ROLL_ANGULAR_MAX),
		randf_range(-ROLL_ANGULAR_MAX, ROLL_ANGULAR_MAX),
	)
	if rand_angular.length() < ROLL_ANGULAR_MIN:
		rand_angular = rand_angular.normalized() * ROLL_ANGULAR_MIN
	angular_velocity = rand_angular

	linear_velocity = Vector3(
		randf_range(-0.8, 0.8),
		ROLL_UPWARD_FORCE,
		randf_range(-0.5, 0.5),
	)


func _physics_process(delta: float) -> void:
	if not _is_rolling:
		return

	_total_roll_time += delta

	if _total_roll_time >= FORCE_SETTLE_TIMEOUT:
		_force_settle()
		return

	var speed: float = linear_velocity.length() + angular_velocity.length()
	if speed < SETTLE_VELOCITY_THRESHOLD:
		_settle_timer += delta
		if _settle_timer >= SETTLE_TIME_REQUIRED:
			_force_settle()
	else:
		_settle_timer = 0.0


func _force_settle() -> void:
	_is_rolling = false
	freeze = true
	is_settled = true
	if cell_data:
		face_value = cell_data.roll()
	else:
		face_value = FaceReader.read_top_face(self)
	settled.emit(cell_index, face_value)


var _drag_rotation: Basis


func begin_drag() -> void:
	_drag_rotation = global_transform.basis
	freeze = true
	is_socketed = true


func socket() -> void:
	is_socketed = true
	visible = false


func unsocket() -> void:
	is_socketed = false
	visible = true
	freeze = true
	if _drag_rotation != Basis():
		global_transform.basis = _drag_rotation


func return_to_tray(tray_position: Vector3) -> void:
	unsocket()
	freeze = true
	is_settled = true
	global_position = tray_position
