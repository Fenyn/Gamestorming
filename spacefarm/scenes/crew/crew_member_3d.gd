class_name CrewMember3D
extends CharacterBody3D

signal crew_interacted(crew_id: String)

const SPEED: float = 2.5
const IDLE_TIME_MIN: float = 3.0
const IDLE_TIME_MAX: float = 8.0
const WANDER_RADIUS: float = 2.5
const ARRIVAL_THRESHOLD: float = 0.3

var crew_id: String = ""
var crew_data: ContactData = null
var home_position: Vector3 = Vector3.ZERO

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _name_label: Label3D = $NameLabel
@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _state_machine: BaseStateMachine = $StateMachine

var nav_agent: NavigationAgent3D:
	get: return _nav_agent


func setup(data: ContactData) -> void:
	crew_id = data.contact_id
	crew_data = data
	if _name_label:
		_name_label.text = data.contact_name
	home_position = position
	add_to_group("crew_members")


func _ready() -> void:
	_nav_agent.path_desired_distance = ARRIVAL_THRESHOLD
	_nav_agent.target_desired_distance = ARRIVAL_THRESHOLD
	call_deferred("_deferred_start")


func _deferred_start() -> void:
	_state_machine.start()


func interact(_player: Node3D) -> void:
	transition_state(&"Talking", {"duration": 2.0})
	crew_interacted.emit(crew_id)


func get_interact_hint() -> String:
	if crew_data:
		return "E/Click: Talk to %s" % crew_data.contact_name
	return "E/Click: Talk"


func get_state_name() -> StringName:
	return _state_machine.get_current_state_name()


func transition_state(state_name: StringName, msg: Dictionary = {}) -> void:
	_state_machine.transition_to(state_name, msg)


func is_busy() -> bool:
	var state: StringName = get_state_name()
	return state == &"Talking" or state == &"Relocating" or state == &"Transit"
