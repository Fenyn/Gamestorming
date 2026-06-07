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
@export var floor_color: Color = Color(0.1, 0.1, 0.13, 1)
@export var wall_color: Color = Color(0.3, 0.3, 0.35, 1)

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
	_build_floor()
	_build_walls()


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


func _build_floor() -> void:
	var floor_rect: ColorRect = ColorRect.new()
	var hw: float = room_width / 2.0
	var hh: float = room_height / 2.0
	floor_rect.offset_left = -hw
	floor_rect.offset_top = -hh
	floor_rect.offset_right = hw
	floor_rect.offset_bottom = hh
	floor_rect.color = floor_color
	floor_rect.z_index = -1
	add_child(floor_rect)


func _build_walls() -> void:
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
		_build_wall_with_airlock(center, full_size, is_horizontal, airlock_label, direction)
	else:
		_build_solid_wall(center, full_size, direction)


func _build_solid_wall(center: Vector2, size: Vector2, direction: String = "") -> void:
	var wall: StaticBody2D = _create_wall_body(center, size)
	_add_wall_visual(wall, size, wall_color)
	if direction != "":
		_wall_nodes_by_direction[direction].append(wall)


func _build_wall_with_exit(center: Vector2, full_size: Vector2, is_horizontal: bool, target_room: String, direction: String) -> void:
	var half_exit: float = EXIT_WIDTH / 2.0

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


func _build_wall_with_airlock(center: Vector2, full_size: Vector2, is_horizontal: bool, label_text: String, direction: String) -> void:
	_build_solid_wall(center, full_size, direction)
	var airlock_vis: ColorRect = ColorRect.new()
	var half_exit: float = EXIT_WIDTH / 2.0
	if is_horizontal:
		airlock_vis.offset_left = -half_exit
		airlock_vis.offset_top = -WALL_THICKNESS / 2.0
		airlock_vis.offset_right = half_exit
		airlock_vis.offset_bottom = WALL_THICKNESS / 2.0
	else:
		airlock_vis.offset_left = -WALL_THICKNESS / 2.0
		airlock_vis.offset_top = -half_exit
		airlock_vis.offset_right = WALL_THICKNESS / 2.0
		airlock_vis.offset_bottom = half_exit
	airlock_vis.color = Color(0.5, 0.15, 0.1, 1)
	airlock_vis.position = center
	airlock_vis.z_index = 1
	add_child(airlock_vis)
	_wall_nodes_by_direction[direction].append(airlock_vis)

	var label: Label = Label.new()
	label.text = "SEALED: %s" % label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.offset_left = -60.0
	label.offset_right = 60.0
	if is_horizontal:
		label.position = center + Vector2(0, -20)
		label.offset_top = -8.0
		label.offset_bottom = 8.0
	else:
		label.position = center + Vector2(-70, 0)
		label.offset_top = -8.0
		label.offset_bottom = 8.0
	add_child(label)
	_wall_nodes_by_direction[direction].append(label)


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


func _add_wall_visual(body: StaticBody2D, size: Vector2, color: Color) -> void:
	var vis: ColorRect = ColorRect.new()
	vis.offset_left = -size.x / 2.0
	vis.offset_top = -size.y / 2.0
	vis.offset_right = size.x / 2.0
	vis.offset_bottom = size.y / 2.0
	vis.color = color
	body.add_child(vis)


func get_entrance_position(direction: String) -> Vector2:
	var marker: Marker2D = _entrances.get(direction, null) as Marker2D
	if marker:
		return marker.global_position
	return global_position
