class_name Card3D
extends Node3D
## One card on the table: a textured quad, a back, a glow for legal choices, and a pick area.

signal clicked(uid: int)
signal hovered(uid: int, over: bool)
signal inspected(uid: int)   # right-click: bring the card up to read

const FLIP_DURATION: float = 0.25

var uid: int = -1
var face_up: bool = true

@onready var front: MeshInstance3D = $Front
@onready var back: MeshInstance3D = $Back
@onready var glow: MeshInstance3D = $Glow
@onready var pick: Area3D = $Pick

var _front_mat: StandardMaterial3D = StandardMaterial3D.new()
var _back_mat: StandardMaterial3D = StandardMaterial3D.new()
var _glow_mat: StandardMaterial3D = StandardMaterial3D.new()


func _ready() -> void:
	for m in [_front_mat, _back_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.albedo_color = Palette.HIGHLIGHT
	front.material_override = _front_mat
	back.material_override = _back_mat
	glow.material_override = _glow_mat
	pick.input_event.connect(_on_pick_input)
	pick.mouse_entered.connect(func() -> void: hovered.emit(uid, true))
	pick.mouse_exited.connect(func() -> void: hovered.emit(uid, false))


func set_textures(front_tex: Texture2D, back_tex: Texture2D) -> void:
	_front_mat.albedo_texture = front_tex
	_back_mat.albedo_texture = back_tex


func set_face_texture(front_tex: Texture2D) -> void:
	_front_mat.albedo_texture = front_tex


func set_highlight(on: bool) -> void:
	glow.visible = on


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
