class_name FighterBlockState
extends BaseState

var _fighter: Fighter = null
var _guard_start_time: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_fighter = owner as Fighter
	_guard_start_time = Time.get_ticks_msec() / 1000.0


func physics_update(delta: float) -> void:
	if _fighter.input == null:
		return

	_fighter.combat_resource.recover_posture(delta, true)
	_fighter.combat_resource.recover_stamina(delta)

	var new_stance: StanceDirection.Direction = _fighter.input.get_stance_direction()
	_fighter.stance_manager.set_stance(new_stance)

	if not _fighter.input.is_action_pressed(&"guard"):
		state_machine.transition_to(&"Idle")
		return

	_fighter.velocity.x = move_toward(_fighter.velocity.x, 0.0, 20.0 * delta)
	_fighter.velocity.z = move_toward(_fighter.velocity.z, 0.0, 20.0 * delta)
	_fighter.velocity.y -= 18.0 * delta
	_fighter.move_and_slide()
	_fighter.face_opponent()


func matches_direction(attack_direction: StanceDirection.Direction) -> bool:
	return _fighter.stance_manager.matches(attack_direction)


func is_within_deflect_window() -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - _guard_start_time
	return elapsed <= _fighter.stats.deflect_window
