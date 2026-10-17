extends RefCounted

## Under-counter cash drawer, 34 x 9 x 30 cm, hung under the front counter's lip
## on two brackets. The drawer opens 24 cm toward the barista (-Z). Back row:
## four bill compartments ($20 $10 $5 $1 from the barista's left) with spring
## clips. Front row: four coin cups (25, 10, 5, 1 cents).
## Origin: housing centre; the back (+Z) touches the counter face.
##
## Read by cash_drawer.gd: Drawer (slid to DrawerOpen), Drawer/Slot_<key> at the
## top of each stack with metadata "half" (compartment half size, Vector2 x, z),
## Drawer/Clip_<key> (bill clip hinges, lifted about +X), and root metadata
## "housing_front_z" (tray behind this is hidden under the housing top).

const MK := preload("res://model_src/model_kit.gd")
const PIECES := preload("res://model_src/cash_pieces.gd")

const SIZE := Vector3(0.34, 0.09, 0.3)
const OPEN_TRAVEL := 0.24
const BILL_KEYS := ["b20", "b10", "b5", "b1"]
const COIN_KEYS := ["c25", "c10", "c5", "c1"]
const COIN_TAGS := ["25¢", "10¢", "5¢", "1¢"]
const PITCH := 0.08
const FLOOR_Y := -0.035
const BILL_Z := 0.035
const COIN_Z := -0.105
const ROW_Z := -0.065

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "CashDrawer"
	var black: Material = MK.mat(Color(0.13, 0.13, 0.14), 0.4, 0.45)
	var h := SIZE.y * 0.5
	# Housing: top, sides, back and floor, open at the front for the drawer.
	MK.box(root, "Top", Vector3(SIZE.x, 0.004, SIZE.z), Vector3(0, h - 0.002, 0), black)
	MK.box(root, "Floor", Vector3(SIZE.x, 0.004, SIZE.z), Vector3(0, -h + 0.002, 0), black)
	for sx in [-1.0, 1.0]:
		MK.box(root, "Side", Vector3(0.004, SIZE.y, SIZE.z), Vector3(float(sx) * (SIZE.x * 0.5 - 0.002), 0, 0), black)
	MK.box(root, "Back", Vector3(SIZE.x, SIZE.y, 0.004), Vector3(0, 0, SIZE.z * 0.5 - 0.002), black)
	var steel: Material = MK.mat(Color(0.6, 0.61, 0.63), 0.6, 0.4)
	for sx in [-1.0, 1.0]:
		MK.box(root, "Bracket", Vector3(0.012, SIZE.y + 0.01, 0.025), Vector3(float(sx) * (SIZE.x * 0.5 + 0.006), 0.005, SIZE.z * 0.5 - 0.0125), steel)
		MK.box(root, "BracketFlange", Vector3(0.03, 0.012, 0.004), Vector3(float(sx) * (SIZE.x * 0.5 + 0.006), 0.04, SIZE.z * 0.5 + 0.002), steel)

	var drawer := MK.group(root, "Drawer")
	var tray_w := SIZE.x - 0.012
	var tray_d := SIZE.z - 0.01
	MK.box(drawer, "Front", Vector3(SIZE.x - 0.004, SIZE.y - 0.006, 0.006), Vector3(0, 0, -SIZE.z * 0.5 + 0.003), black)
	MK.box(drawer, "Pull", Vector3(0.08, 0.008, 0.006), Vector3(0, -0.02, -SIZE.z * 0.5 - 0.002), MK.mat(Color(0.6, 0.6, 0.62), 0.7, 0.3))
	MK.cyl(drawer, "Lock", 0.006, 0.006, 0.004, Vector3(0.13, 0.015, -SIZE.z * 0.5 - 0.0005), MK.mat(Color(0.7, 0.6, 0.3), 0.7, 0.3), 12, Vector3(90, 0, 0))
	var tray: Material = MK.mat(Color(0.2, 0.2, 0.22), 0.1, 0.6)
	MK.box(drawer, "Tray", Vector3(tray_w, 0.006, tray_d), Vector3(0, FLOOR_Y - 0.003, 0.0), tray)
	for sx in [-1.0, 1.0]:
		MK.box(drawer, "TrayWall", Vector3(0.004, 0.035, tray_d), Vector3(float(sx) * (tray_w * 0.5 - 0.002), FLOOR_Y + 0.0175, 0), tray)
	MK.box(drawer, "TrayBack", Vector3(tray_w, 0.035, 0.004), Vector3(0, FLOOR_Y + 0.0175, tray_d * 0.5 - 0.002), tray)
	MK.box(drawer, "RowDivider", Vector3(tray_w, 0.022, 0.004), Vector3(0, FLOOR_Y + 0.011, ROW_Z), tray)
	for i in range(1, 4):
		var x := (2.0 - float(i)) * PITCH
		MK.box(drawer, "BillDivider", Vector3(0.003, 0.03, tray_d * 0.5 + 0.075), Vector3(x, FLOOR_Y + 0.015, (ROW_Z + tray_d * 0.5) * 0.5), tray)
		MK.box(drawer, "CoinDivider", Vector3(0.003, 0.02, 0.075), Vector3(x, FLOOR_Y + 0.01, (ROW_Z - tray_d * 0.5) * 0.5), tray)

	for i in range(4):
		var x := (1.5 - float(i)) * PITCH
		_build_bill_slot(drawer, BILL_KEYS[i], x, steel)
		_build_coin_slot(drawer, COIN_KEYS[i], COIN_TAGS[i], x, i)
	MK.marker(root, "DrawerOpen", Vector3(0, 0, -OPEN_TRAVEL))
	root.set_meta("housing_front_z", -SIZE.z * 0.5)
	return root

## A short stack of bills with the top note printed, under a hinged spring clip.
static func _build_bill_slot(drawer: Node3D, key: String, x: float, steel: Material) -> void:
	var stack_h := 0.01
	MK.box(drawer, "BillStack_" + key, Vector3(PIECES.BILL_SIZE.x - 0.001, stack_h, PIECES.BILL_SIZE.z - 0.001), Vector3(x, FLOOR_Y + stack_h * 0.5, BILL_Z), MK.mat(PIECES.PAPER.darkened(0.12), 0.0, 0.95))
	var top := PIECES.bill(drawer, key)
	top.name = "TopBill_" + key
	top.position = Vector3(x, FLOOR_Y + stack_h, BILL_Z)
	var surface := FLOOR_Y + stack_h + PIECES.BILL_SIZE.y
	var slot := MK.marker(drawer, "Slot_" + key, Vector3(x, surface, BILL_Z))
	slot.set_meta("half", Vector2(0.037, 0.08))

	# Hinge at the back (hidden under the housing), roller resting near the front.
	var clip := Node3D.new()
	clip.name = "Clip_" + key
	clip.position = Vector3(x, surface + 0.004, 0.125)
	drawer.add_child(clip)
	var reach := 0.15
	for sx in [-1.0, 1.0]:
		MK.box(clip, "Arm", Vector3(0.003, 0.003, reach), Vector3(float(sx) * 0.026, 0, -reach * 0.5), steel)
	MK.cyl(clip, "Roller", 0.004, 0.004, 0.058, Vector3(0, 0, -reach), MK.mat(Color(0.15, 0.15, 0.16), 0.0, 0.6), 10, Vector3(0, 0, 90))
	MK.cyl(clip, "Hinge", 0.004, 0.004, 0.058, Vector3.ZERO, steel, 10, Vector3(0, 0, 90))

## A bed of coins with loose ones on top, and the value on the row divider.
static func _build_coin_slot(drawer: Node3D, key: String, tag: String, x: float, seed_i: int) -> void:
	var d: Array = PIECES.COINS[key]
	var bed_h := 0.007
	MK.box(drawer, "CoinBed_" + key, Vector3(0.074, bed_h, 0.07), Vector3(x, FLOOR_Y + bed_h * 0.5, COIN_Z), MK.mat((d[2] as Color).darkened(0.2), d[3], 0.45))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + seed_i
	for k in range(9):
		var c := PIECES.coin(drawer, key)
		c.name = "Loose_%s_%d" % [key, k]
		c.position = Vector3(x + rng.randf_range(-0.025, 0.025), FLOOR_Y + bed_h + rng.randf_range(0.0, 0.002), COIN_Z + rng.randf_range(-0.024, 0.024))
		c.rotation_degrees = Vector3(rng.randf_range(-8, 8), rng.randf_range(0, 360), rng.randf_range(-8, 8))
	var slot := MK.marker(drawer, "Slot_" + key, Vector3(x, FLOOR_Y + bed_h + 0.003, COIN_Z))
	slot.set_meta("half", Vector2(0.037, 0.036))
	var l := Label3D.new()
	l.name = "Tag_" + key
	l.text = tag
	l.font_size = 48
	l.pixel_size = 0.00028
	l.outline_size = 0
	l.modulate = Color(0.85, 0.85, 0.82)
	l.position = Vector3(x, FLOOR_Y + 0.0222, ROW_Z)
	l.rotation_degrees = Vector3(-90, 180, 0)
	drawer.add_child(l)
