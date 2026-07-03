class_name FighterShoveState
extends BaseState

signal shove_started()
signal shove_connected(vs_block: bool)
signal shove_recovered()

enum Phase { STARTUP, ACTIVE, RECOVERY }

const STAMINA_COST: float = 15.0
const POSTURE_VS_BLOCK: int = 35
const POSTURE_VS_NEUTRAL: int = 5
const STARTUP_TIME: float = 0.3
const ACTIVE_TIME: float = 0.067
const RECOVERY_TIME: float = 0.133

var _fighter: Fighter = null
var _phase: Phase = Phase.STARTUP
var _timer: float = 0.0
var _has_hit: bool = false
var _hitbox_connected: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_fighter = owner as Fighter
	_has_hit = false
	_hitbox_connected = false

	if not _fighter.combat_resource.has_stamina(STAMINA_COST):
		state_machine.transition_to(&"Idle")
		return

	_fighter.combat_resource.spend_stamina(STAMINA_COST)
	_phase = Phase.STARTUP
	_timer = STARTUP_TIME
	_fighter.hitbox.monitoring = false
	shove_started.emit()


func exit() -> void:
	_fighter.hitbox.monitoring = false
	_disconnect_hitbox()


func physics_update(delta: float) -> void:
	_timer -= delta

	match _phase:
		Phase.STARTUP:
			if _timer <= 0.0:
				_phase = Phase.ACTIVE
				_timer = ACTIVE_TIME
				_fighter.hitbox.monitoring = true
				_connect_hitbox()

		Phase.ACTIVE:
			if _timer <= 0.0:
				_fighter.hitbox.monitoring = false
				_disconnect_hitbox()
				_phase = Phase.RECOVERY
				_timer = RECOVERY_TIME

		Phase.RECOVERY:
			if _timer <= 0.0:
				shove_recovered.emit()
				state_machine.transition_to(&"Idle")


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
	_resolve_shove(target as Fighter)


func _resolve_shove(target: Fighter) -> void:
	var target_state: StringName = target.state_machine.get_current_state_name()

	if target_state == &"Dodging" or target_state == &"Jumping":
		var current_state: BaseState = target.state_machine.current_state
		if current_state.has_method("is_in_iframes") and current_state.is_in_iframes():
			EventBus.attack_missed.emit(_fighter)
			return

	var vs_block: bool = target_state == &"Blocking"

	if vs_block:
		target.combat_resource.take_posture_damage(POSTURE_VS_BLOCK)
		target.state_machine.transition_to(&"GuardBroken")
	else:
		target.combat_resource.take_posture_damage(POSTURE_VS_NEUTRAL)
		target.state_machine.transition_to(&"Hitstun")

	shove_connected.emit(vs_block)
	EventBus.shove_landed.emit(_fighter, target, vs_block)
