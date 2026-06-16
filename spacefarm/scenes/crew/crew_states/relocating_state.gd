class_name CrewRelocatingState
extends BaseState
## Transitioning between rooms via schedule. NPC is invisible/inactive during relocation.


func enter(_msg: Dictionary = {}) -> void:
	var crew: CrewMember = owner as CrewMember
	crew.velocity = Vector2.ZERO
	crew.visible = false
	crew.set_physics_process(false)


func exit() -> void:
	var crew: CrewMember = owner as CrewMember
	crew.visible = true
	crew.set_physics_process(true)
	state_machine.transition_to(&"Idle")
