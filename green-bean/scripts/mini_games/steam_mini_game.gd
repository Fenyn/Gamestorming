class_name SteamMiniGame
extends BaseMiniGame

const TARGET_TEMP := 65.0
const SCALD_TEMP := 80.0
const HEAT_RATE := 15.0
const PASSIVE_HEAT_RATE := 10.0
const IDEAL_DEPTH_MIN := 0.3
const IDEAL_DEPTH_MAX := 0.6
const FOAM_RATE := 0.2
const TARGET_FOAM := 0.7

var temperature := 20.0
var foam_level := 0.0
var wand_depth := 0.5
var _steaming := false
var _scalded := false
var _finished := false
var _heating := false

var _status_label: Label3D = null

func _ready() -> void:
	super._ready()
	station_name = "steam_wand"

	_status_label = Label3D.new()
	_status_label.text = "Hold LClick to steam\nMove mouse up/down for depth"
	_status_label.font_size = 12
	_status_label.position = Vector3(0, 0.35, 0.01)
	_status_label.pixel_size = 0.002
	add_child(_status_label)

func _on_start() -> void:
	temperature = 20.0
	foam_level = 0.0
	wand_depth = 0.5
	_steaming = false
	_scalded = false
	_finished = false
	_heating = true
	_update_status()

func _on_stop() -> void:
	_steaming = false

func _process(delta: float) -> void:
	_tick_passive(delta)
	if _active:
		_update_mini_game(delta)

func _tick_passive(delta: float) -> void:
	if not _heating or _scalded or _finished:
		return
	if _active:
		return
	temperature += PASSIVE_HEAT_RATE * delta
	if temperature >= SCALD_TEMP:
		_scalded = true
		_heating = false
		if _status_label:
			_status_label.text = "SCALDED!"

func _handle_input(event: InputEvent) -> void:
	if _scalded or _finished:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_steaming = event.pressed
		if not event.pressed and temperature >= TARGET_TEMP * 0.8:
			_finish_steaming()

	if event is InputEventMouseMotion and _steaming:
		wand_depth += event.relative.y * 0.005
		wand_depth = clampf(wand_depth, 0.0, 1.0)

func _update_mini_game(delta: float) -> void:
	if _finished or _scalded:
		return

	if not _steaming:
		_update_status()
		return

	temperature += HEAT_RATE * delta

	if wand_depth >= IDEAL_DEPTH_MIN and wand_depth <= IDEAL_DEPTH_MAX:
		foam_level += FOAM_RATE * delta
	elif wand_depth < IDEAL_DEPTH_MIN:
		foam_level += FOAM_RATE * 0.1 * delta

	foam_level = clampf(foam_level, 0.0, 1.0)

	if temperature >= SCALD_TEMP:
		_scalded = true
		_steaming = false
		_heating = false
		if _status_label:
			_status_label.text = "SCALDED! Press E to exit"
		complete(0.0)
		return

	_update_status()

func _update_status() -> void:
	if not _status_label or not _active:
		return
	if _scalded:
		_status_label.text = "SCALDED!"
		return
	if _finished:
		_status_label.text = "DONE! Press E to exit"
		return
	var temp_str := "Temp: %.0f/%.0f C" % [temperature, TARGET_TEMP]
	var foam_str := "Foam: %.0f%%" % (foam_level * 100)
	var depth_str := "Depth: %.0f%%" % (wand_depth * 100)
	var zone := "GOOD" if wand_depth >= IDEAL_DEPTH_MIN and wand_depth <= IDEAL_DEPTH_MAX else "---"
	_status_label.text = "%s\n%s  %s  [%s]\nHold LClick + move mouse" % [temp_str, foam_str, depth_str, zone]

func _finish_steaming() -> void:
	_finished = true
	_heating = false
	var temp_quality := 1.0 - absf(temperature - TARGET_TEMP) / (SCALD_TEMP - TARGET_TEMP)
	var foam_quality := 1.0 - absf(foam_level - TARGET_FOAM) / TARGET_FOAM
	var quality := (clampf(temp_quality, 0.0, 1.0) + clampf(foam_quality, 0.0, 1.0)) / 2.0
	complete(quality)

func reset_steam() -> void:
	temperature = 20.0
	foam_level = 0.0
	wand_depth = 0.5
	_steaming = false
	_scalded = false
	_finished = false
	_heating = false
	if _status_label:
		_status_label.text = "Hold LClick to steam\nMove mouse up/down for depth"

func is_scalded() -> bool:
	return _scalded

func is_heating() -> bool:
	return _heating

func get_temperature() -> float:
	return temperature
