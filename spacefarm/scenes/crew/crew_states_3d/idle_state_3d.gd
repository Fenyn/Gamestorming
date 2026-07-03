class_name CrewIdleState3D
extends BaseState

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	var crew: CrewMember3D = owner as CrewMember3D
	crew.velocity = Vector3.ZERO
	_timer = randf_range(CrewMember3D.IDLE_TIME_MIN, CrewMember3D.IDLE_TIME_MAX)


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		state_machine.transition_to(&"Wander")
