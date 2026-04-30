class_name BaseStation
extends StaticBody3D

@export var station_name := ""
var _mini_game: BaseMiniGame = null
var _placed_items: Array[Node3D] = []

func _ready() -> void:
	add_to_group("station")
	for child in get_children():
		if child is BaseMiniGame:
			_mini_game = child
			break

func interact(player: Player) -> void:
	if _mini_game and _mini_game.is_active():
		_mini_game.stop()
		return
	if not check_prerequisites(player):
		return
	if _mini_game:
		_mini_game.start(player)

func check_prerequisites(_player: Player) -> bool:
	return true

func receive_item(item: Node3D) -> bool:
	if not _can_receive(item):
		return false
	_placed_items.append(item)
	item.global_position = _get_item_placement_position()
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	_on_item_received(item)
	return true

func _can_receive(_item: Node3D) -> bool:
	return true

func _get_item_placement_position() -> Vector3:
	return global_position + Vector3(0, 0.2, 0)

func _on_item_received(_item: Node3D) -> void:
	pass

func get_placed_item(index: int = 0) -> Node3D:
	if index < _placed_items.size():
		return _placed_items[index]
	return null

func remove_placed_item(item: Node3D) -> void:
	_placed_items.erase(item)
