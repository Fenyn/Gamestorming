class_name CrewTalkingState3D
extends BaseState

var _talk_duration: float = 2.0
var _timer: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	var crew: CrewMember3D = owner as CrewMember3D
	crew.velocity = Vector3.ZERO
	_talk_duration = msg.get("duration", 2.0) as float
	_timer = 0.0


func update(delta: float) -> void:
	_timer += delta
	if _timer >= _talk_duration:
		state_machine.transition_to(&"Idle")
