class_name RelicOffer
extends Control
## One offer on the Relic node: the Relic's face, its Reserve set's name and faces, and one sentence
## on what taking it does to the Reserve. The whole panel is the button. The Relic screen owns the
## rules and wires the signals.

signal pressed
signal hovered(over: bool)
## The pointer entered or left the small face in slot `index`.
signal card_hovered(index: int, over: bool)

const LIFT: float = 10.0

@onready var body: Control = $Body
@onready var glow: Panel = $Body/Glow
@onready var frame: PanelContainer = $Body/Frame
@onready var face: TextureRect = $Body/Frame/Column/Face
@onready var set_label: Label = $Body/Frame/Column/SetName
@onready var card_row: HBoxContainer = $Body/Frame/Column/Cards
@onready var consequence: Label = $Body/Frame/Column/Consequence

var _over: bool = false
var _tween: Tween = null


func _ready() -> void:
	frame.add_theme_stylebox_override("panel", MapArt.panel_box(22))
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	($Body/Frame/Column as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.mouse_entered.connect(_check_hover)
	frame.mouse_exited.connect(_check_hover)
	frame.gui_input.connect(_on_input)
	for i in range(card_row.get_child_count()):
		var card: TextureRect = card_row.get_child(i) as TextureRect
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var index: int = i
		card.mouse_entered.connect(func() -> void:
			_check_hover()
			card_hovered.emit(index, true))
		card.mouse_exited.connect(func() -> void:
			card_hovered.emit(index, false)
			_check_hover())


## Fills the panel. `cards` is one texture per card of the set, at most one per slot.
func show_offer(relic: Texture2D, set_name: String, cards: Array[Texture2D], sentence: String) -> void:
	face.texture = relic
	set_label.text = set_name
	set_label.visible = set_name != ""
	for i in range(card_row.get_child_count()):
		var card: TextureRect = card_row.get_child(i) as TextureRect
		card.visible = i < cards.size()
		card.texture = cards[i] if i < cards.size() else null
	card_row.visible = not cards.is_empty()
	consequence.text = sentence


func card_rect(index: int) -> Rect2:
	return (card_row.get_child(index) as Control).get_global_rect()


## Raises the panel with a bone glow round it, or settles it back.
func lift(up: bool, instant: bool) -> void:
	glow.visible = up
	var target: float = -LIFT if up else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if instant:
		body.position.y = target
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(body, "position:y", target, 0.12)


## The frame and the faces inside it pass the pointer between them, so the panel is hovered for as
## long as the pointer is anywhere over it.
func _check_hover() -> void:
	var over: bool = frame.get_global_rect().has_point(frame.get_global_mouse_position())
	if over == _over:
		return
	_over = over
	hovered.emit(over)


func _on_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
