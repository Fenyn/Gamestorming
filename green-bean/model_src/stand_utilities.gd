extends RefCounted

## Services on the outside of the stand: electric meter, panel and conduit on
## the back wall, a hose bib, and a gutter along the back eave with a downspout
## at each back corner onto a splash block.
## Origin: ground at the stand's centre, so x and z match the shop. Back wall
## outer face z -1.3; back fascia outer face z -1.465, bottom y 2.42.

const MK := preload("res://model_src/model_kit.gd")

const WALL_Z := -1.3
const GUTTER_Z := -1.52
const GUTTER_Y := 2.47

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "StandUtilities"
	var grey: Material = MK.mat(Color(0.62, 0.63, 0.64), 0.5, 0.45)
	var pipe: Material = MK.mat(Color(0.7, 0.71, 0.72), 0.4, 0.5)

	# Meter on its base, the panel beside it, conduit up to the roof and down
	# into the ground.
	var meter_at := Vector3(0.62, 1.35, WALL_Z)
	MK.box(root, "MeterBase", Vector3(0.2, 0.3, 0.08), meter_at + Vector3(0, 0, -0.04), grey)
	MK.cyl(root, "MeterRing", 0.075, 0.075, 0.03, meter_at + Vector3(0, 0.02, -0.095), grey, 20, Vector3(90, 0, 0))
	var dome := StandardMaterial3D.new()
	dome.albedo_color = Color(0.8, 0.88, 0.9, 0.5)
	dome.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dome.roughness = 0.05
	var cover := MK.sphere(root, "MeterDome", 0.065, meter_at + Vector3(0, 0.02, -0.11), dome, 1.0, 16)
	cover.scale = Vector3(1, 1, 0.7)
	MK.box(root, "MeterDial", Vector3(0.06, 0.02, 0.004), meter_at + Vector3(0, 0.035, -0.115), MK.mat(Color(0.15, 0.15, 0.15), 0.0, 0.6))
	var panel_at := Vector3(1.05, 1.3, WALL_Z)
	MK.box(root, "Panel", Vector3(0.32, 0.44, 0.09), panel_at + Vector3(0, 0, -0.045), grey)
	MK.box(root, "PanelDoorLine", Vector3(0.3, 0.002, 0.002), panel_at + Vector3(0, 0.17, -0.091), MK.mat(Color(0.35, 0.36, 0.37), 0.3, 0.6))
	MK.box(root, "WarningLabel", Vector3(0.08, 0.05, 0.002), panel_at + Vector3(0, 0.08, -0.091), MK.mat(Color(0.92, 0.75, 0.15), 0.0, 0.7))
	MK.cyl(root, "ConduitDown", 0.016, 0.016, panel_at.y - 0.22, Vector3(panel_at.x, (panel_at.y - 0.22) * 0.5, WALL_Z - 0.03), pipe, 10)
	MK.cyl(root, "ConduitUp", 0.016, 0.016, GUTTER_Y - 0.08 - (panel_at.y + 0.22), Vector3(panel_at.x, (GUTTER_Y - 0.08 + panel_at.y + 0.22) * 0.5, WALL_Z - 0.03), pipe, 10)
	MK.cyl(root, "ConduitLink", 0.012, 0.012, panel_at.x - meter_at.x - 0.1, Vector3((panel_at.x + meter_at.x) * 0.5, meter_at.y - 0.1, WALL_Z - 0.03), pipe, 10, Vector3(0, 0, 90))
	for y in [0.3, 0.8, 1.9]:
		MK.box(root, "Strap", Vector3(0.05, 0.015, 0.012), Vector3(panel_at.x, y, WALL_Z - 0.03), grey)

	# Hose bib low on the wall.
	var brass: Material = MK.mat(Color(0.72, 0.55, 0.28), 0.8, 0.35)
	MK.cyl(root, "HoseBib", 0.012, 0.012, 0.07, Vector3(-0.6, 0.45, WALL_Z - 0.035), brass, 10, Vector3(90, 0, 0))
	MK.cyl(root, "HoseBibSpout", 0.01, 0.01, 0.04, Vector3(-0.6, 0.43, WALL_Z - 0.065), brass, 10)
	MK.cyl(root, "HoseBibHandle", 0.025, 0.025, 0.008, Vector3(-0.6, 0.45, WALL_Z - 0.075), MK.mat(Color(0.7, 0.15, 0.12), 0.3, 0.5), 10, Vector3(90, 0, 0))

	# Gutter along the back eave and a downspout at each corner.
	var gutter: Material = MK.mat(Color(0.86, 0.86, 0.84), 0.3, 0.5)
	MK.box(root, "Gutter", Vector3(4.24, 0.09, 0.11), Vector3(0, GUTTER_Y, GUTTER_Z), gutter)
	for sx in [-1.0, 1.0]:
		var x := float(sx) * 1.95
		MK.box(root, "Downspout", Vector3(0.07, GUTTER_Y - 0.25, 0.06), Vector3(x, (GUTTER_Y + 0.25) * 0.5 - 0.04, GUTTER_Z), gutter)
		MK.box(root, "Elbow", Vector3(0.07, 0.06, 0.22), Vector3(x, 0.18, GUTTER_Z - 0.08), gutter, Vector3(-30, 0, 0))
		MK.box(root, "SplashBlock", Vector3(0.28, 0.04, 0.5), Vector3(x, 0.02, GUTTER_Z - 0.35), MK.mat(Color(0.66, 0.64, 0.6), 0.0, 0.95))
		MK.box(root, "Bracket", Vector3(0.09, 0.02, 0.05), Vector3(x, 1.2, GUTTER_Z + 0.035), gutter)
	return root
