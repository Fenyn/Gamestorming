extends RefCounted

## Steam station: a small cream-and-chrome steam boiler with a steam wand.
##
## Fits the station's 0.2 x 0.25 x 0.2 m collision box. Origin is the centre of
## that box, so the bottom sits at y = -0.125. Front faces +Z (the barista).
##
## Layout: boiler body at the back with a pressure gauge, a steam knob on top and
## a cup rail; a drip tray in front where the pitcher stands; a steam wand that
## comes out of the body, runs forward and dips straight down into the pitcher.
## A rubber mat on the right holds the spare pitcher.
##
## Nodes the station script uses (move them in the editor and the station follows):
##   PitcherPad    Marker3D on the drip tray where the pitcher is set down.
##   PitcherRest   Marker3D on the mat where the spare pitcher waits.
##   SteamVent     Marker3D where the steam puffs rise from (pitcher mouth).
##   Wand          Node3D holding the steam wand, pivoting where it leaves the body.
##   CameraView    Marker3D for the steaming mini-game camera (looks along -Z).

const BOTTOM := -0.125
const BODY_SIZE := Vector3(0.17, 0.22, 0.09)
const BODY_Z := -0.055
const TRAY_TOP := -0.103
const PAD := Vector3(0, TRAY_TOP, 0.04)
const REST := Vector3(0.158, BOTTOM + 0.004, 0.035)
## The pitcher is 0.12 tall; steam comes out of its mouth.
const VENT := Vector3(0, TRAY_TOP + 0.125, 0.04)
const WAND_JOINT := Vector3(0.03, 0.06, BODY_Z + BODY_SIZE.z * 0.5)

const ENAMEL := Color(0.92, 0.86, 0.74)
const ENAMEL_DARK := Color(0.78, 0.7, 0.58)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "SteamStation"
	_build_body(root)
	_build_tray(root)
	_build_wand(root)
	_build_rest(root)
	_add_marker(root, "PitcherPad", PAD)
	_add_marker(root, "PitcherRest", REST)
	_add_marker(root, "SteamVent", VENT)
	# Frames the pitcher and the mini-game gauges above it.
	var cam := Marker3D.new()
	cam.name = "CameraView"
	cam.position = Vector3(0, 0.33, 0.62)
	cam.rotation_degrees = Vector3(-21, 0, 0)
	root.add_child(cam)
	_build_back_details(root)
	return root

static func _build_back_details(root: Node3D) -> void:
	root = ModelKit.group(root, "BackDetails")
	var dark := ModelKit.metal(ModelKit.METAL_DARK)
	var back_z := BODY_Z - BODY_SIZE.z * 0.5
	# Vent slots and a cable leaving the bottom.
	for i in range(4):
		ModelKit.box(root, "VentSlot", Vector3(0.09, 0.006, 0.003), Vector3(0, 0.05 - i * 0.016, back_z - 0.001), dark)
	ModelKit.cyl(root, "CableGland", 0.008, 0.008, 0.01, Vector3(0.05, BOTTOM + 0.03, back_z - 0.004), dark, 10, Vector3(90, 0, 0))
	# Cable drops to the counter, then runs back along it.
	var black := ModelKit.mat(ModelKit.BLACK)
	ModelKit.cyl(root, "CableDrop", 0.004, 0.004, 0.026, Vector3(0.05, BOTTOM + 0.017, back_z - 0.01), black, 8)
	ModelKit.cyl(root, "CableRun", 0.004, 0.004, 0.16, Vector3(0.07, BOTTOM + 0.004, back_z - 0.085), black, 8, Vector3(90, 15, 0))

static func _add_marker(root: Node3D, marker_name: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = marker_name
	m.position = pos
	m.gizmo_extents = 0.03
	root.add_child(m)

static func _build_body(root: Node3D) -> void:
	root = ModelKit.group(root, "Body")
	var enamel := ModelKit.mat(ENAMEL, 0.0, 0.5)
	var enamel_dark := ModelKit.mat(ENAMEL_DARK, 0.0, 0.6)
	var chrome := ModelKit.mat(ModelKit.STEEL, 0.6, 0.25)
	var dark := ModelKit.metal(ModelKit.METAL_DARK)
	var hx := BODY_SIZE.x * 0.5
	var hz := BODY_SIZE.z * 0.5
	var top := BOTTOM + BODY_SIZE.y
	var center := Vector3(0, BOTTOM + BODY_SIZE.y * 0.5, BODY_Z)

	# Plinth, enamel shell, chrome side panels and a top plate.
	ModelKit.box(root, "Plinth", Vector3(BODY_SIZE.x + 0.01, 0.012, BODY_SIZE.z + 0.01), Vector3(0, BOTTOM + 0.006, BODY_Z), dark)
	ModelKit.box(root, "Shell", BODY_SIZE - Vector3(0, 0.012, 0), center + Vector3(0, 0.006, 0), enamel)
	for x in [-hx, hx]:
		ModelKit.box(root, "SidePanel", Vector3(0.006, BODY_SIZE.y - 0.03, BODY_SIZE.z - 0.016), Vector3(x, center.y + 0.004, BODY_Z), chrome)
	ModelKit.box(root, "TopPlate", Vector3(BODY_SIZE.x + 0.008, 0.008, BODY_SIZE.z + 0.008), Vector3(0, top + 0.004, BODY_Z), chrome)
	# Darker band across the front, like a badge strip.
	ModelKit.box(root, "Band", Vector3(BODY_SIZE.x - 0.01, 0.022, 0.004), Vector3(0, BOTTOM + 0.05, BODY_Z + hz + 0.002), enamel_dark)
	ModelKit.box(root, "Badge", Vector3(0.05, 0.012, 0.003), Vector3(0, BOTTOM + 0.05, BODY_Z + hz + 0.005), ModelKit.metal(Color(0.85, 0.68, 0.36)))

	# Pressure gauge on the front, upper left.
	var gauge_pos := Vector3(-0.042, top - 0.05, BODY_Z + hz)
	ModelKit.cyl(root, "GaugeBezel", 0.026, 0.026, 0.012, gauge_pos + Vector3(0, 0, 0.006), chrome, 20, Vector3(90, 0, 0))
	ModelKit.cyl(root, "GaugeFace", 0.021, 0.021, 0.004, gauge_pos + Vector3(0, 0, 0.012), ModelKit.mat(ModelKit.CREAM, 0.0, 0.4), 20, Vector3(90, 0, 0))
	ModelKit.box(root, "GaugeRedZone", Vector3(0.012, 0.004, 0.002), gauge_pos + Vector3(0.012, 0.012, 0.015), ModelKit.mat(ModelKit.RED), Vector3(0, 0, -40))
	ModelKit.box(root, "GaugeNeedle", Vector3(0.002, 0.017, 0.002), gauge_pos + Vector3(0.004, 0.006, 0.016), ModelKit.mat(ModelKit.BLACK), Vector3(0, 0, -35))
	ModelKit.sphere(root, "GaugePin", 0.003, gauge_pos + Vector3(0, 0, 0.016), ModelKit.mat(ModelKit.BLACK), 1.0, 6)

	# Power light under the gauge.
	ModelKit.sphere(root, "PowerLight", 0.006, Vector3(-0.042, top - 0.09, BODY_Z + hz + 0.002), ModelKit.mat(Color(1.0, 0.45, 0.2), 0.0, 0.3), 1.0, 8)

	# Steam knob on top, right side: chrome stem and a black star knob.
	var knob_base := Vector3(0.045, top + 0.008, BODY_Z)
	ModelKit.cyl(root, "KnobStem", 0.007, 0.007, 0.02, knob_base + Vector3(0, 0.01, 0), chrome, 10)
	ModelKit.cyl(root, "Knob", 0.018, 0.016, 0.014, knob_base + Vector3(0, 0.027, 0), ModelKit.mat(ModelKit.BLACK, 0.0, 0.5), 6)
	ModelKit.sphere(root, "KnobCap", 0.006, knob_base + Vector3(0, 0.035, 0), chrome, 1.0, 8)

	# Cup rail around the top plate, on short posts.
	for x in [-hx + 0.012, hx - 0.012]:
		for z in [-hz + 0.012, hz - 0.012]:
			ModelKit.cyl(root, "RailPost", 0.003, 0.003, 0.018, Vector3(x, top + 0.017, BODY_Z + z), chrome, 8)
	ModelKit.box(root, "RailFront", Vector3(BODY_SIZE.x - 0.024, 0.004, 0.004), Vector3(0, top + 0.026, BODY_Z + hz - 0.012), chrome)
	ModelKit.box(root, "RailBack", Vector3(BODY_SIZE.x - 0.024, 0.004, 0.004), Vector3(0, top + 0.026, BODY_Z - hz + 0.012), chrome)
	ModelKit.box(root, "RailLeft", Vector3(0.004, 0.004, BODY_SIZE.z - 0.024), Vector3(-hx + 0.012, top + 0.026, BODY_Z), chrome)

	# Feet.
	for x in [-hx + 0.015, hx - 0.015]:
		for z in [-hz + 0.012, hz - 0.012]:
			ModelKit.cyl(root, "Foot", 0.008, 0.009, 0.004, Vector3(x, BOTTOM + 0.002, BODY_Z + z), ModelKit.mat(ModelKit.BLACK), 8)

static func _build_tray(root: Node3D) -> void:
	root = ModelKit.group(root, "DripTray")
	var chrome := ModelKit.mat(ModelKit.STEEL, 0.6, 0.25)
	var dark := ModelKit.metal(ModelKit.METAL_DARK)
	var tray_center := Vector3(0, BOTTOM + 0.011, 0.04)
	ModelKit.box(root, "Tray", Vector3(0.15, 0.022, 0.11), tray_center, chrome)
	ModelKit.box(root, "TrayInset", Vector3(0.136, 0.002, 0.096), Vector3(0, TRAY_TOP - 0.0005, 0.04), dark)
	# Grate bars.
	for i in range(7):
		var x := -0.06 + 0.02 * i
		ModelKit.box(root, "GrateBar", Vector3(0.006, 0.003, 0.094), Vector3(x, TRAY_TOP + 0.0015, 0.04), chrome)
	ModelKit.box(root, "TrayLip", Vector3(0.152, 0.008, 0.006), Vector3(0, BOTTOM + 0.018, 0.096), chrome)

static func _build_wand(root: Node3D) -> void:
	# The whole wand hangs off one node at the joint, so it can be swung or
	# tilted as a unit in the editor.
	var wand := Node3D.new()
	wand.name = "Wand"
	wand.position = WAND_JOINT
	root.add_child(wand)
	var chrome := ModelKit.mat(ModelKit.STEEL, 0.6, 0.25)
	var dark := ModelKit.metal(ModelKit.METAL_DARK)
	# Joint, then a short arm forward and left so the tip ends over the pad.
	ModelKit.sphere(wand, "Joint", 0.012, Vector3.ZERO, chrome, 1.0, 10)
	ModelKit.cyl(wand, "JointCollar", 0.014, 0.014, 0.008, Vector3(0, 0, -0.002), dark, 12, Vector3(90, 0, 0))
	var elbow := Vector3(PAD.x - WAND_JOINT.x, 0.0, PAD.z - WAND_JOINT.z)
	var arm_len := elbow.length()
	var arm_yaw := rad_to_deg(atan2(elbow.x, elbow.z))
	ModelKit.cyl(wand, "Arm", 0.006, 0.006, arm_len, elbow * 0.5, chrome, 10, Vector3(90, arm_yaw, 0))
	ModelKit.sphere(wand, "Elbow", 0.008, elbow, chrome, 1.0, 8)
	# Down pipe into the pitcher, with a rubber grip and a nozzle.
	var drop := WAND_JOINT.y - (VENT.y - 0.045)
	ModelKit.cyl(wand, "DownPipe", 0.006, 0.006, drop, elbow + Vector3(0, -drop * 0.5, 0), chrome, 10)
	ModelKit.cyl(wand, "Grip", 0.009, 0.009, 0.03, elbow + Vector3(0, -0.025, 0), ModelKit.mat(ModelKit.BLACK, 0.0, 0.7), 10)
	ModelKit.cyl(wand, "Nozzle", 0.005, 0.008, 0.012, elbow + Vector3(0, -drop - 0.006, 0), dark, 10)

static func _build_rest(root: Node3D) -> void:
	root = ModelKit.group(root, "PitcherMat")
	ModelKit.cyl(root, "Mat", 0.05, 0.05, 0.004, Vector3(REST.x, BOTTOM + 0.002, REST.z), ModelKit.mat(Color(0.22, 0.22, 0.24), 0.0, 0.95), 16)
	for i in range(3):
		ModelKit.torus(root, "MatRidge", 0.012 + i * 0.012, 0.016 + i * 0.012, Vector3(REST.x, BOTTOM + 0.004, REST.z), ModelKit.mat(Color(0.3, 0.3, 0.32), 0.0, 0.9))
