extends RefCounted

## Sauce refill spot (caramel): a wood prep board with a 1.9 L sauce pouch lying
## on it and a place for the empty squeeze bottle. While filling, the station
## tips the pouch over the bottle (Pouch moves to PouchPour).
## Origin: base on the counter. The barista is on +Z (+X is their left).
## Read by sauce_prep_station.gd: BottleSpot, Pouch, PouchPour, PouchLabel
## (Label3D, set per sauce), CameraView. Collider in scenes/stations/sauce_prep.tscn.

const MK := preload("res://model_src/model_kit.gd")

const BOARD := Vector3(0.25, 0.015, 0.2)
const BOTTLE_SPOT := Vector3(0.065, 0.015, 0.01)
## Pouch body 12 x 18 x 3 cm; the spout is on local +Y.
const POUCH := Vector3(0.12, 0.18, 0.03)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "SaucePrepStation"
	MK.rounded_box(root, "Board", BOARD, Vector3(0, BOARD.y * 0.5, 0), 0.015, MK.mat(MK.WOOD, 0.0, 0.7))

	var pouch := MK.group(root, "Pouch")
	pouch.position = Vector3(-0.055, BOARD.y + POUCH.z * 0.5, 0.0)
	pouch.rotation_degrees = Vector3(-90, 0, 0)
	var foil: Material = MK.mat(Color(0.55, 0.33, 0.15), 0.3, 0.45)
	MK.rounded_box(pouch, "Body", POUCH, Vector3.ZERO, 0.012, foil)
	MK.box(pouch, "Seal", Vector3(POUCH.x - 0.004, 0.012, POUCH.z * 0.5), Vector3(0, POUCH.y * 0.5 + 0.004, 0), foil)
	MK.cyl(pouch, "Spout", 0.008, 0.008, 0.016, Vector3(0.035, POUCH.y * 0.5 + 0.016, 0), MK.mat(Color(0.95, 0.95, 0.93), 0.0, 0.5), 12)
	MK.cyl(pouch, "SpoutCap", 0.011, 0.011, 0.01, Vector3(0.035, POUCH.y * 0.5 + 0.028, 0), MK.mat(Color(0.85, 0.2, 0.15), 0.0, 0.5), 12)
	MK.box(pouch, "LabelPanel", Vector3(0.08, 0.07, 0.001), Vector3(0, 0.0, POUCH.z * 0.5 + 0.0005), MK.mat(Color(0.96, 0.94, 0.88), 0.0, 0.9))
	var label := Label3D.new()
	label.name = "PouchLabel"
	label.text = "Sauce"
	label.font_size = 40
	label.pixel_size = 0.0004
	label.outline_size = 0
	label.modulate = Color(0.3, 0.18, 0.1)
	label.position = Vector3(0, 0, POUCH.z * 0.5 + 0.0012)
	pouch.add_child(label)

	# Pour pose: upside down over the bottle, spout tipped toward +X onto the neck.
	var tip_target := BOTTLE_SPOT + Vector3(0, 0.23, 0)
	var angle := deg_to_rad(-155.0)
	var spout_offset := Basis(Vector3.BACK, angle) * Vector3(0.035, POUCH.y * 0.5 + 0.034, 0)
	MK.marker(root, "PouchPour", tip_target - spout_offset, Vector3(0, 0, -155))

	MK.marker(root, "BottleSpot", BOTTLE_SPOT)
	MK.marker(root, "CameraView", Vector3(0, 0.45, 0.38), Vector3(-30, 0, 0))
	return root
