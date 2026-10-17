extends RefCounted

## Cone dripper (the carriable pour-over brewer), at the size of a typical
## one-to-two cup ceramic cone: about 11.5 cm across the rim and 8 cm tall,
## with a 60 degree cone, a single drain hole, a base ring that sits on a cup,
## and a loop handle on one side whose ends are joined into the wall. The paper
## filter is always in, so the ribs a real cone has inside are left out.
##
## Origin is the middle of the dripper, so the base ring sits at y = -0.04 and
## the rim at 0.04. The handle points along +X.
##
## Nodes the Dripper script and the pour-over station use:
##   Collision     CylinderShape3D for the dripper. Moved onto the item at runtime.
##   Filter        The paper filter lining the cone.
##   GroundsFloor  Marker3D at the bottom of the grounds bed inside the filter.
##   Root metadata "ring_contact_y": height (local) where the outside of the cone
##                 is 4.5 cm in radius, which is where a stand's ring holds it.
##                 "grounds_height", "grounds_bottom_radius", "grounds_top_radius"
##                 size the grounds bed.

const MK := preload("res://model_src/model_kit.gd")

const BASE_Y := -0.04
const RIM_Y := 0.04
const CERAMIC := Color(0.95, 0.94, 0.91)
const FOOT_TOP := -0.031
const GROUNDS_BOTTOM_Y := -0.022
const GROUNDS_HEIGHT := 0.026

## Outside, base ring up the cone to the rim, then down the inside to the hole.
const PROFILE := [
	Vector2(0.006, BASE_Y), Vector2(0.034, BASE_Y), Vector2(0.036, BASE_Y + 0.002),
	Vector2(0.036, FOOT_TOP), Vector2(0.040, FOOT_TOP + 0.002), Vector2(0.058, RIM_Y - 0.004),
	Vector2(0.0595, RIM_Y - 0.001), Vector2(0.058, RIM_Y), Vector2(0.0545, RIM_Y - 0.001),
	Vector2(0.0065, FOOT_TOP + 0.004), Vector2(0.006, BASE_Y),
]

static func _radius_at(y: float, r_low: float, y_low: float, r_high: float, y_high: float) -> float:
	return lerpf(r_low, r_high, (y - y_low) / (y_high - y_low))

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "ConeDripper"
	var ceramic: Material = MK.mat(CERAMIC, 0.0, 0.25)

	var profile := PackedVector2Array()
	for p in PROFILE:
		profile.append(p)
	MK.lathe(root, "Body", profile, Vector3.ZERO, ceramic, 32)
	_build_handle(root, ceramic)
	_build_filter(root)

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = 0.058
	shape.height = RIM_Y - BASE_Y
	col.shape = shape
	root.add_child(col)

	MK.marker(root, "GroundsFloor", Vector3(0, GROUNDS_BOTTOM_Y, 0))
	# Inside of the cone runs from r 0.0065 at FOOT_TOP + 0.004 to r 0.0545 near the rim.
	var inner_low_y := FOOT_TOP + 0.004
	var inner_high_y := RIM_Y - 0.001
	root.set_meta("grounds_height", GROUNDS_HEIGHT)
	root.set_meta("grounds_bottom_radius", _radius_at(GROUNDS_BOTTOM_Y, 0.0065, inner_low_y, 0.0545, inner_high_y) - 0.002)
	root.set_meta("grounds_top_radius", _radius_at(GROUNDS_BOTTOM_Y + GROUNDS_HEIGHT, 0.0065, inner_low_y, 0.0545, inner_high_y) - 0.002)
	# Outside of the cone runs from r 0.040 at FOOT_TOP + 0.002 to r 0.058 near the rim.
	var outer_low_y := FOOT_TOP + 0.002
	var outer_high_y := RIM_Y - 0.004
	root.set_meta("ring_contact_y", lerpf(outer_low_y, outer_high_y, (0.045 - 0.040) / (0.058 - 0.040)))
	return root

static func _build_handle(root: Node3D, ceramic: Material) -> void:
	var handle := MK.group(root, "Handle")
	# Loop handle on the +X side. Both ends are sunk 2 mm into the cone wall, and
	# the loop follows the wall's slant, so it is joined to the body all the way.
	var y_low := -0.018
	var y_high := 0.028
	var reach := 0.019
	var path := PackedVector3Array()
	for k in range(15):
		var a := deg_to_rad(-90.0 + 180.0 * float(k) / 14.0)
		var y := lerpf(y_low, y_high, (sin(a) + 1.0) * 0.5)
		var wall := _outer_radius(y) - 0.002
		path.append(Vector3(wall + cos(a) * reach, y, 0))
	MK.sweep(handle, "Loop", path, 0.0035, 0.0055, ceramic, Vector3.BACK, 10)
	# Rounded joints where the loop meets the cone.
	MK.sphere(handle, "JointTop", 0.0052, Vector3(_outer_radius(y_high) - 0.001, y_high, 0), ceramic, 0.9, 10)
	MK.sphere(handle, "JointLow", 0.0052, Vector3(_outer_radius(y_low) - 0.001, y_low, 0), ceramic, 0.9, 10)

## Radius of the outside of the cone at local height y.
static func _outer_radius(y: float) -> float:
	return _radius_at(y, 0.040, FOOT_TOP + 0.002, 0.058, RIM_Y - 0.004)

static func _build_filter(root: Node3D) -> void:
	# Paper cone filter lining the inside, with its seam fold standing above the rim.
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.97, 0.96, 0.93)
	paper.roughness = 0.95
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	var filter := Node3D.new()
	filter.name = "Filter"
	root.add_child(filter)
	var low_y := FOOT_TOP + 0.006
	var top_y := RIM_Y - 0.001
	var profile := PackedVector2Array([
		Vector2(0.0, low_y), Vector2(0.0085, low_y),
		Vector2(_radius_at(top_y, 0.0065, FOOT_TOP + 0.004, 0.0545, RIM_Y - 0.001) - 0.0012, top_y),
	])
	MK.lathe(filter, "Paper", profile, Vector3.ZERO, paper, 32)
	# Seam fold of the paper, lying against the wall on the far side from the handle.
	MK.box(filter, "Seam", Vector3(0.0012, 0.045, 0.012), Vector3(-0.033, 0.016, 0), paper, Vector3(0, 0, -33))
