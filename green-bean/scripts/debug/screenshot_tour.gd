extends Node

## Screenshot tour of the espresso stand. Not part of the game.
## Sets up customers, tickets, filled cups, a scalding pitcher, a kettle pour and a tip,
## then saves PNGs from fixed camera spots. It unlocks all stations in memory only.
## Run from the green-bean folder:
##   godot --path . --resolution 1280x720 res://scenes/debug/screenshot_tour.tscn -- --out=/some/folder
## Without a GPU (Linux, Xvfb + Mesa software GL), add:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility ...

const SHOP := "res://scenes/shops/espresso_stand.tscn"
var _out := "user://shots"
var _shop: Node3D
var _cam: Camera3D

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	UnlockManager.owned_equipment = ["shot_press", "hot_water_station", "fridge", "steam_station", "syrup_rack", "sauce_station", "mocha_prep", "caramel_prep", "bottle_rack"]
	_shop = (load(SHOP) as PackedScene).instantiate()
	add_child(_shop)
	await _frames(10)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_cam = Camera3D.new()
	_cam.fov = 70
	_shop.add_child(_cam)
	_cam.make_current()
	await _run()
	get_tree().quit()

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _shot(name: String, eye: Vector3, target: Vector3, wait: int = 20) -> void:
	_cam.global_position = eye
	_cam.look_at(target, Vector3.UP)
	await _frames(wait)
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("saved ", name)

func _set_day(progress: float) -> void:
	GameManager.prep_active = false
	GameManager.day_active = true
	GameManager.day_timer = GameManager.DAY_LENGTH * (1.0 - progress)

func _run() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	var stations := {}
	for n in _shop.get_children():
		stations[n.name] = n

	# Customers: one waiting impatiently at the register, one walking up.
	_set_day(0.45)
	var spawner: Node = _shop.get_node("CustomerSpawner")
	var c1: Customer = Customer.new()
	spawner.add_child(c1)
	c1.setup(Vector3(1, 0, 2), Vector3(-1, 0, 2), Vector3(3, 0, 5))
	c1.global_position = Vector3(1, 0, 2)
	c1.state = Customer.State.WAITING_TO_ORDER
	c1._show_order()
	c1._order_patience = Customer.ORDER_PATIENCE * 0.2
	var c2: Customer = Customer.new()
	spawner.add_child(c2)
	c2.setup(Vector3(-1, 0, 2), Vector3(-1, 0, 2), Vector3(3, 0, 5))
	c2.global_position = Vector3(2.2, 0, 3.6)

	# Tickets on the rail.
	for t in [[DrinkData.DrinkType.LATTE, DrinkData.CupSize.LARGE], [DrinkData.DrinkType.AMERICANO, DrinkData.CupSize.MEDIUM], [DrinkData.DrinkType.POUR_OVER, DrinkData.CupSize.SMALL]]:
		var order := OrderData.new(t[0], t[1])
		EventBus.ticket_printed.emit({"order": order, "ticket_code": order.ticket_code})

	# Cups on the counter pad: shot, latte with foam and lid, americano.
	var pad: Node3D = stations["CounterPad"]
	var cup_a := Cup.create(DrinkData.CupSize.SMALL, OrderData.new(DrinkData.DrinkType.MACCHIATO, DrinkData.CupSize.SMALL))
	_shop.add_child(cup_a)
	cup_a.global_position = pad.global_position + Vector3(-0.08, 0.04 + 0.05, 0.05)
	cup_a.set_fill(0.3, Color(0.25, 0.15, 0.05))
	var pitcher := Pitcher.new()
	_shop.add_child(pitcher)
	pitcher.global_position = Vector3(5, 5, 5)
	pitcher.fill_milk()
	pitcher.is_steamed = true
	pitcher.foam_level = 0.6
	var cup_b := Cup.create(DrinkData.CupSize.MEDIUM, OrderData.new(DrinkData.DrinkType.LATTE, DrinkData.CupSize.MEDIUM))
	_shop.add_child(cup_b)
	cup_b.global_position = pad.global_position + Vector3(0.08, 0.04 + 0.06, 0.05)
	cup_b.set_fill(0.3, Color(0.25, 0.15, 0.05))
	cup_b.pour_milk_from(pitcher)
	var cup_c := Cup.create(DrinkData.CupSize.LARGE, OrderData.new(DrinkData.DrinkType.AMERICANO, DrinkData.CupSize.LARGE))
	_shop.add_child(cup_c)
	cup_c.global_position = pad.global_position + Vector3(0.08, 0.04 + 0.07, -0.05)
	cup_c.set_fill(0.85, Color(0.3, 0.2, 0.1))
	cup_c.has_lid = true

	# Steam station scalding a pitcher of milk.
	var steam: Node3D = stations["Steam"]
	var p2 := Pitcher.new()
	_shop.add_child(p2)
	p2.fill_milk()
	steam.receive_item(p2)
	steam._steam_game.steam_phase = SteamMiniGame.SteamPhase.SCALDED
	steam._steam_game.temperature = 80.0
	steam._steam_game.foam_level = 0.5
	steam.state = steam.State.SCALDED

	# Kettle pouring into the pour-over.
	var pour: Node3D = stations["PourOver"]
	var kettle := Kettle.new()
	_shop.add_child(kettle)
	player.pickup_item(kettle)
	StationUtils.start_kettle_pour(player, kettle, pour._dripper_slot.global_position, Vector3(0, 0.09, 0), func() -> bool: return true, Vector3.LEFT)

	# Hover glow on the grinder.
	player._set_overlay(stations["Grinder"], player._hover_material)

	await _frames(30)
	await _shot("01_customer_view", Vector3(0.6, 1.65, 3.4), Vector3(0.2, 1.05, 0.4))
	await _shot("02_barista_back_counter", Vector3(0.0, 1.7, 0.1), Vector3(0.0, 1.0, -1.1))
	await _shot("03_steam_scald", Vector3(-1.2, 1.45, -0.25), Vector3(-1.53, 1.12, -0.6), 60)
	await _shot("04_cups_counter_pad", Vector3(0.55, 1.3, -0.25), Vector3(0.58, 0.98, -0.68))
	await _shot("05_pour_over_stream", Vector3(1.25, 1.4, -0.25), Vector3(1.45, 1.15, -0.68))
	await _shot("06_ticket_rail", Vector3(0.05, 1.45, 0.35), Vector3(0.04, 1.05, 0.97))
	await _shot("11_latte_closeup", Vector3(0.66, 1.08, -0.5), Vector3(0.66, 0.96, -0.63))
	await _shot("14_cups_top_down", Vector3(0.58, 1.35, -0.6), Vector3(0.58, 0.95, -0.66))
	await _shot("12_scalded_milk", Vector3(-1.53, 1.42, -0.42), Vector3(-1.53, 1.12, -0.6))
	await _shot("13_patience_bar", Vector3(1.0, 1.75, 0.9), Vector3(1.0, 1.7, 2.0))
	await _shot("07_grinder_hover", Vector3(0.9, 1.45, -0.3), Vector3(1.15, 1.1, -1.05))

	# Tip at hand-off.
	var hand_off: Node3D = stations["HandOff"]
	Fx.coin_burst(hand_off.global_position + Vector3(0, 0.2, 0))
	Fx.sparkle_burst(hand_off.global_position + Vector3(0, 0.2, 0))
	Fx.float_text(hand_off.global_position + Vector3(0, 0.35, 0), "+$0.92 tip", Fx.COIN_COLOR)
	await _shot("08_tip_coins", Vector3(-0.6, 1.5, 0.2), Vector3(-1.0, 1.15, 1.2), 3)

	# A row of customer styles in front of the outdoor seating.
	var styles := [
		{"hat": "beanie", "glasses": true, "skin": 0},
		{"hat": "cap", "backpack": true, "headphones": true, "skin": 5},
		{"glasses": true, "skin": 8},
		{"headphones": true, "backpack": true, "skin": 2},
		{"hat": "cap", "skin": 6},
	]
	for i in range(styles.size()):
		var style: Dictionary = styles[i]
		var prof := CustomerProfile.generate()
		prof.hat = style.get("hat", "")
		prof.glasses = style.get("glasses", false)
		prof.backpack = style.get("backpack", false)
		prof.headphones = style.get("headphones", false)
		prof.skin_index = style.get("skin", 0)
		var walker := CharacterVisual.new()
		walker.setup(prof)
		_shop.add_child(walker)
		walker.global_position = Vector3(-1.6 + i * 0.85, 0, 4.4)
		walker.rotation.y = 0.35 if i % 2 == 0 else -0.35
		if i == 1:
			walker.hold_in_hand(CharacterVisual.make_phone())
		if i == 3:
			walker.hold_in_hand(CharacterVisual.make_takeaway_cup())
	await _frames(10)
	await _shot("18_customer_styles", Vector3(0.1, 1.55, 7.6), Vector3(0.1, 1.15, 4.4))
	await _shot("19_customer_styles_side", Vector3(2.6, 1.6, 5.8), Vector3(0.0, 1.2, 4.4))

	await _shot("15_customers_close", Vector3(0.0, 1.5, 4.2), Vector3(0.6, 1.0, 2.0))
	await _shot("16_street_wide", Vector3(-3.0, 3.2, 16.5), Vector3(0.0, 0.8, 2.0), 30)
	await _shot("17_street_side", Vector3(11.0, 2.2, 9.0), Vector3(0.0, 1.0, 1.5), 30)

	# Morning and golden hour from outside.
	_set_day(0.0)
	await _shot("09_morning_outside", Vector3(1.8, 1.7, 5.0), Vector3(-0.3, 1.0, 0.0), 30)
	_set_day(0.98)
	await _shot("10_golden_hour_outside", Vector3(1.8, 1.7, 5.0), Vector3(-0.3, 1.0, 0.0), 30)

	# A full register line and a few people waiting at pickup.
	_set_day(0.45)
	for n in spawner.get_children():
		if n is Customer:
			n.queue_free()
	# Remove the style line-up from the earlier shot.
	for n in _shop.get_children():
		if n is CharacterVisual:
			n.queue_free()
	spawner._active_customers.clear()
	spawner._line.clear()
	await _frames(2)
	spawner.max_customers = 8
	var spots: Array[Vector3] = spawner._queue_spots
	for i in range(spots.size()):
		spawner._spawn_customer()
		var c: Customer = spawner._line[i]
		c.global_position = spots[i] + Vector3(0.05, 0, 0.05)
	for i in range(3):
		spawner._spawn_customer()
		var c: Customer = spawner._active_customers[spawner._active_customers.size() - 1]
		c.order_taken(OrderData.new(c.drink_type, c.cup_size))
	await _frames(4)
	for i in range(3):
		var c: Customer = spawner._active_customers[spawner._active_customers.size() - 1 - i]
		c.global_position = c._pickup_pos + Vector3(0.05, 0, 0.05)
	await _frames(90)
	await _shot("20_register_line", Vector3(3.2, 2.2, 6.6), Vector3(0.6, 0.9, 2.4), 10)
	await _shot("21_register_line_barista", Vector3(0.2, 1.7, 0.0), Vector3(1.6, 1.1, 3.0), 10)

