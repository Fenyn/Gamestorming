extends RefCounted

## Cone dripper (the carriable pour-over brewer), at the size of a typical
## "02" ceramic cone: 10.5 cm flat base plate, about 11.7 cm across the rim and
## 10 cm tall. The inside is a 60 degree cone that ends in one large hole,
## which you can see through the base. A short collar joins the cone to the base
## plate, and a flat loop handle runs from the upper cone down to the plate.
##
## A paper cone filter lines it. Like a real one, it stands about 1.4 cm proud
## of the rim, with a slightly uneven top edge and a crimped seam down one side.
##
## Origin is the middle of the dripper, so the base plate's underside sits at
## y = -0.05 and the rim at 0.05. The handle points along +X.
##
## Nodes and metadata the Dripper script and the pour-over station use:
##   Collision      CylinderShape3D for the dripper. Moved onto the item at runtime.
##   Filter         The paper filter.
##   GroundsFloor   Marker3D at the bottom of the grounds bed inside the filter.
##   Root metadata  "base_y": underside of the base plate. On a stand's ring or a
##                  saucer, this is the point that rests on it.
##                  "grounds_height", "grounds_bottom_radius", "grounds_top_radius"
##                  size the grounds bed. "slurry_max_y" is the highest the water
##                  stands in the cone during a pour. "cone_slope" and
##                  "cone_radius_at_floor" let the water widen with the cone.

const MK := preload("res://model_src/model_kit.gd")

const BASE_Y := -0.05
const PLATE_TOP := -0.043
const RIM_Y := 0.05
const CERAMIC := Color(0.95, 0.94, 0.91)
## Inside of the cone: radius 0.0095 at HOLE_Y, widening at tan(30 deg).
const HOLE_Y := -0.028
const HOLE_R := 0.0095
const SLOPE := 0.5774
const INNER_RIM_R := 0.0545
const COLLAR_R := 0.024
const FILTER_GAP := 0.0008
const GROUNDS_BOTTOM_Y := -0.022
const GROUNDS_HEIGHT := 0.03
const FILTER_PROUD := 0.014

static func inner_radius(y: float) -> float:
	return HOLE_R + (y - HOLE_Y) * SLOPE

static func outer_radius(y: float) -> float:
	return inner_radius(y) + 0.0045

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "ConeDripper"
	var ceramic: Material = MK.mat(CERAMIC, 0.0, 0.22)

	# Outside: plate, collar, cone to the rolled rim; then the inside back down
	# the cone to the hole, and down through the base.
	var collar_top := HOLE_Y + (COLLAR_R - 0.0045 - HOLE_R) / SLOPE
	var profile := PackedVector2Array([
		Vector2(HOLE_R, BASE_Y), Vector2(0.051, BASE_Y), Vector2(0.0525, BASE_Y + 0.0015),
		Vector2(0.0525, PLATE_TOP - 0.0015), Vector2(0.051, PLATE_TOP), Vector2(COLLAR_R, PLATE_TOP),
		Vector2(COLLAR_R, collar_top), Vector2(outer_radius(RIM_Y - 0.003), RIM_Y - 0.003),
		Vector2(outer_radius(RIM_Y - 0.003) + 0.001, RIM_Y - 0.0008), Vector2(INNER_RIM_R + 0.002, RIM_Y),
		Vector2(INNER_RIM_R, RIM_Y - 0.0006), Vector2(HOLE_R, HOLE_Y), Vector2(HOLE_R, BASE_Y),
	])
	MK.lathe(root, "Body", profile, Vector3.ZERO, ceramic, 36)
	_build_handle(root, ceramic, collar_top)
	_build_filter(root)

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = 0.0585
	shape.height = RIM_Y - BASE_Y
	col.shape = shape
	root.add_child(col)

	MK.marker(root, "GroundsFloor", Vector3(0, GROUNDS_BOTTOM_Y, 0))
	root.set_meta("base_y", BASE_Y)
	root.set_meta("grounds_height", GROUNDS_HEIGHT)
	root.set_meta("grounds_bottom_radius", inner_radius(GROUNDS_BOTTOM_Y) - FILTER_GAP - 0.0006)
	root.set_meta("grounds_top_radius", inner_radius(GROUNDS_BOTTOM_Y + GROUNDS_HEIGHT) - FILTER_GAP - 0.0006)
	root.set_meta("slurry_max_y", RIM_Y - 0.012)
	root.set_meta("cone_slope", SLOPE)
	root.set_meta("cone_radius_at_floor", inner_radius(GROUNDS_BOTTOM_Y) - FILTER_GAP - 0.0006)
	return root

## Flat loop handle from the upper cone down to the base plate, on +X. Both
## ends are sunk into the body so nothing floats.
static func _build_handle(root: Node3D, ceramic: Material, collar_top: float) -> void:
	var handle := MK.group(root, "Handle")
	var top := Vector3(outer_radius(0.024) - 0.002, 0.024, 0)
	var bottom := Vector3(0.046, PLATE_TOP - 0.001, 0)
	var control := Vector3(0.098, 0.006, 0)
	var path := PackedVector3Array()
	for k in range(16):
		var t := float(k) / 15.0
		# Quadratic curve bulging out to the control point.
		path.append(top.lerp(control, t).lerp(control.lerp(bottom, t), t))
	MK.sweep(handle, "Loop", path, 0.0065, 0.0032, ceramic, Vector3.BACK, 10)
	MK.sphere(handle, "JointTop", 0.006, top + Vector3(0.001, 0, 0), ceramic, 0.8, 10)
	MK.sphere(handle, "JointLow", 0.006, bottom + Vector3(0, 0.001, 0), ceramic, 0.8, 10)

static func _build_filter(root: Node3D) -> void:
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.96, 0.95, 0.91)
	paper.roughness = 0.95
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	var filter := Node3D.new()
	filter.name = "Filter"
	root.add_child(filter)
	# Paper cone from a closed tip just above the hole to above the rim.
	var tip_y := HOLE_Y + 0.004
	var top_y := RIM_Y + FILTER_PROUD
	var profile := PackedVector2Array([
		Vector2(0.0, tip_y - 0.002), Vector2(inner_radius(tip_y) - FILTER_GAP, tip_y),
		Vector2(inner_radius(RIM_Y) - FILTER_GAP, RIM_Y - 0.0006),
		Vector2(inner_radius(top_y) - FILTER_GAP, top_y),
	])
	MK.lathe(filter, "Paper", profile, Vector3.ZERO, paper, 40, _paper_edge)
	# Crimped seam: a folded strip of paper running from tip to top on the -X
	# side, with crimp ridges across it.
	var a := Vector3(-(inner_radius(tip_y + 0.004) - FILTER_GAP - 0.001), tip_y + 0.004, 0)
	var b := Vector3(-(inner_radius(top_y) - FILTER_GAP - 0.001), top_y, 0)
	var seam := MK.box(filter, "Seam", Vector3(0.0016, a.distance_to(b), 0.007), Vector3.ZERO, paper)
	var up := (b - a).normalized()
	var side := Vector3.BACK
	seam.transform = Transform3D(Basis(up.cross(side).normalized(), up, side), (a + b) * 0.5)
	var crimp: Material = MK.mat(Color(0.9, 0.89, 0.85), 0.0, 0.95)
	for i in range(14):
		var t := (float(i) + 0.5) / 14.0
		var c := MK.box(filter, "Crimp", Vector3(0.0018, 0.0012, 0.0072), Vector3.ZERO, crimp)
		c.transform = Transform3D(Basis(up.cross(side).normalized(), up, side), a.lerp(b, t) + up.cross(side).normalized() * -0.0002)

## Uneven top edge on the paper, like a real filter that has been pressed in.
static func _paper_edge(v: Vector3, angle: float) -> Vector3:
	if v.y < RIM_Y:
		return v
	var t := (v.y - RIM_Y) / FILTER_PROUD
	return v + Vector3(0, t * (sin(angle * 5.0) * 0.0012 + sin(angle * 11.0 + 1.3) * 0.0006), 0)
