extends StaticBody3D

@export var part_slots: Dictionary = {}

var _part_markers: Dictionary = {}


func _ready() -> void:
	_find_markers()
	_init_parts()
	_update_visuals()
	EventBus.part_installed.connect(_on_part_installed)


func _find_markers() -> void:
	var slots_node: Node = get_node_or_null("PartSlots")
	if not slots_node:
		return
	for child: Node in slots_node.get_children():
		if child is Marker3D:
			_part_markers[child.name.to_lower()] = child


func _init_parts() -> void:
	var part_ids: Array[String] = [
		"camaro_engine_block", "camaro_heads", "camaro_intake",
		"camaro_exhaust", "camaro_carburetor", "camaro_transmission",
		"camaro_suspension", "camaro_body_panels", "camaro_interior",
		"camaro_electrical", "camaro_paint",
	]
	for pid: String in part_ids:
		if not GameState.camaro_parts.has(pid):
			GameState.camaro_parts[pid] = false


func get_interact_hint(player: Node3D) -> String:
	if player.has_held_item():
		var item_id: String = player.get_held_item().get("item_id") as String
		if item_id.begins_with("camaro_"):
			if GameState.is_part_installed(item_id):
				return "[E] Already installed"
			if _check_prerequisites(item_id):
				return "[E] Install %s" % (player.get_held_item().get("display_name") as String)
			return "[E] Missing prerequisites"
		return ""
	var installed: int = 0
	for key: String in GameState.camaro_parts:
		if GameState.camaro_parts[key] as bool:
			installed += 1
	return "[E] Inspect Camaro (%d/%d)" % [installed, GameState.camaro_parts.size()]


func interact(player: Node3D) -> void:
	if not player.has_held_item():
		_inspect()
		return

	var item: Node3D = player.get_held_item()
	var item_id: String = item.get("item_id") as String
	if not item_id.begins_with("camaro_"):
		return

	if GameState.is_part_installed(item_id):
		return

	if not _check_prerequisites(item_id):
		return

	player.drop_held_item()
	item.queue_free()
	GameState.install_part(item_id)
	_update_visuals()


func _check_prerequisites(part_id: String) -> bool:
	var prereq_map: Dictionary = {
		"camaro_heads": ["camaro_engine_block"],
		"camaro_intake": ["camaro_heads"],
		"camaro_exhaust": ["camaro_heads"],
		"camaro_carburetor": ["camaro_intake"],
		"camaro_transmission": ["camaro_engine_block"],
		"camaro_interior": ["camaro_body_panels"],
		"camaro_electrical": ["camaro_engine_block", "camaro_interior"],
		"camaro_paint": ["camaro_body_panels", "camaro_interior"],
	}
	var prereqs: Array = prereq_map.get(part_id, []) as Array
	for prereq: String in prereqs:
		if not GameState.is_part_installed(prereq):
			return false
	return true


func _inspect() -> void:
	var installed: int = 0
	var total: int = GameState.camaro_parts.size()
	for key: String in GameState.camaro_parts:
		if GameState.camaro_parts[key] as bool:
			installed += 1
	EventBus.camaro_progress_changed.emit(installed, total)


func _update_visuals() -> void:
	for part_id: String in GameState.camaro_parts:
		var short_name: String = part_id.replace("camaro_", "")
		var marker: Marker3D = _part_markers.get(short_name, null) as Marker3D
		if not marker:
			continue
		var is_installed: bool = GameState.camaro_parts[part_id] as bool
		for child: Node in marker.get_children():
			if child is Node3D:
				(child as Node3D).visible = is_installed


func _on_part_installed(_part_id: String) -> void:
	_update_visuals()
