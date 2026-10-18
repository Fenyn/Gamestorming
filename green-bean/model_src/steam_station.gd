extends RefCounted

## Compact standalone milk steamer, about 10 x 37 x 24 cm with the depth squeezed
## to 0.2 m. Origin: centre of the station's old 0.2 x 0.25 x 0.2 m box (bottom at
## y = -0.125). Front faces +Z.
##
## Read by steam_station.gd: PitcherPad, PitcherRest, SteamVent (markers), Wand
## (pivots where it leaves the head; its -Y runs down the wand) with Wand/TipEnd
## at the steam holes, Head/Lever (swung forward about its X to open the steam),
## CameraView.

const BOTTOM := -0.125
const WIDTH := 0.11
const HEIGHT := 0.24
const BACK_Z := -0.1
const TOWER_FRONT_Z := -0.005
const HEAD_FRONT_Z := 0.085
const HEAD_BOTTOM := 0.07
const TRAY_TOP := BOTTOM + 0.02
const PAD := Vector3(0, TRAY_TOP, 0.042)
const REST := Vector3(0.12, BOTTOM + 0.004, 0.03)
## The 12 oz pitcher is 0.095 tall; steam comes out of its mouth.
const VENT := Vector3(0, TRAY_TOP + 0.1, 0.042)
const WAND_JOINT := Vector3(0.0, HEAD_BOTTOM - 0.004, 0.035)
## Forward lean puts the tip off-centre in the pitcher so the milk spins.
const WAND_LEAN := 8.0
## The tip clears a fresh 12 oz pitcher's milk by about 8 mm while the pitcher
## rests on the tray, so steaming means lifting the pitcher onto the wand.
const WAND_LENGTH := 0.097

const SHELL := Color(0.93, 0.92, 0.89)
const SHELL_SHADE := Color(0.84, 0.83, 0.8)
const BASE_DARK := Color(0.2, 0.2, 0.22)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "SteamStation"
	_build_tower(root)
	_build_head(root)
	_build_tray(root)
	_build_wand(root)
	_build_rest(root)
	_add_marker(root, "PitcherPad", PAD)
	_add_marker(root, "PitcherRest", REST)
	_add_marker(root, "SteamVent", VENT)
	var cam := Marker3D.new()
	cam.name = "CameraView"
	# Low and close, looking into the pitcher's mouth past the thermometer.
	cam.position = Vector3(0.03, 0.13, 0.26)
	var e := Basis.looking_at(Vector3(0.008, -0.05, 0.04) - cam.position).get_euler()
	cam.rotation = e
	root.add_child(cam)
	return root

static func _add_marker(root: Node3D, marker_name: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = marker_name
	m.position = pos
	m.gizmo_extents = 0.03
	root.add_child(m)

## Rounded-edge slab: a box with its four vertical edges replaced by cylinders.
static func _rounded_box(parent: Node3D, part_name: String, size: Vector3, center: Vector3, radius: float, material: Material) -> void:
	ModelKit.box(parent, part_name, Vector3(size.x - radius * 2.0, size.y, size.z), center, material)
	ModelKit.box(parent, part_name + "Sides", Vector3(size.x, size.y, size.z - radius * 2.0), center, material)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := center + Vector3((size.x * 0.5 - radius) * float(sx), 0, (size.z * 0.5 - radius) * float(sz))
			ModelKit.cyl(parent, part_name + "Edge", radius, radius, size.y, p, material, 10)

static func _build_tower(root: Node3D) -> void:
	root = ModelKit.group(root, "Tower")
	var shell := ModelKit.mat(SHELL, 0.0, 0.45)
	var shade := ModelKit.mat(SHELL_SHADE, 0.0, 0.5)
	var base := ModelKit.mat(BASE_DARK, 0.0, 0.6)
	var depth := TOWER_FRONT_Z - BACK_Z
	var mid_z := (TOWER_FRONT_Z + BACK_Z) * 0.5
	_rounded_box(root, "Plinth", Vector3(WIDTH, 0.012, depth + 0.004), Vector3(0, BOTTOM + 0.006, mid_z), 0.014, base)
	_rounded_box(root, "Shell", Vector3(WIDTH - 0.004, HEIGHT - 0.012, depth), Vector3(0, BOTTOM + 0.012 + (HEIGHT - 0.012) * 0.5, mid_z), 0.012, shell)
	ModelKit.box(root, "Groove", Vector3(WIDTH - 0.002, 0.003, depth - 0.02), Vector3(0, BOTTOM + 0.05, mid_z), shade)
	ModelKit.box(root, "TankWindow", Vector3(0.002, 0.07, 0.03), Vector3(WIDTH * 0.5 - 0.001, BOTTOM + 0.1, mid_z - 0.015), ModelKit.mat(Color(0.55, 0.7, 0.78), 0.0, 0.15))
	ModelKit.box(root, "TankLevel", Vector3(0.0025, 0.045, 0.03), Vector3(WIDTH * 0.5 - 0.0008, BOTTOM + 0.0875, mid_z - 0.015), ModelKit.mat(Color(0.75, 0.88, 0.95), 0.0, 0.1))
	for sx in [-1.0, 1.0]:
		for z in [BACK_Z + 0.015, TOWER_FRONT_Z + 0.07]:
			ModelKit.cyl(root, "Foot", 0.006, 0.007, 0.004, Vector3((WIDTH * 0.5 - 0.015) * float(sx), BOTTOM + 0.002, z), base, 8)
	var black := ModelKit.mat(ModelKit.BLACK)
	ModelKit.cyl(root, "CableGland", 0.007, 0.007, 0.01, Vector3(0.025, BOTTOM + 0.03, BACK_Z - 0.004), base, 10, Vector3(90, 0, 0))
	ModelKit.cyl(root, "CableDrop", 0.0035, 0.0035, 0.026, Vector3(0.025, BOTTOM + 0.017, BACK_Z - 0.01), black, 8)
	ModelKit.cyl(root, "CableRun", 0.0035, 0.0035, 0.06, Vector3(0.03, BOTTOM + 0.0035, BACK_Z - 0.04), black, 8, Vector3(90, 10, 0))

static func _build_head(root: Node3D) -> void:
	root = ModelKit.group(root, "Head")
	var shell := ModelKit.mat(SHELL, 0.0, 0.45)
	var shade := ModelKit.mat(SHELL_SHADE, 0.0, 0.5)
	var top := BOTTOM + HEIGHT
	var head_h := top - HEAD_BOTTOM
	var head_depth := HEAD_FRONT_Z - TOWER_FRONT_Z + 0.01
	var head_mid_z := TOWER_FRONT_Z - 0.01 + head_depth * 0.5
	_rounded_box(root, "Overhang", Vector3(WIDTH - 0.004, head_h, head_depth), Vector3(0, HEAD_BOTTOM + head_h * 0.5, head_mid_z), 0.012, shell)
	ModelKit.box(root, "Underside", Vector3(WIDTH - 0.016, 0.003, head_depth - 0.016), Vector3(0, HEAD_BOTTOM - 0.0015, head_mid_z), shade)
	ModelKit.cyl(root, "TempSensor", 0.006, 0.006, 0.004, Vector3(0, HEAD_BOTTOM - 0.003, 0.066), ModelKit.mat(Color(0.1, 0.1, 0.12), 0.0, 0.2), 12)
	ModelKit.sphere(root, "TempSensorLens", 0.004, Vector3(0, HEAD_BOTTOM - 0.005, 0.066), ModelKit.mat(Color(0.45, 0.12, 0.1), 0.0, 0.1), 0.5, 8)

	var panel := ModelKit.mat(Color(0.08, 0.08, 0.1), 0.0, 0.15)
	ModelKit.box(root, "Panel", Vector3(WIDTH - 0.024, 0.003, 0.05), Vector3(0, top + 0.0015, HEAD_FRONT_Z - 0.032), panel)
	ModelKit.box(root, "Readout", Vector3(0.032, 0.0015, 0.012), Vector3(0, top + 0.0035, HEAD_FRONT_Z - 0.04), ModelKit.mat(Color(0.95, 0.65, 0.3), 0.0, 0.3))
	for x in [-0.02, 0.02]:
		ModelKit.cyl(root, "Button", 0.005, 0.005, 0.002, Vector3(x, top + 0.0035, HEAD_FRONT_Z - 0.019), ModelKit.mat(Color(0.75, 0.75, 0.78), 0.3, 0.4), 10)

	var chrome := ModelKit.mat(ModelKit.STEEL, 0.6, 0.25)
	var lever := Node3D.new()
	lever.name = "Lever"
	lever.position = Vector3(WIDTH * 0.5 + 0.002, HEAD_BOTTOM + head_h * 0.5, 0.03)
	root.add_child(lever)
	ModelKit.cyl(lever, "LeverHub", 0.009, 0.009, 0.008, Vector3(0.002, 0, 0), chrome, 12, Vector3(0, 0, 90))
	ModelKit.box(lever, "Arm", Vector3(0.006, 0.006, 0.04), Vector3(0.008, -0.008, 0.016), chrome, Vector3(-25, 0, 0))
	ModelKit.sphere(lever, "LeverKnob", 0.007, Vector3(0.008, -0.017, 0.034), ModelKit.mat(ModelKit.BLACK, 0.0, 0.5), 1.0, 8)

	ModelKit.box(root, "Badge", Vector3(0.03, 0.006, 0.002), Vector3(0, HEAD_BOTTOM + head_h * 0.45, HEAD_FRONT_Z + 0.001), ModelKit.metal(Color(0.85, 0.68, 0.36)))

static func _build_tray(root: Node3D) -> void:
	root = ModelKit.group(root, "DripTray")
	var base := ModelKit.mat(BASE_DARK, 0.0, 0.6)
	var chrome := ModelKit.mat(ModelKit.STEEL, 0.6, 0.25)
	var depth := HEAD_FRONT_Z + 0.005 - TOWER_FRONT_Z
	var mid_z := TOWER_FRONT_Z + depth * 0.5
	var tray_h := TRAY_TOP - BOTTOM - 0.002
	_rounded_box(root, "Tray", Vector3(WIDTH, tray_h, depth), Vector3(0, BOTTOM + tray_h * 0.5, mid_z), 0.012, base)
	ModelKit.box(root, "Grate", Vector3(WIDTH - 0.016, 0.002, depth - 0.016), Vector3(0, TRAY_TOP - 0.001, mid_z), chrome)
	for i in range(6):
		ModelKit.box(root, "GrateSlot", Vector3(WIDTH - 0.03, 0.0015, 0.004), Vector3(0, TRAY_TOP + 0.0002, TOWER_FRONT_Z + 0.016 + i * 0.0125), base)

static func _build_wand(root: Node3D) -> void:
	var wand := Node3D.new()
	wand.name = "Wand"
	wand.position = WAND_JOINT
	wand.rotation_degrees = Vector3(-WAND_LEAN, 0, 0)
	root.add_child(wand)
	var chrome := ModelKit.mat(ModelKit.STEEL, 0.6, 0.25)
	var dark := ModelKit.metal(ModelKit.METAL_DARK)
	ModelKit.cyl(wand, "Collar", 0.01, 0.009, 0.008, Vector3(0, -0.002, 0), dark, 12)
	ModelKit.sphere(wand, "Joint", 0.008, Vector3(0, -0.008, 0), chrome, 1.0, 10)
	ModelKit.cyl(wand, "Sleeve", 0.0065, 0.0065, 0.035, Vector3(0, -0.0255, 0), ModelKit.mat(Color(0.25, 0.25, 0.27), 0.0, 0.6), 10)
	ModelKit.cyl(wand, "Pipe", 0.0045, 0.0045, WAND_LENGTH - 0.03, Vector3(0, -0.043 - (WAND_LENGTH - 0.03) * 0.5, 0), chrome, 10)
	ModelKit.cyl(wand, "Tip", 0.0035, 0.0055, 0.01, Vector3(0, -0.043 - (WAND_LENGTH - 0.03) - 0.005, 0), dark, 10)
	var tip_end := Marker3D.new()
	tip_end.name = "TipEnd"
	tip_end.position = Vector3(0, -0.043 - (WAND_LENGTH - 0.03) - 0.01, 0)
	wand.add_child(tip_end)

static func _build_rest(root: Node3D) -> void:
	root = ModelKit.group(root, "PitcherMat")
	ModelKit.cyl(root, "Mat", 0.05, 0.05, 0.004, Vector3(REST.x, BOTTOM + 0.002, REST.z), ModelKit.mat(Color(0.22, 0.22, 0.24), 0.0, 0.95), 16)
	for i in range(3):
		ModelKit.torus(root, "MatRidge", 0.012 + i * 0.012, 0.016 + i * 0.012, Vector3(REST.x, BOTTOM + 0.004, REST.z), ModelKit.mat(Color(0.3, 0.3, 0.32), 0.0, 0.9))
