extends RigidBody3D
class_name Orb

signal distance_updated(orb: Orb, total_distance: float)
signal orb_consumed(orb: Orb, total_distance: float)

const BASE_SPARK_RATE: float = 2.0
@export var spark_multiplier: float = 1.0

var maw_pull: float = 0.0
var total_distance: float = 0.0
var _last_position: Vector3
var _is_active: bool = true

func _ready() -> void:
	_last_position = global_position
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4

func _physics_process(_delta: float) -> void:
	if not _is_active:
		return

	var current_pos: Vector3 = global_position
	var frame_distance: float = current_pos.distance_to(_last_position)
	total_distance += frame_distance
	_last_position = current_pos

	distance_updated.emit(self, total_distance)

	if maw_pull > 0.0:
		var to_center: Vector3 = -Vector3(current_pos.x, 0.0, current_pos.z)
		if to_center.length_squared() > 0.01:
			apply_central_force(to_center.normalized() * maw_pull)

	if global_position.y < -20.0:
		consume()

func get_sparks() -> float:
	return total_distance * BASE_SPARK_RATE * spark_multiplier

func set_orb_color(color: Color) -> void:
	for child: Node in get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 0.5
			(child as MeshInstance3D).material_override = mat

func apply_mass_visual() -> void:
	if mass <= 0.5:
		return
	var scale_factor: float = 1.0 + (mass - 0.5) * 0.12
	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).scale = Vector3.ONE * scale_factor

func apply_golden() -> void:
	spark_multiplier *= 5.0
	var gold: Color = Color(1.0, 0.85, 0.2)
	for child: Node in get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = gold
			mat.emission_enabled = true
			mat.emission = gold
			mat.emission_energy_multiplier = 2.0
			(child as MeshInstance3D).material_override = mat
			(child as MeshInstance3D).scale = Vector3.ONE * 1.15

func consume() -> void:
	if not _is_active:
		return
	_is_active = false
	orb_consumed.emit(self, total_distance)
	queue_free()
