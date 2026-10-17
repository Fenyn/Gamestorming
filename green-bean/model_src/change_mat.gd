extends RefCounted

## Rubber change mat on the customer counter, where the barista counts change
## out and the customer's cash is laid down. 26 x 17 cm.
## Origin: underside centre. Customer on +Z, barista on -Z (+X is the barista's
## left).
## Read by cash_drawer.gd: BillSpot (first bill; more fan out toward -X),
## Coin_<key> (one stack per coin), TenderSpot (the customer's bill), and root
## metadata "size" (Vector2 x, z).

const MK := preload("res://model_src/model_kit.gd")

const SIZE := Vector2(0.26, 0.17)
const THICK := 0.004

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "ChangeMat"
	var rubber: Material = MK.mat(Color(0.16, 0.2, 0.17), 0.0, 0.85)
	MK.rounded_box(root, "Mat", Vector3(SIZE.x, THICK, SIZE.y), Vector3(0, THICK * 0.5, 0), 0.012, rubber)
	var lip: Material = MK.mat(Color(0.12, 0.15, 0.13), 0.0, 0.8)
	for sz in [-1.0, 1.0]:
		MK.box(root, "LipX", Vector3(SIZE.x - 0.024, 0.0025, 0.004), Vector3(0, THICK + 0.00125, float(sz) * (SIZE.y * 0.5 - 0.004)), lip)
	for sx in [-1.0, 1.0]:
		MK.box(root, "LipZ", Vector3(0.004, 0.0025, SIZE.y - 0.024), Vector3(float(sx) * (SIZE.x * 0.5 - 0.004), THICK + 0.00125, 0), lip)
	MK.marker(root, "BillSpot", Vector3(0.085, THICK, -0.004))
	var coins := {"c25": Vector2(-0.045, -0.05), "c10": Vector2(-0.09, -0.05), "c5": Vector2(-0.045, -0.005), "c1": Vector2(-0.09, -0.005)}
	for key in coins:
		var c: Vector2 = coins[key]
		MK.marker(root, "Coin_" + key, Vector3(c.x, THICK, c.y))
	MK.marker(root, "TenderSpot", Vector3(-0.06, THICK + 0.001, 0.055), Vector3(0, 82, 0))
	root.set_meta("size", SIZE)
	return root
