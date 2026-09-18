class_name DeckSheet
extends PanelContainer
## One seat on the matchup screen: who the duelist is, their Aspect card (click cycles the
## Aspects) and their Mastery. Nothing else; the deck's make-up was read on the select screen.
## Each sheet's content is centred; the Aspect card sits on the side nearest the VS mark.

const HOVER_SCALE: float = 1.05
const FLIP_TIME: float = 0.11

@onready var tag: Label = $Column/Tag
@onready var duelist_label: Label = $Column/Duelist
@onready var deck_label: Label = $Column/Deck
@onready var tagline_label: Label = $Column/Tagline
@onready var chips: HFlowContainer = $Column/Chips
@onready var school_chip: Label = $Column/Chips/School
@onready var alignment_chip: Label = $Column/Chips/Alignment
@onready var archetype_chip: Label = $Column/Chips/Archetype
@onready var cards: HBoxContainer = $Column/Cards
@onready var portrait_box: VBoxContainer = $Column/Cards/PortraitBox
@onready var portrait: TextureRect = $Column/Cards/PortraitBox/Portrait
@onready var portrait_caption: Label = $Column/Cards/PortraitBox/Caption
@onready var mastery_box: VBoxContainer = $Column/Cards/MasteryBox
@onready var mastery: TextureRect = $Column/Cards/MasteryBox/Mastery
@onready var mastery_caption: Label = $Column/Cards/MasteryBox/MasteryCaption

var seat: int = 0
var _deck: DeckList = null
var _faces: CardFaceCache = null
var _aspect: int = 1                    # the duelist aspect the card shows
var _hovered: bool = false
var _hover_tween: Tween = null
var _flip_tween: Tween = null


func setup(index: int, faces: CardFaceCache) -> void:
	seat = index
	_faces = faces
	if index == 1:
		_mirror()
	portrait.gui_input.connect(_on_portrait_input)
	portrait.mouse_entered.connect(func() -> void: _hover_portrait(true))
	portrait.mouse_exited.connect(func() -> void: _hover_portrait(false))


## Player 2's Aspect card goes on the inner side too, so the two duelists face each other.
func _mirror() -> void:
	cards.move_child(portrait_box, 0)


func show_deck(d: DeckList, tag_text: String) -> void:
	_deck = d
	var duelist: CardDef = Session.library.defs.get(d.duelist_id)
	var school_color: Color = Palette.school_ui(d.style)
	var panel: StyleBoxFlat = ZenithTheme.edged(school_color, Color(school_color, 0.08), 14, 18, 16)
	if seat == 1:
		# The school stripe sits on each panel's outer edge.
		panel.border_width_right = panel.border_width_left
		panel.border_width_left = 0
		panel.content_margin_right = panel.content_margin_left
		panel.content_margin_left = 18
	add_theme_stylebox_override("panel", panel)
	tag.text = tag_text
	duelist_label.text = duelist.title if duelist != null else d.duelist_id
	deck_label.text = d.name
	tagline_label.text = d.tagline
	school_chip.text = CardText.school_name(d.style)
	ZenithTheme.chip(school_chip, school_color)
	alignment_chip.text = d.alignment.capitalize()
	ZenithTheme.chip(alignment_chip, ZenithTheme.MUTED)
	archetype_chip.visible = Archetype.label(d.archetype) != ""
	archetype_chip.text = Archetype.label(d.archetype)
	ZenithTheme.chip(archetype_chip, ZenithTheme.DEFEND)
	var mastery_def: CardDef = Session.library.defs.get(d.mastery_id)
	mastery_box.visible = mastery_def != null
	if mastery_def != null:
		mastery_caption.text = mastery_def.title
		_show_mastery(mastery_def)
	show_aspect(duelist.lowest_aspect() if duelist != null else 1)


## The card lifts a little under the pointer, the way a hand card does, so it reads as
## something to click.
func _hover_portrait(over: bool) -> void:
	_hovered = over
	portrait.pivot_offset = portrait.size * 0.5
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(portrait, "scale", Vector2.ONE * (HOVER_SCALE if over else 1.0), 0.12)
	_hover_tween.tween_property(portrait, "modulate", Color(1.08, 1.08, 1.08) if over else Color.WHITE, 0.12)
	portrait_caption.add_theme_color_override("font_color", ZenithTheme.ACCENT if over else ZenithTheme.MUTED)


## The card cycles through the duelist's Aspects on click; the matching ladder row lights up.
func _on_portrait_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var aspects: Array[int] = _shown_aspects()
		if aspects.size() < 2:
			return
		show_aspect(aspects[(aspects.find(_aspect) + 1) % aspects.size()], true)


## Aspects the deck plays with, lowest first.
func _shown_aspects() -> Array[int]:
	var out: Array[int] = []
	var duelist: CardDef = Session.library.defs.get(_deck.duelist_id) if _deck != null else null
	if duelist == null:
		return out
	for t in duelist.aspects:
		var aspect: int = int(t.get("aspect", 0))
		if aspect <= _deck.aspects:
			out.append(aspect)
	out.sort()
	return out


## With `flip`, the card turns edge-on, swaps its face and turns back, as a card being turned
## over; a fresh deck just shows the face.
func show_aspect(aspect: int, flip: bool = false) -> void:
	var duelist: CardDef = Session.library.defs.get(_deck.duelist_id) if _deck != null else null
	if duelist == null:
		portrait.texture = null
		portrait_caption.text = ""
		return
	_aspect = aspect
	var aspects: Array[int] = _shown_aspects()
	var last: bool = aspects.size() < 2
	portrait_caption.text = CardText.aspect_name(aspect, duelist) + ("" if last else "  ·  click for the next aspect")
	var face: Texture2D = await _faces.render_face(duelist, aspect)
	if _aspect != aspect:
		return   # another click came in while the face rendered
	if not flip:
		portrait.texture = face
		return
	if _flip_tween != null:
		_flip_tween.kill()
	portrait.pivot_offset = portrait.size * 0.5
	var rest: float = HOVER_SCALE if _hovered else 1.0
	_flip_tween = create_tween()
	_flip_tween.tween_property(portrait, "scale:x", 0.0, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flip_tween.tween_callback(func() -> void: portrait.texture = face)
	_flip_tween.tween_property(portrait, "scale:x", rest, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _show_mastery(def: CardDef) -> void:
	var face: Texture2D = await _faces.render_face(def)
	if _deck != null and _deck.mastery_id == def.id:
		mastery.texture = face
