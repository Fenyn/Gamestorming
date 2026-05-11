extends RigidBody3D
class_name Orb

signal distance_updated(orb: Orb, total_distance: float)
signal orb_consumed(orb: Orb, total_distance: float)

const BASE_SPARK_RATE: float = 2.0
@export var spark_multiplier: float = 1.0

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

func consume() -> void:
	if not _is_active:
		return
	_is_active = false
	orb_consumed.emit(self, total_distance)
	queue_free()
