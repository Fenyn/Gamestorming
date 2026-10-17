extends RefCounted

## AeroPress coffee maker (the carriable device), at real size.
##
## Dimensions from AeroPress (Original / Clear): chamber 12.1 cm tall and
## 10.7 cm across its hexagonal flange; plunger 13.4 cm tall with an 8.3 cm
## top. The chamber is a smoky translucent tube with the hex flange at the
## bottom (it rests on the mug rim there) and a black filter cap screwed on
## below it. Brew level marks 1-4 run up the front.
##
## Origin is the middle of the chamber, so the filter cap bottom sits at
## y = -0.0605 and the chamber top at 0.0605. Front (marks) faces +Z.
##
## Nodes the AeropressDevice script and stations use:
##   Collision      CylinderShape3D for the chamber. Moved onto the item at runtime.
##   RimRest        Marker3D on the underside of the flange. On a cup, this point
##                  sits on the cup rim.
##   LiquidFloor    Marker3D on top of the filter inside. Coffee is drawn up
##                  from here, to at most LiquidMaxHeight (root metadata).
##   Plunger        Node3D with the plunger, hidden until pressing. Its origin
##                  is the bottom of the seal.
##   PlungerTop     Marker3D: Plunger position when just pushed into the chamber.
##   PlungerBottom  Marker3D: Plunger position fully pressed (seal on the filter).

const MK := preload("res://model_src/model_kit.gd")

const BOTTOM := -0.0605
const TOP := 0.0605
const FLANGE_BOTTOM := -0.05
const FLANGE_TOP := -0.044
const OUTER_R := 0.032
const INNER_R := 0.0302
const FLOOR_Y := -0.047

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
	# Mark 4 is the most the chamber holds in the game.
	root.set_meta("liquid_max_height", 0.082)
	root.set_meta("liquid_radius", INNER_R - 0.0008)
	return root

static func _build_chamber(root: Node3D, smoke: Material) -> void:
	var chamber := MK.group(root, "Chamber")
	# Tube with a rolled lip at the top, traced up the outside and down the inside.
	var profile := PackedVector2Array([
		Vector2(INNER_R, FLANGE_TOP), Vector2(OUTER_R, FLANGE_TOP), Vector2(OUTER_R, TOP - 0.004),
		Vector2(OUTER_R + 0.0015, TOP - 0.002), Vector2(OUTER_R + 0.001, TOP),
		Vector2(INNER_R, TOP), Vector2(INNER_R, FLANGE_TOP),
	])
	MK.lathe(chamber, "Tube", profile, Vector3.ZERO, smoke, 32)
	# Hexagonal flange at the bottom: 10.7 cm across the corners.
	var flange := MK.cyl(chamber, "Flange", 0.0535, 0.0535, FLANGE_TOP - FLANGE_BOTTOM, Vector3(0, (FLANGE_TOP + FLANGE_BOTTOM) * 0.5, 0), smoke, 6)
	flange.rotation_degrees.y = 30.0
	# Short collar under the flange that the filter cap twists onto.
	MK.cyl(chamber, "Collar", OUTER_R + 0.001, OUTER_R + 0.001, 0.004, Vector3(0, FLANGE_BOTTOM - 0.002, 0), smoke, 24)

static func _build_filter_cap(root: Node3D, black: Material) -> void:
	var cap := MK.group(root, "FilterCap")
	var h := FLANGE_BOTTOM - 0.002 - BOTTOM
	MK.cyl(cap, "Cap", 0.036, 0.0355, h, Vector3(0, BOTTOM + h * 0.5, 0), black, 24)
	# Twist-lock lugs around the rim.
	for i in range(3):
		var a := TAU * float(i) / 3.0
		var lug := MK.box(cap, "Lug", Vector3(0.012, h * 0.7, 0.004), Vector3(sin(a) * 0.0365, BOTTOM + h * 0.5, cos(a) * 0.0365), black)
		lug.rotation.y = a
	# Paper filter edge just showing between cap and chamber.
	MK.cyl(cap, "FilterPaper", 0.0335, 0.0335, 0.001, Vector3(0, FLANGE_BOTTOM - 0.0045, 0), MK.mat(Color(0.97, 0.96, 0.93), 0.0, 0.9), 24)

static func _build_marks(root: Node3D) -> void:
	var marks := MK.group(root, "Marks")
	var white: Material = MK.mat(Color(0.95, 0.95, 0.95), 0.0, 0.6)
	# Levels 1-4 from just above the filter to the top of the brew range.
	for i in range(4):
		var y := FLOOR_Y + 0.018 + float(i) * 0.02
		MK.box(marks, "Tick", Vector3(0.008, 0.0012, 0.0006), Vector3(0.006, y, OUTER_R + 0.0003), white)
		var digit := Label3D.new()
		digit.name = "Level%d" % (i + 1)
		digit.text = str(i + 1)
		digit.font_size = 32
		digit.pixel_size = 0.00018
		digit.outline_size = 0
		digit.modulate = Color(0.95, 0.95, 0.95)
		digit.position = Vector3(-0.004, y, OUTER_R + 0.0006)
		marks.add_child(digit)
	# Circles between the numbers, like the real moulding.
	for i in range(3):
		var y := FLOOR_Y + 0.028 + float(i) * 0.02
		MK.cyl(marks, "Dot", 0.0012, 0.0012, 0.0006, Vector3(-0.004, y, OUTER_R + 0.0003), white, 8, Vector3(90, 0, 0))

static func _build_plunger(root: Node3D, smoke: Material, black: Material) -> void:
	var plunger := Node3D.new()
	plunger.name = "Plunger"
	plunger.visible = false
	root.add_child(plunger)
	var seal_h := 0.012
	# Rubber seal at the bottom, the long tube, and the flared top.
	MK.cyl(plunger, "Seal", INNER_R - 0.0002, INNER_R - 0.0002, seal_h, Vector3(0, seal_h * 0.5, 0), black, 24)
	var tube_h := 0.134 - seal_h - 0.008
	MK.cyl(plunger, "Tube", 0.028, 0.028, tube_h, Vector3(0, seal_h + tube_h * 0.5, 0), smoke, 24)
	MK.cyl(plunger, "TopFlare", 0.0415, 0.03, 0.008, Vector3(0, seal_h + tube_h + 0.004, 0), smoke, 24)
	MK.cyl(plunger, "TopCap", 0.0415, 0.0415, 0.002, Vector3(0, 0.134 - 0.001, 0), smoke, 24)
	# Plunger sits with its seal just inside the chamber top, and presses down to the filter.
	MK.marker(root, "PlungerTop", Vector3(0, TOP - seal_h - 0.004, 0))
	MK.marker(root, "PlungerBottom", Vector3(0, FLOOR_Y + 0.001, 0))
	plunger.position = Vector3(0, TOP - seal_h - 0.004, 0)
