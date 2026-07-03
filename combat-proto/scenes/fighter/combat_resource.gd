class_name CombatResource
extends Node

signal hp_changed(current: int, max_val: int)
signal posture_changed(current: int, max_val: int)
signal stamina_changed(current: float, max_val: float)
signal posture_broken()
signal exhaustion_changed(is_exhausted: bool)
signal died()

var max_hp: int = 100
var current_hp: int = 100
var max_posture: int = 100
var current_posture: int = 0
var max_stamina: float = 100.0
var current_stamina: float = 100.0
var is_exhausted: bool = false

var _stats: FighterStats = null
var _stamina_pause_timer: float = 0.0


func setup(stats: FighterStats) -> void:
	_stats = stats
	max_hp = stats.max_hp
	current_hp = max_hp
	max_posture = stats.max_posture
	current_posture = 0
	max_stamina = stats.max_stamina
	current_stamina = max_stamina
	is_exhausted = false


func take_hp_damage(amount: int) -> void:
	var clamped: int = mini(amount, current_hp)
	current_hp -= clamped
	hp_changed.emit(current_hp, max_hp)
	EventBus.hp_changed.emit(owner, current_hp, max_hp)
	if current_hp <= 0:
		died.emit()


func take_posture_damage(amount: int) -> void:
	current_posture = mini(current_posture + amount, max_posture)
	posture_changed.emit(current_posture, max_posture)
	EventBus.posture_changed.emit(owner, current_posture, max_posture)
	if current_posture >= max_posture:
		posture_broken.emit()
		EventBus.posture_broken.emit(owner)


func reset_posture() -> void:
	current_posture = 0
	posture_changed.emit(current_posture, max_posture)
	EventBus.posture_changed.emit(owner, current_posture, max_posture)


func spend_stamina(amount: float) -> void:
	current_stamina = maxf(current_stamina - amount, 0.0)
	_stamina_pause_timer = _stats.stamina_recovery_pause
	stamina_changed.emit(current_stamina, max_stamina)
	EventBus.stamina_changed.emit(owner, current_stamina, max_stamina)
	if current_stamina <= 0.0 and not is_exhausted:
		is_exhausted = true
		exhaustion_changed.emit(true)
		EventBus.exhaustion_changed.emit(owner, true)


func has_stamina(amount: float) -> bool:
	return current_stamina >= amount


func recover_posture(delta: float, is_guarding: bool) -> void:
	if _stats == null or current_posture <= 0:
		return
	var base_rate: float = _stats.posture_recovery_rate
	if is_guarding:
		base_rate += _stats.guard_recovery_bonus
	var multiplier: float = _stats.get_posture_recovery_multiplier(get_hp_percent())
	var recovery: float = base_rate * multiplier * delta
	current_posture = maxi(current_posture - int(recovery), 0)
	posture_changed.emit(current_posture, max_posture)


func recover_stamina(delta: float) -> void:
	if _stats == null:
		return
	if _stamina_pause_timer > 0.0:
		_stamina_pause_timer -= delta
		return
	if current_stamina >= max_stamina:
		return
	current_stamina = minf(current_stamina + _stats.stamina_recovery_rate * delta, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)
	if is_exhausted and current_stamina >= max_stamina * _stats.exhaustion_threshold:
		is_exhausted = false
		exhaustion_changed.emit(false)
		EventBus.exhaustion_changed.emit(owner, false)


func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, max_hp)
	hp_changed.emit(current_hp, max_hp)
	EventBus.hp_changed.emit(owner, current_hp, max_hp)


func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)


func get_posture_percent() -> float:
	if max_posture <= 0:
		return 0.0
	return float(current_posture) / float(max_posture)


func get_stamina_percent() -> float:
	if max_stamina <= 0.0:
		return 0.0
	return current_stamina / max_stamina


func is_alive() -> bool:
	return current_hp > 0


func full_reset() -> void:
	if _stats:
		setup(_stats)
