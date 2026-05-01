extends Node

enum State { IDLE, OFFERING, TRACKING, ACTIVE }

const COOLDOWN_MIN := 1500.0
const COOLDOWN_MAX := 2100.0
const OFFER_WINDOW := 600.0

var state: State = State.IDLE
var current_surge: Dictionary = {}
var cooldown_timer: float = 0.0
var offer_timer: float = 0.0
var hold_timer: float = 0.0
var effect_timer: float = 0.0
var production_multiplier: float = 1.0
var growth_multiplier: float = 1.0
var _vital_charge_timer: float = 0.0

const VITAL_CHARGE_DURATION := 180.0
const VITAL_CHARGE_MULT := 2.0

var _cooldown_target: float = 0.0

const SURGES := [
	{
		"id": "restoration",
		"name": "Restoration",
		"description": "The wizard calls for a burst of vital energy!",
		"health_tip": "Brief movement breaks reduce heart disease risk and improve focus.",
		"bpm_delta": 20.0,
		"hold_duration": 120.0,
		"effect": "production_mult",
		"effect_value": 2.0,
		"effect_duration": 60.0,
		"min_tiers": 0,
		"requires_plots": false,
	},
	{
		"id": "cascade_flow",
		"name": "Cascade Flow",
		"description": "Your movement stirs the magical cascade and each spell echoes itself!",
		"health_tip": "Even 2 minutes of walking improves circulation and mental clarity.",
		"bpm_delta": 30.0,
		"hold_duration": 120.0,
		"effect": "free_generators",
		"effect_value": 1.0,
		"effect_duration": 0.0,
		"min_tiers": 3,
		"requires_plots": false,
	},
	{
		"id": "growth_pulse",
		"name": "Growth Pulse",
		"description": "Your vitality quickens the Sanctum's growth!",
		"health_tip": "Standing and stretching for a few minutes helps maintain flexibility and blood flow.",
		"bpm_delta": 20.0,
		"hold_duration": 180.0,
		"effect": "growth_mult",
		"effect_value": 3.0,
		"effect_duration": 90.0,
		"min_tiers": 0,
		"requires_plots": true,
	},
]


func _ready() -> void:
	_start_cooldown()


func _process(delta: float) -> void:
	if _vital_charge_timer > 0.0:
		_vital_charge_timer -= delta
		if _vital_charge_timer <= 0.0:
			_vital_charge_timer = 0.0
			EventBus.notification.emit("Vital Charge faded.", "info")

	if not _is_hr_source_valid():
		return

	match state:
		State.IDLE:
			_process_idle(delta)
		State.OFFERING:
			_process_offering(delta)
		State.TRACKING:
			_process_tracking(delta)
		State.ACTIVE:
			_process_active(delta)


func _process_idle(delta: float) -> void:
	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		_offer_surge()


func _process_offering(delta: float) -> void:
	offer_timer -= delta
	if offer_timer <= 0.0:
		_expire_surge()
		return

	if HeartRateManager.smoothed_bpm >= _get_threshold():
		state = State.TRACKING
		hold_timer = 0.0


func _process_tracking(delta: float) -> void:
	offer_timer -= delta
	if offer_timer <= 0.0:
		_expire_surge()
		return

	if HeartRateManager.smoothed_bpm >= _get_threshold():
		hold_timer += delta
		var required: float = current_surge.get("hold_duration", 120.0)
		if hold_timer >= required:
			_complete_surge()
	else:
		state = State.OFFERING


func _process_active(delta: float) -> void:
	effect_timer -= delta
	if effect_timer <= 0.0:
		_end_effect()


func _offer_surge() -> void:
	var available := _get_available_surges()
	if available.is_empty():
		_start_cooldown()
		return

	current_surge = available[randi() % available.size()]
	state = State.OFFERING
	offer_timer = OFFER_WINDOW
	hold_timer = 0.0
	EventBus.surge_opportunity.emit(current_surge["id"])


func _complete_surge() -> void:
	var surge_id: String = current_surge["id"]
	EventBus.surge_completed.emit(surge_id)
	_apply_effect()
	if state != State.ACTIVE:
		_start_cooldown()


func _expire_surge() -> void:
	var surge_id: String = current_surge["id"]
	state = State.IDLE
	EventBus.surge_expired.emit(surge_id)
	current_surge = {}
	_start_cooldown()


func _apply_effect() -> void:
	var effect_type: String = current_surge.get("effect", "")
	var value: float = current_surge.get("effect_value", 1.0)
	var duration: float = current_surge.get("effect_duration", 0.0)

	var surge_power := PlotManager.get_surge_power_mult()
	match effect_type:
		"production_mult":
			production_multiplier = value * surge_power
			effect_timer = duration
			state = State.ACTIVE
			EventBus.surge_effect_started.emit(current_surge["id"], duration)
		"growth_mult":
			growth_multiplier = value * surge_power
			effect_timer = duration
			state = State.ACTIVE
			EventBus.surge_effect_started.emit(current_surge["id"], duration)
		"free_generators":
			var units: float = value
			for tier in GameState.unlocked_tiers:
				if GameState.get_generator_count(tier) > 0.0:
					GameState.add_generator_owned(tier, units)
					EventBus.generator_purchased.emit(tier, GameState.get_generator_count(tier))
			state = State.IDLE
			EventBus.notification.emit(
				"Cascade Flow! +%d free unit of each active generator!" % int(units),
				"surge"
			)
			current_surge = {}


func _end_effect() -> void:
	var surge_id: String = current_surge["id"]
	production_multiplier = 1.0
	growth_multiplier = 1.0
	effect_timer = 0.0
	current_surge = {}
	EventBus.surge_effect_ended.emit(surge_id)
	_start_cooldown()


func _start_cooldown() -> void:
	state = State.IDLE
	var base_cooldown := randf_range(COOLDOWN_MIN, COOLDOWN_MAX)
	var reduction := PrestigeManager.get_blessing_effect("surge_cooldown")
	_cooldown_target = base_cooldown * maxf(0.3, 1.0 - reduction)
	cooldown_timer = _cooldown_target


func _get_threshold() -> float:
	var resting := GameFormulas.resting_heart_rate(GameState.get_age())
	return resting + current_surge.get("bpm_delta", 20.0)


func _get_available_surges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for surge in SURGES:
		if surge["min_tiers"] > 0 and GameState.unlocked_tiers.size() < surge["min_tiers"]:
			continue
		if surge["requires_plots"] and not _has_planted_plots():
			continue
		result.append(surge)
	return result


func _has_planted_plots() -> bool:
	for plot_id in GameState.plots:
		var plot_state: Dictionary = GameState.plots[plot_id]
		var slots: Array = plot_state.get("slots", [])
		for slot in slots:
			if slot.get("planted", false):
				return true
	return false


func _is_hr_source_valid() -> bool:
	return HeartRateManager.source in ["demo", "websocket", "health_connect"]


func get_cooldown_progress() -> float:
	if state != State.IDLE or _cooldown_target <= 0.0:
		return 1.0
	return 1.0 - (cooldown_timer / _cooldown_target)


func get_hold_progress() -> float:
	if current_surge.is_empty():
		return 0.0
	var required: float = current_surge.get("hold_duration", 120.0)
	if required <= 0.0:
		return 1.0
	return clampf(hold_timer / required, 0.0, 1.0)


func get_offer_time_remaining() -> float:
	if state in [State.OFFERING, State.TRACKING]:
		return maxf(0.0, offer_timer)
	return 0.0


func get_effect_time_remaining() -> float:
	if state == State.ACTIVE:
		return maxf(0.0, effect_timer)
	return 0.0


func activate_vital_charge() -> void:
	_vital_charge_timer = VITAL_CHARGE_DURATION


func vital_charge_active() -> bool:
	return _vital_charge_timer > 0.0


func get_vital_charge_remaining() -> float:
	return maxf(0.0, _vital_charge_timer)


func get_vital_charge_mult() -> float:
	if _vital_charge_timer > 0.0:
		return VITAL_CHARGE_MULT
	return 1.0


func get_surge_message() -> String:
	if current_surge.is_empty():
		return ""
	var threshold := int(_get_threshold())
	var hold_min := int(current_surge.get("hold_duration", 120.0)) / 60
	var hold_sec := int(current_surge.get("hold_duration", 120.0)) % 60
	var desc: String = current_surge.get("description", "")
	var tip: String = current_surge.get("health_tip", "")
	var time_str := "%d:%02d" % [hold_min, hold_sec]
	return "%s Elevate your heart rate above %d BPM for %s! (%s)" % [desc, threshold, time_str, tip]


func reset_to_defaults() -> void:
	state = State.IDLE
	current_surge = {}
	production_multiplier = 1.0
	growth_multiplier = 1.0
	hold_timer = 0.0
	offer_timer = 0.0
	effect_timer = 0.0
	_vital_charge_timer = 0.0
	_start_cooldown()
