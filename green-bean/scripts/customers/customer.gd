class_name Customer
extends CharacterBody3D

const MOVE_SPEED := 2.0
const ORDER_PATIENCE := 300.0
const PICKUP_PATIENCE := 300.0

enum State { WALKING_TO_REGISTER, WAITING_TO_ORDER, PAYING, WALKING_TO_PICKUP, WAITING_FOR_DRINK, LEAVING }

var state := State.WALKING_TO_REGISTER
var order_data: OrderData = null
var drink_type: DrinkData.DrinkType = DrinkData.DrinkType.POUR_OVER
var cup_size: DrinkData.CupSize = DrinkData.CupSize.TALL
var _payment_amount := 0.0

var _order_patience := ORDER_PATIENCE
var _pickup_patience := PICKUP_PATIENCE
var _target_pos := Vector3.ZERO
var _register_pos := Vector3.ZERO
var _pickup_pos := Vector3.ZERO
var _exit_pos := Vector3.ZERO
var _leave_reason := ""

var _body_mesh: CSGBox3D = null
var _speech_label: Label3D = null
var _patience_bar_bg: CSGBox3D = null
var _patience_bar_fill: CSGBox3D = null

func _ready() -> void:
	_build_visual()
	_randomize_order()

func _build_visual() -> void:
	_body_mesh = CSGBox3D.new()
	_body_mesh.size = Vector3(0.4, 1.6, 0.3)
	_body_mesh.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(randf_range(0.4, 0.9), randf_range(0.3, 0.7), randf_range(0.3, 0.7))
	_body_mesh.material = mat
	add_child(_body_mesh)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.2
	shape.height = 1.6
	col.shape = shape
	col.position.y = 0.8
	add_child(col)

	_speech_label = Label3D.new()
	_speech_label.text = ""
	_speech_label.font_size = 16
	_speech_label.position = Vector3(0, 2.0, 0)
	_speech_label.pixel_size = 0.003
	_speech_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech_label.visible = false
	_speech_label.add_to_group("world_label")
	add_child(_speech_label)

	_patience_bar_bg = CSGBox3D.new()
	_patience_bar_bg.size = Vector3(0.5, 0.05, 0.02)
	_patience_bar_bg.position = Vector3(0, 1.85, 0)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.2, 0.2, 0.2)
	_patience_bar_bg.material = bg_mat
	add_child(_patience_bar_bg)

	_patience_bar_fill = CSGBox3D.new()
	_patience_bar_fill.size = Vector3(0.5, 0.05, 0.03)
	_patience_bar_fill.position = Vector3(0, 1.85, 0)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.2, 0.9, 0.2)
	_patience_bar_fill.material = fill_mat
	add_child(_patience_bar_fill)

func _randomize_order() -> void:
	drink_type = DrinkData.DrinkType.AMERICANO
	cup_size = DrinkData.CupSize.TALL

func setup(register: Vector3, pickup: Vector3, exit: Vector3) -> void:
	_register_pos = register
	_pickup_pos = pickup
	_exit_pos = exit
	_target_pos = _register_pos
	state = State.WALKING_TO_REGISTER

func _physics_process(delta: float) -> void:
	match state:
		State.WALKING_TO_REGISTER:
			_move_toward_target(delta)
			if _at_target():
				state = State.WAITING_TO_ORDER
				_show_order()
		State.WAITING_TO_ORDER:
			_order_patience -= delta
			_update_patience_bar(_order_patience / ORDER_PATIENCE)
			if _order_patience <= 0:
				_leave("impatient_order")
		State.PAYING:
			_order_patience -= delta
			_update_patience_bar(_order_patience / ORDER_PATIENCE)
			if _order_patience <= 0:
				_leave("impatient_order")
		State.WALKING_TO_PICKUP:
			_move_toward_target(delta)
			if _at_target():
				state = State.WAITING_FOR_DRINK
		State.WAITING_FOR_DRINK:
			_pickup_patience -= delta
			_update_patience_bar(_pickup_patience / PICKUP_PATIENCE)
			if _pickup_patience <= 0:
				_leave("impatient_pickup")
		State.LEAVING:
			_move_toward_target(delta)
			if _at_target():
				EventBus.customer_left.emit(self, _leave_reason)
				queue_free()

func _move_toward_target(delta: float) -> void:
	var dir := (_target_pos - global_position)
	dir.y = 0
	if dir.length() > 0.1:
		velocity = dir.normalized() * MOVE_SPEED
	else:
		velocity = Vector3.ZERO
	move_and_slide()

func _at_target() -> bool:
	var dist := (_target_pos - global_position)
	dist.y = 0
	return dist.length() < 0.2

func _show_order() -> void:
	var drink_names := {
		DrinkData.DrinkType.POUR_OVER: "Pour Over",
		DrinkData.DrinkType.AMERICANO: "Americano",
		DrinkData.DrinkType.LATTE: "Latte",
	}
	var size_names := {
		DrinkData.CupSize.SHORT: "Short",
		DrinkData.CupSize.TALL: "Tall",
		DrinkData.CupSize.GRANDE: "Grande",
		DrinkData.CupSize.VENTI: "Venti",
	}
	if _speech_label:
		_speech_label.text = "%s %s" % [size_names[cup_size], drink_names[drink_type]]
		_speech_label.visible = true

func start_paying(price: float) -> void:
	state = State.PAYING
	if price <= 5.0:
		_payment_amount = 5.0
	elif price <= 10.0:
		_payment_amount = 10.0
	else:
		_payment_amount = 20.0
	if _speech_label:
		_speech_label.text = "$%.0f" % _payment_amount
		_speech_label.visible = true

func interact(player: Player) -> void:
	if state == State.PAYING:
		EventBus.cash_collected.emit(self, _payment_amount)
		if _speech_label:
			_speech_label.text = "waiting..."
			_speech_label.visible = true

func order_taken(order: OrderData = null) -> void:
	order_data = order
	_speech_label.visible = false
	state = State.WALKING_TO_PICKUP
	_target_pos = _pickup_pos
	_pickup_patience = PICKUP_PATIENCE

func drink_received() -> void:
	_speech_label.visible = false
	_leave("satisfied")

func matches_drink(order: OrderData) -> bool:
	return order.drink_type == drink_type and order.cup_size == cup_size

func _leave(reason: String) -> void:
	if state == State.LEAVING:
		return
	state = State.LEAVING
	_target_pos = _exit_pos
	_speech_label.visible = false
	_leave_reason = reason

func _update_patience_bar(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if _patience_bar_fill:
		_patience_bar_fill.size.x = 0.5 * ratio
		_patience_bar_fill.position.x = -0.25 * (1.0 - ratio)
		var mat := _patience_bar_fill.material as StandardMaterial3D
		if mat:
			if ratio > 0.5:
				mat.albedo_color = Color(0.2, 0.9, 0.2)
			elif ratio > 0.25:
				mat.albedo_color = Color(0.9, 0.9, 0.2)
			else:
				mat.albedo_color = Color(0.9, 0.2, 0.2)
