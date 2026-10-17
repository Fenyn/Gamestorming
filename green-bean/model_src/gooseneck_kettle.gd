extends RefCounted

## Gooseneck pour-over kettle, the common 1 litre stovetop kind.
##
## Real size: about 14.4 cm across the base, 13 cm tall, 29.5 cm from spout tip
## to handle, with a 7.8 cm lid opening. The body is a squat dome that narrows
## to a small lid with a knob. The thin gooseneck leaves the body low down,
## rises in an S and bends down at the tip. The black handle is opposite.
##
## Origin is the middle of the body, so the base sits at y = -0.06. The spout
## points along -X and the handle along +X: tilting the kettle about +Z pours,
## and when carried the handle is on the right, by your hand.
##
## Nodes the Kettle script and stations use:
##   Collision   CylinderShape3D for the body. Moved onto the Kettle item at
##               runtime, so resize it here if you change the shape.
##   SpoutTip    Marker3D at the mouth of the spout. Water streams from here,
##               and pours place the kettle so this lands over the target.
##   Lid         Node3D holding the lid and knob. Moved to LidParked while the
##               kettle fills.
##   LidParked   Marker3D for the lid's parked spot: hung on the LidClip on the
##               front (+Z) of the body, dome out, like a fuel cap on its holder.

const MK := preload("res://model_src/model_kit.gd")

const BASE_Y := -0.06
const SHOULDER_Y := 0.045
const STEEL := Color(0.82, 0.83, 0.85)
const HANDLE_BLACK := Color(0.1, 0.1, 0.11)

## Outside of the body, base to the lid seat. Closed by the lid, so no inside.
const BODY := [
	Vector2(0.0, BASE_Y), Vector2(0.066, BASE_Y), Vector2(0.0705, BASE_Y + 0.004),
	Vector2(0.072, -0.045), Vector2(0.0715, -0.025), Vector2(0.068, -0.005),
	Vector2(0.061, 0.015), Vector2(0.052, 0.031), Vector2(0.043, SHOULDER_Y - 0.004),
	Vector2(0.041, SHOULDER_Y), Vector2(0.041, SHOULDER_Y + 0.003),
	Vector2(0.036, SHOULDER_Y + 0.003), Vector2(0.0, SHOULDER_Y + 0.003),
]

## Gooseneck centre line in the XY plane, from the body out to the tip.
const SPOUT_PATH := [
	Vector3(-0.060, -0.040, 0), Vector3(-0.076, -0.036, 0), Vector3(-0.089, -0.026, 0),
	Vector3(-0.098, -0.008, 0), Vector3(-0.106, 0.016, 0), Vector3(-0.116, 0.040, 0),
	Vector3(-0.130, 0.060, 0), Vector3(-0.146, 0.071, 0), Vector3(-0.160, 0.072, 0),
	Vector3(-0.170, 0.066, 0),
]

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "GooseneckKettle"
	var steel: StandardMaterial3D = MK.mat(STEEL, 0.75, 0.25)

	var profile := PackedVector2Array()
	for p in BODY:
		profile.append(p)
	MK.lathe(root, "Body", profile, Vector3.ZERO, steel, 32)
	# Rolled seam where the base meets the wall.
	MK.torus(root, "BaseSeam", 0.0665, 0.0712, Vector3(0, BASE_Y + 0.004, 0), MK.mat(Color(0.7, 0.71, 0.73), 0.7, 0.35))

	_build_spout(root, steel)
	_build_handle(root, steel)
	_build_lid(root, steel)
	_build_lid_clip(root, steel)

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = 0.072
	shape.height = 0.12
	col.shape = shape
	root.add_child(col)
	return root

static func _build_spout(root: Node3D, steel: Material) -> void:
	var spout := MK.group(root, "Spout")
	var path := PackedVector3Array()
	for p in SPOUT_PATH:
		path.append(p)
	# Thicker where it leaves the body, thin through the neck.
	var lower := path.slice(0, 4)
	MK.sweep(spout, "SpoutBase", lower, 0.0075, 0.0075, steel, Vector3.BACK, 12)
	MK.sweep(spout, "Neck", path.slice(2), 0.0048, 0.0048, steel, Vector3.BACK, 12)
	# Weld collar on the body.
	MK.sphere(spout, "Collar", 0.0095, path[0] + Vector3(0.004, 0, 0), steel, 0.8, 12)
	# Mouth: just past the end of the bent-down tip.
	var tip: Vector3 = path[path.size() - 1]
	var before: Vector3 = path[path.size() - 2]
	var dir := (tip - before).normalized()
	MK.marker(root, "SpoutTip", tip + dir * 0.002)

static func _build_handle(root: Node3D, steel: Material) -> void:
	var handle := MK.group(root, "Handle")
	var black: Material = MK.mat(HANDLE_BLACK, 0.0, 0.6)
	# Steel bracket at the shoulder, then a black grip arcing out and down
	# to a lower mount on the body.
	MK.box(handle, "TopBracket", Vector3(0.026, 0.006, 0.016), Vector3(0.05, 0.036, 0), steel, Vector3(0, 0, -30))
	MK.box(handle, "LowBracket", Vector3(0.014, 0.008, 0.014), Vector3(0.071, -0.03, 0), steel)
	var path := PackedVector3Array([
		Vector3(0.058, 0.042, 0), Vector3(0.075, 0.056, 0), Vector3(0.095, 0.060, 0),
		Vector3(0.112, 0.052, 0), Vector3(0.122, 0.034, 0), Vector3(0.122, 0.010, 0),
		Vector3(0.114, -0.012, 0), Vector3(0.099, -0.027, 0), Vector3(0.082, -0.032, 0),
		Vector3(0.074, -0.031, 0),
	])
	MK.sweep(handle, "Grip", path, 0.008, 0.0065, black, Vector3.BACK, 12)
	# Finger ridges on the inside of the grip.
	for i in range(3):
		var p := Vector3(0.113 - i * 0.002, 0.03 - i * 0.014, 0)
		MK.box(handle, "Ridge", Vector3(0.004, 0.003, 0.014), p, black)

static func _build_lid(root: Node3D, steel: Material) -> void:
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, SHOULDER_Y + 0.003, 0)
	root.add_child(lid)
	var lid_profile := PackedVector2Array([
		Vector2(0.0, -0.002), Vector2(0.040, -0.002), Vector2(0.040, 0.001),
		Vector2(0.034, 0.006), Vector2(0.018, 0.009), Vector2(0.0, 0.0095),
	])
	MK.lathe(lid, "LidDome", lid_profile, Vector3.ZERO, steel, 28)
	var black: Material = MK.mat(HANDLE_BLACK, 0.0, 0.6)
	MK.cyl(lid, "KnobStem", 0.005, 0.006, 0.006, Vector3(0, 0.012, 0), black, 12)
	MK.sphere(lid, "Knob", 0.009, Vector3(0, 0.019, 0), black, 0.75, 12)

## Small steel holder on the front of the body. While filling, the lid hangs
## here upright with its lower rim on the shelf, so it is not left floating.
static func _build_lid_clip(root: Node3D, steel: Material) -> void:
	var clip := MK.group(root, "LidClip")
	var wall_z := 0.0712
	# Back plate spot-welded to the body, a shelf sticking out, and a lip.
	MK.box(clip, "Plate", Vector3(0.018, 0.014, 0.002), Vector3(0, -0.012, wall_z), steel)
	MK.box(clip, "Shelf", Vector3(0.024, 0.0025, 0.012), Vector3(0, -0.0185, wall_z + 0.006), steel)
	MK.box(clip, "Lip", Vector3(0.024, 0.007, 0.002), Vector3(0, -0.0155, wall_z + 0.0115), steel)
	# Lid stands on the shelf between plate and lip, dome facing out, leaning
	# back against the body's curve. Its rim radius is 0.04, so its centre sits
	# about 0.04 up the tilted lid from the shelf.
	var lean := deg_to_rad(12.0)
	var centre := Vector3(0, -0.017 + 0.04 * cos(lean), wall_z + 0.006 - 0.04 * sin(lean))
	MK.marker(root, "LidParked", centre, Vector3(90.0 - 12.0, 0, 0))
