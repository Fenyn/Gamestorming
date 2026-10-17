extends StaticBody3D

const TICKET_SPACING := 0.075
const TICKET_REST_Y := 0.21
const MAX_VISIBLE_TICKETS := 5
const SIZE_KEYS := {
	DrinkData.CupSize.SMALL: "small",
	DrinkData.CupSize.MEDIUM: "medium",
	DrinkData.CupSize.LARGE: "large",
	DrinkData.CupSize.EXTRA_LARGE: "extra_large",
}

var _pending_orders: Array[OrderData] = []
var _label: Label3D = null
var _tickets: Array[Node3D] = []

func _ready() -> void:
	add_to_group("station")
	add_to_group("cup_stack")
	EventBus.ticket_printed.connect(_on_ticket_printed)

	_label = StationUtils.create_status_label(self, Vector3(0, 0.25, 0.12))
	_label.text = "[E] Grab cup"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _on_ticket_printed(data: Dictionary) -> void:
	var order: OrderData = data["order"]
	_pending_orders.append(order)
	_update_label()
	_print_ticket(order)

func interact(player: Player) -> void:
	if player.has_held_item():
		return

	var order: OrderData = null
	var size := DrinkData.CupSize.MEDIUM
	if not _pending_orders.is_empty():
		order = _pending_orders.pop_front()
		size = order.cup_size
		_tear_off_ticket()

	var cup := Cup.create(size, order)
	get_tree().current_scene.add_child(cup)
	# The cup comes out of its size's tube, then floats up to the hand.
	cup.global_position = to_global(StationUtils.model_marker(self, "Dispense_" + SIZE_KEYS[size], Vector3(0, 0.3, 0)))
	player.pickup_item(cup)
	_update_label()

func _update_label() -> void:
	if _label:
		if _pending_orders.is_empty():
			_label.text = "[E] Grab cup"
		else:
			_label.text = "%d orders waiting\n[E] Grab cup" % _pending_orders.size()


# ── Ticket rail: printed tickets pop up above the cups, oldest on the left ──

func _print_ticket(order: OrderData) -> void:
	var ticket := Node3D.new()
	ticket.rotation_degrees = Vector3(0, 180, 0)
	ticket.add_child(OrderLabel.build(order, Vector2(0.065, 0.085), 34, 0.0007))
	var rule := Label3D.new()
	rule.text = "- - - - -"
	rule.font_size = 24
	rule.pixel_size = 0.0007
	rule.modulate = Color(0.4, 0.35, 0.3)
	rule.outline_size = 0
	rule.position = Vector3(0, -0.034, 0.001)
	ticket.add_child(rule)
	add_child(ticket)
	_tickets.append(ticket)

	var slot := _tickets.size() - 1
	ticket.position = _ticket_position(slot) + Vector3(0, -0.08, 0)
	ticket.scale = Vector3(1, 0.2, 1)
	ticket.visible = slot < MAX_VISIBLE_TICKETS
	var tween := ticket.create_tween().set_parallel(true)
	ticket.set_meta("tween", tween)
	tween.tween_property(ticket, "position", _ticket_position(slot), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ticket, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _tear_off_ticket() -> void:
	if _tickets.is_empty():
		return
	var ticket: Node3D = _tickets.pop_front()
	_kill_ticket_tween(ticket)
	var tween := ticket.create_tween().set_parallel(true)
	tween.tween_property(ticket, "position:y", ticket.position.y + 0.12, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ticket, "scale", Vector3(0.2, 0.2, 0.2), 0.25)
	tween.chain().tween_callback(ticket.queue_free)
	for i in range(_tickets.size()):
		var t: Node3D = _tickets[i]
		t.visible = i < MAX_VISIBLE_TICKETS
		_kill_ticket_tween(t)
		t.scale = Vector3.ONE
		var slide := t.create_tween()
		t.set_meta("tween", slide)
		slide.tween_property(t, "position", _ticket_position(i), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _kill_ticket_tween(ticket: Node3D) -> void:
	if ticket.has_meta("tween"):
		var old: Tween = ticket.get_meta("tween")
		if old and old.is_valid():
			old.kill()
		ticket.remove_meta("tween")

func _ticket_position(slot: int) -> Vector3:
	var shown := mini(slot, MAX_VISIBLE_TICKETS - 1)
	return Vector3(0.15 - shown * TICKET_SPACING, TICKET_REST_Y, -0.11)
