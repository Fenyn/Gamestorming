class_name PhaseTrack
extends Node3D
## The turn printed on the table as a row of icons along the waist: the turn's opening steps in
## the left notch, Combat's five across the ring, the closing steps in the right notch. The step
## the beat stands on is lit, the ones behind it are dimmed, the ones ahead are faint. It reads the
## same per-beat `live` stamp as everything else a replay draws.

const LIT_SCALE: float = 1.25
const DONE_ALPHA: float = 0.5
const AHEAD_ALPHA: float = 0.2
const WARN_ALPHA: float = 0.75
const HALO_ALPHA: float = 0.45
const FADE: float = 0.18
const PULSE: float = 0.32
## Icon nodes by key, in the order a turn visits them. Combat's keys are its five sub-steps.
const TURN_KEYS: Array[StringName] = [&"draw", &"place", &"power_up", &"declare"]
const COMBAT_KEYS: Array[StringName] = [&"enter", &"attack", &"defend", &"resolve", &"end"]
const CLOSE_KEYS: Array[StringName] = [&"discard", &"recover", &"turn_end"]
const NODE_NAMES: Dictionary = {
	&"draw": "Draw", &"place": "Place", &"power_up": "PowerUp", &"declare": "Declare",
	&"enter": "Enter", &"attack": "Attack", &"defend": "Defend", &"resolve": "Resolve", &"end": "End",
	&"discard": "Discard", &"recover": "Recover", &"turn_end": "TurnEnd",
}
const STEP_KEYS: Dictionary = {
	GameState.Step.DRAW: &"draw", GameState.Step.NON_COMBAT: &"place", GameState.Step.POWER_UP: &"power_up",
	GameState.Step.DECLARE: &"declare", GameState.Step.DISCARD: &"discard", GameState.Step.RECOVER: &"recover",
	GameState.Step.TURN_END: &"turn_end",
}
## Which Combat sub-step each engine phase belongs to. A fight back is the Attack step again with
## the other seat attacking.
const COMBAT_PHASES: Dictionary = {
	GameState.Phase.PREPARE_ACTIVE: &"enter", GameState.Phase.PREPARE_OPPOSING: &"enter",
	GameState.Phase.OPPOSING_DRAW: &"enter", GameState.Phase.ATTACK: &"attack",
	GameState.Phase.FIGHT_BACK: &"attack", GameState.Phase.DEFEND: &"defend",
	GameState.Phase.BATTLE: &"resolve", GameState.Phase.COMBAT_END: &"end",
}

@export var reduced_motion: bool = false
@onready var halo: Sprite3D = $Halo

var lit: StringName = &""               # the key lit now, &"" when none is
var _icons: Dictionary = {}              # key -> Sprite3D
var _states: Dictionary = {}             # key -> [alpha, scale, color] last applied
var _tweens: Dictionary = {}             # key -> Tween


func _ready() -> void:
	for key in NODE_NAMES.keys():
		var icon: Sprite3D = get_node(NodePath(str(NODE_NAMES[key])))
		_icons[key] = icon
		icon.modulate = Color(ZenithTheme.TEXT, AHEAD_ALPHA)


func order() -> Array[StringName]:
	var keys: Array[StringName] = []
	keys.append_array(TURN_KEYS)
	keys.append_array(COMBAT_KEYS)
	keys.append_array(CLOSE_KEYS)
	return keys


## Which key the table stands on: a turn step, or a Combat sub-step while Combat runs. &"" before
## the first turn and after the duel.
static func key_for(step: int, phase: int) -> StringName:
	if step == GameState.Step.COMBAT:
		return COMBAT_PHASES.get(phase, &"enter")
	return STEP_KEYS.get(step, &"")


## The track as the beat reads: the lit step in its own colour (attack red on Attack, defence on
## Defend), everything the turn has passed dimmed, everything ahead faint, and the End icon warm
## once one more pass would close Combat.
func refresh(view: SeatView, live: Dictionary = {}) -> void:
	if view == null:
		return
	var step: int = int(live.get("step", view.step))
	var phase: int = int(live.get("phase", view.phase))
	var current: StringName = &"" if view.is_over() else key_for(step, phase)
	var keys: Array[StringName] = order()
	var at: int = keys.find(current)
	for i in range(keys.size()):
		var key: StringName = keys[i]
		var color: Color = ZenithTheme.TEXT
		var alpha: float = DONE_ALPHA if at >= 0 and i < at else AHEAD_ALPHA
		var size: float = 1.0
		if key == current:
			color = _lit_color(key)
			alpha = 1.0
			size = LIT_SCALE
		elif key == &"end" and step == GameState.Step.COMBAT and view.consecutive_passes == 1:
			color = ZenithTheme.WARN
			alpha = WARN_ALPHA
		_apply(key, Color(color, alpha), size)
	lit = current
	_place_halo()


## A beat that happened on a step without moving the track (a pass, a window that opened on
## nothing) flashes that step's icon.
func pulse(key: StringName) -> void:
	var icon: Sprite3D = _icons.get(key)
	if icon == null or reduced_motion:
		return
	# Settle on the state `refresh` last asked for, not on the colour caught mid-fade, or an icon
	# pulsed while dimming would stay bright.
	var state: Array = _states.get(key, [icon.modulate, 1.0])
	var rest: Color = state[0]
	_kill(key)
	icon.modulate = Color(rest.lightened(0.4), 1.0)
	icon.scale = Vector3.ONE * float(state[1])
	var t: Tween = create_tween()
	t.tween_property(icon, "modulate", rest, PULSE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens[key] = t


func icon(key: StringName) -> Sprite3D:
	return _icons.get(key)


func _lit_color(key: StringName) -> Color:
	if key == &"attack":
		return ZenithTheme.ATTACK
	if key == &"defend":
		return DuelFx.WARD_TONE
	return ZenithTheme.TEXT


func _apply(key: StringName, color: Color, size: float) -> void:
	var state: Array = [color, size]
	if _states.get(key, []) == state:
		return
	_states[key] = state
	var icon: Sprite3D = _icons[key]
	_kill(key)
	if reduced_motion or not is_inside_tree():
		icon.modulate = color
		icon.scale = Vector3.ONE * size
		return
	var t: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(icon, "modulate", color, FADE)
	t.tween_property(icon, "scale", Vector3.ONE * size, FADE)
	_tweens[key] = t


func _place_halo() -> void:
	var icon: Sprite3D = _icons.get(lit)
	halo.visible = icon != null
	if icon == null:
		return
	halo.position = Vector3(icon.position.x, halo.position.y, icon.position.z)
	halo.modulate = Color(_lit_color(lit), HALO_ALPHA)


func _kill(key: StringName) -> void:
	var running: Variant = _tweens.get(key)
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
	_tweens.erase(key)
