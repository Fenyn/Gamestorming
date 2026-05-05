extends Node

const TRAIN_TYPE_PATHS: Dictionary = {
	"handcar": "res://resources/train_types/handcar.tres",
	"steam_loco": "res://resources/train_types/steam_loco.tres",
}

var train_types: Dictionary = {}
var active_trains: Array[Node3D] = []
var train_container: Node3D = null
var _next_train_id: int = 0
var _node_traffic: Dictionary = {}


func _ready() -> void:
	for id: String in TRAIN_TYPE_PATHS:
		train_types[id] = load(TRAIN_TYPE_PATHS[id] as String)


func purchase_train(type_id: String) -> bool:
	if not GameState.unlocked_train_types.has(type_id):
		EventBus.purchase_failed.emit("Train type locked")
		return false

	var data: TrainTypeData = train_types[type_id] as TrainTypeData
	var owned: int = GameState.owned_trains.get(type_id, 0) as int
	var cost: float = GameFormulas.purchase_cost(data.base_cost, data.cost_multiplier, owned)

	if cost > 0.0 and not GameState.spend_gold(cost):
		return false

	GameState.owned_trains[type_id] = owned + 1
	_spawn_train(data)
	EventBus.notification.emit("%s dispatched!" % data.display_name)
	return true


func _spawn_train(data: TrainTypeData) -> void:
	if train_container == null:
		return

	var connected: Array[String] = NetworkManager.get_connected_nodes()
	if connected.is_empty():
		return

	var start_node: String = _pick_least_congested(connected)
	var train_node: Node3D = _create_train_scene(data, start_node)
	train_container.add_child(train_node)
	active_trains.append(train_node)


func _pick_least_congested(nodes: Array[String]) -> String:
	var best: String = nodes[0]
	var best_traffic: int = get_node_traffic(best)
	for node_id: String in nodes:
		var traffic: int = get_node_traffic(node_id)
		if traffic < best_traffic:
			best_traffic = traffic
			best = node_id
	return best


const CARRIAGE_SCENES: Array[String] = [
	"res://kenney_train-kit/Models/GLB format/train-carriage-box.glb",
	"res://kenney_train-kit/Models/GLB format/train-carriage-coal.glb",
	"res://kenney_train-kit/Models/GLB format/train-carriage-wood.glb",
	"res://kenney_train-kit/Models/GLB format/train-carriage-container-blue.glb",
]
const CARRIAGE_SPACING: float = 1.2


func _create_train_scene(data: TrainTypeData, start_node: String) -> Node3D:
	var train: Node3D = Node3D.new()
	train.name = "Train_%d" % _next_train_id
	_next_train_id += 1

	var mesh_scene: PackedScene = load(data.mesh_path) as PackedScene
	if mesh_scene != null:
		var mesh_instance: Node3D = mesh_scene.instantiate() as Node3D
		mesh_instance.rotate_y(PI)
		train.add_child(mesh_instance)

	var carriage_count: int = maxi(0, data.capacity - 1)
	for i: int in range(carriage_count):
		var carriage_path: String = CARRIAGE_SCENES[i % CARRIAGE_SCENES.size()]
		var carriage_scene: PackedScene = load(carriage_path) as PackedScene
		if carriage_scene != null:
			var carriage: Node3D = carriage_scene.instantiate() as Node3D
			carriage.rotate_y(PI)
			carriage.position.z = CARRIAGE_SPACING * (i + 1)
			train.add_child(carriage)

	var script: GDScript = load("res://scripts/trains/train.gd") as GDScript
	train.set_script(script)
	train.set("train_id", _next_train_id - 1)
	train.set("train_data", data)
	train.set("current_node_id", start_node)
	train.position = NetworkManager.get_node_position(start_node)

	return train


func register_destination(node_id: String) -> void:
	_node_traffic[node_id] = _node_traffic.get(node_id, 0) as int + 1


func unregister_destination(node_id: String) -> void:
	var current: int = _node_traffic.get(node_id, 0) as int
	_node_traffic[node_id] = maxi(0, current - 1)


func get_node_traffic(node_id: String) -> int:
	return _node_traffic.get(node_id, 0) as int


func clear_all() -> void:
	for train: Node3D in active_trains:
		if is_instance_valid(train):
			train.queue_free()
	active_trains.clear()
	_node_traffic.clear()
	_next_train_id = 0
