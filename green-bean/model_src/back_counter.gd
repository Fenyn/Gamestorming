extends RefCounted

## Back bar counter top, wall to wall (3.32 x 0.78 m), with a 4 cm stone top and
## rounded front edge overhanging the cabinets by 2.5 cm, a recessed dark apron
## under it, and a 3-row tiled backsplash on the back wall.
## Origin: centre of the top surface (shop y 0.89). The wall is at -Z and the
## barista works from +Z. The collider is in the shop scene.

const MK := preload("res://model_src/model_kit.gd")

const WIDTH := 3.322
const DEPTH := 0.78
const TOP := 0.04
## Deep enough to hide the cabinets' own top slabs behind it.
const RAIL := 0.08
const STONE := Color(0.81, 0.776, 0.722)
const TILE := Color(0.93, 0.92, 0.88)
const GROUT := Color(0.7, 0.68, 0.64)
const TILE_SIZE := Vector2(0.15, 0.075)
const TILE_ROWS := 3

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "BackCounter"
	var stone: Material = MK.mat(STONE, 0.0, 0.45)
	var front_z := DEPTH * 0.5
	var r := TOP * 0.5
	MK.box(root, "Top", Vector3(WIDTH, TOP, DEPTH - r), Vector3(0, -TOP * 0.5, -r * 0.5), stone)
	MK.cyl(root, "FrontEdge", r, r, WIDTH, Vector3(0, -r, front_z - r), stone, 12, Vector3(0, 0, 90))
	MK.box(root, "Rail", Vector3(WIDTH, RAIL, 0.02), Vector3(0, -TOP - RAIL * 0.5, front_z - 0.03), MK.mat(MK.WOOD_DARKER, 0.0, 0.7))
	_build_backsplash(root, -DEPTH * 0.5)
	return root

## Running-bond tiles proud of a grout backing, so the joints read as lines.
static func _build_backsplash(root: Node3D, wall_z: float) -> void:
	var splash := MK.group(root, "Backsplash")
	var h := TILE_SIZE.y * TILE_ROWS
	MK.box(splash, "Grout", Vector3(WIDTH, h, 0.006), Vector3(0, h * 0.5, wall_z + 0.003), MK.mat(GROUT, 0.0, 0.8))
	var tile: Material = MK.mat(TILE, 0.0, 0.2)
	var joint := 0.003
	for row in range(TILE_ROWS):
		var y := (float(row) + 0.5) * TILE_SIZE.y
		var x := -WIDTH * 0.5 - (TILE_SIZE.x * 0.5 if row % 2 == 1 else 0.0)
		while x < WIDTH * 0.5:
			var x0 := maxf(x, -WIDTH * 0.5)
			var x1 := minf(x + TILE_SIZE.x, WIDTH * 0.5)
			if x1 - x0 > joint * 2.0:
				MK.box(splash, "Tile", Vector3(x1 - x0 - joint, TILE_SIZE.y - joint, 0.006), Vector3((x0 + x1) * 0.5, y, wall_z + 0.009), tile)
			x += TILE_SIZE.x
	MK.box(splash, "Cap", Vector3(WIDTH, 0.012, 0.014), Vector3(0, h + 0.006, wall_z + 0.007), MK.mat(STONE, 0.0, 0.45))
