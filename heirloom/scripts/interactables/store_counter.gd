extends StaticBody3D

@export var shop_ui_scene: PackedScene = null

var _shop_open := false
var _active_ui: Control = null


func interact(player: Node3D) -> void:
	if _shop_open:
		return

	if player.has_held_item():
		_try_sell(player)
		return

	_open_shop(player)


func _try_sell(player: Node3D) -> void:
	var item: Node3D = player.get_held_item()
	if not item:
		return
	var item_id: String = item.get("item_id") as String
	var price: float = Economy.get_sell_price(item_id)
	if price <= 0.0:
		return

	var discount: float = Economy.get_friendship_discount("earl")
	var final_price: float = price * (1.0 + discount)
	GameState.add_money(final_price)
	EventBus.item_sold.emit(item_id, final_price)
	player.drop_held_item()
	item.queue_free()


func _open_shop(player: Node3D) -> void:
	_shop_open = true
	if shop_ui_scene:
		_active_ui = shop_ui_scene.instantiate() as Control
		_active_ui.connect("shop_closed", _on_shop_closed)
		get_tree().root.add_child(_active_ui)
	player.enter_screen_mode(global_position, global_position + Vector3(0, 1.5, 1.5))


func _on_shop_closed() -> void:
	_shop_open = false
	if _active_ui:
		_active_ui.queue_free()
		_active_ui = null
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player and player.has_method("exit_screen_mode"):
		player.exit_screen_mode()
