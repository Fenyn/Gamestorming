extends RefCounted

## Flat roof for the walk-up stand: dark membrane deck, olive fascia all round,
## wood plank soffits under the overhangs (1 m over the customers at the front),
## a cream ceiling inside, and a header beam over the open service window.
## Origin: top of the walls at the stand's centre (shop (0, 2.5, 0)), so x and z
## match the shop. Walls' inner faces: x +-1.70, back z -1.2; window at z 1.25.
## The collider is in the shop scene.

const MK := preload("res://model_src/model_kit.gd")

const EAVE := Rect2(-2.1, -1.45, 4.2, 3.67)
const INNER := Rect2(-1.7, -1.2, 3.4, 2.45)
const OUTER_WALL := Rect2(-1.8, -1.3, 3.6, 2.55)
const DECK := 0.1
const FASCIA_H := 0.2
const OLIVE := Color(0.37, 0.41, 0.24)
const MEMBRANE := Color(0.28, 0.29, 0.3)
const CEILING := Color(0.95, 0.93, 0.88)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "StandRoof"
	var olive: Material = MK.mat(OLIVE, 0.0, 0.6)
	MK.box(root, "Deck", Vector3(EAVE.size.x, DECK, EAVE.size.y), _at(EAVE, DECK * 0.5), MK.mat(MEMBRANE, 0.0, 0.9))
	MK.box(root, "Ceiling", Vector3(INNER.size.x, 0.012, INNER.size.y), _at(INNER, -0.006), MK.mat(CEILING, 0.0, 0.9))

	# Fascia boards round the deck edge, with a light drip edge on top.
	var fy := DECK - FASCIA_H * 0.5 + 0.02
	var drip: Material = MK.mat(Color(0.85, 0.85, 0.82), 0.4, 0.5)
	for side in [[Vector3(EAVE.size.x + 0.06, FASCIA_H, 0.03), Vector3(EAVE.get_center().x, fy, EAVE.end.y + 0.015)],
			[Vector3(EAVE.size.x + 0.06, FASCIA_H, 0.03), Vector3(EAVE.get_center().x, fy, EAVE.position.y - 0.015)],
			[Vector3(0.03, FASCIA_H, EAVE.size.y), Vector3(EAVE.end.x + 0.015, fy, EAVE.get_center().y)],
			[Vector3(0.03, FASCIA_H, EAVE.size.y), Vector3(EAVE.position.x - 0.015, fy, EAVE.get_center().y)]]:
		MK.box(root, "Fascia", side[0], side[1], olive)
		MK.box(root, "DripEdge", Vector3(side[0].x + 0.01, 0.012, side[0].z + 0.01), side[1] + Vector3(0, FASCIA_H * 0.5 + 0.006, 0), drip)

	_build_soffits(root)

	# Header beam across the service window, under the ceiling line.
	MK.box(root, "Header", Vector3(INNER.size.x + 0.36, 0.16, 0.12), Vector3(0, -0.08, INNER.end.y), olive)
	return root

## Planks run across each overhang, outside the walls only.
static func _build_soffits(root: Node3D) -> void:
	var soffit := MK.group(root, "Soffit")
	var wood: Material = MK.mat(MK.WOOD, 0.0, 0.75)
	var gap: Material = MK.mat(MK.WOOD_DARKER, 0.0, 0.8)
	var y := -0.004
	# Front overhang: planks along X, stepping toward the street.
	_plank_field(soffit, Rect2(EAVE.position.x, OUTER_WALL.end.y, EAVE.size.x, EAVE.end.y - OUTER_WALL.end.y), true, y, wood, gap)
	_plank_field(soffit, Rect2(EAVE.position.x, EAVE.position.y, EAVE.size.x, OUTER_WALL.position.y - EAVE.position.y), true, y, wood, gap)
	_plank_field(soffit, Rect2(OUTER_WALL.end.x, OUTER_WALL.position.y, EAVE.end.x - OUTER_WALL.end.x, OUTER_WALL.size.y), false, y, wood, gap)
	_plank_field(soffit, Rect2(EAVE.position.x, OUTER_WALL.position.y, OUTER_WALL.position.x - EAVE.position.x, OUTER_WALL.size.y), false, y, wood, gap)

static func _plank_field(parent: Node3D, area: Rect2, along_x: bool, y: float, wood: Material, gap: Material) -> void:
	MK.box(parent, "Backing", Vector3(area.size.x, 0.006, area.size.y), Vector3(area.get_center().x, y + 0.001, area.get_center().y), gap)
	var pitch := 0.1
	var span := area.size.y if along_x else area.size.x
	var n := maxi(1, int(round(span / pitch)))
	var w := span / float(n)
	for i in range(n):
		var c := (float(i) + 0.5) * w
		if along_x:
			MK.box(parent, "Plank", Vector3(area.size.x, 0.008, w - 0.008), Vector3(area.get_center().x, y - 0.004, area.position.y + c), wood)
		else:
			MK.box(parent, "Plank", Vector3(w - 0.008, 0.008, area.size.y), Vector3(area.position.x + c, y - 0.004, area.get_center().y), wood)

static func _at(r: Rect2, y: float) -> Vector3:
	return Vector3(r.get_center().x, y, r.get_center().y)
