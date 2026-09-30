class_name ReserveCard
extends Control
## One card on the Reserve screen, standing for every copy of it in its pile: the face, a copy
## count, a NEW chip for a card that just arrived, and a ring while it is a drop target. The screen
## owns the rules, the clicks and the drags.

signal pressed
signal hovered(over: bool)

@onready var face: TextureButton = $Face
@onready var ring: Panel = $Ring
@onready var new_chip: Label = $New
@onready var count_chip: Label = $Count

var pile: String = ""
var card_id: String = ""


func _ready() -> void:
	(ring.get_theme_stylebox("panel") as StyleBoxFlat).border_color = ZenithTheme.ACCENT
	ZenithTheme.chip(new_chip, ZenithTheme.ACCENT, true)
	ZenithTheme.chip(count_chip, ZenithTheme.FRAME, true)
	face.pressed.connect(func() -> void: pressed.emit())
	face.mouse_entered.connect(func() -> void: hovered.emit(true))
	face.mouse_exited.connect(func() -> void: hovered.emit(false))


func show_card(pile_name: String, id: String, texture: Texture2D, copies: int, fresh: bool, size_value: Vector2) -> void:
	pile = pile_name
	card_id = id
	custom_minimum_size = size_value
	face.texture_normal = texture
	count_chip.text = "x%d" % copies
	count_chip.visible = copies > 1
	new_chip.visible = fresh


func mark(on: bool) -> void:
	ring.visible = on
