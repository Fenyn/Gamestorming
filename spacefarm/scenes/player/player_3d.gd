class_name Player3D
extends CharacterBody3D

const SPEED: float = 5.0
const TOOLBAR_ACTIONS: Array[String] = [
	"tool_1", "tool_2", "tool_3", "tool_4", "tool_5",
	"tool_6", "tool_7", "tool_8", "tool_9", "tool_0",
]

enum Facing { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

var _nearest_interactable: Node3D = null
var _interactables_in_range: Array[Node3D] = []
var _facing: Facing = Facing.DOWN

@onready var _interact_area: Area3D = %InteractArea
@onready var _sprite: Sprite3D = %PlayerSprite


func _ready() -> void:
	_interact_area.body_entered.connect(_on_interact_area_body_entered)
	_interact_area.body_exited.connect(_on_interact_area_body_exited)


func _physics_process(_delta: float) -> void:
	var input: Vector2 = InputManager.move_input
	velocity = Vector3(input.x, 0.0, input.y) * SPEED

	if velocity.length() > 0.1:
		_update_facing()

	move_and_slide()
	_update_nearest_interactable()


func _update_facing() -> void:
	if absf(velocity.x) > absf(velocity.z):
		_facing = Facing.RIGHT if velocity.x > 0 else Facing.LEFT
	else:
		_facing = Facing.DOWN if velocity.z > 0 else Facing.UP


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and InputManager.is_action_active("interact"):
		_try_interact()
	for i: int in range(mini(GameState.TOOLBAR_SIZE, TOOLBAR_ACTIONS.size())):
		if event.is_action_pressed(TOOLBAR_ACTIONS[i]):
			GameState.set_active_slot(i)
			if _nearest_interactable and _nearest_interactable.has_method("get_interact_hint"):
				EventBus.interact_hint_changed.emit(_nearest_interactable.get_interact_hint())
			break


func _try_interact() -> void:
	if _nearest_interactable == null:
		return
	if _nearest_interactable.has_method("interact"):
		_nearest_interactable.interact(self)


func _update_nearest_interactable() -> void:
	var closest: Node3D = null
	var closest_dist: float = INF
	for body: Node3D in _interactables_in_range:
		if not is_instance_valid(body):
			continue
		var dist: float = global_position.distance_to(body.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = body
	if closest != _nearest_interactable:
		_nearest_interactable = closest
		if _nearest_interactable and _nearest_interactable.has_method("get_interact_hint"):
			EventBus.interact_hint_changed.emit(_nearest_interactable.get_interact_hint())
		else:
			EventBus.interact_hint_changed.emit("")


func _on_interact_area_body_entered(body: Node3D) -> void:
	if body == self:
		return
	if body.has_method("interact"):
		_interactables_in_range.append(body)


func _on_interact_area_body_exited(body: Node3D) -> void:
	_interactables_in_range.erase(body)
	if _nearest_interactable == body:
		_nearest_interactable = null
		EventBus.interact_hint_changed.emit("")
