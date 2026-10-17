extends RefCounted

## Hand coffee grinder: a cast iron countertop wheel mill, the kind general
## stores used. A big spoked flywheel on one side turns the burrs, beans go in
## an open bowl hopper on top, and the grounds fall out of a chute at the front
## into whatever stands on the base below.
##
## Real one-wheel store mills are about 46 cm wide and 53 cm tall. This one is
## a smaller household-sized wheel mill (about 30 cm wide, 39 cm tall, 22 cm
## deep, 24 cm wheel) so it fits the stand's counter. It is painted red with
## gold striping, like most of them were.
##
## Origin is the middle of the base's underside, so it sits on the counter at
## y = 0. Front faces +Z (the barista). The wheel is on +X.
##
## Nodes the station script uses (move them in the editor and the station follows):
##   Crank       Node3D holding the wheel and its handle. The station spins it
##               about its X axis while grinding.
##   DevicePad   Marker3D on the base under the chute, where the dripper or shot
##               press is set down.
##   SpoutTip    Marker3D at the chute mouth, where the grounds fall from.
##   GaugeAnchor Marker3D where the grind mini-game's bar and label are drawn.
##   CameraView  Marker3D for the grinding camera.
##
## Colliders live in scenes/stations/grinder.tscn.

const MK := preload("res://model_src/model_kit.gd")

const BASE_SIZE := Vector3(0.24, 0.025, 0.22)
const BASE_X := 0.02
const BASE_TOP := 0.025
## Burr housing: a drum on the X axis behind the chute.
const HOUSING_C := Vector3(0, 0.235, -0.035)
const HOUSING_R := 0.048
const HOUSING_LEN := 0.07
## Flywheel centre, on the same axle, outboard on +X.
const WHEEL_C := Vector3(0.105, 0.235, -0.035)
const WHEEL_R := 0.12
const PAD := Vector3(0, BASE_TOP, 0.05)
## Chute mouth: above the tallest device (the shot press, about 12 cm).
const SPOUT := Vector3(0, 0.168, 0.05)

const IRON_RED := Color(0.55, 0.11, 0.09)
const GOLD := Color(0.83, 0.66, 0.3)
const IRON := Color(0.16, 0.15, 0.15)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "HandGrinder"
	var red: Material = MK.mat(IRON_RED, 0.25, 0.45)
	var gold: Material = MK.mat(GOLD, 0.7, 0.35)
	var iron: Material = MK.mat(IRON, 0.5, 0.5)

	_build_base(root)
	_build_frame(root, red, gold)
	_build_housing(root, red, gold, iron)
	_build_hopper(root, red, gold)
	_build_chute(root, red, gold)
	_build_wheel(root, red, gold, iron)

	MK.marker(root, "DevicePad", PAD)
	MK.marker(root, "SpoutTip", SPOUT)
	MK.marker(root, "GaugeAnchor", Vector3(-0.2, 0.3, 0.06))
	var cam_pos := Vector3(-0.08, 0.36, 0.42)
	var look := Vector3(0.02, 0.17, 0.0)
	var e := Basis.looking_at(look - cam_pos).get_euler()
	MK.marker(root, "CameraView", cam_pos, Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)))
	return root

static func _build_base(root: Node3D) -> void:
	var base := MK.group(root, "Base")
	var wood: Material = MK.mat(MK.WOOD_DARKER, 0.0, 0.6)
	MK.rounded_box(base, "Board", BASE_SIZE, Vector3(BASE_X, BASE_SIZE.y * 0.5, 0), 0.01, wood)
	# Painted stripe around the board's edge.
	var stripe: Material = MK.mat(GOLD, 0.2, 0.5)
	MK.box(base, "StripeFront", Vector3(BASE_SIZE.x - 0.02, 0.003, 0.001), Vector3(BASE_X, BASE_SIZE.y * 0.5, BASE_SIZE.z * 0.5 + 0.0003), stripe)
	for sx in [-1.0, 1.0]:
		MK.box(base, "StripeSide", Vector3(0.001, 0.003, BASE_SIZE.z - 0.02), Vector3(BASE_X + float(sx) * (BASE_SIZE.x * 0.5 + 0.0003), BASE_SIZE.y * 0.5, 0), stripe)
	# Worn ring where cups and brewers have been set under the chute.
	MK.torus(base, "PadRing", 0.046, 0.05, PAD + Vector3(0, 0.0005, 0), MK.mat(Color(0.3, 0.2, 0.13), 0.0, 0.8))

static func _build_frame(root: Node3D, red: Material, gold: Material) -> void:
	var frame := MK.group(root, "Frame")
	# Cast foot bolted to the board, and a waisted pillar up to the housing.
	var foot_c := Vector3(0, BASE_TOP, HOUSING_C.z - 0.01)
	MK.cyl(frame, "Foot", 0.06, 0.066, 0.016, foot_c + Vector3(0, 0.008, 0), red, 24)
	MK.torus(frame, "FootBead", 0.058, 0.063, foot_c + Vector3(0, 0.016, 0), gold)
	var pillar_bottom := BASE_TOP + 0.016
	var pillar_top := HOUSING_C.y - HOUSING_R + 0.01
	var profile := PackedVector2Array([
		Vector2(0.0, pillar_bottom), Vector2(0.042, pillar_bottom), Vector2(0.03, pillar_bottom + 0.03),
		Vector2(0.022, (pillar_bottom + pillar_top) * 0.5), Vector2(0.026, pillar_top - 0.025),
		Vector2(0.038, pillar_top), Vector2(0.0, pillar_top),
	])
	MK.lathe(frame, "Pillar", profile, Vector3(0, 0, foot_c.z), red, 20)
	for i in range(4):
		var a := TAU * (float(i) + 0.5) / 4.0
		MK.cyl(frame, "Bolt", 0.0045, 0.0045, 0.006, foot_c + Vector3(sin(a) * 0.05, 0.016, cos(a) * 0.05), MK.mat(IRON, 0.5, 0.5), 8)

static func _build_housing(root: Node3D, red: Material, gold: Material, iron: Material) -> void:
	var housing := MK.group(root, "BurrHousing")
	# Drum on the X axis, with gold bands at each end.
	MK.cyl(housing, "Drum", HOUSING_R, HOUSING_R, HOUSING_LEN, HOUSING_C, red, 28, Vector3(0, 0, 90))
	for sx in [-1.0, 1.0]:
		MK.torus(housing, "Band", HOUSING_R - 0.002, HOUSING_R + 0.0035, HOUSING_C + Vector3(float(sx) * (HOUSING_LEN * 0.5 - 0.004), 0, 0), gold, Vector3(0, 0, 90))
	# Grind adjustment: a thumb nut on the end of the axle, on the -X side.
	var nut_x := HOUSING_C.x - HOUSING_LEN * 0.5
	MK.cyl(housing, "AdjustBoss", 0.016, 0.02, 0.012, HOUSING_C + Vector3(nut_x - HOUSING_C.x - 0.006, 0, 0), red, 16, Vector3(0, 0, 90))
	var nut := MK.cyl(housing, "AdjustNut", 0.011, 0.011, 0.01, HOUSING_C + Vector3(nut_x - HOUSING_C.x - 0.017, 0, 0), gold, 6, Vector3(0, 0, 90))
	nut.rotation_degrees.x = 30.0
	for i in range(2):
		MK.box(housing, "Wing", Vector3(0.004, 0.034, 0.008), HOUSING_C + Vector3(nut_x - HOUSING_C.x - 0.025, 0, 0), iron, Vector3(float(i) * 90.0, 0, 0))
	# Axle from the drum out to the wheel hub.
	MK.cyl(housing, "Axle", 0.007, 0.007, WHEEL_C.x - HOUSING_C.x - HOUSING_LEN * 0.5 + 0.004, Vector3((HOUSING_C.x + HOUSING_LEN * 0.5 + WHEEL_C.x) * 0.5, HOUSING_C.y, HOUSING_C.z), iron, 10, Vector3(0, 0, 90))

static func _build_hopper(root: Node3D, red: Material, gold: Material) -> void:
	var hopper := MK.group(root, "Hopper")
	var neck_y := HOUSING_C.y + HOUSING_R - 0.006
	var top_y := neck_y + 0.09
	# Open flared bowl on a short neck, wall traced up the outside and down the inside.
	var profile := PackedVector2Array([
		Vector2(0.0, neck_y), Vector2(0.026, neck_y), Vector2(0.03, neck_y + 0.02),
		Vector2(0.06, neck_y + 0.055), Vector2(0.078, top_y - 0.004), Vector2(0.081, top_y),
		Vector2(0.075, top_y), Vector2(0.056, neck_y + 0.058), Vector2(0.026, neck_y + 0.026),
		Vector2(0.0, neck_y + 0.024),
	])
	MK.lathe(hopper, "Bowl", profile, Vector3(0, 0, HOUSING_C.z), red, 32)
	MK.torus(hopper, "RimBead", 0.076, 0.083, Vector3(0, top_y - 0.001, HOUSING_C.z), gold)
	MK.torus(hopper, "NeckBead", 0.025, 0.031, Vector3(0, neck_y + 0.006, HOUSING_C.z), gold)
	# Beans heaped in the bowl.
	var beans := MK.group(hopper, "Beans")
	var bean_mat: Material = MK.mat(MK.BEANS, 0.0, 0.6)
	var bed_y := neck_y + 0.05
	MK.cyl(beans, "BeanBed", 0.05, 0.046, 0.004, Vector3(0, bed_y, HOUSING_C.z), bean_mat, 24)
	for i in range(26):
		var a := float(i) * 2.399
		var r := 0.046 * sqrt((float(i) + 0.5) / 26.0)
		var p := Vector3(sin(a) * r, bed_y + 0.004 + (0.046 - r) * 0.12, HOUSING_C.z + cos(a) * r)
		var bean := MK.sphere(beans, "Bean", 0.0055, p, bean_mat, 0.65, 6)
		bean.rotation = Vector3(float(i) * 0.7, a, 0.0)

static func _build_chute(root: Node3D, red: Material, gold: Material) -> void:
	var chute := MK.group(root, "Chute")
	# Square throat out of the front of the drum, angled down to the mouth.
	var start := HOUSING_C + Vector3(0, -HOUSING_R * 0.35, HOUSING_R * 0.7)
	var mouth := SPOUT + Vector3(0, 0.006, 0)
	var dir := (mouth - start).normalized()
	var length := start.distance_to(mouth)
	var throat := MK.box(chute, "Throat", Vector3(0.034, length, 0.028), Vector3.ZERO, red)
	var side := Vector3.RIGHT
	var fwd := side.cross(dir).normalized()
	throat.transform = Transform3D(Basis(side, dir, fwd), (start + mouth) * 0.5)
	# Flared mouth with a gold lip, pointing straight down at the pad.
	MK.cyl(chute, "Mouth", 0.02, 0.024, 0.014, SPOUT + Vector3(0, 0.007, 0), red, 16)
	MK.torus(chute, "MouthLip", 0.018, 0.022, SPOUT + Vector3(0, 0.0005, 0), gold)
	MK.cyl(chute, "Opening", 0.015, 0.015, 0.002, SPOUT, MK.mat(Color(0.06, 0.05, 0.05), 0.0, 0.9), 16)

static func _build_wheel(root: Node3D, red: Material, gold: Material, iron: Material) -> void:
	# Everything that turns hangs off one node at the hub.
	var crank := Node3D.new()
	crank.name = "Crank"
	crank.position = WHEEL_C
	root.add_child(crank)
	# Rim in the YZ plane, with a gold stripe on its face.
	MK.torus(crank, "Rim", WHEEL_R - 0.012, WHEEL_R, Vector3.ZERO, red, Vector3(0, 0, 90), 48)
	MK.torus(crank, "RimStripe", WHEEL_R - 0.008, WHEEL_R - 0.005, Vector3(0.006, 0, 0), gold, Vector3(0, 0, 90), 48)
	# Hub and six S-curved spokes.
	MK.cyl(crank, "Hub", 0.02, 0.02, 0.026, Vector3.ZERO, red, 16, Vector3(0, 0, 90))
	MK.cyl(crank, "HubCap", 0.012, 0.014, 0.008, Vector3(0.016, 0, 0), gold, 16, Vector3(0, 0, 90))
	for i in range(6):
		var a := TAU * float(i) / 6.0
		var path := PackedVector3Array()
		for k in range(6):
			var t := float(k) / 5.0
			var r := lerpf(0.016, WHEEL_R - 0.008, t)
			var bend := a + sin(t * PI) * 0.22
			path.append(Vector3(0, cos(bend) * r, sin(bend) * r))
		MK.sweep(crank, "Spoke", path, 0.005, 0.0055, red, Vector3.RIGHT, 8)
	# Turned wooden handle on the rim, sticking out toward +X.
	var grip_at := Vector3(0, WHEEL_R - 0.006, 0)
	MK.cyl(crank, "HandlePin", 0.005, 0.005, 0.02, grip_at + Vector3(0.012, 0, 0), iron, 10, Vector3(0, 0, 90))
	MK.cyl(crank, "HandleGrip", 0.011, 0.009, 0.055, grip_at + Vector3(0.048, 0, 0), MK.mat(MK.WOOD_DARKER, 0.0, 0.5), 14, Vector3(0, 0, 90))
	MK.sphere(crank, "HandleEnd", 0.0105, grip_at + Vector3(0.076, 0, 0), MK.mat(MK.WOOD_DARKER, 0.0, 0.5), 0.8, 10)
