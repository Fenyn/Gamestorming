extends RefCounted

## Hand coffee grinder for the grinder station.
##
## Fits the station's 0.25 x 0.35 x 0.25 m collision box. Origin is the centre of
## that box, so the base plate sits at y = -0.175. Front faces +Z (the barista).
##
## Layout: a wooden base plate; a wooden body at the back with a steel burr
## housing and a bean hopper on top; a spout that points forward over the spot
## where the dripper or aeropress sits. The crank handle is not part of the
## model: grinder_station.gd builds it so it can turn with the mouse.

const BASE_TOP := -0.145
const BODY_Z := -0.055
## Where the station script should hang the crank (right side of the body).
const CRANK_PIVOT := Vector3(0.082, -0.045, -0.055)
## Tip of the spout, for the grind dust particles.
const SPOUT_TIP := Vector3(0, -0.035, 0.045)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "HandGrinder"

	# Base plate with a darker trim strip around the bottom.
	ModelKit.box(root, "Base", Vector3(0.25, 0.026, 0.25), Vector3(0, -0.162, 0), ModelKit.mat(ModelKit.WOOD_DARK))
	ModelKit.box(root, "BaseTrim", Vector3(0.254, 0.008, 0.254), Vector3(0, -0.171, 0), ModelKit.mat(ModelKit.WOOD_DARKER))
	# Dosing pad where the device sits, slightly darker so it reads as a spot.
	ModelKit.cyl(root, "DosingPad", 0.055, 0.055, 0.004, Vector3(0, BASE_TOP + 0.002, 0.055), ModelKit.mat(ModelKit.WOOD_DARKER), 20)

	# Wooden body.
	ModelKit.box(root, "Body", Vector3(0.13, 0.15, 0.12), Vector3(0, -0.07, BODY_Z), ModelKit.mat(ModelKit.WOOD))
	ModelKit.box(root, "BodyCap", Vector3(0.14, 0.012, 0.13), Vector3(0, 0.011, BODY_Z), ModelKit.mat(ModelKit.WOOD_DARK))
	# Little drawer on the back, like a classic box grinder.
	ModelKit.box(root, "Drawer", Vector3(0.09, 0.045, 0.006), Vector3(0, -0.1, BODY_Z - 0.063), ModelKit.mat(ModelKit.WOOD_DARK))
	ModelKit.sphere(root, "DrawerKnob", 0.008, Vector3(0, -0.1, BODY_Z - 0.069), ModelKit.metal(ModelKit.METAL_DARK))
	# Brass-coloured plate on the front with the grind setting dial.
	ModelKit.box(root, "FrontPlate", Vector3(0.07, 0.04, 0.004), Vector3(0, -0.11, BODY_Z + 0.062), ModelKit.metal(Color(0.85, 0.68, 0.36)))
	ModelKit.cyl(root, "Dial", 0.016, 0.016, 0.008, Vector3(0, -0.11, BODY_Z + 0.066), ModelKit.metal(ModelKit.METAL_DARK), 12, Vector3(90, 0, 0))
	ModelKit.box(root, "DialMark", Vector3(0.003, 0.012, 0.003), Vector3(0, -0.103, BODY_Z + 0.071), ModelKit.mat(ModelKit.CREAM))

	# Spout: a short steel chute angled down toward the device, with a lip.
	# Tilting the cylinder -62 degrees about X leans its top back into the body,
	# so the open bottom end points forward and down over the dosing pad.
	ModelKit.cyl(root, "Spout", 0.02, 0.016, 0.07, Vector3(0, -0.012, 0.012), ModelKit.metal(ModelKit.STEEL), 12, Vector3(-62, 0, 0))
	ModelKit.torus(root, "SpoutLip", 0.016, 0.024, Vector3(0, -0.028, 0.043), ModelKit.metal(ModelKit.METAL_DARK), Vector3(-62, 0, 0))

	# Burr housing and hopper.
	ModelKit.cyl(root, "BurrHousing", 0.05, 0.046, 0.045, Vector3(0, 0.04, BODY_Z), ModelKit.metal(ModelKit.STEEL), 20)
	ModelKit.torus(root, "HousingRing", 0.044, 0.054, Vector3(0, 0.02, BODY_Z), ModelKit.metal(ModelKit.METAL_DARK))
	ModelKit.cyl(root, "Hopper", 0.044, 0.062, 0.07, Vector3(0, 0.097, BODY_Z), ModelKit.metal(ModelKit.METAL), 20)
	ModelKit.torus(root, "HopperRim", 0.058, 0.068, Vector3(0, 0.132, BODY_Z), ModelKit.metal(ModelKit.STEEL))
	# Heap of beans filling the hopper.
	ModelKit.sphere(root, "BeanHeap", 0.058, Vector3(0, 0.122, BODY_Z), ModelKit.mat(ModelKit.BEANS), 0.45, 16)
	for i in range(9):
		var a := TAU * float(i) / 9.0
		var r := 0.03 if i % 2 == 0 else 0.042
		ModelKit.sphere(root, "Bean%d" % i, 0.01, Vector3(cos(a) * r, 0.134 - r * 0.15, BODY_Z + sin(a) * r), ModelKit.mat(ModelKit.BEANS.darkened(0.25)), 0.65, 8)

	# Shaft through the right side, where the crank attaches.
	ModelKit.cyl(root, "CrankShaft", 0.008, 0.008, 0.03, CRANK_PIVOT + Vector3(-0.012, 0, 0), ModelKit.metal(ModelKit.METAL_DARK), 10, Vector3(0, 0, 90))
	ModelKit.cyl(root, "CrankBoss", 0.018, 0.018, 0.012, Vector3(0.069, CRANK_PIVOT.y, CRANK_PIVOT.z), ModelKit.metal(ModelKit.STEEL), 14, Vector3(0, 0, 90))
	return root
