class_name RosterTile
extends Button
## One deck in the library grid: portrait, deck name, duelist, playstyle, and a
## badge when the choosing seat holds it.

signal picked(index: int)

@onready var thumb: TextureRect = $Row/Thumb
@onready var deck_label: Label = $Row/Column/Deck
@onready var duelist_label: Label = $Row/Column/Duelist
@onready var school_label: Label = $Row/Column/School
@onready var badge: Label = $Badge
@onready var stars: PanelContainer = $Row/Stars

## Pip tint by mean stages cleared of the eight: gold from 6, green from 5, red below.
const STRENGTH_COLORS: Array = [
	[6.0, Color(0.95, 0.78, 0.35)],
	[5.0, Color(0.55, 0.80, 0.60)],
	[0.0, Color(0.88, 0.55, 0.45)],
]

var index: int = 0
var _school_color: Color = ZenithTheme.MUTED
var _hover_tween: Tween


func _ready() -> void:
	mouse_entered.connect(func() -> void: _hover(true))
	mouse_exited.connect(func() -> void: _hover(false))
	focus_entered.connect(func() -> void: _hover(true))
	focus_exited.connect(func() -> void: _hover(false))


func _hover(on: bool) -> void:
	if ArcaneBackdrop.motion_reduced():
		return
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	thumb.pivot_offset = thumb.size * 0.5
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.tween_property(thumb, "scale", Vector2.ONE * (1.045 if on else 1.0), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(thumb, "modulate", Color(1.12, 1.12, 1.12) if on else Color.WHITE, 0.18)


func setup(pos: int, d: DeckList) -> void:
	index = pos
	_school_color = Palette.school_ui(d.style)
	tooltip_text = "%s\n%s\n%s" % [d.name, d.tagline, d.blurb]
	add_theme_stylebox_override("focus", ZenithTheme.box(Color.TRANSPARENT, Color(0.8, 0.8, 0.8), 2, 2, 0, 0))
	var duelist: CardDef = Session.library.defs.get(d.duelist_face_id())
	thumb.texture = CardFace.art_texture(duelist, duelist.aspect) if duelist != null else null
	var fallback: Label = $Row/Thumb/Fallback
	fallback.visible = thumb.texture == null
	fallback.text = duelist.title.left(1) if duelist != null else "?"
	fallback.add_theme_color_override("font_color", _school_color.lightened(0.2))
	fallback.add_theme_stylebox_override("normal", ZenithTheme.box(Color(_school_color, 0.12), Color(_school_color, 0.25), 12, 1))
	# A starter's pip row says how it plays and how far it gets; the line stays for precons only.
	$Row/Column/Difficulty.visible = d.cleared <= 0.0
	$Row/Column/Difficulty.text = "%s to play  /  %d life cards" % [d.difficulty.capitalize(), d.cards.size()]
	deck_label.text = d.name
	duelist_label.text = duelist.title if duelist != null else d.duelist_face_id()
	school_label.text = "%s  /  %s" % [CardText.school_name(d.style).to_upper(), Archetype.label(d.archetype)]
	ZenithTheme.chip(school_label, Palette.school_ui(d.style))
	badge.visible = false
	# Adventure starters carry a five-pip pick rating along the bottom edge: stages cleared plus
	# ease of play, so the fullest row is the deck a new player should reach for.
	stars.visible = d.cleared > 0.0
	if d.cleared > 0.0:
		var filled: int = clampi(int(round(d.run_score() / 2.0)), 1, 5)
		var tint: Color = strength_color(d.cleared)
		stars.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0, 0))
		for i in range(5):
			var pip: Panel = $Row/Stars/StarRow.get_child(i)
			pip.add_theme_stylebox_override("panel", ZenithTheme.pip(i < filled, tint, true))
		stars.tooltip_text = "How good a first pick this deck is: ease of play and how far it gets in a run."


static func strength_color(cleared: float) -> Color:
	for band in STRENGTH_COLORS:
		if cleared >= float(band[0]):
			return band[1]
	return ZenithTheme.MUTED


## 0 hidden, 1 picked, 2 locked.
func set_badge(state: int, _text: String, color: Color) -> void:
	badge.visible = state > 0
	badge.text = "READY" if state == 2 else "SELECTED"
	var fill: Color = Color(0.17, 0.17, 0.17) if state > 0 else Color(0.075, 0.075, 0.075, 0.96)
	var edge: Color = Color(0.65, 0.65, 0.65) if state > 0 else Color(0.22, 0.22, 0.22)
	add_theme_stylebox_override("normal", ZenithTheme.box(fill, edge, 3, 2 if state > 0 else 1, 10, 10))
	add_theme_stylebox_override("hover", ZenithTheme.box(Color(0.20, 0.20, 0.20), Color(0.44, 0.44, 0.44), 2, 1, 10, 10))
	add_theme_stylebox_override("disabled", get_theme_stylebox("normal"))
	ZenithTheme.chip(badge, color, state == 2)


func _pressed() -> void:
	picked.emit(index)
