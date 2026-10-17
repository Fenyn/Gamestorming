extends RefCounted

## Single-wall hot paper cup with a rolled rim, kraft sleeve and a sip lid.
## Sizes follow common hot cups (top / bottom diameter x height):
## 8 oz 80/56 x 92 mm, 12 oz 90/60 x 112, 16 oz 90/60 x 136, 20 oz 90/60 x 155.
## Origin: centre (base at y = -height / 2). Front (+Z) gets the ticket sticker.
##
## Read by cup.gd: Collision (moved onto the item), Lid (shown when lidded),
## LiquidFloor, StickerSpot, and root metadata "inner_profile" (inside wall as
## (radius, y), low to high) so the drink widens with the cup.

const MK := preload("res://model_src/model_kit.gd")

const SIZES := {
	"small": [0.040, 0.028, 0.092],
	"medium": [0.045, 0.030, 0.112],
	"large": [0.045, 0.030, 0.136],
	"extra_large": [0.045, 0.030, 0.155],
}
const PAPER := Color(0.96, 0.95, 0.92)
const KRAFT := Color(0.62, 0.45, 0.3)
const LID := Color(0.16, 0.13, 0.11)
const WALL := 0.0012

static func build(size_name := "medium") -> Node3D:
	var dims: Array = SIZES[size_name]
	var top_r: float = dims[0]
	var bottom_r: float = dims[1]
	var h: float = dims[2]
	var root := Node3D.new()
	root.name = "PaperCup_" + size_name
	var paper: Material = MK.mat(PAPER, 0.0, 0.8)
	var base_y := -h * 0.5
	var rim_y := h * 0.5 - 0.002
	var floor_y := base_y + 0.008
	var r_at := func(y: float) -> float:
		return lerpf(bottom_r, top_r, (y - base_y) / (rim_y - base_y))

	# Recessed base: the wall runs a little below the floor disc, like a real cup.
	var profile := PackedVector2Array([
		Vector2(bottom_r - 0.003, base_y), Vector2(bottom_r, base_y),
		Vector2(top_r, rim_y), Vector2(top_r - WALL, rim_y),
		Vector2(float(r_at.call(floor_y)) - WALL, floor_y), Vector2(0.0, floor_y),
		Vector2(0.0, floor_y - 0.001), Vector2(bottom_r - 0.003, floor_y - 0.001),
		Vector2(bottom_r - 0.003, base_y),
	])
	MK.lathe(root, "Body", profile, Vector3.ZERO, paper, 32)
	MK.torus(root, "RolledRim", top_r - 0.0012, top_r + 0.0018, Vector3(0, rim_y + 0.0008, 0), paper, Vector3.ZERO, 32)

	# Corrugated kraft sleeve around the lower middle, a few mm off the wall.
	var sleeve_low := base_y + h * 0.22
	var sleeve_high := base_y + h * 0.62
	var sleeve_profile := PackedVector2Array([
		Vector2(float(r_at.call(sleeve_low)) + 0.0004, sleeve_low), Vector2(float(r_at.call(sleeve_low)) + 0.0022, sleeve_low),
		Vector2(float(r_at.call(sleeve_high)) + 0.0022, sleeve_high), Vector2(float(r_at.call(sleeve_high)) + 0.0004, sleeve_high),
	])
	MK.lathe(root, "Sleeve", sleeve_profile, Vector3.ZERO, MK.mat(KRAFT, 0.0, 0.95), 32)

	_build_lid(root, top_r, rim_y)

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = top_r
	shape.height = h
	col.shape = shape
	root.add_child(col)

	MK.marker(root, "LiquidFloor", Vector3(0, floor_y, 0))
	var sticker_y := base_y + h * 0.78
	var slope := atan2(top_r - bottom_r, rim_y - base_y)
	MK.marker(root, "StickerSpot", Vector3(0, sticker_y, float(r_at.call(sticker_y)) + 0.0006), Vector3(rad_to_deg(slope), 0, 0))
	var inner := PackedVector2Array([
		Vector2(float(r_at.call(floor_y)) - WALL, floor_y), Vector2(top_r - WALL, rim_y),
	])
	root.set_meta("inner_profile", inner)
	return root

## Domed sip lid that snaps over the rim, with the sip slot at the front.
static func _build_lid(root: Node3D, top_r: float, rim_y: float) -> void:
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, rim_y, 0)
	lid.visible = false
	root.add_child(lid)
	var plastic: Material = MK.mat(LID, 0.0, 0.35)
	var r := top_r + 0.0025
	var profile := PackedVector2Array([
		Vector2(r - 0.002, -0.003), Vector2(r, -0.002), Vector2(r, 0.004),
		Vector2(r - 0.003, 0.006), Vector2(r - 0.006, 0.006), Vector2(r - 0.009, 0.013),
		Vector2(r * 0.55, 0.016), Vector2(0.0, 0.0165),
	])
	MK.lathe(lid, "Shell", profile, Vector3.ZERO, plastic, 32)
	var slot: Material = MK.mat(Color(0.05, 0.04, 0.04), 0.0, 0.6)
	# Raised sip spout with its opening, at the front edge of the dome.
	MK.box(lid, "SipRise", Vector3(0.016, 0.004, 0.008), Vector3(0, 0.016, r - 0.012), plastic)
	MK.box(lid, "SipSlot", Vector3(0.011, 0.001, 0.0035), Vector3(0, 0.0183, r - 0.011), slot)
	MK.cyl(lid, "Vent", 0.0012, 0.0012, 0.001, Vector3(0, 0.0168, -r * 0.45), slot, 8)
