extends Node

var current_bpm: float = 80.0
var smoothed_bpm: float = 80.0
var source: String = "demo"
var is_connected: bool = false
var current_phase: String = ""

const SMOOTH_FACTOR := 0.15
const UPDATE_INTERVAL := 0.25
const WS_URL := "ws://localhost:9876"
const RECONNECT_DELAY := 3.0

var _update_timer: float = 0.0
var _last_factor: float = -1.0
var _beat_accumulator: float = 0.0
var _vitality_beat_counter: int = 0
var _step_poll_timer: float = 0.0
var _last_known_steps: int = 0

const VITALITY_PER_1000_STEPS := 1.0
const VITALITY_BEATS_FALLBACK := 500
const STEP_POLL_INTERVAL := 60.0

# WebSocket state
var _ws: WebSocketPeer
var _ws_reconnect_timer: float = 0.0
var _ws_was_connected: bool = false

# Demo simulation state
var _demo_hr: float = 68.0
var _demo_time: float = 0.0

const DEMO_TAP_BOOST := 4.0
const DEMO_DECAY_RATE := 5.0


func _ready() -> void:
	current_bpm = GameState.get_simulated_bpm()
	smoothed_bpm = current_bpm
	source = GameState.get_hr_source()

	if source == "websocket":
		_ws_connect()


func _process(delta: float) -> void:
	match source:
		"simulated":
			current_bpm = GameState.get_simulated_bpm()
			current_phase = ""
		"demo":
			_process_demo(delta)
		"websocket":
			_process_websocket(delta)
		"health_connect":
			_process_health_connect()

	smoothed_bpm = lerpf(smoothed_bpm, current_bpm, SMOOTH_FACTOR)

	if smoothed_bpm > 0.0:
		var beat_interval := 60.0 / smoothed_bpm
		_beat_accumulator += delta
		if _beat_accumulator >= beat_interval:
			_beat_accumulator -= beat_interval
			EventBus.heartbeat_fired.emit()
			_accumulate_vitality_from_beats()

	_poll_steps(delta)
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		var factor := get_hr_factor()
		if not is_equal_approx(factor, _last_factor):
			_last_factor = factor
			EventBus.heart_rate_updated.emit(smoothed_bpm, factor)


# --- Demo simulation (tap to raise HR) ---

func demo_tap() -> void:
	var max_hr := GameFormulas.max_heart_rate(GameState.get_age())
	var headroom := (max_hr - _demo_hr) / maxf(max_hr - 60.0, 1.0)
	_demo_hr += DEMO_TAP_BOOST * maxf(headroom, 0.1)
	_demo_hr = minf(_demo_hr, max_hr)


func _process_demo(delta: float) -> void:
	_demo_time += delta
	var resting := GameFormulas.resting_heart_rate(GameState.get_age())

	if _demo_hr > resting:
		_demo_hr -= DEMO_DECAY_RATE * delta
		_demo_hr = maxf(_demo_hr, resting)

	var noise := sin(_demo_time * 1.5) * 0.8
	current_bpm = maxf(resting - 2.0, _demo_hr + noise)
	current_phase = ""


# --- WebSocket ---

func _process_websocket(delta: float) -> void:
	if not _ws:
		_ws_reconnect_timer += delta
		if _ws_reconnect_timer >= RECONNECT_DELAY:
			_ws_reconnect_timer = 0.0
			_ws_connect()
		return

	_ws.poll()
	var state := _ws.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if not _ws_was_connected:
				_ws_was_connected = true
				is_connected = true
				EventBus.heart_rate_source_changed.emit("websocket")
				EventBus.notification.emit("HR monitor connected!", "info")

			while _ws.get_available_packet_count() > 0:
				var pkt := _ws.get_packet()
				_parse_hr_message(pkt.get_string_from_utf8())

		WebSocketPeer.STATE_CLOSED:
			if _ws_was_connected:
				_ws_was_connected = false
				is_connected = false
				EventBus.notification.emit("HR monitor disconnected.", "warning")
			_ws = null
			_ws_reconnect_timer = 0.0


func _ws_connect() -> void:
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(WS_URL)
	if err != OK:
		_ws = null


func _parse_hr_message(text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data: Dictionary = json.data
	if data.get("type") == "heart_rate":
		var bpm: float = data.get("bpm", 0.0)
		if bpm > 0.0:
			current_bpm = bpm
		current_phase = data.get("phase", "")


# --- Public API ---

func reset_to_defaults() -> void:
	_demo_hr = GameFormulas.resting_heart_rate(GameState.get_age())
	_demo_time = 0.0
	_beat_accumulator = 0.0
	_vitality_beat_counter = 0
	_step_poll_timer = 0.0
	_last_known_steps = 0
	current_phase = ""
	current_bpm = GameState.get_simulated_bpm()
	smoothed_bpm = current_bpm


func get_hr_factor() -> float:
	var age := GameState.get_age()
	var resting := GameFormulas.resting_heart_rate(age)
	var max_hr := GameFormulas.max_heart_rate(age)
	return GameFormulas.hr_speed_factor(smoothed_bpm, resting, max_hr, GameState.get_hr_cap_pct())


func _accumulate_vitality_from_beats() -> void:
	if source == "health_connect":
		return
	_vitality_beat_counter += 1
	if _vitality_beat_counter >= VITALITY_BEATS_FALLBACK:
		_vitality_beat_counter = 0
		GameState.add_vitality(1.0)


func _poll_steps(delta: float) -> void:
	if source != "health_connect" or not _hc_plugin:
		return
	_step_poll_timer += delta
	if _step_poll_timer < STEP_POLL_INTERVAL:
		return
	_step_poll_timer = 0.0
	var current_steps: int = _hc_plugin.getDailySteps()
	if _last_known_steps <= 0:
		_last_known_steps = current_steps
		return
	var step_delta := current_steps - _last_known_steps
	if step_delta > 0:
		_last_known_steps = current_steps
		var vitality_earned := float(step_delta) / 1000.0 * VITALITY_PER_1000_STEPS
		if vitality_earned > 0.0:
			GameState.add_vitality(vitality_earned)


func set_simulated_bpm(bpm: float) -> void:
	GameState.settings["simulated_bpm"] = bpm
	if source == "simulated":
		current_bpm = bpm


func set_source(new_source: String) -> void:
	source = new_source
	GameState.settings["hr_source"] = new_source

	match new_source:
		"websocket":
			_ws_connect()
		"demo":
			_demo_hr = GameFormulas.resting_heart_rate(GameState.get_age())
			_demo_time = 0.0
		"health_connect":
			_start_health_connect()
		_:
			pass

	if new_source != "websocket":
		if _ws:
			_ws.close()
			_ws = null
		is_connected = false
		_ws_was_connected = false

	if new_source != "health_connect":
		_stop_health_connect()

	EventBus.heart_rate_source_changed.emit(new_source)


# --- Health Connect ---

var _hc_plugin = null


func is_health_connect_available() -> bool:
	if _hc_plugin:
		return _hc_plugin.isHealthConnectAvailable()
	if Engine.has_singleton("HealthConnect"):
		_hc_plugin = Engine.get_singleton("HealthConnect")
		return _hc_plugin.isHealthConnectAvailable()
	return false


func _start_health_connect() -> void:
	if not is_health_connect_available():
		EventBus.notification.emit("Health Connect not available on this device.", "warning")
		return
	if not _hc_plugin.checkPermissions():
		_hc_plugin.requestPermissions()
		EventBus.notification.emit("Please grant health permissions.", "info")
		return
	_hc_plugin.startPolling()
	is_connected = true
	EventBus.notification.emit("Health Connect active!", "info")


func _stop_health_connect() -> void:
	if _hc_plugin:
		_hc_plugin.stopPolling()
	is_connected = false


func _process_health_connect() -> void:
	if not _hc_plugin:
		return
	var hr: int = _hc_plugin.getLatestHR()
	if hr > 0:
		current_bpm = float(hr)
	current_phase = ""


func get_daily_steps() -> int:
	if _hc_plugin and source == "health_connect":
		return _hc_plugin.getDailySteps()
	return 0
