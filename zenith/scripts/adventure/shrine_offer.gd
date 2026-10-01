class_name ShrineOffer
extends Control
## One offer at the Shrine: the Resonance's medallion, its name, a chip naming what it serves (STYLE
## for a style Resonance), its sentence, and a style Resonance's penalty in the penalty colour. The
## whole panel is the button. The Shrine screen owns the rules and wires the signals.

signal pressed
signal hovered(over: bool)

const LIFT: float = 10.0

@onready var body: Control = $Body
@onready var glow: Panel = $Body/Glow
@onready var frame: PanelContainer = $Body/Frame
@onready var sigil: ResonanceSigil = $Body/Frame/Column/Sigil
@onready var name_label: Label = $Body/Frame/Column/Name
@onready var chip: Label = $Body/Frame/Column/ChipRow/Chip
@onready var effect: Label = $Body/Frame/Column/Effect
@onready var rule: HSeparator = $Body/Frame/Column/Rule
@onready var penalty: Label = $Body/Frame/Column/Penalty

var _over: bool = false
var _tween: Tween = null


func _ready() -> void:
	frame.add_theme_stylebox_override("panel", MapArt.panel_box(22))
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	($Body/Frame/Column as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sigil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	name_label.add_theme_font_override("font", ZenithTheme.TITLE_FONT)
	effect.add_theme_color_override("font_color", ZenithTheme.TEXT)
	# Two pixels at the design size, so the rule survives the scale down to 720p.
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = ZenithTheme.FRAME_DIM
	line.thickness = 2
	rule.add_theme_stylebox_override("separator", line)
	penalty.add_theme_color_override("font_color", ZenithTheme.PENALTY)
	frame.mouse_entered.connect(_check_hover)
	frame.mouse_exited.connect(_check_hover)
	frame.gui_input.connect(_on_input)


## Fills the panel for Resonance `id`; `tag` is the chip's word.
func show_offer(id: String, tag: String) -> void:
	sigil.resonance = id
	name_label.text = ResonanceData.name_of(id)
	var style: bool = ResonanceData.is_style(id)
	chip.text = Archetype.subtheme_label(tag).to_upper() if not style else "STYLE"
	ZenithTheme.chip(chip, ZenithTheme.PENALTY if style else ZenithTheme.FRAME)
	effect.text = ResonanceData.effect_of(id)
	penalty.text = ResonanceData.penalty_of(id)
	penalty.visible = penalty.text != ""
	rule.visible = penalty.visible


## Raises the panel with a bone glow round it and lights the medallion's ring, or settles it back.
func lift(up: bool, instant: bool) -> void:
	glow.visible = up
	sigil.lit = up
	var target: float = -LIFT if up else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if instant:
		body.position.y = target
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(body, "position:y", target, 0.12)


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
