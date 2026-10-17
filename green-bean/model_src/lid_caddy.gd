extends RefCounted

## Countertop lid caddy: a black two-slot organiser holding stacks of sip lids,
## 80 mm (small cup) and 90 mm (the rest). Origin: base underside, on the
## counter at y = 0. The open front faces +Z.

const MK := preload("res://model_src/model_kit.gd")

const LID := Color(0.16, 0.13, 0.11)

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "LidCaddy"
	var body: Material = MK.mat(Color(0.12, 0.12, 0.13), 0.1, 0.5)
	var lid: Material = MK.mat(LID, 0.0, 0.35)
	var w := 0.23
	var d := 0.11
	var h := 0.11
	MK.rounded_box(root, "Base", Vector3(w, 0.01, d), Vector3(0, 0.005, 0), 0.008, body)
	MK.box(root, "Back", Vector3(w, h, 0.006), Vector3(0, h * 0.5, -d * 0.5 + 0.003), body)
	for sx in [-1.0, 0.0, 1.0]:
		MK.box(root, "Divider", Vector3(0.006, h * (0.6 if sx == 0.0 else 1.0), d), Vector3(float(sx) * (w * 0.5 - 0.003), h * (0.3 if sx == 0.0 else 0.5), 0), body)
	# Two stacks of nested lids; each lid shows as a thin dome with its rim.
	var stacks := [[-0.056, 0.0425], [0.056, 0.0475]]
	for s in stacks:
		var x: float = s[0]
		var r: float = s[1]
		var stack := MK.group(root, "Lids%d" % int(r * 2000.0))
		for i in range(11):
			var y := 0.012 + float(i) * 0.0065
			MK.cyl(stack, "Rim", r, r, 0.0045, Vector3(x, y, 0.004), lid, 24)
		MK.cyl(stack, "TopDome", r - 0.008, r * 0.55, 0.009, Vector3(x, 0.012 + 11.0 * 0.0065 + 0.002, 0.004), lid, 24)
	return root
