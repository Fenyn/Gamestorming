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

var index: int = 0
var _school_color: Color = ZenithTheme.MUTED


func setup(pos: int, d: DeckList) -> void:
	index = pos
	_school_color = Palette.school_ui(d.style)
	tooltip_text = "%s\n%s\n%s" % [d.name, d.tagline, d.blurb]
	add_theme_stylebox_override("focus", ZenithTheme.box(Color.TRANSPARENT, ZenithTheme.ACCENT, 12, 2, 0, 0))
	var duelist: CardDef = Session.library.defs.get(d.duelist_face_id())
	thumb.texture = CardFace.art_texture(duelist, duelist.aspect) if duelist != null else null
	var fallback: Label = $Row/Thumb/Fallback
	fallback.visible = thumb.texture == null
	fallback.text = duelist.title.left(1) if duelist != null else "?"
	fallback.add_theme_color_override("font_color", _school_color.lightened(0.2))
	fallback.add_theme_stylebox_override("normal", ZenithTheme.box(Color(_school_color, 0.12), Color(_school_color, 0.25), 12, 1))
	$Row/Column/Difficulty.text = "%s to play  /  %d life cards" % [d.difficulty.capitalize(), d.cards.size()]
	deck_label.text = d.name
	duelist_label.text = duelist.title if duelist != null else d.duelist_face_id()
	school_label.text = "%s  /  %s" % [CardText.school_name(d.style).to_upper(), Archetype.label(d.archetype)]
	ZenithTheme.chip(school_label, Palette.school_ui(d.style))
	badge.visible = false


## 0 hidden, 1 picked, 2 locked.
func set_badge(state: int, _text: String, color: Color) -> void:
	badge.visible = state > 0
	badge.text = "READY" if state == 2 else "SELECTED"
	var fill: Color = Color(_school_color, 0.16) if state > 0 else Color(0.075, 0.085, 0.11)
	var edge: Color = ZenithTheme.ACCENT if state > 0 else Color(1, 1, 1, 0.10)
	add_theme_stylebox_override("normal", ZenithTheme.box(fill, edge, 12, 2 if state > 0 else 1, 14, 10))
	add_theme_stylebox_override("disabled", get_theme_stylebox("normal"))
	ZenithTheme.chip(badge, color, state == 2)


func _pressed() -> void:
	picked.emit(index)
