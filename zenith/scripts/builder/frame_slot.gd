class_name FrameSlot
extends Button
## One of the deck's fixed slots in the builder: the Duelist, a Duelist Aspect, the Mastery or the
## Relic. Empty, it is a framed outline with a large plus and what goes there (a small slot shows
## only its number); filled, the card's face inside the same frame. Hovering outlines it;
## `set_marked` rings the one that matters most (the top Aspect).

signal hovered(over: bool)

@onready var face: TextureRect = $Face
@onready var empty: VBoxContainer = $Empty
@onready var plus: Label = $Empty/Plus
@onready var caption: Label = $Empty/Caption

var card_id: String = ""
var _marked: bool = false


func _ready() -> void:
	mouse_entered.connect(func() -> void: hovered.emit(true))
	mouse_exited.connect(func() -> void: hovered.emit(false))
	caption.add_theme_color_override("font_color", ZenithTheme.MUTED)
	plus.add_theme_color_override("font_color", Color(ZenithTheme.ACCENT, 0.5))
	_paint()


func show_empty(text: String) -> void:
	card_id = ""
	face.texture = null
	var wide: bool = custom_minimum_size.x > 80.0
	plus.visible = wide
	caption.text = text
	empty.visible = true
	_paint()


func show_card(id: String, texture: Texture2D) -> void:
	card_id = id
	face.texture = texture
	empty.visible = false
	_paint()


func set_marked(on: bool) -> void:
	_marked = on
	_paint()


func _paint() -> void:
	var filled: bool = card_id != ""
	var edge: Color = ZenithTheme.ACCENT if _marked else (ZenithTheme.FRAME_DIM if filled else ZenithTheme.FRAME)
	var fill: Color = Color(0, 0, 0, 0.25) if filled else ZenithTheme.BG_INPUT
	var normal: StyleBoxFlat = ZenithTheme.box(fill, edge, 6, 2 if _marked else 1, 2, 2)
	var hover: StyleBoxFlat = ZenithTheme.box(fill if filled else ZenithTheme.HOVER, ZenithTheme.ACCENT, 6, 2, 2, 2)
	for state: String in ["normal", "focus", "disabled"]:
		add_theme_stylebox_override(state, normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
