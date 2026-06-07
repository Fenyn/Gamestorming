extends StaticBody3D

const FEED_RANGE := 3.0
const FEED_PER_FOOD := 0.5

var _food_level: float = 0.0


func _ready() -> void:
	add_to_group("chicken_feeder")


func get_interact_hint(player: Node3D) -> String:
	if not GameState.is_upgrade_complete("chicken_coop"):
		return ""
	var held: Node3D = player.get_held_item() as Node3D
	if held and held.has_method("is_food") and held.is_food():
		return "[E] Fill feeder with %s" % (held.get("display_name") as String)
	if _food_level > 0.0:
		return "Feeder (%.0f%% full)" % (_food_level * 100.0)
	return "Feeder (empty — hold food to fill)"


func interact(player: Node3D) -> void:
	if not GameState.is_upgrade_complete("chicken_coop"):
		return

	var held: Node3D = player.get_held_item() as Node3D
	if not held or not held.has_method("is_food") or not held.is_food():
		return

	_food_level = clampf(_food_level + FEED_PER_FOOD, 0.0, 1.0)
	player.drop_held_item()
	held.queue_free()

	_feed_nearby_chickens()


func _feed_nearby_chickens() -> void:
	for node: Node in get_tree().get_nodes_in_group("chicken"):
		var chicken: Node3D = node as Node3D
		if not chicken.has_method("is_hungry"):
			continue
		var dist: float = global_position.distance_to(chicken.global_position)
		if dist > FEED_RANGE:
			continue
		if chicken.is_hungry() and _food_level > 0.0:
			chicken.feed(0.4)
			_food_level = clampf(_food_level - 0.1, 0.0, 1.0)


func consume_daily() -> void:
	var chickens: Array[Node] = get_tree().get_nodes_in_group("chicken")
	for node: Node in chickens:
		var chicken: Node3D = node as Node3D
		if not chicken.has_method("is_hungry"):
			continue
		var dist: float = global_position.distance_to(chicken.global_position)
		if dist > FEED_RANGE * 2.0:
			continue
		if _food_level > 0.0:
			chicken.feed(0.3)
			_food_level = clampf(_food_level - 0.08, 0.0, 1.0)
