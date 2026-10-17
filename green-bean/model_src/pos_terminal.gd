extends RefCounted

## Countertop POS: a touchscreen on a swivel stand, sized to the register's
## screen quad (0.4 x 0.36 m, tilted back 15 degrees), plus a small thermal
## ticket printer beside it. Origin: base underside. The screen faces -Z (the
## barista). The station's ScreenQuad sits on the bezel face at y 0.364.

const MK := preload("res://model_src/model_kit.gd")

const SCREEN_CENTER := Vector3(0, 0.364, 0.003)
const SCREEN_SIZE := Vector2(0.4, 0.362)
const TILT := 15.0

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "PosTerminal"
	var shell: Material = MK.mat(Color(0.14, 0.14, 0.15), 0.2, 0.45)
	var steel: Material = MK.mat(Color(0.72, 0.73, 0.75), 0.7, 0.3)

	MK.rounded_box(root, "Base", Vector3(0.2, 0.014, 0.16), Vector3(0, 0.007, 0.03), 0.02, steel)
	# Post from the base up to a hinge behind the screen.
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(TILT))
	var hinge := SCREEN_CENTER + tilt * Vector3(0, -0.03, 0.04)
	MK.cyl(root, "Post", 0.016, 0.02, hinge.y - 0.014, Vector3(0, (hinge.y + 0.014) * 0.5, hinge.z), steel, 16)
	MK.cyl(root, "Hinge", 0.018, 0.018, 0.05, hinge, steel, 16, Vector3(0, 0, 90))

	# Bezel around the screen quad, and a thicker back shell.
	var bezel := MeshInstance3D.new()
	var bezel_mesh := BoxMesh.new()
	bezel_mesh.size = Vector3(SCREEN_SIZE.x + 0.024, SCREEN_SIZE.y + 0.024, 0.014)
	bezel.mesh = bezel_mesh
	bezel.material_override = shell
	bezel.name = "Bezel"
	bezel.transform = Transform3D(tilt, SCREEN_CENTER + tilt * Vector3(0, 0, 0.0075))
	root.add_child(bezel)
	var back := MeshInstance3D.new()
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(SCREEN_SIZE.x - 0.04, SCREEN_SIZE.y - 0.06, 0.016)
	back.mesh = back_mesh
	back.material_override = shell
	back.name = "BackShell"
	back.transform = Transform3D(tilt, SCREEN_CENTER + tilt * Vector3(0, 0, 0.022))
	root.add_child(back)

	_build_printer(root, Vector3(0.27, 0, 0.0))
	return root

## Thermal ticket printer: dark box, paper slot at the front, a ticket curling out.
static func _build_printer(root: Node3D, at: Vector3) -> void:
	var printer := MK.group(root, "TicketPrinter")
	var body: Material = MK.mat(Color(0.2, 0.2, 0.21), 0.1, 0.5)
	MK.rounded_box(printer, "Body", Vector3(0.11, 0.1, 0.15), at + Vector3(0, 0.05, 0.02), 0.012, body)
	MK.box(printer, "Lid", Vector3(0.1, 0.006, 0.09), at + Vector3(0, 0.103, 0.035), MK.mat(Color(0.16, 0.16, 0.17), 0.1, 0.4))
	MK.box(printer, "Slot", Vector3(0.082, 0.004, 0.006), at + Vector3(0, 0.1, -0.05), MK.mat(Color(0.04, 0.04, 0.04), 0.0, 0.9))
	MK.cyl(printer, "Led", 0.003, 0.003, 0.002, at + Vector3(0.04, 0.07, -0.0555), MK.mat(Color(0.3, 0.9, 0.4), 0.0, 0.3), 8, Vector3(90, 0, 0))
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.98, 0.97, 0.94)
	paper.roughness = 0.9
	paper.cull_mode = BaseMaterial3D.CULL_DISABLED
	var path := PackedVector3Array()
	for k in range(7):
		var t := float(k) / 6.0
		path.append(at + Vector3(0, 0.101 + sin(t * PI * 0.5) * 0.03, -0.05 - t * 0.035))
	MK.sweep(printer, "Ticket", path, 0.038, 0.0004, paper, Vector3.RIGHT, 4)
