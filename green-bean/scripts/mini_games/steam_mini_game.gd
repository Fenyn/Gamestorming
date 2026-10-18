class_name SteamMiniGame
extends BaseMiniGame

## Milk steaming, played like the real thing: the wand is fixed and you raise
## and lower the pitcher under it (mouse up / down) while holding the steam open.
## What matters is how deep the tip sits below the milk surface:
## - just under (TIP_ZONE): it pulls air in and builds microfoam (the "tearing"
##   hiss),
## - at or above the surface: it sprays and screeches and makes big bubbles,
## - deeper: it only heats and rolls the milk.
## Foam raises the surface, so the tip sinks deeper as you stretch and you lower
## the pitcher to follow it. Once the milk passes STRETCH_TEMP the pitcher goes
## back on the tray, where the foam has lifted the milk round the tip, and it
## keeps heating on its own (TEXTURING) until READY, then SCALDED if left. The
## station draws all of this; nothing here is visual.

enum SteamPhase { IDLE, STRETCHING, TEXTURING, READY, SCALDED }

const STRETCH_TEMP := 37.0
const TARGET_TEMP := 63.0
const SCALD_TEMP := 75.0
## The stretch lasts about 5 s of steam, long enough to reach a cappuccino's foam.
const ACTIVE_HEAT_RATE := 3.2
## Texturing and ready keep heating whether or not anyone is watching, since the
## wand has no auto shut-off: about 10 s to target, then about 5 s to scald.
const PASSIVE_HEAT_RATE := 2.5

## Tip depth below the surface (metres) that builds foam.
const TIP_ZONE := Vector2(0.002, 0.012)
## How far the pitcher can be lifted off the tray, and how far per mouse pixel.
const LIFT_MAX := 0.045
const LIFT_PER_PIXEL := 0.00012

const FOAM_RATE_GOOD := 0.18
const FOAM_RATE_BAD := 0.03

var target_foam := 0.5

var temperature := 20.0
var foam_level := 0.0
var steam_phase := SteamPhase.IDLE
var _steaming := false
var _has_been_started := false

## Pitcher lift off the tray (m), and the station's geometry: how far the tip
## sits above fresh milk with the pitcher resting, and how much foam raises the
## surface (m at foam 1).
var lift := 0.0
var tip_clearance := 0.008
var foam_rise_m := 0.024

func _ready() -> void:
	super._ready()
	station_name = "steam_wand"

func _on_start() -> void:
	if not _has_been_started:
		temperature = 20.0
		foam_level = 0.0
		steam_phase = SteamPhase.STRETCHING
		_has_been_started = true
		# Start with the tip just touching the milk.
		lift = clampf(tip_clearance, 0.0, LIFT_MAX)
	_steaming = false

func _on_stop() -> void:
	_steaming = false
	SoundManager.stop_loop("steam_hiss_good")
	SoundManager.stop_loop("steam_screech")
	SoundManager.stop_loop("steam_roll")

func get_controls_hint() -> String:
	match steam_phase:
		SteamPhase.STRETCHING:
			return hint([["Hold click", "Steam"], ["Mouse up / down", "Raise / lower pitcher"], ["E", "Leave"]])
		SteamPhase.READY:
			return hint([["Click", "Steam off"], ["E", "Leave"]])
	return hint([["E", "Leave"]])

func get_assist_readout() -> String:
	var line := "%d°C      Foam %d%% / %d%%" % [roundi(temperature), roundi(foam_level * 100.0), roundi(target_foam * 100.0)]
	if steam_phase == SteamPhase.STRETCHING and _steaming:
		var d := tip_depth()
		line += "      " + ("Too shallow" if d < TIP_ZONE.x else ("Too deep" if d > TIP_ZONE.y else "Stretching"))
	return line

func _process(delta: float) -> void:
	_tick_passive(delta)
	if is_playing():
		_update_mini_game(delta)

func _tick_passive(delta: float) -> void:
	if steam_phase != SteamPhase.TEXTURING and steam_phase != SteamPhase.READY:
		return
	if _lingering:
		return
	temperature += PASSIVE_HEAT_RATE * delta
	if temperature >= SCALD_TEMP:
		steam_phase = SteamPhase.SCALDED
		SoundManager.stop_loop("steam_texture_loop")
		SoundManager.play("milk_scald")
		if _active:
			end_after(0.8)
	elif temperature >= TARGET_TEMP and steam_phase == SteamPhase.TEXTURING:
		steam_phase = SteamPhase.READY
		SoundManager.play("milk_ready")

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
		if event is InputEventMouseMotion:
			lift = clampf(lift - event.relative.y * LIFT_PER_PIXEL, 0.0, LIFT_MAX)

## Tip depth below the milk surface in metres; negative when above it.
func tip_depth() -> float:
	return lift - tip_clearance + foam_level * foam_rise_m

func _is_in_zone() -> bool:
	var d := tip_depth()
	return d >= TIP_ZONE.x and d <= TIP_ZONE.y

func _update_mini_game(delta: float) -> void:
	if steam_phase != SteamPhase.STRETCHING:
		return
	if _steaming:
		temperature += ACTIVE_HEAT_RATE * delta
		var d := tip_depth()
		if _is_in_zone():
			foam_level += FOAM_RATE_GOOD * delta
			_set_loop("steam_hiss_good")
		elif d < TIP_ZONE.x:
			foam_level += FOAM_RATE_BAD * delta
			_set_loop("steam_screech")
		else:
			foam_level += FOAM_RATE_BAD * delta * 0.3
			_set_loop("steam_roll")
		foam_level = clampf(foam_level, 0.0, 1.0)
	else:
		_set_loop("")

	if temperature >= STRETCH_TEMP:
		steam_phase = SteamPhase.TEXTURING
		_steaming = false
		_set_loop("")
		SoundManager.play_loop("steam_texture_loop")
		end_after(0.5)

func _set_loop(sound: String) -> void:
	for s in ["steam_hiss_good", "steam_screech", "steam_roll"]:
		if s == sound:
			if not SoundManager.is_loop_playing(s):
				SoundManager.play_loop(s)
		else:
			SoundManager.stop_loop(s)

func _finish_steaming() -> void:
	SoundManager.stop_loop("steam_texture_loop")
	var temp_quality := 1.0 - absf(temperature - TARGET_TEMP) / (SCALD_TEMP - TARGET_TEMP)
	var foam_diff := absf(foam_level - target_foam) / maxf(target_foam, 0.1)
	var foam_quality := clampf(1.0 - foam_diff, 0.0, 1.0)
	var quality := (clampf(temp_quality, 0.0, 1.0) + foam_quality) / 2.0
	complete(quality, 0.4)

func set_foam_target(target: float) -> void:
	target_foam = target

func reset_steam() -> void:
	temperature = 20.0
	foam_level = 0.0
	lift = 0.0
	_steaming = false
	steam_phase = SteamPhase.IDLE
	_has_been_started = false

## Steam valve open: held during the stretch, always on while texturing.
func is_steaming() -> bool:
	return is_playing() and _steaming

func is_scalded() -> bool:
	return steam_phase == SteamPhase.SCALDED

func is_heating() -> bool:
	return steam_phase == SteamPhase.TEXTURING

func is_ready() -> bool:
	return steam_phase == SteamPhase.READY

func get_temperature() -> float:
	return temperature
