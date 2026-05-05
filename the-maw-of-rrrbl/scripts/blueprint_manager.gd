extends Node
class_name BlueprintManager

var blueprints: Array[Dictionary] = []

func save_blueprint(slot: int, placed_pieces: Array[TrackPiece]) -> bool:
	var data: Array[Dictionary] = []
	for piece: TrackPiece in placed_pieces:
		if piece.piece_data == null:
			continue
		data.append({
			"piece_id": piece.piece_data.piece_id,
			"position": _vec3_to_array(piece.global_position),
			"rotation": _vec3_to_array(piece.rotation),
		})

	while blueprints.size() <= slot:
		blueprints.append({})

	blueprints[slot] = {
		"name": "Blueprint %d" % (slot + 1),
		"pieces": data,
	}
	return true

func load_blueprint(slot: int, catalog: PieceCatalog,
		track_builder: TrackBuilder, spark_manager: SparkManager) -> int:
	if not has_blueprint(slot):
		return 0

	var pieces: Array = blueprints[slot].get("pieces", []) as Array
	var placed_count: int = 0

	for entry: Dictionary in pieces:
		var piece_id: String = entry["piece_id"] as String
		var data: TrackPieceData = catalog.get_piece(piece_id)
		if data == null:
			continue
		if not spark_manager.spend(data.spark_cost):
			break

		var piece: TrackPiece = TrackPiece.new()
		track_builder.add_child(piece)
		piece.global_position = _array_to_vec3(entry["position"] as Array)
		piece.rotation = _array_to_vec3(entry["rotation"] as Array)
		piece.setup(data)
		track_builder.placed_pieces.append(piece)
		placed_count += 1

	return placed_count

func has_blueprint(slot: int) -> bool:
	return slot < blueprints.size() and not blueprints[slot].is_empty()

func to_save_data() -> Array[Dictionary]:
	return blueprints.duplicate()

func load_save_data(data: Array) -> void:
	blueprints.clear()
	for entry: Variant in data:
		blueprints.append(entry as Dictionary)

func _vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _array_to_vec3(a: Array) -> Vector3:
	return Vector3(a[0] as float, a[1] as float, a[2] as float)
