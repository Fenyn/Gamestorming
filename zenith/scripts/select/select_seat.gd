class_name SelectSeat
extends PanelContainer
## The choosing player's panel on the duelist select: the picked duelist's portrait at a whole
## pixel scale, who they are and how the deck plays, the deck's make-up, and Lock in. One panel
## serves every seat in turn; `set_seat` points it at whoever is choosing.

signal lock_toggled(seat: int, locked: bool)
signal name_changed(seat: int, player_name: String)

@onready var portrait_box: Control = $Row/Scroll/Content/Tabs/Overview/Hero/PortraitBox
@onready var silhouette: Label = $Row/Scroll/Content/Tabs/Overview/Hero/PortraitBox/Silhouette
@onready var portrait: TextureRect = $Row/Scroll/Content/Tabs/Overview/Hero/PortraitBox/Portrait
@onready var stamp: Label = $Row/Scroll/Content/Tabs/Overview/Hero/PortraitBox/Stamp
@onready var tag: Label = $Row/Header/Tag
@onready var name_edit: LineEdit = $Row/Header/Name
@onready var duelist_label: Label = $Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll/Identity/Duelist
@onready var deck_label: Label = $Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll/Identity/Deck
@onready var tagline_label: Label = $Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll/Identity/Tagline
@onready var chips: HFlowContainer = $Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll/Identity/Chips
@onready var school_chip: Label = $Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll/Identity/Chips/School
@onready var alignment_chip: Label = $Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll/Identity/Chips/Alignment
@onready var archetype_chip: Label = $Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll/Identity/Chips/Archetype
@onready var difficulty_chip: Label = $Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll/Identity/Chips/Difficulty
@onready var blurb_label: Label = $Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll/Identity/Blurb
@onready var aspect_header: Label = $Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll/Identity/AspectHeader
@onready var aspect_title: Label = $Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll/Identity/AspectTitle
@onready var aspect_power: Label = $Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll/Identity/AspectPower
@onready var lock_button: Button = $Row/Lock
@onready var hint_label: Label = $Row/Hint
@onready var info: DeckInfo = $"Row/Scroll/Content/Tabs/Details/Cards & Aspects"

@onready var mastery_box: Control = $Row/Scroll/Content/Tabs/Overview/Summary/Mastery
@onready var mastery_card: TextureRect = $Row/Scroll/Content/Tabs/Overview/Summary/Mastery/Card
@onready var mastery_zoom: TextureRect = $MasteryZoom

var _mastery_generation: int = 0
var seat: int = 0
var faces: CardFaceCache = null   # set by the screen before the first set_seat
var deck: DeckList = null
var locked: bool = false
var _aspect: int = 1              # the Aspect the portrait and the Aspect block show
var _might_max: int = 1
var _color: Color = ZenithTheme.MUTED
var _tween: Tween = null


func _ready() -> void:
	var portrait_material: ShaderMaterial = ShaderMaterial.new()
	portrait_material.shader = preload("res://assets/hero_portrait.gdshader")
	portrait.material = portrait_material
	_might_max = DeckInfo.might_max_of(Session.decks)
	mastery_card.mouse_entered.connect(_show_mastery_zoom)
	mastery_card.focus_entered.connect(_show_mastery_zoom)
	mastery_card.mouse_exited.connect(func() -> void: mastery_zoom.hide())
	mastery_card.focus_exited.connect(func() -> void: mastery_zoom.hide())
	name_edit.text_changed.connect(func(t: String) -> void:
		Session.player_names[seat] = t if t.strip_edges() != "" else "Player %d" % (seat + 1)
		name_changed.emit(seat, Session.player_names[seat]))
	lock_button.pressed.connect(func() -> void: lock_toggled.emit(seat, not locked))
	portrait_box.resized.connect(_layout_portrait)
	portrait.gui_input.connect(_on_portrait_input)
	info.aspect_clicked.connect(func(aspect: int) -> void: show_aspect(aspect))
	$Row/Details.pressed.connect(func() -> void:
		var tabs: TabContainer = $Row/Scroll/Content/Tabs
		tabs.current_tab = 1 - tabs.current_tab
	)
	$Row/Scroll/Content/Tabs.tab_changed.connect(func(tab_index: int) -> void:
		$Row/Details.text = "Back to duelist" if tab_index == 1 else "Details"
		$Row/Selection.visible = tab_index == 1
		mastery_zoom.hide())


## Opens the deck detail tab, where the Aspect chips and the Life Deck make-up are. The Details
## button does the same; this is what `--dev-details` calls for a screenshot.
func show_details() -> void:
	if deck != null:
		($Row/Scroll/Content/Tabs as TabContainer).current_tab = 1


## Points the panel at `index`, showing that seat's current pick and lock state.
func set_seat(index: int, tag_text: String) -> void:
	seat = index
	tag.text = tag_text
	name_edit.text = Session.player_names[index]
	show_deck(Session.chosen[index])
	set_locked(Session.locked[index])


func show_deck(d: DeckList) -> void:
	deck = d
	$Row/Scroll/Content/Tabs/Overview/Summary/IdentityScroll.scroll_vertical = 0
	_show_mastery(d)
	$Row/Selection.text = d.name if d != null else "No deck selected"
	$Row/Scroll/Content/Tabs.current_tab = 0
	$Row/Details.text = "Details"
	$Row/Details.disabled = d == null
	var has: bool = d != null
	portrait.visible = has
	$Row/Scroll/Content/Tabs/Overview/Hero.visible = has
	$Row/Scroll/Content/Tabs.set_tab_disabled(1, not has)
	silhouette.visible = not has
	chips.visible = has
	blurb_label.visible = false
	aspect_header.visible = has
	aspect_title.visible = has
	aspect_power.visible = false
	deck_label.visible = true
	tagline_label.visible = true
	duelist_label.visible = has
	lock_button.disabled = not has
	if not has:
		_color = ZenithTheme.MUTED
		deck_label.text = "Choose your deck"
		tagline_label.text = "Select a deck to explore its duelist, playstyle, and cards."
		$Row/Scroll/Content/Tabs.current_tab = 0
		_paint()
		return
	var duelist: CardDef = Session.library.defs.get(d.duelist_face_id())
	# The panel edge and stamp carry the player colour for this battle; the chip below still
	# names the school.
	_color = Session.seat_color(seat)
	duelist_label.text = duelist.title if duelist != null else d.duelist_face_id()
	deck_label.text = d.name
	tagline_label.text = d.tagline
	school_chip.text = CardText.school_name(d.style)
	ZenithTheme.chip(school_chip, Palette.school_ui(d.style))
	alignment_chip.text = d.alignment.capitalize()
	ZenithTheme.chip(alignment_chip, ZenithTheme.MUTED)
	archetype_chip.visible = Archetype.label(d.archetype) != ""
	archetype_chip.text = Archetype.label(d.archetype)
	ZenithTheme.chip(archetype_chip, ZenithTheme.DEFEND)
	difficulty_chip.visible = false
	difficulty_chip.text = "%s to play" % d.difficulty.capitalize()
	ZenithTheme.chip(difficulty_chip, ZenithTheme.ACCENT)
	blurb_label.text = d.blurb
	info.show_deck(d, _might_max, faces)
	$Row/Scroll/Content/Tabs/Details.scroll_vertical = 0
	show_aspect(duelist.aspect if duelist != null else 1)
	_paint()


## Aspects the deck plays with, lowest first.
func _shown_aspects() -> Array[int]:
	var out: Array[int] = []
	if deck == null:
		return out
	for def in deck.duelist_stack(Session.library).defs:
		out.append(def.aspect)
	out.sort()
	return out


## Shows one Aspect: its art in the portrait, its title and power in the Aspect block, its chip lit.
## Each Aspect is its own card, so this looks up the card for that tier.
func show_aspect(aspect: int) -> void:
	var stack: PersonalityStack = deck.duelist_stack(Session.library) if deck != null else null
	var duelist: CardDef = stack.def_for(aspect) if stack != null else null
	if duelist == null:
		return
	_aspect = aspect
	var aspects: Array[int] = _shown_aspects()
	var mixed: bool = CardText.stack_mixes_lines(stack)
	portrait.texture = CardFace.art_texture(duelist, aspect)
	portrait.tooltip_text = "%s\n%s - click to preview next Aspect" % [
		CardText.rung_label(duelist, mixed), CardText.personality_name(duelist)]
	silhouette.visible = portrait.texture == null
	silhouette.text = duelist.title.left(1)
	silhouette.add_theme_color_override("font_color", _color)
	_layout_portrait()
	# The tier is the card's own Aspect number, not its place in the row: a stack is consecutive
	# from 1, so the two agree, and reading it off the card is what stays true if that ever changes.
	aspect_header.text = "ASPECT %d OF %d  ·  SURGE %d" % [duelist.aspect, aspects.size(), int(duelist.aspect_data(aspect).get("surge", 0))]
	# The line word appears only where a stack climbs through more than one of a character's lines.
	aspect_title.text = CardText.aspect_name(aspect, duelist)
	if mixed and duelist.variant != "":
		aspect_title.text += "  ·  %s" % duelist.variant
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
	lock_button.text = "Change champion" if on else "Confirm champion"
	lock_button.theme_type_variation = &"Button" if on else &"AccentButton"
	name_edit.editable = not on
	if on:
		_pop(stamp)
	_paint()


## School light and the lock stamp carry identity; the panel uses Godot-drawn styling.
func _paint() -> void:
	add_theme_stylebox_override("panel", SanctumUI.panel())
	var aura: ArcaneBackdrop = portrait_box.get_node("Aura")
	aura.set_school(Palette.school_ui(deck.style) if deck != null else Color(0.34, 0.74, 0.82))
	if locked:
		aura.confirm()
	ZenithTheme.chip(stamp, _color, true)
	if locked:
		hint_label.text = "Locked in. Click Change to pick again."
	elif deck != null:
		hint_label.text = "Choose an Aspect to inspect its stats." if $Row/Scroll/Content/Tabs.current_tab == 1 else "Click the portrait to preview the next Aspect."
	else:
		hint_label.text = ""


## Fit the complete portrait to the available stage without cropping or stretching.
func _layout_portrait() -> void:
	if portrait.texture == null:
		return
	var tex: Vector2 = portrait.texture.get_size()
	var box: Vector2 = portrait_box.size
	var fit: float = minf(box.x / tex.x, box.y / tex.y)
	var k: float = fit
	portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
	portrait.size = tex * k
	portrait.position = (box - portrait.size) * 0.5
	portrait.pivot_offset = portrait.size * 0.5


func _pop(node: Control) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if ArcaneBackdrop.motion_reduced():
		node.scale = Vector2.ONE
		node.modulate = Color.WHITE
		return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * 1.06
	node.modulate = Color(1.3, 1.3, 1.3)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(node, "scale", Vector2.ONE, 0.18)
	_tween.tween_property(node, "modulate", Color.WHITE, 0.25)


## Mastery geometry is fixed in the scene, independent of the scrolling identity text.
func _show_mastery(d: DeckList) -> void:
	_mastery_generation += 1
	var generation: int = _mastery_generation
	mastery_card.texture = null
	mastery_box.hide()
	mastery_zoom.hide()
	if d == null or faces == null:
		return
	var def: CardDef = Session.library.defs.get(d.mastery_id)
	if def == null:
		return
	var texture: Texture2D = await faces.render_face(def)
	if generation != _mastery_generation:
		return
	mastery_card.texture = texture
	mastery_box.show()
	if mastery_card.has_focus():
		_show_mastery_zoom()


func _show_mastery_zoom() -> void:
	if mastery_card.texture == null or not mastery_card.is_visible_in_tree():
		return
	mastery_zoom.texture = mastery_card.texture
	var view: Vector2 = get_viewport_rect().size
	var origin: Vector2 = mastery_card.global_position
	var pos: Vector2 = origin - Vector2(mastery_zoom.size.x + 12, (mastery_zoom.size.y - mastery_card.size.y) * 0.5)
	pos.x = clampf(pos.x, 8, maxf(8, view.x - mastery_zoom.size.x - 8))
	pos.y = clampf(pos.y, 8, maxf(8, view.y - mastery_zoom.size.y - 8))
	mastery_zoom.global_position = pos
	mastery_zoom.show()
