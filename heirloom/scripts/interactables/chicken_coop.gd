extends StaticBody3D

@export var chicken_scene: PackedScene = null
@export var max_chickens: int = 6
@export var spawn_radius: float = 3.0

var _chickens: Array[Node3D] = []


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)

	if GameState.is_upgrade_complete("chicken_coop"):
		_spawn_initial_flock()


func get_interact_hint(player: Node3D) -> String:
	if not GameState.is_upgrade_complete("chicken_coop"):
		return ""

	var chicken_count: int = GameState.inventory.get("chicken_purchased", 0) as int
	if _chickens.is_empty() and chicken_count <= 0:
		return "Coop (buy chickens at store)"

	if player.has_held_item():
		var held: Node3D = player.get_held_item()
		if held.get("item_id") == "chicken_purchase":
			if _chickens.size() < max_chickens:
				return "[E] Release chicken (%d/%d)" % [_chickens.size(), max_chickens]
			return "Coop full (%d/%d)" % [_chickens.size(), max_chickens]

	var hungry: int = 0
	for c: Node3D in _chickens:
		if is_instance_valid(c) and c.has_method("is_hungry") and c.is_hungry():
			hungry += 1

	if hungry > 0:
		return "[E] Coop: %d chickens (%d hungry)" % [_chickens.size(), hungry]
	return "[E] Coop: %d chickens (fed)" % _chickens.size()


func interact(player: Node3D) -> void:
	if not GameState.is_upgrade_complete("chicken_coop"):
		return

	var held: Node3D = player.get_held_item() as Node3D
	if held and held.get("item_id") == "chicken_purchase":
		_add_chicken(player)
		return


func _add_chicken(player: Node3D) -> void:
	if _chickens.size() >= max_chickens:
		return

	var crate: Node3D = player.get_held_item()
	player.drop_held_item()
	if is_instance_valid(crate):
		crate.queue_free()

	_spawn_chicken()


func _spawn_initial_flock() -> void:
	var count: int = GameState.inventory.get("chicken_count", 0) as int
	for i: int in count:
		_spawn_chicken()


func _spawn_chicken() -> void:
	if not chicken_scene:
		return

	var chicken: Node3D = chicken_scene.instantiate()
	get_parent().add_child(chicken)
	var angle: float = randf() * TAU
	var dist: float = randf_range(1.0, spawn_radius)
	chicken.global_position = global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

	if chicken.has_method("setup"):
		chicken.setup(global_position, 0.8)

	chicken.add_to_group("chicken")
	_chickens.append(chicken)

	GameState.inventory["chicken_count"] = _chickens.size()


func _on_day_started(_day: int) -> void:
	if not GameState.is_upgrade_complete("chicken_coop"):
		return

	_clean_dead()

	# Let the feeder distribute food, then each chicken processes the new day
	var feeders: Array[Node] = get_tree().get_nodes_in_group("chicken_feeder")
	for feeder: Node in feeders:
		if feeder.has_method("consume_daily"):
			feeder.consume_daily()

	for chicken: Node3D in _chickens:
		if is_instance_valid(chicken) and chicken.has_method("on_new_day"):
			chicken.on_new_day()

	GameState.inventory["chicken_count"] = _chickens.size()


func _clean_dead() -> void:
	var alive: Array[Node3D] = []
	for c: Node3D in _chickens:
		if is_instance_valid(c):
			alive.append(c)
	_chickens = alive
