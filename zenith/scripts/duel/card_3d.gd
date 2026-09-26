class_name Card3D
extends Node3D
## One card on the table: a textured quad, a back, a glow for legal choices, a wider role glow
## for the personalities in a fight, and a pick area. The quads sit under `Body`, which shakes
## and lunges on its own so the table can keep tweening the card's own transform meanwhile.

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
## How far under the face the legal-choice glow and the role aura lie, in world units. The table
## scales a slot's whole basis, height included, so a local offset would sink the duelist's (2.6x)
## under the mat; `_keep_underlays` holds these fixed instead.
const GLOW_DROP: float = 0.004
const ROLE_DROP: float = 0.006
## Hover is a softer bone than the legal-choice glow, so the two still read apart.
const HOVER_TINT: Color = Color(ZenithTheme.ACCENT, 0.6)
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

var _front_mat: StandardMaterial3D = StandardMaterial3D.new()
var _back_mat: StandardMaterial3D = StandardMaterial3D.new()
var _glow_mat: ShaderMaterial = ShaderMaterial.new()
var _role_mat: ShaderMaterial = ShaderMaterial.new()
var _flash: Tween = null
var _motion: Tween = null
var _hover_motion: Tween = null
var _highlighted: bool = false
var _hovering: bool = false
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


func set_textures(front_tex: Texture2D, back_tex: Texture2D) -> void:
	_front_mat.albedo_texture = front_tex
	_back_mat.albedo_texture = back_tex


func set_face_texture(front_tex: Texture2D) -> void:
	_front_mat.albedo_texture = front_tex


## A card that is not on the table any more but whose effect still stands. It reads as a faded
## marker and still answers hover and inspect, so the passive can be read like any other card.
func set_ghost(on: bool) -> void:
	for m in [_front_mat, _back_mat]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if on else BaseMaterial3D.TRANSPARENCY_DISABLED
		m.albedo_color = Color(ZenithTheme.TEXT_SOFT, 0.55) if on else Color.WHITE


func set_highlight(on: bool) -> void:
	_highlighted = on
	var presence_only: bool = not on and not _hovering and _presence_color.a > 0.0 and face_up
	glow.visible = on or _hovering or presence_only
	var tint: Color = HOVER_TINT
	if on:
		tint = Color(ZenithTheme.ACCENT, 1.0)
	elif presence_only:
		tint = Color(_presence_color, 0.9)
	_glow_mat.set_shader_parameter("tint", tint)
	_glow_mat.set_shader_parameter("highlight", 1.0 if on else 0.0)
	_update_border()


## The other online player's pointer is over this card: the same glow and border a local hover
## gets, in their seat colour, plus the wide role aura when the card has no fight role. A
## transparent colour clears it. The viewer's own hover and a legal choice take the inner glow and
## the border first; the wide aura still shows theirs.
func set_presence(color: Color) -> void:
	if _presence_color == color:
		return
	_presence_color = color
	_update_role()
	set_highlight(_highlighted)


## Visual lift does not move the picking area, or contend with resolution motion on Body.
## Keyboard focus can use this same feedback without synthesizing pointer events.
func set_hovered(on: bool) -> void:
	_hovering = on and face_up
	set_highlight(_highlighted)
	_glow_mat.set_shader_parameter("selected", 1.0 if _hovering else 0.0)
	if _hover_motion != null:
		_hover_motion.kill()
	_hover_motion = create_tween().set_parallel(true)
	var duration: float = 0.06 if reduced_motion else 0.14
	_hover_motion.tween_property(surface, "position:y", 0.025 if _hovering and not reduced_motion else 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_motion.tween_property(surface, "scale", Vector3.ONE * (1.035 if _hovering and not reduced_motion else 1.0), duration)


## A standing tint under the card for its part in the fight (attacking red, defending blue);
## a transparent colour clears it.
func set_role(color: Color) -> void:
	_role_color = color
	_update_role()
	_update_border()


## The wide aura carries the fight role, and otherwise the other online player's hover, so their
## hover still reads on a card that already glows as a legal choice.
func _update_role() -> void:
	var color: Color = _role_color if _role_color.a > 0.0 else _presence_color
	role.visible = color.a > 0.0 and (face_up or _role_color.a > 0.0)
	_role_mat.set_shader_parameter("tint", Color(color, 0.9))


func _update_border() -> void:
	var active: bool = face_up and (_highlighted or _hovering or _role_color.a > 0.0 or _presence_color.a > 0.0)
	# A legal choice outranks the fight role on the border, so a personality whose Power can be used
	# mid-Combat still reads as clickable; the role keeps the wide aura under the card.
	var color: Color = HOVER_TINT
	if _highlighted:
		color = ZenithTheme.ACCENT
	elif _role_color.a > 0.0:
		color = _role_color
	elif not _hovering and _presence_color.a > 0.0:
		color = _presence_color
	border_fx.set_effect(Color(color, 1.0), active, reduced_motion)
	_glow_mat.set_shader_parameter("motion", 0.0 if reduced_motion else 1.0)
	_role_mat.set_shader_parameter("motion", 0.0 if reduced_motion else 1.0)


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


## The blow landing: a short jab along `direction` that holds on the contact frame for `stop`
## seconds before it comes home, so a heavy hit reads heavier. Awaitable.
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
	body.position = Vector3.ZERO


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
