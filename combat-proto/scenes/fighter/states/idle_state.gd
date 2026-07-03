class_name FighterIdleState
extends BaseState

var _fighter: Fighter = null


func enter(_msg: Dictionary = {}) -> void:
	_fighter = owner as Fighter


func physics_update(delta: float) -> void:
	if _fighter.input == null:
		return

	_fighter.combat_resource.recover_posture(delta, false)
	_fighter.combat_resource.recover_stamina(delta)

	var new_stance: StanceDirection.Direction = _fighter.input.get_stance_direction()
	_fighter.stance_manager.set_stance(new_stance)

	if _fighter.input.is_action_just_pressed(&"lock_on"):
		_fighter.toggle_lock_on()

	if _fighter.combat_resource.is_exhausted:
		state_machine.transition_to(&"Exhausted")
		return

	if _fighter.input.is_action_just_pressed(&"guard"):
		state_machine.transition_to(&"Blocking")
		return

	if _fighter.input.is_action_just_pressed(&"light_attack"):
		state_machine.transition_to(&"Attacking", {"attack_key": "light"})
		return

	if _fighter.input.is_action_just_pressed(&"heavy_attack"):
		state_machine.transition_to(&"Attacking", {"attack_key": "heavy"})
		return

	if _fighter.input.is_action_just_pressed(&"dodge"):
		if _fighter.combat_resource.has_stamina(15.0):
			state_machine.transition_to(&"Dodging")
			return

	if _fighter.input.is_action_just_pressed(&"jump"):
		if _fighter.combat_resource.has_stamina(10.0):
			state_machine.transition_to(&"Jumping")
			return

	if _fighter.input.is_action_just_pressed(&"shove"):
		if _fighter.combat_resource.has_stamina(15.0):
			state_machine.transition_to(&"Shoving")
			return

	var move: Vector2 = _fighter.input.get_move_vector()
	if move.length_squared() > 0.01:
		state_machine.transition_to(&"Moving")
		return

	_fighter.velocity.x = move_toward(_fighter.velocity.x, 0.0, 20.0 * delta)
	_fighter.velocity.z = move_toward(_fighter.velocity.z, 0.0, 20.0 * delta)
	_fighter.velocity.y -= 18.0 * delta
	_fighter.move_and_slide()
