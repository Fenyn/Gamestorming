extends Node

## Player options, saved to user://settings.cfg.
## - control_hints: the controls strip shown at the bottom of the screen during a
##   mini-game.
## - assist_readouts: numbers for the current mini-game (temperature, foam,
##   pumps) shown above the controls strip, for players who can't read the
##   in-world gauges. F1 toggles it until there is a settings menu.

signal changed

const PATH := "user://settings.cfg"

var control_hints := true:
	set(v):
		control_hints = v
		_save()
var assist_readouts := false:
	set(v):
		assist_readouts = v
		_save()

var _loading := false

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	_loading = true
	control_hints = bool(cfg.get_value("assist", "control_hints", true))
	assist_readouts = bool(cfg.get_value("assist", "readouts", false))
	_loading = false

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F1:
		assist_readouts = not assist_readouts

func _save() -> void:
	changed.emit()
	if _loading:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("assist", "control_hints", control_hints)
	cfg.set_value("assist", "readouts", assist_readouts)
	cfg.save(PATH)
