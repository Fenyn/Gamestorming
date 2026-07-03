class_name FighterDeflectState
extends BaseState

const DEFLECT_DURATION: float = 0.3

var _fighter: Fighter = null
var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_fighter = owner as Fighter
	_timer = DEFLECT_DURATION


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		state_machine.transition_to(&"Idle")
		return

	_fighter.velocity.x = move_toward(_fighter.velocity.x, 0.0, 30.0 * delta)
	_fighter.velocity.z = move_toward(_fighter.velocity.z, 0.0, 30.0 * delta)
	_fighter.velocity.y -= 18.0 * delta
	_fighter.move_and_slide()
