extends RefCounted

## Ground surfaces in front of and beside the stand: a warm paver patio where
## customers queue and pick up (to the sidewalk), a paver seating area along the
## stand's left side, a darker edging course round both, and a 2.8 m concrete
## sidewalk with control joints every 1.5 m.
## Origin: shop origin; everything sits on the ground (y 0 to 0.02). No collider:
## the shop's Floor is the walking surface.

const MK := preload("res://model_src/model_kit.gd")

const TOP := 0.02
## Patio in front of the service window, and the seating area on the left side.
const PATIO := Rect2(-5.0, 1.25, 10.2, 2.65)
const SEATING := Rect2(-5.0, -1.45, 3.16, 2.7)
const SIDEWALK := Rect2(-20.0, 3.9, 40.0, 2.8)
const PAVER := 0.6
const JOINT := 0.012

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "SitePaving"
	var paver: Material = MK.mat(Color(0.74, 0.62, 0.52), 0.0, 0.95)
	var paver_joint: Material = MK.mat(Color(0.56, 0.47, 0.4), 0.0, 1.0)
	var edging: Material = MK.mat(Color(0.5, 0.4, 0.34), 0.0, 0.95)
	var concrete: Material = MK.mat(Color(0.74, 0.71, 0.66), 0.0, 0.95)
	var concrete_joint: Material = MK.mat(Color(0.6, 0.58, 0.54), 0.0, 1.0)

	var patio := MK.group(root, "Patio")
	for r in [PATIO, SEATING]:
		var area: Rect2 = r
		_slab(patio, "Pavers", area, paver)
		_grid(patio, area, PAVER, PAVER, paver_joint)
		_edging(patio, area, edging)

	var walk := MK.group(root, "Sidewalk")
	_slab(walk, "Concrete", SIDEWALK, concrete)
	_grid(walk, SIDEWALK, 1.5, 0.0, concrete_joint)
	return root

static func _slab(parent: Node3D, name: String, area: Rect2, mat: Material) -> void:
	MK.box(parent, name, Vector3(area.size.x, TOP, area.size.y), Vector3(area.get_center().x, TOP * 0.5, area.get_center().y), mat)

## Joint lines across the area every step_x along X and step_z along Z (0 = none).
static func _grid(parent: Node3D, area: Rect2, step_x: float, step_z: float, mat: Material) -> void:
	var y := TOP + 0.0006
	var x := area.position.x + step_x
	while x < area.end.x - 0.05:
		MK.box(parent, "Joint", Vector3(JOINT, 0.001, area.size.y), Vector3(x, y, area.get_center().y), mat)
		x += step_x
	if step_z <= 0.0:
		return
	var z := area.position.y + step_z
	while z < area.end.y - 0.05:
		MK.box(parent, "Joint", Vector3(area.size.x, 0.001, JOINT), Vector3(area.get_center().x, y, z), mat)
		z += step_z

static func _edging(parent: Node3D, area: Rect2, mat: Material) -> void:
	var w := 0.12
	var y := TOP * 0.5 + 0.001
	MK.box(parent, "Edging", Vector3(area.size.x, TOP + 0.002, w), Vector3(area.get_center().x, y, area.position.y + w * 0.5), mat)
	MK.box(parent, "Edging", Vector3(area.size.x, TOP + 0.002, w), Vector3(area.get_center().x, y, area.end.y - w * 0.5), mat)
	MK.box(parent, "Edging", Vector3(w, TOP + 0.002, area.size.y), Vector3(area.position.x + w * 0.5, y, area.get_center().y), mat)
	MK.box(parent, "Edging", Vector3(w, TOP + 0.002, area.size.y), Vector3(area.end.x - w * 0.5, y, area.get_center().y), mat)
