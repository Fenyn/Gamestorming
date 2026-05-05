extends Node3D
class_name OrbSpawner

signal orb_spawned(orb: Orb)

@export var orb_scene: PackedScene
@export var spawn_interval: float = 3.0
@export var orb_radius: float = 0.15
@export var auto_spawn: bool = true

var _timer: float = 0.0

func _ready() -> void:
	_timer = spawn_interval

func _process(delta: float) -> void:
	if not auto_spawn:
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		spawn_orb()

func spawn_orb() -> void:
	if orb_scene == null:
		push_warning("OrbSpawner: No orb scene assigned")
		return

	var orb: Orb = orb_scene.instantiate() as Orb
	orb.global_position = global_position
	get_tree().current_scene.add_child(orb)
	orb_spawned.emit(orb)
