extends RefCounted

## Hand coffee grinder for the grinder station.
##
## Fits the station's 0.25 x 0.35 x 0.25 m collision box. Origin is the centre of
## that box, so the base sits at y = -0.175. Front faces +Z (the barista).
##
## Layout: a two-tier wooden base on small feet; a wooden body at the back with
## corner posts, a burr housing and a bean hopper on top; a spout that points
## forward over a ringed dosing pad where the dripper or aeropress sits.
##
## The scene also holds the parts the station script uses, so they can be moved
## in the editor:
##   Crank       Node3D the station rotates about its X axis while grinding.
##   DevicePad   Marker3D where the dripper or aeropress is set down.
##   SpoutTip    Marker3D where grind dust falls from.

const BASE_TOP := -0.139
const BODY_Z := -0.055
const BODY_SIZE := Vector3(0.13, 0.15, 0.12)
const BODY_BOTTOM := BASE_TOP
const BODY_TOP := BODY_BOTTOM + 0.15
## Centre of the dosing pad, where devices are placed.
const PAD_CENTER := Vector3(0, BASE_TOP, 0.068)
## Where the station script should hang the crank (outside the right-side boss).
const CRANK_PIVOT := Vector3(0.09, -0.04, BODY_Z)
## Tip of the spout, for the grind dust particles.
const SPOUT_TIP := Vector3(0, -0.042, 0.064)

const SPOUT_TILT := -62.0
const SPOUT_LENGTH := 0.075

const BRASS := Color(0.85, 0.68, 0.36)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "HandGrinder"
	_build_base(root)
	_build_body(root)
	_build_spout(root)
	_build_top(root)
	_build_crank_mount(root)
	_build_crank(root)
	_add_marker(root, "DevicePad", PAD_CENTER)
	_add_marker(root, "SpoutTip", SPOUT_TIP)
	return root

static func _add_marker(root: Node3D, marker_name: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = marker_name
	m.position = pos
	m.gizmo_extents = 0.03
	root.add_child(m)

## Crank arm and wooden knob, pivoting on the shaft. Rotate the Crank node about X.
static func _build_crank(root: Node3D) -> void:
	var crank := Node3D.new()
	crank.name = "Crank"
	crank.position = CRANK_PIVOT + Vector3(0.004, 0, 0)
	root.add_child(crank)
	var iron := ModelKit.mat(Color(0.25, 0.25, 0.27), 0.6, 0.35)
	var knob_wood := ModelKit.mat(Color(0.45, 0.28, 0.16))
	ModelKit.cyl(crank, "Hub", 0.012, 0.012, 0.008, Vector3.ZERO, iron, 10, Vector3(0, 0, 90))
	ModelKit.box(crank, "Arm", Vector3(0.008, 0.075, 0.014), Vector3(0.002, 0.0375, 0), iron)
	ModelKit.cyl(crank, "ArmTip", 0.008, 0.008, 0.008, Vector3(0.002, 0.075, 0), iron, 10, Vector3(0, 0, 90))
	ModelKit.cyl(crank, "Knob", 0.011, 0.011, 0.03, Vector3(0.021, 0.075, 0), knob_wood, 10, Vector3(0, 0, 90))
	ModelKit.sphere(crank, "KnobCap", 0.011, Vector3(0.036, 0.075, 0), knob_wood, 1.0, 10)

static func _build_base(root: Node3D) -> void:
	root = ModelKit.group(root, "Base")
	var wood_dark := ModelKit.mat(ModelKit.WOOD_DARK)
	var wood_darker := ModelKit.mat(ModelKit.WOOD_DARKER)
	# Four low feet, then a wide lower slab and a slightly smaller top slab,
	# which gives the edge a stepped, bevelled look.
	for x in [-0.105, 0.105]:
		for z in [-0.105, 0.105]:
			ModelKit.cyl(root, "Foot", 0.012, 0.014, 0.006, Vector3(x, -0.172, z), wood_darker, 10)
	ModelKit.box(root, "BaseLower", Vector3(0.25, 0.018, 0.25), Vector3(0, -0.16, 0), wood_dark)
	ModelKit.box(root, "BaseUpper", Vector3(0.236, 0.008, 0.236), Vector3(0, -0.147, 0), ModelKit.mat(ModelKit.WOOD_DARK.lightened(0.08)))
	ModelKit.box(root, "BaseInlay", Vector3(0.2, 0.002, 0.004), Vector3(0, BASE_TOP + 0.001, 0.115), wood_darker)

	# Dosing pad: darker disc with a thin steel ring, centred under the spout.
	ModelKit.cyl(root, "DosingPad", 0.046, 0.046, 0.003, PAD_CENTER + Vector3(0, 0.0015, 0), wood_darker, 20)
	ModelKit.torus(root, "PadRing", 0.045, 0.051, PAD_CENTER + Vector3(0, 0.002, 0), ModelKit.metal(ModelKit.METAL_DARK))

	# A few stray beans on the base.
	var bean := ModelKit.mat(ModelKit.BEANS.darkened(0.15))
	for p in [Vector3(0.085, 0, 0.09), Vector3(0.098, 0, 0.07), Vector3(-0.09, 0, 0.1)]:
		var b := ModelKit.sphere(root, "StrayBean", 0.007, (p as Vector3) + Vector3(0, BASE_TOP + 0.004, 0), bean, 0.6, 8)
		b.rotation_degrees.y = (p as Vector3).x * 900.0

static func _build_body(root: Node3D) -> void:
	root = ModelKit.group(root, "Body")
	var wood := ModelKit.mat(ModelKit.WOOD)
	var wood_dark := ModelKit.mat(ModelKit.WOOD_DARK)
	var wood_darker := ModelKit.mat(ModelKit.WOOD_DARKER)
	var body_center := Vector3(0, BODY_BOTTOM + BODY_SIZE.y * 0.5, BODY_Z)
	ModelKit.box(root, "Panels", BODY_SIZE, body_center, wood)

	# Corner posts, slightly proud of the panels, plus a band across the middle.
	var hx := BODY_SIZE.x * 0.5
	var hz := BODY_SIZE.z * 0.5
	for x in [-hx, hx]:
		for z in [-hz, hz]:
			ModelKit.box(root, "CornerPost", Vector3(0.016, BODY_SIZE.y, 0.016), Vector3(x, body_center.y, BODY_Z + z), wood_dark)
	ModelKit.box(root, "BodyBand", Vector3(BODY_SIZE.x + 0.006, 0.01, BODY_SIZE.z + 0.006), Vector3(0, BODY_BOTTOM + 0.035, BODY_Z), wood_dark)

	# Two-tier cap.
	ModelKit.box(root, "CapLower", Vector3(0.146, 0.008, 0.136), Vector3(0, BODY_TOP + 0.004, BODY_Z), wood_dark)
	ModelKit.box(root, "CapUpper", Vector3(0.132, 0.006, 0.122), Vector3(0, BODY_TOP + 0.011, BODY_Z), ModelKit.mat(ModelKit.WOOD_DARK.lightened(0.08)))

	# Back drawer: dark frame, lighter front, metal pull bar.
	var back_z := BODY_Z - hz
	ModelKit.box(root, "DrawerFrame", Vector3(0.096, 0.052, 0.004), Vector3(0, BODY_BOTTOM + 0.07, back_z - 0.001), wood_darker)
	ModelKit.box(root, "Drawer", Vector3(0.086, 0.042, 0.006), Vector3(0, BODY_BOTTOM + 0.07, back_z - 0.004), wood_dark)
	ModelKit.box(root, "DrawerPull", Vector3(0.036, 0.006, 0.006), Vector3(0, BODY_BOTTOM + 0.07, back_z - 0.011), ModelKit.metal(ModelKit.STEEL))
	for x in [-0.018, 0.018]:
		ModelKit.box(root, "DrawerPullPost", Vector3(0.005, 0.005, 0.008), Vector3(x, BODY_BOTTOM + 0.07, back_z - 0.008), ModelKit.metal(ModelKit.STEEL))

	# Brass plate with the grind setting dial, below the spout.
	var front_z := BODY_Z + hz
	var plate_y := BODY_BOTTOM + 0.065
	var brass := ModelKit.metal(BRASS)
	ModelKit.box(root, "FrontPlate", Vector3(0.072, 0.042, 0.004), Vector3(0, plate_y, front_z + 0.002), brass)
	for x in [-0.03, 0.03]:
		for y in [-0.015, 0.015]:
			ModelKit.sphere(root, "PlateScrew", 0.0025, Vector3(x, plate_y + y, front_z + 0.0045), ModelKit.metal(ModelKit.METAL_DARK), 1.0, 6)
	ModelKit.cyl(root, "Dial", 0.015, 0.015, 0.008, Vector3(0, plate_y, front_z + 0.007), ModelKit.metal(ModelKit.METAL_DARK), 12, Vector3(90, 0, 0))
	ModelKit.box(root, "DialMark", Vector3(0.003, 0.011, 0.003), Vector3(0, plate_y + 0.007, front_z + 0.012), ModelKit.mat(ModelKit.CREAM))
	# Tick marks around the dial.
	for i in range(5):
		var a := deg_to_rad(-60.0 + 30.0 * i)
		ModelKit.box(root, "DialTick", Vector3(0.002, 0.005, 0.002), Vector3(sin(a) * 0.022, plate_y + cos(a) * 0.022, front_z + 0.0045), ModelKit.mat(ModelKit.WOOD_DARKER), Vector3(0, 0, -rad_to_deg(a)))

static func _build_spout(root: Node3D) -> void:
	root = ModelKit.group(root, "Spout")
	# The cylinder is tilted so its top leans back into the body and its open
	# bottom end points forward and down, ending right above the pad centre.
	var tilt := deg_to_rad(SPOUT_TILT)
	var axis := Vector3(0, cos(tilt), sin(tilt))
	var mouth := Vector3(0, SPOUT_TIP.y + 0.008, PAD_CENTER.z - 0.004)
	var center := mouth + axis * SPOUT_LENGTH * 0.5
	var rot := Vector3(SPOUT_TILT, 0, 0)
	ModelKit.cyl(root, "Spout", 0.019, 0.015, SPOUT_LENGTH, center, ModelKit.metal(ModelKit.STEEL), 12, rot)
	ModelKit.torus(root, "SpoutLip", 0.016, 0.023, mouth, ModelKit.metal(ModelKit.METAL_DARK), rot)
	# Dark disc just inside the mouth so it reads as an opening.
	ModelKit.cyl(root, "SpoutMouth", 0.016, 0.016, 0.002, mouth + axis * 0.004, ModelKit.mat(ModelKit.BLACK), 12, rot)
	# Flange where the spout meets the body.
	ModelKit.cyl(root, "SpoutFlange", 0.026, 0.026, 0.004, Vector3(0, center.y + 0.012, BODY_Z + BODY_SIZE.z * 0.5 + 0.002), ModelKit.metal(ModelKit.METAL_DARK), 12, Vector3(90, 0, 0))

static func _build_top(root: Node3D) -> void:
	root = ModelKit.group(root, "Hopper")
	var steel := ModelKit.metal(ModelKit.STEEL)
	var dark := ModelKit.metal(ModelKit.METAL_DARK)
	var top := BODY_TOP + 0.014
	ModelKit.cyl(root, "BurrHousing", 0.05, 0.046, 0.04, Vector3(0, top + 0.02, BODY_Z), steel, 20)
	ModelKit.torus(root, "HousingRing", 0.044, 0.054, Vector3(0, top + 0.004, BODY_Z), dark)
	ModelKit.torus(root, "HousingRingTop", 0.042, 0.05, Vector3(0, top + 0.038, BODY_Z), dark)
	# Hex adjustment nut on the front of the housing.
	ModelKit.cyl(root, "AdjustNut", 0.011, 0.011, 0.01, Vector3(0, top + 0.02, BODY_Z + 0.05), dark, 6, Vector3(90, 0, 0))

	# Hopper with a coloured label band and a rolled rim.
	var hopper_bottom := top + 0.04
	ModelKit.cyl(root, "Hopper", 0.044, 0.064, 0.075, Vector3(0, hopper_bottom + 0.0375, BODY_Z), ModelKit.metal(ModelKit.METAL), 20)
	ModelKit.cyl(root, "HopperBand", 0.0505, 0.0555, 0.02, Vector3(0, hopper_bottom + 0.028, BODY_Z), ModelKit.mat(ModelKit.RED, 0.0, 0.6), 20)
	ModelKit.torus(root, "HopperRim", 0.06, 0.07, Vector3(0, hopper_bottom + 0.075, BODY_Z), steel)

	# Beans: a low heap with individual beans scattered over it.
	var beans_y := hopper_bottom + 0.064
	ModelKit.sphere(root, "BeanHeap", 0.058, Vector3(0, beans_y, BODY_Z), ModelKit.mat(ModelKit.BEANS), 0.4, 16)
	var bean_dark := ModelKit.mat(ModelKit.BEANS.darkened(0.25))
	var bean_light := ModelKit.mat(ModelKit.BEANS.lightened(0.12))
	for i in range(14):
		var a := TAU * float(i) / 14.0 + (0.3 if i % 2 == 0 else 0.0)
		var r := 0.018 + 0.03 * float((i * 7) % 5) / 4.0
		var h := beans_y + 0.022 * (1.0 - r / 0.06)
		var b := ModelKit.sphere(root, "Bean", 0.009, Vector3(cos(a) * r, h, BODY_Z + sin(a) * r), bean_dark if i % 3 else bean_light, 0.6, 8)
		b.rotation_degrees = Vector3(0, rad_to_deg(a) * 2.0, 20)

static func _build_crank_mount(root: Node3D) -> void:
	root = ModelKit.group(root, "CrankMount")
	# Boss on the right side of the body and a shaft out to the crank pivot.
	var side_x := BODY_SIZE.x * 0.5 + 0.008
	ModelKit.cyl(root, "CrankBoss", 0.02, 0.02, 0.01, Vector3(side_x + 0.005, CRANK_PIVOT.y, CRANK_PIVOT.z), ModelKit.metal(ModelKit.STEEL), 14, Vector3(0, 0, 90))
	var shaft_len := CRANK_PIVOT.x - side_x
	ModelKit.cyl(root, "CrankShaft", 0.007, 0.007, shaft_len, Vector3(side_x + shaft_len * 0.5, CRANK_PIVOT.y, CRANK_PIVOT.z), ModelKit.metal(ModelKit.METAL_DARK), 10, Vector3(0, 0, 90))
