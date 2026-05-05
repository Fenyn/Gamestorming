extends Node
class_name PieceCatalog

## Builds TrackPieceData entries for all Kenney Marble Kit pieces.
## Connection points are defined in local space relative to piece origin (center).
##
## Coordinate conventions (matching Kenney kit):
##   X = left/right
##   Y = up
##   Z = forward/back (primary flow axis for straights)
##
## Direction vectors point OUTWARD from the piece (the direction a connecting
## piece would extend toward). Two pieces connect when their connection points
## overlap and their directions are opposite.

const MODEL_DIR: String = "res://kenney_marble-kit/Models/GLB format/"

var _pieces: Dictionary = {}

func _ready() -> void:
	_register_all()

func get_piece(piece_id: String) -> TrackPieceData:
	return _pieces.get(piece_id) as TrackPieceData

func get_all_pieces() -> Array:
	return _pieces.values()

func _register_all() -> void:
	_register_straights()
	_register_curves()
	_register_bends()
	_register_s_curves()
	_register_waves()
	_register_splits()
	_register_ramps()
	_register_slants()
	_register_helixes()
	_register_bumps()
	_register_tunnels()
	_register_misc()
	_register_ends()

# --- Helpers ---

func _conn(pos: Vector3, dir: Vector3, h: float = 0.0, wide: bool = false) -> ConnectionPoint:
	var c: ConnectionPoint = ConnectionPoint.new()
	c.local_position = pos
	c.local_direction = dir.normalized()
	c.height_offset = h
	c.width = ConnectionPoint.TrackWidth.WIDE if wide else ConnectionPoint.TrackWidth.STANDARD
	return c

## Per-placement Spark costs by category.
## Free pieces (Straight/Corner) let the player always build something.
## Costs scale so the player places ~30 pieces per 5-min cycle.
const CATEGORY_COSTS: Dictionary = {
	TrackPieceData.PieceCategory.STRAIGHT: 0.0,
	TrackPieceData.PieceCategory.CORNER: 0.0,
	TrackPieceData.PieceCategory.CURVE: 10.0,
	TrackPieceData.PieceCategory.TUNNEL: 10.0,
	TrackPieceData.PieceCategory.END_CAP: 5.0,
	TrackPieceData.PieceCategory.RAMP: 15.0,
	TrackPieceData.PieceCategory.BEND: 15.0,
	TrackPieceData.PieceCategory.S_CURVE: 25.0,
	TrackPieceData.PieceCategory.WAVE: 25.0,
	TrackPieceData.PieceCategory.SPLIT: 25.0,
	TrackPieceData.PieceCategory.BUMP: 20.0,
	TrackPieceData.PieceCategory.FUNNEL: 20.0,
	TrackPieceData.PieceCategory.HELIX: 50.0,
	TrackPieceData.PieceCategory.CROSS: 40.0,
	TrackPieceData.PieceCategory.DECORATIVE: 0.0,
}

const SIZE_MULTIPLIERS: Dictionary = {
	"large": 1.5,
	"medium": 1.3,
	"long": 1.3,
	"double": 1.8,
	"wide": 1.2,
}

func _cost_for(id: String, cat: TrackPieceData.PieceCategory) -> float:
	var base: float = CATEGORY_COSTS.get(cat, 10.0) as float
	var mult: float = 1.0
	for keyword: String in SIZE_MULTIPLIERS:
		if id.contains(keyword):
			mult = maxf(mult, SIZE_MULTIPLIERS[keyword] as float)
	return base * mult

func _add(id: String, name: String, cat: TrackPieceData.PieceCategory,
		model: String, conns: Array[ConnectionPoint], cost_override: float = -1.0) -> void:
	var data: TrackPieceData = TrackPieceData.new()
	data.piece_id = id
	data.display_name = name
	data.category = cat
	data.model_path = MODEL_DIR + model
	data.spark_cost = cost_override if cost_override >= 0.0 else _cost_for(id, cat)
	data.connections = conns
	_pieces[id] = data

# --- Straights (flow along Z, connections at front/back) ---

func _register_straights() -> void:
	# Standard straight: free starter piece
	_add("straight", "Straight", TrackPieceData.PieceCategory.STRAIGHT,
		"straight.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1)),
			_conn(Vector3(0, 0,  0.5), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint], 0.0)

	_add("straight_wide", "Wide Straight", TrackPieceData.PieceCategory.STRAIGHT,
		"straight-wide.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1), 0.0, true),
			_conn(Vector3(0, 0,  0.5), Vector3(0, 0,  1), 0.0, true),
		] as Array[ConnectionPoint])

	_add("straight_hole", "Straight (Hole)", TrackPieceData.PieceCategory.STRAIGHT,
		"straight-hole.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1)),
			_conn(Vector3(0, 0,  0.5), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("straight_wide_hole", "Wide Straight (Hole)", TrackPieceData.PieceCategory.STRAIGHT,
		"straight-wide-hole.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1), 0.0, true),
			_conn(Vector3(0, 0,  0.5), Vector3(0, 0,  1), 0.0, true),
		] as Array[ConnectionPoint])

# --- Curves (90° turns) ---

func _register_curves() -> void:
	# curve: 2x2 quarter circle. Entry at -Z, exit at +X
	_add("curve", "Curve", TrackPieceData.PieceCategory.CURVE,
		"curve.glb", [
			_conn(Vector3(0, 0, -1.0), Vector3(0, 0, -1)),
			_conn(Vector3(1.0, 0, 0),  Vector3(1, 0,  0)),
		] as Array[ConnectionPoint])

	_add("curve_large", "Large Curve", TrackPieceData.PieceCategory.CURVE,
		"curve-large.glb", [
			_conn(Vector3(0, 0, -1.5), Vector3(0, 0, -1)),
			_conn(Vector3(1.5, 0, 0),  Vector3(1, 0,  0)),
		] as Array[ConnectionPoint])

	_add("curve_solid", "Curve (Solid)", TrackPieceData.PieceCategory.CURVE,
		"curve-solid.glb", [
			_conn(Vector3(0, 0, -1.0), Vector3(0, 0, -1)),
			_conn(Vector3(1.0, 0, 0),  Vector3(1, 0,  0)),
		] as Array[ConnectionPoint])

	_add("curve_solid_large", "Large Curve (Solid)", TrackPieceData.PieceCategory.CURVE,
		"curve-solid-large.glb", [
			_conn(Vector3(0, 0, -1.5), Vector3(0, 0, -1)),
			_conn(Vector3(1.5, 0, 0),  Vector3(1, 0,  0)),
		] as Array[ConnectionPoint])

	# Wide curves
	_add("curve_wide", "Wide Curve", TrackPieceData.PieceCategory.CURVE,
		"curve-wide.glb", [
			_conn(Vector3(0, 0, -0.85), Vector3(0, 0, -1), 0.0, true),
			_conn(Vector3(0.85, 0, 0),  Vector3(1, 0,  0), 0.0, true),
		] as Array[ConnectionPoint])

	_add("curve_wide_large", "Large Wide Curve", TrackPieceData.PieceCategory.CURVE,
		"curve-wide-large.glb", [
			_conn(Vector3(0, 0, -1.5), Vector3(0, 0, -1), 0.0, true),
			_conn(Vector3(1.5, 0, 0),  Vector3(1, 0,  0), 0.0, true),
		] as Array[ConnectionPoint])

	_add("curve_wide_medium", "Medium Wide Curve", TrackPieceData.PieceCategory.CURVE,
		"curve-wide-medium.glb", [
			_conn(Vector3(0, 0, -1.0), Vector3(0, 0, -1), 0.0, true),
			_conn(Vector3(1.0, 0, 0),  Vector3(1, 0,  0), 0.0, true),
		] as Array[ConnectionPoint])

# --- Bends (gentle S-shaped single curves, entry/exit on same axis but offset) ---

func _register_bends() -> void:
	# bend: 1 wide x 2 deep, shifts track laterally by 1 unit
	_add("bend", "Bend", TrackPieceData.PieceCategory.BEND,
		"bend.glb", [
			_conn(Vector3(-0.5, 0, -1.0), Vector3(0, 0, -1)),
			_conn(Vector3( 0.5, 0,  1.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("bend_medium", "Medium Bend", TrackPieceData.PieceCategory.BEND,
		"bend-medium.glb", [
			_conn(Vector3(-1.0, 0, -2.0), Vector3(0, 0, -1)),
			_conn(Vector3( 1.0, 0,  2.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("bend_large", "Large Bend", TrackPieceData.PieceCategory.BEND,
		"bend-large.glb", [
			_conn(Vector3(-1.5, 0, -3.0), Vector3(0, 0, -1)),
			_conn(Vector3( 1.5, 0,  3.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	# Solid variants
	_add("bend_solid_medium", "Medium Bend (Solid)", TrackPieceData.PieceCategory.BEND,
		"bend-solid-medium.glb", [
			_conn(Vector3(-1.0, 0, -2.0), Vector3(0, 0, -1)),
			_conn(Vector3( 1.0, 0,  2.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("bend_solid_large", "Large Bend (Solid)", TrackPieceData.PieceCategory.BEND,
		"bend-solid-large.glb", [
			_conn(Vector3(-1.5, 0, -3.0), Vector3(0, 0, -1)),
			_conn(Vector3( 1.5, 0,  3.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

# --- S-Curves (lateral offset, entry/exit parallel but shifted) ---

func _register_s_curves() -> void:
	# s-curve-left: 4 wide x 3 deep, shifts track left by ~2
	_add("s_curve_left", "S-Curve Left", TrackPieceData.PieceCategory.S_CURVE,
		"s-curve-left.glb", [
			_conn(Vector3( 2.0, 0, -1.5), Vector3(0, 0, -1)),
			_conn(Vector3(-2.0, 0,  1.5), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("s_curve_right", "S-Curve Right", TrackPieceData.PieceCategory.S_CURVE,
		"s-curve-right.glb", [
			_conn(Vector3(-2.0, 0, -1.5), Vector3(0, 0, -1)),
			_conn(Vector3( 2.0, 0,  1.5), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("s_curve_left_large", "Large S-Curve Left", TrackPieceData.PieceCategory.S_CURVE,
		"s-curve-left-large.glb", [
			_conn(Vector3( 3.0, 0, -2.5), Vector3(0, 0, -1)),
			_conn(Vector3(-3.0, 0,  2.5), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("s_curve_right_large", "Large S-Curve Right", TrackPieceData.PieceCategory.S_CURVE,
		"s-curve-right-large.glb", [
			_conn(Vector3(-3.0, 0, -2.5), Vector3(0, 0, -1)),
			_conn(Vector3( 3.0, 0,  2.5), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	# Short s-curves (a/b/c variants with slight differences)
	_add("s_curve_short_left_a", "Short S-Curve Left A", TrackPieceData.PieceCategory.S_CURVE,
		"s-curve-short-left-a.glb", [
			_conn(Vector3( 0.5, 0, -1.0), Vector3(0, 0, -1)),
			_conn(Vector3(-0.5, 0,  1.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("s_curve_short_left_b", "Short S-Curve Left B", TrackPieceData.PieceCategory.S_CURVE,
		"s-curve-short-left-b.glb", [
			_conn(Vector3( 0.5, 0, -1.0), Vector3(0, 0, -1)),
			_conn(Vector3(-0.5, 0,  1.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("s_curve_short_left_c", "Short S-Curve Left C", TrackPieceData.PieceCategory.S_CURVE,
		"s-curve-short-left-c.glb", [
			_conn(Vector3( 0.5, 0, -1.0), Vector3(0, 0, -1)),
			_conn(Vector3(-0.5, 0,  1.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

# --- Waves (undulating pieces along Z) ---

func _register_waves() -> void:
	# wave-a: ~1.25 wide x 4 deep
	_add("wave_a", "Wave A", TrackPieceData.PieceCategory.WAVE,
		"wave-a.glb", [
			_conn(Vector3(0, 0, -2.0), Vector3(0, 0, -1)),
			_conn(Vector3(0, 0,  2.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("wave_b", "Wave B", TrackPieceData.PieceCategory.WAVE,
		"wave-b.glb", [
			_conn(Vector3(0, 0, -2.0), Vector3(0, 0, -1)),
			_conn(Vector3(0, 0,  2.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("wave_c", "Wave C", TrackPieceData.PieceCategory.WAVE,
		"wave-c.glb", [
			_conn(Vector3(0, 0, -2.0), Vector3(0, 0, -1)),
			_conn(Vector3(0, 0,  2.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("wave_solid_a", "Wave A (Solid)", TrackPieceData.PieceCategory.WAVE,
		"wave-solid-a.glb", [
			_conn(Vector3(0, 0, -2.0), Vector3(0, 0, -1)),
			_conn(Vector3(0, 0,  2.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("wave_solid_b", "Wave B (Solid)", TrackPieceData.PieceCategory.WAVE,
		"wave-solid-b.glb", [
			_conn(Vector3(0, 0, -2.0), Vector3(0, 0, -1)),
			_conn(Vector3(0, 0,  2.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("wave_solid_c", "Wave C (Solid)", TrackPieceData.PieceCategory.WAVE,
		"wave-solid-c.glb", [
			_conn(Vector3(0, 0, -2.0), Vector3(0, 0, -1)),
			_conn(Vector3(0, 0,  2.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

# --- Splits (1 in, 2+ out) ---

func _register_splits() -> void:
	# split: 1x1, Y-junction. Entry -Z, exits +X and -X
	_add("split", "Split", TrackPieceData.PieceCategory.SPLIT,
		"split.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1)),
			_conn(Vector3(-0.5, 0, 0), Vector3(-1, 0, 0)),
			_conn(Vector3( 0.5, 0, 0), Vector3( 1, 0, 0)),
		] as Array[ConnectionPoint])

	_add("split_left", "Split Left", TrackPieceData.PieceCategory.SPLIT,
		"split-left.glb", [
			_conn(Vector3(0, 0, -1.0), Vector3(0, 0, -1)),
			_conn(Vector3(-1.0, 0, 0), Vector3(-1, 0, 0)),
			_conn(Vector3(0, 0,  1.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("split_right", "Split Right", TrackPieceData.PieceCategory.SPLIT,
		"split-right.glb", [
			_conn(Vector3(0, 0, -1.0), Vector3(0, 0, -1)),
			_conn(Vector3(1.0, 0,  0), Vector3(1, 0,  0)),
			_conn(Vector3(0, 0,  1.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("split_double", "Double Split", TrackPieceData.PieceCategory.SPLIT,
		"split-double.glb", [
			_conn(Vector3(0, 0, -1.0), Vector3(0, 0, -1)),
			_conn(Vector3(-1.5, 0, 1.0), Vector3(0, 0, 1)),
			_conn(Vector3( 1.5, 0, 1.0), Vector3(0, 0, 1)),
		] as Array[ConnectionPoint])

	_add("split_double_sides", "Double Split (Sides)", TrackPieceData.PieceCategory.SPLIT,
		"split-double-sides.glb", [
			_conn(Vector3(0, 0, -1.0), Vector3(0, 0, -1)),
			_conn(Vector3(-1.5, 0, 0), Vector3(-1, 0, 0)),
			_conn(Vector3( 1.5, 0, 0), Vector3( 1, 0, 0)),
		] as Array[ConnectionPoint])

# --- Ramps (entry level, exit raised or lowered) ---

func _register_ramps() -> void:
	for suffix: String in ["a", "b", "c", "d"]:
		var h: float = 0.25
		# ramp-start: level at -Z, raised at +Z
		_add("ramp_start_%s" % suffix, "Ramp Start %s" % suffix.to_upper(),
			TrackPieceData.PieceCategory.RAMP,
			"ramp-start-%s.glb" % suffix, [
				_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1), 0.0),
				_conn(Vector3(0, h, 0.5),  Vector3(0, 0,  1), h),
			] as Array[ConnectionPoint])

		_add("ramp_end_%s" % suffix, "Ramp End %s" % suffix.to_upper(),
			TrackPieceData.PieceCategory.RAMP,
			"ramp-end-%s.glb" % suffix, [
				_conn(Vector3(0, h, -0.5), Vector3(0, 0, -1), h),
				_conn(Vector3(0, 0,  0.5), Vector3(0, 0,  1), 0.0),
			] as Array[ConnectionPoint])

		_add("ramp_long_%s" % suffix, "Long Ramp %s" % suffix.to_upper(),
			TrackPieceData.PieceCategory.RAMP,
			"ramp-long-%s.glb" % suffix, [
				_conn(Vector3(0, 0,   -1.0), Vector3(0, 0, -1), 0.0),
				_conn(Vector3(0, 0.5,  1.0), Vector3(0, 0,  1), 0.5),
			] as Array[ConnectionPoint])

# --- Slants (angled pieces, steeper than ramps) ---

func _register_slants() -> void:
	# slant-a: 1x1, rises 0.5 (from 0 to 0.5 at top)
	for suffix: String in ["a", "b", "c", "d"]:
		var rise_short: float = 0.5 if suffix in ["a", "d"] else 0.75
		_add("slant_%s" % suffix, "Slant %s" % suffix.to_upper(),
			TrackPieceData.PieceCategory.RAMP,
			"slant-%s.glb" % suffix, [
				_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1), 0.0),
				_conn(Vector3(0, rise_short, 0.5), Vector3(0, 0, 1), rise_short),
			] as Array[ConnectionPoint])

		_add("slant_long_%s" % suffix, "Long Slant %s" % suffix.to_upper(),
			TrackPieceData.PieceCategory.RAMP,
			"slant-long-%s.glb" % suffix, [
				_conn(Vector3(0, 0, -1.0), Vector3(0, 0, -1), 0.0),
				_conn(Vector3(0, 0.5, 1.0), Vector3(0, 0, 1), 0.5),
			] as Array[ConnectionPoint])

# --- Helixes (spiral descent) ---

func _register_helixes() -> void:
	# helix-quarter: 90° turn that descends 1.0
	_add("helix_quarter_left", "Helix Quarter Left", TrackPieceData.PieceCategory.HELIX,
		"helix-quarter-left.glb", [
			_conn(Vector3(0, 1.0, -1.0), Vector3(0, 0, -1), 1.0),
			_conn(Vector3(1.0, 0, 0),    Vector3(1, 0,  0), 0.0),
		] as Array[ConnectionPoint])

	_add("helix_quarter_right", "Helix Quarter Right", TrackPieceData.PieceCategory.HELIX,
		"helix-quarter-right.glb", [
			_conn(Vector3(0, 1.0, -1.0), Vector3(0, 0, -1), 1.0),
			_conn(Vector3(-1.0, 0, 0),   Vector3(-1, 0, 0), 0.0),
		] as Array[ConnectionPoint])

	# helix-half: 180° turn, descends 1.5
	_add("helix_half_left", "Helix Half Left", TrackPieceData.PieceCategory.HELIX,
		"helix-half-left.glb", [
			_conn(Vector3(0, 1.5, -2.0), Vector3(0, 0, -1), 1.5),
			_conn(Vector3(0, 0,    2.0), Vector3(0, 0,  1), 0.0),
		] as Array[ConnectionPoint])

	_add("helix_half_right", "Helix Half Right", TrackPieceData.PieceCategory.HELIX,
		"helix-half-right.glb", [
			_conn(Vector3(0, 1.5, -2.0), Vector3(0, 0, -1), 1.5),
			_conn(Vector3(0, 0,    2.0), Vector3(0, 0,  1), 0.0),
		] as Array[ConnectionPoint])

	# helix-full: 360° loop, descends 2.5
	_add("helix_left", "Full Helix Left", TrackPieceData.PieceCategory.HELIX,
		"helix-left.glb", [
			_conn(Vector3(0, 2.5, -2.0), Vector3(0, 0, -1), 2.5),
			_conn(Vector3(0, 0,   -2.0), Vector3(0, 0, -1), 0.0),
		] as Array[ConnectionPoint])

	_add("helix_right", "Full Helix Right", TrackPieceData.PieceCategory.HELIX,
		"helix-right.glb", [
			_conn(Vector3(0, 2.5, -2.0), Vector3(0, 0, -1), 2.5),
			_conn(Vector3(0, 0,   -2.0), Vector3(0, 0, -1), 0.0),
		] as Array[ConnectionPoint])

	# Large helix variants
	_add("helix_large_quarter_left", "Large Helix Quarter Left", TrackPieceData.PieceCategory.HELIX,
		"helix-large-quarter-left.glb", [
			_conn(Vector3(0, 1.0, -1.5), Vector3(0, 0, -1), 1.0),
			_conn(Vector3(1.5, 0, 0),    Vector3(1, 0,  0), 0.0),
		] as Array[ConnectionPoint])

	_add("helix_large_quarter_right", "Large Helix Quarter Right", TrackPieceData.PieceCategory.HELIX,
		"helix-large-quarter-right.glb", [
			_conn(Vector3(0, 1.0, -1.5), Vector3(0, 0, -1), 1.0),
			_conn(Vector3(-1.5, 0, 0),   Vector3(-1, 0, 0), 0.0),
		] as Array[ConnectionPoint])

	_add("helix_large_half_left", "Large Helix Half Left", TrackPieceData.PieceCategory.HELIX,
		"helix-large-half-left.glb", [
			_conn(Vector3(0, 1.5, -3.0), Vector3(0, 0, -1), 1.5),
			_conn(Vector3(0, 0,    3.0), Vector3(0, 0,  1), 0.0),
		] as Array[ConnectionPoint])

	_add("helix_large_half_right", "Large Helix Half Right", TrackPieceData.PieceCategory.HELIX,
		"helix-large-half-right.glb", [
			_conn(Vector3(0, 1.5, -3.0), Vector3(0, 0, -1), 1.5),
			_conn(Vector3(0, 0,    3.0), Vector3(0, 0,  1), 0.0),
		] as Array[ConnectionPoint])

	_add("helix_large_left", "Large Full Helix Left", TrackPieceData.PieceCategory.HELIX,
		"helix-large-left.glb", [
			_conn(Vector3(0, 2.5, -3.0), Vector3(0, 0, -1), 2.5),
			_conn(Vector3(0, 0,   -3.0), Vector3(0, 0, -1), 0.0),
		] as Array[ConnectionPoint])

	_add("helix_large_right", "Large Full Helix Right", TrackPieceData.PieceCategory.HELIX,
		"helix-large-right.glb", [
			_conn(Vector3(0, 2.5, -3.0), Vector3(0, 0, -1), 2.5),
			_conn(Vector3(0, 0,   -3.0), Vector3(0, 0, -1), 0.0),
		] as Array[ConnectionPoint])

# --- Bumps (elevated sections) ---

func _register_bumps() -> void:
	for suffix: String in ["a", "b", "c", "d"]:
		_add("bump_%s" % suffix, "Bump %s" % suffix.to_upper(),
			TrackPieceData.PieceCategory.BUMP,
			"bump-%s.glb" % suffix, [
				_conn(Vector3(0, 0, -2.0), Vector3(0, 0, -1)),
				_conn(Vector3(0, 0,  2.0), Vector3(0, 0,  1)),
			] as Array[ConnectionPoint])

		_add("bump_solid_%s" % suffix, "Bump %s (Solid)" % suffix.to_upper(),
			TrackPieceData.PieceCategory.BUMP,
			"bump-solid-%s.glb" % suffix, [
				_conn(Vector3(0, 0, -2.0), Vector3(0, 0, -1)),
				_conn(Vector3(0, 0,  2.0), Vector3(0, 0,  1)),
			] as Array[ConnectionPoint])

# --- Tunnel ---

func _register_tunnels() -> void:
	_add("tunnel", "Tunnel", TrackPieceData.PieceCategory.TUNNEL,
		"tunnel.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1)),
			_conn(Vector3(0, 0,  0.5), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

# --- Misc: corner, cross, funnel ---

func _register_misc() -> void:
	_add("corner", "Corner", TrackPieceData.PieceCategory.CORNER,
		"corner.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1)),
			_conn(Vector3(0.5, 0, 0),  Vector3(1, 0,  0)),
		] as Array[ConnectionPoint], 0.0)

	_add("corner_solid", "Corner (Solid)", TrackPieceData.PieceCategory.CORNER,
		"corner-solid.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1)),
			_conn(Vector3(0.5, 0, 0),  Vector3(1, 0,  0)),
		] as Array[ConnectionPoint])

	_add("cross", "Crossroads", TrackPieceData.PieceCategory.CROSS,
		"cross.glb", [
			_conn(Vector3(0, 0, -0.5),  Vector3(0, 0, -1)),
			_conn(Vector3(0, 0,  0.5),  Vector3(0, 0,  1)),
			_conn(Vector3(-0.5, 0, 0),  Vector3(-1, 0, 0)),
			_conn(Vector3( 0.5, 0, 0),  Vector3( 1, 0, 0)),
		] as Array[ConnectionPoint])

	_add("funnel", "Funnel", TrackPieceData.PieceCategory.FUNNEL,
		"funnel.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1), 0.0, true),
			_conn(Vector3(0, 0,  0.5), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

	_add("funnel_long", "Long Funnel", TrackPieceData.PieceCategory.FUNNEL,
		"funnel-long.glb", [
			_conn(Vector3(0, 0, -1.0), Vector3(0, 0, -1), 0.0, true),
			_conn(Vector3(0, 0,  1.0), Vector3(0, 0,  1)),
		] as Array[ConnectionPoint])

# --- End caps (single connection, terminates track) ---

func _register_ends() -> void:
	_add("end_rounded", "End (Rounded)", TrackPieceData.PieceCategory.END_CAP,
		"end-rounded.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1)),
		] as Array[ConnectionPoint])

	_add("end_square", "End (Square)", TrackPieceData.PieceCategory.END_CAP,
		"end-square.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1)),
		] as Array[ConnectionPoint])

	_add("end_hole_rounded", "End Hole (Rounded)", TrackPieceData.PieceCategory.END_CAP,
		"end-hole-rounded.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1)),
		] as Array[ConnectionPoint])

	_add("end_hole_square", "End Hole (Square)", TrackPieceData.PieceCategory.END_CAP,
		"end-hole-square.glb", [
			_conn(Vector3(0, 0, -0.5), Vector3(0, 0, -1)),
		] as Array[ConnectionPoint])
