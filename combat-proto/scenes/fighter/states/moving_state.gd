class_name FighterMovingState
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
	if move.length_squared() < 0.01:
		state_machine.transition_to(&"Idle")
		return

	var speed: float = _fighter.stats.move_speed
	if _fighter.is_locked_on:
		var forward: Vector3 = -_fighter.global_transform.basis.z
		var right: Vector3 = _fighter.global_transform.basis.x
		var wish_dir: Vector3 = (right * move.x + forward * -move.y).normalized()
		_fighter.velocity.x = wish_dir.x * speed
		_fighter.velocity.z = wish_dir.z * speed
	else:
		var cam_basis: Basis = _fighter.get_viewport().get_camera_3d().global_transform.basis
		var cam_forward: Vector3 = -cam_basis.z
		cam_forward.y = 0.0
		cam_forward = cam_forward.normalized()
		var cam_right: Vector3 = cam_basis.x
		cam_right.y = 0.0
		cam_right = cam_right.normalized()
		var wish_dir: Vector3 = (cam_right * move.x + cam_forward * -move.y).normalized()
		_fighter.velocity.x = wish_dir.x * speed
		_fighter.velocity.z = wish_dir.z * speed

	_fighter.velocity.y -= 18.0 * delta
	_fighter.move_and_slide()
	_fighter.face_opponent()
