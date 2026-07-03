class_name BaseRoom
extends Node2D
## A station room. Floors and walls are painted TileMapLayers; wall collision
## comes from the tileset's physics layer, so the painted walls ARE the
## collision. Exit zones and entrance markers for open exits are baked into
## each room scene by tools/room_painter.gd; sealed airlocks stay solid wall
## until unlock_airlock() erases the door tiles and creates the exit.

const TILE_SIZE: int = 48
const EXIT_WIDTH: float = 96.0
const EXIT_ZONE_DEPTH: float = 24.0
const ENTRANCE_OFFSET: float = 40.0

@export_group("Room")
@export var room_id: String = ""
@export var room_width: float = 480.0
@export var room_height: float = 384.0
## Grow-ring biome for crop gating: verdant, arid, fungal, or cryo.
@export var biome: String = "verdant"

@export_group("Exits")
@export var exit_north: String = ""
@export var exit_south: String = ""
@export var exit_east: String = ""
@export var exit_west: String = ""

@export_group("Sealed Airlocks")
@export var airlock_north: String = ""
@export var airlock_south: String = ""
@export var airlock_east: String = ""
@export var airlock_west: String = ""

var _entrances: Dictionary = {}
var _nav_region: NavigationRegion2D = null

@onready var _floor_layer: TileMapLayer = $FloorLayer
@onready var _wall_layer: TileMapLayer = $WallLayer


func _ready() -> void:
	for child: Node in get_children():
		var child_name: String = String(child.name)
		if child is Marker2D and child_name.begins_with("Entrance_"):
			_entrances[child_name.trim_prefix("Entrance_")] = child
	_create_navigation_region()


func _create_navigation_region() -> void:
	_nav_region = NavigationRegion2D.new()
	var nav_poly: NavigationPolygon = NavigationPolygon.new()
	var inset: float = float(TILE_SIZE) * 1.5
	var hw: float = room_width / 2.0 - inset
	var hh: float = room_height / 2.0 - inset
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh),
	])
	nav_poly.add_outline(outline)
	nav_poly.make_polygons_from_outlines()
	_nav_region.navigation_polygon = nav_poly
	add_child(_nav_region)


func get_exit_target(direction: String) -> String:
	match direction:
		"north": return exit_north
		"south": return exit_south
		"east": return exit_east
		"west": return exit_west
	return ""


func get_airlock_label(direction: String) -> String:
	match direction:
		"north": return airlock_north
		"south": return airlock_south
		"east": return airlock_east
		"west": return airlock_west
	return ""


func unlock_airlock(direction: String, target_room: String) -> void:
	_open_door_visual(direction)
	create_exit(direction, target_room)


## Creates the ExitZone trigger and entrance marker for a door. Used at
## runtime when an airlock unlocks, and by tools/room_painter.gd to bake
## the nodes for regular exits into the scene. Returns the created nodes.
func create_exit(direction: String, target_room: String) -> Array[Node]:
	var hw: float = room_width / 2.0
	var hh: float = room_height / 2.0

	var zone: ExitZone = ExitZone.new()
	zone.name = "Exit_%s" % direction
	zone.target_room = target_room
	zone.target_entrance = direction
	zone.collision_layer = 0
	zone.collision_mask = 1

	var shape_node: CollisionShape2D = CollisionShape2D.new()
	shape_node.name = "Shape"
	var rect: RectangleShape2D = RectangleShape2D.new()
	match direction:
		"north":
			rect.size = Vector2(EXIT_WIDTH, EXIT_ZONE_DEPTH)
			zone.position = Vector2(0, -hh - EXIT_ZONE_DEPTH / 2.0)
		"south":
			rect.size = Vector2(EXIT_WIDTH, EXIT_ZONE_DEPTH)
			zone.position = Vector2(0, hh + EXIT_ZONE_DEPTH / 2.0)
		"east":
			rect.size = Vector2(EXIT_ZONE_DEPTH, EXIT_WIDTH)
			zone.position = Vector2(hw + EXIT_ZONE_DEPTH / 2.0, 0)
		"west":
			rect.size = Vector2(EXIT_ZONE_DEPTH, EXIT_WIDTH)
			zone.position = Vector2(-hw - EXIT_ZONE_DEPTH / 2.0, 0)
	shape_node.shape = rect
	zone.add_child(shape_node)
	add_child(zone)

	var marker: Marker2D = Marker2D.new()
	marker.name = "Entrance_%s" % direction
	match direction:
		"north": marker.position = Vector2(0, -hh + ENTRANCE_OFFSET)
		"south": marker.position = Vector2(0, hh - ENTRANCE_OFFSET)
		"east": marker.position = Vector2(hw - ENTRANCE_OFFSET, 0)
		"west": marker.position = Vector2(-hw + ENTRANCE_OFFSET, 0)
	add_child(marker)
	_entrances[direction] = marker

	return [zone, marker]


func has_entrance(direction: String) -> bool:
	return _entrances.has(direction)


func get_entrance_position(direction: String) -> Vector2:
	var marker: Marker2D = _entrances.get(direction, null) as Marker2D
	if marker:
		return marker.global_position
	return global_position


func _open_door_visual(direction: String) -> void:
	if _wall_layer == null or _wall_layer.tile_set == null:
		return
	var half_cols: int = int(room_width) / TILE_SIZE / 2
	var half_rows: int = int(room_height) / TILE_SIZE / 2
	match direction:
		"north":
			for x: int in [-1, 0]:
				_wall_layer.erase_cell(Vector2i(x, -half_rows - 1))
				_wall_layer.erase_cell(Vector2i(x, -half_rows - 2))
				_paint_doorway_floor(Vector2i(x, -half_rows - 1), Vector2i(x, -half_rows))
				_paint_doorway_floor(Vector2i(x, -half_rows - 2), Vector2i(x, -half_rows))
		"south":
			for x: int in [-1, 0]:
				_wall_layer.erase_cell(Vector2i(x, half_rows))
				_wall_layer.erase_cell(Vector2i(x, half_rows + 1))
				_paint_doorway_floor(Vector2i(x, half_rows), Vector2i(x, half_rows - 1))
				_paint_doorway_floor(Vector2i(x, half_rows + 1), Vector2i(x, half_rows - 1))
		"west":
			for y: int in [-1, 0]:
				_wall_layer.erase_cell(Vector2i(-half_cols - 1, y))
		"east":
			for y: int in [-1, 0]:
				_wall_layer.erase_cell(Vector2i(half_cols, y))


func _paint_doorway_floor(target: Vector2i, copy_from: Vector2i) -> void:
	if _floor_layer == null or _floor_layer.get_cell_source_id(target) != -1:
		return
	var src_id: int = _floor_layer.get_cell_source_id(copy_from)
	if src_id == -1:
		return
	_floor_layer.set_cell(target, src_id, _floor_layer.get_cell_atlas_coords(copy_from))
