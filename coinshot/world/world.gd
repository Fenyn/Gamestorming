extends Node3D

const PLAYER_SCENE := preload("res://player/player.tscn")

# Levels can be GDScript classes (procedural) or .tscn paths (hand-made).
var _levels: Array = [
	Level1Rooftops,
	Level2Canals,
	Level3Keeps,
	Level4Spires,
	Level5Citadel,
]
var _current_index: int = 0
var _current_level: LevelBase = null
var _player: Player = null

func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_kill_volume()
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	_load_level(0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("next_level"):
		_load_level((_current_index + 1) % _levels.size())
	elif event.is_action_pressed("prev_level"):
		_load_level((_current_index - 1 + _levels.size()) % _levels.size())

func _load_level(index: int) -> void:
	if _current_level:
		_current_level.level_completed.disconnect(_on_level_completed)
		_current_level.queue_free()
		await get_tree().process_frame

	_current_index = index
	var entry = _levels[index]
	if entry is String:
		var scene: PackedScene = load(entry as String)
		_current_level = scene.instantiate() as LevelBase
	else:
		_current_level = (entry as Script).new() as LevelBase
	add_child(_current_level)
	_current_level.build()
	_current_level.level_completed.connect(_on_level_completed)

	if _player:
		_player.set_spawn(_current_level.spawn_point)

func _on_level_completed() -> void:
	var next := _current_index + 1
	if next < _levels.size():
		_load_level(next)

func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.28, 0.25)
	sky_mat.sky_horizon_color = Color(0.50, 0.45, 0.40)
	sky_mat.ground_horizon_color = Color(0.38, 0.35, 0.32)
	sky_mat.ground_bottom_color = Color(0.20, 0.18, 0.16)
	sky_mat.sun_angle_max = 25.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_light_color = Color(0.45, 0.42, 0.38)
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 0.9
	sun.light_color = Color(1.0, 0.9, 0.8)
	sun.shadow_enabled = true
	add_child(sun)

func _build_ground() -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "GroundBackdrop"
	mesh.global_position = Vector3(0, -30, 0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 500)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.26, 0.24)
	mat.roughness = 1.0
	mesh.material_override = mat
	add_child(mesh)

func _build_kill_volume() -> void:
	var area := Area3D.new()
	area.name = "KillVolume"
	area.global_position = Vector3(0, -20, 0)
	add_child(area)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2000, 2, 2000)
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(func(body: Node3D):
		if body is Player:
			body._respawn()
	)
