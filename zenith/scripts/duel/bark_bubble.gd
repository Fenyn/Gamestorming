class_name BarkBubble
extends PanelContainer
## One shouted line beside a duelist card, or one of Vale's notes beside what it is about. It pops
## in, holds, and fades by itself; a word in capitals shakes it. The tail points at `aim`. Whoever
## owns it sets `home`, where it stands, every frame.

const POP_TIME: float = 0.14
const POP_FROM: float = 0.6
const OUT_TIME: float = 0.15
const SHAKE: float = 2.0
const SHAKE_TIME: float = 0.2
const MAX_WIDTH: float = 380.0
const MIN_WIDTH: float = 90.0
const TAIL_BASE: float = 11.0
const TAIL_LENGTH: float = 16.0
const FIGHTER_FILL: Color = ZenithTheme.ACCENT
const FIGHTER_EDGE: Color = Color(0.12, 0.10, 0.09, 0.9)

@onready var face: TextureRect = $Row/Face
@onready var label: Label = $Row/Text
@onready var tail: Polygon2D = $Tail

## The ring target or anchor it stands beside, "" while it is down.
var anchor: String = ""
var home: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.ZERO
var reduced_motion: bool = false
var _left: float = 0.0
var _shaking: float = 0.0
var _tween: Tween = null
var _note: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows `text` for `hold` seconds. A `portrait` makes it one of Vale's notes, in the coach's colours.
func pop(text: String, portrait: Texture2D, hold: float, at: String) -> void:
	_note = portrait != null
	anchor = at
	face.texture = portrait
	face.visible = _note
	label.text = text
	var fill: Color = ZenithTheme.BG if _note else FIGHTER_FILL
	add_theme_stylebox_override("panel", ZenithTheme.box(fill, ZenithTheme.FRAME if _note else FIGHTER_EDGE, 10, 2, 14, 8))
	label.add_theme_color_override("font_color", ZenithTheme.TEXT if _note else ZenithTheme.TEXT_DARK)
	tail.color = fill
	var font: Font = label.get_theme_font("font")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x + 4.0
	label.custom_minimum_size.x = clampf(width, MIN_WIDTH, MAX_WIDTH - (60.0 if _note else 28.0))
	reset_size()
	_left = hold
	_shaking = SHAKE_TIME if TutorialPacing.shouted(text) and not reduced_motion else 0.0
	visible = true
	if _tween != null:
		_tween.kill()
	modulate.a = 1.0
	scale = Vector2.ONE
	if reduced_motion:
		return
	scale = Vector2.ONE * POP_FROM
	modulate.a = 0.0
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, POP_TIME * 0.6)


func showing() -> bool:
	return visible and anchor != ""


func dismiss() -> void:
	if not visible or anchor == "":
		return
	anchor = ""
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, OUT_TIME)
	_tween.tween_callback(hide)


func _process(delta: float) -> void:
	if not visible:
		return
	if anchor != "":
		_left -= delta
		if _left <= 0.0:
			dismiss()
	var offset: Vector2 = Vector2.ZERO
	if _shaking > 0.0:
		_shaking -= delta
		offset = Vector2(randf_range(-SHAKE, SHAKE), randf_range(-SHAKE, SHAKE))
	# An autowrapped label only settles its height once laid out at its width, so the bubble shrinks
	# to fit every frame.
	reset_size()
	pivot_offset = size * 0.5
	position = home + offset
	_aim_tail()


## A small triangle from the edge nearest `aim` toward it.
func _aim_tail() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, size)
	var local: Vector2 = aim - position
	if box.has_point(local) or aim == Vector2.ZERO:
		tail.visible = false
		return
	tail.visible = true
	var edge: Vector2 = Vector2(clampf(local.x, 14.0, size.x - 14.0), clampf(local.y, 10.0, size.y - 10.0))
	var along: Vector2 = Vector2.RIGHT
	if local.y > size.y or local.y < 0.0:
		edge.y = size.y - 1.0 if local.y > size.y else 1.0
	else:
		edge.x = size.x - 1.0 if local.x > size.x else 1.0
		along = Vector2.DOWN
	var direction: Vector2 = (local - edge).normalized()
	tail.polygon = PackedVector2Array([edge - along * TAIL_BASE * 0.5, edge + along * TAIL_BASE * 0.5,
		edge + direction * TAIL_LENGTH])
