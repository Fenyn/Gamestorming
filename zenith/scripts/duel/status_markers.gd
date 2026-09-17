class_name StatusMarkers
extends Node3D
## Tracking marks on a personality card, in the card's frame. Vigor lights the rung of the Might
## ladder printed on the face; a fighter also gets one Acclaim pip per point needed along its top edge.

const CARD: Vector2 = Vector2(0.63, 0.88)
const FACE: Vector2 = Vector2(512, 716)   # face pixels the ladder rects are measured in
const PIP: Vector3 = Vector3(0.042, 0.005, 0.024)
const PIP_STEP: float = 0.056
const EDGE_GAP: float = 0.03
const LIFT: float = 0.004                 # above the card quad, no z-fight
const BAR_HEIGHT: float = 0.004
const BAR_GROW: float = 1.18
const PULSE_TIME: float = 0.9
const OFF_COLOR: Color = Color(0.22, 0.20, 0.18)

var _acclaim_pips: Array[MeshInstance3D] = []
var _bar: MeshInstance3D = null
var _bar_mat: StandardMaterial3D = null
var _rungs: Array[Vector3] = []           # card-local rung centres, index 0 = stage 10
var _rung_size: Vector3 = Vector3.ZERO
var _materials: Dictionary = {}           # Color -> StandardMaterial3D
var _pulse: Tween = null


func _ready() -> void:
	_bar = MeshInstance3D.new()
	_bar.mesh = BoxMesh.new()
	_bar_mat = StandardMaterial3D.new()
	_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bar_mat.albedo_color = Color(ZenithTheme.VIGOR, 0.55)
	_bar.material_override = _bar_mat
	_bar.visible = false
	add_child(_bar)


## Rung rects in face pixels, top rung first, from the face layout.
func setup(ladder: Array[Rect2]) -> void:
	_rungs.clear()
	for r in ladder:
		var c: Vector2 = r.get_center()
		_rungs.append(Vector3((c.x / FACE.x - 0.5) * CARD.x, LIFT, (c.y / FACE.y - 0.5) * CARD.y))
		_rung_size = Vector3(r.size.x / FACE.x * CARD.x * BAR_GROW, BAR_HEIGHT, r.size.y / FACE.y * CARD.y * BAR_GROW)
	(_bar.mesh as BoxMesh).size = _rung_size


## Lays the pip row out centred along the top edge, rebuilt only when the count changes.
func _lay_out_pips(count: int) -> void:
	if _acclaim_pips.size() == count:
		return
	for m in _acclaim_pips:
		m.queue_free()
	_acclaim_pips.clear()
	var top: float = -(CARD.y * 0.5 + EDGE_GAP)
	var span: float = PIP_STEP * (count - 1)
	for i in range(count):
		var m: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = PIP
		m.mesh = box
		m.material_override = _material(OFF_COLOR)
		m.position = Vector3(-span * 0.5 + PIP_STEP * i, LIFT, top)
		add_child(m)
		_acclaim_pips.append(m)


func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	_materials[color] = mat
	return mat


## Vigor 0 drops the bar one step below the ladder in the warning colour. `standing` is the
## owning player for a fighter (Acclaim pips), null for an Ally.
func set_status(vigor: int, standing: SeatPlayer) -> void:
	var stages: int = CardInstance.MAX_STAGE
	if _rungs.size() == stages:
		_bar.visible = true
		if vigor >= 1:
			_bar.position = _rungs[stages - clampi(vigor, 1, stages)]
			_bar_mat.albedo_color = Color(ZenithTheme.VIGOR, 0.55)
		else:
			var step: Vector3 = _rungs[stages - 1] - _rungs[stages - 2]
			_bar.position = _rungs[stages - 1] + step
			_bar_mat.albedo_color = Color(ZenithTheme.WARN, 0.6)
		_start_pulse()
	_lay_out_pips(standing.acclaim_needed if standing != null else 0)
	for i in range(_acclaim_pips.size()):
		_acclaim_pips[i].material_override = _material(ZenithTheme.ACCENT if i < standing.acclaim else OFF_COLOR)


func _start_pulse() -> void:
	if _pulse != null:
		_pulse.kill()
	var base: Color = _bar_mat.albedo_color
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_bar_mat, "albedo_color:a", base.a * 0.45, PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_bar_mat, "albedo_color:a", base.a, PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
