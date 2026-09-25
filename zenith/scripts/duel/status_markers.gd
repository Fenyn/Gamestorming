class_name StatusMarkers
extends Node3D
## Tracking marks on a personality card, in the card's frame. Energy lights the rung of the Might
## ladder printed on the face. An Ally has no stat crest of its own, so its Energy and Might are
## also spelled out under the card.

const CARD: Vector2 = Vector2(0.63, 0.88)
const FACE: Vector2 = Vector2(512, 716)   # face pixels the ladder rects are measured in
const LIFT: float = 0.004                 # above the card quad, no z-fight
const BAR_HEIGHT: float = 0.004
const BAR_GROW: float = 1.18
const PULSE_TIME: float = 0.9
## The lit bar breathes between these. The floor is the faintest it can be and still read on the
## cream face.
const BAR_ALPHA_MIN: float = 0.55
const BAR_ALPHA_MAX: float = 0.8
const OUTLINE: Color = Color(0.03, 0.025, 0.03, 0.95)

const STAT_GAP: float = 0.13              # clear of the card's outer edge
const STAT_STEP: float = 0.20             # caption beyond the number, clear of its own line

var _stat_value: Label3D = null
var _stat_caption: Label3D = null
var _bar: MeshInstance3D = null
var _bar_mat: StandardMaterial3D = null
var _rungs: Array[Vector3] = []           # card-local rung centres, index 0 = stage 10, last = stage 0
var _lit: Color = ZenithTheme.ENERGY
var _rung_size: Vector3 = Vector3.ZERO
var _pulse: Tween = null


func _ready() -> void:
	_bar = MeshInstance3D.new()
	_bar.mesh = BoxMesh.new()
	_bar_mat = StandardMaterial3D.new()
	_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bar_mat.albedo_color = Color(ZenithTheme.ENERGY, 0.55)
	_bar.material_override = _bar_mat
	_bar.visible = false
	add_child(_bar)
	_stat_value = _stat_label(60, ZenithTheme.ENERGY)
	_stat_caption = _stat_label(30, ZenithTheme.MUTED)
	_place_stats()


## A billboarded line beside the card. The card's own scale carries through, so the ladder and
## these numbers keep their proportions at every row scale.
func _stat_label(size: int, color: Color) -> Label3D:
	var l: Label3D = Label3D.new()
	l.font_size = size
	l.pixel_size = 0.0042
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = OUTLINE
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.no_depth_test = true
	l.double_sided = true
	l.visible = false
	add_child(l)
	return l


## The Ally's numbers sit beyond the card edge nearest the viewer, on both sides of the table,
## so reading the opponent's Allies never means looking past their cards. Card local +z faces
## the viewer whichever seat holds the table, because `TableLayout.slot` yaws by viewer.
func _place_stats() -> void:
	_stat_value.position = Vector3(0.0, LIFT, CARD.y * 0.5 + STAT_GAP)
	_stat_caption.position = Vector3(0.0, LIFT, CARD.y * 0.5 + STAT_GAP + STAT_STEP)


## Rung rects in face pixels, stage 10 first down to stage 0, from the face layout. `lit` is the
## owner's Mastery colour, the same one the face paints its live rung in.
func setup(ladder: Array[Rect2], lit: Color = ZenithTheme.ENERGY) -> void:
	_lit = lit
	_rungs.clear()
	for r in ladder:
		var c: Vector2 = r.get_center()
		_rungs.append(Vector3((c.x / FACE.x - 0.5) * CARD.x, LIFT, (c.y / FACE.y - 0.5) * CARD.y))
		_rung_size = Vector3(r.size.x / FACE.x * CARD.x * BAR_GROW, BAR_HEIGHT, r.size.y / FACE.y * CARD.y * BAR_GROW)
	(_bar.mesh as BoxMesh).size = _rung_size


## Energy 0 lights the stage 0 rung like any other. `standing` is the owning player for a
## duelist, null for an Ally. `might` turns on the Ally's Energy and Might line beside the card; a
## duelist's stat crest already carries both, so it stays off there.
func set_status(energy: int, standing: SeatPlayer, might: int = -1) -> void:
	var stages: int = CardInstance.MAX_STAGE
	if _rungs.size() == stages + 1:
		_bar.visible = true
		_bar.position = _rungs[stages - clampi(energy, 0, stages)]
		_bar_mat.albedo_color = Color(_lit, BAR_ALPHA_MAX)
		_start_pulse()
	var spell_out: bool = standing == null and might >= 0
	_stat_value.visible = spell_out
	_stat_caption.visible = spell_out
	if spell_out:
		# Energy only: it decides whether the Ally can take control, attack or be spent, and it is
		# the one number the row is too tight to spell out twice. Might stays on the hover view.
		_stat_value.text = str(energy)
		_stat_value.modulate = ZenithTheme.WARN if energy <= 0 else ZenithTheme.ENERGY
		_stat_caption.text = "ENERGY"


func _start_pulse() -> void:
	if _pulse != null:
		_pulse.kill()
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_bar_mat, "albedo_color:a", BAR_ALPHA_MIN, PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_bar_mat, "albedo_color:a", BAR_ALPHA_MAX, PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
