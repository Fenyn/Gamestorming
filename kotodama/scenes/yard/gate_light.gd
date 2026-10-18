class_name GateLight
extends Node2D
## A nameless light waiting beyond the torii. Clicking it starts an invitation.

signal clicked(light: GateLight)

const FLICKER_TIME: float = 0.45
const SEED_TINT: Color = Color(0.7, 1.0, 0.6)

var is_seed: bool = false

@onready var _sprite: Sprite2D = %Sprite
@onready var _click: Area2D = %Click

var _time: float = 0.0


func _ready() -> void:
	_click.input_event.connect(_on_click_input_event)
	if is_seed:
		_sprite.modulate = SEED_TINT


func _process(delta: float) -> void:
	_time += delta
	_sprite.frame = int(_time / FLICKER_TIME) % 2


func _on_click_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
