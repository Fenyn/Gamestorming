class_name FighterDodgeState
extends BaseState

var _fighter: Fighter = null
var _timer: float = 0.0
var _direction: Vector3 = Vector3.ZERO
var _move_input: Vector2 = Vector2.ZERO


func enter(_msg: Dictionary = {}) -> void:
	_fighter = owner as Fighter
	_timer = _fighter.stats.dodge_duration
	_fighter.combat_resource.spend_stamina(15.0)

	_move_input = _fighter.input.get_move_vector()
	if _move_input.length_squared() < 0.01:
		_move_input = Vector2(0.0, 1.0)

	var basis: Basis = _fighter.global_transform.basis
	_direction = (basis.x * _move_input.x + -basis.z * -_move_input.y).normalized()


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		state_machine.transition_to(&"Idle")
		return

	_fighter.velocity.x = _direction.x * _fighter.stats.dodge_speed
	_fighter.velocity.z = _direction.z * _fighter.stats.dodge_speed
	_fighter.velocity.y -= 18.0 * delta
	_fighter.move_and_slide()


func is_in_iframes() -> bool:
	var elapsed: float = _fighter.stats.dodge_duration - _timer
	var start: float = _fighter.stats.dodge_iframe_start
	var end: float = start + _fighter.stats.dodge_iframe_duration
	return elapsed >= start and elapsed <= end


func is_forward_dodge() -> bool:
	return _move_input.y < -0.5


func is_side_dodge() -> bool:
	return absf(_move_input.x) > 0.5
