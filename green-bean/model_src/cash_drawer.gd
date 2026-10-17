extends RefCounted

## Compact cash drawer, 30 x 9 x 20 cm, mounted under the front counter's lip on
## two brackets (the counter is too shallow to stand it on). The drawer opens
## toward the barista (-Z) and holds a bill and coin tray.
## Origin: box centre; the back (+Z) touches the counter face.
##
## Read by cash_drawer.gd: Drawer (slid to DrawerOpen while making change).

const MK := preload("res://model_src/model_kit.gd")

const SIZE := Vector3(0.3, 0.09, 0.2)
const OPEN_TRAVEL := 0.13

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

	var drawer := Node3D.new()
	drawer.name = "Drawer"
	root.add_child(drawer)
	var inner := SIZE - Vector3(0.012, 0.014, 0.01)
	MK.box(drawer, "Front", Vector3(SIZE.x - 0.004, SIZE.y - 0.006, 0.006), Vector3(0, 0, -SIZE.z * 0.5 + 0.003), black)
	MK.box(drawer, "Pull", Vector3(0.08, 0.008, 0.006), Vector3(0, -0.02, -SIZE.z * 0.5 - 0.002), MK.mat(Color(0.6, 0.6, 0.62), 0.7, 0.3))
	MK.cyl(drawer, "Lock", 0.006, 0.006, 0.004, Vector3(0.11, 0.015, -SIZE.z * 0.5 - 0.0005), MK.mat(Color(0.7, 0.6, 0.3), 0.7, 0.3), 12, Vector3(90, 0, 0))
	MK.box(drawer, "Tray", Vector3(inner.x, 0.004, inner.z), Vector3(0, -h + 0.008, 0.0), MK.mat(Color(0.2, 0.2, 0.22), 0.1, 0.6))
	# Bill slots at the back of the tray, coin cups at the front.
	var bill_colors := [Color(0.55, 0.68, 0.5), Color(0.6, 0.7, 0.55), Color(0.5, 0.64, 0.47), Color(0.57, 0.69, 0.52)]
	for i in range(4):
		var x := -0.105 + float(i) * 0.07
		MK.box(drawer, "BillDivider", Vector3(0.003, 0.03, 0.1), Vector3(x - 0.035, -h + 0.025, 0.035), black)
		MK.box(drawer, "Bills", Vector3(0.062, 0.012, 0.09), Vector3(x, -h + 0.017, 0.035), MK.mat(bill_colors[i], 0.0, 0.9))
	var coin_colors := [Color(0.75, 0.75, 0.78), Color(0.75, 0.75, 0.78), Color(0.72, 0.72, 0.75), Color(0.7, 0.5, 0.35), Color(0.75, 0.75, 0.78)]
	for i in range(5):
		var x := -0.116 + float(i) * 0.058
		MK.cyl(drawer, "CoinCup", 0.024, 0.022, 0.018, Vector3(x, -h + 0.019, -0.055), black, 16)
		MK.cyl(drawer, "Coins", 0.019, 0.019, 0.008, Vector3(x, -h + 0.02, -0.055), MK.mat(coin_colors[i], 0.7, 0.35), 16)
	MK.marker(root, "DrawerOpen", Vector3(0, 0, -OPEN_TRAVEL))
	return root
