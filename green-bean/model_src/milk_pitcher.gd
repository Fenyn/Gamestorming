extends RefCounted

## Milk steaming pitcher: a 12 oz stainless pitcher like the ones on every bar.
##
## Shape follows real 12 oz / 350 ml pitchers (about 7.5 cm across at the base,
## 9.5 cm tall): a wide belly that narrows toward the top so the milk can spin, a
## pointed pour spout, and a C handle opposite the spout.
##
## Origin is the middle of the pitcher, so the base sits at y = -0.0475 and the
## rim at 0.0475. The Collision node is moved onto the Pitcher item at runtime,
## so resize it here if you change the shape. The spout points along -Z and the
## handle along +Z, so on the steamer pad the handle faces the barista and the
## spout faces the wand, and when carried the spout points away from you.
##
## Nodes the Pitcher script uses:
##   Collision     CylinderShape3D for the item. Moved onto the Pitcher body.
##   MilkFloor     Marker3D on the inside floor. Milk is drawn up from here.
##   Root metadata "inner_profile": (radius, y) points of the inside wall, low
##                 to high. The milk narrows to follow it as it rises.

const MK := preload("res://model_src/model_kit.gd")

const BASE_Y := -0.0475
const RIM_Y := 0.0475
const FLOOR_Y := -0.043
const STEEL := Color(0.8, 0.81, 0.83)

## Outside wall, bottom to rim.
const OUTER := [
	Vector2(0.0, BASE_Y), Vector2(0.033, BASE_Y), Vector2(0.037, BASE_Y + 0.0025),
	Vector2(0.0385, -0.035), Vector2(0.039, -0.02), Vector2(0.0375, 0.0),
	Vector2(0.034, 0.02), Vector2(0.0315, 0.033), Vector2(0.0315, 0.041),
	Vector2(0.033, RIM_Y),
]
## Inside wall, rim to floor. Wall is about 1.5 mm thick.
const INNER := [
	Vector2(0.0315, RIM_Y), Vector2(0.030, 0.041), Vector2(0.030, 0.033),
	Vector2(0.0325, 0.02), Vector2(0.036, 0.0), Vector2(0.0375, -0.02),
	Vector2(0.037, -0.035), Vector2(0.034, FLOOR_Y + 0.002), Vector2(0.0, FLOOR_Y),
]

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "MilkPitcher"
	var steel: StandardMaterial3D = MK.mat(STEEL, 0.75, 0.28)

	var profile := PackedVector2Array()
	for p in OUTER:
		profile.append(p)
	for p in INNER:
		profile.append(p)
	MK.lathe(root, "Body", profile, Vector3.ZERO, steel, 28, _spout)

	_build_handle(root, steel)

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = 0.039
	shape.height = RIM_Y - BASE_Y
	col.shape = shape
	root.add_child(col)

	var floor_marker := Marker3D.new()
	floor_marker.name = "MilkFloor"
	floor_marker.position = Vector3(0, FLOOR_Y, 0)
	root.add_child(floor_marker)

	# Inside wall for the milk, low to high (reverse of INNER, without the floor centre).
	var inner_profile := PackedVector2Array()
	for i in range(INNER.size() - 2, -1, -1):
		inner_profile.append(INNER[i])
	root.set_meta("inner_profile", inner_profile)
	return root

## Pulls the top of the wall out and up toward -Z into a pointed spout.
static func _spout(v: Vector3, angle: float) -> Vector3:
	var t := clampf((v.y - 0.025) / (RIM_Y - 0.025), 0.0, 1.0)
	if t <= 0.0:
		return v
	var facing := maxf(0.0, -cos(angle))
	var w := pow(facing, 5.0) * t * t
	return v + Vector3(0, w * 0.006, -w * 0.016)

static func _build_handle(root: Node3D, steel: Material) -> void:
	var handle := MK.group(root, "Handle")
	# C handle in the YZ plane: leaves the wall under the rim, runs out, curves
	# down and tucks back into the belly. Edit the points to reshape it.
	var path := PackedVector3Array([
		Vector3(0, 0.035, 0.029), Vector3(0, 0.037, 0.043), Vector3(0, 0.035, 0.054),
		Vector3(0, 0.028, 0.061), Vector3(0, 0.016, 0.063), Vector3(0, 0.0, 0.061),
		Vector3(0, -0.013, 0.056), Vector3(0, -0.022, 0.049), Vector3(0, -0.027, 0.041),
		Vector3(0, -0.028, 0.036),
	])
	MK.sweep(handle, "Grip", path, 0.0055, 0.003, steel)
	# Thumb rest: a flat pad on top of the arm.
	MK.box(handle, "ThumbRest", Vector3(0.013, 0.002, 0.011), Vector3(0, 0.0395, 0.046), steel)
