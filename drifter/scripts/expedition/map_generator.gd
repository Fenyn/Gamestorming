class_name MapGenerator

const ROWS: int = 5
const MIN_COLS: int = 2
const MAX_COLS: int = 3

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func generate() -> Array[Array]:
	_rng.randomize()
	var map: Array[Array] = []

	for row: int in ROWS:
		var nodes: Array[MapNodeData] = []
		var col_count: int = _rng.randi_range(MIN_COLS, MAX_COLS)

		if row == 0:
			col_count = _rng.randi_range(2, 3)
		elif row == ROWS - 1:
			col_count = 1

		for col: int in col_count:
			var node := MapNodeData.new()
			node.row = row
			node.column = col
			node.type = _pick_type(row)
			nodes.append(node)

		map.append(nodes)

	_ensure_elite(map)
	_connect_rows(map)
	return map


static func _pick_type(row: int) -> MapNodeData.NodeType:
	if row == ROWS - 1:
		return MapNodeData.NodeType.APEX
	if row == 0:
		return MapNodeData.NodeType.ENCOUNTER

	var roll: float = _rng.randf()
	if row == ROWS - 2:
		if roll < 0.5:
			return MapNodeData.NodeType.SHELTER
		return MapNodeData.NodeType.ENCOUNTER

	if roll < 0.45:
		return MapNodeData.NodeType.ENCOUNTER
	elif roll < 0.65:
		return MapNodeData.NodeType.ELITE
	elif roll < 0.80:
		return MapNodeData.NodeType.TRADER
	elif roll < 0.90:
		return MapNodeData.NodeType.SHELTER
	else:
		return MapNodeData.NodeType.ANOMALY


static func _ensure_elite(map: Array[Array]) -> void:
	var has_elite: bool = false
	for row: Array in map:
		for node: MapNodeData in row:
			if node.type == MapNodeData.NodeType.ELITE:
				has_elite = true
				break
		if has_elite:
			break

	if has_elite:
		return

	var eligible_rows: Array[int] = []
	for row: int in range(1, ROWS - 2):
		eligible_rows.append(row)

	if eligible_rows.is_empty():
		return

	var target_row: int = eligible_rows[_rng.randi_range(0, eligible_rows.size() - 1)]
	var target_col: int = _rng.randi_range(0, (map[target_row] as Array).size() - 1)
	var node: MapNodeData = map[target_row][target_col] as MapNodeData
	node.type = MapNodeData.NodeType.ELITE


static func _connect_rows(map: Array[Array]) -> void:
	for row: int in map.size() - 1:
		var current_row: Array = map[row]
		var next_row: Array = map[row + 1]

		for node: MapNodeData in current_row:
			var target_col: int = clampi(node.column, 0, next_row.size() - 1)
			var target: Vector2i = Vector2i(row + 1, target_col)
			if target not in node.connections:
				node.connections.append(target)

		for col: int in next_row.size():
			var has_incoming: bool = false
			for node: MapNodeData in current_row:
				for conn: Vector2i in node.connections:
					if conn == Vector2i(row + 1, col):
						has_incoming = true
						break
				if has_incoming:
					break
			if not has_incoming:
				var source_col: int = clampi(col, 0, current_row.size() - 1)
				var target: Vector2i = Vector2i(row + 1, col)
				if target not in current_row[source_col].connections:
					current_row[source_col].connections.append(target)

		if current_row.size() > 1 and next_row.size() > 1:
			var extra_idx: int = _rng.randi_range(0, current_row.size() - 1)
			var extra_target: int = _rng.randi_range(0, next_row.size() - 1)
			var target: Vector2i = Vector2i(row + 1, extra_target)
			if target not in current_row[extra_idx].connections:
				current_row[extra_idx].connections.append(target)
