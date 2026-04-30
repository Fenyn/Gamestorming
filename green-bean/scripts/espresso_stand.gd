extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _customer_spawner: Node3D = null

func _ready() -> void:
	_build_environment()
	_build_stand()
	_build_stations()
	_build_customers()
	_spawn_player()
	GameManager.start_day()

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.75, 0.85)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.85, 0.8)
	environment.ambient_light_energy = 0.5
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

func _build_stand() -> void:
	_add_box(Vector3(0, -0.05, 0), Vector3(8, 0.1, 8), Color(0.4, 0.45, 0.4))
	_add_box(Vector3(0, 0.05, 0), Vector3(3.5, 0.1, 2.5), Color(0.55, 0.45, 0.35))
	_add_box(Vector3(0, 1.25, -1.25), Vector3(3.5, 2.5, 0.1), Color(0.65, 0.55, 0.45))
	_add_box(Vector3(-1.75, 1.25, 0), Vector3(0.1, 2.5, 2.5), Color(0.65, 0.55, 0.45))
	_add_box(Vector3(1.75, 1.25, 0), Vector3(0.1, 2.5, 2.5), Color(0.65, 0.55, 0.45))
	_add_box(Vector3(0, 0.5, 1.15), Vector3(3.5, 1.0, 0.2), Color(0.5, 0.4, 0.3))
	_add_box(Vector3(0, 2.6, 0.3), Vector3(4.0, 0.08, 3.2), Color(0.3, 0.5, 0.3))
	_add_box(Vector3(0, 0.85, -0.9), Vector3(3.2, 0.08, 0.8), Color(0.45, 0.38, 0.3))

func _build_stations() -> void:
	_build_station("res://scripts/stations/register.gd",
		Vector3(1.0, 1.1, 0.9), Vector3(0.35, 0.3, 0.25), Color(0.3, 0.3, 0.35), "Register")

	_build_station("res://scripts/stations/cash_drawer.gd",
		Vector3(0.55, 0.95, 0.9), Vector3(0.25, 0.1, 0.2), Color(0.35, 0.35, 0.38), "CashDrawer")

	_build_station("res://scripts/stations/cup_stack.gd",
		Vector3(-0.2, 1.1, 0.9), Vector3(0.4, 0.3, 0.2), Color(0.9, 0.9, 0.85), "CupStack")

	_build_station("res://scripts/stations/grinder_station.gd",
		Vector3(-1.2, 1.1, -0.9), Vector3(0.25, 0.35, 0.25), Color(0.25, 0.25, 0.25), "Grinder")

	_build_station("res://scripts/stations/aeropress_station.gd",
		Vector3(-0.5, 1.0, -0.9), Vector3(0.2, 0.3, 0.2), Color(0.4, 0.4, 0.42), "Aeropress")

	_build_station("res://scripts/stations/pour_over_station.gd",
		Vector3(0.2, 1.05, -0.9), Vector3(0.25, 0.25, 0.25), Color(0.6, 0.5, 0.4), "PourOver")

	_build_station("res://scripts/stations/hot_water_station.gd",
		Vector3(0.8, 1.2, -1.1), Vector3(0.2, 0.4, 0.2), Color(0.7, 0.7, 0.72), "HotWater")

	_build_station("res://scripts/stations/counter_pad.gd",
		Vector3(0.8, 0.92, -0.7), Vector3(0.4, 0.02, 0.3), Color(0.35, 0.3, 0.25), "CounterPad")

	_build_station("res://scripts/stations/steam_station.gd",
		Vector3(1.2, 1.0, -0.9), Vector3(0.2, 0.25, 0.2), Color(0.72, 0.72, 0.74), "Steam")

	_build_station("res://scripts/stations/fridge_station.gd",
		Vector3(1.5, 0.5, -0.3), Vector3(0.35, 1.0, 0.35), Color(0.85, 0.85, 0.88), "Fridge")

	_build_station("res://scripts/stations/hand_off.gd",
		Vector3(-1.0, 1.05, 1.15), Vector3(0.4, 0.1, 0.2), Color(0.5, 0.42, 0.32), "HandOff")

	# Station name labels
	_add_label(Vector3(-1.2, 1.45, -0.9), "GRINDER")
	_add_label(Vector3(-0.5, 1.4, -0.9), "AEROPRESS")
	_add_label(Vector3(0.2, 1.35, -0.9), "POUR OVER")
	_add_label(Vector3(0.8, 1.55, -1.1), "HOT WATER")
	_add_label(Vector3(1.2, 1.35, -0.9), "STEAM")
	_add_label(Vector3(1.5, 1.1, -0.3), "FRIDGE")
	_add_label(Vector3(1.0, 1.5, 0.9), "REGISTER")
	_add_label(Vector3(0.55, 1.1, 0.9), "CASH DRAWER")
	_add_label(Vector3(-0.2, 1.45, 0.9), "CUPS")
	_add_label(Vector3(-1.0, 1.2, 1.15), "HAND OFF")

func _build_customers() -> void:
	_customer_spawner = Node3D.new()
	_customer_spawner.set_script(load("res://scripts/customers/customer_spawner.gd"))
	_customer_spawner.name = "CustomerSpawner"
	add_child(_customer_spawner)
	_customer_spawner.setup(Vector3(0.5, 0, 2.5), Vector3(-1.0, 0, 2.5))

func _spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.position = Vector3(0, 0.1, 0)
	add_child(player)

func _build_station(script_path: String, pos: Vector3, size: Vector3, color: Color, station_name: String) -> StaticBody3D:
	var station := StaticBody3D.new()
	station.name = station_name
	station.position = pos
	station.set_script(load(script_path))

	var mesh := CSGBox3D.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	station.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	station.add_child(col)

	add_child(station)
	return station

func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var box := CSGBox3D.new()
	box.size = size
	box.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	box.use_collision = true
	add_child(box)

func _add_label(pos: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 12
	label.position = pos
	label.pixel_size = 0.002
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.add_to_group("world_label")
	add_child(label)
