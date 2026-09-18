class_name RosterTile
extends Button
## One deck on the roster strip: portrait thumbnail, deck name, duelist, school chip, and a
## badge when the choosing seat holds it.

signal picked(index: int)

@onready var thumb: TextureRect = $Row/Thumb
@onready var deck_label: Label = $Row/Column/Deck
@onready var duelist_label: Label = $Row/Column/Duelist
@onready var school_label: Label = $Row/Column/School
@onready var badge: Label = $Badge

var index: int = 0


func setup(pos: int, d: DeckList) -> void:
	index = pos
	var duelist: CardDef = Session.library.defs.get(d.duelist_id)
	thumb.texture = CardFace.art_texture(duelist, duelist.lowest_aspect()) if duelist != null else null
	deck_label.text = d.name
	duelist_label.text = duelist.title if duelist != null else d.duelist_id
	school_label.text = CardText.school_name(d.style).to_upper()
	ZenithTheme.chip(school_label, Palette.school_ui(d.style))
	badge.visible = false


## 0 hidden, 1 picked, 2 locked.
func set_badge(state: int, text: String, color: Color) -> void:
	badge.visible = state > 0
	badge.text = text
	ZenithTheme.chip(badge, color, state == 2)


func _pressed() -> void:
	picked.emit(index)
