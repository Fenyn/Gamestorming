extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

const BOTTLE_COUNT := 3

const STATION_EQUIPMENT_MAP := {
	"Aeropress": "aeropress",
	"HotWater": "hot_water_station",
	"Fridge": "fridge",
	"Steam": "steam_station",
	"VanillaSyrup": "syrup_rack",
	"MochaSauce": "sauce_station",
	"CaramelSauce": "sauce_station",
	"MochaPrep": "mocha_prep",
	"CaramelPrep": "caramel_prep",
	"BottleRack": "bottle_rack",
}

func _ready() -> void:
	_spawn_player()
	_setup_customers()
	_gate_stations()
	_spawn_sauce_bottles()
	GameManager.start_prep()

func _spawn_player() -> void:
	var spawn := $PlayerSpawn as Marker3D
	var player := PLAYER_SCENE.instantiate()
	player.position = spawn.position
	add_child(player)

func _setup_customers() -> void:
	var spawner := Node3D.new()
	spawner.set_script(load("res://scripts/customers/customer_spawner.gd"))
	spawner.name = "CustomerSpawner"
	add_child(spawner)
	var reg_pos := ($RegisterPos as Marker3D).position
	var pickup_pos := ($PickupPos as Marker3D).position
	spawner.setup(reg_pos, pickup_pos)

func _gate_stations() -> void:
	for node_name in STATION_EQUIPMENT_MAP:
		var equip_id: String = STATION_EQUIPMENT_MAP[node_name]
		var node := get_node_or_null(node_name)
		if node:
			if equip_id in UnlockManager.owned_equipment:
				node.visible = true
				node.process_mode = Node.PROCESS_MODE_INHERIT
			else:
				node.visible = false
				node.process_mode = Node.PROCESS_MODE_DISABLED

func _spawn_sauce_bottles() -> void:
	if "sauce_station" not in UnlockManager.owned_equipment:
		return
	var rack := get_node_or_null("BottleRack")
	if rack and not rack.visible:
		rack = null
	for i in range(BOTTLE_COUNT):
		var bottle := SauceBottle.create_empty()
		bottle.name = "SauceBottle%d" % i
		add_child(bottle)
		if rack and rack.has_method("receive_item"):
			rack.receive_item(bottle)
		else:
			bottle.global_position = Vector3(0.6 + i * 0.08, 0.95, -1.1)
