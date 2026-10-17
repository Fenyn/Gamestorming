extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

const BOTTLE_COUNT := 3

const STATION_EQUIPMENT_MAP := {
	"ShotPress": "shot_press",
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
	# CSG and collision shapes finish setting up at the end of this frame, so bake then.
	call_deferred("_bake_navigation")
	_spawn_player()
	_setup_customers()
	_setup_ambient_life()
	_gate_stations()
	_spawn_sauce_bottles()
	GameManager.start_prep()

## Bakes the walkable area for customers from every static collider in the shop
## (stand, street props, seating). Runs once at startup; it takes a few milliseconds.
func _bake_navigation() -> void:
	var region := get_node_or_null("NavRegion") as NavigationRegion3D
	if region == null:
		return
	# The navmesh uses finer height cells than the default map so paths sit close
	# to the ground; the map must match or Godot warns and offsets the paths.
	var map := region.get_navigation_map()
	NavigationServer3D.map_set_cell_size(map, region.navigation_mesh.cell_size)
	NavigationServer3D.map_set_cell_height(map, region.navigation_mesh.cell_height)
	region.bake_navigation_mesh(false)

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
	# Line and pickup spots are Marker3D children, so they can be moved in the editor.
	spawner.setup(reg_pos, pickup_pos, _marker_positions("RegisterQueue"), _marker_positions("PickupSpots"))

func _marker_positions(parent_name: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var parent := get_node_or_null(parent_name)
	if parent:
		for child in parent.get_children():
			if child is Marker3D:
				out.append((child as Marker3D).position)
	return out

func _setup_ambient_life() -> void:
	var life := AmbientLife.new()
	life.name = "AmbientLife"
	add_child(life)

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
	var rack_node := get_node_or_null("BottleRack") as Node3D
	var rack := rack_node if rack_node and rack_node.visible else null
	var spare_spot := rack_node.global_position if rack_node else Vector3(0.12, 0.9, -1.15)
	for i in range(BOTTLE_COUNT):
		var bottle := SauceBottle.create_empty()
		bottle.name = "SauceBottle%d" % i
		add_child(bottle)
		if rack and rack.has_method("receive_item"):
			rack.receive_item(bottle)
		else:
			bottle.global_position = spare_spot + Vector3((i - 1) * 0.08, StationUtils.item_half_height(bottle, 0.1), 0)
