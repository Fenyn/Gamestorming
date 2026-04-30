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

# WebSocket state
var _ws: WebSocketPeer
var _ws_reconnect_timer: float = 0.0
var _ws_was_connected: bool = false

# Demo simulation state
var _demo_phase_index: int = 0
var _demo_phase_timer: float = 0.0
var _demo_hr: float = 68.0
var _demo_time: float = 0.0

const DEMO_WORKOUT := [
	{"name": "REST",           "target": 68,  "variance": 4,  "duration": 8.0,  "ramp": 0.05},
	{"name": "WARMUP",         "target": 95,  "variance": 5,  "duration": 20.0, "ramp": 0.08},
	{"name": "LIFTING SET 1",  "target": 135, "variance": 8,  "duration": 30.0, "ramp": 0.12},
	{"name": "REST",           "target": 100, "variance": 5,  "duration": 8.0,  "ramp": 0.10},
	{"name": "LIFTING SET 2",  "target": 145, "variance": 10, "duration": 28.0, "ramp": 0.12},
	{"name": "REST",           "target": 105, "variance": 5,  "duration": 8.0,  "ramp": 0.10},
	{"name": "LIFTING SET 3",  "target": 155, "variance": 12, "duration": 25.0, "ramp": 0.14},
	{"name": "REST",           "target": 110, "variance": 6,  "duration": 8.0,  "ramp": 0.10},
	{"name": "HEAVY SET",      "target": 170, "variance": 10, "duration": 22.0, "ramp": 0.15},
	{"name": "REST",           "target": 115, "variance": 6,  "duration": 8.0,  "ramp": 0.10},
	{"name": "LIFTING SET 4",  "target": 148, "variance": 10, "duration": 28.0, "ramp": 0.12},
	{"name": "COOLDOWN",       "target": 90,  "variance": 5,  "duration": 15.0, "ramp": 0.06},
	{"name": "REST",           "target": 72,  "variance": 3,  "duration": 10.0, "ramp": 0.05},
]


func _ready() -> void:
	current_bpm = GameState.settings.get("simulated_bpm", 80.0)
	smoothed_bpm = current_bpm
	source = GameState.settings.get("hr_source", "demo")

	if source == "websocket":
		_ws_connect()


func _process(delta: float) -> void:
	match source:
		"simulated":
			current_bpm = GameState.settings.get("simulated_bpm", 80.0)
			current_phase = ""
		"demo":
			_process_demo(delta)
		"websocket":
			_process_websocket(delta)

	smoothed_bpm = lerpf(smoothed_bpm, current_bpm, SMOOTH_FACTOR)

	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		var factor := get_hr_factor()
		if not is_equal_approx(factor, _last_factor):
			_last_factor = factor
			EventBus.heart_rate_updated.emit(smoothed_bpm, factor)


# --- Demo simulation ---

func _process_demo(delta: float) -> void:
	_demo_time += delta
	var phase: Dictionary = DEMO_WORKOUT[_demo_phase_index]

	var target: float = phase["target"] + sin(_demo_time * 0.7) * phase["variance"] * 0.3
	_demo_hr += (target - _demo_hr) * phase["ramp"]

	var noise := sin(_demo_time * 2.3) * 1.2 + sin(_demo_time * 0.4) * 0.8
	current_bpm = maxf(45.0, _demo_hr + noise)
	current_phase = phase["name"]

	_demo_phase_timer += delta
	if _demo_phase_timer >= phase["duration"]:
		_demo_phase_timer = 0.0
		_demo_phase_index = (_demo_phase_index + 1) % DEMO_WORKOUT.size()


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
	_demo_phase_index = 0
	_demo_phase_timer = 0.0
	_demo_hr = 68.0
	_demo_time = 0.0
	current_phase = ""
	current_bpm = GameState.settings.get("simulated_bpm", 80.0)
	smoothed_bpm = current_bpm


func get_hr_factor() -> float:
	var age: float = GameState.settings.get("age", 30.0)
	var resting := GameFormulas.resting_heart_rate(age)
	var cap_pct: float = GameState.settings.get("hr_cap_pct", 0.85)
	var max_hr := GameFormulas.max_heart_rate(age)
	return GameFormulas.hr_speed_factor(smoothed_bpm, resting, max_hr, cap_pct)


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
			_demo_phase_index = 0
			_demo_phase_timer = 0.0
			_demo_hr = 68.0
			_demo_time = 0.0
		_:
			pass

	if new_source != "websocket":
		if _ws:
			_ws.close()
			_ws = null
		is_connected = false
		_ws_was_connected = false

	EventBus.heart_rate_source_changed.emit(new_source)
