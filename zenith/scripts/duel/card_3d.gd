class_name Card3D
extends Node3D
## One card on the table: face and back quads, a frame glow (blue when usable now, bone-white for
## a target or pick), a wider role aura, and a pick area. The quads sit
## under `Body`, which shakes and lunges on its own so the table can tween the card's transform.

signal clicked(uid: int)
signal hovered(uid: int, over: bool)
signal inspected(uid: int)   # right-click: bring the card up to read
signal motion_done           # the Body motion now running ended or was replaced

const FLIP_DURATION: float = 0.25
const FLASH_TIME: float = 0.35
const SHAKE_TIME: float = 0.32
const WINDUP_TIME: float = 0.14
const WINDUP_DISTANCE: float = 0.10
const STRIKE_TIME: float = 0.08
const RECOIL_TIME: float = 0.22
## When a lunge's strike makes contact, for a caller timing the streak to it.
const LUNGE_TIME: float = WINDUP_TIME + STRIKE_TIME
## How far under the face the underlays lie, in world units. Slots scale the whole basis, so
## `_keep_underlays` holds these fixed rather than as local offsets.
const GLOW_DROP: float = 0.004
const ROLE_DROP: float = 0.006
const HOVER_TINT: Color = Color(ZenithTheme.ACCENT, 0.6)
## Heavier than a plain choice so it reads on the small Remain and Relic cards.
const USABLE_GLOW: float = 1.8
const WOBBLE_TIME: float = 0.6
const WOBBLE_DEGREES: float = 5.0     # per hit tier
const FACE_HALF_HEIGHT: float = 0.44  # the face quad's half height, where a wobble pivots
const GATHER_LIFT: float = 0.1
const SHEEN_TIME: float = 0.9
var uid: int = -1
var face_up: bool = true
@export var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if is_node_ready():
			_update_border()

@onready var body: Node3D = $Body
@onready var surface: Node3D = $Body/Surface
@onready var front: MeshInstance3D = $Body/Surface/Front
@onready var back: MeshInstance3D = $Body/Surface/Back
@onready var glow: MeshInstance3D = $Body/Surface/Glow
@onready var role: MeshInstance3D = $Body/Surface/Role
@onready var pick: Area3D = $Pick
@onready var border_fx: Node3D = $Body/Surface/BorderFx
@onready var sheen_mesh: MeshInstance3D = $Body/Surface/Sheen

var _front_mat: StandardMaterial3D = StandardMaterial3D.new()
var _back_mat: StandardMaterial3D = StandardMaterial3D.new()
var _glow_mat: ShaderMaterial = ShaderMaterial.new()
var _role_mat: ShaderMaterial = ShaderMaterial.new()
var _flash: Tween = null
var _motion: Tween = null
var _hover_motion: Tween = null
var _highlighted: bool = false
var _usable: bool = false
var _hovering: bool = false
var _gathering: bool = false
var _role_color: Color = Color.TRANSPARENT
var _presence_color: Color = Color.TRANSPARENT   # the other online player's hover, in their seat colour


func _ready() -> void:
	for m in [_front_mat, _back_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.disable_fog = true
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for m in [_glow_mat, _role_mat]:
		m.shader = preload("res://scripts/duel/card_aura.gdshader")
	_glow_mat.set_shader_parameter("plane_size", Vector2(0.72, 0.97))
	_role_mat.set_shader_parameter("plane_size", Vector2(0.80, 1.05))
	_role_mat.set_shader_parameter("border_extent", Vector2(0.337, 0.462))
	_glow_mat.set_shader_parameter("tint", HOVER_TINT)
	front.material_override = _front_mat
	back.material_override = _back_mat
	glow.material_override = _glow_mat
	role.material_override = _role_mat
	pick.input_event.connect(_on_pick_input)
	pick.mouse_entered.connect(func() -> void: set_hovered(true); hovered.emit(uid, true))
	pick.mouse_exited.connect(func() -> void: set_hovered(false); hovered.emit(uid, false))
	set_notify_transform(true)
	_keep_underlays()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_node_ready():
		_keep_underlays()


func _keep_underlays() -> void:
	var height: float = maxf(0.001, global_basis.get_scale().y)
	if not is_equal_approx(glow.position.y * height, -GLOW_DROP):
		glow.position.y = -GLOW_DROP / height
		role.position.y = -ROLE_DROP / height
		_glow_mat.set_shader_parameter("thickness", clampf(1.0 / global_basis.get_scale().x, 1.0, 2.5))


func set_textures(front_tex: Texture2D, back_tex: Texture2D) -> void:
	_front_mat.albedo_texture = front_tex
	_back_mat.albedo_texture = back_tex


func set_face_texture(front_tex: Texture2D) -> void:
	_front_mat.albedo_texture = front_tex


## A faded marker for a card gone from the table whose effect still stands. It still answers
## hover and inspect.
func set_ghost(on: bool) -> void:
	for m in [_front_mat, _back_mat]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if on else BaseMaterial3D.TRANSPARENCY_DISABLED
		m.albedo_color = Color(ZenithTheme.TEXT_SOFT, 0.55) if on else Color.WHITE


func set_highlight(on: bool) -> void:
	_highlighted = on
	_update_glow()


## The viewer's pending decision offers to use this card itself (its Power, a Drill, a Remain
## attack), as opposed to choosing it as a target.
func set_usable(on: bool) -> void:
	_usable = on
	_update_glow()


func is_usable() -> bool:
	return _usable


func _update_glow() -> void:
	var chosen: bool = _usable or _highlighted or _gathering
	var presence_only: bool = not chosen and not _hovering and _presence_color.a > 0.0 and face_up
	glow.visible = chosen or _hovering or presence_only
	var tint: Color = HOVER_TINT
	if _gathering:
		tint = Color(ZenithTheme.ACCENT, 1.0)
	elif _usable:
		tint = Color(ZenithTheme.USABLE, 1.0)
	elif _highlighted:
		tint = Color(ZenithTheme.ACCENT, 1.0)
	elif presence_only:
		tint = Color(_presence_color, 0.9)
	_glow_mat.set_shader_parameter("tint", tint)
	_glow_mat.set_shader_parameter("highlight", USABLE_GLOW if _usable or _gathering else (1.0 if chosen else 0.0))
	_update_border()


## The other online player's hover, in their seat colour; transparent clears it. The viewer's own
## hover and choices take the glow and border first; the role aura still shows theirs.
func set_presence(color: Color) -> void:
	if _presence_color == color:
		return
	_presence_color = color
	_update_role()
	_update_glow()


## Lifts `surface`, so the pick area and Body motion are untouched.
func set_hovered(on: bool) -> void:
	_hovering = on and face_up
	_update_glow()
	_glow_mat.set_shader_parameter("selected", 1.0 if _hovering else 0.0)
	if _hover_motion != null:
		_hover_motion.kill()
	_hover_motion = create_tween().set_parallel(true)
	var duration: float = 0.06 if reduced_motion else 0.14
	_hover_motion.tween_property(surface, "position:y", 0.025 if _hovering and not reduced_motion else 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_motion.tween_property(surface, "scale", Vector3.ONE * (1.035 if _hovering and not reduced_motion else 1.0), duration)


## A standing tint under the attacking card; a transparent colour clears it.
func set_role(color: Color) -> void:
	_role_color = color
	_update_role()
	_update_border()


## The wide aura shows the fight role, else the other online player's hover.
func _update_role() -> void:
	var color: Color = _role_color if _role_color.a > 0.0 else _presence_color
	role.visible = color.a > 0.0 and (face_up or _role_color.a > 0.0)
	_role_mat.set_shader_parameter("tint", Color(color, 0.9))


func _update_border() -> void:
	var active: bool = face_up and (_usable or _highlighted or _hovering or _role_color.a > 0.0 or _presence_color.a > 0.0)
	var color: Color = HOVER_TINT
	if _usable:
		color = ZenithTheme.USABLE
	elif _highlighted:
		color = ZenithTheme.ACCENT
	elif _role_color.a > 0.0:
		color = _role_color
	elif not _hovering and _presence_color.a > 0.0:
		color = _presence_color
	border_fx.set_effect(Color(color, 1.0), active, reduced_motion)
	for m: ShaderMaterial in [_glow_mat, _role_mat]:
		m.set_shader_parameter("motion", 0.0 if reduced_motion else 1.0)


## The face tints toward `color` for a moment, as a hit or a heal.
func flash(color: Color) -> void:
	if _flash != null:
		_flash.kill()
	_front_mat.albedo_color = color.lerp(Color.WHITE, 0.25)
	_back_mat.albedo_color = _front_mat.albedo_color
	_flash = create_tween().set_parallel(true)
	_flash.tween_property(_front_mat, "albedo_color", Color.WHITE, FLASH_TIME)
	_flash.tween_property(_back_mat, "albedo_color", Color.WHITE, FLASH_TIME)


## A short rattle of the quads, for taking a hit. Awaitable.
func shake(strength: float = 0.05) -> void:
	if reduced_motion:
		_stop_motion()
		return
	var t: Tween = _start_motion()
	var steps: int = 5
	for i in range(steps):
		var falloff: float = 1.0 - float(i) / steps
		var off: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * strength * falloff
		t.tween_property(body, "position", off, SHAKE_TIME / (steps + 1))
	t.tween_property(body, "position", Vector3.ZERO, SHAKE_TIME / (steps + 1))
	await _motion_end(t)


## The attack: the quads draw back a little, snap out along `direction` (world space), and settle
## home. Awaitable.
func lunge(direction: Vector3, distance: float = 0.45) -> void:
	if reduced_motion:
		_stop_motion()
		return
	var toward: Vector3 = global_transform.basis.inverse() * direction.normalized()
	var t: Tween = _start_motion()
	t.tween_property(body, "position", -toward * WINDUP_DISTANCE + Vector3(0, 0.08, 0), WINDUP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(body, "position", toward * distance + Vector3(0, 0.15, 0), STRIKE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(body, "position", Vector3.ZERO, RECOIL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _motion_end(t)


## A short jab along `direction` that holds on the contact frame for `stop` seconds. Awaitable.
func jab(direction: Vector3, stop: float = 0.0, distance: float = 0.2) -> void:
	if reduced_motion:
		_stop_motion()
		return
	var toward: Vector3 = global_transform.basis.inverse() * direction.normalized()
	var t: Tween = _start_motion()
	t.tween_property(body, "position", toward * distance + Vector3(0, 0.06, 0), STRIKE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if stop > 0.0:
		t.tween_interval(stop)
	t.tween_property(body, "position", Vector3.ZERO, RECOIL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _motion_end(t)


## Thrown back along `direction` (world space) and bouncing home, for an attacker whose blow was
## stopped. Awaitable.
func knock(direction: Vector3, distance: float = 0.12) -> void:
	if reduced_motion:
		_stop_motion()
		return
	var away: Vector3 = global_transform.basis.inverse() * direction.normalized()
	var t: Tween = _start_motion()
	t.tween_property(body, "position", away * distance, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(body, "position", Vector3.ZERO, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _motion_end(t)


## A small hop in place, for a card that just changed (Energy, Fervor, an aspect). Awaitable.
func hop(height: float = 0.12) -> void:
	if reduced_motion:
		_stop_motion()
		return
	var t: Tween = _start_motion()
	t.tween_property(body, "position:y", height, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(body, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _motion_end(t)


## A struck practice dummy rocking on its base: a damped swing of WOBBLE_DEGREES per `tier` about
## the bottom edge of the face. Awaitable.
func wobble(tier: float = 1.0) -> void:
	if reduced_motion:
		_stop_motion()
		return
	var t: Tween = _start_motion()
	var pivot: Vector3 = surface.transform * Vector3(0.0, 0.0, FACE_HALF_HEIGHT)
	t.tween_method(func(progress: float) -> void: _rock(progress, tier, pivot), 0.0, 1.0, WOBBLE_TIME)
	t.tween_callback(func() -> void: body.transform = Transform3D.IDENTITY)
	await _motion_end(t)


func _rock(progress: float, tier: float, pivot: Vector3) -> void:
	var angle: float = deg_to_rad(WOBBLE_DEGREES * tier) * sin(progress * TAU * 2.5) * (1.0 - progress)
	var turn: Basis = Basis(Vector3.UP, angle)
	body.transform = Transform3D(turn, pivot - turn * pivot)


## A fighter gathering itself before a move: the card rises, glows and holds for `time`. Awaitable.
func gather(time: float = 0.5) -> void:
	_gathering = true
	_update_glow()
	if reduced_motion:
		_stop_motion()
		await get_tree().create_timer(time).timeout
	else:
		var t: Tween = _start_motion()
		t.tween_property(body, "position:y", GATHER_LIFT, time * 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_interval(time * 0.35)
		t.tween_property(body, "position:y", 0.0, time * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await _motion_end(t)
	_gathering = false
	_update_glow()


## Grey metal light sweeps across the face once, over a flash of `color`.
func sheen(color: Color, time: float = SHEEN_TIME) -> void:
	flash(color)
	if reduced_motion:
		return
	var m: ShaderMaterial = sheen_mesh.material_override
	sheen_mesh.visible = true
	var t: Tween = create_tween()
	t.tween_method(func(value: float) -> void: m.set_shader_parameter("sweep", value), 0.0, 1.0, time)
	t.tween_callback(func() -> void: sheen_mesh.visible = false)


## Every Body motion replaces the last. A killed tween never emits `finished`, so each motion
## is awaited through `motion_done`, which fires when it ends and when a newer motion cuts it off.
func _start_motion() -> Tween:
	_stop_motion()
	_motion = create_tween()
	var t: Tween = _motion
	t.finished.connect(func() -> void:
		if _motion == t:
			motion_done.emit())
	return t


func _motion_end(t: Tween) -> void:
	while _motion == t and t.is_valid() and t.is_running():
		await motion_done


func _stop_motion() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
		motion_done.emit()
	body.transform = Transform3D.IDENTITY


## Target basis for the current facing; the view composes it with the zone slot.
func facing_basis() -> Basis:
	return Basis.IDENTITY if face_up else Basis(Vector3.FORWARD, PI)


func _on_pick_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(uid)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			inspected.emit(uid)
