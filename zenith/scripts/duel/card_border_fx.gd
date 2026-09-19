extends Node3D
## Local edge emitters, shared by table cards and the camera-relative hand.

@onready var sparks: GPUParticles3D = $Sparks
var _material: ShaderMaterial


func _ready() -> void:
	_material = sparks.material_override.duplicate()
	sparks.material_override = _material


func set_effect(color: Color, active: bool, reduced_motion: bool) -> void:
	var show_particles: bool = active and not reduced_motion
	visible = show_particles
	if sparks.emitting != show_particles:
		sparks.emitting = show_particles
	_material.set_shader_parameter("tint", color)
