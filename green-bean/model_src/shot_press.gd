extends RefCounted

## Shot press (plunger brewer): chamber 12.1 cm with a 9.2 cm flange, plunger
## 13.4 cm. Origin: chamber centre (filter cap bottom at y = -0.0605). Fill marks
## face +Z; the top one, with "FILL" beside it, is the water line.
##
## Read by shot_press.gd: Collision (moved onto the item), RimRest (flange
## underside, sits on the cup rim), LiquidFloor and root metadata
## liquid_max_height (the FILL line) / liquid_radius / rim_height, Plunger
## (hidden until pressing; origin at the seal bottom) with Plunger/Level/Bubble
## (moved across the vial, metadata "travel" = its reach from centre) under a
## printed ring (metadata "ring_radius"), PlungerTop, PlungerBottom.

const MK := preload("res://model_src/model_kit.gd")

const BOTTOM := -0.0605
const TOP := 0.0605
const FLANGE_BOTTOM := -0.05
const FLANGE_TOP := -0.044
const OUTER_R := 0.032
const INNER_R := 0.0302
const FLOOR_Y := -0.047
## Water line above the liquid floor, and the rim's height above it.
const FILL_H := 0.09
const RIM_H := TOP - 0.002 - FLOOR_Y
const PLUNGER_H := 0.134
const VIAL_R := 0.016

static func _smoke() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.33, 0.35, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.25
	m.metallic = 0.0
	return m

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "ShotPress"
	var smoke := _smoke()
	var black: Material = MK.mat(Color(0.09, 0.09, 0.1), 0.0, 0.55)

	_build_chamber(root, smoke)
	_build_filter_cap(root, black)
	_build_marks(root)
	_build_plunger(root, smoke, black)

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = 0.034
	shape.height = TOP - BOTTOM
	col.shape = shape
	root.add_child(col)

	MK.marker(root, "RimRest", Vector3(0, FLANGE_BOTTOM, 0))
	MK.marker(root, "LiquidFloor", Vector3(0, FLOOR_Y, 0))
	root.set_meta("liquid_max_height", FILL_H)
	root.set_meta("rim_height", RIM_H)
	root.set_meta("liquid_radius", INNER_R - 0.0008)
	return root

static func _build_chamber(root: Node3D, smoke: Material) -> void:
	var chamber := MK.group(root, "Chamber")
	var profile := PackedVector2Array([
		Vector2(INNER_R, FLANGE_TOP), Vector2(OUTER_R, FLANGE_TOP), Vector2(OUTER_R, TOP - 0.004),
		Vector2(OUTER_R + 0.0015, TOP - 0.002), Vector2(OUTER_R + 0.001, TOP),
		Vector2(INNER_R, TOP), Vector2(INNER_R, FLANGE_TOP),
	])
	MK.lathe(chamber, "Tube", profile, Vector3.ZERO, smoke, 32)
	var flange_h := FLANGE_TOP - FLANGE_BOTTOM
	var flange_y := (FLANGE_TOP + FLANGE_BOTTOM) * 0.5
	MK.cyl(chamber, "Flange", 0.046, 0.046, flange_h, Vector3(0, flange_y, 0), smoke, 32)
	for sx in [-1.0, 1.0]:
		MK.box(chamber, "GripTab", Vector3(0.018, flange_h, 0.026), Vector3(float(sx) * 0.05, flange_y, 0), smoke)
	MK.cyl(chamber, "Collar", OUTER_R + 0.001, OUTER_R + 0.001, 0.004, Vector3(0, FLANGE_BOTTOM - 0.002, 0), smoke, 24)

static func _build_filter_cap(root: Node3D, black: Material) -> void:
	var cap := MK.group(root, "FilterCap")
	var h := FLANGE_BOTTOM - 0.002 - BOTTOM
	MK.cyl(cap, "Cap", 0.036, 0.0355, h, Vector3(0, BOTTOM + h * 0.5, 0), black, 24)
	for i in range(3):
		var a := TAU * float(i) / 3.0
		var lug := MK.box(cap, "Lug", Vector3(0.012, h * 0.7, 0.004), Vector3(sin(a) * 0.0365, BOTTOM + h * 0.5, cos(a) * 0.0365), black)
		lug.rotation.y = a
	MK.cyl(cap, "FilterPaper", 0.0335, 0.0335, 0.001, Vector3(0, FLANGE_BOTTOM - 0.0045, 0), MK.mat(Color(0.97, 0.96, 0.93), 0.0, 0.9), 24)

## Ticks every centimetre up the front, and a wide FILL line at the water line.
static func _build_marks(root: Node3D) -> void:
	var marks := MK.group(root, "Marks")
	var white: Material = MK.mat(Color(0.95, 0.95, 0.95), 0.0, 0.6)
	for i in range(8):
		var y := FLOOR_Y + 0.02 + float(i) * 0.01
		if y > FLOOR_Y + FILL_H - 0.005:
			break
		var w := 0.008 if i % 2 == 0 else 0.004
		MK.box(marks, "Tick", Vector3(w, 0.001, 0.0006), Vector3(0.0, y, OUTER_R + 0.0003), white)
	# The line wraps a quarter of the way round so it reads from an angle.
	var fill_y := FLOOR_Y + FILL_H
	for i in range(9):
		var a := deg_to_rad(-45.0 + float(i) * 11.25)
		var seg := MK.box(marks, "FillLine", Vector3(0.0066, 0.0016, 0.0006), Vector3(sin(a) * (OUTER_R + 0.0003), fill_y, cos(a) * (OUTER_R + 0.0003)), white)
		seg.rotation.y = a
	var l := Label3D.new()
	l.name = "FillText"
	l.text = "FILL"
	l.font_size = 32
	l.pixel_size = 0.00016
	l.outline_size = 0
	l.modulate = Color(0.95, 0.95, 0.95)
	l.position = Vector3(0, fill_y + 0.0042, OUTER_R + 0.0004)
	marks.add_child(l)

## Bubble level set into the plunger cap: a shallow clear vial with a printed
## ring. Keep the bubble inside the ring while pressing.
static func _build_level(plunger: Node3D, black: Material) -> void:
	var level := MK.group(plunger, "Level")
	level.position = Vector3(0, PLUNGER_H, 0)
	MK.cyl(level, "Bezel", VIAL_R + 0.0025, VIAL_R + 0.0025, 0.0016, Vector3(0, 0.0008, 0), black, 32)
	MK.cyl(level, "Face", VIAL_R, VIAL_R, 0.0004, Vector3(0, 0.0018, 0), MK.mat(Color(0.86, 0.9, 0.62), 0.0, 0.3), 32)
	var ring_r := VIAL_R * 0.42
	MK.torus(level, "Ring", ring_r - 0.0005, ring_r + 0.0005, Vector3(0, 0.0021, 0), MK.mat(Color(0.12, 0.12, 0.12), 0.0, 0.5), Vector3.ZERO, 32)
	MK.box(level, "CrossX", Vector3(VIAL_R * 1.6, 0.0002, 0.0004), Vector3(0, 0.0021, 0), MK.mat(Color(0.3, 0.3, 0.3), 0.0, 0.5))
	MK.box(level, "CrossZ", Vector3(0.0004, 0.0002, VIAL_R * 1.6), Vector3(0, 0.0021, 0), MK.mat(Color(0.3, 0.3, 0.3), 0.0, 0.5))
	var bubble := MK.sphere(level, "Bubble", 0.0034, Vector3(0, 0.0024, 0), MK.mat(Color(0.97, 0.98, 0.9), 0.0, 0.1), 0.45, 12)
	bubble.set_meta("travel", VIAL_R - 0.0036)
	var dome := StandardMaterial3D.new()
	dome.albedo_color = Color(0.9, 0.95, 1.0, 0.18)
	dome.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dome.roughness = 0.02
	MK.sphere(level, "Dome", VIAL_R, Vector3(0, 0.0018, 0), dome, 0.22, 24)
	level.set_meta("ring_radius", ring_r)

static func _build_plunger(root: Node3D, smoke: Material, black: Material) -> void:
	var plunger := Node3D.new()
	plunger.name = "Plunger"
	plunger.visible = false
	root.add_child(plunger)
	var seal_h := 0.012
	MK.cyl(plunger, "Seal", INNER_R - 0.0002, INNER_R - 0.0002, seal_h, Vector3(0, seal_h * 0.5, 0), black, 24)
	var tube_h := 0.134 - seal_h - 0.008
	MK.cyl(plunger, "Tube", 0.028, 0.028, tube_h, Vector3(0, seal_h + tube_h * 0.5, 0), smoke, 24)
	MK.cyl(plunger, "TopFlare", 0.0415, 0.03, 0.008, Vector3(0, seal_h + tube_h + 0.004, 0), smoke, 24)
	MK.cyl(plunger, "TopCap", 0.0415, 0.0415, 0.002, Vector3(0, PLUNGER_H - 0.001, 0), smoke, 24)
	_build_level(plunger, black)
	MK.marker(root, "PlungerTop", Vector3(0, TOP - seal_h - 0.004, 0))
	MK.marker(root, "PlungerBottom", Vector3(0, FLOOR_Y + 0.001, 0))
	plunger.position = Vector3(0, TOP - seal_h - 0.004, 0)
