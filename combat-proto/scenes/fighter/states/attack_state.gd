class_name FighterAttackState
extends BaseState

signal attack_started(attack_data: AttackData)
signal attack_active()
signal attack_recovered()

enum Phase { STARTUP, CHARGING, ACTIVE, RECOVERY }

var _fighter: Fighter = null
var _attack_data: AttackData = null
var _phase: Phase = Phase.STARTUP
var _timer: float = 0.0
var _charge_elapsed: float = 0.0
var _has_hit: bool = false
var _is_unblockable: bool = false
var _has_armor: bool = false
var _original_mesh_color: Color = Color.WHITE
var _hitbox_connected: bool = false


func enter(msg: Dictionary = {}) -> void:
	_fighter = owner as Fighter
	_has_hit = false
	_is_unblockable = false
	_has_armor = false
	_charge_elapsed = 0.0
	_hitbox_connected = false

	var attack_key: String = msg.get("attack_key", "light") as String
	var direction: StanceDirection.Direction = _fighter.stance_manager.current_stance
	_attack_data = _fighter.profile.get_directional_attack(attack_key, direction)

	if _attack_data == null:
		_attack_data = _fighter.profile.get_attack(attack_key)

	if _attack_data == null:
		state_machine.transition_to(&"Idle")
		return

	if not _fighter.combat_resource.has_stamina(_attack_data.stamina_cost):
		state_machine.transition_to(&"Idle")
		return

	_fighter.combat_resource.spend_stamina(_attack_data.stamina_cost)

	_phase = Phase.STARTUP
	_timer = _attack_data.startup_time

	if _attack_data.is_perilous:
		_apply_perilous_flash()
		EventBus.perilous_warning.emit(_fighter, _attack_data.indicator_color)

	_fighter.hitbox.monitoring = false
	attack_started.emit(_attack_data)
	EventBus.attack_started.emit(_fighter, _attack_data)


func exit() -> void:
	_fighter.hitbox.monitoring = false
	_clear_perilous_flash()
	_disconnect_hitbox()


func physics_update(delta: float) -> void:
	if _attack_data == null:
		state_machine.transition_to(&"Idle")
		return

	match _phase:
		Phase.STARTUP:
			_process_startup(delta)
		Phase.CHARGING:
			_process_charging(delta)
		Phase.ACTIVE:
			_process_active(delta)
		Phase.RECOVERY:
			_process_recovery(delta)


func _process_startup(delta: float) -> void:
	_timer -= delta

	if _attack_data.feint_window > 0.0:
		var elapsed: float = _attack_data.startup_time - _timer
		if elapsed <= _attack_data.feint_window:
			if _fighter.input.is_action_just_pressed(&"feint"):
				EventBus.attack_feinted.emit(_fighter)
				state_machine.transition_to(&"Idle")
				return

	if _attack_data.is_chargeable and _fighter.input.is_action_pressed(&"heavy_attack"):
		_phase = Phase.CHARGING
		_charge_elapsed = 0.0
		_clear_perilous_flash()
		return

	if _timer <= 0.0:
		_enter_active_phase()


func _process_charging(delta: float) -> void:
	_charge_elapsed += delta

	if _fighter.input.is_action_just_pressed(&"feint"):
		EventBus.attack_feinted.emit(_fighter)
		state_machine.transition_to(&"Idle")
		return

	if _charge_elapsed >= _attack_data.charge_time:
		_is_unblockable = _attack_data.unblockable_at_full_charge
		_has_armor = _attack_data.has_hyper_armor or _attack_data.unblockable_at_full_charge

	if not _fighter.input.is_action_pressed(&"heavy_attack"):
		_enter_active_phase()


func _process_active(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_fighter.hitbox.monitoring = false
		_disconnect_hitbox()
		_phase = Phase.RECOVERY
		_timer = _attack_data.recovery_time
		if _is_unblockable:
			_timer = _attack_data.recovery_time * 1.2
		attack_recovered.emit()


func _process_recovery(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		state_machine.transition_to(&"Idle")


func _enter_active_phase() -> void:
	_phase = Phase.ACTIVE
	_timer = _attack_data.active_time
	_fighter.hitbox.monitoring = true
	_connect_hitbox()
	_clear_perilous_flash()
	attack_active.emit()


func _connect_hitbox() -> void:
	if _hitbox_connected:
		return
	if not _fighter.hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		_fighter.hitbox.area_entered.connect(_on_hitbox_area_entered)
		_hitbox_connected = true


func _disconnect_hitbox() -> void:
	if _hitbox_connected:
		if _fighter.hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			_fighter.hitbox.area_entered.disconnect(_on_hitbox_area_entered)
		_hitbox_connected = false


func _on_hitbox_area_entered(area: Area3D) -> void:
	if _has_hit:
		return

	var target: Node = area.owner
	if target == null or target == _fighter:
		return
	if not (target is Fighter):
		return

	_has_hit = true
	_resolve_hit(target as Fighter)


func _resolve_hit(target: Fighter) -> void:
	var effective_attack: AttackData = _attack_data
	if _is_unblockable:
		effective_attack = _create_charged_attack_data()

	var result: HitResult = CombatResolver.resolve_hit(effective_attack, _fighter, target)
	_apply_hit_result(result, target)


func _apply_hit_result(result: HitResult, target: Fighter) -> void:
	match result.outcome:
		HitResult.Outcome.HIT:
			target.combat_resource.take_hp_damage(result.hp_damage_to_defender)
			target.combat_resource.take_posture_damage(result.posture_damage_to_defender)
			if result.defender_state_transition != &"":
				target.state_machine.transition_to(result.defender_state_transition)
			EventBus.attack_landed.emit(_fighter, target, _attack_data)

		HitResult.Outcome.BLOCKED:
			target.combat_resource.take_posture_damage(result.posture_damage_to_defender)
			target.combat_resource.spend_stamina(result.stamina_cost_to_defender)
			EventBus.attack_blocked.emit(_fighter, target, _attack_data)

		HitResult.Outcome.DEFLECTED:
			_fighter.combat_resource.take_posture_damage(result.posture_damage_to_attacker)
			if result.defender_state_transition != &"":
				target.state_machine.transition_to(result.defender_state_transition)
			EventBus.attack_deflected.emit(_fighter, target, _attack_data)

		HitResult.Outcome.DODGED:
			EventBus.attack_missed.emit(_fighter)

		HitResult.Outcome.PERILOUS_COUNTERED:
			_fighter.combat_resource.take_posture_damage(result.posture_damage_to_attacker)
			EventBus.perilous_countered.emit(_fighter, target, result.counter_type)
			state_machine.transition_to(&"Hitstun")

		HitResult.Outcome.GRABBED:
			target.combat_resource.take_hp_damage(result.hp_damage_to_defender)
			target.combat_resource.take_posture_damage(result.posture_damage_to_defender)
			if result.defender_state_transition != &"":
				target.state_machine.transition_to(result.defender_state_transition)
			EventBus.attack_landed.emit(_fighter, target, _attack_data)

		HitResult.Outcome.MISSED:
			EventBus.attack_missed.emit(_fighter)

	if not _has_armor and result.outcome == HitResult.Outcome.DEFLECTED:
		state_machine.transition_to(&"Idle")


func _create_charged_attack_data() -> AttackData:
	var charged: AttackData = _attack_data.duplicate() as AttackData
	var charge_ratio: float = clampf(_charge_elapsed / _attack_data.charge_time, 0.0, 1.0)
	var multiplier: float = lerpf(1.0, _attack_data.charge_damage_multiplier, charge_ratio)
	charged.hp_damage = int(charged.hp_damage * multiplier)
	charged.posture_on_hit = int(charged.posture_on_hit * multiplier)
	if charge_ratio >= 1.0:
		charged.is_blockable = false
		charged.has_hyper_armor = true
	return charged


func _apply_perilous_flash() -> void:
	var mesh: MeshInstance3D = _fighter.get_node_or_null(NodePath("%FighterMesh")) as MeshInstance3D
	if mesh == null:
		return
	var mat: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
	if mat:
		_original_mesh_color = mat.albedo_color
		var flash_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
		flash_mat.albedo_color = _attack_data.indicator_color
		flash_mat.emission_enabled = true
		flash_mat.emission = _attack_data.indicator_color
		flash_mat.emission_energy_multiplier = 2.0
		mesh.set_surface_override_material(0, flash_mat)


func _clear_perilous_flash() -> void:
	var mesh: MeshInstance3D = _fighter.get_node_or_null(NodePath("%FighterMesh")) as MeshInstance3D
	if mesh == null:
		return
	mesh.set_surface_override_material(0, null)
