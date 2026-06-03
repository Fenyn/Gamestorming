extends Area3D

@export var fish_scene: PackedScene = null

const CATCH_CHANCES: Array[Dictionary] = [
	{"id": "fish_common", "name": "Common Fish", "price": 8.0, "weight": 60},
	{"id": "fish_uncommon", "name": "Uncommon Fish", "price": 15.0, "weight": 30},
	{"id": "fish_rare", "name": "Rare Fish", "price": 25.0, "weight": 10},
]


func interact(player: Node3D) -> void:
	if player.has_held_item():
		return
	_catch_fish(player)


func _catch_fish(player: Node3D) -> void:
	var roll: int = randi_range(1, 100)
	var cumulative: int = 0
	var catch_data: Dictionary = CATCH_CHANCES[0]

	for entry: Dictionary in CATCH_CHANCES:
		cumulative += entry["weight"] as int
		if roll <= cumulative:
			catch_data = entry
			break

	if fish_scene:
		var fish: Node3D = fish_scene.instantiate()
		get_parent().add_child(fish)
		fish.global_position = global_position + Vector3(0, 1.0, 0)
		if fish.has_method("set_fish_type"):
			fish.set_fish_type(catch_data["id"] as String, catch_data["name"] as String, catch_data["price"] as float)
		player.pickup_item(fish)
