extends RefCounted

## Exterior trim for the stand: green corner boards over the back wall/side wall
## joints, green posts at the side walls' front ends carrying the header beam,
## and wood knee braces under the 1 m front overhang.
## Origin: ground at the stand's centre, so x and z match the shop. Side walls'
## outer faces x +-1.839, back wall outer face z -1.3, service window at z 1.25,
## header beam underside y 2.34, soffit y 2.496.

const MK := preload("res://model_src/model_kit.gd")

const GREEN := Color(0.22, 0.42, 0.28)
const WALL_TOP := 2.5
const HEADER_BOTTOM := 2.34
const SOFFIT_Y := 2.496

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "StandFrame"
	var green: Material = MK.mat(GREEN, 0.0, 0.6)
	var wood: Material = MK.mat(MK.WOOD_DARK, 0.0, 0.7)
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		# Back corner: fills the notch where the back wall stops short of the
		# side wall and stands 1 cm proud of both faces.
		MK.box(root, "CornerBoard", Vector3(0.115, WALL_TOP, 0.12), Vector3(x * 1.7925, WALL_TOP * 0.5, -1.25), green)
		# Front post under the header beam, covering the side wall's end.
		MK.box(root, "FrontPost", Vector3(0.2, HEADER_BOTTOM, 0.13), Vector3(x * 1.75, HEADER_BOTTOM * 0.5, 1.245), green)
		_brace(root, Vector3(x * 1.75, 1.95, 1.31), Vector3(x * 1.75, SOFFIT_Y - 0.02, 1.95), wood)

	return root

## Square timber from a to b, with a block where it meets the soffit.
static func _brace(root: Node3D, a: Vector3, b: Vector3, wood: Material) -> void:
	var up := (b - a).normalized()
	var side := Vector3.RIGHT
	var brace := MK.box(root, "KneeBrace", Vector3(0.07, a.distance_to(b), 0.07), Vector3.ZERO, wood)
	brace.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) * 0.5)
	MK.box(root, "BraceBlock", Vector3(0.09, 0.03, 0.14), Vector3(b.x, SOFFIT_Y - 0.015, b.z), wood)
