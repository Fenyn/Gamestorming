extends StaticBody3D

var _pending_orders: Array[OrderData] = []
var _label: Label3D = null

func _ready() -> void:
	add_to_group("station")
	add_to_group("cup_stack")
	EventBus.ticket_printed.connect(_on_ticket_printed)

	_label = Label3D.new()
	_label.text = "CUPS\n[E] Grab cup"
	_label.font_size = 12
	_label.position = Vector3(0, 0.25, 0.12)
	_label.pixel_size = 0.002
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.add_to_group("world_label")
	add_child(_label)

func _on_ticket_printed(data: Dictionary) -> void:
	var order: OrderData = data["order"]
	_pending_orders.append(order)
	_update_label()

func interact(player: Player) -> void:
	if player.has_held_item():
		return

	var order: OrderData = null
	var size := DrinkData.CupSize.TALL
	if not _pending_orders.is_empty():
		order = _pending_orders.pop_front()
		size = order.cup_size

	var cup := Cup.create(size, order)
	get_tree().current_scene.add_child(cup)
	cup.global_position = global_position + Vector3(0, 0.3, 0)
	player.pickup_item(cup)
	_update_label()

func _update_label() -> void:
	if _label:
		if _pending_orders.is_empty():
			_label.text = "CUPS\n[E] Grab cup"
		else:
			_label.text = "CUPS (%d orders)\n[E] Grab cup" % _pending_orders.size()
