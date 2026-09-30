class_name ShopSlot
extends Control
## One card on the Shop's cloth: the face, a cord and a hanging price tag, or an empty outline once
## the card is sold. Odd slots hang a little lower. The Shop screen owns the rules and wires the
## signals.

signal pressed
signal hovered(over: bool)
signal inspected

## How far every other slot hangs below its neighbours.
const STAGGER: float = 12.0
## Under the pointer a card grows in place and rises a little. At this size it stays clear of its
## neighbours, its own tag and the cloth's edge.
const HOVER_SCALE: float = 1.1
const LIFT: float = 6.0
const BLOCKED_TINT: Color = Color(0.5, 0.5, 0.52)

@onready var body: Control = $Body
@onready var card: Control = $Body/Card
@onready var glow: Panel = $Body/Card/Glow
@onready var shadow: Panel = $Body/Card/Shadow
@onready var face: TextureButton = $Body/Card/Face
@onready var sold_panel: PanelContainer = $Body/Card/Sold
@onready var cord: ColorRect = $Body/Cord
@onready var tag: PanelContainer = $Body/Tag
@onready var gem: TextureRect = $Body/Tag/Row/Gem
@onready var price_label: Label = $Body/Tag/Row/Price

var _buyable: bool = false
var _tween: Tween = null


func _ready() -> void:
	gem.texture = MapArt.ui("mana")
	price_label.add_theme_font_size_override("font_size", ZenithTheme.SIZE_ROW)
	face.pressed.connect(func() -> void: pressed.emit())
	face.mouse_entered.connect(func() -> void: hovered.emit(true))
	face.mouse_exited.connect(func() -> void: hovered.emit(false))
	face.gui_input.connect(func(event: InputEvent) -> void:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
			inspected.emit())


func set_index(index: int) -> void:
	body.position.y = STAGGER if index % 2 == 1 else 0.0


## A card on sale. `short` paints the price in the can't-pay colour; `reason` is the hover line of a
## card that cannot be bought, "" for one that can.
func show_card(texture: Texture2D, price: int, short: bool, reason: String) -> void:
	_buyable = reason == ""
	face.texture_normal = texture
	face.visible = true
	shadow.visible = true
	sold_panel.visible = false
	cord.visible = true
	tag.visible = true
	face.self_modulate = Color.WHITE if _buyable else BLOCKED_TINT
	face.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _buyable else Control.CURSOR_ARROW
	face.tooltip_text = reason
	price_label.text = str(price)
	if short:
		price_label.add_theme_color_override("font_color", ZenithTheme.SHORT)
		price_label.add_theme_color_override("font_shadow_color", Color(ZenithTheme.SHORT, 0.35))
	else:
		ZenithTheme.mana_label(price_label)


func show_sold() -> void:
	lift(false, true)
	_buyable = false
	face.visible = false
	shadow.visible = false
	sold_panel.visible = true
	cord.visible = false
	tag.visible = false


## Grows and raises the hovered card, a buyable one with a soft glow round it, or settles it back.
func lift(up: bool, instant: bool) -> void:
	glow.visible = up and _buyable
	card.pivot_offset = card.size * 0.5
	var target_y: float = -LIFT if up else 0.0
	var target_scale: Vector2 = Vector2.ONE * (HOVER_SCALE if up else 1.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if instant:
		card.position.y = target_y
		card.scale = target_scale
		return
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "position:y", target_y, 0.12)
	_tween.tween_property(card, "scale", target_scale, 0.12)
