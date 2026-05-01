extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const REGISTER_SCENE := preload("res://scenes/stations/register.tscn")
const CASH_DRAWER_SCENE := preload("res://scenes/stations/cash_drawer.tscn")
const CUP_STACK_SCENE := preload("res://scenes/stations/cup_stack.tscn")
const GRINDER_SCENE := preload("res://scenes/stations/grinder.tscn")
const AEROPRESS_SCENE := preload("res://scenes/stations/aeropress.tscn")
const POUR_OVER_SCENE := preload("res://scenes/stations/pour_over.tscn")
const HOT_WATER_SCENE := preload("res://scenes/stations/hot_water.tscn")
const STEAM_SCENE := preload("res://scenes/stations/steam.tscn")
const FRIDGE_SCENE := preload("res://scenes/stations/fridge.tscn")
const HAND_OFF_SCENE := preload("res://scenes/stations/hand_off.tscn")
const COUNTER_PAD_SCENE := preload("res://scenes/stations/counter_pad.tscn")

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
	_place(REGISTER_SCENE, Vector3(1.0, 1.1, 0.9), "REGISTER")
	_place(CASH_DRAWER_SCENE, Vector3(0.55, 0.95, 0.9), "CASH DRAWER")
	_place(CUP_STACK_SCENE, Vector3(-0.2, 1.1, 0.9), "CUPS")
	_place(GRINDER_SCENE, Vector3(-1.2, 1.1, -0.9), "GRINDER")
	_place(AEROPRESS_SCENE, Vector3(-0.5, 1.0, -0.9), "AEROPRESS")
	_place(POUR_OVER_SCENE, Vector3(0.2, 1.05, -0.9), "POUR OVER")
	_place(COUNTER_PAD_SCENE, Vector3(0.8, 0.92, -0.7))
	_place(HOT_WATER_SCENE, Vector3(0.8, 1.2, -1.1), "HOT WATER")
	_place(STEAM_SCENE, Vector3(1.2, 1.0, -0.9), "STEAM")
	_place(FRIDGE_SCENE, Vector3(1.5, 0.5, -0.3), "FRIDGE")
	_place(HAND_OFF_SCENE, Vector3(-1.0, 1.05, 1.15), "HAND OFF")

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

func _place(scene: PackedScene, pos: Vector3, label_text: String = "") -> Node3D:
	var instance := scene.instantiate()
	instance.position = pos
	add_child(instance)
	if label_text != "":
		_add_label(pos + Vector3(0, 0.4, 0), label_text)
	return instance

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
