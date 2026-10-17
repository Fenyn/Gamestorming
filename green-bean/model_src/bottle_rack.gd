extends RefCounted

## Wire rack holding three squeeze bottles upright, 24 x 8 cm.
## Origin: base on the counter. Read by bottle_rack.gd: Slot0-2 (floor of each
## ring; a bottle is stood on it).

const MK := preload("res://model_src/model_kit.gd")

const PITCH := 0.075
const RING_R := 0.033
const RING_Y := 0.07

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "BottleRack"
	var steel: Material = MK.mat(Color(0.72, 0.73, 0.75), 0.75, 0.3)
	MK.box(root, "Base", Vector3(0.24, 0.004, 0.08), Vector3(0, 0.002, 0), steel)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MK.cyl(root, "Leg", 0.0025, 0.0025, RING_Y, Vector3(float(sx) * 0.115, RING_Y * 0.5, float(sz) * 0.034), steel, 8)
	for sz in [-1.0, 1.0]:
		MK.cyl(root, "Rail", 0.0025, 0.0025, 0.23, Vector3(0, RING_Y, float(sz) * 0.034), steel, 8, Vector3(0, 0, 90))
	for i in range(3):
		var x := (float(i) - 1.0) * PITCH
		MK.torus(root, "Ring", RING_R - 0.0025, RING_R + 0.0025, Vector3(x, RING_Y, 0), steel, Vector3.ZERO, 24)
		MK.marker(root, "Slot%d" % i, Vector3(x, 0.004, 0))
	return root
