extends StaticBody3D

enum State { STANDING, STUMP, SAPLING, GROWING }

@export var log_scene: PackedScene = null
@export var logs_to_spawn: int = 3
@export var growth_days: int = 7

var _state: State = State.STANDING
var _chop_progress: float = 0.0
var _grow_days: int = 0
const CHOPS_NEEDED := 5.0

@onready var _model: Node3D = $Model


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)


func get_interact_hint(player: Node3D) -> String:
	match _state:
		State.STANDING:
			var held: Node3D = player.get_held_item() as Node3D
			if held and held.get("tool_type") == 1:
				return "[E] Chop (%d/%d)" % [int(_chop_progress), int(CHOPS_NEEDED)]
			return "[E] Chop (hold axe)"
		State.STUMP:
			var saplings: int = GameState.inventory.get("sapling", 0) as int
			if saplings > 0:
				return "[E] Plant sapling"
			return "Stump (buy saplings at store)"
		State.SAPLING:
			return "Sapling (%d/%d days)" % [_grow_days, growth_days]
		State.GROWING:
			return "Growing (%d/%d days)" % [_grow_days, growth_days]
	return ""


func interact(player: Node3D) -> void:
	match _state:
		State.STANDING:
			_try_chop(player)
		State.STUMP:
			_try_plant()


func _try_chop(player: Node3D) -> void:
	var held: Node3D = player.get_held_item() as Node3D
	if not held or held.get("tool_type") != 1:
		return

	_chop_progress += 1.0
	if _chop_progress >= CHOPS_NEEDED:
		_fell_tree()


func _fell_tree() -> void:
	_state = State.STUMP

	if log_scene:
		for i: int in logs_to_spawn:
			var log_item: Node3D = log_scene.instantiate()
			get_parent().add_child(log_item)
			var offset := Vector3(randf_range(-1.0, 1.0), 0.5, randf_range(-1.0, 1.0))
			log_item.global_position = global_position + offset

	_chop_progress = 0.0
	_update_visuals()


func _try_plant() -> void:
	var saplings: int = GameState.inventory.get("sapling", 0) as int
	if saplings <= 0:
		return
	GameState.inventory["sapling"] = saplings - 1
	_state = State.SAPLING
	_grow_days = 0
	_update_visuals()


func _on_day_started(_day: int) -> void:
	if _state == State.SAPLING or _state == State.GROWING:
		_grow_days += 1
		if _grow_days >= growth_days:
			_state = State.STANDING
			_grow_days = 0
		elif _grow_days >= growth_days / 2:
			_state = State.GROWING
		_update_visuals()


func _update_visuals() -> void:
	if not _model:
		return

	match _state:
		State.STANDING:
			_model.visible = true
			_model.scale = Vector3.ONE
		State.STUMP:
			_model.visible = true
			_model.scale = Vector3(1.0, 0.1, 1.0)
		State.SAPLING:
			_model.visible = true
			_model.scale = Vector3(0.3, 0.2, 0.3)
		State.GROWING:
			var pct: float = float(_grow_days) / float(growth_days)
			_model.visible = true
			_model.scale = Vector3.ONE * lerpf(0.3, 1.0, pct)
