class_name BaseRoom3D
extends Node3D
## A 3D station room. Floors, walls, and props are MeshInstance3D children placed
## in the editor from imported FBX assets. Navigation uses a baked
## NavigationRegion3D. Exit zones and entrance markers use the same interface as
## BaseRoom so Station3D room-graph logic ports directly.

const EXIT_ZONE_DEPTH: float = 0.5
const EXIT_ZONE_WIDTH: float = 2.0
const EXIT_ZONE_HEIGHT: float = 2.5
const ENTRANCE_OFFSET: float = 1.5

@export_group("Room")
@export var room_id: String = ""
@export var room_width: float = 10.0
@export var room_depth: float = 8.0

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


func _ready() -> void:
	for child: Node in get_children():
		var child_name: String = String(child.name)
		if child is Marker3D and child_name.begins_with("Entrance_"):
			_entrances[child_name.trim_prefix("Entrance_")] = child


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
	create_exit(direction, target_room)


func create_exit(direction: String, target_room: String) -> Array[Node]:
	var hw: float = room_width / 2.0
	var hd: float = room_depth / 2.0

	var zone: ExitZone3D = ExitZone3D.new()
	zone.name = "Exit_%s" % direction
	zone.target_room = target_room
	zone.target_entrance = direction
	zone.collision_layer = 0
	zone.collision_mask = 1

	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "Shape"
	var box: BoxShape3D = BoxShape3D.new()
	match direction:
		"north":
			box.size = Vector3(EXIT_ZONE_WIDTH, EXIT_ZONE_HEIGHT, EXIT_ZONE_DEPTH)
			zone.position = Vector3(0.0, EXIT_ZONE_HEIGHT / 2.0, -hd - EXIT_ZONE_DEPTH / 2.0)
		"south":
			box.size = Vector3(EXIT_ZONE_WIDTH, EXIT_ZONE_HEIGHT, EXIT_ZONE_DEPTH)
			zone.position = Vector3(0.0, EXIT_ZONE_HEIGHT / 2.0, hd + EXIT_ZONE_DEPTH / 2.0)
		"east":
			box.size = Vector3(EXIT_ZONE_DEPTH, EXIT_ZONE_HEIGHT, EXIT_ZONE_WIDTH)
			zone.position = Vector3(hw + EXIT_ZONE_DEPTH / 2.0, EXIT_ZONE_HEIGHT / 2.0, 0.0)
		"west":
			box.size = Vector3(EXIT_ZONE_DEPTH, EXIT_ZONE_HEIGHT, EXIT_ZONE_WIDTH)
			zone.position = Vector3(-hw - EXIT_ZONE_DEPTH / 2.0, EXIT_ZONE_HEIGHT / 2.0, 0.0)
	shape_node.shape = box
	zone.add_child(shape_node)
	add_child(zone)

	var marker: Marker3D = Marker3D.new()
	marker.name = "Entrance_%s" % direction
	match direction:
		"north": marker.position = Vector3(0.0, 0.0, -hd + ENTRANCE_OFFSET)
		"south": marker.position = Vector3(0.0, 0.0, hd - ENTRANCE_OFFSET)
		"east": marker.position = Vector3(hw - ENTRANCE_OFFSET, 0.0, 0.0)
		"west": marker.position = Vector3(-hw + ENTRANCE_OFFSET, 0.0, 0.0)
	add_child(marker)
	_entrances[direction] = marker

	return [zone, marker]


func has_entrance(direction: String) -> bool:
	return _entrances.has(direction)


func get_entrance_position(direction: String) -> Vector3:
	var marker: Marker3D = _entrances.get(direction, null) as Marker3D
	if marker:
		return marker.global_position
	return global_position
