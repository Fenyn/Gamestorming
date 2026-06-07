class_name BaseRoom
extends Node2D

const WALL_THICKNESS: float = 16.0
const EXIT_WIDTH: float = 48.0
const EXIT_ZONE_DEPTH: float = 24.0
const ENTRANCE_OFFSET: float = 40.0

@export_group("Room")
@export var room_id: String = ""
@export var room_width: float = 400.0
@export var room_height: float = 300.0

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
var _wall_nodes_by_direction: Dictionary = {}


func _ready() -> void:
	_build_collision_walls()


func unlock_airlock(direction: String, target_room: String) -> void:
	for node: Node in _wall_nodes_by_direction.get(direction, []):
		node.queue_free()
	_wall_nodes_by_direction[direction] = []

	var hw: float = room_width / 2.0 + WALL_THICKNESS / 2.0
	var hh: float = room_height / 2.0 + WALL_THICKNESS / 2.0
	var full_w: float = room_width + WALL_THICKNESS
	var full_h: float = room_height + WALL_THICKNESS

	var center: Vector2 = Vector2.ZERO
	var full_size: Vector2 = Vector2.ZERO
	var is_horizontal: bool = false
	match direction:
		"north":
			center = Vector2(0, -hh)
			full_size = Vector2(full_w, WALL_THICKNESS)
			is_horizontal = true
		"south":
			center = Vector2(0, hh)
			full_size = Vector2(full_w, WALL_THICKNESS)
			is_horizontal = true
		"west":
			center = Vector2(-hw, 0)
			full_size = Vector2(WALL_THICKNESS, full_h)
		"east":
			center = Vector2(hw, 0)
			full_size = Vector2(WALL_THICKNESS, full_h)

	_build_wall_with_exit(center, full_size, is_horizontal, target_room, direction)


func _build_collision_walls() -> void:
	var hw: float = room_width / 2.0 + WALL_THICKNESS / 2.0
	var hh: float = room_height / 2.0 + WALL_THICKNESS / 2.0
	var full_w: float = room_width + WALL_THICKNESS
	var full_h: float = room_height + WALL_THICKNESS

	_build_wall_side(Vector2(0, -hh), Vector2(full_w, WALL_THICKNESS), exit_north, airlock_north, "north")
	_build_wall_side(Vector2(0, hh), Vector2(full_w, WALL_THICKNESS), exit_south, airlock_south, "south")
	_build_wall_side(Vector2(-hw, 0), Vector2(WALL_THICKNESS, full_h), exit_west, airlock_west, "west")
	_build_wall_side(Vector2(hw, 0), Vector2(WALL_THICKNESS, full_h), exit_east, airlock_east, "east")


func _build_wall_side(center: Vector2, full_size: Vector2, exit_target: String, airlock_label: String, direction: String) -> void:
	var is_horizontal: bool = full_size.x > full_size.y
	_wall_nodes_by_direction[direction] = []

	if exit_target != "":
		_build_wall_with_exit(center, full_size, is_horizontal, exit_target, direction)
	elif airlock_label != "":
		_build_solid_wall(center, full_size, direction)
	else:
		_build_solid_wall(center, full_size, direction)


func _build_solid_wall(center: Vector2, size: Vector2, direction: String = "") -> void:
	var wall: StaticBody2D = _create_wall_body(center, size)
	if direction != "":
		_wall_nodes_by_direction[direction].append(wall)


func _build_wall_with_exit(center: Vector2, full_size: Vector2, is_horizontal: bool, target_room: String, direction: String) -> void:
	if is_horizontal:
		var seg_width: float = (full_size.x - EXIT_WIDTH) / 2.0
		var offset: float = (seg_width + EXIT_WIDTH) / 2.0
		_build_solid_wall(center + Vector2(-offset, 0), Vector2(seg_width, full_size.y))
		_build_solid_wall(center + Vector2(offset, 0), Vector2(seg_width, full_size.y))
	else:
		var seg_height: float = (full_size.y - EXIT_WIDTH) / 2.0
		var offset: float = (seg_height + EXIT_WIDTH) / 2.0
		_build_solid_wall(center + Vector2(0, -offset), Vector2(full_size.x, seg_height))
		_build_solid_wall(center + Vector2(0, offset), Vector2(full_size.x, seg_height))

	_build_exit_zone(center, direction, target_room)
	_build_entrance(center, direction)


func _build_exit_zone(wall_center: Vector2, direction: String, target_room: String) -> void:
	var zone: ExitZone = ExitZone.new()
	zone.target_room = target_room
	zone.target_entrance = direction
	zone.collision_layer = 0
	zone.collision_mask = 1

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()

	match direction:
		"north":
			rect.size = Vector2(EXIT_WIDTH, EXIT_ZONE_DEPTH)
			zone.position = wall_center + Vector2(0, -EXIT_ZONE_DEPTH / 2.0)
		"south":
			rect.size = Vector2(EXIT_WIDTH, EXIT_ZONE_DEPTH)
			zone.position = wall_center + Vector2(0, EXIT_ZONE_DEPTH / 2.0)
		"east":
			rect.size = Vector2(EXIT_ZONE_DEPTH, EXIT_WIDTH)
			zone.position = wall_center + Vector2(EXIT_ZONE_DEPTH / 2.0, 0)
		"west":
			rect.size = Vector2(EXIT_ZONE_DEPTH, EXIT_WIDTH)
			zone.position = wall_center + Vector2(-EXIT_ZONE_DEPTH / 2.0, 0)

	shape.shape = rect
	zone.add_child(shape)
	zone.name = "Exit_%s" % direction
	add_child(zone)


func _build_entrance(wall_center: Vector2, direction: String) -> void:
	var marker: Marker2D = Marker2D.new()
	match direction:
		"north":
			marker.position = wall_center + Vector2(0, ENTRANCE_OFFSET)
		"south":
			marker.position = wall_center + Vector2(0, -ENTRANCE_OFFSET)
		"east":
			marker.position = wall_center + Vector2(-ENTRANCE_OFFSET, 0)
		"west":
			marker.position = wall_center + Vector2(ENTRANCE_OFFSET, 0)
	marker.name = "Entrance_%s" % direction
	add_child(marker)
	_entrances[direction] = marker


func _create_wall_body(center: Vector2, size: Vector2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = center
	body.collision_layer = 1

	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	add_child(body)
	return body


func get_entrance_position(direction: String) -> Vector2:
	var marker: Marker2D = _entrances.get(direction, null) as Marker2D
	if marker:
		return marker.global_position
	return global_position
