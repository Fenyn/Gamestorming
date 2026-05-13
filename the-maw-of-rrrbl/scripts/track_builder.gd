extends Node3D
class_name TrackBuilder

signal piece_placed(piece: TrackPiece)

const SNAP_THRESHOLD: float = 1.5
const COLOR_VALID: Color = Color(0.5, 1.0, 0.7, 0.4)
const COLOR_INVALID: Color = Color(1.0, 0.3, 0.3, 0.4)

@export var catalog: PieceCatalog

var spark_manager: SparkManager
var build_radius: float = 8.0
var placed_pieces: Array[TrackPiece] = []
var anchor_points: Array[Dictionary] = []
var _ghost: Node3D = null
var _ghost_data: TrackPieceData = null
var _ghost_valid: bool = false
var _ghost_color: Color = Color.TRANSPARENT
var _target_connection: Dictionary = {}
var _ghost_connection_index: int = 0
var _selected_piece_id: String = ""
var _rotation_offset: float = 0.0

func select_piece(piece_id: String) -> void:
	_selected_piece_id = piece_id
	_ghost_data = catalog.get_piece(piece_id)

	_clear_ghost()
	if _ghost_data == null:
		return

	var scene: PackedScene = load(_ghost_data.model_path) as PackedScene
	if scene == null:
		return

	_ghost = scene.instantiate() as Node3D
	_ghost.name = "Ghost"
	_apply_ghost_color(COLOR_VALID)
	add_child(_ghost)

	if _ghost_data.spark_cost > 0.0:
		var cost_label: Label3D = Label3D.new()
		cost_label.name = "CostLabel"
		cost_label.text = "-%d" % int(_ghost_data.spark_cost)
		cost_label.font_size = 20
		cost_label.modulate = Color(1.0, 0.85, 0.3, 0.9)
		cost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cost_label.position.y = 1.0
		_ghost.add_child(cost_label)

func cancel_selection() -> void:
	_selected_piece_id = ""
	_ghost_data = null
	_clear_ghost()

func cycle_ghost_connection() -> void:
	if _ghost_data == null:
		return
	_ghost_connection_index = (_ghost_connection_index + 1) % _ghost_data.connections.size()
	_update_ghost_snap()

func rotate_ghost() -> void:
	if _ghost == null:
		return
	_rotation_offset = fmod(_rotation_offset + deg_to_rad(90), TAU)
	if _target_connection.is_empty():
		_ghost.rotation.y = _rotation_offset
	else:
		_apply_snap(_target_connection)

func set_build_radius(radius: float) -> void:
	build_radius = radius

func set_anchor_points(anchors: Array[Dictionary]) -> void:
	anchor_points = anchors

func update_cursor(fallback_pos: Vector3, ray_origin: Vector3, ray_dir: Vector3) -> void:
	if _ghost == null or _ghost_data == null:
		return

	var best_snap: Dictionary = _find_best_snap_on_ray(ray_origin, ray_dir)
	if best_snap.is_empty():
		if fallback_pos == Vector3.INF:
			return
		var in_bounds: bool = Vector2(fallback_pos.x, fallback_pos.z).length() <= build_radius
		_ghost.global_position = fallback_pos.snapped(Vector3(0.5, 0.5, 0.5))
		_ghost.rotation.y = _rotation_offset
		_ghost_valid = in_bounds and placed_pieces.is_empty()
		_target_connection = {}
	else:
		_apply_snap(best_snap)
		var snap_pos: Vector3 = _ghost.global_position
		_ghost_valid = Vector2(snap_pos.x, snap_pos.z).length() <= build_radius
		_target_connection = best_snap

	_apply_ghost_color(COLOR_VALID if _ghost_valid else COLOR_INVALID)

func confirm_placement() -> bool:
	if _ghost == null or _ghost_data == null or not _ghost_valid:
		return false

	if spark_manager and _ghost_data.spark_cost > 0.0:
		if not spark_manager.spend(_ghost_data.spark_cost):
			return false

	var piece: TrackPiece = TrackPiece.new()
	add_child(piece)
	piece.global_transform = _ghost.global_transform
	piece.setup(_ghost_data)

	if not _target_connection.is_empty() and not _target_connection.get("is_anchor", false):
		var source_piece: TrackPiece = _target_connection["source_piece"] as TrackPiece
		var source_index: int = _target_connection["source_index"] as int
		source_piece.mark_connection_occupied(source_index)
		piece.mark_connection_occupied(_ghost_connection_index)
		piece.set_meta("snap_source_piece", source_piece)
		piece.set_meta("snap_source_index", source_index)

	placed_pieces.append(piece)
	piece_placed.emit(piece)

	_clear_ghost()
	if not _selected_piece_id.is_empty():
		select_piece(_selected_piece_id)

	return true

func undo_last() -> void:
	if placed_pieces.is_empty():
		return
	var piece: TrackPiece = placed_pieces.pop_back()
	if spark_manager and piece.piece_data:
		spark_manager.earn(piece.piece_data.spark_cost)
	if piece.has_meta("snap_source_piece"):
		var source: TrackPiece = piece.get_meta("snap_source_piece") as TrackPiece
		var source_index: int = piece.get_meta("snap_source_index") as int
		if is_instance_valid(source):
			source.occupied_connections.erase(source_index)
			source.restore_connection_marker(source_index)
	piece.queue_free()

func clear_all() -> void:
	for piece: TrackPiece in placed_pieces:
		piece.queue_free()
	placed_pieces.clear()

func _find_best_snap_on_ray(ray_origin: Vector3, ray_dir: Vector3) -> Dictionary:
	var best_dist: float = INF
	var best_result: Dictionary = {}

	for piece: TrackPiece in placed_pieces:
		var open_conns: Array[Dictionary] = piece.get_open_world_connections()
		for conn: Dictionary in open_conns:
			var conn_pos: Vector3 = conn["position"] as Vector3
			var dist: float = _point_to_ray_distance(conn_pos, ray_origin, ray_dir)
			if dist < SNAP_THRESHOLD and dist < best_dist:
				best_dist = dist
				best_result = {
					"source_piece": piece,
					"source_index": conn["index"] as int,
					"source_position": conn_pos,
					"source_direction": conn["direction"] as Vector3,
					"source_height": conn["height_offset"] as float,
				}

	for anchor: Dictionary in anchor_points:
		var anchor_pos: Vector3 = anchor["position"] as Vector3
		var dist: float = _point_to_ray_distance(anchor_pos, ray_origin, ray_dir)
		if dist < SNAP_THRESHOLD and dist < best_dist:
			best_dist = dist
			best_result = {
				"is_anchor": true,
				"source_position": anchor_pos,
				"source_direction": anchor["direction"] as Vector3,
				"source_height": 0.0,
			}

	return best_result

func _point_to_ray_distance(point: Vector3, ray_origin: Vector3, ray_dir: Vector3) -> float:
	var to_point: Vector3 = point - ray_origin
	var t: float = to_point.dot(ray_dir)
	if t < 0.0:
		return INF
	var closest: Vector3 = ray_origin + ray_dir * t
	return closest.distance_to(point)

func _apply_snap(snap: Dictionary) -> void:
	if _ghost == null or _ghost_data == null:
		return
	if _ghost_connection_index >= _ghost_data.connections.size():
		_ghost_connection_index = 0

	var ghost_conn: ConnectionPoint = _ghost_data.connections[_ghost_connection_index]
	var source_pos: Vector3 = snap["source_position"] as Vector3
	var source_dir: Vector3 = snap["source_direction"] as Vector3

	var target_dir: Vector3 = -source_dir
	var ghost_local_dir: Vector3 = ghost_conn.local_direction

	var angle: float = atan2(
		ghost_local_dir.cross(target_dir).y,
		ghost_local_dir.dot(target_dir)
	)

	_ghost.rotation = Vector3.ZERO
	_ghost.rotate_y(angle + _rotation_offset)

	var rotated_offset: Vector3 = _ghost.global_transform.basis * ghost_conn.local_position
	_ghost.global_position = source_pos - rotated_offset

func _clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_ghost_valid = false
	_ghost_color = Color.TRANSPARENT
	_ghost_connection_index = 0
	_rotation_offset = 0.0

func _apply_ghost_color(color: Color) -> void:
	if _ghost == null or color == _ghost_color:
		return
	_ghost_color = color
	_set_material_recursive(_ghost, color)

func _set_material_recursive(node: Node, color: Color) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = color
			mi.material_override = mat
		_set_material_recursive(child, color)

func _update_ghost_snap() -> void:
	if _ghost == null:
		return
	if not _target_connection.is_empty():
		_apply_snap(_target_connection)
