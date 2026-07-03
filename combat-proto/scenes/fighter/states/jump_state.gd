class_name FighterJumpState
extends BaseState

const GRAVITY: float = 18.0

var _fighter: Fighter = null
var _timer: float = 0.0
var _vertical_velocity: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_fighter = owner as Fighter
	_timer = _fighter.stats.jump_duration
	_fighter.combat_resource.spend_stamina(10.0)

	var jump_time: float = _fighter.stats.jump_duration * 0.5
	_vertical_velocity = (2.0 * _fighter.stats.jump_height) / jump_time


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		state_machine.transition_to(&"Idle")
		return

	_vertical_velocity -= GRAVITY * delta
	_fighter.velocity.y = _vertical_velocity
	_fighter.velocity.x = move_toward(_fighter.velocity.x, 0.0, 10.0 * delta)
	_fighter.velocity.z = move_toward(_fighter.velocity.z, 0.0, 10.0 * delta)
	_fighter.move_and_slide()

	if _fighter.is_on_floor() and _timer < _fighter.stats.jump_duration - 0.1:
		state_machine.transition_to(&"Idle")


func is_in_iframes() -> bool:
	var elapsed: float = _fighter.stats.jump_duration - _timer
	var start: float = _fighter.stats.jump_iframe_start
	var end: float = start + _fighter.stats.jump_iframe_duration
	return elapsed >= start and elapsed <= end
