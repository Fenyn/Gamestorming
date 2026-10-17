extends RefCounted

## Rubber bar mat (38 x 38 cm, 1.2 cm thick) with a raised rim and a grid of
## nubs, where finished or in-progress items can be set down.
## Origin: underside centre. Read by counter_pad.gd: Slot0-3 markers on the mat
## surface.

const MK := preload("res://model_src/model_kit.gd")

const SIZE := 0.38
const THICK := 0.012

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "BarMat"
	var rubber: Material = MK.mat(Color(0.13, 0.13, 0.14), 0.0, 0.9)
	var nub: Material = MK.mat(Color(0.17, 0.17, 0.18), 0.0, 0.85)
	MK.rounded_box(root, "Mat", Vector3(SIZE, THICK * 0.6, SIZE), Vector3(0, THICK * 0.3, 0), 0.015, rubber)
	for sx in [-1.0, 1.0]:
		MK.box(root, "RimX", Vector3(SIZE - 0.02, THICK, 0.012), Vector3(0, THICK * 0.5, float(sx) * (SIZE * 0.5 - 0.006)), rubber)
		MK.box(root, "RimZ", Vector3(0.012, THICK, SIZE - 0.02), Vector3(float(sx) * (SIZE * 0.5 - 0.006), THICK * 0.5, 0), rubber)
	var nubs := MK.group(root, "Nubs")
	var n := 12
	for i in range(n):
		for j in range(n):
			var p := Vector3((float(i) - (n - 1) * 0.5) * 0.028, THICK * 0.6 + 0.002, (float(j) - (n - 1) * 0.5) * 0.028)
			MK.cyl(nubs, "Nub", 0.006, 0.005, 0.004, p, nub, 8)
	var top := THICK * 0.6 + 0.004
	var offsets := [Vector3(-0.08, top, -0.08), Vector3(0.08, top, -0.08), Vector3(-0.08, top, 0.08), Vector3(0.08, top, 0.08)]
	for i in range(4):
		MK.marker(root, "Slot%d" % i, offsets[i])
	return root
