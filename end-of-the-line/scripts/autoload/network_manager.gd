extends Node

const NODE_PATHS: Array[String] = [
	"res://resources/map_nodes/mine.tres",
	"res://resources/map_nodes/farm.tres",
	"res://resources/map_nodes/factory.tres",
	"res://resources/map_nodes/town.tres",
	"res://resources/map_nodes/port.tres",
]

const STARTER_EDGES: Array[Array] = [
	["mine", "town"],
	["farm", "town"],
]

var nodes: Dictionary = {}
var edges: Array[Dictionary] = []
var adjacency: Dictionary = {}
var track_container: Node3D = null

var _next_edge_id: int = 0


func _ready() -> void:
	for path in NODE_PATHS:
		var data: NodeData = load(path) as NodeData
		nodes[data.id] = data
		adjacency[data.id] = [] as Array[String]


func setup_starter_network() -> void:
	for edge_def in STARTER_EDGES:
		add_edge(edge_def[0] as String, edge_def[1] as String)


func add_edge(from_id: String, to_id: String) -> int:
	var edge_id: int = _next_edge_id
	_next_edge_id += 1
	var from_data: NodeData = nodes[from_id] as NodeData
	var to_data: NodeData = nodes[to_id] as NodeData
	var length: float = from_data.position.distance_to(to_data.position)

	var edge: Dictionary = {
		"id": edge_id,
		"from": from_id,
		"to": to_id,
		"length": length,
		"path_node": null,
	}
	edges.append(edge)

	if not adjacency[from_id].has(to_id):
		(adjacency[from_id] as Array).append(to_id)
	if not adjacency[to_id].has(from_id):
		(adjacency[to_id] as Array).append(from_id)

	_create_track_path(edge)
	EventBus.node_connected.emit(from_id)
	EventBus.node_connected.emit(to_id)
	return edge_id


func get_connected_nodes() -> Array[String]:
	var connected: Array[String] = []
	for node_id: String in adjacency:
		if (adjacency[node_id] as Array).size() > 0:
			if not connected.has(node_id):
				connected.append(node_id)
	return connected


func get_unconnected_nodes() -> Array[String]:
	var unconnected: Array[String] = []
	for node_id: String in adjacency:
		if (adjacency[node_id] as Array).size() == 0:
			unconnected.append(node_id)
	return unconnected


func get_edge_between(from_id: String, to_id: String) -> Dictionary:
	for edge: Dictionary in edges:
		if (edge["from"] == from_id and edge["to"] == to_id) or \
			(edge["from"] == to_id and edge["to"] == from_id):
			return edge
	return {}


func get_edges_from(node_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for edge: Dictionary in edges:
		if edge["from"] == node_id or edge["to"] == node_id:
			result.append(edge)
	return result


func get_node_position(node_id: String) -> Vector3:
	if nodes.has(node_id):
		return (nodes[node_id] as NodeData).position
	return Vector3.ZERO


func get_shortest_path(from_id: String, to_id: String) -> Array[String]:
	if from_id == to_id:
		return [from_id]

	var dist: Dictionary = {}
	var prev: Dictionary = {}
	var queue: Array[String] = []

	for node_id: String in nodes:
		dist[node_id] = INF
		prev[node_id] = ""
		queue.append(node_id)

	dist[from_id] = 0.0

	while queue.size() > 0:
		var current: String = ""
		var min_dist: float = INF
		for q_id: String in queue:
			if (dist[q_id] as float) < min_dist:
				min_dist = dist[q_id] as float
				current = q_id

		if current == "" or current == to_id:
			break

		queue.erase(current)

		for neighbor: String in adjacency[current] as Array:
			if not queue.has(neighbor):
				continue
			var edge: Dictionary = get_edge_between(current, neighbor)
			if edge.is_empty():
				continue
			var alt: float = (dist[current] as float) + (edge["length"] as float)
			if alt < (dist[neighbor] as float):
				dist[neighbor] = alt
				prev[neighbor] = current

	if (prev[to_id] as String) == "" and from_id != to_id:
		return []

	var path: Array[String] = []
	var current: String = to_id
	while current != "":
		path.push_front(current)
		current = prev[current] as String
	return path


func _create_track_path(edge: Dictionary) -> void:
	if track_container == null:
		return

	var from_pos: Vector3 = get_node_position(edge["from"] as String)
	var to_pos: Vector3 = get_node_position(edge["to"] as String)

	var path_node: Path3D = Path3D.new()
	path_node.name = "Track_%s_%s" % [edge["from"], edge["to"]]
	var curve: Curve3D = Curve3D.new()
	curve.add_point(from_pos)
	curve.add_point(to_pos)
	path_node.curve = curve

	track_container.add_child(path_node)
	edge["path_node"] = path_node

	_place_track_meshes(path_node, from_pos, to_pos)
	EventBus.track_segment_built.emit(from_pos, to_pos)


func _place_track_meshes(path_node: Path3D, from_pos: Vector3, to_pos: Vector3) -> void:
	var track_scene: PackedScene = load("res://kenney_train-kit/Models/GLB format/railroad-straight.glb") as PackedScene
	if track_scene == null:
		_place_fallback_track(path_node, from_pos, to_pos)
		return

	var direction: Vector3 = (to_pos - from_pos)
	var dir_norm: Vector3 = direction.normalized()
	var length: float = direction.length()
	var angle: float = atan2(dir_norm.x, dir_norm.z)

	var segment_length: float = 0.5
	var count: int = int(ceil(length / segment_length))

	for i: int in range(count):
		var t: float = (float(i) + 0.5) / float(count)
		var pos: Vector3 = from_pos.lerp(to_pos, t)
		var instance: Node3D = track_scene.instantiate() as Node3D
		instance.position = pos
		instance.rotation.y = angle
		path_node.add_child(instance)


func _place_fallback_track(path_node: Path3D, from_pos: Vector3, to_pos: Vector3) -> void:
	var direction: Vector3 = to_pos - from_pos
	var length: float = direction.length()
	var mid: Vector3 = from_pos.lerp(to_pos, 0.5)
	mid.y = 0.02

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.3, 0.04, length)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.35, 0.25)
	box.material = mat
	mesh_inst.mesh = box
	mesh_inst.position = mid

	var angle: float = atan2(direction.x, direction.z)
	mesh_inst.rotation.y = angle

	path_node.add_child(mesh_inst)


func reset_to_starter() -> void:
	for edge: Dictionary in edges:
		var path_node: Node3D = edge.get("path_node") as Node3D
		if path_node != null:
			path_node.queue_free()

	edges.clear()
	for node_id: String in adjacency:
		adjacency[node_id] = [] as Array[String]

	EventBus.network_reset.emit()
	setup_starter_network()
