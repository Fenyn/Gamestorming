class_name DoorLight
extends Node3D

enum Status { SAFE, SEALED, BREACH }

@onready var _mesh: MeshInstance3D = $LightMesh
@onready var _glow: OmniLight3D = $Glow

var _status: Status = Status.SAFE

const COLORS: Dictionary = {
	Status.SAFE: Color(0.2, 0.9, 0.2),
	Status.SEALED: Color(0.9, 0.7, 0.1),
	Status.BREACH: Color(0.9, 0.15, 0.1),
}


func set_status(status: Status) -> void:
	_status = status
	var color: Color = COLORS.get(status, Color.WHITE) as Color
	var mat: StandardMaterial3D = _mesh.material_override as StandardMaterial3D
	if mat:
		mat.emission = color
	_glow.light_color = color
