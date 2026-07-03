class_name FighterExhaustedState
extends BaseState

var _fighter: Fighter = null


func enter(_msg: Dictionary = {}) -> void:
	_fighter = owner as Fighter


func physics_update(delta: float) -> void:
	_fighter.combat_resource.recover_stamina(delta)
	_fighter.combat_resource.recover_posture(delta, false)

	var threshold: float = _fighter.stats.exhaustion_threshold * _fighter.stats.max_stamina
	if _fighter.combat_resource.current_stamina > threshold:
		state_machine.transition_to(&"Idle")
		return

	var new_stance: StanceDirection.Direction = _fighter.input.get_stance_direction()
	_fighter.stance_manager.set_stance(new_stance)

	if _fighter.input.is_action_just_pressed(&"guard"):
		state_machine.transition_to(&"Blocking")
		return

	if _fighter.input.is_action_just_pressed(&"light_attack"):
		state_machine.transition_to(&"Attacking", {"attack_key": "light", "exhausted": true})
		return

	if _fighter.input.is_action_just_pressed(&"heavy_attack"):
		state_machine.transition_to(&"Attacking", {"attack_key": "heavy", "exhausted": true})
		return

	var move: Vector2 = _fighter.input.get_move_vector()
	var penalty: float = 1.0 - _fighter.stats.exhaustion_speed_penalty
	var speed: float = _fighter.stats.move_speed * penalty

	if move.length_squared() > 0.01:
		var basis: Basis = _fighter.global_transform.basis
		var wish_dir: Vector3 = (basis.x * move.x + -basis.z * -move.y).normalized()
		_fighter.velocity.x = wish_dir.x * speed
		_fighter.velocity.z = wish_dir.z * speed
	else:
		_fighter.velocity.x = move_toward(_fighter.velocity.x, 0.0, 20.0 * delta)
		_fighter.velocity.z = move_toward(_fighter.velocity.z, 0.0, 20.0 * delta)

	_fighter.velocity.y -= 18.0 * delta
	_fighter.move_and_slide()
	_fighter.face_opponent()
