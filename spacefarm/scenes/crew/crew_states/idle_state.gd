class_name CrewIdleState
extends BaseState

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	var crew: CrewMember = owner as CrewMember
	crew.velocity = Vector2.ZERO
	_timer = randf_range(CrewMember.IDLE_TIME_MIN, CrewMember.IDLE_TIME_MAX)


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		state_machine.transition_to(&"Wander")
