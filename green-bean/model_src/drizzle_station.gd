extends RefCounted

## Sauce drizzle spot: a dark rubber mat (26 x 16 cm) with a printed cup ring
## where the cup stands, and a wire holder on the left that keeps the squeeze
## bottle upright. A small tent card names the sauce.
## Origin: base on the counter. The barista is on +Z (+X is their left).
## Read by sauce_station.gd: CupSpot, BottleSpot (holder floor), NameCard
## (Label3D, set per sauce). Colliders are in scenes/stations/sauce.tscn.

const MK := preload("res://model_src/model_kit.gd")

const MAT := Vector2(0.26, 0.16)
const CUP_SPOT := Vector3(-0.03, 0.005, 0.02)
const BOTTLE_SPOT := Vector3(0.085, 0.005, -0.02)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "DrizzleStation"
	MK.rounded_box(root, "Mat", Vector3(MAT.x, 0.005, MAT.y), Vector3(0, 0.0025, 0), 0.012, MK.mat(Color(0.14, 0.13, 0.13), 0.0, 0.9))
	MK.torus(root, "CupRing", 0.047, 0.051, CUP_SPOT + Vector3(0, 0.0002, 0), MK.mat(Color(0.4, 0.38, 0.36), 0.0, 0.9), Vector3.ZERO, 28)

	# Wire bottle holder: foot disc, two uprights and a ring at mid-height.
	var steel: Material = MK.mat(Color(0.72, 0.73, 0.75), 0.75, 0.3)
	var holder := MK.group(root, "BottleHolder")
	MK.cyl(holder, "Foot", 0.036, 0.036, 0.004, BOTTLE_SPOT + Vector3(0, -0.002, 0), steel, 20)
	for sz in [-1.0, 1.0]:
		MK.cyl(holder, "Upright", 0.0022, 0.0022, 0.09, BOTTLE_SPOT + Vector3(0.033 * float(sz), 0.045, 0), steel, 8)
	MK.torus(holder, "Ring", 0.032, 0.035, BOTTLE_SPOT + Vector3(0, 0.09, 0), steel, Vector3.ZERO, 24)

	# Tent card at the back-right corner.
	var card := MK.group(root, "Card")
	var paper: Material = MK.mat(Color(0.96, 0.94, 0.88), 0.0, 0.9)
	var at := Vector3(-0.09, 0.005, -0.055)
	for sz in [-1.0, 1.0]:
		MK.box(card, "Leaf", Vector3(0.06, 0.04, 0.002), at + Vector3(0, 0.019, 0.006 * float(sz)), paper, Vector3(float(sz) * 15.0, 0, 0))
	var name_card := Label3D.new()
	name_card.name = "NameCard"
	name_card.text = "Sauce"
	name_card.font_size = 40
	name_card.pixel_size = 0.0004
	name_card.outline_size = 0
	name_card.modulate = Color(0.25, 0.2, 0.15)
	name_card.position = at + Vector3(0, 0.02, 0.0125)
	name_card.rotation_degrees = Vector3(-15, 0, 0)
	root.add_child(name_card)

	MK.marker(root, "CupSpot", CUP_SPOT)
	MK.marker(root, "BottleSpot", BOTTLE_SPOT)
	return root
