extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@export var auto_start_day := true

func _ready() -> void:
	_spawn_player()
	_setup_customers()
	if auto_start_day:
		GameManager.start_day()

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
