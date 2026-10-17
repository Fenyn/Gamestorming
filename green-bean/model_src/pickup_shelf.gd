extends RefCounted

## Hand-off riser: a wooden plank on two blocks where finished drinks wait, with
## a tented chalkboard "PICK UP" sign readable from both sides.
## Origin: underside centre, on the counter. Customers are on +Z.
## Read by hand_off.gd: DrinkSpot (riser top, where the cup is stood).

const MK := preload("res://model_src/model_kit.gd")

const PLANK := Vector3(0.36, 0.018, 0.13)
const RISE := 0.035

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "PickupShelf"
	var wood: Material = MK.mat(MK.WOOD, 0.0, 0.65)
	var wood_dark: Material = MK.mat(MK.WOOD_DARK, 0.0, 0.7)
	for sx in [-1.0, 1.0]:
		MK.box(root, "Block", Vector3(0.04, RISE, PLANK.z - 0.02), Vector3(float(sx) * (PLANK.x * 0.5 - 0.035), RISE * 0.5, 0), wood_dark)
	var top := RISE + PLANK.y
	MK.rounded_box(root, "Plank", PLANK, Vector3(0, RISE + PLANK.y * 0.5, 0), 0.008, wood)

	# Tented sign at the right end: two boards leaning together.
	var sign := MK.group(root, "Sign")
	var board: Material = MK.mat(Color(0.15, 0.17, 0.16), 0.0, 0.9)
	var at := Vector3(0.125, top, 0)
	for sz in [-1.0, 1.0]:
		var b := MK.box(sign, "Board", Vector3(0.09, 0.075, 0.004), at + Vector3(0, 0.036, float(sz) * 0.011), board, Vector3(float(sz) * 17.0, 0, 0))
		var text := Label3D.new()
		text.name = "Text"
		text.text = "PICK UP"
		text.font_size = 40
		text.pixel_size = 0.0005
		text.outline_size = 0
		text.modulate = Color(0.94, 0.93, 0.88)
		text.position = Vector3(0, 0, 0.0025 * float(sz))
		text.rotation_degrees = Vector3(0, 0 if sz > 0.0 else 180, 0)
		b.add_child(text)
	MK.marker(root, "DrinkSpot", Vector3(-0.04, top, 0))
	return root
