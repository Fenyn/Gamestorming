extends Node

const BUILDER_TYPE_PATHS: Dictionary = {
	"track_layer": "res://resources/builder_types/track_layer.tres",
	"pathfinder": "res://resources/builder_types/pathfinder.tres",
}

var builder_types: Dictionary = {}
var active_builders: Array[Node3D] = []
var builder_container: Node3D = null
var _next_builder_id: int = 0


func _ready() -> void:
	for id: String in BUILDER_TYPE_PATHS:
		builder_types[id] = load(BUILDER_TYPE_PATHS[id] as String)


func purchase_builder(type_id: String) -> bool:
	if not GameState.unlocked_builder_types.has(type_id):
		EventBus.purchase_failed.emit("Builder type locked")
		return false

	var unconnected: Array[String] = NetworkManager.get_unconnected_nodes()
	if unconnected.is_empty():
		EventBus.purchase_failed.emit("All nodes already connected")
		return false

	var data: BuilderTypeData = builder_types[type_id] as BuilderTypeData
	var owned: int = GameState.owned_builders.get(type_id, 0) as int
	var cost: float = GameFormulas.purchase_cost(data.base_cost, data.cost_multiplier, owned)

	if not GameState.spend_gold(cost):
		return false

	GameState.owned_builders[type_id] = owned + 1
	_spawn_builder(data, unconnected)
	EventBus.notification.emit("%s deployed!" % data.display_name)
	return true


func _spawn_builder(data: BuilderTypeData, unconnected: Array[String]) -> void:
	if builder_container == null:
		return

	var connected: Array[String] = NetworkManager.get_connected_nodes()
	if connected.is_empty():
		return

	var target_id: String = _pick_nearest_unconnected(connected, unconnected)
	var source_id: String = _pick_nearest_connected(target_id, connected)

	var builder_node: Node3D = _create_builder_scene(data, source_id, target_id)
	builder_container.add_child(builder_node)
	active_builders.append(builder_node)
	EventBus.builder_started.emit(_next_builder_id - 1, target_id)


func _pick_nearest_unconnected(connected: Array[String], unconnected: Array[String]) -> String:
	var best: String = unconnected[0]
	var best_dist: float = INF

	for u_id: String in unconnected:
		var u_pos: Vector3 = NetworkManager.get_node_position(u_id)
		for c_id: String in connected:
			var c_pos: Vector3 = NetworkManager.get_node_position(c_id)
			var dist: float = u_pos.distance_to(c_pos)
			if dist < best_dist:
				best_dist = dist
				best = u_id

	return best


func _pick_nearest_connected(target_id: String, connected: Array[String]) -> String:
	var target_pos: Vector3 = NetworkManager.get_node_position(target_id)
	var best: String = connected[0]
	var best_dist: float = INF

	for c_id: String in connected:
		var dist: float = NetworkManager.get_node_position(c_id).distance_to(target_pos)
		if dist < best_dist:
			best_dist = dist
			best = c_id

	return best


func _create_builder_scene(data: BuilderTypeData, source_id: String, target_id: String) -> Node3D:
	var builder: Node3D = Node3D.new()
	builder.name = "Builder_%d" % _next_builder_id
	_next_builder_id += 1

	var body: MeshInstance3D = MeshInstance3D.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()

	if data.id == "track_layer":
		var capsule: CapsuleMesh = CapsuleMesh.new()
		capsule.radius = 0.1
		capsule.height = 0.3
		mat.albedo_color = Color(0.95, 0.7, 0.15)
		capsule.material = mat
		body.mesh = capsule
		body.position.y = 0.15
	else:
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		mat.albedo_color = Color(0.2, 0.8, 0.5)
		sphere.material = mat
		body.mesh = sphere
		body.position.y = 0.12

	builder.add_child(body)

	var hat: MeshInstance3D = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.08
	cone.height = 0.1
	var hat_mat: StandardMaterial3D = StandardMaterial3D.new()
	hat_mat.albedo_color = mat.albedo_color.lightened(0.3)
	cone.material = hat_mat
	hat.mesh = cone
	hat.position.y = body.position.y + 0.18
	builder.add_child(hat)

	var script: GDScript = load("res://scripts/builders/builder.gd") as GDScript
	builder.set_script(script)
	builder.set("builder_id", _next_builder_id - 1)
	builder.set("builder_data", data)
	builder.set("source_node_id", source_id)
	builder.set("target_node_id", target_id)
	builder.position = NetworkManager.get_node_position(source_id)

	return builder


func clear_all() -> void:
	for builder: Node3D in active_builders:
		if is_instance_valid(builder):
			builder.queue_free()
	active_builders.clear()
	_next_builder_id = 0
