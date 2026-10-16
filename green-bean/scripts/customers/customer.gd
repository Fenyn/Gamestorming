class_name Customer
extends CharacterBody3D

const MOVE_SPEED := 2.0
const CHARACTER_SCENE := preload("res://assets/models/characters/characterMedium.fbx")
const IDLE_ANIM_SCENE := preload("res://assets/models/characters/idle.fbx")
const RUN_ANIM_SCENE := preload("res://assets/models/characters/run.fbx")
const SKIN_PATH := "res://assets/models/characters/skins/customer_%02d.png"
const SKIN_COUNT := 10
# characterMedium.fbx imports 3.76 units tall; this makes customers 1.7 m.
const CHARACTER_SCALE := 0.4516
# There is no walk animation in the pack, so walking is the run played slowly.
const WALK_ANIM_SPEED := 0.55
const ANIM_IDLE := "customer/idle"
const ANIM_WALK := "customer/run"

const ORDER_PATIENCE := 300.0
const PICKUP_PATIENCE := 300.0

enum State { WALKING_TO_REGISTER, WAITING_TO_ORDER, PAYING, WALKING_TO_PICKUP, WAITING_FOR_DRINK, LEAVING }

var state := State.WALKING_TO_REGISTER
var order_data: OrderData = null
var drink_type: DrinkData.DrinkType = DrinkData.DrinkType.POUR_OVER
var cup_size: DrinkData.CupSize = DrinkData.CupSize.MEDIUM
var syrup_type: int = -1
var sauce_type: int = -1
var _payment_amount := 0.0

var _order_patience := ORDER_PATIENCE
var _pickup_patience := PICKUP_PATIENCE
var _target_pos := Vector3.ZERO
var _register_pos := Vector3.ZERO
var _pickup_pos := Vector3.ZERO
var _exit_pos := Vector3.ZERO
var _leave_reason := ""
var _warned_impatient := false

static var _anim_library: AnimationLibrary = null
static var _skin_materials: Array[StandardMaterial3D] = []

var _anim_player: AnimationPlayer = null
var _speech_label: Label3D = null
var _patience_bar_bg: CSGBox3D = null
var _patience_bar_fill: CSGBox3D = null
var _visual_root: Node3D = null
var _anim_time := 0.0
var _patience_ratio := 1.0
var _bar_shake := 0.0

func _ready() -> void:
	_build_visual()
	_randomize_order()

func _build_visual() -> void:
	# Body parts hang off a root node so walking can bob and lean them
	# without moving the collision shape.
	_visual_root = Node3D.new()
	add_child(_visual_root)
	_anim_time = randf() * TAU

	# Kenney animated character with a random skin. Faces +Z like the rest of the code expects.
	var character: Node3D = CHARACTER_SCENE.instantiate()
	character.scale = Vector3.ONE * CHARACTER_SCALE
	_visual_root.add_child(character)
	var skin := _get_skin_material(randi() % SKIN_COUNT)
	for node in character.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = skin
	_anim_player = AnimationPlayer.new()
	character.add_child(_anim_player)
	_anim_player.add_animation_library("customer", _get_anim_library())
	_anim_player.play(ANIM_IDLE)
	_anim_player.seek(randf() * 1.0, true)

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

const SYRUP_CHANCE := 0.3
const SAUCE_CHANCE := 0.15

func _randomize_order() -> void:
	var available_drinks := UnlockManager.get_menu_drinks()
	if available_drinks.is_empty():
		available_drinks = [DrinkData.DrinkType.POUR_OVER]
	drink_type = available_drinks[randi() % available_drinks.size()] as DrinkData.DrinkType

	var available_sizes := UnlockManager.owned_sizes.duplicate()
	if available_sizes.is_empty():
		available_sizes = [DrinkData.CupSize.SMALL]
	cup_size = available_sizes[randi() % available_sizes.size()] as DrinkData.CupSize

	var available_syrups := UnlockManager.owned_syrups.duplicate()
	if not available_syrups.is_empty() and randf() < SYRUP_CHANCE:
		syrup_type = available_syrups[randi() % available_syrups.size()]
	else:
		syrup_type = -1

	if DrinkData.has_step(drink_type, DrinkData.Step.ADD_SAUCE):
		sauce_type = DrinkData.SauceType.MOCHA
	else:
		var available_sauces := UnlockManager.owned_sauces.duplicate()
		if not available_sauces.is_empty() and randf() < SAUCE_CHANCE:
			sauce_type = available_sauces[randi() % available_sauces.size()]
		else:
			sauce_type = -1

func setup(register: Vector3, pickup: Vector3, exit: Vector3) -> void:
	_register_pos = register
	_pickup_pos = pickup
	_exit_pos = exit
	_target_pos = _register_pos
	state = State.WALKING_TO_REGISTER

func _process(delta: float) -> void:
	_animate(delta)

func _animate(delta: float) -> void:
	if _visual_root == null:
		return
	var moving := velocity.length() > 0.1
	_anim_time += delta * (10.0 if moving else 2.0)

	# Face the walk direction, or the player while waiting at the counter.
	var face_dir := Vector3.ZERO
	if moving:
		face_dir = velocity
	elif state == State.WAITING_TO_ORDER or state == State.PAYING or state == State.WAITING_FOR_DRINK:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player:
			face_dir = player.global_position - global_position
	face_dir.y = 0.0
	if face_dir.length() > 0.05:
		var target_yaw := atan2(face_dir.x, face_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-8.0 * delta))

	if _anim_player:
		var wanted := ANIM_WALK if moving else ANIM_IDLE
		if _anim_player.current_animation != wanted:
			_anim_player.play(wanted, 0.25)
		_anim_player.speed_scale = WALK_ANIM_SPEED if moving else 1.0
	if moving:
		_visual_root.rotation.z = 0.0
	else:
		# Impatient customers sway from side to side.
		var impatience := clampf((0.35 - _patience_ratio) / 0.35, 0.0, 1.0)
		_visual_root.rotation.z = sin(_anim_time * 3.0) * 0.04 * impatience

	if _patience_bar_fill and _patience_bar_bg:
		_bar_shake = sin(Time.get_ticks_msec() * 0.06) * 0.012 if _patience_ratio < 0.25 else 0.0
		_patience_bar_bg.position.x = _bar_shake
		_patience_bar_fill.position.x = -0.25 * (1.0 - _patience_ratio) + _bar_shake

func _physics_process(delta: float) -> void:
	match state:
		State.WALKING_TO_REGISTER:
			_move_toward_target(delta)
			if _at_target():
				state = State.WAITING_TO_ORDER
				_show_order()
				SoundManager.play("customer_arrive")
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
	if _speech_label:
		var parts: Array[String] = [DrinkData.get_size_name(cup_size)]
		if syrup_type >= 0:
			parts.append(DrinkData.get_syrup_name(syrup_type as DrinkData.SyrupType))
		if sauce_type >= 0 and not DrinkData.has_step(drink_type, DrinkData.Step.ADD_SAUCE):
			parts.append(DrinkData.get_sauce_name(sauce_type as DrinkData.SauceType))
		parts.append(DrinkData.get_drink_name(drink_type))
		_speech_label.text = " ".join(parts)
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
		SoundManager.play("cash_collect")
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

func drink_received(stars: float = 0.0) -> void:
	if _speech_label and stars > 0.0:
		_speech_label.text = "%.1f / 5" % stars
		_speech_label.visible = true
	else:
		_speech_label.visible = false
	_leave("satisfied")

func matches_drink(order: OrderData) -> bool:
	return order.drink_type == drink_type and order.cup_size == cup_size and order.requested_syrup == syrup_type and order.requested_sauce == sauce_type

func _leave(reason: String) -> void:
	if state == State.LEAVING:
		return
	state = State.LEAVING
	_target_pos = _exit_pos
	_speech_label.visible = false
	_leave_reason = reason
	if reason == "satisfied":
		SoundManager.play("customer_happy")
	else:
		SoundManager.play("customer_angry")

func _update_patience_bar(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio < 0.25 and not _warned_impatient:
		_warned_impatient = true
		SoundManager.play("customer_impatient")
	_patience_ratio = ratio
	if _patience_bar_fill:
		_patience_bar_fill.size.x = 0.5 * ratio
		_patience_bar_fill.position.x = -0.25 * (1.0 - ratio) + _bar_shake
		var mat := _patience_bar_fill.material as StandardMaterial3D
		if mat:
			# Smooth green -> yellow -> red instead of three hard steps.
			var green := Color(0.2, 0.9, 0.2)
			var yellow := Color(0.95, 0.85, 0.2)
			var red := Color(0.95, 0.2, 0.15)
			if ratio > 0.5:
				mat.albedo_color = yellow.lerp(green, (ratio - 0.5) / 0.5)
			else:
				mat.albedo_color = red.lerp(yellow, ratio / 0.5)
			if ratio < 0.25:
				mat.emission_enabled = true
				mat.emission = red * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
			else:
				mat.emission_enabled = false


static func _get_skin_material(index: int) -> StandardMaterial3D:
	if _skin_materials.is_empty():
		for i in range(SKIN_COUNT):
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = load(SKIN_PATH % (i + 1))
			mat.roughness = 0.9
			_skin_materials.append(mat)
	return _skin_materials[index % _skin_materials.size()]

## Idle and run come from separate FBX files that share the character's skeleton.
## Copy their animations into one looping library, once.
static func _get_anim_library() -> AnimationLibrary:
	if _anim_library:
		return _anim_library
	_anim_library = AnimationLibrary.new()
	_anim_library.add_animation("idle", _extract_animation(IDLE_ANIM_SCENE, "Idle"))
	_anim_library.add_animation("run", _extract_animation(RUN_ANIM_SCENE, "Run"))
	return _anim_library

static func _extract_animation(scene: PackedScene, name_suffix: String) -> Animation:
	var root := scene.instantiate()
	var found: Animation = null
	for node in root.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for anim_name in player.get_animation_list():
			if String(anim_name).ends_with(name_suffix):
				found = player.get_animation(anim_name).duplicate() as Animation
	root.free()
	if found == null:
		push_warning("Customer: no '%s' animation found" % name_suffix)
		return Animation.new()
	found.loop_mode = Animation.LOOP_LINEAR
	return found
