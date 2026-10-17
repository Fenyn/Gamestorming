extends RefCounted

## Pour-over brew stand: a wooden base with a post and a ring arm that holds
## the cone dripper over the cup, a flat brew scale under the cup, and a
## ceramic saucer where the spare dripper waits.
##
## The ring is high enough for the tallest cup, so the dripper always sits in
## the same place and the cup goes underneath on the scale.
##
## Origin is the middle of the base's underside, so it sits on the counter at
## y = 0. Front faces +Z (the barista).
##
## Nodes the station script uses (move them in the editor and the station follows):
##   CupSpot      Marker3D on top of the scale where the cup stands.
##   RingSeat     Marker3D at the centre of the ring. The dripper hangs in it.
##   DripperRest  Marker3D on the saucer where the spare dripper stands.
##   CameraView   Marker3D for the pour camera, looking down into the dripper.
##
## Colliders live in scenes/stations/pour_over.tscn.

const MK := preload("res://model_src/model_kit.gd")

const STAND_X := -0.03
const BASE_SIZE := Vector3(0.15, 0.018, 0.16)
const SCALE_SIZE := Vector3(0.115, 0.014, 0.115)
## Ring height: the dripper's base clears the top of the extra large cup.
const RING_Y := 0.235
const POST_Z := -0.062
const REST := Vector3(0.092, 0.0, 0.035)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "PourOverStand"
	var wood: Material = MK.mat(MK.WOOD, 0.0, 0.7)
	var wood_dark: Material = MK.mat(MK.WOOD_DARK, 0.0, 0.7)
	var black: Material = MK.mat(Color(0.12, 0.12, 0.13), 0.3, 0.5)

	_build_frame(root, wood, wood_dark, black)
	_build_scale(root, black)
	_build_saucer(root)

	var scale_top := BASE_SIZE.y + SCALE_SIZE.y
	MK.marker(root, "CupSpot", Vector3(STAND_X, scale_top, 0))
	MK.marker(root, "RingSeat", Vector3(STAND_X, RING_Y, 0))
	MK.marker(root, "DripperRest", REST + Vector3(0, 0.008, 0))
	var cam_pos := Vector3(STAND_X + 0.02, RING_Y + 0.3, 0.17)
	var look := Vector3(STAND_X, RING_Y + 0.02, 0)
	var e := Basis.looking_at(look - cam_pos).get_euler()
	MK.marker(root, "CameraView", cam_pos, Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)))
	return root

static func _build_frame(root: Node3D, wood: Material, wood_dark: Material, black: Material) -> void:
	var frame := MK.group(root, "Frame")
	MK.rounded_box(frame, "Base", BASE_SIZE, Vector3(STAND_X, BASE_SIZE.y * 0.5, 0), 0.012, wood)
	var post_h := RING_Y + 0.012 - BASE_SIZE.y
	MK.rounded_box(frame, "Post", Vector3(0.026, post_h, 0.026), Vector3(STAND_X, BASE_SIZE.y + post_h * 0.5, POST_Z), 0.006, wood_dark)
	# Arm from the post out to the ring.
	var arm_len := -POST_Z - 0.04
	MK.box(frame, "Arm", Vector3(0.02, 0.012, arm_len), Vector3(STAND_X, RING_Y, POST_Z + arm_len * 0.5), wood_dark)
	# Black steel ring the dripper drops into.
	MK.torus(frame, "Ring", 0.042, 0.049, Vector3(STAND_X, RING_Y, 0), black)
	MK.cyl(frame, "RingBolt", 0.004, 0.004, 0.016, Vector3(STAND_X, RING_Y, POST_Z + 0.014), black, 10, Vector3(90, 0, 0))

static func _build_scale(root: Node3D, black: Material) -> void:
	var scale := MK.group(root, "BrewScale")
	var c := Vector3(STAND_X, BASE_SIZE.y + SCALE_SIZE.y * 0.5, 0.004)
	MK.rounded_box(scale, "Body", SCALE_SIZE, c, 0.01, black)
	MK.box(scale, "Platform", Vector3(SCALE_SIZE.x - 0.012, 0.002, SCALE_SIZE.z - 0.03), c + Vector3(0, SCALE_SIZE.y * 0.5, -0.008), MK.mat(Color(0.2, 0.2, 0.21), 0.4, 0.35))
	# Front readout: dark window with lit digits, and two buttons.
	var front_z := c.z + SCALE_SIZE.z * 0.5
	MK.box(scale, "Display", Vector3(0.05, 0.008, 0.001), Vector3(STAND_X, c.y, front_z + 0.0005), MK.mat(Color(0.04, 0.05, 0.05), 0.0, 0.2))
	var lcd := StandardMaterial3D.new()
	lcd.albedo_color = Color(0.55, 0.9, 1.0)
	lcd.emission_enabled = true
	lcd.emission = Color(0.4, 0.8, 1.0)
	lcd.emission_energy_multiplier = 1.2
	for i in range(4):
		MK.box(scale, "Digit", Vector3(0.006, 0.0055, 0.0005), Vector3(STAND_X - 0.012 + float(i) * 0.0085, c.y, front_z + 0.0012), lcd)
	for sx in [-1.0, 1.0]:
		MK.cyl(scale, "Button", 0.0035, 0.0035, 0.002, Vector3(STAND_X + float(sx) * 0.038, c.y, front_z + 0.001), MK.mat(Color(0.35, 0.35, 0.37), 0.2, 0.5), 10, Vector3(90, 0, 0))

static func _build_saucer(root: Node3D) -> void:
	var saucer := MK.group(root, "Saucer")
	var ceramic: Material = MK.mat(Color(0.95, 0.94, 0.91), 0.0, 0.25)
	var profile := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.034, 0.0), Vector2(0.036, 0.002), Vector2(0.046, 0.008),
		Vector2(0.048, 0.01), Vector2(0.046, 0.0105), Vector2(0.034, 0.008), Vector2(0.0, 0.008),
	])
	MK.lathe(saucer, "Saucer", profile, REST, ceramic, 28)
