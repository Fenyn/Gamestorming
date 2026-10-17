extends RefCounted

## Festoon lights over the seating area: three strands hung between two wood
## poles and the stand's left corner post and back corner board, sagging 25 cm,
## with a warm bulb every 45 cm.
## Origin: shop origin, so the anchor points are shop coordinates. Poles are
## separate props (street_props.gd light_pole) placed at POLE_A and POLE_B.

const MK := preload("res://model_src/model_kit.gd")

const POLE_A := Vector3(-4.85, 2.66, -1.2)
const POLE_B := Vector3(-4.85, 2.66, 3.7)
const STAND_BACK := Vector3(-1.85, 2.3, -1.31)
const STAND_FRONT := Vector3(-1.85, 2.3, 1.31)
const SAG := 0.25
const BULB_STEP := 0.45

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "StringLights"
	var wire: Material = MK.mat(Color(0.12, 0.12, 0.12), 0.0, 0.6)
	var bulb := StandardMaterial3D.new()
	bulb.albedo_color = Color(1.0, 0.86, 0.6)
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.78, 0.45)
	bulb.emission_energy_multiplier = 1.5
	var socket: Material = MK.mat(Color(0.1, 0.1, 0.1), 0.0, 0.6)
	for strand in [[POLE_A, STAND_BACK], [POLE_B, STAND_FRONT], [POLE_A, POLE_B]]:
		_strand(root, strand[0], strand[1], wire, bulb, socket)
	return root

## Catenary-ish wire as a parabola from a to b, with bulbs hanging from it.
static func _strand(root: Node3D, a: Vector3, b: Vector3, wire: Material, bulb: Material, socket: Material) -> void:
	var g := MK.group(root, "Strand")
	var span := a.distance_to(b)
	var segments := maxi(8, int(span / 0.25))
	var path := PackedVector3Array()
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		path.append(a.lerp(b, t) - Vector3(0, SAG * 4.0 * t * (1.0 - t), 0))
	var side := (b - a).cross(Vector3.UP).normalized()
	MK.sweep(g, "Wire", path, 0.004, 0.004, wire, side, 6)
	var n := int(span / BULB_STEP)
	for i in range(1, n):
		var t := float(i) / float(n)
		var p := a.lerp(b, t) - Vector3(0, SAG * 4.0 * t * (1.0 - t), 0)
		MK.cyl(g, "Socket", 0.012, 0.012, 0.03, p - Vector3(0, 0.02, 0), socket, 8)
		MK.sphere(g, "Bulb", 0.028, p - Vector3(0, 0.055, 0), bulb, 1.2, 10)
