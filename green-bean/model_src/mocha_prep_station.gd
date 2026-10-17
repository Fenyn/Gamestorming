extends RefCounted

## Mocha batch spot: a wood prep board with a 2 L clear mixing jug (handle on the
## left, spout on the right), a stand-up bag of cocoa powder, a balloon whisk,
## and a place for the empty squeeze bottle.
## Origin: base on the counter. The barista is on +Z (+X is their left).
## Read by mocha_prep_station.gd: PowderBag (hidden while its powder is in the
## jug), BagCut (start of the cut line across the bag's top), JugFloor and root
## metadata jug_radius / jug_fill_height for the batch level, BottleSpot,
## CameraView. Collider in scenes/stations/mocha_prep.tscn.

const MK := preload("res://model_src/model_kit.gd")

const BOARD := Vector3(0.3, 0.015, 0.22)
const JUG := Vector3(-0.08, 0.015, -0.01)
const JUG_R := 0.058
const JUG_H := 0.17
const BAG := Vector3(0.065, 0.015, -0.055)
const BAG_SIZE := Vector3(0.08, 0.11, 0.045)
const BOTTLE_SPOT := Vector3(0.105, 0.015, 0.055)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "MochaPrepStation"
	MK.rounded_box(root, "Board", BOARD, Vector3(0, BOARD.y * 0.5, 0), 0.015, MK.mat(MK.WOOD, 0.0, 0.7))
	_build_jug(root)
	_build_bag(root)
	_build_whisk(root)
	MK.marker(root, "BottleSpot", BOTTLE_SPOT)
	MK.marker(root, "CameraView", Vector3(0, 0.45, 0.36), Vector3(-35, 0, 0))
	return root

static func _build_jug(root: Node3D) -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.82, 0.88, 0.9, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	var jug := MK.group(root, "Jug")
	jug.position = JUG
	var profile := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(JUG_R - 0.006, 0.0), Vector2(JUG_R - 0.002, 0.004),
		Vector2(JUG_R + 0.004, JUG_H), Vector2(JUG_R + 0.001, JUG_H),
	])
	MK.lathe(jug, "Body", profile, Vector3.ZERO, glass, 28, func(v: Vector3, a: float) -> Vector3:
		# Pull the rim out into a pour spout on +X.
		var t := clampf((v.y - JUG_H * 0.8) / (JUG_H * 0.2), 0.0, 1.0)
		var lip := maxf(cos(a - PI * 0.5), 0.0)
		return v + Vector3(lip * lip * lip * 0.018 * t, 0, 0))
	var ticks: Material = MK.mat(Color(0.35, 0.4, 0.45), 0.0, 0.6)
	for i in range(4):
		MK.box(jug, "Tick", Vector3(0.012, 0.0015, 0.001), Vector3(0, 0.035 + float(i) * 0.03, JUG_R + 0.0015 + float(i) * 0.0007), ticks)
	var path := PackedVector3Array()
	for k in range(12):
		var t := float(k) / 11.0
		path.append(Vector3(-JUG_R - 0.002 - sin(t * PI) * 0.04, JUG_H - 0.02 - t * 0.11, 0))
	MK.sweep(jug, "Handle", path, 0.005, 0.009, glass, Vector3.BACK, 8)
	MK.marker(root, "JugFloor", JUG + Vector3(0, 0.005, 0))
	root.set_meta("jug_radius", JUG_R - 0.004)
	root.set_meta("jug_fill_height", JUG_H * 0.8)

static func _build_bag(root: Node3D) -> void:
	var bag := MK.group(root, "PowderBag")
	bag.position = BAG
	var kraft: Material = MK.mat(Color(0.62, 0.45, 0.3), 0.0, 0.95)
	MK.rounded_box(bag, "Body", BAG_SIZE, Vector3(0, BAG_SIZE.y * 0.5, 0), 0.01, kraft)
	MK.box(bag, "Fold", Vector3(BAG_SIZE.x, 0.015, 0.012), Vector3(0, BAG_SIZE.y + 0.0075, 0), kraft)
	MK.box(bag, "LabelPanel", Vector3(0.06, 0.05, 0.001), Vector3(0, 0.05, BAG_SIZE.z * 0.5 + 0.0005), MK.mat(Color(0.96, 0.94, 0.88), 0.0, 0.9))
	var label := Label3D.new()
	label.name = "BagLabel"
	label.text = "Cocoa"
	label.font_size = 40
	label.pixel_size = 0.0004
	label.outline_size = 0
	label.modulate = Color(0.3, 0.18, 0.1)
	label.position = Vector3(0, 0.05, BAG_SIZE.z * 0.5 + 0.0012)
	bag.add_child(label)
	MK.marker(root, "BagCut", BAG + Vector3(-BAG_SIZE.x * 0.5, BAG_SIZE.y - 0.008, BAG_SIZE.z * 0.5 + 0.002))

## Balloon whisk lying across the front of the board.
static func _build_whisk(root: Node3D) -> void:
	var whisk := MK.group(root, "Whisk")
	whisk.position = Vector3(-0.01, BOARD.y + 0.012, 0.085)
	whisk.rotation_degrees = Vector3(0, 0, 90)
	var steel: Material = MK.mat(Color(0.78, 0.79, 0.8), 0.8, 0.3)
	MK.cyl(whisk, "Handle", 0.009, 0.007, 0.1, Vector3(0, -0.06, 0), MK.mat(Color(0.15, 0.15, 0.16), 0.0, 0.5), 12)
	for i in range(4):
		var loop := MK.torus(whisk, "Wire", 0.024, 0.0265, Vector3(0, 0.035, 0), steel, Vector3(0, 45.0 * float(i), 90), 20)
		# Stretch along the whisk's axis (the ring's local X after the 90 deg roll).
		loop.scale = Vector3(1.6, 1, 1)
