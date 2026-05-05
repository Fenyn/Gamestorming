extends StaticBody3D
class_name TrackPiece

var piece_data: TrackPieceData
var occupied_connections: Dictionary = {}

func setup(data: TrackPieceData) -> void:
	piece_data = data

	var scene: PackedScene = load(data.model_path) as PackedScene
	if scene == null:
		push_error("TrackPiece: Failed to load model: %s" % data.model_path)
		return

	var model: Node3D = scene.instantiate() as Node3D
	add_child(model)

	_generate_collision(model)
	_create_connection_markers()

func _generate_collision(model: Node3D) -> void:
	for child: Node in model.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			mi.create_trimesh_collision()

func _create_connection_markers() -> void:
	if piece_data == null:
		return

	for i: int in piece_data.connections.size():
		var conn: ConnectionPoint = piece_data.connections[i]
		var marker: Marker3D = Marker3D.new()
		marker.name = "Connection_%d" % i
		marker.position = conn.local_position
		add_child(marker)

func get_world_connection(index: int) -> Dictionary:
	if piece_data == null or index >= piece_data.connections.size():
		return {}

	var conn: ConnectionPoint = piece_data.connections[index]
	var world_pos: Vector3 = to_global(conn.local_position)
	var world_dir: Vector3 = global_transform.basis * conn.local_direction

	return {
		"position": world_pos,
		"direction": world_dir.normalized(),
		"height_offset": conn.height_offset,
		"width": conn.width,
		"index": index,
		"occupied": occupied_connections.get(index, false),
	}

func get_open_world_connections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in piece_data.connections.size():
		var wc: Dictionary = get_world_connection(i)
		if not wc.get("occupied", false):
			result.append(wc)
	return result

func mark_connection_occupied(index: int) -> void:
	occupied_connections[index] = true
