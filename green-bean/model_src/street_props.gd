extends RefCounted

## Small outdoor props, one per kind. Each has its origin on the ground.
## - umbrella: 2.0 m patio umbrella, canopy 1.8 m across, through a table's hole.
## - bike_rack: two inverted-U steel hoops on a base rail, 1 m long along X.
## - hydrant: 80 cm fire hydrant with two side outlets.
## - parking_meter: single meter on a 1.2 m post, faces +Z.
## - light_pole: 2.7 m wood pole for string lights; the wire hooks at the top.

const MK := preload("res://model_src/model_kit.gd")

static func build(kind := "umbrella") -> Node3D:
	match kind:
		"bike_rack":
			return bike_rack()
		"hydrant":
			return hydrant()
		"parking_meter":
			return parking_meter()
		"light_pole":
			return light_pole()
	return umbrella()

static func umbrella() -> Node3D:
	var root := Node3D.new()
	root.name = "Umbrella"
	var pole: Material = MK.mat(MK.WOOD_DARK, 0.0, 0.6)
	MK.cyl(root, "Pole", 0.02, 0.02, 2.2, Vector3(0, 1.1, 0), pole, 10)
	MK.cyl(root, "Base", 0.22, 0.24, 0.06, Vector3(0, 0.03, 0), MK.mat(Color(0.25, 0.25, 0.26), 0.3, 0.6), 16)
	var canvas: Material = MK.mat(Color(0.93, 0.9, 0.82), 0.0, 0.9)
	var trim: Material = MK.mat(Color(0.22, 0.42, 0.28), 0.0, 0.8)
	# Eight-panel canopy as a shallow cone with a green valance.
	MK.cyl(root, "Canopy", 0.9, 0.04, 0.32, Vector3(0, 2.0, 0), canvas, 8)
	MK.cyl(root, "Valance", 0.905, 0.905, 0.08, Vector3(0, 1.82, 0), trim, 8)
	MK.sphere(root, "Finial", 0.035, Vector3(0, 2.2, 0), pole, 1.0, 8)
	for i in range(8):
		var a := TAU * (float(i) + 0.5) / 8.0
		var rib := MK.box(root, "Rib", Vector3(0.012, 0.012, 0.86), Vector3(sin(a) * 0.45, 1.83, cos(a) * 0.45), pole)
		rib.rotation = Vector3(-0.35, a, 0)
	return root

static func bike_rack() -> Node3D:
	var root := Node3D.new()
	root.name = "BikeRack"
	var steel: Material = MK.mat(Color(0.25, 0.27, 0.28), 0.6, 0.4)
	for sx in [-0.3, 0.3]:
		var hoop := PackedVector3Array()
		hoop.append(Vector3(sx + 0.22, 0.0, 0))
		for k in range(1, 12):
			var a := PI * float(k) / 11.0
			hoop.append(Vector3(sx + cos(a) * 0.22, 0.6 + sin(a) * 0.22, 0))
		hoop.append(Vector3(sx - 0.22, 0.0, 0))
		MK.sweep(root, "Hoop", hoop, 0.022, 0.022, steel, Vector3.BACK, 10)
	MK.box(root, "Rail", Vector3(1.0, 0.03, 0.05), Vector3(0, 0.015, 0), steel)
	return root

static func hydrant() -> Node3D:
	var root := Node3D.new()
	root.name = "Hydrant"
	var red: Material = MK.mat(Color(0.75, 0.16, 0.12), 0.2, 0.5)
	var cap: Material = MK.mat(Color(0.85, 0.82, 0.75), 0.2, 0.5)
	MK.cyl(root, "Flange", 0.13, 0.13, 0.05, Vector3(0, 0.025, 0), red, 16)
	MK.cyl(root, "Barrel", 0.1, 0.1, 0.55, Vector3(0, 0.325, 0), red, 16)
	MK.cyl(root, "Ring", 0.115, 0.115, 0.04, Vector3(0, 0.6, 0), red, 16)
	MK.sphere(root, "Bonnet", 0.105, Vector3(0, 0.63, 0), cap, 0.8, 16)
	MK.cyl(root, "Nut", 0.025, 0.03, 0.05, Vector3(0, 0.74, 0), cap, 5)
	for sx in [-1.0, 1.0]:
		MK.cyl(root, "Outlet", 0.04, 0.04, 0.09, Vector3(float(sx) * 0.13, 0.42, 0), red, 12, Vector3(0, 0, 90))
		MK.cyl(root, "OutletCap", 0.048, 0.048, 0.03, Vector3(float(sx) * 0.18, 0.42, 0), cap, 6, Vector3(0, 0, 90))
	MK.cyl(root, "Pumper", 0.055, 0.055, 0.08, Vector3(0, 0.4, 0.12), red, 12, Vector3(90, 0, 0))
	MK.cyl(root, "PumperCap", 0.065, 0.065, 0.03, Vector3(0, 0.4, 0.17), cap, 6, Vector3(90, 0, 0))
	return root

static func parking_meter() -> Node3D:
	var root := Node3D.new()
	root.name = "ParkingMeter"
	var grey: Material = MK.mat(Color(0.4, 0.42, 0.44), 0.6, 0.4)
	MK.cyl(root, "Post", 0.035, 0.035, 1.15, Vector3(0, 0.575, 0), grey, 10)
	MK.rounded_box(root, "Housing", Vector3(0.18, 0.3, 0.14), Vector3(0, 1.3, 0), 0.03, MK.mat(Color(0.3, 0.32, 0.34), 0.5, 0.45))
	MK.sphere(root, "Dome", 0.09, Vector3(0, 1.45, 0), MK.mat(Color(0.3, 0.32, 0.34), 0.5, 0.45), 0.9, 14)
	MK.box(root, "Screen", Vector3(0.11, 0.07, 0.004), Vector3(0, 1.36, 0.071), MK.mat(Color(0.55, 0.7, 0.6), 0.0, 0.3))
	MK.box(root, "Slot", Vector3(0.03, 0.006, 0.004), Vector3(0, 1.25, 0.071), MK.mat(Color(0.1, 0.1, 0.1), 0.0, 0.5))
	return root

static func light_pole() -> Node3D:
	var root := Node3D.new()
	root.name = "LightPole"
	var wood: Material = MK.mat(MK.WOOD_DARK, 0.0, 0.75)
	MK.box(root, "Post", Vector3(0.09, 2.7, 0.09), Vector3(0, 1.35, 0), wood)
	MK.box(root, "Footing", Vector3(0.3, 0.12, 0.3), Vector3(0, 0.06, 0), MK.mat(Color(0.62, 0.6, 0.57), 0.0, 0.95))
	MK.cyl(root, "Hook", 0.015, 0.015, 0.06, Vector3(0, 2.66, 0.05), MK.mat(Color(0.5, 0.5, 0.52), 0.7, 0.4), 8, Vector3(90, 0, 0))
	return root
