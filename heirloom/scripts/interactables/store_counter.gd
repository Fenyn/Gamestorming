extends StaticBody3D

@export var shop_ui_scene: PackedScene = null

var _shop_open := false
var _active_ui: Control = null


func get_interact_hint(player: Node3D) -> String:
	if player.has_held_item():
		var held: Node3D = player.get_held_item()
		if held.has_method("get_item_count") and held.get_item_count() > 0:
			return "[E] Sell cart (%d items)" % held.get_item_count()
		var price: float = held.get("sell_price") as float
		if price > 0.0:
			return "[E] Sell ($%.2f)" % price
		return "[E] Shop"
	if not _is_store_open():
		return "Store closed (opens 7 AM)"
	return "[E] Shop"


func interact(player: Node3D) -> void:
	if _shop_open:
		return

	if player.has_held_item():
		var held: Node3D = player.get_held_item()
		if held.has_method("sell_all"):
			var total: float = held.sell_all()
			return
		_try_sell(player)
		return

	_open_shop(player)


func _try_sell(player: Node3D) -> void:
	var item: Node3D = player.get_held_item()
	if not item:
		return
	var price: float = item.get("sell_price") as float
	if price <= 0.0:
		return

	var discount: float = Economy.get_friendship_discount("earl")
	var final_price: float = price * (1.0 + discount)
	GameState.add_money(final_price)
	EventBus.item_sold.emit(item.get("item_id") as String, final_price)
	player.drop_held_item()
	item.queue_free()


func receive_item(item: Node3D) -> bool:
	var price: float = item.get("sell_price") as float
	if price <= 0.0:
		return false
	var discount: float = Economy.get_friendship_discount("earl")
	GameState.add_money(price * (1.0 + discount))
	EventBus.item_sold.emit(item.get("item_id") as String, price)
	item.queue_free()
	return true


func _is_store_open() -> bool:
	var earl: Node = get_tree().get_first_node_in_group("store_npc")
	if earl and earl.has_method("is_available"):
		return earl.is_available()
	var hour: int = TimeManager.current_hour % 24
	return hour >= 7 and hour < 20


func _open_shop(player: Node3D) -> void:
	if not _is_store_open():
		return
	_shop_open = true
	if shop_ui_scene:
		_active_ui = shop_ui_scene.instantiate() as Control
		_active_ui.connect("shop_closed", _on_shop_closed)
		_active_ui.set("_store_position", global_position)
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
