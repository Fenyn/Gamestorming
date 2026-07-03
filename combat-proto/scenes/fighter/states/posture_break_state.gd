class_name FighterPostureBreakState
extends BaseState

var _fighter: Fighter = null
var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_fighter = owner as Fighter
	_timer = _fighter.stats.posture_break_stun_duration
	EventBus.posture_broken.emit(_fighter)


func exit() -> void:
	_fighter.combat_resource.reset_posture()


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		state_machine.transition_to(&"Idle")
		return

	_fighter.velocity.x = move_toward(_fighter.velocity.x, 0.0, 30.0 * delta)
	_fighter.velocity.z = move_toward(_fighter.velocity.z, 0.0, 30.0 * delta)
	_fighter.velocity.y -= 18.0 * delta
	_fighter.move_and_slide()


func is_deathblowable() -> bool:
	return _timer > 0.0
