class_name CombatResolver
extends RefCounted


static func resolve_hit(attack_data: AttackData, _attacker: Node, defender: Node) -> HitResult:
	var defender_state: StringName = _get_defender_state(defender)

	match defender_state:
		&"Blocking":
			return _resolve_vs_block(attack_data, defender)
		&"Dodging":
			return _resolve_vs_dodge(attack_data, defender)
		&"Jumping":
			return _resolve_vs_jump(attack_data)
		_:
			return _resolve_vs_open(attack_data)


static func _resolve_vs_block(attack_data: AttackData, defender: Node) -> HitResult:
	if not attack_data.is_blockable:
		return _resolve_vs_open(attack_data)

	var block_state: BaseState = _get_current_state(defender)
	if block_state == null:
		return _resolve_vs_open(attack_data)

	var direction_match: bool = false
	if block_state.has_method("matches_direction"):
		direction_match = block_state.matches_direction(attack_data.stance)

	if not direction_match:
		return _resolve_vs_open(attack_data)

	if attack_data.is_deflectable and block_state.has_method("is_within_deflect_window"):
		if block_state.is_within_deflect_window():
			return HitResult.deflected(attack_data)

	return HitResult.blocked(attack_data)


static func _resolve_vs_dodge(attack_data: AttackData, defender: Node) -> HitResult:
	var dodge_state: BaseState = _get_current_state(defender)
	if dodge_state == null:
		return _resolve_vs_open(attack_data)

	if dodge_state.has_method("is_in_iframes") and dodge_state.is_in_iframes():
		if attack_data.is_perilous and attack_data.perilous_counter != &"":
			if _check_perilous_counter(attack_data, dodge_state):
				return _get_perilous_counter_result(attack_data)
		return HitResult.dodged()

	return _resolve_vs_open(attack_data)


static func _resolve_vs_jump(attack_data: AttackData) -> HitResult:
	if attack_data.is_perilous and attack_data.perilous_counter == &"jump":
		return HitResult.perilous_countered(&"jump", 30)
	return HitResult.dodged()


static func _resolve_vs_open(attack_data: AttackData) -> HitResult:
	if attack_data.attack_type == AttackData.AttackType.PERILOUS_GRAB:
		return HitResult.grabbed(attack_data)
	return HitResult.hit(attack_data)


static func _check_perilous_counter(attack_data: AttackData, dodge_state: BaseState) -> bool:
	if attack_data.perilous_counter == &"mikiri":
		if dodge_state.has_method("is_forward_dodge") and dodge_state.is_forward_dodge():
			return true
	elif attack_data.perilous_counter == &"side_dodge":
		if dodge_state.has_method("is_side_dodge") and dodge_state.is_side_dodge():
			return true
	return false


static func _get_perilous_counter_result(attack_data: AttackData) -> HitResult:
	match attack_data.perilous_counter:
		&"mikiri":
			return HitResult.perilous_countered(&"mikiri", 50)
		&"side_dodge":
			return HitResult.perilous_countered(&"side_dodge", 0)
	return HitResult.dodged()


static func _get_defender_state(defender: Node) -> StringName:
	if defender.has_method("get_current_state_name"):
		return defender.get_current_state_name()
	var state_machine: Node = defender.get_node_or_null(NodePath("%StateMachine"))
	if state_machine and state_machine.has_method("get_current_state_name"):
		return state_machine.get_current_state_name()
	return &""


static func _get_current_state(defender: Node) -> BaseState:
	var state_machine: Node = defender.get_node_or_null(NodePath("%StateMachine"))
	if state_machine and state_machine is BaseStateMachine:
		return (state_machine as BaseStateMachine).current_state
	return null
