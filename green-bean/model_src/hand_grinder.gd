extends RefCounted

## Modern hand burr grinder (5 cm x 17 cm, 13 cm crank) in a wooden holder, with a
## device pad beside it. Origin: holder underside, on the counter at y = 0. Front
## faces +Z; grinder on -X, pad on +X.
##
## Read by grinder_station.gd: Crank (spun about root metadata "crank_axis"),
## CatchCup and CatchCup/CupLip (tipped into the device at DumpPoint, whose
## rotation is the tipped pose), DevicePad, GaugeAnchor, CameraView. Colliders are
## in scenes/stations/grinder.tscn.

const MK := preload("res://model_src/model_kit.gd")

const BASE_SIZE := Vector3(0.24, 0.02, 0.15)
const BASE_X := 0.01
const BASE_TOP := 0.02
const GRINDER_XZ := Vector2(-0.06, -0.015)
const BODY_R := 0.025
const CUP_H := 0.045
const ADJUST_H := 0.012
const BODY_H := 0.1
const CAP_H := 0.01
const PAD := Vector3(0.062, BASE_TOP, 0.02)

const STEEL := Color(0.78, 0.79, 0.8)
const STEEL_DARK := Color(0.55, 0.56, 0.58)
const RUBBER := Color(0.12, 0.12, 0.13)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "HandGrinder"
	var steel: Material = MK.mat(STEEL, 0.7, 0.32)
	var steel_dark: Material = MK.mat(STEEL_DARK, 0.6, 0.4)
	var rubber: Material = MK.mat(RUBBER, 0.0, 0.85)
	var wood: Material = MK.mat(MK.WOOD, 0.0, 0.65)
	var wood_dark: Material = MK.mat(MK.WOOD_DARK, 0.0, 0.65)

	_build_holder(root, wood, wood_dark, rubber)
	var g := Vector3(GRINDER_XZ.x, BASE_TOP + 0.003, GRINDER_XZ.y)
	_build_catch_cup(root, g, steel, steel_dark)
	var body_bottom := g.y + CUP_H
	_build_body(root, g, body_bottom, steel, steel_dark, rubber)
	_build_crank(root, Vector3(g.x, body_bottom + ADJUST_H + BODY_H + CAP_H, g.z), steel, wood_dark)

	root.set_meta("crank_axis", Vector3.UP)
	MK.marker(root, "DevicePad", PAD)
	# Cup centre sits right of the pad so the tipped opening is over its middle.
	MK.marker(root, "DumpPoint", Vector3(PAD.x + 0.034, 0.188, PAD.z), Vector3(0, 0, 115))
	MK.marker(root, "GaugeAnchor", Vector3(-0.2, 0.26, 0.05))
	var cam_pos := Vector3(-0.07, 0.36, 0.4)
	var look := Vector3(0.0, 0.13, 0.0)
	var e := Basis.looking_at(look - cam_pos).get_euler()
	MK.marker(root, "CameraView", cam_pos, Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)))
	return root

static func _build_holder(root: Node3D, wood: Material, wood_dark: Material, rubber: Material) -> void:
	var holder := MK.group(root, "Holder")
	MK.rounded_box(holder, "Base", BASE_SIZE, Vector3(BASE_X, BASE_SIZE.y * 0.5, 0), 0.012, wood)
	MK.cyl(holder, "GrinderMat", 0.032, 0.032, 0.003, Vector3(GRINDER_XZ.x, BASE_TOP + 0.0015, GRINDER_XZ.y), MK.mat(Color(0.62, 0.45, 0.3), 0.0, 0.95), 24)
	MK.torus(holder, "PadRing", 0.052, 0.056, PAD + Vector3(0, 0.0005, 0), MK.mat(Color(0.55, 0.36, 0.22), 0.0, 0.8), Vector3.ZERO, 32)
	# Clamp ring holds the grinder so the catch cup can come off underneath.
	var post_z := GRINDER_XZ.y - 0.045
	var clamp_y := BASE_TOP + CUP_H + 0.045
	MK.rounded_box(holder, "Post", Vector3(0.024, clamp_y + 0.012 - BASE_TOP, 0.018), Vector3(GRINDER_XZ.x, (BASE_TOP + clamp_y + 0.012) * 0.5, post_z), 0.005, wood_dark)
	MK.box(holder, "ClampArm", Vector3(0.02, 0.014, 0.02), Vector3(GRINDER_XZ.x, clamp_y, post_z + 0.015), wood_dark)
	MK.torus(holder, "ClampRing", BODY_R + 0.0015, BODY_R + 0.008, Vector3(GRINDER_XZ.x, clamp_y, GRINDER_XZ.y), wood_dark, Vector3.ZERO, 32)
	MK.torus(holder, "ClampPad", BODY_R + 0.001, BODY_R + 0.0025, Vector3(GRINDER_XZ.x, clamp_y, GRINDER_XZ.y), rubber, Vector3.ZERO, 32)

static func _build_catch_cup(root: Node3D, g: Vector3, steel: Material, steel_dark: Material) -> void:
	var cup := Node3D.new()
	cup.name = "CatchCup"
	cup.position = g + Vector3(0, CUP_H * 0.5, 0)
	root.add_child(cup)
	var h := CUP_H * 0.5
	var profile := PackedVector2Array([
		Vector2(0.0, -h), Vector2(BODY_R - 0.003, -h), Vector2(BODY_R, -h + 0.003),
		Vector2(BODY_R, h - 0.006), Vector2(BODY_R - 0.0015, h - 0.005), Vector2(BODY_R - 0.0015, h),
		Vector2(BODY_R - 0.003, h), Vector2(BODY_R - 0.003, -h + 0.002), Vector2(0.0, -h + 0.002),
	])
	MK.lathe(cup, "Cup", profile, Vector3.ZERO, steel, 32)
	MK.cyl(cup, "Thread", BODY_R - 0.0012, BODY_R - 0.0012, 0.004, Vector3(0, h - 0.0025, 0), steel_dark, 32)
	MK.marker(cup, "CupLip", Vector3(0, h, 0))

static func _build_body(root: Node3D, g: Vector3, body_bottom: float, steel: Material, steel_dark: Material, rubber: Material) -> void:
	var body := MK.group(root, "Body")
	var x := g.x
	var z := g.z
	var adj_y := body_bottom + ADJUST_H * 0.5
	MK.cyl(body, "AdjustRing", BODY_R + 0.0012, BODY_R + 0.0012, ADJUST_H, Vector3(x, adj_y, z), steel_dark, 24)
	for i in range(24):
		var a := TAU * float(i) / 24.0
		var knurl := MK.box(body, "Knurl", Vector3(0.0016, ADJUST_H * 0.8, 0.0012), Vector3(x + sin(a) * (BODY_R + 0.0016), adj_y, z + cos(a) * (BODY_R + 0.0016)), steel_dark)
		knurl.rotation.y = a
	var white: Material = MK.mat(Color(0.95, 0.95, 0.95), 0.0, 0.5)
	MK.box(body, "IndexMark", Vector3(0.002, 0.006, 0.0008), Vector3(x, adj_y + ADJUST_H * 0.5 + 0.004, z + BODY_R + 0.0004), white)
	var main_bottom := body_bottom + ADJUST_H
	MK.cyl(body, "Barrel", BODY_R, BODY_R, BODY_H, Vector3(x, main_bottom + BODY_H * 0.5, z), steel, 32)
	MK.cyl(body, "Grip", BODY_R + 0.0015, BODY_R + 0.0015, BODY_H * 0.45, Vector3(x, main_bottom + BODY_H * 0.48, z), rubber, 32)
	for i in range(3):
		MK.torus(body, "GripRib", BODY_R + 0.0008, BODY_R + 0.0026, Vector3(x, main_bottom + BODY_H * (0.32 + float(i) * 0.08), z), rubber, Vector3.ZERO, 32)
	var cap_bottom := main_bottom + BODY_H
	var cap_profile := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(BODY_R, 0.0), Vector2(BODY_R, CAP_H * 0.5),
		Vector2(BODY_R - 0.004, CAP_H), Vector2(0.0, CAP_H + 0.001),
	])
	MK.lathe(body, "Cap", cap_profile, Vector3(x, cap_bottom, z), steel, 32)

static func _build_crank(root: Node3D, top: Vector3, steel: Material, wood: Material) -> void:
	var crank := Node3D.new()
	crank.name = "Crank"
	crank.position = top
	root.add_child(crank)
	MK.cyl(crank, "Shaft", 0.004, 0.004, 0.014, Vector3(0, 0.007, 0), steel, 12)
	MK.cyl(crank, "Nut", 0.007, 0.007, 0.006, Vector3(0, 0.017, 0), steel, 6)
	var arm_len := 0.13
	MK.box(crank, "Arm", Vector3(arm_len, 0.005, 0.012), Vector3(arm_len * 0.5, 0.021, 0), steel)
	MK.cyl(crank, "ArmEnd", 0.006, 0.006, 0.005, Vector3(arm_len, 0.021, 0), steel, 16)
	MK.cyl(crank, "KnobPin", 0.0025, 0.0025, 0.01, Vector3(arm_len, 0.028, 0), steel, 8)
	MK.cyl(crank, "Knob", 0.011, 0.009, 0.026, Vector3(arm_len, 0.046, 0), wood, 16)
	MK.sphere(crank, "KnobTop", 0.009, Vector3(arm_len, 0.059, 0), wood, 0.6, 12)
