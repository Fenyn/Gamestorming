extends RefCounted

## Flat plastic stirring paddle for the shot press: 17 cm long, 2.2 cm blade.
## Origin: the blade's bottom edge, centred. The blade lies in the XY plane.

const MK := preload("res://model_src/model_kit.gd")

const LENGTH := 0.17
const BLADE := Vector2(0.022, 0.035)
const THICK := 0.003

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "StirPaddle"
	var plastic: Material = MK.mat(Color(0.14, 0.14, 0.15), 0.0, 0.5)
	MK.rounded_box(root, "Blade", Vector3(BLADE.x, BLADE.y, THICK), Vector3(0, BLADE.y * 0.5, 0), 0.004, plastic)
	var shaft_h := LENGTH - BLADE.y - 0.03
	MK.box(root, "Shaft", Vector3(0.008, shaft_h, THICK), Vector3(0, BLADE.y + shaft_h * 0.5, 0), plastic)
	MK.rounded_box(root, "Grip", Vector3(0.016, 0.03, THICK + 0.001), Vector3(0, LENGTH - 0.015, 0), 0.006, plastic)
	return root
