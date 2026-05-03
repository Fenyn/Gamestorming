class_name SpellSlot
extends Node3D

@export var slot_position: int = 0
@export var owner_player: int = 0

var _mesh: MeshInstance3D

func _ready() -> void:
	_mesh = $MeshInstance3D
	_set_color(Color(0.55, 0.3, 0.6, 1.0))

func _set_color(color: Color) -> void:
	if _mesh == null:
		return
	var mat: StandardMaterial3D = _mesh.get_surface_override_material(0)
	if mat == null:
		mat = StandardMaterial3D.new()
		_mesh.set_surface_override_material(0, mat)
	mat.albedo_color = color
