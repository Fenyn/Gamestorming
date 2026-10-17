extends RefCounted

## Milk steaming pitcher: a 12 oz stainless pitcher like the ones on every bar.
##
## Shape follows real 350 ml pitchers (about 8 cm across at the belly, 10-12 cm
## tall): a wide belly that narrows toward the top so the milk can spin, a
## pointed pour spout, and a C handle opposite the spout.
##
## Origin is the centre of the item's 0.12 m tall, 0.04 m radius collision
## cylinder, so the base sits at y = -0.06. The spout points along -Z and the
## handle along +Z, so on the steamer pad the handle faces the barista and the
## spout faces the wand, and when carried the spout points away from you.
##
## Nodes the Pitcher script uses:
##   MilkFloor     Marker3D on the inside floor. Milk is drawn up from here.
##   Root metadata "inner_profile": (radius, y) points of the inside wall, low
##                 to high. The milk narrows to follow it as it rises.

const MK := preload("res://model_src/model_kit.gd")

const BASE_Y := -0.06
const RIM_Y := 0.06
const FLOOR_Y := -0.054
const STEEL := Color(0.8, 0.81, 0.83)

## Outside wall, bottom to rim.
const OUTER := [
	Vector2(0.0, BASE_Y), Vector2(0.034, BASE_Y), Vector2(0.038, BASE_Y + 0.003),
	Vector2(0.040, -0.045), Vector2(0.0405, -0.025), Vector2(0.039, 0.0),
	Vector2(0.036, 0.025), Vector2(0.0335, 0.045), Vector2(0.034, 0.055),
	Vector2(0.0355, RIM_Y),
]
## Inside wall, rim to floor. Wall is about 1.5 mm thick.
const INNER := [
	Vector2(0.0335, RIM_Y), Vector2(0.032, 0.055), Vector2(0.032, 0.045),
	Vector2(0.0345, 0.025), Vector2(0.0375, 0.0), Vector2(0.039, -0.025),
	Vector2(0.0385, -0.045), Vector2(0.035, FLOOR_Y + 0.002), Vector2(0.0, FLOOR_Y),
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
	var t := clampf((v.y - 0.035) / (RIM_Y - 0.035), 0.0, 1.0)
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
		Vector3(0, 0.046, 0.030), Vector3(0, 0.048, 0.045), Vector3(0, 0.046, 0.057),
		Vector3(0, 0.038, 0.065), Vector3(0, 0.024, 0.067), Vector3(0, 0.005, 0.065),
		Vector3(0, -0.012, 0.060), Vector3(0, -0.024, 0.052), Vector3(0, -0.030, 0.042),
		Vector3(0, -0.031, 0.036),
	])
	MK.sweep(handle, "Grip", path, 0.0055, 0.003, steel)
	# Thumb rest: a flat pad on top of the arm.
	MK.box(handle, "ThumbRest", Vector3(0.013, 0.002, 0.012), Vector3(0, 0.0505, 0.05), steel)
