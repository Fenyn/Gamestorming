extends Node3D

## Spawns customers and manages where they stand: a line at the register and
## separate spots at the pickup counter.

const CUSTOMER_SPAWN_INTERVAL_START := 999.0
const CUSTOMER_SPAWN_INTERVAL_PEAK := 999.0
## One customer at a time while testing. The line supports up to one customer per
## queue spot; raise this (and lower the spawn intervals) for real days.
const MAX_CUSTOMERS := 1
const SPAWN_OFFSET := Vector3(3, 0, 4)
const QUEUE_SPACING := 0.85

## Instance copies of the constants, so tests and debug tools can override them.
var max_customers := MAX_CUSTOMERS
var spawn_interval_start := CUSTOMER_SPAWN_INTERVAL_START
var spawn_interval_peak := CUSTOMER_SPAWN_INTERVAL_PEAK

var _spawn_timer := 0.0
var _active_customers: Array[Customer] = []
var _register_pos := Vector3(0.5, 0, 2.5)
var _pickup_pos := Vector3(-1.0, 0, 2.5)
var _exit_pos := Vector3(3, 0, 5)

## Spot 0 is at the register; the rest trail back toward the street.
var _queue_spots: Array[Vector3] = []
var _pickup_spots: Array[Vector3] = []
## Customers in the register line, front first.
var _line: Array[Customer] = []
## Which customer holds each pickup spot (null when free).
var _pickup_owners: Array = []
## Customers waiting for a drink when every pickup spot is taken.
var _pickup_overflow: Array[Customer] = []

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.order_charged.connect(_on_order_charged)
	EventBus.cash_collected.connect(_on_cash_collected)
	EventBus.drink_handed_off.connect(_on_drink_handed_off)

## queue_spots and pickup_spots are optional. Without them a straight line is
## generated behind the register and spots are spread around the pickup point.
func setup(register: Vector3, pickup: Vector3, queue_spots: Array[Vector3] = [], pickup_spots: Array[Vector3] = []) -> void:
	_register_pos = register
	_pickup_pos = pickup
	# Off to the right along the sidewalk, so customers walk in and out of view.
	_exit_pos = register + Vector3(8, 0, 3.5)

	_queue_spots = queue_spots.duplicate()
	if _queue_spots.is_empty():
		for i in range(5):
			_queue_spots.append(register + Vector3(0, 0, QUEUE_SPACING * i))
	_queue_spots[0] = register

	_pickup_spots = pickup_spots.duplicate()
	if _pickup_spots.is_empty():
		for offset in [Vector3.ZERO, Vector3(-0.75, 0, 0.35), Vector3(0.7, 0, 0.5), Vector3(-0.2, 0, 0.9)]:
			_pickup_spots.append(pickup + (offset as Vector3))
	_pickup_owners.clear()
	for i in range(_pickup_spots.size()):
		_pickup_owners.append(null)

func _on_day_started() -> void:
	_spawn_timer = 3.0

func _on_day_ended() -> void:
	pass

func _process(delta: float) -> void:
	_prune_customers()
	_update_line()
	_update_pickup_spots()

	if not GameManager.day_active:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0 and can_spawn():
		_spawn_customer()
		var day_progress := 1.0 - (GameManager.get_time_remaining() / GameManager.DAY_LENGTH)
		var peak := 0.5
		var intensity: float
		if day_progress < peak:
			intensity = day_progress / peak
		else:
			intensity = 1.0 - (day_progress - peak) / (1.0 - peak)
		intensity = clampf(intensity, 0.0, 1.0)
		_spawn_timer = lerpf(spawn_interval_start, spawn_interval_peak, intensity)

func can_spawn() -> bool:
	return _active_customers.size() < max_customers and _line.size() < _queue_spots.size()

func _prune_customers() -> void:
	for i in range(_active_customers.size() - 1, -1, -1):
		if not is_instance_valid(_active_customers[i]):
			_active_customers.remove_at(i)

## Drops customers who left the line (paid, or gave up) and moves everyone
## behind them forward.
func _update_line() -> void:
	for i in range(_line.size() - 1, -1, -1):
		var c: Customer = _line[i]
		if not is_instance_valid(c) or not c.is_in_register_line():
			_line.remove_at(i)
	for i in range(_line.size()):
		var c: Customer = _line[i]
		if c.queue_index != i:
			_assign_queue_spot(c, i)

func _assign_queue_spot(c: Customer, index: int) -> void:
	var slot := mini(index, _queue_spots.size() - 1)
	var spot: Vector3 = _queue_spots[slot]
	# Face the person ahead; the front of the line faces the counter.
	var look: Vector3 = _queue_spots[slot - 1] if slot > 0 else _register_pos + Vector3(0, 0, -1)
	c.assign_queue_spot(index, spot, look)

## Gives every customer heading to pickup their own spot, and frees spots as they leave.
func _update_pickup_spots() -> void:
	for i in range(_pickup_owners.size()):
		var owner = _pickup_owners[i]
		if owner != null and (not is_instance_valid(owner) or not (owner as Customer).is_at_pickup()):
			_pickup_owners[i] = null
	for i in range(_pickup_overflow.size() - 1, -1, -1):
		var waiting: Customer = _pickup_overflow[i]
		if not is_instance_valid(waiting) or not waiting.is_at_pickup():
			_pickup_overflow.remove_at(i)
	for c in _active_customers:
		if not c.is_at_pickup() or _pickup_owners.has(c):
			continue
		var free := _pickup_owners.find(null)
		if free >= 0:
			_pickup_overflow.erase(c)
			_pickup_owners[free] = c
			c.assign_pickup_spot(_pickup_spots[free])
		elif not _pickup_overflow.has(c):
			# More waiting customers than spots: stand loosely behind the pickup
			# point until a spot frees up.
			_pickup_overflow.append(c)
			c.assign_pickup_spot(_pickup_pos + Vector3(randf_range(-1.0, 1.0), 0, randf_range(1.0, 1.6)))

func _spawn_customer() -> void:
	var customer := Customer.new()
	customer.profile = CustomerProfile.generate()
	# Avoid two customers with the same name at once; it's on the cups.
	var tries := 0
	while _name_in_use(customer.profile.display_name) and tries < 10:
		customer.profile.display_name = CustomerProfile.NAMES[randi() % CustomerProfile.NAMES.size()]
		tries += 1
	add_child(customer)
	customer.global_position = _exit_pos
	customer.setup(_register_pos, _pickup_pos, _exit_pos)
	_active_customers.append(customer)
	_line.append(customer)
	_assign_queue_spot(customer, _line.size() - 1)

	EventBus.customer_arrived.emit(customer)

func _name_in_use(display_name: String) -> bool:
	for c in _active_customers:
		if c.profile and c.profile.display_name == display_name:
			return true
	return false

## The order rung up at the register belongs to whoever is at the front of the line.
func _on_order_charged(data: Dictionary) -> void:
	var order: OrderData = data["order"]
	var price := order.base_price
	var front: Customer = null
	if not _line.is_empty() and is_instance_valid(_line[0]) and _line[0].state == Customer.State.WAITING_TO_ORDER:
		front = _line[0]
	if front == null:
		for c in _active_customers:
			if c.state == Customer.State.WAITING_TO_ORDER:
				front = c
				break
	if front:
		front.order_data = order
		order.customer_name = front.profile.display_name
		front.start_paying(price)

func _on_cash_collected(_customer: Node3D, _amount: float) -> void:
	pass

## Hands the drink to the customer who ordered it. Falls back to anyone waiting
## for the same drink, then anyone waiting at all.
func _on_drink_handed_off(data: Dictionary) -> void:
	var order: OrderData = data["order"]
	var stars: float = data.get("stars", 0.0)
	for c in _active_customers:
		if c.is_at_pickup() and c.order_data == order:
			c.drink_received(stars)
			return
	for c in _active_customers:
		if c.is_at_pickup() and c.matches_drink(order):
			c.drink_received(stars)
			return
	for c in _active_customers:
		if c.is_at_pickup():
			c.drink_received(stars)
			return
