class_name BuilderCard
extends Control
## One card in the deck builder's library: its face once rendered (its title until then), a band
## with the title readable at tile size, copies in the deck against the card's limit, and its state:
## a light veil at the limit, dimmed and tagged ("Pact only") when the deck cannot run or use it.
## Hovering lifts it. The screen owns the rules and the drags; this reports a click on release, so a
## drag never also counts as a click.

## `button` is MOUSE_BUTTON_LEFT or MOUSE_BUTTON_RIGHT; `shift` asks for the Reserve.
signal clicked(button: int, shift: bool)
signal hovered(over: bool)

@onready var body: Control = $Body
@onready var face: TextureRect = $Body/Face
@onready var placeholder: Label = $Body/Placeholder
@onready var veil: ColorRect = $Body/Veil
@onready var band: Label = $Body/Band
@onready var tag: Label = $Body/Tag
@onready var ring: Panel = $Body/Ring
@onready var count_chip: Label = $Body/Count

var card_id: String = ""
var has_face: bool = false
## Why the deck cannot run or use this card, "" when it can.
var reason: String = ""
var _pressed: int = 0
var _pop: Tween
var _lift: Tween


func _ready() -> void:
	placeholder.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.RAISED, ZenithTheme.BORDER, 8, 1, 10, 10))
	band.add_theme_stylebox_override("normal", ZenithTheme.box(Color(0.04, 0.035, 0.04, 0.9), Color(0, 0, 0, 0), 0, 0, 6, 2))
	ring.add_theme_stylebox_override("panel", ZenithTheme.box(Color.TRANSPARENT, ZenithTheme.ACCENT, 8, 2, 0, 0))
	ZenithTheme.chip(tag, ZenithTheme.FRAME_DIM, true)
	mouse_entered.connect(func() -> void:
		_hover(true)
		hovered.emit(true))
	mouse_exited.connect(func() -> void:
		_hover(false)
		hovered.emit(false))
	resized.connect(func() -> void: body.pivot_offset = size * 0.5)


func show_card(def: CardDef, size_value: Vector2) -> void:
	card_id = def.id
	custom_minimum_size = size_value
	placeholder.text = def.title
	placeholder.add_theme_color_override("font_color", Palette.type_ui(def.type).lightened(0.25))
	band.text = def.title
	# Allies share a name across Aspects and lines; the band says which one this is.
	if def.type == CardDef.Type.PERSONALITY:
		band.text = "%s %d" % [def.character.get_slice(" ", 0).trim_suffix(","), def.aspect] \
			+ (" · " + def.aspect_title if def.aspect_title != "" else "")
		tooltip_text = "%s, Aspect %d%s" % [def.character, def.aspect, (" · " + def.aspect_title) if def.aspect_title != "" else ""]
	var school: String = def.school
	band.add_theme_color_override("font_color", Palette.school_ui(school).lightened(0.35) if school != "" else ZenithTheme.TEXT)


func set_face(texture: Texture2D) -> void:
	face.texture = texture
	has_face = texture != null
	placeholder.visible = not has_face


## `copies` in the deck of `limit`; `full` when another copy cannot go in for a count reason;
## `why` and `short` are set for a card the deck can never run or use.
func set_state(copies: int, limit: int, full: bool, why: String, short: String) -> void:
	var text: String = "%d/%d" % [copies, limit]
	if count_chip.text != text and copies > 0 and count_chip.visible:
		_bump()
	count_chip.text = text
	count_chip.visible = copies > 0
	ZenithTheme.chip(count_chip, ZenithTheme.ENERGY if copies >= limit else ZenithTheme.ACCENT, true)
	reason = why
	veil.visible = full or why != ""
	veil.color = Color(0.02, 0.02, 0.02, 0.62 if why != "" else 0.32)
	body.modulate = Color(0.72, 0.72, 0.72) if why != "" else Color.WHITE
	tag.visible = why != ""
	tag.text = short


## A refused add: a short shake.
func shake() -> void:
	if ArcaneBackdrop.motion_reduced():
		return
	var tween: Tween = create_tween()
	for x: float in [7.0, -6.0, 4.0, -2.0, 0.0]:
		tween.tween_property(body, "position:x", x, 0.04)


func _hover(on: bool) -> void:
	ring.visible = on
	if ArcaneBackdrop.motion_reduced():
		return
	if _lift != null and _lift.is_valid():
		_lift.kill()
	_lift = create_tween()
	_lift.tween_property(body, "scale", Vector2.ONE * (1.04 if on else 1.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _bump() -> void:
	if ArcaneBackdrop.motion_reduced():
		return
	if _pop != null and _pop.is_valid():
		_pop.kill()
	count_chip.pivot_offset = count_chip.size * 0.5
	count_chip.scale = Vector2.ONE * 1.35
	_pop = create_tween()
	_pop.tween_property(count_chip, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or (press.button_index != MOUSE_BUTTON_LEFT and press.button_index != MOUSE_BUTTON_RIGHT):
		return
	if press.pressed:
		_pressed = press.button_index
	elif _pressed == press.button_index:
		_pressed = 0
		if Rect2(Vector2.ZERO, size).has_point(press.position):
			clicked.emit(press.button_index, press.shift_pressed)
	accept_event()
