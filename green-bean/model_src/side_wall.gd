extends RefCounted

## Side wall of the stand, 2.5 m tall and 0.1 m thick, from the back wall's
## outer face (z -1.3) to the service window (z 1.25). Cream inside, dark
## grey-green outside. It has either a window whose sill clears the back counter
## (the counter runs underneath it) or the staff door.
## Origin: floor level at the wall's centre line (shop x +-1.75, z 0).
## build(side, opening): side = 1 for the right wall (interior toward -X), -1 for
## the left; opening = "window" or "door". The door is the staff door, centred
## at DOOR_Z between the back counter (front edge z -0.42) and the front counter
## (z 0.8), with a concrete step outside because the stand floor is 10 cm up.

const MK := preload("res://model_src/model_kit.gd")

const HEIGHT := 2.5
const HALF_T := 0.05
const Z_BACK := -1.3
const Z_FRONT := 1.25
## Opening through the wall, then the frame inside it, then the glass.
const OPEN_Z := 0.468
const OPEN_Y := Vector2(1.055, 2.048)
const GLASS_Z := 0.345
const GLASS_Y := Vector2(1.15, 1.953)
const CASING := 0.125
const CASING_DEPTH := 0.039
const DOOR_Z := 0.1
const DOOR_HALF := 0.425
const DOOR_Y := Vector2(0.1, 2.13)
const DOOR_COLOR := Color(0.37, 0.41, 0.24)
const INSIDE := Color(0.902, 0.835, 0.733)
const OUTSIDE := Color(0.29, 0.27, 0.25)
const TRIM := Color(0.898, 0.6, 0.392)

static func build(side := 1, opening := "window") -> Node3D:
	var s := float(side)
	var root := Node3D.new()
	root.name = "SideWall"
	var trim: Material = MK.mat(TRIM, 0.0, 0.7)
	if opening == "door":
		_build_body(root, s, Rect2(DOOR_Z - DOOR_HALF, DOOR_Y.x, DOOR_HALF * 2.0, DOOR_Y.y - DOOR_Y.x))
		_build_door(root, s, trim)
		return root
	_build_body(root, s, Rect2(-OPEN_Z, OPEN_Y.x, OPEN_Z * 2.0, OPEN_Y.y - OPEN_Y.x))

	# Casing on both faces, jambs lining the opening, then the sash frame.
	for face in [-1.0, 1.0]:
		var x := s * float(face) * (HALF_T + CASING_DEPTH * 0.5)
		_ring(root, "Casing", Vector2(OPEN_Z + CASING, OPEN_Y.x - CASING * 0.76), Vector2(OPEN_Z + CASING, OPEN_Y.y + CASING * 0.77), OPEN_Z, OPEN_Y, x, CASING_DEPTH, trim)
	_ring(root, "Jamb", Vector2(OPEN_Z, OPEN_Y.x), Vector2(OPEN_Z, OPEN_Y.y), OPEN_Z - 0.012, Vector2(OPEN_Y.x + 0.012, OPEN_Y.y - 0.012), 0.0, HALF_T * 2.0, trim)
	_ring(root, "Sash", Vector2(OPEN_Z - 0.012, OPEN_Y.x + 0.012), Vector2(OPEN_Z - 0.012, OPEN_Y.y - 0.012), GLASS_Z, GLASS_Y, 0.0, 0.03, trim)
	MK.box(root, "Sill", Vector3(0.07, 0.02, (OPEN_Z + CASING) * 2.0 + 0.04), Vector3(s * (HALF_T + 0.035), OPEN_Y.x - CASING * 0.76 - 0.01, 0), trim)

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.83, 0.77, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic = 0.2
	MK.box(root, "Glass", Vector3(0.006, GLASS_Y.y - GLASS_Y.x, GLASS_Z * 2.0), Vector3(0, (GLASS_Y.x + GLASS_Y.y) * 0.5, 0), glass)
	return root

## Wall body round one opening (z, y rect); the outer 2 mm is the exterior colour.
static func _build_body(root: Node3D, s: float, hole: Rect2) -> void:
	var inside: Material = MK.mat(INSIDE, 0.0, 0.9)
	var outside: Material = MK.mat(OUTSIDE, 0.0, 0.85)
	var body := MK.group(root, "Body")
	var pieces := [Rect2(Z_BACK, hole.end.y, Z_FRONT - Z_BACK, HEIGHT - hole.end.y),
		Rect2(Z_BACK, 0.0, hole.position.x - Z_BACK, hole.end.y),
		Rect2(hole.end.x, 0.0, Z_FRONT - hole.end.x, hole.end.y)]
	if hole.position.y > 0.0:
		pieces.append(Rect2(hole.position.x, 0.0, hole.size.x, hole.position.y))
	for r in pieces:
		var rect: Rect2 = r
		var c := Vector3(0, rect.get_center().y, rect.get_center().x)
		MK.box(body, "Core", Vector3(HALF_T * 2.0 - 0.002, rect.size.y, rect.size.x), c + Vector3(-s * 0.001, 0, 0), inside)
		MK.box(body, "Exterior", Vector3(0.002, rect.size.y, rect.size.x), c + Vector3(s * (HALF_T - 0.001), 0, 0), outside)

## Staff door: casing on both faces, jambs, a painted slab with a narrow glass
## lite, lever handles, a kick plate, and the step outside.
static func _build_door(root: Node3D, s: float, trim: Material) -> void:
	var door := MK.group(root, "Door")
	door.position = Vector3(0, 0, DOOR_Z)
	var top := DOOR_Y.y
	var bottom := DOOR_Y.x
	for face in [-1.0, 1.0]:
		var x := s * float(face) * (HALF_T + CASING_DEPTH * 0.5)
		MK.box(door, "CasingTop", Vector3(CASING_DEPTH, 0.1, (DOOR_HALF + 0.09) * 2.0), Vector3(x, top + 0.05, 0), trim)
		for sz in [-1.0, 1.0]:
			MK.box(door, "CasingSide", Vector3(CASING_DEPTH, top, 0.09), Vector3(x, top * 0.5, float(sz) * (DOOR_HALF + 0.045)), trim)
	for sz in [-1.0, 1.0]:
		MK.box(door, "Jamb", Vector3(HALF_T * 2.0, top - bottom, 0.02), Vector3(0, (top + bottom) * 0.5, float(sz) * (DOOR_HALF - 0.01)), trim)
	MK.box(door, "Head", Vector3(HALF_T * 2.0, 0.02, DOOR_HALF * 2.0), Vector3(0, top - 0.01, 0), trim)
	MK.box(door, "Threshold", Vector3(HALF_T * 2.0 + 0.02, 0.012, DOOR_HALF * 2.0), Vector3(0, bottom + 0.006, 0), MK.mat(Color(0.6, 0.6, 0.62), 0.6, 0.4))

	var slab_w := (DOOR_HALF - 0.02) * 2.0 - 0.006
	var slab_h := top - bottom - 0.035
	var slab_y := bottom + 0.012 + slab_h * 0.5
	var lite := Vector2(0.12, 0.6)
	var lite_y := slab_y + 0.35
	var lite_z := -0.18
	var paint: Material = MK.mat(DOOR_COLOR, 0.0, 0.55)
	var t := 0.045
	# Slab in four pieces round the lite.
	MK.box(door, "Slab", Vector3(t, slab_h, slab_w * 0.5 + lite_z - lite.x * 0.5), Vector3(0, slab_y, (-slab_w * 0.5 + lite_z - lite.x * 0.5) * 0.5), paint)
	MK.box(door, "Slab", Vector3(t, slab_h, slab_w * 0.5 - lite_z - lite.x * 0.5), Vector3(0, slab_y, (slab_w * 0.5 + lite_z + lite.x * 0.5) * 0.5), paint)
	var slab_top := slab_y + slab_h * 0.5
	var slab_bottom := slab_y - slab_h * 0.5
	MK.box(door, "Slab", Vector3(t, slab_top - (lite_y + lite.y * 0.5), lite.x), Vector3(0, (slab_top + lite_y + lite.y * 0.5) * 0.5, lite_z), paint)
	MK.box(door, "Slab", Vector3(t, (lite_y - lite.y * 0.5) - slab_bottom, lite.x), Vector3(0, (slab_bottom + lite_y - lite.y * 0.5) * 0.5, lite_z), paint)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.83, 0.77, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	MK.box(door, "Lite", Vector3(0.006, lite.y, lite.x), Vector3(0, lite_y, lite_z), glass)

	var steel: Material = MK.mat(Color(0.72, 0.73, 0.75), 0.8, 0.3)
	for face in [-1.0, 1.0]:
		var x := float(face) * (t * 0.5 + 0.004)
		MK.box(door, "Rose", Vector3(0.008, 0.06, 0.03), Vector3(x, 1.0, slab_w * 0.5 - 0.07), steel)
		MK.box(door, "Lever", Vector3(0.02, 0.016, 0.11), Vector3(x + float(face) * 0.015, 1.0, slab_w * 0.5 - 0.12), steel)
		MK.box(door, "KickPlate", Vector3(0.003, 0.2, slab_w - 0.04), Vector3(x, slab_bottom + 0.11, 0), steel)
	MK.box(door, "Step", Vector3(0.38, 0.09, DOOR_HALF * 2.0 + 0.2), Vector3(s * (HALF_T + 0.19), 0.045, 0), MK.mat(Color(0.7, 0.68, 0.64), 0.0, 0.95))

## Rectangular frame in the wall plane: outer half-width/height to the inner
## opening, as four boards. outer_lo/outer_hi are (half_z, y) of the bottom and
## top edges.
static func _ring(root: Node3D, name: String, outer_lo: Vector2, outer_hi: Vector2, inner_z: float, inner_y: Vector2, x: float, depth: float, mat: Material) -> void:
	var g := MK.group(root, name)
	var half := outer_lo.x
	MK.box(g, "Bottom", Vector3(depth, inner_y.x - outer_lo.y, half * 2.0), Vector3(x, (outer_lo.y + inner_y.x) * 0.5, 0), mat)
	MK.box(g, "Top", Vector3(depth, outer_hi.y - inner_y.y, half * 2.0), Vector3(x, (inner_y.y + outer_hi.y) * 0.5, 0), mat)
	for sz in [-1.0, 1.0]:
		MK.box(g, "Side", Vector3(depth, inner_y.y - inner_y.x, half - inner_z), Vector3(x, (inner_y.x + inner_y.y) * 0.5, float(sz) * (inner_z + half) * 0.5), mat)
