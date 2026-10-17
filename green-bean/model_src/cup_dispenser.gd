extends RefCounted

## Four gravity cup tubes (S, M, L, XL) on a steel bracket under the front
## counter's lip. Cups stack mouth-down and the bottom one is pulled out
## through a gripper ring. Clear tubes show the stacks.
## Origin: the station's mount point, 0.161 below the counter top. The bracket
## is on +Z against the counter; the barista is on -Z.
##
## Read by cup_stack.gd: Dispense_<size> markers (small, medium, large,
## extra_large) where a grabbed cup appears. Colliders are in
## scenes/stations/cup_stack.tscn.

const MK := preload("res://model_src/model_kit.gd")

const SIZES := [["small", 0.040, 0.028], ["medium", 0.045, 0.030], ["large", 0.045, 0.030], ["extra_large", 0.045, 0.030]]
const LETTERS := ["S", "M", "L", "XL"]
const SPACING := 0.108
const TUBE_TOP := 0.15
const TUBE_BOTTOM := -0.12
const TUBE_Z := -0.01
const BRACKET_Z := 0.06
const PAPER := Color(0.96, 0.95, 0.92)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "CupDispenser"
	var steel: Material = MK.mat(Color(0.78, 0.79, 0.8), 0.7, 0.32)
	var black: Material = MK.mat(Color(0.1, 0.1, 0.11), 0.0, 0.6)
	var paper: Material = MK.mat(PAPER, 0.0, 0.8)
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.85, 0.9, 0.95, 0.22)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.1

	var width := SPACING * 4.0 + 0.02
	MK.box(root, "Bracket", Vector3(width, TUBE_TOP - TUBE_BOTTOM + 0.02, 0.004), Vector3(0, (TUBE_TOP + TUBE_BOTTOM) * 0.5, BRACKET_Z), steel)
	MK.box(root, "TopRail", Vector3(width, 0.008, 0.08), Vector3(0, TUBE_TOP + 0.004, TUBE_Z + 0.02), steel)

	for i in range(4):
		# S on the barista's left: the barista looks along +Z, so +X is their left.
		var x := (1.5 - float(i)) * SPACING
		var top_r: float = SIZES[i][1]
		var bottom_r: float = SIZES[i][2]
		var tube_r := top_r + 0.004
		var c := Vector3(x, 0, TUBE_Z)
		var tube := MK.group(root, "Tube_" + str(SIZES[i][0]))
		# Clear tube with a lip at the top.
		var profile := PackedVector2Array([
			Vector2(tube_r - 0.002, TUBE_BOTTOM), Vector2(tube_r, TUBE_BOTTOM),
			Vector2(tube_r, TUBE_TOP), Vector2(tube_r - 0.002, TUBE_TOP), Vector2(tube_r - 0.002, TUBE_BOTTOM),
		])
		MK.lathe(tube, "Tube", profile, c, clear, 24)
		MK.box(tube, "Clamp", Vector3(0.024, 0.016, BRACKET_Z - TUBE_Z - tube_r), Vector3(x, TUBE_TOP - 0.04, (TUBE_Z + tube_r + BRACKET_Z) * 0.5), steel)
		# Gripper ring at the bottom, with the fingers that hold the stack.
		MK.torus(tube, "Gripper", tube_r - 0.004, tube_r + 0.004, c + Vector3(0, TUBE_BOTTOM, 0), black, Vector3.ZERO, 24)
		for k in range(6):
			var a := TAU * float(k) / 6.0
			var finger := MK.box(tube, "Finger", Vector3(0.008, 0.006, 0.004), c + Vector3(sin(a) * (top_r - 0.001), TUBE_BOTTOM - 0.002, cos(a) * (top_r - 0.001)), black)
			finger.rotation.y = a
		# The stack: nested cups mouth-down, showing a rim every 1.2 cm, and the
		# bottom cup's base sticking out below the gripper.
		var stack_bottom := TUBE_BOTTOM - 0.012
		MK.cyl(tube, "Stack", top_r - 0.0005, top_r - 0.0005, TUBE_TOP - 0.03 - stack_bottom, c + Vector3(0, (TUBE_TOP - 0.03 + stack_bottom) * 0.5, 0), paper, 24)
		var y := stack_bottom + 0.004
		while y < TUBE_TOP - 0.035:
			MK.torus(tube, "Rim", top_r - 0.0012, top_r + 0.0012, c + Vector3(0, y, 0), paper, Vector3.ZERO, 24)
			y += 0.012
		var out_h := 0.05
		MK.cyl(tube, "BottomCup", top_r - 0.0005, lerpf(top_r, bottom_r, out_h / 0.11), out_h, c + Vector3(0, stack_bottom - out_h * 0.5, 0), paper, 24)
		var tag := Label3D.new()
		tag.name = "SizeTag"
		tag.text = LETTERS[i]
		tag.font_size = 48
		tag.pixel_size = 0.0004
		tag.outline_size = 0
		tag.modulate = Color(0.12, 0.12, 0.13)
		tag.position = Vector3(x, TUBE_TOP - 0.022, TUBE_Z - tube_r - 0.001)
		tag.rotation_degrees = Vector3(0, 180, 0)
		tube.add_child(tag)
		MK.marker(root, "Dispense_" + str(SIZES[i][0]), c + Vector3(0, stack_bottom - 0.07, 0))
	return root
