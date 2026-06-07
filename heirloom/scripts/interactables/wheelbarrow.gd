extends CharacterBody3D

const PUSH_SPEED := 3.0
const MAX_ITEMS := 8

var _items: Array[Node3D] = []
var _being_pushed := false
var _pusher: Node3D = null

@onready var _load_area: Area3D = $LoadArea


func _ready() -> void:
	add_to_group("carriable")


func get_interact_hint(player: Node3D) -> String:
	if _being_pushed:
		return "[E] Release wheelbarrow"
	if player.has_held_item():
		if _items.size() < MAX_ITEMS:
			return "[Click] Load item (%d/%d)" % [_items.size(), MAX_ITEMS]
		return "Wheelbarrow full (%d/%d)" % [_items.size(), MAX_ITEMS]
	if not _items.is_empty():
		return "[E] Push wheelbarrow (%d items)" % _items.size()
	return "[E] Push wheelbarrow"


func interact(player: Node3D) -> void:
	if _being_pushed:
		_release(player)
	else:
		_grab(player)


func receive_item(item: Node3D) -> bool:
	if _items.size() >= MAX_ITEMS:
		return false
	_load_item(item)
	return true


func _grab(player: Node3D) -> void:
	if player.has_held_item():
		return
	_being_pushed = true
	_pusher = player


func _release(_player: Node3D) -> void:
	_being_pushed = false
	_pusher = null
	velocity = Vector3.ZERO


func _load_item(item: Node3D) -> void:
	_items.append(item)
	if item is RigidBody3D:
		(item as RigidBody3D).freeze = true
	for child: Node in item.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	item.get_parent().remove_child(item)
	add_child(item)
	_arrange_items()


func _arrange_items() -> void:
	for i: int in _items.size():
		if not is_instance_valid(_items[i]):
			continue
		var row: int = i / 2
		var col: int = i % 2
		_items[i].position = Vector3(
			float(col) * 0.25 - 0.125,
			0.4 + float(row) * 0.15,
			float(row) * 0.15 - 0.15)


func unload_all() -> Array[Node3D]:
	var unloaded: Array[Node3D] = []
	for item: Node3D in _items:
		if not is_instance_valid(item):
			continue
		remove_child(item)
		unloaded.append(item)
	_items.clear()
	return unloaded


func sell_all() -> float:
	var total: float = 0.0
	var discount: float = Economy.get_friendship_discount("earl")
	for item: Node3D in _items:
		if not is_instance_valid(item):
			continue
		var price: float = item.get("sell_price") as float
		if price > 0.0:
			total += price * (1.0 + discount)
			EventBus.item_sold.emit(item.get("item_id") as String, price)
		item.queue_free()
	_items.clear()
	if total > 0.0:
		GameState.add_money(total)
	return total


func get_item_count() -> int:
	return _items.size()


func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float
	if not is_on_floor():
		velocity.y -= gravity * delta

	if _being_pushed and _pusher and is_instance_valid(_pusher):
		var dir: Vector3 = -_pusher.global_transform.basis.z
		dir.y = 0.0
		dir = dir.normalized()
		velocity.x = dir.x * PUSH_SPEED
		velocity.z = dir.z * PUSH_SPEED
		global_position.y = _pusher.global_position.y
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		if _being_pushed and (not _pusher or not is_instance_valid(_pusher)):
			_being_pushed = false
			_pusher = null

	move_and_slide()
