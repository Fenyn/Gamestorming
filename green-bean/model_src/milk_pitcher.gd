extends RefCounted

## 12 oz steaming pitcher: 7.5 cm base, 9.5 cm tall. Origin: centre (base at
## y = -0.0475). Spout -Z, handle +Z.
##
## Read by pitcher.gd: Collision (moved onto the item), MilkFloor, root metadata
## "inner_profile" (inside wall as (radius, y), low to high) so the milk narrows
## with the wall, "milk_height" (a fresh fill) and "foam_rise" (how much higher
## fully foamed milk stands), and Thermometer/Dial/Needle (turned about its Z to
## the milk temperature; metadata "deg_per_c", "zero_deg").
## Etched lines inside mark the milk height for latte and cappuccino foam.

const MK := preload("res://model_src/model_kit.gd")

const BASE_Y := -0.0475
const RIM_Y := 0.0475
const FLOOR_Y := -0.043
const STEEL := Color(0.8, 0.81, 0.83)
## Fresh milk depth and foam's extra height at foam 1; matches the etched lines.
const MILK_HEIGHT := 0.04
const FOAM_RISE := 0.6
## Foam targets from DrinkData.FOAM_TARGETS, etched as lines with their names.
const FOAM_LINES := [["LATTE", 0.35], ["CAP", 0.75]]
## Thermometer dial: 0 to 100 C across 270 degrees, target band and scald zone.
const DIAL_ZERO_DEG := -135.0
const DIAL_DEG_PER_C := 2.7
const TARGET_BAND := Vector2(60.0, 66.0)
const SCALD_FROM := 72.0

const OUTER := [
	Vector2(0.0, BASE_Y), Vector2(0.033, BASE_Y), Vector2(0.037, BASE_Y + 0.0025),
	Vector2(0.0385, -0.035), Vector2(0.039, -0.02), Vector2(0.0375, 0.0),
	Vector2(0.034, 0.02), Vector2(0.0315, 0.033), Vector2(0.0315, 0.041),
	Vector2(0.033, RIM_Y),
]
## Inside wall, rim to floor. Wall is about 1.5 mm thick.
const INNER := [
	Vector2(0.0315, RIM_Y), Vector2(0.030, 0.041), Vector2(0.030, 0.033),
	Vector2(0.0325, 0.02), Vector2(0.036, 0.0), Vector2(0.0375, -0.02),
	Vector2(0.037, -0.035), Vector2(0.034, FLOOR_Y + 0.002), Vector2(0.0, FLOOR_Y),
]

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "MilkPitcher"
	var steel: StandardMaterial3D = MK.mat(STEEL, 0.75, 0.28)

	var profile := PackedVector2Array()
	for p in OUTER:
		profile.append(p)
	for p in INNER:
		profile.append(p)
	MK.lathe(root, "Body", profile, Vector3.ZERO, steel, 28, _spout)

	_build_handle(root, steel)
	_build_lines(root)
	_build_thermometer(root)

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := CylinderShape3D.new()
	shape.radius = 0.039
	shape.height = RIM_Y - BASE_Y
	col.shape = shape
	root.add_child(col)

	var floor_marker := Marker3D.new()
	floor_marker.name = "MilkFloor"
	floor_marker.position = Vector3(0, FLOOR_Y, 0)
	root.add_child(floor_marker)

	# INNER reversed, without the floor centre point.
	var inner_profile := PackedVector2Array()
	for i in range(INNER.size() - 2, -1, -1):
		inner_profile.append(INNER[i])
	root.set_meta("inner_profile", inner_profile)
	root.set_meta("milk_height", MILK_HEIGHT)
	root.set_meta("foam_rise", FOAM_RISE)
	return root

static func _inner_r(y: float) -> float:
	for i in range(INNER.size() - 2):
		var a: Vector2 = INNER[i]
		var b: Vector2 = INNER[i + 1]
		if y <= a.y and y >= b.y:
			return lerpf(b.x, a.x, (y - b.y) / maxf(a.y - b.y, 0.0001))
	return 0.034

## Etched rings on the inside wall where milk stands at each drink's foam.
static func _build_lines(root: Node3D) -> void:
	var lines := MK.group(root, "FoamLines")
	var etch: Material = MK.mat(STEEL.darkened(0.45), 0.6, 0.5)
	for line in FOAM_LINES:
		var y := FLOOR_Y + MILK_HEIGHT * (1.0 + float(line[1]) * FOAM_RISE)
		var r := _inner_r(y)
		MK.torus(lines, "Line", r - 0.0004, r + 0.0002, Vector3(0, y, 0), etch, Vector3.ZERO, 32)
		var l := Label3D.new()
		l.name = "Name"
		l.text = str(line[0])
		l.font_size = 24
		l.pixel_size = 0.00013
		l.outline_size = 0
		l.modulate = STEEL.darkened(0.5)
		l.position = Vector3(0, y + 0.0025, -r + 0.0006)
		lines.add_child(l)

## Clip-on dial thermometer on the right of the rim, dial tilted to the barista.
static func _build_thermometer(root: Node3D) -> void:
	var thermo := MK.group(root, "Thermometer")
	var x := 0.026
	var steel: Material = MK.mat(Color(0.75, 0.76, 0.78), 0.7, 0.3)
	MK.box(thermo, "Clip", Vector3(0.006, 0.012, 0.004), Vector3(0.031, RIM_Y - 0.003, 0), steel)
	MK.box(thermo, "ClipTop", Vector3(0.008, 0.002, 0.004), Vector3(0.0295, RIM_Y + 0.003, 0), steel)
	var stem_top := RIM_Y + 0.018
	var stem_bottom := FLOOR_Y + 0.008
	MK.cyl(thermo, "Stem", 0.0016, 0.0016, stem_top - stem_bottom, Vector3(x, (stem_top + stem_bottom) * 0.5, 0), steel, 8)
	var dial := MK.group(thermo, "Dial")
	dial.position = Vector3(x, stem_top + 0.016, 0.003)
	dial.rotation_degrees = Vector3(-30, 0, 0)
	MK.cyl(dial, "Case", 0.017, 0.017, 0.008, Vector3.ZERO, steel, 24, Vector3(90, 0, 0))
	MK.cyl(dial, "Face", 0.0152, 0.0152, 0.0005, Vector3(0, 0, 0.0042), MK.mat(Color(0.97, 0.97, 0.95), 0.0, 0.5), 24, Vector3(90, 0, 0))
	var black: Material = MK.mat(Color(0.1, 0.1, 0.1), 0.0, 0.5)
	var green: Material = MK.mat(Color(0.2, 0.65, 0.3), 0.0, 0.5)
	var red: Material = MK.mat(Color(0.85, 0.2, 0.15), 0.0, 0.5)
	for c in range(0, 101, 2):
		var a := deg_to_rad(DIAL_ZERO_DEG + DIAL_DEG_PER_C * float(c))
		var dir := Vector3(sin(a), cos(a), 0)
		var in_band := float(c) >= TARGET_BAND.x and float(c) <= TARGET_BAND.y
		var hot := float(c) >= SCALD_FROM
		if in_band or hot:
			var seg := MK.box(dial, "Band", Vector3(0.0024, 0.003, 0.0004), Vector3(0, 0, 0.0047) + dir * 0.0128, green if in_band else red)
			seg.rotation.z = -a
		if c % 10 == 0:
			var tick := MK.box(dial, "Tick", Vector3(0.0006, 0.0028, 0.0004), Vector3(0, 0, 0.0049) + dir * 0.0128, black)
			tick.rotation.z = -a
	var needle := Node3D.new()
	needle.name = "Needle"
	needle.position = Vector3(0, 0, 0.0052)
	dial.add_child(needle)
	MK.box(needle, "Pointer", Vector3(0.0009, 0.012, 0.0004), Vector3(0, 0.005, 0), MK.mat(Color(0.8, 0.12, 0.1), 0.0, 0.5))
	MK.cyl(needle, "Hub", 0.0016, 0.0016, 0.001, Vector3.ZERO, black, 10, Vector3(90, 0, 0))
	MK.cyl(dial, "Lens", 0.0155, 0.0155, 0.0006, Vector3(0, 0, 0.0062), _lens(), 24, Vector3(90, 0, 0))
	needle.set_meta("deg_per_c", DIAL_DEG_PER_C)
	needle.set_meta("zero_deg", DIAL_ZERO_DEG)

static func _lens() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.95, 1.0, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.02
	return m

## Pulls the top of the wall out and up toward -Z into a pointed spout.
static func _spout(v: Vector3, angle: float) -> Vector3:
	var t := clampf((v.y - 0.025) / (RIM_Y - 0.025), 0.0, 1.0)
	if t <= 0.0:
		return v
	var facing := maxf(0.0, -cos(angle))
	var w := pow(facing, 5.0) * t * t
	return v + Vector3(0, w * 0.006, -w * 0.016)

static func _build_handle(root: Node3D, steel: Material) -> void:
	var handle := MK.group(root, "Handle")
	var path := PackedVector3Array([
		Vector3(0, 0.035, 0.029), Vector3(0, 0.037, 0.043), Vector3(0, 0.035, 0.054),
		Vector3(0, 0.028, 0.061), Vector3(0, 0.016, 0.063), Vector3(0, 0.0, 0.061),
		Vector3(0, -0.013, 0.056), Vector3(0, -0.022, 0.049), Vector3(0, -0.027, 0.041),
		Vector3(0, -0.028, 0.036),
	])
	MK.sweep(handle, "Grip", path, 0.0055, 0.003, steel)
	MK.box(handle, "ThumbRest", Vector3(0.013, 0.002, 0.011), Vector3(0, 0.0395, 0.046), steel)
