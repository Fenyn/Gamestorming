class_name TurnToken
extends Node3D
## Marks whose turn it is: a stone token on the viewer's left end of the centre line, resting on
## the turn owner's side of it and hopping across when the turn passes. Who acts right now, which
## swings back and forth through Combat, is lit on the duelists' plates instead.

## Out from the centre toward the viewer's left, and off the centre line toward the owner.
const REST_X: float = 4.45
const REST_Z: float = 0.34
const HOP_HEIGHT: float = 0.4
const HOP_TIME: float = 0.55

@onready var ring: MeshInstance3D = $Ring
var _material: StandardMaterial3D
var _rest: Vector3 = Vector3.ZERO
var _hop: Tween = null


func _ready() -> void:
	_material = (ring.material_override as StandardMaterial3D).duplicate()
	ring.material_override = _material
	visible = false


## `side` is the sign of the turn owner's half (world z), 0 when nobody holds a turn; `viewer_sign`
## is 1 for the seat at +z and -1 for the other, so the token keeps to the viewer's left.
func show_turn(side: float, viewer_sign: float, color: Color, reduced_motion: bool) -> void:
	_material.albedo_color = color
	_material.emission = color
	if is_zero_approx(side):
		visible = false
		return
	# The crest reads upright for the viewer.
	rotation.y = 0.0 if viewer_sign > 0.0 else PI
	var rest: Vector3 = Vector3(-REST_X * viewer_sign, 0.0, REST_Z * side)
	if rest.is_equal_approx(_rest) and visible:
		return
	var crossing: bool = visible and is_equal_approx(rest.x, _rest.x)
	_rest = rest
	visible = true
	if _hop != null and _hop.is_valid():
		_hop.kill()
	if reduced_motion or not crossing:
		position = rest
		return
	_hop = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hop.tween_method(_hop_step.bind(position, rest), 0.0, 1.0, HOP_TIME)


func _hop_step(t: float, from: Vector3, to: Vector3) -> void:
	position = from.lerp(to, t) + Vector3.UP * HOP_HEIGHT * sin(t * PI)
