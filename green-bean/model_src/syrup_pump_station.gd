extends RefCounted

## Syrup station: a 750 ml round glass syrup bottle (7.2 cm across, 27 cm to the
## neck) with a dosing pump whose spout reaches 9.5 cm forward over a small
## steel drip tray where the cup stands. Plain paper label with the flavour name.
## Origin: base on the counter. The barista is on +Z.
## Read by syrup_station.gd: PumpHead (pushed down while pumping), Syrup (liquid,
## tinted per flavour), PumpHead/SpoutTip (where syrup leaves the spout),
## NameLabel (Label3D, set per flavour), PumpTag/Text (Label3D, the pumps per cup
## size, written from DrinkData), CupSpot (tray top under the spout), CameraView.
## Colliders are in scenes/stations/syrup.tscn.

const MK := preload("res://model_src/model_kit.gd")

const BOTTLE_Z := -0.045
const BOTTLE_R := 0.036
const BODY_TOP := 0.2
const NECK_TOP := 0.27
const PUMP_REST_Y := 0.29
const SPOUT_REACH := 0.095
const TRAY := Vector3(0.1, 0.012, 0.12)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "SyrupPumpStation"
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.75, 0.86, 0.8, 0.5)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	var c := Vector3(0, 0, BOTTLE_Z)
	var profile := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(BOTTLE_R - 0.004, 0.0), Vector2(BOTTLE_R, 0.005),
		Vector2(BOTTLE_R, BODY_TOP), Vector2(0.022, BODY_TOP + 0.035), Vector2(0.014, BODY_TOP + 0.05),
		Vector2(0.014, NECK_TOP),
	])
	MK.lathe(root, "Bottle", profile, c, glass, 28)
	MK.cyl(root, "Syrup", BOTTLE_R - 0.003, BOTTLE_R - 0.003, 0.16, c + Vector3(0, 0.084, 0), MK.mat(Color(0.85, 0.65, 0.3), 0.0, 0.25), 24)

	var paper: Material = MK.mat(Color(0.96, 0.94, 0.88), 0.0, 0.9)
	MK.cyl(root, "Label", BOTTLE_R + 0.0008, BOTTLE_R + 0.0008, 0.08, c + Vector3(0, 0.11, 0), paper, 28)
	var name_label := Label3D.new()
	name_label.name = "NameLabel"
	name_label.text = "Syrup"
	name_label.font_size = 48
	name_label.pixel_size = 0.0004
	name_label.outline_size = 0
	name_label.modulate = Color(0.25, 0.2, 0.15)
	name_label.position = c + Vector3(0, 0.11, BOTTLE_R + 0.0015)
	root.add_child(name_label)

	var black: Material = MK.mat(Color(0.12, 0.12, 0.13), 0.0, 0.5)
	MK.cyl(root, "PumpCollar", 0.02, 0.02, 0.022, c + Vector3(0, NECK_TOP + 0.009, 0), black, 18)
	var head := MK.group(root, "PumpHead")
	head.position = c + Vector3(0, PUMP_REST_Y, 0)
	MK.cyl(head, "Stem", 0.006, 0.006, 0.03, Vector3(0, -0.005, 0), MK.mat(Color(0.85, 0.85, 0.85), 0.0, 0.4), 10)
	MK.cyl(head, "Cap", 0.02, 0.018, 0.018, Vector3(0, 0.019, 0), black, 18)
	MK.box(head, "Spout", Vector3(0.012, 0.01, SPOUT_REACH), Vector3(0, 0.022, SPOUT_REACH * 0.5), black)
	MK.cyl(head, "Tip", 0.005, 0.004, 0.016, Vector3(0, 0.012, SPOUT_REACH - 0.003), black, 10)
	MK.marker(head, "SpoutTip", Vector3(0, 0.004, SPOUT_REACH - 0.003))
	_build_tag(root, c)

	var steel: Material = MK.mat(Color(0.7, 0.71, 0.73), 0.7, 0.35)
	var tray_z := BOTTLE_Z + SPOUT_REACH
	MK.box(root, "DripTray", Vector3(TRAY.x, TRAY.y * 0.6, TRAY.z), Vector3(0, TRAY.y * 0.3, tray_z), steel)
	for i in range(5):
		MK.box(root, "Grate", Vector3(TRAY.x - 0.008, 0.004, 0.006), Vector3(0, TRAY.y - 0.002, tray_z - TRAY.z * 0.4 + float(i) * TRAY.z * 0.2), steel)
	MK.marker(root, "CupSpot", Vector3(0, TRAY.y, tray_z))
	var cam_pos := Vector3(0.06, 0.36, 0.36)
	var e := Basis.looking_at(Vector3(0.0, 0.2, 0.02) - cam_pos).get_euler()
	MK.marker(root, "CameraView", cam_pos, Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)))
	return root

## Card tag on a loop of cord round the neck, listing pumps per cup size.
static func _build_tag(root: Node3D, c: Vector3) -> void:
	var tag := MK.group(root, "PumpTag")
	tag.position = c + Vector3(0.0, BODY_TOP + 0.022, BOTTLE_R + 0.004)
	tag.rotation_degrees = Vector3(-30, 0, 0)
	var cord: Material = MK.mat(Color(0.75, 0.7, 0.6), 0.0, 0.9)
	var loop_c := c + Vector3(0, BODY_TOP + 0.048, 0)
	MK.torus(root, "TagCord", 0.0145, 0.0158, loop_c, cord, Vector3(0, 0, 0), 20)
	# Cord from the loop down to the card's top edge.
	var card_top := tag.position + tag.basis * Vector3(0, 0.015, 0)
	var from := loop_c + Vector3(0, 0, 0.015)
	var run := card_top - from
	var strand := MK.box(root, "TagString", Vector3(0.0012, run.length(), 0.0012), (from + card_top) * 0.5, cord)
	strand.rotation.x = atan2(run.z, run.y)
	MK.box(tag, "Card", Vector3(0.05, 0.03, 0.0008), Vector3.ZERO, MK.mat(Color(0.97, 0.95, 0.88), 0.0, 0.8))
	MK.box(tag, "Edge", Vector3(0.052, 0.032, 0.0006), Vector3(0, 0, -0.0005), MK.mat(Color(0.37, 0.41, 0.24), 0.0, 0.8))
	var t := Label3D.new()
	t.name = "Text"
	t.text = "PUMPS"
	t.font_size = 32
	t.pixel_size = 0.00022
	t.outline_size = 0
	t.line_spacing = -4
	t.modulate = Color(0.2, 0.17, 0.14)
	t.position = Vector3(0, 0, 0.0006)
	tag.add_child(t)
