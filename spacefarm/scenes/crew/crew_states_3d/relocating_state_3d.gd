class_name CrewRelocatingState3D
extends BaseState


func enter(_msg: Dictionary = {}) -> void:
	var crew: CrewMember3D = owner as CrewMember3D
	crew.velocity = Vector3.ZERO
	crew.visible = false
	crew.set_physics_process(false)


func exit() -> void:
	var crew: CrewMember3D = owner as CrewMember3D
	crew.visible = true
	crew.set_physics_process(true)
