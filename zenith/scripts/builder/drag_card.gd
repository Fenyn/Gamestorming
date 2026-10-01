class_name DragCard
extends Control
## The card in hand while the deck builder drags it: lifted off the table with a soft shadow under
## it, and swaying with the pointer's motion as a card held by one corner would, leaning into a
## sideways move and settling when the pointer stops. Godot moves this control with the pointer;
## this only shapes the card inside it.

const LIFT: float = 1.08
## Radians of lean per pixel per second of sideways speed, and the most it leans.
const LEAN: float = 0.0004
const MAX_LEAN: float = 0.2
## How fast the lean and the squash follow the motion (per second).
const FOLLOW: float = 14.0

var _card: TextureRect
var _shadow: Panel
## Over this rect (the deck column) the card shrinks to SHRUNK of its size.
var shrink_zone: Rect2 = Rect2()
const SHRUNK: float = 0.7
var _last: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _size_k: float = 1.0
var _lean: float = 0.0
var _squash: float = 0.0


static func make(texture: Texture2D, card_size: Vector2) -> DragCard:
	var drag: DragCard = DragCard.new()
	drag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag._shadow = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.45)
	box.set_corner_radius_all(10)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 16
	drag._shadow.add_theme_stylebox_override("panel", box)
	drag._shadow.size = card_size
	drag._shadow.position = -card_size * 0.5 + Vector2(14, 22)
	drag._shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag.add_child(drag._shadow)
	drag._card = TextureRect.new()
	drag._card.texture = texture
	drag._card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag._card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag._card.size = card_size
	drag._card.position = -card_size * 0.5
	drag._card.pivot_offset = Vector2(card_size.x * 0.5, card_size.y * 0.12)
	drag._card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag._card.scale = Vector2.ONE * LIFT
	drag.add_child(drag._card)
	drag._shadow.pivot_offset = drag._card.pivot_offset
	return drag


func _ready() -> void:
	_last = get_global_mouse_position()


## Holds a fixed lean, for a screenshot of a card mid-drag; the motion no longer drives it.
func pose(lean: float) -> void:
	set_process(false)
	_lean = lean
	_size_k = SHRUNK if shrink_zone.has_point(global_position) else 1.0
	_card.scale = Vector2.ONE * LIFT * _size_k
	_shadow.scale = Vector2.ONE * _size_k
	_card.rotation = lean
	_shadow.rotation = lean * 0.8
	_shadow.position = -_card.size * 0.5 + Vector2(14, 22) + Vector2(-9, -2)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var at: Vector2 = get_global_mouse_position()
	# Frames with no pointer event read as zero speed; smoothing the speed first keeps the lean
	# from twitching between them.
	_velocity = _velocity.lerp((at - _last) / delta, clampf(20.0 * delta, 0.0, 1.0))
	var velocity: Vector2 = _velocity
	_last = at
	var k: float = clampf(FOLLOW * delta, 0.0, 1.0)
	_lean = lerpf(_lean, clampf(velocity.x * LEAN, -MAX_LEAN, MAX_LEAN), k)
	_squash = lerpf(_squash, clampf(absf(velocity.y) * 0.00008, 0.0, 0.06), k)
	_size_k = lerpf(_size_k, SHRUNK if shrink_zone.has_point(at) else 1.0, clampf(12.0 * delta, 0.0, 1.0))
	_card.rotation = _lean
	_card.scale = Vector2(LIFT * (1.0 - _squash * 0.5), LIFT * (1.0 + _squash)) * _size_k
	_shadow.scale = Vector2.ONE * _size_k
	_shadow.rotation = _lean * 0.8
	# The shadow trails a little further the faster the card moves, as if lifted higher.
	_shadow.position = -_card.size * 0.5 + Vector2(14, 22) + Vector2(-velocity.x, -velocity.y).limit_length(900.0) * 0.012
