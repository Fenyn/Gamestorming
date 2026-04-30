class_name SteamMiniGame
extends BaseMiniGame

enum SteamPhase { IDLE, STRETCHING, TEXTURING, READY, SCALDED }

const STRETCH_TEMP := 37.0
const TARGET_TEMP := 63.0
const SCALD_TEMP := 75.0
const ACTIVE_HEAT_RATE := 6.5
const PASSIVE_HEAT_RATE := 5.2

# The sweet spot is narrow and sinks as milk volume rises
const ZONE_SIZE := 0.12
const ZONE_START_CENTER := 0.15
const ZONE_END_CENTER := 0.75
const WAND_SENSITIVITY := 0.005

const FOAM_RATE_GOOD := 0.18
const FOAM_RATE_BAD := 0.03
const TARGET_FOAM := 0.7
const BAR_WIDTH := 0.2

var temperature := 20.0
var foam_level := 0.0
var wand_depth := 0.15
var steam_phase := SteamPhase.IDLE
var _steaming := false
var _has_been_started := false
var _stretch_progress := 0.0

var _status_label: Label3D = null
var _temp_bar_bg: CSGBox3D = null
var _temp_bar_fill: CSGBox3D = null
var _foam_bar_bg: CSGBox3D = null
var _foam_bar_fill: CSGBox3D = null
var _depth_bar_bg: CSGBox3D = null
var _depth_indicator: CSGBox3D = null
var _zone_marker: CSGBox3D = null

func _ready() -> void:
	super._ready()
	station_name = "steam_wand"

	_status_label = Label3D.new()
	_status_label.text = ""
	_status_label.font_size = 14
	_status_label.position = Vector3(0, 0.28, 0.18)
	_status_label.pixel_size = 0.001
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_status_label)

	# Temperature bar (horizontal, top)
	_temp_bar_bg = _make_hbar(Vector3(0, 0.22, 0.18), Color(0.2, 0.2, 0.2))
	_temp_bar_fill = _make_hbar(Vector3(-BAR_WIDTH / 2.0, 0.22, 0.18), Color(0.9, 0.5, 0.2))

	# Foam bar (horizontal, below temp)
	_foam_bar_bg = _make_hbar(Vector3(0, 0.18, 0.18), Color(0.2, 0.2, 0.2))
	_foam_bar_fill = _make_hbar(Vector3(-BAR_WIDTH / 2.0, 0.18, 0.18), Color(0.85, 0.85, 0.9))

	# Depth gauge (vertical bar on left side)
	_depth_bar_bg = CSGBox3D.new()
	_depth_bar_bg.size = Vector3(0.015, 0.14, 0.015)
	_depth_bar_bg.position = Vector3(-0.14, 0.15, 0.18)
	var dbg := StandardMaterial3D.new()
	dbg.albedo_color = Color(0.15, 0.15, 0.15)
	_depth_bar_bg.material = dbg
	add_child(_depth_bar_bg)

	# Sweet spot zone (green band on the depth gauge)
	_zone_marker = CSGBox3D.new()
	_zone_marker.size = Vector3(0.018, 0.02, 0.012)
	_zone_marker.position = Vector3(-0.14, 0.20, 0.18)
	var zm := StandardMaterial3D.new()
	zm.albedo_color = Color(0.2, 0.7, 0.2, 0.6)
	_zone_marker.material = zm
	add_child(_zone_marker)

	# Wand position indicator (player's current depth)
	_depth_indicator = CSGBox3D.new()
	_depth_indicator.size = Vector3(0.022, 0.012, 0.016)
	_depth_indicator.position = Vector3(-0.14, 0.20, 0.18)
	var di := StandardMaterial3D.new()
	di.albedo_color = Color(0.9, 0.9, 0.2)
	_depth_indicator.material = di
	add_child(_depth_indicator)

func _make_hbar(pos: Vector3, color: Color) -> CSGBox3D:
	var bar := CSGBox3D.new()
	bar.size = Vector3(BAR_WIDTH if pos.x == 0 else 0.001, 0.012, 0.012 if pos.x == 0 else 0.013)
	bar.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bar.material = mat
	add_child(bar)
	return bar

func _on_start() -> void:
	if not _has_been_started:
		temperature = 20.0
		foam_level = 0.0
		wand_depth = 0.15
		steam_phase = SteamPhase.STRETCHING
		_stretch_progress = 0.0
		_has_been_started = true
	_steaming = false
	_update_status()
	_update_bars()

func _on_stop() -> void:
	_steaming = false

func _process(delta: float) -> void:
	_tick_passive(delta)
	if _active:
		_update_mini_game(delta)

func _tick_passive(delta: float) -> void:
	if steam_phase == SteamPhase.TEXTURING and not _active:
		temperature += PASSIVE_HEAT_RATE * delta
		if temperature >= TARGET_TEMP:
			steam_phase = SteamPhase.READY
		if temperature >= SCALD_TEMP:
			steam_phase = SteamPhase.SCALDED

func _handle_input(event: InputEvent) -> void:
	if steam_phase == SteamPhase.SCALDED:
		return
	if steam_phase == SteamPhase.READY:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_finish_steaming()
		return

	if steam_phase == SteamPhase.STRETCHING:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_steaming = event.pressed
		if event is InputEventMouseMotion and _steaming:
			wand_depth += event.relative.y * WAND_SENSITIVITY
			wand_depth = clampf(wand_depth, 0.0, 1.0)

func _get_zone_center() -> float:
	return lerpf(ZONE_START_CENTER, ZONE_END_CENTER, _stretch_progress)

func _is_in_zone() -> bool:
	var center := _get_zone_center()
	return absf(wand_depth - center) <= ZONE_SIZE / 2.0

func _update_mini_game(delta: float) -> void:
	if steam_phase == SteamPhase.SCALDED or steam_phase == SteamPhase.READY:
		_update_status()
		_update_bars()
		return

	if steam_phase == SteamPhase.TEXTURING:
		_update_status()
		_update_bars()
		return

	if steam_phase == SteamPhase.STRETCHING:
		if _steaming:
			temperature += ACTIVE_HEAT_RATE * delta
			_stretch_progress = clampf((temperature - 20.0) / (STRETCH_TEMP - 20.0), 0.0, 1.0)

			if _is_in_zone():
				foam_level += FOAM_RATE_GOOD * delta
			else:
				foam_level += FOAM_RATE_BAD * delta
			foam_level = clampf(foam_level, 0.0, 1.0)

		if temperature >= STRETCH_TEMP:
			steam_phase = SteamPhase.TEXTURING
			_steaming = false
			stop()
			return

		if temperature >= SCALD_TEMP:
			steam_phase = SteamPhase.SCALDED
			complete(0.0)
			return

	_update_status()
	_update_bars()

func _update_status() -> void:
	if not _status_label or not _active:
		return
	match steam_phase:
		SteamPhase.STRETCHING:
			var in_zone := _is_in_zone()
			_status_label.text = "STRETCH  %.0f C  [%s]\nHold LClick, track the zone down\nFoam: %.0f%%" % [
				temperature, "GOOD" if in_zone else "---", foam_level * 100
			]
		SteamPhase.TEXTURING:
			_status_label.text = "TEXTURING  %.0f C\nPress E to walk away" % temperature
		SteamPhase.READY:
			_status_label.text = "%.0f C  READY!\nLClick to finish" % temperature
		SteamPhase.SCALDED:
			_status_label.text = "SCALDED!\nPress E"

func _update_bars() -> void:
	# Temperature bar
	var temp_ratio := clampf((temperature - 20.0) / (SCALD_TEMP - 20.0), 0.0, 1.0)
	_fill_hbar(_temp_bar_fill, temp_ratio)
	var tm := _temp_bar_fill.material as StandardMaterial3D
	if tm:
		if temperature >= SCALD_TEMP * 0.95:
			tm.albedo_color = Color(1.0, 0.2, 0.2)
		elif temperature >= TARGET_TEMP * 0.9:
			tm.albedo_color = Color(0.2, 0.9, 0.3)
		else:
			tm.albedo_color = Color(0.9, 0.5, 0.2)

	# Foam bar
	_fill_hbar(_foam_bar_fill, clampf(foam_level, 0.0, 1.0))

	# Depth gauge: wand indicator position
	if _depth_indicator and _depth_bar_bg:
		var y_top := _depth_bar_bg.position.y + 0.07
		var y_bot := _depth_bar_bg.position.y - 0.07
		_depth_indicator.position.y = lerpf(y_top, y_bot, wand_depth)
		var di_mat := _depth_indicator.material as StandardMaterial3D
		if di_mat:
			di_mat.albedo_color = Color(0.2, 0.9, 0.3) if _is_in_zone() else Color(0.9, 0.3, 0.2)

	# Zone marker: sweet spot that sinks
	if _zone_marker and _depth_bar_bg:
		var y_top := _depth_bar_bg.position.y + 0.07
		var y_bot := _depth_bar_bg.position.y - 0.07
		var center := _get_zone_center()
		_zone_marker.position.y = lerpf(y_top, y_bot, center)
		var zone_visual_h := (y_top - y_bot) * ZONE_SIZE
		_zone_marker.size.y = maxf(zone_visual_h, 0.01)

func _fill_hbar(bar: CSGBox3D, ratio: float) -> void:
	if not bar:
		return
	var w := BAR_WIDTH * ratio
	bar.size.x = maxf(w, 0.001)
	bar.position.x = -BAR_WIDTH / 2.0 + w / 2.0

func _finish_steaming() -> void:
	var temp_quality := 1.0 - absf(temperature - TARGET_TEMP) / (SCALD_TEMP - TARGET_TEMP)
	var foam_quality := 1.0 - absf(foam_level - TARGET_FOAM) / TARGET_FOAM
	var quality := (clampf(temp_quality, 0.0, 1.0) + clampf(foam_quality, 0.0, 1.0)) / 2.0
	complete(quality)

func reset_steam() -> void:
	temperature = 20.0
	foam_level = 0.0
	wand_depth = 0.15
	_steaming = false
	steam_phase = SteamPhase.IDLE
	_stretch_progress = 0.0
	_has_been_started = false

func is_scalded() -> bool:
	return steam_phase == SteamPhase.SCALDED

func is_heating() -> bool:
	return steam_phase == SteamPhase.TEXTURING

func is_ready() -> bool:
	return steam_phase == SteamPhase.READY

func get_temperature() -> float:
	return temperature
