class_name Spirit
extends Node2D
## One kanji in the yard: a tinted blob with the glyph on it.

signal clicked(spirit: Spirit)

const PASTEL_MIX: float = 0.45
const INK: Color = Color("1e1928")
const BOB_HEIGHT: float = 2.0
const BOB_TIME: float = 1.4
const NEW_ALPHA: float = 0.65
const DIM_ALPHA: float = 0.45
const SCALE_SMALL: float = 0.75
const SCALE_FULL: float = 1.0
const SCALE_BIG: float = 1.2

var kanji: Dictionary = {}
var key: String = ""

@onready var _body: Node2D = %Body
@onready var _blob: Sprite2D = %Blob
@onready var _glyph: Sprite2D = %Glyph
@onready var _halo: Sprite2D = %Halo
@onready var _bubble: Sprite2D = %Bubble
@onready var _click: Area2D = %Click


func _ready() -> void:
	_click.input_event.connect(_on_click_input_event)


func setup(k: Dictionary) -> void:
	kanji = k
	key = Progress.kanji_key(k["ch"])
	if not is_node_ready():
		await ready
	_glyph.texture = Data.glyph_for(k["cp"])
	_glyph.modulate = INK
	_blob.modulate = Data.zone_tint(k["zone"]).lerp(Color.WHITE, PASTEL_MIX)
	_start_bob()


func set_stage(stage: int) -> void:
	if not is_node_ready():
		await ready
	var s: float = SCALE_SMALL
	if stage >= Srs.MASTER:
		s = SCALE_BIG
	elif stage >= Srs.GURU:
		s = SCALE_FULL
	_body.scale = Vector2(s, s)
	_halo.visible = stage >= Srs.BURNED
	_body.modulate.a = NEW_ALPHA if stage == 0 else 1.0


func set_hungry(on: bool) -> void:
	_bubble.visible = on


func set_dim(on: bool) -> void:
	modulate.a = DIM_ALPHA if on else 1.0


func _start_bob() -> void:
	var tween: Tween = create_tween().set_loops()
	var phase: float = fmod(float(key.hash() % 100) / 100.0, 1.0)
	tween.tween_property(_body, "position:y", -BOB_HEIGHT, BOB_TIME).set_delay(phase * BOB_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_body, "position:y", 0.0, BOB_TIME).set_trans(Tween.TRANS_SINE)


func _on_click_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
