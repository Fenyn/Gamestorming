class_name FighterDeadState
extends BaseState

var _fighter: Fighter = null


func enter(_msg: Dictionary = {}) -> void:
	_fighter = owner as Fighter
	_fighter.velocity = Vector3.ZERO
	EventBus.fighter_died.emit(_fighter)


func physics_update(delta: float) -> void:
	_fighter.velocity.y -= 18.0 * delta
	_fighter.move_and_slide()
