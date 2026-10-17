extends RefCounted

## Side wall of the stand with one window whose sill clears the back counter, so
## the counter runs underneath it (the stock wall's window came down to 0.67 m
## and the counter cut through its trim). 2.5 m tall, 0.1 m thick, from the back
## wall's outer face (z -1.3) to the service window (z 1.25).
## Cream inside, dark grey-green outside, wood casing round the window on both
## faces, a wood frame in the opening and a glass pane.
## Origin: floor level at the wall's centre line (shop x +-1.75, z 0).
## build(side): side = 1 for the right wall (interior toward -X), -1 for the left.

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
const INSIDE := Color(0.902, 0.835, 0.733)
const OUTSIDE := Color(0.306, 0.388, 0.388)
const TRIM := Color(0.898, 0.6, 0.392)

static func build(side := 1) -> Node3D:
	var s := float(side)
	var root := Node3D.new()
	root.name = "SideWall"
	var inside: Material = MK.mat(INSIDE, 0.0, 0.9)
	var outside: Material = MK.mat(OUTSIDE, 0.0, 0.85)
	var trim: Material = MK.mat(TRIM, 0.0, 0.7)

	# Wall body round the opening; the outer 2 mm is the exterior colour.
	var body := MK.group(root, "Body")
	for r in [Rect2(Z_BACK, 0.0, Z_FRONT - Z_BACK, OPEN_Y.x),
			Rect2(Z_BACK, OPEN_Y.y, Z_FRONT - Z_BACK, HEIGHT - OPEN_Y.y),
			Rect2(Z_BACK, OPEN_Y.x, -OPEN_Z - Z_BACK, OPEN_Y.y - OPEN_Y.x),
			Rect2(OPEN_Z, OPEN_Y.x, Z_FRONT - OPEN_Z, OPEN_Y.y - OPEN_Y.x)]:
		var rect: Rect2 = r
		var c := Vector3(0, rect.get_center().y, rect.get_center().x)
		MK.box(body, "Core", Vector3(HALF_T * 2.0 - 0.002, rect.size.y, rect.size.x), c + Vector3(-s * 0.001, 0, 0), inside)
		MK.box(body, "Exterior", Vector3(0.002, rect.size.y, rect.size.x), c + Vector3(s * (HALF_T - 0.001), 0, 0), outside)

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
