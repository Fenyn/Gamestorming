class_name Flower
extends Node2D
## One word in a bed: a stem and a bloom tinted by its zone.

signal clicked(flower: Flower)

const PASTEL_MIX: float = 0.25
const DROOP_FRAME: int = 1
const BLOOM_BUD: int = 0
const BLOOM_SMALL: int = 1
const BLOOM_FULL: int = 2
const BLOOM_BIG: int = 3
const DROOP_OFFSET: Vector2 = Vector2(4, 4)

var word: Dictionary = {}
var key: String = ""

@onready var _stem: Sprite2D = %Stem
@onready var _bloom: Sprite2D = %Bloom
@onready var _bubble: Sprite2D = %Bubble
@onready var _label: Label = %Label
@onready var _click: Area2D = %Click

var _bloom_home: Vector2


func _ready() -> void:
	_bloom_home = _bloom.position
	_click.input_event.connect(_on_click_input_event)
	_click.mouse_entered.connect(func() -> void: _label.visible = true)
	_click.mouse_exited.connect(func() -> void: _label.visible = false)
	_label.visible = false


func setup(w: Dictionary) -> void:
	word = w
	key = Progress.word_key(w["word"])
	if not is_node_ready():
		await ready
	_bloom.modulate = Data.zone_tint(w["zone"]).lerp(Color.WHITE, PASTEL_MIX)
	_label.text = w["word"]


func set_stage(stage: int) -> void:
	if not is_node_ready():
		await ready
	var frame: int = BLOOM_BUD
	if stage >= Srs.MASTER:
		frame = BLOOM_BIG
	elif stage >= Srs.GURU:
		frame = BLOOM_FULL
	elif stage >= 1:
		frame = BLOOM_SMALL
	_bloom.frame = frame


func set_hungry(on: bool) -> void:
	_bubble.visible = on


func set_droop(on: bool) -> void:
	_stem.frame = DROOP_FRAME if on else 0
	_bloom.position = _bloom_home + DROOP_OFFSET if on else _bloom_home


func _on_click_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
