extends RefCounted

## 12 oz sauce squeeze bottle: translucent white body (5.8 cm across), screw
## collar and a cone nozzle, 20 cm tall overall, with a plain paper label band.
## Origin: centre (base at y = -0.1).
## Read by sauce_bottle.gd: Collision (moved onto the item), Cap (tinted by the
## sauce), FillFloor marker and root metadata fill_radius / fill_max_height for
## the sauce level shown through the body.

const MK := preload("res://model_src/model_kit.gd")

const R := 0.029
const BASE_Y := -0.1
const SHOULDER_Y := 0.045
const COLLAR_Y := 0.058

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "SqueezeBottle"
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.93, 0.93, 0.9, 0.72)
	body.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body.roughness = 0.4
	var profile := PackedVector2Array([
		Vector2(0.0, BASE_Y), Vector2(R - 0.004, BASE_Y), Vector2(R, BASE_Y + 0.004),
		Vector2(R, SHOULDER_Y - 0.01), Vector2(R - 0.006, SHOULDER_Y), Vector2(0.016, COLLAR_Y),
	])
	MK.lathe(root, "Body", profile, Vector3.ZERO, body, 24)
	MK.cyl(root, "Label", R + 0.0006, R + 0.0006, 0.04, Vector3(0, -0.02, 0), MK.mat(Color(0.96, 0.95, 0.9), 0.0, 0.9), 24)

	var cap := MK.group(root, "Cap")
	var cap_mat: Material = MK.mat(Color(0.3, 0.3, 0.3), 0.0, 0.5)
	MK.cyl(cap, "Collar", 0.019, 0.019, 0.02, Vector3(0, COLLAR_Y + 0.01, 0), cap_mat, 20)
	MK.cyl(cap, "Nozzle", 0.008, 0.0025, 0.024, Vector3(0, COLLAR_Y + 0.032, 0), cap_mat, 14)

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = R
	shape.height = 0.2
	col.shape = shape
	root.add_child(col)

	MK.marker(root, "FillFloor", Vector3(0, BASE_Y + 0.003, 0))
	root.set_meta("fill_radius", R - 0.003)
	root.set_meta("fill_max_height", SHOULDER_Y - 0.012 - BASE_Y)
	return root
