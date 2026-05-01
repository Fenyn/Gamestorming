extends Node3D

const CUSTOMER_SPAWN_INTERVAL_START := 999.0
const CUSTOMER_SPAWN_INTERVAL_PEAK := 999.0
const MAX_CUSTOMERS := 1
const SPAWN_OFFSET := Vector3(3, 0, 4)

var _spawn_timer := 0.0
var _active_customers: Array[Customer] = []
var _register_pos := Vector3(0.5, 0, 2.5)
var _pickup_pos := Vector3(-1.0, 0, 2.5)
var _exit_pos := Vector3(3, 0, 5)

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.order_charged.connect(_on_order_charged)
	EventBus.cash_collected.connect(_on_cash_collected)
	EventBus.drink_handed_off.connect(_on_drink_handed_off)

func setup(register: Vector3, pickup: Vector3) -> void:
	_register_pos = register
	_pickup_pos = pickup
	_exit_pos = register + Vector3(2, 0, 3)

func _on_day_started() -> void:
	_spawn_timer = 3.0

func _on_day_ended() -> void:
	pass

func _process(delta: float) -> void:
	if not GameManager.day_active:
		return

	_active_customers = _active_customers.filter(func(c): return is_instance_valid(c))

	_spawn_timer -= delta
	if _spawn_timer <= 0 and _active_customers.size() < MAX_CUSTOMERS:
		_spawn_customer()
		var day_progress := 1.0 - (GameManager.get_time_remaining() / GameManager.DAY_LENGTH)
		var peak := 0.5
		var intensity: float
		if day_progress < peak:
			intensity = day_progress / peak
		else:
			intensity = 1.0 - (day_progress - peak) / (1.0 - peak)
		intensity = clampf(intensity, 0.0, 1.0)
		_spawn_timer = lerpf(CUSTOMER_SPAWN_INTERVAL_START, CUSTOMER_SPAWN_INTERVAL_PEAK, intensity)

func _spawn_customer() -> void:
	var customer := Customer.new()
	add_child(customer)
	customer.global_position = _exit_pos
	customer.setup(_register_pos, _pickup_pos, _exit_pos)
	_active_customers.append(customer)

	EventBus.customer_arrived.emit(customer)

func _on_order_charged(data: Dictionary) -> void:
	var order: OrderData = data["order"]
	var price := order.base_price
	for c in _active_customers:
		if is_instance_valid(c) and c.state == Customer.State.WAITING_TO_ORDER:
			if c.matches_drink(order):
				c.order_data = order
				c.start_paying(price)
				return
	for c in _active_customers:
		if is_instance_valid(c) and c.state == Customer.State.WAITING_TO_ORDER:
			c.order_data = order
			c.start_paying(price)
			return

func _on_cash_collected(customer: Node3D, _amount: float) -> void:
	pass

func _on_drink_handed_off(data: Dictionary) -> void:
	var order: OrderData = data["order"]
	var stars: float = data.get("stars", 0.0)
	for c in _active_customers:
		if is_instance_valid(c) and c.state == Customer.State.WAITING_FOR_DRINK:
			if c.matches_drink(order):
				c.drink_received(stars)
				return
	for c in _active_customers:
		if is_instance_valid(c) and c.state == Customer.State.WAITING_FOR_DRINK:
			c.drink_received(stars)
			return
