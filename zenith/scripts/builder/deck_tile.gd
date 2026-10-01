class_name DeckTile
extends Button
## One deck on the builder's "Your decks" page: the Duelist's portrait on a school-coloured edge, the
## deck name, its Duelist, school and size, and whether it is legal. A saved deck offers Edit, then
## Play when legal or Fix when not, with Duplicate and Delete under the "..." menu; a shipped deck
## offers Copy. A click anywhere else on the tile does what Edit or Copy does.

signal opened
## `ai_seat` 1 against the AI, -1 hotseat.
signal played(ai_seat: int)
signal fixed
signal duplicated
signal removed

const MENU_DUPLICATE: int = 0
const MENU_DELETE: int = 1

@onready var edge: ColorRect = $Row/Edge
@onready var art: TextureRect = $Row/Art
@onready var figure: TypeIcon = $Row/Art/Figure
@onready var name_label: Label = $Row/Column/Name
@onready var duelist_label: Label = $Row/Column/Duelist
@onready var school_chip: Label = $Row/Column/Chips/School
@onready var size_label: Label = $Row/Column/Chips/Size
@onready var status_label: Label = $Row/Column/Status
@onready var edit_button: Button = $Row/Column/Actions/Edit
@onready var play_button: MenuButton = $Row/Column/Actions/Play
@onready var more_button: MenuButton = $Row/Column/Actions/More

var _legal: bool = false


func _ready() -> void:
	pressed.connect(func() -> void: opened.emit())
	edit_button.pressed.connect(func() -> void: opened.emit())
	# Legal: a menu of how to play. Not legal: the same button reads Fix and opens the problems.
	var play_menu: PopupMenu = play_button.get_popup()
	play_menu.id_pressed.connect(func(id: int) -> void: played.emit(1 if id == 0 else -1))
	play_button.about_to_popup.connect(func() -> void:
		play_menu.clear()
		if _legal:
			play_menu.add_item("Duel the AI", 0)
			play_menu.add_item("Hotseat duel", 1))
	play_button.pressed.connect(func() -> void:
		if not _legal:
			fixed.emit())
	var menu: PopupMenu = more_button.get_popup()
	menu.add_item("Duplicate", MENU_DUPLICATE)
	menu.add_item("Delete", MENU_DELETE)
	menu.id_pressed.connect(func(id: int) -> void:
		if id == MENU_DUPLICATE:
			duplicated.emit()
		else:
			removed.emit())
	add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.BG, ZenithTheme.BORDER, ZenithTheme.RADIUS, 1, 10, 10))
	add_theme_stylebox_override("hover", ZenithTheme.box(ZenithTheme.BG_ACTIVE, ZenithTheme.FRAME, ZenithTheme.RADIUS, 2, 10, 10))
	add_theme_stylebox_override("pressed", ZenithTheme.box(ZenithTheme.BG_ACTIVE, ZenithTheme.ACCENT, ZenithTheme.RADIUS, 2, 10, 10))
	add_theme_stylebox_override("focus", ZenithTheme.box(Color.TRANSPARENT, ZenithTheme.ACCENT, ZenithTheme.RADIUS, 2, 0, 0))
	figure.type = CardDef.Type.PERSONALITY
	figure.color = Color(1, 1, 1, 0.3)


## `problems` is the validator's count; a shipped deck shows Copy where a saved one shows Edit.
func setup(deck: DeckList, library: CardLibrary, problems: int, shipped: bool) -> void:
	var duelist: CardDef = library.defs.get(deck.duelist_face_id())
	var top: CardDef = library.defs.get(deck.duelist_ids[deck.duelist_ids.size() - 1]) if not deck.duelist_ids.is_empty() else null
	var school: String = deck.style if deck.mastery_id != "" and deck.style != "freestyle" else ""
	edge.color = Palette.school_ui(school)
	art.texture = CardFace.art_texture(duelist, duelist.aspect) if duelist != null else null
	figure.visible = art.texture == null
	name_label.text = deck.name
	duelist_label.text = duelist.character if duelist != null else "No Duelist yet"
	if top != null and top.aspect_title != "":
		duelist_label.text += ", " + top.aspect_title
	school_chip.text = CardText.school_name(school).to_upper() if deck.mastery_id != "" else "NO MASTERY"
	ZenithTheme.chip(school_chip, Palette.school_ui(school))
	size_label.text = "%d cards" % deck.total_cards()
	_legal = problems == 0
	if shipped:
		var parts: PackedStringArray = PackedStringArray()
		if deck.archetype != "":
			parts.append(Archetype.label(deck.archetype))
		if deck.difficulty != "":
			parts.append(deck.difficulty.capitalize())
		status_label.text = "  ·  ".join(parts)
		status_label.add_theme_color_override("font_color", ZenithTheme.TEXT_SOFT)
	elif _legal:
		status_label.text = "Legal. Ready to play."
		status_label.add_theme_color_override("font_color", ZenithTheme.ENERGY)
	else:
		status_label.text = "%d %s to fix" % [problems, "problem" if problems == 1 else "problems"]
		status_label.add_theme_color_override("font_color", ZenithTheme.WARN)
	edit_button.text = "Copy" if shipped else "Edit"
	play_button.visible = not shipped
	play_button.text = "Play" if _legal else "Fix"
	play_button.theme_type_variation = &"AccentButton" if _legal else &""
	play_button.tooltip_text = "Duel the AI with this deck" if _legal else "Open it with its problems listed"
	more_button.visible = not shipped
	tooltip_text = "Copy %s into a new deck" % deck.name if shipped else "Edit %s" % deck.name


## The tile of a deck just saved or copied glows for a moment.
func pulse() -> void:
	if ArcaneBackdrop.motion_reduced():
		return
	modulate = Color(1.6, 1.5, 1.2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.9)
