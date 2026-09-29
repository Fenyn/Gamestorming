class_name PhaseTrack
extends Node3D
## The turn's steps as icons on a band between the duelists, the current one lit in the turn
## owner's school colour and the owner's edge of the band lit. Reads the per-beat `live` stamp.

const LIT_SCALE: float = 1.3
const DONE_ALPHA: float = 0.5
const AHEAD_ALPHA: float = 0.22
const WARN_ALPHA: float = 0.75
const FADE: float = 0.18
const PULSE: float = 0.32
const SWEEP: float = 0.5
const SLIDE: float = 0.22
## The band's half extents on the table: x along the centre line, z across it.
const HALF_SIZE: Vector2 = Vector2(1.88, 0.135)
const POOL_OFFSET: float = 0.05
const POOL_ALPHA: float = 0.62
const EDGE_ALPHA: float = 1.0
## The school colour is theme, so a dark school is lifted until it reads on the band.
const MIN_VALUE: float = 0.85
## Icon nodes by key, in the order a turn visits them. Combat's keys are its five sub-steps.
const TURN_KEYS: Array[StringName] = [&"draw", &"place", &"power_up", &"declare"]
const COMBAT_KEYS: Array[StringName] = [&"enter", &"attack", &"defend", &"resolve", &"end"]
const CLOSE_KEYS: Array[StringName] = [&"discard", &"recover", &"turn_end"]
const NODE_NAMES: Dictionary = {
	&"draw": "Draw", &"place": "Place", &"power_up": "PowerUp", &"declare": "Declare",
	&"enter": "Enter", &"attack": "Attack", &"defend": "Defend", &"resolve": "Resolve", &"end": "End",
	&"discard": "Discard", &"recover": "Recover", &"turn_end": "TurnEnd",
}
const STEP_WORDS: Dictionary = {
	&"draw": "Draw", &"place": "Place", &"power_up": "Power Up", &"declare": "Declare",
	&"enter": "Enter", &"attack": "Attack", &"defend": "Defend", &"resolve": "Resolve", &"end": "End",
	&"discard": "Discard", &"recover": "Recover", &"turn_end": "End Turn",
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
@onready var band: MeshInstance3D = $Band
@onready var step_label: Label3D = $StepLabel

var lit: StringName = &""               # the key lit now, &"" when none is
var turn_seat: int = -1                  # whose turn the band shows, -1 when nobody's
var _viewer: int = 0
var _turn_color: Color = ZenithTheme.TEXT
var _material: ShaderMaterial
var _icons: Dictionary = {}              # key -> Sprite3D
var _states: Dictionary = {}             # key -> [color, scale] last applied
var _tweens: Dictionary = {}             # key -> Tween
var _sweep: Tween = null
var _slide: Tween = null


func _ready() -> void:
	_material = band.material_override as ShaderMaterial
	_material.set_shader_parameter("half_size", HALF_SIZE)
	_material.set_shader_parameter("edge_alpha", 0.0)
	_material.set_shader_parameter("edge_z", HALF_SIZE.y)
	_material.set_shader_parameter("edge_color", ZenithTheme.TEXT)
	_material.set_shader_parameter("pool_alpha", 0.0)
	_material.set_shader_parameter("pool_center", Vector2.ZERO)
	for key in NODE_NAMES.keys():
		var icon: Sprite3D = get_node(NodePath(str(NODE_NAMES[key])))
		_icons[key] = icon
		icon.modulate = Color(ZenithTheme.TEXT, AHEAD_ALPHA)


## The band on the table, the same for either viewer since it turns about its own centre.
static func band_rect() -> Rect2:
	return Rect2(-HALF_SIZE, HALF_SIZE * 2.0)


func order() -> Array[StringName]:
	var keys: Array[StringName] = []
	keys.append_array(TURN_KEYS)
	keys.append_array(COMBAT_KEYS)
	keys.append_array(CLOSE_KEYS)
	return keys


## Which key the table stands on: a turn step, or a Combat sub-step while Combat runs. &"" before
## the first turn and after the duel.
static func _readable(school: Color) -> Color:
	return Color.from_hsv(school.h, school.s, maxf(school.v, MIN_VALUE))


static func key_for(step: int, phase: int) -> StringName:
	if step == GameState.Step.COMBAT:
		return COMBAT_PHASES.get(phase, &"enter")
	return STEP_KEYS.get(step, &"")


## The seat whose side of the table is nearest the camera. The track turns to read for them.
func set_viewer(seat: int) -> void:
	rotation.y = PI if seat == 1 else 0.0
	if seat == _viewer:
		return
	_viewer = seat
	_show_turn(false)


func refresh(view: SeatView, live: Dictionary = {}) -> void:
	if view == null:
		return
	var step: int = int(live.get("step", view.step))
	var phase: int = int(live.get("phase", view.phase))
	var current: StringName = &"" if view.is_over() else key_for(step, phase)
	var seat: int = -1 if view.is_over() else int(live.get("active", view.active))
	var seat_color: Color = _readable(Palette.school_ui(view.player(seat).style)) if seat >= 0 and seat < view.players.size() else ZenithTheme.TEXT
	var keys: Array[StringName] = order()
	var at: int = keys.find(current)
	for i in range(keys.size()):
		var key: StringName = keys[i]
		var color: Color = ZenithTheme.TEXT
		var alpha: float = DONE_ALPHA if at >= 0 and i < at else AHEAD_ALPHA
		var size: float = 1.0
		if key == current:
			color = seat_color
			alpha = 1.0
			size = LIT_SCALE
		elif key == &"end" and step == GameState.Step.COMBAT and view.consecutive_passes == 1:
			color = ZenithTheme.WARN
			alpha = WARN_ALPHA
		_apply(key, Color(color, alpha), size)
	var turn_changed: bool = seat != turn_seat or not seat_color.is_equal_approx(_turn_color)
	var step_changed: bool = current != lit
	lit = current
	turn_seat = seat
	_turn_color = seat_color
	if turn_changed or step_changed:
		_show_turn(true)


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


## +1 when the lit edge is the viewer's near one, -1 the far one, 0 when no edge is lit.
func edge_side() -> float:
	if turn_seat < 0:
		return 0.0
	return 1.0 if turn_seat == _viewer else -1.0


## Where the lit edge and the pool are drawn now, in the band's own coordinates.
func edge_z() -> float:
	return float(_material.get_shader_parameter("edge_z"))


func edge_alpha() -> float:
	return float(_material.get_shader_parameter("edge_alpha"))


func pool_centre() -> Vector2:
	return _material.get_shader_parameter("pool_center")


func pool_alpha() -> float:
	return float(_material.get_shader_parameter("pool_alpha"))


func _show_turn(animated: bool) -> void:
	var side: float = edge_side()
	var lit_icon: Sprite3D = _icons.get(lit)
	step_label.visible = lit_icon != null
	step_label.text = str(STEP_WORDS.get(lit, ""))
	step_label.modulate = _turn_color.lerp(ZenithTheme.TEXT, 0.35)
	if _material == null:
		return
	_material.set_shader_parameter("pool_color", _turn_color)
	var pool_to: Vector2 = Vector2(lit_icon.position.x, POOL_OFFSET * side) if lit_icon != null else pool_centre()
	_kill_tween(_slide)
	var was_shown: bool = pool_alpha() > 0.0
	_material.set_shader_parameter("pool_alpha", POOL_ALPHA if lit_icon != null and side != 0.0 else 0.0)
	if not animated or reduced_motion or not is_inside_tree() or not was_shown:
		_material.set_shader_parameter("pool_center", pool_to)
	else:
		_slide = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_slide.tween_method(_set_pool, pool_centre(), pool_to, SLIDE)
	_kill_tween(_sweep)
	if side == 0.0:
		_material.set_shader_parameter("edge_alpha", 0.0)
		return
	var edge_to: float = HALF_SIZE.y * side
	var from_color: Color = _material.get_shader_parameter("edge_color")
	var crossing: bool = edge_alpha() > 0.0 and not is_equal_approx(edge_z(), edge_to)
	_material.set_shader_parameter("edge_alpha", EDGE_ALPHA)
	if not animated or not crossing or reduced_motion or not is_inside_tree():
		_material.set_shader_parameter("edge_z", edge_to)
		_material.set_shader_parameter("edge_color", _turn_color)
		return
	_sweep = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sweep.tween_method(_set_edge.bind(edge_z(), edge_to, from_color, _turn_color), 0.0, 1.0, SWEEP)


func _set_pool(at: Vector2) -> void:
	_material.set_shader_parameter("pool_center", at)


func _set_edge(t: float, from_z: float, to_z: float, from_color: Color, to_color: Color) -> void:
	_material.set_shader_parameter("edge_z", lerpf(from_z, to_z, t))
	_material.set_shader_parameter("edge_color", from_color.lerp(to_color, t))


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


func _kill(key: StringName) -> void:
	_kill_tween(_tweens.get(key))
	_tweens.erase(key)


func _kill_tween(running: Variant) -> void:
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
