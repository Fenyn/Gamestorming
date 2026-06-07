class_name Player
extends CharacterBody2D

const SPEED: float = 120.0
const TOOLBAR_ACTIONS: Array[String] = [
	"tool_1", "tool_2", "tool_3", "tool_4", "tool_5",
	"tool_6", "tool_7", "tool_8", "tool_9", "tool_0",
]
const FRAME_W: int = 48
const FRAME_H: int = 96
const WALK_FRAMES: int = 6
const WALK_ANIM_SPEED: float = 0.1
const IDLE_ANIM_SPEED: float = 0.2
const FACING_COL_OFFSET: Array[int] = [3, 2, 0, 1]

enum Facing { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

var _nearest_interactable: Node2D = null
var _interactables_in_range: Array[Node2D] = []
var _facing: Facing = Facing.DOWN
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _is_moving: bool = false

@onready var _interact_area: Area2D = %InteractArea
@onready var _sprite: Sprite2D = %PlayerSprite


func _ready() -> void:
	_interact_area.body_entered.connect(_on_interact_area_body_entered)
	_interact_area.body_exited.connect(_on_interact_area_body_exited)
	_update_sprite_frame()


func _physics_process(delta: float) -> void:
	velocity = InputManager.move_input * SPEED
	_is_moving = velocity.length() > 1.0

	if _is_moving:
		_update_facing()
		_anim_timer += delta
		if _anim_timer >= WALK_ANIM_SPEED:
			_anim_timer -= WALK_ANIM_SPEED
			_anim_frame = (_anim_frame + 1) % WALK_FRAMES
			_update_sprite_frame()
	else:
		_anim_timer += delta
		if _anim_timer >= IDLE_ANIM_SPEED:
			_anim_timer -= IDLE_ANIM_SPEED
			_anim_frame = (_anim_frame + 1) % WALK_FRAMES
			_update_sprite_frame()

	move_and_slide()
	_update_nearest_interactable()


func _update_facing() -> void:
	var old_facing: Facing = _facing
	if absf(velocity.x) > absf(velocity.y):
		_facing = Facing.RIGHT if velocity.x > 0 else Facing.LEFT
	else:
		_facing = Facing.DOWN if velocity.y > 0 else Facing.UP
	if _facing != old_facing:
		_anim_frame = 0
		_update_sprite_frame()


func _update_sprite_frame() -> void:
	if _sprite.texture == null:
		return
	var sheet_group: int = FACING_COL_OFFSET[int(_facing)]
	var col: int = sheet_group * WALK_FRAMES + _anim_frame
	var row_y: int = FRAME_H * 2 if _is_moving else FRAME_H
	_sprite.region_rect = Rect2(col * FRAME_W, row_y, FRAME_W, FRAME_H)


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
	var closest: Node2D = null
	var closest_dist: float = INF
	for body: Node2D in _interactables_in_range:
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


func _on_interact_area_body_entered(body: Node2D) -> void:
	if body == self:
		return
	if body.has_method("interact"):
		_interactables_in_range.append(body)


func _on_interact_area_body_exited(body: Node2D) -> void:
	_interactables_in_range.erase(body)
	if _nearest_interactable == body:
		_nearest_interactable = null
		EventBus.interact_hint_changed.emit("")
