extends RefCounted

## Hot water dispenser: a slim commercial hot water tower.
##
## Proportions follow countertop units like the Bunn H3X / H5X Element
## (about 19 cm wide, 43 cm deep, 56-72 cm tall): a tall stainless tower, an
## upper head that overhangs the dispense area, a faucet with a red lever under
## the head front, an LED temperature readout on a black control panel, and a
## drip tray with about 20 cm of cup clearance. No branding.
##
## Origin is the middle of the base, so the unit stands on the counter at y = 0.
## Front faces +Z (the barista).
##
## Nodes the station script uses (move them in the editor and the station follows):
##   Spout        Marker3D at the faucet nozzle. Water streams from here.
##   FillPoint    Marker3D on the grate under the spout. The cup or kettle is
##                stood here while it fills, then handed back.
##   KettleRest   Marker3D on the counter beside the unit where the kettle waits.
##   CameraView   Marker3D for the fill camera, looking at the cup under the spout.
##   Lever        Node3D holding the faucet lever, pivoting at its base.
##
## Colliders live in scenes/stations/hot_water.tscn (tower, head and tray boxes).

const MK := preload("res://model_src/model_kit.gd")

const WIDTH := 0.19
const DEPTH := 0.43
const HEIGHT := 0.56
const BACK_Z := -DEPTH * 0.5
const FRONT_Z := DEPTH * 0.5
## Front face of the tower behind the dispense area.
const TOWER_FRONT_Z := 0.0
## Underside of the head. Tray top + about 20 cm of clearance.
const HEAD_BOTTOM := 0.245
const TRAY_TOP := 0.03
const SPOUT := Vector3(0, HEAD_BOTTOM - 0.04, 0.15)
const FILL := Vector3(0, TRAY_TOP, 0.15)
const KETTLE_REST := Vector3(0.175, 0.0, 0.12)
## Fill camera: front-right of the cup, a bit above it. From the right it stays
## clear of the steamer, which stands front-left of the unit in the espresso stand.
const CAMERA_OFFSET := Vector3(0.15, 0.14, 0.22)
const CAMERA_LOOK_AT := Vector3(0, 0.1, 0)

const SHELL := Color(0.78, 0.79, 0.81)
const SHELL_DARK := Color(0.6, 0.61, 0.63)
const PANEL := Color(0.1, 0.1, 0.11)
const LEVER_RED := Color(0.78, 0.13, 0.12)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "HotWaterDispenser"
	_build_body(root)
	_build_panel(root)
	_build_faucet(root)
	_build_tray(root)
	_build_back(root)

	MK.marker(root, "Spout", SPOUT)
	MK.marker(root, "FillPoint", FILL)
	MK.marker(root, "KettleRest", KETTLE_REST)
	var cam_pos := FILL + CAMERA_OFFSET
	var cam_basis := Basis.looking_at(FILL + CAMERA_LOOK_AT - cam_pos)
	var cam_rot := cam_basis.get_euler()
	MK.marker(root, "CameraView", cam_pos, Vector3(rad_to_deg(cam_rot.x), rad_to_deg(cam_rot.y), rad_to_deg(cam_rot.z)))
	return root

static func _build_body(root: Node3D) -> void:
	var body := MK.group(root, "Body")
	var steel: Material = MK.mat(SHELL, 0.6, 0.35)
	var seam: Material = MK.mat(SHELL_DARK, 0.5, 0.45)
	# Tower behind the dispense area, full height.
	var tower_depth := TOWER_FRONT_Z - BACK_Z
	MK.rounded_box(body, "Tower", Vector3(WIDTH, HEIGHT - 0.012, tower_depth), Vector3(0, (HEIGHT - 0.012) * 0.5 + 0.006, BACK_Z + tower_depth * 0.5), 0.012, steel)
	# Head overhanging the cup.
	var head_depth := FRONT_Z - TOWER_FRONT_Z
	var head_h := HEIGHT - 0.006 - HEAD_BOTTOM
	MK.rounded_box(body, "Head", Vector3(WIDTH, head_h, head_depth), Vector3(0, HEAD_BOTTOM + head_h * 0.5, TOWER_FRONT_Z + head_depth * 0.5 - 0.001), 0.012, steel)
	# Lid: a slightly inset cap with a seam line under it.
	MK.box(body, "Lid", Vector3(WIDTH - 0.008, 0.008, DEPTH - 0.008), Vector3(0, HEIGHT - 0.004, 0), steel)
	MK.box(body, "LidSeam", Vector3(WIDTH + 0.001, 0.003, DEPTH - 0.02), Vector3(0, HEIGHT - 0.012, 0), seam)
	for i in range(5):
		MK.box(body, "Vent", Vector3(0.08, 0.002, 0.006), Vector3(0, HEIGHT + 0.0005, -0.16 + i * 0.014), MK.mat(PANEL))
	# Splash panel on the tower face behind the cup.
	MK.box(body, "SplashPanel", Vector3(WIDTH - 0.03, HEAD_BOTTOM - TRAY_TOP - 0.01, 0.003), Vector3(0, (HEAD_BOTTOM + TRAY_TOP) * 0.5, TOWER_FRONT_Z + 0.0015), MK.mat(SHELL_DARK, 0.7, 0.3))
	# Darker underside of the head around the faucet.
	MK.box(body, "HeadUnderside", Vector3(WIDTH - 0.02, 0.003, head_depth - 0.02), Vector3(0, HEAD_BOTTOM - 0.0015, TOWER_FRONT_Z + head_depth * 0.5), MK.mat(Color(0.35, 0.35, 0.37), 0.4, 0.5))
	# Side panel seams.
	for sx in [-1.0, 1.0]:
		MK.box(body, "SideSeam", Vector3(0.002, HEIGHT - 0.06, 0.003), Vector3(float(sx) * (WIDTH * 0.5 + 0.0005), HEIGHT * 0.5, -0.09), seam)

static func _build_panel(root: Node3D) -> void:
	var panel := MK.group(root, "ControlPanel")
	var z := FRONT_Z + 0.001
	MK.box(panel, "Panel", Vector3(WIDTH - 0.03, 0.12, 0.004), Vector3(0, 0.455, z), MK.mat(PANEL, 0.1, 0.4))
	# LED readout: dark window with glowing red-orange digits.
	MK.box(panel, "Display", Vector3(0.07, 0.03, 0.003), Vector3(0, 0.48, z + 0.003), MK.mat(Color(0.05, 0.03, 0.03), 0.0, 0.2))
	var led := StandardMaterial3D.new()
	led.albedo_color = Color(1.0, 0.35, 0.15)
	led.emission_enabled = true
	led.emission = Color(1.0, 0.3, 0.1)
	led.emission_energy_multiplier = 1.6
	for i in range(3):
		MK.box(panel, "Digit", Vector3(0.012, 0.018, 0.001), Vector3(-0.018 + i * 0.018, 0.48, z + 0.005), led)
	# Program and dispense buttons.
	for i in range(3):
		MK.cyl(panel, "Button", 0.006, 0.006, 0.004, Vector3(-0.035 + i * 0.035, 0.428, z + 0.003), MK.mat(Color(0.75, 0.75, 0.77), 0.3, 0.4), 12, Vector3(90, 0, 0))
	# Small blank badge under the panel.
	MK.box(panel, "Badge", Vector3(0.06, 0.012, 0.002), Vector3(0, 0.375, z), MK.mat(Color(0.9, 0.9, 0.92), 0.6, 0.3))

static func _build_faucet(root: Node3D) -> void:
	var faucet := MK.group(root, "Faucet")
	var chrome: Material = MK.mat(Color(0.85, 0.86, 0.88), 0.8, 0.2)
	var black: Material = MK.mat(PANEL, 0.1, 0.5)
	# Faucet body hangs from the head underside near the front.
	MK.box(faucet, "Mount", Vector3(0.03, 0.006, 0.05), Vector3(0, HEAD_BOTTOM - 0.003, SPOUT.z + 0.02), chrome)
	MK.cyl(faucet, "Valve", 0.012, 0.012, 0.025, Vector3(0, HEAD_BOTTOM - 0.018, SPOUT.z + 0.01), chrome, 14)
	MK.cyl(faucet, "Nozzle", 0.006, 0.005, 0.016, Vector3(0, SPOUT.y + 0.008, SPOUT.z), chrome, 12)
	MK.cyl(faucet, "NozzleTip", 0.005, 0.0045, 0.003, Vector3(0, SPOUT.y + 0.0015, SPOUT.z), black, 12)
	# Red lever: pivots on the front of the valve and leans out toward the barista.
	var lever := Node3D.new()
	lever.name = "Lever"
	lever.position = Vector3(0, HEAD_BOTTOM - 0.018, SPOUT.z + 0.024)
	lever.rotation_degrees = Vector3(-35, 0, 0)
	faucet.add_child(lever)
	MK.cyl(lever, "Stem", 0.004, 0.004, 0.02, Vector3(0, -0.01, 0), chrome, 10)
	MK.box(lever, "Handle", Vector3(0.016, 0.05, 0.01), Vector3(0, -0.044, 0), MK.mat(LEVER_RED, 0.1, 0.45))
	MK.sphere(lever, "HandleEnd", 0.008, Vector3(0, -0.07, 0), MK.mat(LEVER_RED, 0.1, 0.45), 1.0, 10)

static func _build_tray(root: Node3D) -> void:
	var tray := MK.group(root, "DripTray")
	var depth := FRONT_Z - TOWER_FRONT_Z
	MK.rounded_box(tray, "Tray", Vector3(WIDTH - 0.01, TRAY_TOP - 0.004, depth - 0.008), Vector3(0, (TRAY_TOP - 0.004) * 0.5, TOWER_FRONT_Z + depth * 0.5 - 0.004), 0.008, MK.mat(Color(0.16, 0.16, 0.17), 0.1, 0.6))
	MK.box(tray, "Grate", Vector3(WIDTH - 0.03, 0.004, depth - 0.03), Vector3(0, TRAY_TOP - 0.002, TOWER_FRONT_Z + depth * 0.5 - 0.004), MK.mat(Color(0.8, 0.81, 0.83), 0.7, 0.3))
	for i in range(8):
		MK.box(tray, "Slot", Vector3(WIDTH - 0.05, 0.001, 0.005), Vector3(0, TRAY_TOP + 0.0005, TOWER_FRONT_Z + 0.03 + i * 0.02), MK.mat(Color(0.12, 0.12, 0.13)))

static func _build_back(root: Node3D) -> void:
	var back := MK.group(root, "Back")
	var black: Material = MK.mat(PANEL, 0.0, 0.7)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MK.cyl(back, "Foot", 0.008, 0.008, 0.006, Vector3(float(sx) * (WIDTH * 0.5 - 0.02), 0.003, float(sz) * (DEPTH * 0.5 - 0.03)), black, 10)
	# Water inlet and power cord out of the back, short so they read as fittings.
	MK.cyl(back, "WaterInlet", 0.006, 0.006, 0.03, Vector3(0.04, 0.05, BACK_Z - 0.015), MK.mat(Color(0.7, 0.55, 0.3), 0.7, 0.35), 10, Vector3(90, 0, 0))
	MK.cyl(back, "Cord", 0.004, 0.004, 0.05, Vector3(-0.04, 0.04, BACK_Z - 0.025), black, 8, Vector3(90, 0, 0))
