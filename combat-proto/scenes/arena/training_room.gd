class_name TrainingRoom
extends Node3D

@onready var player_fighter: Fighter = %PlayerFighter
@onready var enemy_fighter: Fighter = %EnemyFighter
@onready var combat_camera: CombatCamera = %CombatCamera
@onready var combat_hud: CombatHUD = %CombatHUD
@onready var ai_controller: AIController = %AIController
@onready var spawn_p1: Marker3D = %SpawnP1
@onready var spawn_p2: Marker3D = %SpawnP2


func _ready() -> void:
	_setup_player()
	_setup_enemy()
	_setup_camera()
	_setup_hud()

	EventBus.round_reset.connect(_on_round_reset)
	EventBus.match_ended.connect(_on_match_ended)

	InputManager.capture_mouse()
	GameState.start_match(GameState.MatchMode.TRAINING)

	player_fighter.start()
	enemy_fighter.start()


func _setup_player() -> void:
	var default_profile: FighterProfile = preload("res://resources/fighters/default_profile.tres")
	player_fighter.profile = default_profile
	player_fighter.combat_resource.setup(default_profile.stats)
	var human_input: HumanInput = HumanInput.new()
	human_input.setup(-1)
	player_fighter.input = human_input
	player_fighter.opponent = enemy_fighter
	player_fighter.is_locked_on = true
	player_fighter.global_position = spawn_p1.global_position


func _setup_enemy() -> void:
	var default_profile: FighterProfile = preload("res://resources/fighters/default_profile.tres")
	enemy_fighter.profile = default_profile
	enemy_fighter.combat_resource.setup(default_profile.stats)
	var ai_input: AIInput = AIInput.new()
	enemy_fighter.input = ai_input
	enemy_fighter.opponent = player_fighter
	enemy_fighter.is_locked_on = true
	enemy_fighter.global_position = spawn_p2.global_position
	ai_controller.fighter = enemy_fighter
	ai_controller._ai_input = ai_input


func _setup_camera() -> void:
	combat_camera.setup_pve(player_fighter, enemy_fighter)


func _setup_hud() -> void:
	combat_hud.setup(player_fighter, enemy_fighter)


func _on_round_reset() -> void:
	player_fighter.global_position = spawn_p1.global_position
	enemy_fighter.global_position = spawn_p2.global_position
	player_fighter.reset_fighter()
	enemy_fighter.reset_fighter()
	GameState.is_round_active = true


func _on_match_ended(_winner: Node) -> void:
	pass


func _process(_delta: float) -> void:
	if player_fighter and player_fighter.input is HumanInput:
		var human: HumanInput = player_fighter.input as HumanInput
		human.poll(InputManager.raw_mouse_delta)
