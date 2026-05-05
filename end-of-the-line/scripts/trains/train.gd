extends Node3D

var train_data: TrainTypeData
var train_id: int = -1
var current_node_id: String = ""

var _route: Array[String] = []
var _route_index: int = 0
var _destination_id: String = ""
var _hops_completed: int = 0

var _moving: bool = false
var _idle: bool = false
var _idle_timer: float = 0.0
var _current_path: Path3D = null
var _progress: float = 0.0
var _curve_length: float = 0.0
var _direction_forward: bool = true

const IDLE_DURATION: float = 0.8
const DISTANCE_BONUS_PER_HOP: float = 0.15
const CONGESTION_PENALTY: float = 0.4


func _ready() -> void:
	_plan_route()


func _process(delta: float) -> void:
	if _idle:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_idle = false
			if _route.is_empty():
				_plan_route()
			else:
				_advance_route()
		return

	if not _moving or _current_path == null:
		return

	var speed: float = train_data.speed
	_progress += (speed * delta) / _curve_length

	if _progress >= 1.0:
		_progress = 1.0
		_arrive_at_node()
	else:
		_update_position()


func _plan_route() -> void:
	var connected: Array[String] = NetworkManager.get_connected_nodes()
	if connected.size() < 2:
		_moving = false
		return

	var best_destination: String = _score_destinations(connected)
	if best_destination == "" or best_destination == current_node_id:
		_moving = false
		return

	if _destination_id != "":
		TrainManager.unregister_destination(_destination_id)

	_destination_id = best_destination
	TrainManager.register_destination(_destination_id)

	_route = NetworkManager.get_shortest_path(current_node_id, _destination_id)
	_route_index = 0
	_hops_completed = 0

	if _route.size() < 2:
		_moving = false
		return

	_advance_route()


func _score_destinations(connected: Array[String]) -> String:
	var candidates: Array[Dictionary] = []
	var total_weight: float = 0.0

	for node_id: String in connected:
		if node_id == current_node_id:
			continue

		var path: Array[String] = NetworkManager.get_shortest_path(current_node_id, node_id)
		if path.size() < 2:
			continue

		var node_data: NodeData = NetworkManager.nodes.get(node_id) as NodeData
		if node_data == null:
			continue

		var hops: int = path.size() - 1
		var distance: float = _estimate_route_distance(path)
		var base_value: float = node_data.gold_per_delivery * train_data.capacity
		var distance_bonus: float = 1.0 + (float(hops - 1) * DISTANCE_BONUS_PER_HOP)
		var congestion: int = TrainManager.get_node_traffic(node_id)
		var congestion_mult: float = 1.0 / (1.0 + float(congestion) * CONGESTION_PENALTY)

		var score: float = (base_value * distance_bonus * congestion_mult) / distance

		if score > 0.0:
			var weight: float = score * score
			candidates.append({"id": node_id, "weight": weight})
			total_weight += weight

	if candidates.is_empty():
		return ""

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for c: Dictionary in candidates:
		cumulative += c["weight"] as float
		if roll <= cumulative:
			return c["id"] as String

	return (candidates.back()["id"]) as String


func _estimate_route_distance(path: Array[String]) -> float:
	var total: float = 0.0
	for i: int in range(path.size() - 1):
		var edge: Dictionary = NetworkManager.get_edge_between(path[i], path[i + 1])
		if not edge.is_empty():
			total += edge["length"] as float
	return maxf(total, 0.1)


func _advance_route() -> void:
	_route_index += 1
	if _route_index >= _route.size():
		_plan_route()
		return

	var next_node: String = _route[_route_index]
	_start_moving_to(next_node)


func _start_moving_to(node_id: String) -> void:
	var edge: Dictionary = NetworkManager.get_edge_between(current_node_id, node_id)
	if edge.is_empty():
		_plan_route()
		return

	_current_path = edge.get("path_node") as Path3D
	if _current_path == null or _current_path.curve == null:
		_plan_route()
		return

	_curve_length = _current_path.curve.get_baked_length()
	if _curve_length < 0.01:
		_plan_route()
		return

	_direction_forward = (edge["from"] as String) == current_node_id
	_progress = 0.0
	_moving = true
	_update_position()

	EventBus.train_departed.emit(train_id, current_node_id, node_id)


func _update_position() -> void:
	if _current_path == null or _current_path.curve == null:
		return

	var t: float = _progress if _direction_forward else (1.0 - _progress)
	var offset: float = t * _curve_length
	var pos: Vector3 = _current_path.curve.sample_baked(offset)
	position = pos

	var look_ahead: float
	if _direction_forward:
		look_ahead = minf(offset + 0.5, _curve_length)
	else:
		look_ahead = maxf(offset - 0.5, 0.0)

	var look_pos: Vector3 = _current_path.curve.sample_baked(look_ahead)
	if pos.distance_to(look_pos) > 0.01:
		look_at(look_pos, Vector3.UP)


func _arrive_at_node() -> void:
	_moving = false
	current_node_id = _route[_route_index]
	position = NetworkManager.get_node_position(current_node_id)
	_hops_completed += 1

	var node_data: NodeData = NetworkManager.nodes.get(current_node_id) as NodeData
	if node_data != null:
		var is_final_stop: bool = current_node_id == _destination_id
		var gold: float = node_data.gold_per_delivery * train_data.capacity

		if is_final_stop:
			var distance_bonus: float = 1.0 + (float(_hops_completed - 1) * DISTANCE_BONUS_PER_HOP)
			gold *= distance_bonus
			TrainManager.unregister_destination(_destination_id)
			_destination_id = ""

		GameState.add_gold(gold)
		EventBus.delivery_completed.emit(gold)

	EventBus.train_arrived.emit(train_id, current_node_id)

	var at_destination: bool = _route_index >= _route.size() - 1
	_idle = true

	if at_destination:
		_idle_timer = IDLE_DURATION
		_route.clear()
	else:
		_idle_timer = IDLE_DURATION * 0.3


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _destination_id != "":
			TrainManager.unregister_destination(_destination_id)
