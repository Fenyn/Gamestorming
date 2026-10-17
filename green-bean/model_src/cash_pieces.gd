extends RefCounted

## One of each bill and coin the cash drawer hands out, as templates the station
## duplicates. Generic notes (no real currency art): pale paper with a printed
## frame, a medallion, corner numerals and a colour band per value. Coins use
## real diameters and thicknesses.
## Each child is named by key (b20 b10 b5 b1 c25 c10 c5 c1), origin at its
## underside centre. Bills lie flat with the long side along Z and read upright
## from -Z (the barista).

const MK := preload("res://model_src/model_kit.gd")

const BILL_SIZE := Vector3(0.066, 0.0006, 0.156)
const PAPER := Color(0.8, 0.84, 0.76)
const INK := Color(0.3, 0.42, 0.33)
const BILLS := {
	"b20": ["20", Color(0.35, 0.62, 0.52)],
	"b10": ["10", Color(0.86, 0.6, 0.3)],
	"b5": ["5", Color(0.58, 0.46, 0.7)],
	"b1": ["1", Color(0.62, 0.66, 0.6)],
}
## key: [diameter, thickness, colour, metallic]
const COINS := {
	"c25": [0.02426, 0.00175, Color(0.78, 0.79, 0.8), 0.85],
	"c10": [0.01791, 0.00135, Color(0.8, 0.81, 0.82), 0.85],
	"c5": [0.02121, 0.00195, Color(0.68, 0.68, 0.66), 0.75],
	"c1": [0.01905, 0.00152, Color(0.72, 0.45, 0.3), 0.8],
}

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "CashPieces"
	var x := 0.0
	for key in BILLS:
		bill(root, key).position = Vector3(x, 0, 0)
		x += 0.08
	for key in COINS:
		coin(root, key).position = Vector3(x, 0, 0)
		x += 0.04
	return root

static func bill(parent: Node3D, key: String) -> Node3D:
	var node := MK.group(parent, key)
	var label: String = BILLS[key][0]
	var accent: Color = BILLS[key][1]
	var t := BILL_SIZE.y
	MK.box(node, "Paper", BILL_SIZE, Vector3(0, t * 0.5, 0), MK.mat(PAPER, 0.0, 0.95))
	var ink: Material = MK.mat(INK, 0.0, 0.9)
	var top := t + 0.00005
	# Printed frame, then the value band across the middle and the medallion.
	MK.box(node, "Frame", Vector3(BILL_SIZE.x - 0.008, 0.00005, BILL_SIZE.z - 0.008), Vector3(0, top, 0), ink)
	MK.box(node, "Field", Vector3(BILL_SIZE.x - 0.012, 0.00005, BILL_SIZE.z - 0.012), Vector3(0, top + 0.00005, 0), MK.mat(PAPER.lightened(0.08), 0.0, 0.95))
	MK.box(node, "Band", Vector3(BILL_SIZE.x - 0.012, 0.00005, 0.03), Vector3(0, top + 0.0001, 0.032), MK.mat(accent, 0.0, 0.9))
	MK.cyl(node, "Medallion", 0.017, 0.017, 0.00005, Vector3(0, top + 0.0001, -0.018), MK.mat(accent.darkened(0.25), 0.0, 0.9), 20)
	MK.cyl(node, "MedallionInner", 0.013, 0.013, 0.00005, Vector3(0, top + 0.00015, -0.018), MK.mat(PAPER.lightened(0.05), 0.0, 0.95), 20)
	for corner in [Vector2(1, 1), Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1)]:
		_numeral(node, label, Vector3(corner.x * 0.021, top + 0.0002, corner.y * 0.062), 64)
	_numeral(node, label, Vector3(0, top + 0.0002, 0.032), 110)
	return node

static func _numeral(parent: Node3D, text: String, pos: Vector3, size: int) -> void:
	var l := Label3D.new()
	l.name = MK.unique_name(parent, "Numeral")
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0001
	l.outline_size = 0
	l.modulate = INK.darkened(0.3)
	l.double_sided = false
	l.position = pos
	# Face up, text top toward +Z so it reads upright from -Z.
	l.rotation_degrees = Vector3(-90, 180, 0)
	parent.add_child(l)

static func coin(parent: Node3D, key: String) -> Node3D:
	var node := MK.group(parent, key)
	var d: Array = COINS[key]
	var r: float = float(d[0]) * 0.5
	var t: float = d[1]
	var metal: Material = MK.mat(d[2], d[3], 0.35)
	MK.cyl(node, "Disc", r, r, t, Vector3(0, t * 0.5, 0), metal, 20)
	# Raised rim around a slightly sunk face, so coins catch the light at the edge.
	MK.torus(node, "Rim", r - 0.0012, r, Vector3(0, t, 0), MK.mat((d[2] as Color).lightened(0.12), d[3], 0.3), Vector3.ZERO, 20)
	MK.cyl(node, "Relief", r * 0.45, r * 0.45, 0.0002, Vector3(0, t + 0.0001, 0), MK.mat((d[2] as Color).darkened(0.12), d[3], 0.45), 14)
	return node
