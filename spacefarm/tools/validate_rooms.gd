extends SceneTree
## Regression check for room scenes after running tools/room_painter.gd.
## Verifies layers are painted, exits are baked, wall tiles collide, and
## airlock unlocking opens the wall.
##
## Run:  godot --headless --path . --script tools/validate_rooms.gd

const ROOMS_DIR: String = "res://scenes/station/rooms/"
const ROOM_FILES: Array[String] = [
	"hub", "living_quarters", "grow_bay_room", "grow_bay_b", "grow_bay_c",
	"grow_bay_d", "cargo_bay", "service_tunnel", "processing_lab",
	"advanced_processing", "hybridization_lab",
]

var _failed: bool = false


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	for file: String in ROOM_FILES:
		await _check_room(file)
	_check_exit_reciprocity()
	_check_airlock_unlock()
	var station: PackedScene = load("res://scenes/station/station.tscn") as PackedScene
	_expect(station != null, "station.tscn loads")
	print("RESULT: " + ("FAIL" if _failed else "ALL OK"))
	quit(1 if _failed else 0)


func _check_room(file: String) -> void:
	var packed: PackedScene = load(ROOMS_DIR + file + ".tscn") as PackedScene
	if not _expect(packed != null, "%s loads" % file):
		return
	var room: BaseRoom = packed.instantiate() as BaseRoom
	root.add_child(room)
	await physics_frame
	await physics_frame

	var floor_layer: TileMapLayer = room.get_node("FloorLayer") as TileMapLayer
	var wall_layer: TileMapLayer = room.get_node("WallLayer") as TileMapLayer
	_expect(floor_layer.get_used_cells().size() > 0, "%s floor painted" % file)
	_expect(wall_layer.get_used_cells().size() > 0, "%s walls painted" % file)

	# every exit export has a baked zone + entrance; airlocks have neither
	for direction: String in ["north", "south", "east", "west"]:
		var has_exit: bool = room.get_exit_target(direction) != ""
		var zone: Node = room.get_node_or_null("Exit_%s" % direction)
		var marker: Node = room.get_node_or_null("Entrance_%s" % direction)
		_expect((zone != null) == has_exit, "%s zone %s matches exit export" % [file, direction])
		_expect((marker != null) == has_exit, "%s entrance %s matches exit export" % [file, direction])

	# a point inside the top wall band must collide; room center must not
	var space: PhysicsDirectSpaceState2D = room.get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	query.position = room.global_position + Vector2(room.room_width / 4.0, -room.room_height / 2.0 - 24.0)
	_expect(space.intersect_point(query).size() > 0, "%s wall tile collides" % file)
	query.position = room.global_position + Vector2(room.room_width / 4.0, 0)
	_expect(space.intersect_point(query).is_empty(), "%s interior is clear" % file)

	room.free()
	await process_frame


## Every exit must lead to a room whose opposite-direction exit leads back,
## so arriving players always have an entrance marker to land on.
func _check_exit_reciprocity() -> void:
	var opposites: Dictionary = {"north": "south", "south": "north", "east": "west", "west": "east"}
	var rooms: Dictionary = {}
	for file: String in ROOM_FILES:
		var room: BaseRoom = (load(ROOMS_DIR + file + ".tscn") as PackedScene).instantiate() as BaseRoom
		rooms[room.room_id] = room
	for room: BaseRoom in rooms.values():
		for direction: String in opposites:
			var target_id: String = room.get_exit_target(direction)
			if target_id == "":
				continue
			var target: BaseRoom = rooms.get(target_id, null) as BaseRoom
			if not _expect(target != null, "%s %s exit targets known room '%s'" % [room.room_id, direction, target_id]):
				continue
			var back: String = target.get_exit_target(opposites[direction])
			var sealed_back: bool = target.get_airlock_label(opposites[direction]) != ""
			_expect(back == room.room_id or sealed_back,
				"%s.%s -> %s reciprocated (got '%s')" % [room.room_id, direction, target_id, back])
	for room: BaseRoom in rooms.values():
		room.free()


func _check_airlock_unlock() -> void:
	var packed: PackedScene = load(ROOMS_DIR + "hub.tscn") as PackedScene
	var hub: BaseRoom = packed.instantiate() as BaseRoom
	root.add_child(hub)
	var wall_layer: TileMapLayer = hub.get_node("WallLayer") as TileMapLayer
	var before: int = wall_layer.get_used_cells().size()
	hub.unlock_airlock("west", "processing_lab")
	_expect(wall_layer.get_used_cells().size() == before - 2, "hub west airlock erases 2 wall tiles")
	_expect(hub.get_node_or_null("Exit_west") != null, "hub west airlock creates exit zone")
	_expect(hub.get_node_or_null("Entrance_west") != null, "hub west airlock creates entrance")
	hub.free()


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		print("FAIL: " + label)
		_failed = true
	return condition
