class_name Card3D
extends Node3D
## One card on the table: a textured quad, a back, a glow for legal choices, a wider role glow
## for the personalities in a fight, and a pick area. The quads sit under `Body`, which shakes
## and lunges on its own so the table can keep tweening the card's own transform meanwhile.

signal clicked(uid: int)
signal hovered(uid: int, over: bool)
signal inspected(uid: int)   # right-click: bring the card up to read

const FLIP_DURATION: float = 0.25
const FLASH_TIME: float = 0.35
const SHAKE_TIME: float = 0.32
const LUNGE_TIME: float = 0.18

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


func _ready() -> void:
	for m in [_front_mat, _back_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for m in [_glow_mat, _role_mat]:
		m.shader = preload("res://scripts/duel/card_aura.gdshader")
	_glow_mat.set_shader_parameter("plane_size", Vector2(0.72, 0.97))
	_role_mat.set_shader_parameter("plane_size", Vector2(0.80, 1.05))
	_role_mat.set_shader_parameter("border_extent", Vector2(0.337, 0.462))
	_glow_mat.set_shader_parameter("tint", Palette.HIGHLIGHT)
	front.material_override = _front_mat
	back.material_override = _back_mat
	glow.material_override = _glow_mat
	role.material_override = _role_mat
	pick.input_event.connect(_on_pick_input)
	pick.mouse_entered.connect(func() -> void: set_hovered(true); hovered.emit(uid, true))
	pick.mouse_exited.connect(func() -> void: set_hovered(false); hovered.emit(uid, false))


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
		m.albedo_color = Color(0.72, 0.82, 0.92, 0.55) if on else Color.WHITE


func set_highlight(on: bool) -> void:
	_highlighted = on
	glow.visible = on or _hovering
	_glow_mat.set_shader_parameter("tint", Color(ZenithTheme.ACCENT, 1.0) if on else Color(0.55, 0.85, 1.0, 0.85))
	_glow_mat.set_shader_parameter("highlight", 1.0 if on else 0.0)
	_update_border()


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
	role.visible = color.a > 0.0
	_role_mat.set_shader_parameter("tint", Color(color, 0.9))
	_update_border()


func _update_border() -> void:
	var active: bool = face_up and (_highlighted or _hovering or _role_color.a > 0.0)
	var color: Color = _role_color if _role_color.a > 0.0 else (ZenithTheme.ACCENT if _highlighted else Color(0.55, 0.85, 1.0))
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
	_stop_motion()
	if reduced_motion:
		return
	_motion = create_tween()
	var steps: int = 5
	for i in range(steps):
		var falloff: float = 1.0 - float(i) / steps
		var off: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * strength * falloff
		_motion.tween_property(body, "position", off, SHAKE_TIME / (steps + 1))
	_motion.tween_property(body, "position", Vector3.ZERO, SHAKE_TIME / (steps + 1))
	await _motion.finished


## The quads push out along `direction` (world space) and back, for attacking. Awaitable.
func lunge(direction: Vector3, distance: float = 0.45) -> void:
	_stop_motion()
	if reduced_motion:
		return
	var local: Vector3 = global_transform.basis.inverse() * (direction.normalized() * distance) + Vector3(0, 0.15, 0)
	_motion = create_tween()
	_motion.tween_property(body, "position", local, LUNGE_TIME).set_ease(Tween.EASE_OUT)
	_motion.tween_property(body, "position", Vector3.ZERO, LUNGE_TIME).set_ease(Tween.EASE_IN)
	await _motion.finished


## A small hop in place, for a card that just changed (Energy, Fervor, an aspect). Awaitable.
func hop(height: float = 0.12) -> void:
	_stop_motion()
	if reduced_motion:
		return
	_motion = create_tween()
	_motion.tween_property(body, "position:y", height, 0.12).set_ease(Tween.EASE_OUT)
	_motion.tween_property(body, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN)
	await _motion.finished


func _stop_motion() -> void:
	if _motion != null:
		_motion.kill()
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
