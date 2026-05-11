class_name StatusScreen
extends Node3D

@onready var _viewport: SubViewport = $SubViewport
@onready var _screen_mesh: MeshInstance3D = $ScreenMesh


func _ready() -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = _viewport.get_texture()
	mat.emission_enabled = true
	mat.emission_texture = _viewport.get_texture()
	mat.emission_energy_multiplier = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_screen_mesh.material_override = mat
