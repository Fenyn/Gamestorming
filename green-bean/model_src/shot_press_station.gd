extends RefCounted

## Shot press brew spot: silicone mat where the cup stands (the press sits on the
## cup), a wooden stand that holds the spare press upright, a dish of filters and
## a digital brew timer. Origin: mat underside, on the counter at y = 0. Front
## faces +Z.
##
## Read by shot_press_station.gd: CupSpot, DeviceRest, CameraView (pour and stir),
## PressView (looks down on the plunger's level), BrewTimer/Display (Label3D).
## Colliders are in scenes/stations/shot_press.tscn.

const MK := preload("res://model_src/model_kit.gd")

const MAT_SIZE := Vector3(0.3, 0.005, 0.2)
const CUP_SPOT := Vector3(-0.045, MAT_SIZE.y, 0.02)
const STAND_CENTER := Vector3(0.09, 0.0, -0.02)
const STAND_SIZE := Vector3(0.095, 0.022, 0.095)
const DEVICE_REST := Vector3(STAND_CENTER.x, MAT_SIZE.y + STAND_SIZE.y - 0.006, STAND_CENTER.z)
const CAMERA_POS := Vector3(0.04, 0.4, 0.33)
const CAMERA_LOOK_AT := Vector3(0.0, 0.16, 0.0)
const PRESS_CAMERA_POS := Vector3(-0.02, 0.56, 0.23)
const PRESS_LOOK_AT := Vector3(-0.035, 0.265, 0.03)
const TIMER_SPOT := Vector3(0.105, MAT_SIZE.y, 0.07)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "ShotPressStation"
	_build_mat(root)
	_build_stand(root)
	_build_filters(root)
	_build_timer(root)

	MK.marker(root, "CupSpot", CUP_SPOT)
	MK.marker(root, "DeviceRest", DEVICE_REST)
	_view(root, "CameraView", CAMERA_POS, CAMERA_LOOK_AT)
	_view(root, "PressView", PRESS_CAMERA_POS, PRESS_LOOK_AT)
	return root

static func _view(root: Node3D, name: String, pos: Vector3, look: Vector3) -> void:
	var e := Basis.looking_at(look - pos).get_euler()
	MK.marker(root, name, pos, Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)))

## Kitchen brew timer, face tilted back toward the barista. The station writes
## the countdown into Display.
static func _build_timer(root: Node3D) -> void:
	var timer := MK.group(root, "BrewTimer")
	timer.position = TIMER_SPOT
	var body := MK.group(timer, "Body")
	body.rotation_degrees = Vector3(-25, 0, 0)
	body.position.y = 0.0045
	var shell: Material = MK.mat(Color(0.93, 0.92, 0.88), 0.0, 0.45)
	MK.rounded_box(body, "Shell", Vector3(0.058, 0.038, 0.02), Vector3(0, 0.019, 0), 0.008, shell)
	MK.box(body, "Screen", Vector3(0.044, 0.02, 0.001), Vector3(0, 0.022, 0.0102), MK.mat(Color(0.62, 0.68, 0.58), 0.0, 0.3))
	var d := Label3D.new()
	d.name = "Display"
	d.text = "0:00"
	d.font_size = 64
	d.pixel_size = 0.00024
	d.outline_size = 0
	d.modulate = Color(0.12, 0.14, 0.12)
	d.position = Vector3(0, 0.022, 0.011)
	body.add_child(d)
	for x in [-0.014, 0.014]:
		MK.cyl(body, "Button", 0.004, 0.004, 0.003, Vector3(x, 0.039, 0), MK.mat(Color(0.82, 0.3, 0.22), 0.0, 0.5), 12)
	# Fold-out foot behind keeps it standing at the tilt.
	MK.box(timer, "Foot", Vector3(0.04, 0.003, 0.02), Vector3(0, 0.0015, -0.006), MK.mat(Color(0.75, 0.74, 0.7), 0.0, 0.5))

static func _build_mat(root: Node3D) -> void:
	var mat_group := MK.group(root, "BrewMat")
	var silicone: Material = MK.mat(Color(0.2, 0.21, 0.22), 0.0, 0.95)
	MK.rounded_box(mat_group, "Mat", MAT_SIZE, Vector3(0, MAT_SIZE.y * 0.5, 0), 0.02, silicone)
	var ring: Material = MK.mat(Color(0.27, 0.28, 0.29), 0.0, 0.9)
	for i in range(3):
		var r := 0.02 + float(i) * 0.016
		MK.torus(mat_group, "DripRing", r - 0.002, r + 0.002, CUP_SPOT + Vector3(0, 0.0005, 0), ring)

static func _build_stand(root: Node3D) -> void:
	var stand := MK.group(root, "Stand")
	var wood: Material = MK.mat(MK.WOOD_DARK, 0.0, 0.7)
	var wood_dark: Material = MK.mat(MK.WOOD_DARKER, 0.0, 0.75)
	var base_center := STAND_CENTER + Vector3(0, MAT_SIZE.y + STAND_SIZE.y * 0.5, 0)
	MK.rounded_box(stand, "Base", STAND_SIZE, base_center, 0.01, wood)
	MK.cyl(stand, "Cradle", 0.038, 0.038, 0.002, Vector3(STAND_CENTER.x, DEVICE_REST.y + 0.0005, STAND_CENTER.z), wood_dark, 24)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MK.cyl(stand, "Foot", 0.006, 0.006, 0.003, STAND_CENTER + Vector3(float(sx) * 0.035, MAT_SIZE.y + 0.0015, float(sz) * 0.035), MK.mat(Color(0.1, 0.1, 0.1), 0.0, 0.8), 10)

static func _build_filters(root: Node3D) -> void:
	var filters := MK.group(root, "Filters")
	var center := Vector3(-0.115, MAT_SIZE.y, -0.06)
	var holder: Material = MK.mat(MK.WOOD_DARK, 0.0, 0.7)
	MK.cyl(filters, "Dish", 0.04, 0.038, 0.008, center + Vector3(0, 0.004, 0), holder, 24)
	var paper: Material = MK.mat(Color(0.97, 0.96, 0.93), 0.0, 0.9)
	for i in range(6):
		var jitter := Vector3(sin(float(i) * 1.7) * 0.0012, 0, cos(float(i) * 2.3) * 0.0012)
		MK.cyl(filters, "Filter", 0.0335, 0.0335, 0.0008, center + Vector3(0, 0.008 + float(i) * 0.0011, 0) + jitter, paper, 24)
