class_name SelectSeat
extends PanelContainer
## The choosing player's panel on the duelist select: the picked duelist's portrait at a whole
## pixel scale, who they are and how the deck plays, the deck's make-up, and Lock in. One panel
## serves every seat in turn; `set_seat` points it at whoever is choosing.

signal lock_toggled(seat: int, locked: bool)
signal name_changed(seat: int, player_name: String)

@onready var portrait_box: Control = $Row/PortraitBox
@onready var silhouette: Label = $Row/PortraitBox/Silhouette
@onready var portrait: TextureRect = $Row/PortraitBox/Portrait
@onready var stamp: Label = $Row/PortraitBox/Stamp
@onready var tag: Label = $Row/Identity/Header/Tag
@onready var name_edit: LineEdit = $Row/Identity/Header/Name
@onready var duelist_label: Label = $Row/Identity/Duelist
@onready var deck_label: Label = $Row/Identity/Deck
@onready var tagline_label: Label = $Row/Identity/Tagline
@onready var chips: HFlowContainer = $Row/Identity/Chips
@onready var school_chip: Label = $Row/Identity/Chips/School
@onready var alignment_chip: Label = $Row/Identity/Chips/Alignment
@onready var archetype_chip: Label = $Row/Identity/Chips/Archetype
@onready var difficulty_chip: Label = $Row/Identity/Chips/Difficulty
@onready var blurb_label: Label = $Row/Identity/Blurb
@onready var aspect_header: Label = $Row/Identity/AspectHeader
@onready var aspect_title: Label = $Row/Identity/AspectTitle
@onready var aspect_power: Label = $Row/Identity/AspectPower
@onready var lock_button: Button = $Row/Identity/Lock
@onready var hint_label: Label = $Row/Identity/Hint
@onready var info: DeckInfo = $Row/Info

var seat: int = 0
var faces: CardFaceCache = null   # set by the screen before the first set_seat
var deck: DeckList = null
var locked: bool = false
var _aspect: int = 1              # the Aspect the portrait and the Aspect block show
var _might_max: int = 1
var _color: Color = ZenithTheme.MUTED
var _tween: Tween = null


func _ready() -> void:
	_might_max = DeckInfo.might_max_of(Session.decks)
	name_edit.text_changed.connect(func(t: String) -> void:
		Session.player_names[seat] = t if t.strip_edges() != "" else "Player %d" % (seat + 1)
		name_changed.emit(seat, Session.player_names[seat]))
	lock_button.pressed.connect(func() -> void: lock_toggled.emit(seat, not locked))
	portrait_box.resized.connect(_layout_portrait)
	portrait.gui_input.connect(_on_portrait_input)
	info.aspect_clicked.connect(func(aspect: int) -> void: show_aspect(aspect))


## Points the panel at `index`, showing that seat's current pick and lock state.
func set_seat(index: int, tag_text: String) -> void:
	seat = index
	tag.text = tag_text
	name_edit.text = Session.player_names[index]
	show_deck(Session.chosen[index])
	set_locked(Session.locked[index])


func show_deck(d: DeckList) -> void:
	deck = d
	var has: bool = d != null
	portrait.visible = has
	silhouette.visible = not has
	chips.visible = has
	info.visible = has
	blurb_label.visible = has
	aspect_header.visible = has
	aspect_title.visible = has
	aspect_power.visible = has
	deck_label.visible = has
	lock_button.disabled = not has
	if not has:
		_color = ZenithTheme.MUTED
		duelist_label.text = "Choose a duelist"
		tagline_label.text = "Pick from the roster below."
		_paint()
		return
	var duelist: CardDef = Session.library.defs.get(d.duelist_id)
	_color = Palette.school_ui(d.style)
	duelist_label.text = duelist.title if duelist != null else d.duelist_id
	deck_label.text = d.name
	tagline_label.text = d.tagline
	school_chip.text = CardText.school_name(d.style)
	ZenithTheme.chip(school_chip, _color)
	alignment_chip.text = d.alignment.capitalize()
	ZenithTheme.chip(alignment_chip, ZenithTheme.MUTED)
	archetype_chip.visible = Archetype.label(d.archetype) != ""
	archetype_chip.text = Archetype.label(d.archetype)
	ZenithTheme.chip(archetype_chip, ZenithTheme.DEFEND)
	difficulty_chip.visible = d.difficulty != ""
	difficulty_chip.text = "%s to play" % d.difficulty.capitalize()
	ZenithTheme.chip(difficulty_chip, ZenithTheme.ACCENT)
	blurb_label.text = d.blurb
	info.show_deck(d, _might_max, faces)
	show_aspect(duelist.lowest_aspect() if duelist != null else 1)
	_paint()


## Aspects the deck plays with, lowest first.
func _shown_aspects() -> Array[int]:
	var out: Array[int] = []
	var duelist: CardDef = Session.library.defs.get(deck.duelist_id) if deck != null else null
	if duelist == null:
		return out
	for t in duelist.aspects:
		var aspect: int = int(t.get("aspect", 0))
		if aspect <= deck.aspects:
			out.append(aspect)
	out.sort()
	return out


## Shows one Aspect: its art in the portrait, its title and power in the Aspect block, its chip lit.
func show_aspect(aspect: int) -> void:
	var duelist: CardDef = Session.library.defs.get(deck.duelist_id) if deck != null else null
	if duelist == null:
		return
	_aspect = aspect
	var aspects: Array[int] = _shown_aspects()
	portrait.texture = CardFace.art_texture(duelist, aspect)
	_layout_portrait()
	aspect_header.text = "ASPECT %d OF %d  ·  SURGE %d" % [aspects.find(aspect) + 1, aspects.size(), int(duelist.aspect_data(aspect).get("surge", 0))]
	aspect_title.text = CardText.aspect_name(aspect, duelist)
	aspect_power.text = "
".join(CardText.aspect_text(duelist, aspect))
	info.highlight_aspect(aspect)
	_pop(portrait)


## Clicking the portrait steps to the next Aspect, wrapping.
func _on_portrait_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var aspects: Array[int] = _shown_aspects()
		if aspects.size() > 1:
			show_aspect(aspects[(aspects.find(_aspect) + 1) % aspects.size()])


func set_locked(on: bool) -> void:
	locked = on
	stamp.visible = on
	lock_button.text = "Change" if on else "Lock in"
	lock_button.theme_type_variation = &"Button" if on else &"AccentButton"
	name_edit.editable = not on
	if on:
		_pop(stamp)
	_paint()


## The panel edge and tint follow the school.
func _paint() -> void:
	var edge: Color = _color if deck != null else ZenithTheme.BORDER
	var bg: Color = Color(_color, 0.10) if deck != null else ZenithTheme.BG
	add_theme_stylebox_override("panel", ZenithTheme.edged(edge, bg, 14, 18, 16))
	ZenithTheme.chip(stamp, _color, true)
	if locked:
		hint_label.text = "Locked in. Click Change to pick again."
	elif deck != null:
		hint_label.text = "Enter locks in. Left and right move through the roster. Click the portrait or an Aspect to see each step of the climb."
	else:
		hint_label.text = ""


## Pixel art stays crisp at a whole-number scale, centred in its box.
func _layout_portrait() -> void:
	if portrait.texture == null:
		return
	var tex: Vector2 = portrait.texture.get_size()
	var box: Vector2 = portrait_box.size
	var k: float = maxf(1.0, floorf(minf(box.x / tex.x, box.y / tex.y)))
	portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
	portrait.size = tex * k
	portrait.position = (box - portrait.size) * 0.5
	portrait.pivot_offset = portrait.size * 0.5


func _pop(node: Control) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * 1.06
	node.modulate = Color(1.3, 1.3, 1.3)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(node, "scale", Vector2.ONE, 0.18)
	_tween.tween_property(node, "modulate", Color.WHITE, 0.25)
