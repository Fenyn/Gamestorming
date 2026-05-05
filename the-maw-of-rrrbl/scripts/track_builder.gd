extends Node3D
class_name TrackBuilder

## Handles placing track pieces with snap-to-connection logic.
## The player selects a piece type, and it snaps to open connections
## on existing track pieces. Confirm to place.

signal piece_placed(piece: TrackPiece)

const SNAP_DISTANCE: float = 0.5

@export var catalog: PieceCatalog

var spark_manager: SparkManager
var placed_pieces: Array[TrackPiece] = []
var _ghost: Node3D = null
var _ghost_data: TrackPieceData = null
var _ghost_valid: bool = false
var _target_connection: Dictionary = {}
var _ghost_connection_index: int = 0
var _selected_piece_id: String = ""

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
	_set_ghost_transparent(_ghost)
	add_child(_ghost)

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
	_ghost.rotate_y(deg_to_rad(90))
	_update_ghost_snap()

func update_cursor(world_pos: Vector3) -> void:
	if _ghost == null or _ghost_data == null:
		return

	if placed_pieces.is_empty():
		_ghost.global_position = world_pos.snapped(Vector3(0.5, 0.5, 0.5))
		_ghost_valid = true
		_target_connection = {}
		return

	var best_snap: Dictionary = _find_best_snap(world_pos)
	if best_snap.is_empty():
		_ghost.global_position = world_pos.snapped(Vector3(0.5, 0.5, 0.5))
		_ghost_valid = false
		_target_connection = {}
	else:
		_apply_snap(best_snap)
		_ghost_valid = true
		_target_connection = best_snap

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

	if not _target_connection.is_empty():
		var source_piece: TrackPiece = _target_connection["source_piece"] as TrackPiece
		var source_index: int = _target_connection["source_index"] as int
		source_piece.mark_connection_occupied(source_index)
		piece.mark_connection_occupied(_ghost_connection_index)

	placed_pieces.append(piece)
	piece_placed.emit(piece)

	_clear_ghost()
	if not _selected_piece_id.is_empty():
		select_piece(_selected_piece_id)

	return true

func clear_all() -> void:
	for piece: TrackPiece in placed_pieces:
		piece.queue_free()
	placed_pieces.clear()

func _find_best_snap(cursor_pos: Vector3) -> Dictionary:
	var best_dist: float = INF
	var best_result: Dictionary = {}

	for piece: TrackPiece in placed_pieces:
		var open_conns: Array[Dictionary] = piece.get_open_world_connections()
		for conn: Dictionary in open_conns:
			var conn_pos: Vector3 = conn["position"] as Vector3
			var dist: float = cursor_pos.distance_to(conn_pos)
			if dist < SNAP_DISTANCE * 5.0 and dist < best_dist:
				best_dist = dist
				best_result = {
					"source_piece": piece,
					"source_index": conn["index"] as int,
					"source_position": conn_pos,
					"source_direction": conn["direction"] as Vector3,
					"source_height": conn["height_offset"] as float,
				}

	return best_result

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
	_ghost.rotate_y(angle)

	var rotated_offset: Vector3 = _ghost.global_transform.basis * ghost_conn.local_position
	_ghost.global_position = source_pos - rotated_offset

func _clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_ghost_valid = false
	_ghost_connection_index = 0

func _set_ghost_transparent(node: Node) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.5, 1.0, 0.7, 0.4)
			mi.material_override = mat
		_set_ghost_transparent(child)

func _update_ghost_snap() -> void:
	if _ghost == null:
		return
	if not _target_connection.is_empty():
		_apply_snap(_target_connection)
