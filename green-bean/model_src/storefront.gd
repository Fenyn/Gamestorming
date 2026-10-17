extends RefCounted

## Two-storey shop building for the far side of the street: ground-floor
## shopfront (bulkhead, display glass with a dim interior behind it, a door,
## transom), a lettered sign band, a striped awning, upper-floor windows with
## sills and lintels, a belt course, pilasters at each end, cornice and parapet.
## Only the front is detailed; it is seen from across the road.
## Origin: ground at the centre of the front face; the front faces +Z and the
## building runs 6 m back toward -Z.
## build(width, facade, sign, awning): facade and awning are colours.

const MK := preload("res://model_src/model_kit.gd")

const GROUND_H := 3.6
const UPPER_H := 3.0
const PARAPET := 0.6
const DEPTH := 6.0
const FRAME := Color(0.2, 0.21, 0.22)
const TRIM := Color(0.93, 0.91, 0.86)
const INTERIOR := Color(0.32, 0.25, 0.2)

static func build(width := 7.0, facade := Color(0.62, 0.3, 0.25), sign := "Bakery", awning := Color(0.2, 0.4, 0.3)) -> Node3D:
	var root := Node3D.new()
	root.name = "Storefront"
	var total_h := GROUND_H + UPPER_H + PARAPET
	var wall: Material = MK.mat(facade, 0.0, 0.9)
	var trim: Material = MK.mat(TRIM, 0.0, 0.7)
	var frame: Material = MK.mat(FRAME, 0.3, 0.5)
	MK.box(root, "Body", Vector3(width, total_h, DEPTH), Vector3(0, total_h * 0.5, -DEPTH * 0.5), wall)
	MK.box(root, "Roof", Vector3(width - 0.3, 0.05, DEPTH - 0.3), Vector3(0, total_h - 0.3, -DEPTH * 0.5), MK.mat(Color(0.3, 0.3, 0.31), 0.0, 0.9))

	# Pilasters at each end, belt course, cornice and parapet cap.
	for sx in [-1.0, 1.0]:
		MK.box(root, "Pilaster", Vector3(0.3, total_h, 0.08), Vector3(float(sx) * (width * 0.5 - 0.15), total_h * 0.5, 0.04), MK.mat(facade.darkened(0.15), 0.0, 0.9))
	MK.box(root, "Belt", Vector3(width, 0.12, 0.08), Vector3(0, GROUND_H, 0.04), trim)
	MK.box(root, "Cornice", Vector3(width + 0.1, 0.22, 0.2), Vector3(0, GROUND_H + UPPER_H + 0.05, 0.1), trim)
	MK.box(root, "ParapetCap", Vector3(width + 0.04, 0.06, 0.12), Vector3(0, total_h + 0.03, 0.0), trim)

	_build_shopfront(root, width, frame, wall, facade)
	_build_sign(root, width, sign, facade)
	_build_awning(root, width, awning)
	_build_upper(root, width, trim)
	return root

static func _build_shopfront(root: Node3D, width: float, frame: Material, wall: Material, facade: Color) -> void:
	var front := MK.group(root, "Shopfront")
	var inner := width - 0.9
	var glass_y := Vector2(0.55, 2.65)
	var door_w := 1.0
	var door_x := inner * 0.18
	MK.box(front, "Bulkhead", Vector3(inner, glass_y.x, 0.1), Vector3(0, glass_y.x * 0.5, 0.05), MK.mat(facade.darkened(0.3), 0.0, 0.85))
	# Dim shop interior behind the glass, so the windows read as rooms.
	MK.box(front, "Interior", Vector3(inner, glass_y.y - glass_y.x, 0.05), Vector3(0, (glass_y.x + glass_y.y) * 0.5, -0.6), MK.mat(INTERIOR, 0.0, 0.9))
	for y in [1.2, 1.9]:
		MK.box(front, "Shelf", Vector3(inner * 0.8, 0.04, 0.3), Vector3(-0.3, y, -0.45), MK.mat(INTERIOR.lightened(0.25), 0.0, 0.8))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.65, 0.7, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic = 0.3
	MK.box(front, "Glass", Vector3(inner, glass_y.y - glass_y.x, 0.01), Vector3(0, (glass_y.x + glass_y.y) * 0.5, -0.05), glass)
	# Mullions, the door frame and the transom bar.
	MK.box(front, "Transom", Vector3(inner, 0.08, 0.08), Vector3(0, glass_y.y + 0.04, -0.02), frame)
	MK.box(front, "TransomGlass", Vector3(inner, 0.5, 0.01), Vector3(0, glass_y.y + 0.33, -0.05), glass)
	MK.box(front, "Head", Vector3(inner, 0.08, 0.08), Vector3(0, GROUND_H - 0.45, -0.02), frame)
	for x in [-inner * 0.5, door_x - door_w * 0.5, door_x + door_w * 0.5, inner * 0.5, -inner * 0.15]:
		MK.box(front, "Mullion", Vector3(0.07, GROUND_H - 0.45, 0.08), Vector3(float(x), (GROUND_H - 0.45) * 0.5, -0.02), frame)
	# Door: a glass door in a dark frame, with a push bar.
	MK.box(front, "DoorGap", Vector3(door_w - 0.07, glass_y.x, 0.1), Vector3(door_x, glass_y.x * 0.5, -0.04), MK.mat(INTERIOR, 0.0, 0.9))
	MK.box(front, "DoorRail", Vector3(door_w - 0.07, 0.18, 0.05), Vector3(door_x, 0.09, -0.03), frame)
	MK.box(front, "PushBar", Vector3(door_w * 0.6, 0.04, 0.04), Vector3(door_x, 1.05, 0.0), MK.mat(Color(0.75, 0.76, 0.78), 0.8, 0.3))
	MK.box(front, "Step", Vector3(door_w + 0.2, 0.12, 0.3), Vector3(door_x, 0.06, 0.15), MK.mat(Color(0.6, 0.58, 0.55), 0.0, 0.95))
	var lamp: Material = MK.mat(Color(1.0, 0.9, 0.7), 0.0, 0.4)
	MK.cyl(front, "WallLamp", 0.07, 0.05, 0.18, Vector3(door_x + door_w * 0.5 + 0.35, 2.5, 0.12), MK.mat(FRAME, 0.4, 0.5), 10)
	MK.sphere(front, "WallLampGlow", 0.05, Vector3(door_x + door_w * 0.5 + 0.35, 2.4, 0.12), lamp, 1.0, 10)

static func _build_sign(root: Node3D, width: float, text: String, facade: Color) -> void:
	var band := Vector3(width - 1.0, 0.5, 0.08)
	var y := GROUND_H - 0.27
	MK.box(root, "SignBand", band, Vector3(0, y, 0.06), MK.mat(facade.darkened(0.45), 0.0, 0.7))
	var l := Label3D.new()
	l.name = "SignText"
	l.text = text.to_upper()
	l.font_size = 160
	l.pixel_size = 0.0022
	l.outline_size = 0
	l.modulate = TRIM
	l.position = Vector3(0, y, 0.105)
	root.add_child(l)

## Striped fabric awning sloping out 1.1 m over the shop windows, with a valance.
static func _build_awning(root: Node3D, width: float, color: Color) -> void:
	var awning := MK.group(root, "Awning")
	var w := width - 1.2
	var reach := 1.1
	var drop := 0.45
	var top_y := GROUND_H - 0.58
	var slope := atan2(drop, reach)
	var length := Vector2(reach, drop).length()
	var n := maxi(4, int(w / 0.45))
	var stripe_w := w / float(n)
	var light: Material = MK.mat(Color(0.95, 0.93, 0.87), 0.0, 0.9)
	var dark: Material = MK.mat(color, 0.0, 0.9)
	for i in range(n):
		var x := -w * 0.5 + (float(i) + 0.5) * stripe_w
		var stripe := MK.box(awning, "Stripe", Vector3(stripe_w, 0.02, length), Vector3(x, top_y - drop * 0.5, reach * 0.5), light if i % 2 == 0 else dark)
		stripe.rotation = Vector3(slope, 0, 0)
		MK.box(awning, "Valance", Vector3(stripe_w, 0.22, 0.02), Vector3(x, top_y - drop - 0.11, reach), light if i % 2 == 0 else dark)
	var steel: Material = MK.mat(FRAME, 0.4, 0.5)
	for sx in [-1.0, 1.0]:
		var arm := MK.box(awning, "Arm", Vector3(0.03, 0.03, length), Vector3(float(sx) * w * 0.5, top_y - drop * 0.5 - 0.02, reach * 0.5), steel)
		arm.rotation = Vector3(slope, 0, 0)

static func _build_upper(root: Node3D, width: float, trim: Material) -> void:
	var upper := MK.group(root, "Upper")
	var count := maxi(2, int((width - 1.0) / 2.2))
	var span := width - 1.4
	var glass: Material = MK.mat(Color(0.3, 0.38, 0.45), 0.4, 0.15)
	var curtain: Material = MK.mat(Color(0.9, 0.86, 0.76), 0.0, 0.9)
	for i in range(count):
		var x := -span * 0.5 + (float(i) + 0.5) * span / float(count)
		var y := GROUND_H + 1.45
		MK.box(upper, "Frame", Vector3(1.1, 1.5, 0.06), Vector3(x, y, 0.01), trim)
		MK.box(upper, "Pane", Vector3(0.96, 1.36, 0.02), Vector3(x, y, 0.035), glass)
		MK.box(upper, "Curtain", Vector3(0.3, 1.3, 0.01), Vector3(x - 0.32, y, 0.02), curtain)
		MK.box(upper, "Bar", Vector3(0.96, 0.04, 0.03), Vector3(x, y + 0.15, 0.05), trim)
		MK.box(upper, "Sill", Vector3(1.25, 0.06, 0.14), Vector3(x, y - 0.78, 0.07), trim)
		MK.box(upper, "Lintel", Vector3(1.25, 0.12, 0.08), Vector3(x, y + 0.81, 0.04), trim)
