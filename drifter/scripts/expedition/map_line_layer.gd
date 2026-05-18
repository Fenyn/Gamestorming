class_name MapLineLayer
extends Control

var map_ref: ExpeditionMap


func _draw() -> void:
	if not map_ref:
		return

	var map: Array[Array] = RunState.map_nodes
	for row: int in map.size():
		for col: int in (map[row] as Array).size():
			var node_data: MapNodeData = map[row][col] as MapNodeData
			var from_coord: Vector2i = Vector2i(row, col)
			var from_btn: Button = map_ref.get_node_button(from_coord)
			if not from_btn:
				continue
			var from_center: Vector2 = from_btn.position + from_btn.size / 2.0

			for target: Vector2i in node_data.connections:
				var to_btn: Button = map_ref.get_node_button(target)
				if not to_btn:
					continue
				var to_center: Vector2 = to_btn.position + to_btn.size / 2.0

				var line_color: Color = Color(0.25, 0.35, 0.45, 0.6)
				if from_coord in RunState.visited_nodes:
					if target in RunState.visited_nodes:
						line_color = Color(0.4, 0.8, 0.9, 0.8)

				draw_line(from_center, to_center, line_color, 2.0, true)
