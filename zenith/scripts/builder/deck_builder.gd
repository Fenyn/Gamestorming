extends Control
## The deck builder. It opens on "Your decks": saved decks as tiles, a New deck tile, the shipped
## decks to copy, and a banner to resume a deck left unsaved. A new deck starts with two picks, the
## Duelist and then the Mastery; the library then shows only what that deck can run and somebody in
## it can use, clumped by school and card type. The editor's deck column carries the Duelist and
## Mastery cards, the Aspect stack and Relic, counters, a type bar, the Life Deck as strips and a
## Reserve drawer. Click adds, right-click or a strip click takes out, drags work both ways, Ctrl+Z /
## Ctrl+Y undo and redo, every edit is autosaved as a draft. Rules live in DeckDraft and DeckImport;
## saved decks in CustomDecks, and Session lists the legal ones for play.

const CARD_SCENE: PackedScene = preload("res://scenes/builder/builder_card.tscn")
const DECK_TILE: PackedScene = preload("res://scenes/builder/deck_tile.tscn")
## The smallest library tile; tiles grow to fill the panel's width.
const MIN_CARD: Vector2 = Vector2(150, 210)
const CARD_RATIO: float = 1.4
const STRIP_HEIGHT: int = 34
const STRIP_FONT: int = 20
const PREVIEW_GAP: float = 14.0
const RENDER_AHEAD: float = 420.0
const UNDO_DEPTH: int = 200
## A printing in the Aspect picker, big enough to read its rules text.
const ASPECT_CARD: Vector2 = Vector2(300, 420)
const TOAST_SECONDS: float = 2.4
const SCHOOL_ORDER: Array[String] = ["pyre", "tide", "storm", "shade", "steel", "root", ""]
const TYPE_ORDER: Array[CardDef.Type] = [
	CardDef.Type.PERSONALITY, CardDef.Type.STRIKE, CardDef.Type.ART, CardDef.Type.COMBAT,
	CardDef.Type.NON_COMBAT, CardDef.Type.DRILL, CardDef.Type.SEAL, CardDef.Type.GROUNDS, CardDef.Type.RELIC]
const TYPE_PLURALS: Dictionary = {
	CardDef.Type.PERSONALITY: "Allies", CardDef.Type.STRIKE: "Strikes", CardDef.Type.ART: "Arts",
	CardDef.Type.COMBAT: "Combat", CardDef.Type.NON_COMBAT: "Non-Combat", CardDef.Type.DRILL: "Drills",
	CardDef.Type.SEAL: "Seals", CardDef.Type.GROUNDS: "Grounds", CardDef.Type.RELIC: "Relics"}
const SORT_NAME: int = 0
const SORT_IN_DECK: int = 1
const GROUP_FREESTYLE: String = "freestyle"
const GROUP_SIGNATURE: String = "signature"
const HINT_POOL: String = "Click to add   ·   Right-click to take one out\nShift-click for the Reserve   ·   Drag it to the deck"
const HINT_STRIP: String = "Right-click or the minus button takes one out\nThe plus button adds one   ·   Drag to move it"
const HINT_SLOT: String = "Click to change"

@onready var faces: CardFaceCache = $CardFaceCache
@onready var shelf: Control = $Shelf
@onready var shelf_back: Button = $Shelf/Column/Top/Back
@onready var shelf_title: Label = $Shelf/Column/Top/Title
@onready var shelf_import: Button = $Shelf/Column/Top/Import
@onready var shelf_new: Button = $Shelf/Column/Top/NewDeck
@onready var restore_banner: PanelContainer = $Shelf/Column/Restore
@onready var restore_text: Label = $Shelf/Column/Restore/Row/Text
@onready var restore_resume: Button = $Shelf/Column/Restore/Row/Resume
@onready var restore_discard: Button = $Shelf/Column/Restore/Row/Discard
@onready var mine_grid: GridContainer = $Shelf/Column/Scroll/Content/MineGrid
@onready var new_tile: Button = $Shelf/Column/Scroll/Content/MineGrid/NewTile
@onready var mine_empty: Label = $Shelf/Column/Scroll/Content/MineEmpty
@onready var shipped_grid: GridContainer = $Shelf/Column/Scroll/Content/ShippedGrid
@onready var editor: Control = $Editor
@onready var back_button: Button = $Editor/Column/TopBar/Back
@onready var name_edit: LineEdit = $Editor/Column/TopBar/NameEdit
@onready var unsaved_chip: Label = $Editor/Column/TopBar/Unsaved
@onready var undo_button: Button = $Editor/Column/TopBar/Undo
@onready var redo_button: Button = $Editor/Column/TopBar/Redo
@onready var import_button: Button = $Editor/Column/TopBar/Import
@onready var share_button: Button = $Editor/Column/TopBar/Share
@onready var play_button: MenuButton = $Editor/Column/TopBar/Play
@onready var save_as_button: Button = $Editor/Column/TopBar/SaveAs
@onready var save_button: Button = $Editor/Column/TopBar/Save
@onready var pool_panel: PanelContainer = $Editor/Column/Body/PoolPanel
@onready var search: LineEdit = $Editor/Column/Body/PoolPanel/Column/Tools/Search
@onready var sort_button: OptionButton = $Editor/Column/Body/PoolPanel/Column/Tools/Sort
@onready var show_all: CheckBox = $Editor/Column/Body/PoolPanel/Column/Tools/ShowAll
@onready var type_chips_box: HFlowContainer = $Editor/Column/Body/PoolPanel/Column/TypeChips
@onready var group_row: HBoxContainer = $Editor/Column/Body/PoolPanel/Column/GroupRow
@onready var clear_filters: Button = $Editor/Column/Body/PoolPanel/Column/GroupRow/Clear
@onready var pool_scroll: ScrollContainer = $Editor/Column/Body/PoolPanel/Column/Scroll
@onready var pool_sections: VBoxContainer = $Editor/Column/Body/PoolPanel/Column/Scroll/Sections
@onready var pool_empty: VBoxContainer = $Editor/Column/Body/PoolPanel/Column/Scroll/Sections/Empty
@onready var pool_empty_text: Label = $Editor/Column/Body/PoolPanel/Column/Scroll/Sections/Empty/Text
@onready var pool_empty_filters: Label = $Editor/Column/Body/PoolPanel/Column/Scroll/Sections/Empty/Filters
@onready var pool_empty_clear: Button = $Editor/Column/Body/PoolPanel/Column/Scroll/Sections/Empty/Clear
@onready var footer: Label = $Editor/Column/Body/PoolPanel/Column/Footer
@onready var deck_panel: PanelContainer = $Editor/Column/Body/DeckPanel
@onready var duelist_slot: FrameSlot = $Editor/Column/Body/DeckPanel/Column/Identity/DuelistBox/Duelist
@onready var mastery_slot: FrameSlot = $Editor/Column/Body/DeckPanel/Column/Identity/MasteryBox/Mastery
@onready var duelist_name: Label = $Editor/Column/Body/DeckPanel/Column/Identity/Info/Name
@onready var duelist_line: Label = $Editor/Column/Body/DeckPanel/Column/Identity/Info/Line
@onready var aspect_slots: Array[FrameSlot] = [
	$Editor/Column/Body/DeckPanel/Column/Identity/Info/Slots/AspectsBox/Aspects/Aspect1,
	$Editor/Column/Body/DeckPanel/Column/Identity/Info/Slots/AspectsBox/Aspects/Aspect2,
	$Editor/Column/Body/DeckPanel/Column/Identity/Info/Slots/AspectsBox/Aspects/Aspect3,
	$Editor/Column/Body/DeckPanel/Column/Identity/Info/Slots/AspectsBox/Aspects/Aspect4,
	$Editor/Column/Body/DeckPanel/Column/Identity/Info/Slots/AspectsBox/Aspects/Aspect5]
@onready var relic_slot: FrameSlot = $Editor/Column/Body/DeckPanel/Column/Identity/Info/Slots/RelicBox/Relic
@onready var vigil_button: Button = $Editor/Column/Body/DeckPanel/Column/Identity/Info/Side/Vigil
@onready var pact_button: Button = $Editor/Column/Body/DeckPanel/Column/Identity/Info/Side/Pact
@onready var reserve_button: Button = $Editor/Column/Body/DeckPanel/Column/Identity/Info/Badges/Reserve
@onready var life_label: Label = $Editor/Column/Body/DeckPanel/Column/Counters/Life
@onready var range_label: Label = $Editor/Column/Body/DeckPanel/Column/Counters/Range
@onready var notes_button: Button = $Editor/Column/Body/DeckPanel/Column/Identity/Info/Badges/Notes
@onready var problems_button: Button = $Editor/Column/Body/DeckPanel/Column/Identity/Info/Badges/Problems
@onready var type_bar: HBoxContainer = $Editor/Column/Body/DeckPanel/Column/TypeBar
@onready var legend: Label = $Editor/Column/Body/DeckPanel/Column/Legend
@onready var notes_drawer: PanelContainer = $Editor/Column/Body/DeckPanel/Column/NotesDrawer
@onready var notes_summary: Label = $Editor/Column/Body/DeckPanel/Column/NotesDrawer/Column/Header/Summary
@onready var notes_close: Button = $Editor/Column/Body/DeckPanel/Column/NotesDrawer/Column/Header/Close
@onready var notes_copy: Button = $Editor/Column/Body/DeckPanel/Column/NotesDrawer/Column/Header/CopyMissing
@onready var notes_list: VBoxContainer = $Editor/Column/Body/DeckPanel/Column/NotesDrawer/Column/Scroll/List
@onready var list_scroll: ScrollContainer = $Editor/Column/Body/DeckPanel/Column/ListScroll
@onready var life_list: VBoxContainer = $Editor/Column/Body/DeckPanel/Column/ListScroll/List
@onready var reserve_drawer: PanelContainer = $Editor/Column/Body/DeckPanel/Column/ReserveDrawer
@onready var reserve_info: Label = $Editor/Column/Body/DeckPanel/Column/ReserveDrawer/Column/Header/Info
@onready var reserve_close: Button = $Editor/Column/Body/DeckPanel/Column/ReserveDrawer/Column/Header/Close
@onready var reserve_scroll: ScrollContainer = $Editor/Column/Body/DeckPanel/Column/ReserveDrawer/Column/Scroll
@onready var reserve_list: VBoxContainer = $Editor/Column/Body/DeckPanel/Column/ReserveDrawer/Column/Scroll/List
@onready var duelist_picker: Control = $DuelistPicker
@onready var picker_grid: GridContainer = $DuelistPicker/Center/Panel/Row/Left/Scroll/Grid
@onready var picker_name: Label = $DuelistPicker/Center/Panel/Row/Right/Name
@onready var picker_info: Label = $DuelistPicker/Center/Panel/Row/Right/Info
@onready var picker_lines: HFlowContainer = $DuelistPicker/Center/Panel/Row/Right/Lines
@onready var picker_faces: Array[TextureRect] = [
	$DuelistPicker/Center/Panel/Row/Right/Stack/Face1, $DuelistPicker/Center/Panel/Row/Right/Stack/Face2,
	$DuelistPicker/Center/Panel/Row/Right/Stack/Face3, $DuelistPicker/Center/Panel/Row/Right/Stack/Face4,
	$DuelistPicker/Center/Panel/Row/Right/Stack/Face5]
@onready var picker_cancel: Button = $DuelistPicker/Center/Panel/Row/Right/Buttons/Cancel
@onready var picker_choose: Button = $DuelistPicker/Center/Panel/Row/Right/Buttons/Choose
@onready var mastery_picker: Control = $MasteryPicker
@onready var mastery_list: HFlowContainer = $MasteryPicker/Center/Panel/Row/Left/Scroll/List
@onready var mastery_name: Label = $MasteryPicker/Center/Panel/Row/Right/Name
@onready var mastery_face: TextureRect = $MasteryPicker/Center/Panel/Row/Right/Face
@onready var mastery_info: Label = $MasteryPicker/Center/Panel/Row/Right/Info
@onready var mastery_cancel: Button = $MasteryPicker/Center/Panel/Row/Right/Buttons/Cancel
@onready var mastery_choose: Button = $MasteryPicker/Center/Panel/Row/Right/Buttons/Choose
@onready var aspect_overlay: Control = $AspectOverlay
@onready var aspect_panel: PanelContainer = $AspectOverlay/Panel
@onready var aspect_heading: Label = $AspectOverlay/Panel/Column/Heading
@onready var aspect_options: HBoxContainer = $AspectOverlay/Panel/Column/Options
@onready var aspect_remove: Button = $AspectOverlay/Panel/Column/Buttons/Remove
@onready var aspect_close: Button = $AspectOverlay/Panel/Column/Buttons/Close
@onready var problems_overlay: Control = $ProblemsOverlay
@onready var problems_panel: PanelContainer = $ProblemsOverlay/Panel
@onready var problems_text: Label = $ProblemsOverlay/Panel/Column/Text
@onready var problems_fix: Button = $ProblemsOverlay/Panel/Column/Buttons/Fix
@onready var problems_close: Button = $ProblemsOverlay/Panel/Column/Buttons/Close
@onready var import_dialog: Control = $ImportDialog
@onready var paste_edit: TextEdit = $ImportDialog/Center/Panel/Column/Paste
@onready var open_file_button: Button = $ImportDialog/Center/Panel/Column/Buttons/OpenFile
@onready var cancel_import_button: Button = $ImportDialog/Center/Panel/Column/Buttons/Cancel
@onready var go_import_button: Button = $ImportDialog/Center/Panel/Column/Buttons/Go
@onready var file_dialog: FileDialog = $FileDialog
@onready var confirm: ConfirmModal = $Confirm
@onready var toast: Label = $Toast
@onready var preview: PanelContainer = $Preview
@onready var preview_face: TextureRect = $Preview/Column/Face
@onready var preview_info: Label = $Preview/Column/Info
@onready var preview_hint: Label = $Preview/Column/Hint

var draft: DeckDraft
var _tiles: Array[BuilderCard] = []
var _tile_of: Dictionary = {}       # card id -> BuilderCard
var _sections: Dictionary = {}      # "group|type" -> PoolSection
var _haystacks: Dictionary = {}     # card id -> lowercased title, character, keywords and rules text
var _type_chips: Dictionary = {}    # Button -> CardDef.Type
var _group_chips: Dictionary = {}   # Button -> group key
var _strips: Dictionary = {}        # "life:<id>" / "reserve:<id>" -> strip Button
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _last_import: ImportResult = null
var _dirty: bool = false
var _index: SourceIndex = null
var _picked_character: String = ""
var _picked_line: String = ""
var _aspect_at: int = 0
var _flash: String = ""
var _card_size: Vector2 = MIN_CARD
var _toast_tween: Tween
var _dragging: bool = false
## Where the last add came from, so the fly-in can start there once the strip exists.
var _fly_from: BuilderCard = null
## The kept draft file holds this session's deck, so this session may clear it.
var _draft_owned: bool = false
## A dev screenshot holds the preview open whatever the real pointer does.
var _pin_preview: bool = false
var _picked_mastery: String = ""
## The saved deck whose tile pulses when "Your decks" next shows.
var _highlight_id: String = ""
## The card in hand while dragging: its face, where it was lifted from, and that control.
var _drag_texture: Texture2D = null
var _drag_origin: Rect2 = Rect2()
var _drag_source: Control = null
## A drop lands the card from here rather than from a library tile.
var _fly_rect: Rect2 = Rect2()
var _drag_from: String = ""
var _hot_zone: String = ""
## Why the zone under a dragged card would refuse it, "" when it would take it.
var _hot_block: String = ""


func _ready() -> void:
	theme = SanctumUI.theme()
	MapArt.tint_for_school("")
	SanctumUI.dress(self, shelf_title)
	for panel: PanelContainer in [pool_panel, deck_panel]:
		panel.add_theme_stylebox_override("panel", MapArt.panel_box(22))
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		(panel.get_child(0) as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for node: NodePath in [^"DuelistPicker/Center/Panel", ^"MasteryPicker/Center/Panel", ^"ImportDialog/Center/Panel"]:
		(get_node(node) as PanelContainer).add_theme_stylebox_override("panel", ZenithTheme.modal_panel())
	for panel: PanelContainer in [aspect_panel, problems_panel]:
		panel.add_theme_stylebox_override("panel", ZenithTheme.modal_panel())
	for overlay: Control in [aspect_overlay, problems_overlay]:
		var close: Control = overlay
		(overlay.get_node("Dim") as ColorRect).gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
				close.visible = false)
	restore_banner.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_ACTIVE, ZenithTheme.ACCENT, ZenithTheme.RADIUS, 1, 14, 6))
	restore_discard.add_theme_stylebox_override("normal", ZenithTheme.box(Color(0, 0, 0, 0), ZenithTheme.FRAME, ZenithTheme.RADIUS, 1, 12, 6))
	reserve_drawer.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.FRAME_DIM, ZenithTheme.RADIUS, 1, 10, 8))
	notes_drawer.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.ACCENT_SOFT, ZenithTheme.RADIUS, 1, 10, 8))
	_segment(vigil_button, true)
	_segment(pact_button, false)
	var play_menu: PopupMenu = play_button.get_popup()
	play_menu.add_item("Duel the AI", 0)
	play_menu.add_item("Hotseat duel", 1)
	play_menu.id_pressed.connect(func(id: int) -> void: _on_play(1 if id == 0 else -1))
	new_tile.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.FRAME_DIM, ZenithTheme.RADIUS, 1, 10, 10))
	new_tile.add_theme_stylebox_override("hover", ZenithTheme.box(ZenithTheme.BG_ACTIVE, ZenithTheme.ACCENT, ZenithTheme.RADIUS, 2, 10, 10))
	ZenithTheme.chip(unsaved_chip, ZenithTheme.WARN)
	sort_button.add_item("Each group by name", SORT_NAME)
	sort_button.add_item("Deck's cards first", SORT_IN_DECK)
	sort_button.tooltip_text = "The library is grouped by school and card type; this orders each group."
	var chip_types: Dictionary = {"Ally": CardDef.Type.PERSONALITY, "Strike": CardDef.Type.STRIKE, "Art": CardDef.Type.ART,
		"Combat": CardDef.Type.COMBAT, "NonCombat": CardDef.Type.NON_COMBAT, "Drill": CardDef.Type.DRILL,
		"Seal": CardDef.Type.SEAL, "Grounds": CardDef.Type.GROUNDS, "Relic": CardDef.Type.RELIC}
	for node_name: String in chip_types.keys():
		var chip: Button = type_chips_box.get_node(node_name)
		_type_chips[chip] = chip_types[node_name]
		chip.toggled.connect(func(_on: bool) -> void: _filter())
	for node_name: String in ["School", "Freestyle", "Signature"]:
		var chip: Button = group_row.get_node(node_name)
		_group_chips[chip] = node_name.to_lower()
		chip.toggled.connect(func(_on: bool) -> void: _filter())
	_build_pool()
	_build_duelist_picker()
	search.text_changed.connect(func(_t: String) -> void: _filter())
	sort_button.item_selected.connect(func(_i: int) -> void: _sort_pool())
	show_all.toggled.connect(func(_on: bool) -> void: _filter())
	clear_filters.pressed.connect(_clear_filters)
	pool_empty_clear.pressed.connect(_clear_filters)
	pool_scroll.resized.connect(_resize_grid)
	shelf_back.pressed.connect(_leave_shelf)
	shelf_new.pressed.connect(_on_new)
	new_tile.pressed.connect(_on_new)
	shelf_import.pressed.connect(_open_import)
	restore_resume.pressed.connect(_resume_draft)
	restore_discard.pressed.connect(_discard_kept_draft)
	back_button.pressed.connect(_leave_editor)
	undo_button.pressed.connect(_on_undo)
	redo_button.pressed.connect(_on_redo)
	import_button.pressed.connect(_open_import)
	share_button.pressed.connect(_on_share)
	save_button.pressed.connect(_on_save)
	save_as_button.pressed.connect(_on_save_as)
	name_edit.text_changed.connect(func(text: String) -> void:
		draft.deck.name = text
		_mark_dirty())
	vigil_button.pressed.connect(_on_side.bind("vigil"))
	pact_button.pressed.connect(_on_side.bind("pact"))
	reserve_button.toggled.connect(func(on: bool) -> void: reserve_drawer.visible = on)
	reserve_close.pressed.connect(func() -> void: reserve_button.button_pressed = false)
	duelist_slot.pressed.connect(_open_duelist_picker)
	mastery_slot.pressed.connect(_open_mastery_picker)
	for n in range(aspect_slots.size()):
		aspect_slots[n].pressed.connect(_open_aspect_popup.bind(n + 1))
	relic_slot.pressed.connect(func() -> void:
		if relic_slot.card_id == "":
			_type_only(CardDef.Type.RELIC)
			return
		var id: String = relic_slot.card_id
		_mutate(func() -> String: return "" if draft.remove_from_frame(id) else "No Relic to take out."))
	for slot: FrameSlot in aspect_slots + [duelist_slot, mastery_slot, relic_slot]:
		slot.hovered.connect(func(over: bool) -> void:
			if over and slot.card_id != "":
				_show_preview(Session.library.defs[slot.card_id], slot, "", HINT_SLOT)
			else:
				_hide_preview())
	problems_button.pressed.connect(_open_problems)
	problems_fix.pressed.connect(_fix_problems)
	problems_close.pressed.connect(func() -> void: problems_overlay.visible = false)
	notes_button.toggled.connect(func(on: bool) -> void: notes_drawer.visible = on)
	notes_close.pressed.connect(func() -> void: notes_button.button_pressed = false)
	notes_copy.pressed.connect(func() -> void:
		if _last_import == null:
			return
		var lines: PackedStringArray = PackedStringArray()
		for line in _last_import.missing():
			lines.append("%dx %s" % [line.qty, line.text])
		DisplayServer.clipboard_set("\n".join(lines))
		_toast("Copied %d lines." % lines.size(), false, notes_copy.get_global_rect().position + Vector2(-140, 40)))
	picker_cancel.pressed.connect(_cancel_duelist_picker)
	picker_choose.pressed.connect(_on_choose_duelist)
	mastery_cancel.pressed.connect(func() -> void:
		mastery_picker.visible = false
		_hide_preview())
	mastery_choose.pressed.connect(_on_choose_mastery)
	aspect_remove.pressed.connect(_on_aspect_remove)
	aspect_close.pressed.connect(func() -> void: aspect_overlay.visible = false)
	open_file_button.pressed.connect(func() -> void: file_dialog.popup_centered())
	file_dialog.file_selected.connect(func(path: String) -> void: paste_edit.text = FileAccess.get_file_as_string(path))
	cancel_import_button.pressed.connect(func() -> void: import_dialog.visible = false)
	go_import_button.pressed.connect(_on_import)
	for area: Control in [list_scroll, life_list]:
		area.set_drag_forwarding(Callable(), _can_drop.bind("life"), _drop.bind("life"))
	for area: Control in [reserve_scroll, reserve_list, reserve_drawer]:
		area.set_drag_forwarding(Callable(), _can_drop.bind("reserve"), _drop.bind("reserve"))
	for area: Control in [pool_scroll, pool_sections]:
		area.set_drag_forwarding(Callable(), _can_drop.bind("pool"), _drop.bind("pool"))
	draft = DeckDraft.blank(Session.library)
	SanctumUI.wire_buttons(self)
	_pump_faces()
	# The drop zones' padding from the start, so the first drag moves nothing.
	_paint_drop_zones()
	if not await _dev_flags():
		_show_shelf()
		# Back from a duel or the select screen: straight back to that deck.
		if Session.builder_deck_id != "":
			for deck: DeckList in CustomDecks.load_all():
				if deck.id == Session.builder_deck_id:
					_open_saved(deck)
			Session.builder_deck_id = ""
		if Session.builder_from_select:
			back_button.text = "Back to deck select"
			back_button.tooltip_text = "Save or leave this deck and go back to picking (Esc)"
			shelf_back.text = "Back to deck select"
	AdventureDev.screenshot(self)


## Vigil and Pact read as one two-part control: the picked half filled, the other an outline.
func _segment(button: Button, left: bool) -> void:
	var off: StyleBoxFlat = ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.FRAME_DIM, 0, 1, 10, 4)
	var on: StyleBoxFlat = ZenithTheme.box(ZenithTheme.ACCENT_SOFT, ZenithTheme.ACCENT, 0, 1, 10, 4)
	var hover: StyleBoxFlat = ZenithTheme.box(ZenithTheme.HOVER, ZenithTheme.FRAME, 0, 1, 10, 4)
	for box: StyleBoxFlat in [off, on, hover]:
		if left:
			box.corner_radius_top_left = ZenithTheme.RADIUS
			box.corner_radius_bottom_left = ZenithTheme.RADIUS
		else:
			box.corner_radius_top_right = ZenithTheme.RADIUS
			box.corner_radius_bottom_right = ZenithTheme.RADIUS
	button.add_theme_stylebox_override("normal", off)
	button.add_theme_stylebox_override("disabled", off)
	button.add_theme_stylebox_override("pressed", on)
	button.add_theme_stylebox_override("hover_pressed", on)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_pressed_color", ZenithTheme.ACCENT)
	button.add_theme_color_override("font_hover_pressed_color", ZenithTheme.ACCENT)


## While dragging, leaving every zone clears the lit one; `_can_drop` only hears about the zones.
func _process(_delta: float) -> void:
	if not _dragging or _hot_zone == "":
		return
	var at: Vector2 = get_global_mouse_position()
	for zone: Control in [list_scroll, reserve_scroll, pool_scroll]:
		if zone.is_visible_in_tree() and zone.get_global_rect().has_point(at):
			return
	_hot_zone = ""
	_hot_block = ""
	_paint_drop_zones()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_dragging = false
		_paint_drop_zones()
		if is_instance_valid(_drag_source):
			_drag_source.modulate.a = 1.0
		# Dropped where it cannot go: the card drifts back to where it was picked up.
		if not get_viewport().gui_is_drag_successful() and _drag_texture != null and _drag_origin.has_area():
			var size_now: Vector2 = _card_size * 0.9
			_fly(_drag_texture, Rect2(get_global_mouse_position() - size_now * 0.5, size_now), _drag_origin, true)
		_drag_source = null
		_drag_texture = null
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and _dirty and draft != null:
		CustomDecks.save_draft(draft.deck)


# --- Your decks -----------------------------------------------------------------------------------

func _show_shelf() -> void:
	_hide_preview()
	editor.visible = false
	shelf.visible = true
	MapArt.tint_for_school("")
	for child in mine_grid.get_children():
		if child != new_tile:
			mine_grid.remove_child(child)
			child.queue_free()
	for child in shipped_grid.get_children():
		shipped_grid.remove_child(child)
		child.queue_free()
	# Newest first, so the deck just saved or copied leads.
	var saved: Array[DeckList] = CustomDecks.load_all()
	var stamp: Dictionary = {}
	for deck in saved:
		stamp[deck.id] = CustomDecks.modified(deck.id)
	saved.sort_custom(func(a: DeckList, b: DeckList) -> bool:
		return int(stamp[a.id]) > int(stamp[b.id]) if int(stamp[a.id]) != int(stamp[b.id]) else a.name < b.name)
	var glow: DeckTile = null
	for deck in saved:
		var tile: DeckTile = DECK_TILE.instantiate() as DeckTile
		mine_grid.add_child(tile)
		tile.setup(deck, Session.library, DeckValidator.validate(deck, Session.library).size(), false)
		tile.opened.connect(_open_saved.bind(deck))
		tile.played.connect(_play_saved.bind(deck))
		tile.fixed.connect(_fix_saved.bind(deck))
		tile.duplicated.connect(_duplicate_saved.bind(deck))
		tile.removed.connect(_delete_saved.bind(deck))
		if deck.id == _highlight_id:
			glow = tile
	_highlight_id = ""
	if glow != null:
		glow.pulse.call_deferred()
	mine_empty.visible = saved.is_empty()
	for deck in Session.decks:
		if deck.custom:
			continue
		var tile: DeckTile = DECK_TILE.instantiate() as DeckTile
		shipped_grid.add_child(tile)
		tile.setup(deck, Session.library, 0, true)
		tile.opened.connect(_copy_shipped.bind(deck))
	var columns: int = maxi(1, int((get_viewport_rect().size.x - 96 + 16) / (400 + 16)))
	mine_grid.columns = columns
	shipped_grid.columns = columns
	for grid: GridContainer in [mine_grid, shipped_grid]:
		for tile: Node in grid.get_children():
			(tile as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(tile as Control).custom_minimum_size.x = 400
	var kept: DeckList = CustomDecks.load_draft()
	_draft_owned = false
	restore_banner.visible = kept != null
	if kept != null:
		restore_text.text = "You left \"%s\" with unsaved changes." % kept.name
	SanctumUI.wire_buttons(shelf)


func _show_editor() -> void:
	shelf.visible = false
	editor.visible = true
	await get_tree().process_frame
	_resize_grid()


## Before opening any other deck while an unsaved one is kept from an earlier visit: ask, since
## editing the other would write over it. True when the caller may go on.
func _settle_kept_draft() -> bool:
	var kept: DeckList = CustomDecks.load_draft()
	if kept == null or _draft_owned:
		return true
	var answer: int = await confirm.ask("Discard the unsaved \"%s\"?" % kept.name,
		"Its changes were kept from your last visit. Opening another deck replaces them.",
		["Discard them", "Keep editing it", "Cancel"] as Array[String], true)
	match answer:
		0:
			CustomDecks.clear_draft()
			restore_banner.visible = false
			return true
		1:
			_resume_draft()
	return false


func _discard_kept_draft() -> void:
	var kept: DeckList = CustomDecks.load_draft()
	if kept == null:
		restore_banner.visible = false
		return
	var answer: int = await confirm.ask("Discard the unsaved \"%s\"?" % kept.name,
		"The changes kept from your last visit are lost. The saved deck, if any, stays as it was.",
		["Discard them", "Keep them"] as Array[String], true)
	if answer == 0:
		CustomDecks.clear_draft()
		restore_banner.visible = false


func _open_saved(deck: DeckList) -> void:
	if not await _settle_kept_draft():
		return
	_last_import = null
	_load(DeckDraft.of(deck, Session.library))
	_show_editor()


## Play from a legal deck's tile: no editor in between.
## `ai_seat` 1 duels the AI, -1 is hotseat, as the editor's Play menu.
func _play_saved(ai_seat: int, deck: DeckList) -> void:
	Session.leave_adventure()
	Session.ai_seat = ai_seat
	Session.builder_from_select = false
	Session.builder_seat = -1
	Session.preselect_deck_id = deck.id
	Session.builder_deck_id = deck.id
	Session.go_to_select()


func _fix_saved(deck: DeckList) -> void:
	await _open_saved(deck)
	if editor.visible:
		await get_tree().process_frame
		_open_problems()


func _copy_shipped(deck: DeckList) -> void:
	if not await _settle_kept_draft():
		return
	_last_import = null
	var next: DeckDraft = DeckDraft.of(deck, Session.library)
	next.deck.name = CustomDecks.clean_name("%s (copy)" % deck.name)
	_load(next)
	_mark_dirty()
	_show_editor()
	_toast("A copy of %s. Save it to keep it." % deck.name, false, save_button.get_global_rect().get_center() + Vector2(-300, 40))


func _duplicate_saved(deck: DeckList) -> void:
	var copy: DeckList = DeckList.from_dict(deck.to_dict())
	copy.name = CustomDecks.clean_name("%s (copy)" % deck.name)
	copy.id = ""
	CustomDecks.save(copy)
	Session.reload_decks()
	_highlight_id = copy.id
	_show_shelf()
	_toast("Duplicated as \"%s\"." % copy.name, false, shelf_new.get_global_rect().position + Vector2(-260, 60))


func _delete_saved(deck: DeckList) -> void:
	var answer: int = await confirm.ask("Delete %s?" % deck.name, "The deck file is removed. This cannot be undone.",
		["Delete it", "Keep it"] as Array[String], true)
	if answer != 0:
		return
	CustomDecks.delete(deck.id)
	Session.reload_decks()
	_show_shelf()


func _on_new() -> void:
	if not await _settle_kept_draft():
		return
	_last_import = null
	_load(DeckDraft.blank(Session.library))
	_show_editor()
	_open_duelist_picker()


func _resume_draft() -> void:
	var kept: DeckList = CustomDecks.load_draft()
	if kept == null:
		restore_banner.visible = false
		return
	var next: DeckDraft = DeckDraft.new()
	next.library = Session.library
	next.deck = kept
	_last_import = null
	_load(next)
	_mark_dirty()
	_show_editor()


## Back to "Your decks", asking first when the deck has unsaved changes.
func _leave_editor() -> void:
	if not await _settle_unsaved("Leave this deck?"):
		return
	# Opened from the select screen: back there, with this deck picked when it can be played.
	if Session.builder_from_select:
		Session.builder_from_select = false
		if draft.deck.id != "" and draft.problems().is_empty():
			Session.preselect_deck_id = draft.deck.id
		Session.go_to_select()
		return
	_show_shelf()


## The shelf's Back: to the select screen on a trip from there, otherwise to the title.
func _leave_shelf() -> void:
	if Session.builder_from_select:
		Session.builder_from_select = false
		Session.go_to_select()
		return
	Session.go_to_title()


## Asks what to do with unsaved changes: save, drop them, or stay. True when the caller may go on.
func _settle_unsaved(title: String) -> bool:
	if not _dirty:
		return true
	var answer: int = await confirm.ask(title, "\"%s\" has changes that are not saved." % draft.deck.name,
		["Save and continue", "Discard changes", "Stay"] as Array[String])
	match answer:
		0:
			return _on_save()
		1:
			_dirty = false
			if _draft_owned:
				CustomDecks.clear_draft()
			return true
	return false


# --- The card pool --------------------------------------------------------------------------------

## A card's school group: its school, else Signature for a card naming a personality, else Freestyle.
static func group_key(def: CardDef) -> String:
	if def.school != "":
		return def.school
	return GROUP_SIGNATURE if def.is_signature() else GROUP_FREESTYLE


## Every card but the Masteries, which have their own picker, each in the section for its school
## group and type. `_order_sections` and `_sort_pool` set the order.
func _build_pool() -> void:
	for id in Session.library.all_ids():
		var def: CardDef = Session.library.defs[id]
		if def.type == CardDef.Type.MASTERY:
			continue
		var tile: BuilderCard = CARD_SCENE.instantiate() as BuilderCard
		_section_for(def).grid.add_child(tile)
		tile.show_card(def, MIN_CARD)
		tile.clicked.connect(_on_tile.bind(id))
		tile.hovered.connect(func(over: bool) -> void:
			if over:
				_show_preview(def, tile, tile.reason, HINT_POOL)
			else:
				_hide_preview())
		tile.set_drag_forwarding(_drag_card.bind("pool", id), Callable(), Callable())
		_tiles.append(tile)
		_tile_of[id] = tile
		var tags: String = " ".join(PackedStringArray(def.raw.get("tags", [])))
		_haystacks[id] = ("%s %s %s %s" % [def.title, def.character, tags, CardText.rules_text(def)]).to_lower()
	pool_sections.move_child(pool_empty, pool_sections.get_child_count() - 1)
	_sort_pool()


func _section_for(def: CardDef) -> PoolSection:
	var key: String = "%s|%d" % [group_key(def), int(def.type)]
	if not _sections.has(key):
		var section: PoolSection = PoolSection.make(group_key(def), def.type, MIN_CARD)
		pool_sections.add_child(section)
		_sections[key] = section
	return _sections[key]


## The deck's own school first, then Freestyle, Signature and the other schools; types in
## TYPE_ORDER within each.
func _order_sections() -> void:
	var own: String = draft.deck.style if draft.deck.mastery_id != "" and draft.deck.style != "freestyle" else ""
	var rank: Callable = func(s: PoolSection) -> int:
		var g: int
		if s.group == own:
			g = 0
		elif s.group == GROUP_FREESTYLE:
			g = 1
		elif s.group == GROUP_SIGNATURE:
			g = 2
		else:
			g = 3 + SCHOOL_ORDER.find(s.group)
		return g * 100 + TYPE_ORDER.find(s.type)
	var ordered: Array[PoolSection] = []
	for value: Variant in _sections.values():
		ordered.append(value as PoolSection)
	ordered.sort_custom(func(a: PoolSection, b: PoolSection) -> bool: return int(rank.call(a)) < int(rank.call(b)))
	for i in range(ordered.size()):
		pool_sections.move_child(ordered[i], i)


## Within each section: by name (Allies by character, then Aspect), or the deck's own cards first.
func _sort_pool() -> void:
	var mode: int = sort_button.get_selected_id()
	var lib: CardLibrary = Session.library
	for value: Variant in _sections.values():
		var grid: GridContainer = (value as PoolSection).grid
		var tiles: Array[BuilderCard] = []
		for child: Node in grid.get_children():
			tiles.append(child as BuilderCard)
		tiles.sort_custom(func(a: BuilderCard, b: BuilderCard) -> bool:
			var da: CardDef = lib.defs[a.card_id]
			var db: CardDef = lib.defs[b.card_id]
			if mode == SORT_IN_DECK:
				var ia: bool = draft.copies(a.card_id) > 0
				var ib: bool = draft.copies(b.card_id) > 0
				if ia != ib:
					return ia
			if da.type == CardDef.Type.PERSONALITY and da.character != db.character:
				return da.character < db.character
			if da.title != db.title:
				return da.title < db.title
			return da.aspect < db.aspect)
		for i in range(tiles.size()):
			grid.move_child(tiles[i], i)


## Tiles in the order they show, section by section.
func _ordered_tiles() -> Array[BuilderCard]:
	var out: Array[BuilderCard] = []
	for section: Node in pool_sections.get_children():
		if section is PoolSection:
			for tile: Node in (section as PoolSection).grid.get_children():
				out.append(tile as BuilderCard)
	return out


func _filter() -> void:
	var words: PackedStringArray = PackedStringArray()
	var keys: Dictionary = {}
	for word in search.text.strip_edges().to_lower().split(" ", false):
		if word.contains(":") and word.get_slice(":", 1) != "":
			keys[word.get_slice(":", 0)] = word.get_slice(":", 1)
		else:
			words.append(word)
	var types: Dictionary = {}
	for chip: Button in _type_chips.keys():
		if chip.button_pressed:
			types[_type_chips[chip]] = true
	var groups: Dictionary = {}
	for chip: Button in _group_chips.keys():
		if chip.button_pressed:
			groups[_group_chips[chip]] = true
	var counts: Dictionary = {}
	var shown: int = 0
	var hidden_by_deck: int = 0
	for tile in _tiles:
		var def: CardDef = Session.library.defs[tile.card_id]
		var fits: bool = _pool_block(def) == ""
		var searched: bool = _matches(def, words, keys)
		var grouped: bool = groups.is_empty() or groups.has(_chip_group(def))
		if (fits or show_all.button_pressed) and searched and grouped:
			counts[def.type] = int(counts.get(def.type, 0)) + 1
		var on: bool = searched and grouped and (types.is_empty() or types.has(def.type)) and (fits or show_all.button_pressed)
		if not fits and searched and grouped and not show_all.button_pressed:
			hidden_by_deck += 1
		tile.visible = on
		if on:
			shown += 1
	for chip: Button in _type_chips.keys():
		var n: int = int(counts.get(_type_chips[chip], 0))
		chip.text = "%s %d" % [TYPE_PLURALS[_type_chips[chip]], n]
		chip.disabled = n == 0 and not chip.button_pressed
	for chip: Button in _type_chips.keys() + _group_chips.keys():
		chip.theme_type_variation = &"AccentButton" if chip.button_pressed else &"CompactButton"
	var filtering: bool = not types.is_empty() or not groups.is_empty() or search.text.strip_edges() != ""
	clear_filters.visible = filtering
	var note: String = ""
	if hidden_by_deck > 0:
		note = "   ·   %d hidden: the deck cannot run them or nobody in it can use them (Show unusable)" % hidden_by_deck
	footer.text = "%d cards%s" % [shown, note]
	for value: Variant in _sections.values():
		(value as PoolSection).refresh_header(_group_label((value as PoolSection).group))
	pool_empty.visible = shown == 0
	if shown == 0:
		pool_empty_text.text = "No card matches \"%s\"." % search.text.strip_edges() if search.text.strip_edges() != "" \
			else "No card matches these filters."
		var active: PackedStringArray = PackedStringArray()
		for chip: Button in _type_chips.keys() + _group_chips.keys():
			if chip.button_pressed:
				active.append(chip.text.get_slice(" ", 0))
		if not show_all.button_pressed:
			active.append("only cards this deck can use")
		pool_empty_filters.text = "Filtering by: " + ", ".join(active) if not active.is_empty() else ""
		pool_empty.custom_minimum_size.y = maxf(0.0, pool_scroll.size.y - 24.0)
	_paint_tiles()


func _clear_filters() -> void:
	search.text = ""
	for chip: Button in _type_chips.keys() + _group_chips.keys():
		chip.set_pressed_no_signal(false)
	_filter()


## Shows only one type, from a slot that asks for it (the empty Relic slot shows the Relics).
func _type_only(type: CardDef.Type) -> void:
	for chip: Button in _type_chips.keys():
		chip.set_pressed_no_signal(_type_chips[chip] == type)
	_filter()
	pool_scroll.scroll_vertical = 0


func _group_label(group: String) -> String:
	if group == GROUP_SIGNATURE:
		return "Signature"
	if group == GROUP_FREESTYLE:
		return "Freestyle"
	return CardText.school_name(group)


## Why the pool hides `def` for this deck: the Duelist's own character (their Aspects live in the
## slots), or DeckDraft's reasons.
func _pool_block(def: CardDef) -> String:
	var head: CardDef = draft.duelist()
	if def.type == CardDef.Type.PERSONALITY and head != null and def.character == head.character:
		return "This is your Duelist. Change Aspects from the slots above the deck."
	return draft.fit_block(def)


## The group chip a card answers to: "school" for the deck's own school.
func _chip_group(def: CardDef) -> String:
	if def.is_signature():
		return "signature"
	return "school" if def.school != "" else "freestyle"


## Free words must all appear in the card's text; `key:value` terms narrow by type, school, side,
## keyword, bloodline or name.
func _matches(def: CardDef, words: PackedStringArray, keys: Dictionary) -> bool:
	var hay: String = _haystacks[def.id]
	for word in words:
		if not hay.contains(word):
			return false
	for key: String in keys.keys():
		var value: String = keys[key]
		match key:
			"type", "t":
				var label: String = str(CardText.TYPE_LABELS.get(def.type, "")).to_lower()
				if not (label.begins_with(value) or (value.begins_with("all") and def.type == CardDef.Type.PERSONALITY)):
					return false
			"school", "s":
				if not CardText.school_name(def.school).to_lower().begins_with(value):
					return false
			"side":
				if def.alignment_only == "" or not def.alignment_only.begins_with(value):
					return false
			"kw", "keyword":
				var tags: Array = def.raw.get("tags", [])
				var gate_tag: String = str(def.only.get("tag", ""))
				if not (tags.any(func(t: Variant) -> bool: return str(t).begins_with(value)) or gate_tag.begins_with(value)):
					return false
			"blood", "bloodline":
				if not (def.bloodline.begins_with(value) or str(def.only.get("bloodline", "")).begins_with(value)):
					return false
			"name", "n":
				if not def.title.to_lower().contains(value):
					return false
	return true


func _paint_tiles() -> void:
	for tile in _tiles:
		if not tile.visible:
			continue
		var def: CardDef = Session.library.defs[tile.card_id]
		var why: String = _pool_block(def)
		var short: String = "Your Duelist" if why != "" and def.type == CardDef.Type.PERSONALITY and draft.duelist() != null \
			and def.character == draft.duelist().character else draft.fit_tag(def)
		tile.set_state(draft.copies(tile.card_id), draft.limit(tile.card_id), why == "" and draft.add_block(tile.card_id) != "", why, short)


## Tiles grow to fill the panel's width, at least MIN_CARD, in the card's proportions.
func _resize_grid() -> void:
	var width: float = pool_scroll.size.x - 18
	if width <= 0.0:
		return
	var gap: float = 12.0
	var columns: int = maxi(1, int((width + gap) / (MIN_CARD.x + gap)))
	var tile_w: float = floor((width - gap * (columns - 1)) / columns)
	_card_size = Vector2(tile_w, round(tile_w * CARD_RATIO))
	for value: Variant in _sections.values():
		(value as PoolSection).grid.columns = columns
	for tile in _tiles:
		tile.custom_minimum_size = _card_size


## Renders pool faces in the background, the ones in view (and just below) first, one at a time.
func _pump_faces() -> void:
	while is_inside_tree():
		var tile: BuilderCard = _next_face()
		if tile == null:
			await get_tree().process_frame
			if not is_inside_tree():
				return
			continue
		var def: CardDef = Session.library.defs[tile.card_id]
		var texture: Texture2D = await faces.render_face(def, def.aspect)
		if not is_inside_tree():
			return
		if is_instance_valid(tile):
			tile.set_face(texture)


func _next_face() -> BuilderCard:
	if not editor.visible or duelist_picker.visible or mastery_picker.visible:
		return null
	var view: Rect2 = pool_scroll.get_global_rect().grow_individual(0, 0, 0, RENDER_AHEAD)
	for tile in _tiles:
		if tile.visible and not tile.has_face and view.intersects(tile.get_global_rect()):
			return tile
	return null


func _on_tile(button: int, shift: bool, id: String) -> void:
	var def: CardDef = Session.library.defs[id]
	var tile: BuilderCard = _tile_of[id]
	if button == MOUSE_BUTTON_RIGHT:
		var from_reserve: bool = draft.deck.cards.count(id) == 0 and draft.deck.reserve.has(id)
		var strip: Control = _strips.get(("reserve:" if from_reserve else "life:") + id)
		var start: Rect2 = strip.get_global_rect() if strip != null else Rect2()
		var take: Callable = func() -> String:
			return "" if (draft.remove(id) or draft.remove_reserve(id)) else "The deck runs no copy of %s." % def.title
		if _mutate(take, tile) and start.has_area():
			_fly(tile.face.texture, start, tile.get_global_rect())
		return
	if def.type == CardDef.Type.PERSONALITY and draft.duelist() == null:
		_open_duelist_picker(def.character)
		return
	var add: Callable = func() -> String:
		var block: String = draft.add_block(id, shift)
		if block == "":
			draft.add(id, shift)
		return block
	var to_reserve: bool = shift or bool(def.raw.get("reserve_only", false))
	_flash = ("reserve:" if to_reserve else "life:") + id
	_fly_from = tile
	if _mutate(add, tile) and to_reserve:
		reserve_button.button_pressed = true


# --- Editing, undo and redo -----------------------------------------------------------------------

## Runs one edit, which returns "" or why it was refused, and keeps it on the undo stack. A refused
## edit shakes `source` and says why beside the pointer. True when the edit went through.
func _mutate(action: Callable, source: BuilderCard = null) -> bool:
	var before: Dictionary = draft.snapshot()
	var block: String = action.call()
	if block != "":
		_fly_from = null
		_flash = ""
		_toast(block, true)
		if source != null:
			source.shake()
		return false
	_undo.append(before)
	if _undo.size() > UNDO_DEPTH:
		_undo.pop_front()
	_redo.clear()
	_mark_dirty()
	_after_edit()
	return true


func _on_undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(draft.snapshot())
	draft.restore(_undo.pop_back())
	_mark_dirty()
	_after_edit()


func _on_redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(draft.snapshot())
	draft.restore(_redo.pop_back())
	_mark_dirty()
	_after_edit()


func _mark_dirty() -> void:
	_dirty = true
	unsaved_chip.visible = true
	_set_save_enabled(true)
	CustomDecks.save_draft(draft.deck)
	_draft_owned = true


## Save in the accent style only while there is something to save; disabled it reads as plain.
func _set_save_enabled(on: bool) -> void:
	save_button.disabled = not on
	save_button.theme_type_variation = &"AccentButton" if on else &""


func _after_edit() -> void:
	_refresh_deck()
	_order_sections()
	_filter()
	if sort_button.get_selected_id() == SORT_IN_DECK:
		_sort_pool()


func _load(next: DeckDraft) -> void:
	draft = next
	_undo.clear()
	_redo.clear()
	_dirty = false
	unsaved_chip.visible = false
	name_edit.text = draft.deck.name
	notes_button.set_pressed_no_signal(false)
	notes_drawer.visible = false
	_after_edit()
	_set_save_enabled(false)


# --- The deck column ------------------------------------------------------------------------------

func _refresh_deck() -> void:
	var deck: DeckList = draft.deck
	var head: CardDef = draft.duelist()
	undo_button.disabled = _undo.is_empty()
	redo_button.disabled = _redo.is_empty()
	_fill_identity(head)
	var problems: Array[String] = draft.readable_problems()
	var total: int = draft.total()
	var in_range: bool = total >= DeckValidator.MIN_CARDS and total <= draft.max_cards()
	life_label.text = "%d cards" % total
	life_label.add_theme_color_override("font_color", ZenithTheme.TEXT if in_range else ZenithTheme.WARN)
	range_label.text = "of %d to %d   ·   Life Deck %d   ·   Aspects %d (%d to %d)" % [DeckValidator.MIN_CARDS, draft.max_cards(),
		deck.cards.size(), deck.duelist_ids.size(), DeckValidator.MIN_ASPECTS, DeckValidator.MAX_ASPECTS]
	range_label.add_theme_color_override("font_color", ZenithTheme.TEXT_SOFT)
	problems_button.text = "Legal" if problems.is_empty() else "%d %s" % [problems.size(), "problem" if problems.size() == 1 else "problems"]
	problems_button.add_theme_color_override("font_color", ZenithTheme.ENERGY if problems.is_empty() else ZenithTheme.WARN)
	problems_button.tooltip_text = "Every deck rule is met." if problems.is_empty() else "See what to fix"
	problems_text.text = "\n".join(problems)
	play_button.disabled = not problems.is_empty()
	save_as_button.disabled = head == null
	play_button.tooltip_text = "Save, then play this deck" if problems.is_empty() else "Fix the deck's problems to play it"
	var relic: CardDef = Session.library.defs.get(deck.relic_id)
	reserve_button.text = "Reserve %d/%d" % [deck.reserve.size(), relic.reserve_size] if relic != null else "No Reserve"
	reserve_button.disabled = relic == null and deck.reserve.is_empty()
	reserve_button.tooltip_text = "Open the Reserve" if relic != null else "A Relic holds a Reserve. Click the Relic slot to see the Relics."
	if reserve_button.disabled:
		reserve_button.button_pressed = false
	reserve_info.text = ("%s holds %d. Shift-click a library card or drag a strip here." % [relic.title, relic.reserve_size]) \
		if relic != null else "No Relic, so no Reserve."
	_fill_type_bar()
	var flagged: Dictionary = draft.problem_ids()
	_strips.clear()
	_fill_strips(life_list, deck.cards, "life", flagged)
	_fill_strips(reserve_list, deck.reserve, "reserve", flagged)
	notes_button.visible = _last_import != null
	_land_flash()


func _fill_identity(head: CardDef) -> void:
	var deck: DeckList = draft.deck
	if head == null:
		duelist_slot.show_empty("Choose a Duelist")
		duelist_name.text = "No Duelist yet"
		duelist_line.text = "Click the Duelist slot to pick who leads the deck."
	else:
		_show_slot(duelist_slot, deck.duelist_ids[deck.duelist_ids.size() - 1])
		duelist_name.text = head.character
		duelist_line.text = _identity_line(deck)
	var height: int = deck.duelist_ids.size()
	for n in range(aspect_slots.size()):
		var id: String = ""
		for duelist_id in deck.duelist_ids:
			if (Session.library.defs[duelist_id] as CardDef).aspect == n + 1:
				id = duelist_id
		var slot: FrameSlot = aspect_slots[n]
		if id == "":
			slot.show_empty(str(n + 1))
			slot.tooltip_text = "Aspect %d. Click to add it." % (n + 1) if head != null and n == height else ""
			slot.disabled = head == null or n > height
		else:
			_show_slot(slot, id)
			slot.disabled = false
			slot.tooltip_text = ""
		slot.set_marked(id != "" and n == height - 1)
	if deck.relic_id == "":
		relic_slot.show_empty("R")
		relic_slot.tooltip_text = "No Relic. Click to show the Relics in the library."
	else:
		_show_slot(relic_slot, deck.relic_id)
		relic_slot.tooltip_text = ""
	if deck.mastery_id == "":
		mastery_slot.show_empty("Choose a Mastery")
	else:
		_show_slot(mastery_slot, deck.mastery_id)
	var open_side: bool = draft.side_is_open()
	for pair: Array in [[vigil_button, "vigil"], [pact_button, "pact"]]:
		var button: Button = pair[0]
		var on: bool = deck.alignment == pair[1]
		button.button_pressed = on
		button.disabled = not open_side and not on
		button.tooltip_text = "" if open_side else "This Duelist serves one side only."
	MapArt.tint_for_school(deck.style if deck.mastery_id != "" and deck.style != "freestyle" else "")


## "Draconic · Either side · Marked · Mercenary", from the stack.
func _identity_line(deck: DeckList) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var head: CardDef = draft.duelist()
	if head.bloodline != "":
		parts.append(CardText.bloodline_name(head.bloodline))
	parts.append("Either side" if draft.side_is_open() else deck.alignment.capitalize() + " only")
	var tags: Array[String] = []
	var lines: Array[String] = []
	for id in deck.duelist_ids:
		var def: CardDef = Session.library.defs[id]
		for t in def.raw.get("tags", []):
			if not tags.has(str(t)):
				tags.append(str(t))
		if def.variant != "" and not lines.has(def.variant):
			lines.append(def.variant)
	for t in tags:
		parts.append(CardText.keyword_name(t))
	if not lines.is_empty():
		parts.append(" and ".join(lines))
	return "  ·  ".join(parts)


func _show_slot(slot: FrameSlot, id: String) -> void:
	var def: CardDef = Session.library.defs[id]
	slot.show_card(id, faces.face(def, def.aspect))
	if slot.face.texture == null:
		var texture: Texture2D = await faces.render_face(def, def.aspect)
		if is_instance_valid(slot) and slot.card_id == id:
			slot.show_card(id, texture)


func _fill_type_bar() -> void:
	for child in type_bar.get_children():
		type_bar.remove_child(child)
		child.queue_free()
	var parts: PackedStringArray = PackedStringArray()
	for type: CardDef.Type in TYPE_ORDER:
		var n: int = 0
		for id in draft.deck.cards:
			if (Session.library.defs[id] as CardDef).type == type:
				n += 1
		if n == 0:
			continue
		var block: ColorRect = ColorRect.new()
		block.color = Palette.type_ui(type)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.size_flags_stretch_ratio = float(n)
		block.tooltip_text = "%s %d" % [TYPE_PLURALS[type], n]
		block.mouse_filter = Control.MOUSE_FILTER_STOP
		type_bar.add_child(block)
		parts.append("%s %d" % [TYPE_PLURALS[type], n])
	legend.text = "   ".join(parts) if not parts.is_empty() else "The Life Deck is empty. Click cards in the library to add them, or drag them here."


## Strips by type, each type's strips with the deck's own school first, then Freestyle, then
## Signature, then by name. A strip whose card breaks a rule is tinted.
func _fill_strips(list: VBoxContainer, ids: Array[String], pile: String, flagged: Dictionary) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var own: String = draft.deck.style
	var rank: Callable = func(d: CardDef) -> int:
		var g: String = group_key(d)
		return 0 if g == own else (1 if g == GROUP_FREESTYLE else (2 if g == GROUP_SIGNATURE else 3))
	for type: CardDef.Type in TYPE_ORDER:
		var group: Array[String] = []
		var copies: int = 0
		for id in ids:
			var def: CardDef = Session.library.defs.get(id)
			if def != null and def.type == type:
				copies += 1
				if not group.has(id):
					group.append(id)
		if group.is_empty():
			continue
		group.sort_custom(func(a: String, b: String) -> bool:
			var da: CardDef = Session.library.defs[a]
			var db: CardDef = Session.library.defs[b]
			if int(rank.call(da)) != int(rank.call(db)):
				return int(rank.call(da)) < int(rank.call(db))
			return da.title < db.title)
		var header: Label = Label.new()
		header.text = "%s  %d" % [TYPE_PLURALS[type].to_upper(), copies]
		header.theme_type_variation = &"CaptionLabel"
		list.add_child(header)
		var groups: Dictionary = {}
		for id in group:
			groups[group_key(Session.library.defs[id] as CardDef)] = true
		var last_group: String = ""
		for id in group:
			var def: CardDef = Session.library.defs[id]
			# Within a type, a quiet line names each school group when there is more than one.
			if groups.size() > 1 and group_key(def) != last_group:
				last_group = group_key(def)
				var divider: HBoxContainer = HBoxContainer.new()
				divider.add_theme_constant_override("separation", 8)
				divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var lead: ColorRect = ColorRect.new()
				lead.custom_minimum_size = Vector2(14, 1)
				lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				lead.color = Color(ZenithTheme.ACCENT, 0.3)
				divider.add_child(lead)
				var sub: Label = Label.new()
				sub.text = _group_label(last_group)
				sub.add_theme_font_size_override("font_size", 16)
				sub.add_theme_color_override("font_color", Color(ZenithTheme.ACCENT, 0.6))
				divider.add_child(sub)
				var rule: ColorRect = ColorRect.new()
				rule.custom_minimum_size = Vector2(0, 1)
				rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				rule.color = Color(ZenithTheme.ACCENT, 0.15)
				divider.add_child(rule)
				list.add_child(divider)
			var why: String = draft.legal_block(def)
			if def.type == CardDef.Type.PERSONALITY and draft.duelist() != null and def.character == draft.duelist().character:
				why = "An Ally may not share the Duelist's character."
			if why == "" and flagged.has(id):
				why = "This card breaks a deck rule. Open the problems list."
			var strip: Button = _build_strip(def, ids.count(id), pile, why)
			list.add_child(strip)
			_strips["%s:%s" % [pile, id]] = strip


## One strip: type edge, a faded crop of the art, the title, copies against the limit, and − / +
## buttons. A plain click only shows the card; right-click, − or a drag out takes a copy away.
func _build_strip(def: CardDef, copies: int, pile: String, why: String) -> Button:
	var row: Button = Button.new()
	row.custom_minimum_size = Vector2(0, STRIP_HEIGHT)
	row.focus_mode = Control.FOCUS_NONE
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.clip_contents = true
	var fill: Color = ZenithTheme.WARN_SOFT if why != "" else ZenithTheme.RAISED
	row.add_theme_stylebox_override("normal", ZenithTheme.box(fill, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 0, 0))
	row.add_theme_stylebox_override("hover", ZenithTheme.box(ZenithTheme.HOVER, ZenithTheme.FRAME, ZenithTheme.RADIUS, 1, 0, 0))
	row.add_theme_stylebox_override("pressed", ZenithTheme.box(ZenithTheme.HOVER, ZenithTheme.FRAME, ZenithTheme.RADIUS, 1, 0, 0))
	var art: Texture2D = CardFace.art_texture(def, def.aspect)
	if art != null:
		var crop: TextureRect = TextureRect.new()
		crop.texture = art
		crop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		crop.anchor_left = 1.0
		crop.anchor_right = 1.0
		crop.anchor_bottom = 1.0
		crop.offset_left = -250.0
		crop.offset_right = -132.0
		crop.modulate = Color(1, 1, 1, 0.32)
		crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(crop)
	var h: HBoxContainer = HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_right = -4
	row.add_child(h)
	var edge: ColorRect = ColorRect.new()
	edge.custom_minimum_size = Vector2(5, 0)
	edge.color = Palette.type_ui(def.type)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(edge)
	var name_label: Label = Label.new()
	name_label.text = def.title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(1, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", STRIP_FONT)
	name_label.add_theme_color_override("font_color", ZenithTheme.WARN if why != "" else ZenithTheme.TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(name_label)
	var limit: int = draft.limit(def.id)
	var count: Label = Label.new()
	count.text = "%d/%d" % [copies, limit]
	count.custom_minimum_size = Vector2(40, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", STRIP_FONT)
	count.add_theme_color_override("font_color", ZenithTheme.ENERGY if copies >= limit else ZenithTheme.TEXT_SOFT)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(count)
	var id: String = def.id
	var minus: Button = Button.new()
	minus.text = "−"
	minus.theme_type_variation = &"CompactButton"
	minus.custom_minimum_size = Vector2(30, 0)
	minus.focus_mode = Control.FOCUS_NONE
	minus.tooltip_text = "Take one out"
	h.add_child(minus)
	var plus: Button = Button.new()
	plus.text = "+"
	plus.theme_type_variation = &"CompactButton"
	plus.custom_minimum_size = Vector2(30, 0)
	plus.focus_mode = Control.FOCUS_NONE
	plus.tooltip_text = "Add one more"
	plus.disabled = draft.add_block(id, pile == "reserve") != ""
	if not plus.disabled:
		plus.add_theme_color_override("font_color", ZenithTheme.ACCENT)
	h.add_child(plus)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	# The buttons stay quiet until the row is under the pointer; a + that can add still shows at rest.
	var rest_plus: float = 0.6 if not plus.disabled else 0.12
	minus.modulate.a = 0.3
	plus.modulate.a = rest_plus
	row.mouse_entered.connect(func() -> void:
		minus.modulate.a = 1.0
		plus.modulate.a = 1.0 if not plus.disabled else 0.12)
	row.mouse_exited.connect(func() -> void:
		if not row.get_global_rect().has_point(row.get_global_mouse_position()):
			minus.modulate.a = 0.3
			plus.modulate.a = rest_plus)
	var take: Callable = func() -> String:
		return "" if (draft.remove_reserve(id) if pile == "reserve" else draft.remove(id)) else "That card is already out."
	var remove: Callable = func() -> void:
		_hide_preview()
		var tile: BuilderCard = _tile_of.get(id)
		var start: Rect2 = row.get_global_rect()
		if _mutate(take) and tile != null and tile.is_visible_in_tree():
			_fly(tile.face.texture, start, tile.get_global_rect())
	row.gui_input.connect(func(event: InputEvent) -> void:
		var press: InputEventMouseButton = event as InputEventMouseButton
		if press != null and press.pressed and press.button_index == MOUSE_BUTTON_RIGHT:
			remove.call())
	minus.pressed.connect(remove)
	plus.pressed.connect(func() -> void:
		_flash = "%s:%s" % [pile, id]
		_mutate(func() -> String:
			var block: String = draft.add_block(id, pile == "reserve")
			if block == "":
				draft.add(id, pile == "reserve")
			return block))
	row.mouse_entered.connect(func() -> void: _show_preview(def, row, why, HINT_STRIP))
	row.mouse_exited.connect(_hide_preview)
	row.set_drag_forwarding(_drag_card.bind(pile, id), _can_drop.bind(pile), _drop.bind(pile))
	return row


## After a refresh: the strip an add landed on scrolls into view and glows, and the card flies in.
func _land_flash() -> void:
	var key: String = _flash
	var from: BuilderCard = _fly_from
	var dropped: Rect2 = _fly_rect
	var dropped_texture: Texture2D = _drag_texture
	_flash = ""
	_fly_from = null
	_fly_rect = Rect2()
	if key == "" or not _strips.has(key):
		return
	var strip: Button = _strips[key]
	await get_tree().process_frame
	if not is_instance_valid(strip):
		return
	(reserve_scroll if key.begins_with("reserve:") else list_scroll).ensure_control_visible(strip)
	await get_tree().process_frame
	if not is_instance_valid(strip):
		return
	if from != null and is_instance_valid(from):
		_fly(from.face.texture, from.get_global_rect(), strip.get_global_rect())
	elif dropped.has_area() and dropped_texture != null:
		_fly(dropped_texture, dropped, strip.get_global_rect())
	if ArcaneBackdrop.motion_reduced():
		return
	strip.modulate = Color(1.7, 1.6, 1.25)
	create_tween().tween_property(strip, "modulate", Color.WHITE, 0.5)


## A copy of a card face flies from one rect to another and fades.
## With `settle` the card keeps its face to the end and lands exactly on `to`, as a card dropped
## somewhere it cannot go slides back into its place.
func _fly(texture: Texture2D, from: Rect2, to: Rect2, settle: bool = false) -> void:
	if ArcaneBackdrop.motion_reduced() or texture == null or not from.has_area():
		return
	var ghost: TextureRect = TextureRect.new()
	ghost.texture = texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	move_child(ghost, preview.get_index())
	ghost.position = from.position
	ghost.size = from.size
	var tween: Tween = create_tween().set_parallel(true)
	if settle:
		tween.tween_property(ghost, "position", to.position, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost, "size", to.size, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(ghost, "modulate:a", 0.0, 0.12)
	else:
		var end_size: Vector2 = Vector2(to.size.y / CARD_RATIO, to.size.y) if to.size.y < from.size.y else to.size
		tween.tween_property(ghost, "position", to.position + Vector2(to.size.x * 0.1, 0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(ghost, "size", end_size, 0.3)
		tween.tween_property(ghost, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ghost.queue_free)


func _on_side(side: String) -> void:
	if draft.deck.alignment == side:
		_refresh_deck()
		return
	_mutate(func() -> String: return "" if draft.set_alignment(side) else "This Duelist serves one side only.")


func _fix_problems() -> void:
	problems_overlay.visible = false
	var before: int = draft.deck.cards.size() + draft.deck.reserve.size()
	var fix: Callable = func() -> String:
		return "" if draft.remove_illegal() > 0 else "No card can be taken out to fix these. Add cards or change the Duelist."
	if _mutate(fix):
		var removed: int = before - draft.deck.cards.size() - draft.deck.reserve.size()
		_toast("Took out %d %s. Undo puts them back." % [removed, "card" if removed == 1 else "cards"], false)


func _open_problems() -> void:
	var problems: Array[String] = draft.readable_problems()
	if problems.is_empty():
		_toast("Every deck rule is met. Save it and play it.", false, problems_button.get_global_rect().position + Vector2(-300, 40))
		return
	problems_text.text = "\n".join(problems)
	var fixable: int = 0
	for id in draft.deck.cards + draft.deck.reserve:
		var def: CardDef = Session.library.defs.get(id)
		if def != null and draft.legal_block(def) != "":
			fixable += 1
	problems_fix.visible = fixable > 0
	problems_fix.text = "Take out the %d %s this deck cannot run" % [fixable, "card" if fixable == 1 else "cards"]
	problems_overlay.visible = true
	problems_panel.reset_size()
	var anchor: Rect2 = problems_button.get_global_rect()
	problems_panel.position = Vector2(clampf(anchor.end.x - problems_panel.size.x, 16.0, get_viewport_rect().size.x - problems_panel.size.x - 16.0), anchor.end.y + 8.0)


# --- Toasts and the preview -----------------------------------------------------------------------

## A short note beside the pointer (or at `at`), fading after a moment.
func _toast(text: String, warn: bool, at: Vector2 = Vector2(-1, -1)) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color", ZenithTheme.WARN if warn else ZenithTheme.TEXT)
	(toast.get_theme_stylebox("normal") as StyleBoxFlat).border_color = ZenithTheme.WARN if warn else ZenithTheme.ACCENT
	toast.reset_size()
	var spot: Vector2 = get_global_mouse_position() + Vector2(18, 22) if at.x < 0.0 else at
	var view: Vector2 = get_viewport_rect().size
	toast.position = Vector2(clampf(spot.x, 12.0, view.x - toast.size.x - 12.0), clampf(spot.y, 12.0, view.y - toast.size.y - 12.0))
	toast.modulate.a = 1.0
	toast.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(func() -> void: toast.visible = false)


func _show_preview(def: CardDef, anchor: Control, why: String = "", hint: String = "") -> void:
	var texture: Texture2D = faces.face(def, def.aspect)
	if texture == null:
		texture = await faces.render_face(def, def.aspect)
	if not is_instance_valid(anchor) or not anchor.is_visible_in_tree() or not anchor.get_global_rect().has_point(get_global_mouse_position()):
		return
	_place_preview(def, texture, anchor, why, hint)


## The card large beside `anchor`, never over it: to its right when there is room, else its left.
## Under the face: copies against the limit, the Reserve, the school and type, and why the deck
## cannot use it, then the clicks it takes.
func _place_preview(def: CardDef, texture: Texture2D, anchor: Control, why: String, hint: String) -> void:
	preview_face.texture = texture
	var lines: PackedStringArray = PackedStringArray()
	if def.type != CardDef.Type.MASTERY and not draft.deck.duelist_ids.has(def.id):
		var held: String = "In the deck %d of %d" % [draft.deck.cards.count(def.id), draft.limit(def.id)]
		if draft.deck.reserve.has(def.id):
			held += "   ·   Reserve %d" % draft.deck.reserve.count(def.id)
		lines.append(held)
		var limit_why: String = draft.limit_reason(def.id)
		if limit_why != "":
			lines.append(limit_why)
	var kind: String = "%s %s" % [_group_label(group_key(def)), str(CardText.TYPE_LABELS.get(def.type, "Card"))]
	if def.is_signature():
		kind = "Signature %s  ·  %s" % [str(CardText.TYPE_LABELS.get(def.type, "Card")), def.character]
	lines.append(kind)
	preview_info.text = "\n".join(lines)
	preview_info.add_theme_color_override("font_color", ZenithTheme.TEXT_SOFT)
	if why != "":
		preview_hint.text = why
		preview_hint.add_theme_color_override("font_color", ZenithTheme.WARN)
	else:
		preview_hint.text = hint
		preview_hint.add_theme_color_override("font_color", ZenithTheme.MUTED)
	preview_hint.visible = preview_hint.text != ""
	preview.reset_size()
	var rect: Rect2 = anchor.get_global_rect()
	var view: Vector2 = get_viewport_rect().size
	# A library card's preview stays over the library, off the deck column and above its footer.
	var in_pool: bool = editor.visible and pool_panel.get_global_rect().encloses(rect)
	var right_edge: float = deck_panel.get_global_rect().position.x - PREVIEW_GAP if in_pool else view.x - PREVIEW_GAP
	# Whichever side it lands on, it ends above the library's footer line.
	var bottom: float = footer.get_global_rect().position.y - 4.0 if editor.visible else view.y - PREVIEW_GAP
	var at: Vector2 = Vector2(rect.end.x + PREVIEW_GAP, rect.get_center().y - preview.size.y * 0.5)
	if at.x + preview.size.x > right_edge:
		# Left of the anchor; a deck strip's preview clears the deck panel's frame too.
		var left_of: float = rect.position.x
		if editor.visible and deck_panel.get_global_rect().encloses(rect):
			left_of = deck_panel.get_global_rect().position.x
		at.x = left_of - PREVIEW_GAP - preview.size.x
	at.x = maxf(at.x, PREVIEW_GAP)
	at.y = clampf(at.y, PREVIEW_GAP, maxf(PREVIEW_GAP, bottom - preview.size.y))
	preview.position = at
	preview.visible = true


func _hide_preview() -> void:
	if not _pin_preview:
		preview.visible = false


# --- Drag and drop --------------------------------------------------------------------------------

## Picks a card up: the card itself rides the pointer (DragCard), and what it was lifted from dims
## until it lands or comes back.
func _drag_card(_at: Vector2, from: String, id: String) -> Variant:
	_pin_preview = false
	_hide_preview()
	var def: CardDef = Session.library.defs[id]
	var texture: Texture2D = faces.face(def, def.aspect)
	var source: Control = _tile_of.get(id) if from == "pool" else _strips.get("%s:%s" % [from, id])
	_drag_texture = texture
	_drag_origin = source.get_global_rect() if source != null else Rect2()
	_drag_source = source
	if texture != null:
		var held: DragCard = DragCard.make(texture, _card_size * 0.9)
		# Over the deck list the card shrinks so the strips it passes stay readable.
		held.shrink_zone = deck_panel.get_global_rect()
		set_drag_preview(held)
	else:
		var tag: Label = Label.new()
		tag.text = def.title
		ZenithTheme.chip(tag, ZenithTheme.ACCENT, true)
		set_drag_preview(tag)
	if source != null and from == "pool":
		source.modulate.a = 0.35
	_dragging = true
	_paint_drop_zones(from)
	return {"builder": true, "from": from, "id": id}


## While a card is dragged, the places it can go are outlined.
## While a card is dragged, every place it can go gets a faint outline, and the one under it a lit
## fill.
func _paint_drop_zones(from: String = "") -> void:
	if from != "":
		_drag_from = from
	if not _dragging:
		_drag_from = ""
		_hot_zone = ""
		_hot_block = ""
	var targets: Array = [[list_scroll, "life"], [reserve_scroll, "reserve"], [pool_scroll, "pool"]]
	for pair: Array in targets:
		var zone: ScrollContainer = pair[0]
		var key: String = pair[1]
		var open: bool = _dragging and _drag_from != key
		# The same padding lit or not, so nothing in the list shifts or clips as a card passes.
		var box: StyleBoxFlat = ZenithTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), ZenithTheme.RADIUS, 2, 4, 4)
		if open and _hot_zone == key:
			var refused: bool = _hot_block != ""
			box = ZenithTheme.box(Color(ZenithTheme.WARN if refused else ZenithTheme.ACCENT, 0.08),
				ZenithTheme.WARN if refused else ZenithTheme.ACCENT, ZenithTheme.RADIUS, 2, 4, 4)
		elif open:
			box = ZenithTheme.box(Color(0, 0, 0, 0), ZenithTheme.ACCENT_SOFT, ZenithTheme.RADIUS, 2, 4, 4)
		zone.add_theme_stylebox_override("panel", box)


## Over a zone the card could go to: lit, or warn-tinted with the reason beside the pointer when the
## deck would refuse it there (a card at its limit, the Reserve full), so the player knows before
## letting go.
func _can_drop(_at: Vector2, data: Variant, to: String) -> bool:
	var ok: bool = data is Dictionary and bool((data as Dictionary).get("builder", false)) and str((data as Dictionary).get("from", "")) != to
	var block: String = ""
	if ok and to != "pool":
		var id: String = str((data as Dictionary)["id"])
		var from: String = str((data as Dictionary)["from"])
		if from == "pool":
			block = draft.add_block(id, to == "reserve")
		elif to == "reserve" and draft.deck.reserve.size() >= _reserve_size():
			block = "The Reserve is full."
	var hot: String = to if ok else ""
	if hot != _hot_zone or block != _hot_block:
		_hot_zone = hot
		var was: String = _hot_block
		_hot_block = block
		_paint_drop_zones()
		if block != "" and block != was:
			_toast(block, true)
	return ok and block == ""


func _reserve_size() -> int:
	var relic: CardDef = Session.library.defs.get(draft.deck.relic_id)
	return relic.reserve_size if relic != null else 0


func _drop(_at: Vector2, data: Variant, to: String) -> void:
	var from: String = str((data as Dictionary)["from"])
	var id: String = str((data as Dictionary)["id"])
	_dragging = false
	_paint_drop_zones()
	var size_now: Vector2 = _card_size * 0.9
	_fly_rect = Rect2(get_global_mouse_position() - size_now * 0.5, size_now)
	match to:
		"pool":
			_mutate(func() -> String: return "" if (draft.remove_reserve(id) if from == "reserve" else draft.remove(id)) else "")
		"life", "reserve":
			var to_reserve: bool = to == "reserve"
			_flash = "%s:%s" % [to, id]
			_mutate(func() -> String:
				var block: String = draft.add_block(id, to_reserve) if from == "pool" else ""
				if block != "":
					return block
				if from == "pool":
					draft.add(id, to_reserve)
				elif from == "life":
					draft.remove(id)
					block = draft.add_block(id, true)
					if block != "":
						draft.add(id)
						return block
					draft.add(id, true)
				else:
					draft.remove_reserve(id)
					block = draft.add_block(id)
					if block != "":
						draft.add(id, true)
						return block
					draft.add(id)
				return "")


# --- The Duelist picker ---------------------------------------------------------------------------

func _build_duelist_picker() -> void:
	for character in DeckDraft.duelist_characters(Session.library):
		var stack: Array[String] = DeckDraft.stack_for(Session.library, character)
		var first: CardDef = Session.library.defs[stack[0]]
		var tile: Button = Button.new()
		tile.custom_minimum_size = Vector2(240, 248)
		tile.toggle_mode = true
		tile.focus_mode = Control.FOCUS_NONE
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tile.set_meta("character", character)
		var column: VBoxContainer = VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_left = 8
		column.offset_right = -8
		column.offset_top = 8
		column.offset_bottom = -8
		column.add_theme_constant_override("separation", 4)
		column.clip_contents = true
		tile.add_child(column)
		var art: TextureRect = TextureRect.new()
		art.texture = CardFace.art_texture(first, first.aspect)
		art.custom_minimum_size = Vector2(0, 150)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(art)
		if art.texture == null:
			var figure: TypeIcon = TypeIcon.new()
			figure.type = CardDef.Type.PERSONALITY
			figure.color = Color(1, 1, 1, 0.3)
			figure.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			figure.offset_top = 24
			figure.offset_bottom = -24
			figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.add_child(figure)
		var name_label: Label = Label.new()
		name_label.text = character
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.custom_minimum_size = Vector2(1, 0)
		column.add_child(name_label)
		var info: Label = Label.new()
		info.theme_type_variation = &"CaptionLabel"
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info.custom_minimum_size = Vector2(1, 0)
		info.text = _character_line(character, true)
		column.add_child(info)
		tile.pressed.connect(_pick_character.bind(character))
		picker_grid.add_child(tile)
	for n in range(picker_faces.size()):
		var face: TextureRect = picker_faces[n]
		face.mouse_filter = Control.MOUSE_FILTER_STOP
		face.mouse_entered.connect(func() -> void:
			var id: String = str(face.get_meta("card", ""))
			if id != "":
				_show_preview(Session.library.defs[id], face))
		face.mouse_exited.connect(_hide_preview)


## "Draconic · Pact · Aspects 1-5", from a character's printed cards; `short` drops the words so
## it fits a picker tile ("Draconic · Pact · 1-5").
func _character_line(character: String, short: bool = false) -> String:
	var stack: Array[String] = DeckDraft.stack_for(Session.library, character)
	var first: CardDef = Session.library.defs[stack[0]]
	var parts: PackedStringArray = PackedStringArray()
	if first.bloodline != "":
		parts.append(CardText.bloodline_name(first.bloodline))
	var side: String = ""
	for id in stack:
		var s: String = (Session.library.defs[id] as CardDef).alignment_only
		side = s if s != "" else side
	parts.append(side.capitalize() if side != "" else ("Either" if short else "Either side"))
	parts.append(("1-%d" if short else "Aspects 1-%d") % stack.size())
	return (" · " if short else "  ·  ").join(parts)


func _open_duelist_picker(character: String = "") -> void:
	_hide_preview()
	duelist_picker.visible = true
	var head: CardDef = draft.duelist()
	picker_cancel.text = "Cancel" if head != null else "Back to your decks"
	var start: String = character if character != "" else (head.character if head != null else "")
	if start == "" or not DeckDraft.duelist_characters(Session.library).has(start):
		start = str(picker_grid.get_child(0).get_meta("character"))
	_pick_character(start)


func _cancel_duelist_picker() -> void:
	duelist_picker.visible = false
	_hide_preview()
	if draft.duelist() == null and draft.deck.cards.is_empty():
		_dirty = false
		if _draft_owned:
			CustomDecks.clear_draft()
		_show_shelf()


func _pick_character(character: String) -> void:
	_picked_character = character
	for tile: Node in picker_grid.get_children():
		var button: Button = tile as Button
		var on: bool = str(button.get_meta("character")) == character
		button.button_pressed = on
		button.add_theme_stylebox_override("normal", ZenithTheme.selected_box(8, 8) if on else ZenithTheme.box(ZenithTheme.BG, ZenithTheme.BORDER, ZenithTheme.RADIUS, 1, 8, 8))
		button.add_theme_stylebox_override("hover", ZenithTheme.selected_box(8, 8) if on else ZenithTheme.box(ZenithTheme.BG_ACTIVE, ZenithTheme.FRAME, ZenithTheme.RADIUS, 1, 8, 8))
	var lines: Array[String] = DeckDraft.lines_of(Session.library, character)
	for child in picker_lines.get_children():
		picker_lines.remove_child(child)
		child.queue_free()
	_picked_line = DeckDraft.main_line(Session.library, character)
	var head: CardDef = draft.duelist()
	if head != null and head.character == character:
		for id in draft.deck.duelist_ids:
			var v: String = (Session.library.defs[id] as CardDef).variant
			if v != "" and lines.has(v):
				_picked_line = v
	if lines.size() > 1:
		var label: Label = Label.new()
		label.text = "LINE"
		label.theme_type_variation = &"CaptionLabel"
		picker_lines.add_child(label)
		for line in lines:
			var button: Button = Button.new()
			button.text = line
			button.toggle_mode = true
			button.theme_type_variation = &"CompactButton"
			button.pressed.connect(func() -> void:
				_picked_line = line
				_show_picked_stack())
			picker_lines.add_child(button)
	picker_name.text = character
	_show_picked_stack()


func _show_picked_stack() -> void:
	for child: Node in picker_lines.get_children():
		var button: Button = child as Button
		if button != null:
			button.button_pressed = button.text == _picked_line
			button.theme_type_variation = &"AccentButton" if button.text == _picked_line else &"CompactButton"
	var stack: Array[String] = DeckDraft.stack_for(Session.library, _picked_character, _picked_line)
	var tags: Array[String] = []
	for id in stack:
		for t in (Session.library.defs[id] as CardDef).raw.get("tags", []):
			if not tags.has(CardText.keyword_name(str(t))):
				tags.append(CardText.keyword_name(str(t)))
	picker_info.text = _character_line(_picked_character) + (("  ·  " + ", ".join(tags)) if not tags.is_empty() else "")
	var head: CardDef = draft.duelist()
	var same: bool = head != null and head.character == _picked_character and draft.deck.duelist_ids == stack
	picker_choose.text = "Keep %s" % _picked_character if same else "Choose %s" % _picked_character
	var picked: String = _picked_character
	var line: String = _picked_line
	for n in range(picker_faces.size()):
		picker_faces[n].texture = null
		picker_faces[n].visible = n < stack.size()
		picker_faces[n].set_meta("card", stack[n] if n < stack.size() else "")
	for n in range(stack.size()):
		var def: CardDef = Session.library.defs[stack[n]]
		var texture: Texture2D = await faces.render_face(def, def.aspect)
		if _picked_character != picked or _picked_line != line or not is_inside_tree():
			return
		picker_faces[n].texture = texture


func _on_choose_duelist() -> void:
	duelist_picker.visible = false
	_hide_preview()
	var character: String = _picked_character
	var line: String = _picked_line
	var stack: Array[String] = DeckDraft.stack_for(Session.library, character, line)
	if draft.deck.duelist_ids != stack:
		var allies: int = 0
		for id in draft.deck.cards + draft.deck.reserve:
			var def: CardDef = Session.library.defs.get(id)
			if def != null and def.type == CardDef.Type.PERSONALITY and def.character == character:
				allies += 1
		_mutate(func() -> String:
			draft.choose_duelist(character, line)
			return "")
		if allies > 0:
			_toast("%d %s of %s left the deck: an Ally may not share the Duelist's character." % [allies, "Ally" if allies == 1 else "Allies", character], false,
				deck_panel.get_global_rect().position + Vector2(20, 240))
	if draft.deck.mastery_id == "":
		_open_mastery_picker()


# --- The Mastery picker ---------------------------------------------------------------------------

func _open_mastery_picker() -> void:
	_hide_preview()
	for child in mastery_list.get_children():
		mastery_list.remove_child(child)
		child.queue_free()
	var by_school: Dictionary = {}
	for def: CardDef in Session.library.defs.values():
		if def.type == CardDef.Type.MASTERY and not bool(def.raw.get("banned", false)):
			if not by_school.has(def.school):
				by_school[def.school] = [] as Array[CardDef]
			(by_school[def.school] as Array[CardDef]).append(def)
	mastery_picker.visible = true
	for school in SCHOOL_ORDER:
		if not by_school.has(school):
			continue
		var masteries: Array[CardDef] = by_school[school]
		masteries.sort_custom(func(a: CardDef, b: CardDef) -> bool: return a.title < b.title)
		var block: VBoxContainer = VBoxContainer.new()
		block.add_theme_constant_override("separation", 6)
		mastery_list.add_child(block)
		var heading: HBoxContainer = HBoxContainer.new()
		heading.add_theme_constant_override("separation", 10)
		block.add_child(heading)
		var label: Label = Label.new()
		label.text = CardText.school_name(school)
		label.theme_type_variation = &"HeaderLabel"
		label.add_theme_color_override("font_color", Palette.school_ui(school).lightened(0.2))
		heading.add_child(label)
		var why: String = draft.fit_block(masteries[0])
		if why != "":
			var note: Label = Label.new()
			note.text = why
			note.theme_type_variation = &"CaptionLabel"
			note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			heading.add_child(note)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		block.add_child(row)
		for def in masteries:
			row.add_child(_mastery_button(def))
	var start: String = draft.deck.mastery_id
	if start == "":
		for id in draft.mastery_options():
			start = id
			break
	_pick_mastery(start)


## One Mastery in the picker: its face with a readable name under it. Clicking it shows it in
## the detail pane; Choose takes it.
func _mastery_button(def: CardDef) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.set_meta("mastery", def.id)
	var button: TextureButton = TextureButton.new()
	button.custom_minimum_size = Vector2(98, 137)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var why: String = draft.fit_block(def)
	button.modulate = Color(0.45, 0.45, 0.45) if why != "" else Color.WHITE
	button.tooltip_text = why
	box.add_child(button)
	var ring: Panel = Panel.new()
	ring.name = "Ring"
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_theme_stylebox_override("panel", ZenithTheme.box(Color.TRANSPARENT, ZenithTheme.ACCENT, 8, 3, 0, 0))
	ring.visible = false
	button.add_child(ring)
	var title: Label = Label.new()
	title.text = def.title.trim_suffix(" Mastery").get_slice(" ", 1)
	title.custom_minimum_size = Vector2(98, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.theme_type_variation = &"CaptionLabel"
	title.add_theme_color_override("font_color", ZenithTheme.MUTED if why != "" else ZenithTheme.TEXT)
	box.add_child(title)
	if def.id == draft.deck.mastery_id:
		var held: Label = Label.new()
		held.text = "IN DECK"
		held.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		held.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ZenithTheme.chip(held, ZenithTheme.ACCENT)
		box.add_child(held)
	var id: String = def.id
	button.pressed.connect(func() -> void: _pick_mastery(id))
	_fill_texture_button(button, def)
	return box


## Shows `id` in the detail pane, rings it, and says what choosing it means for this deck.
func _pick_mastery(id: String) -> void:
	_picked_mastery = id
	var def: CardDef = Session.library.defs.get(id)
	for block: Node in mastery_list.get_children():
		for box: Node in block.get_child(1).get_children():
			var ring: Panel = box.get_child(0).get_node("Ring")
			ring.visible = str(box.get_meta("mastery", "")) == id
	if def == null:
		mastery_name.text = ""
		mastery_face.texture = null
		mastery_info.text = "No Mastery fits this Duelist."
		mastery_choose.disabled = true
		return
	mastery_name.text = def.title
	var why: String = draft.fit_block(def)
	var breaks: int = 0 if why != "" or draft.deck.cards.is_empty() else draft.illegal_after_mastery(id)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s school. Its cards and Freestyle cards stay in the library." % CardText.school_name(def.school) \
		if def.school != "" else "Freestyle: no school cards at all, every Freestyle card.")
	if why != "":
		lines.append(why)
	elif breaks > 0:
		lines.append("Choosing it leaves %d %s in this deck that it cannot run." % [breaks, "card" if breaks == 1 else "cards"])
	mastery_info.text = "\n".join(lines)
	mastery_info.add_theme_color_override("font_color", ZenithTheme.WARN if why != "" or breaks > 0 else ZenithTheme.TEXT_SOFT)
	mastery_choose.disabled = why != ""
	mastery_choose.text = "Keep it" if id == draft.deck.mastery_id else "Choose it"
	mastery_face.texture = faces.face(def, def.aspect)
	if mastery_face.texture == null:
		var texture: Texture2D = await faces.render_face(def, def.aspect)
		if _picked_mastery == id:
			mastery_face.texture = texture


func _on_choose_mastery() -> void:
	var id: String = _picked_mastery
	mastery_picker.visible = false
	_hide_preview()
	if id == "" or draft.deck.mastery_id == id:
		return
	var breaks: int = 0 if draft.deck.cards.is_empty() else draft.illegal_after_mastery(id)
	_mutate(func() -> String:
		draft.set_mastery(id)
		return "")
	if breaks > 0:
		_toast("%d %s no longer fit this Mastery. The problems list can take them out." % [breaks, "card" if breaks == 1 else "cards"], true,
			problems_button.get_global_rect().position + Vector2(-420, 40))


func _fill_texture_button(button: TextureButton, def: CardDef) -> void:
	var texture: Texture2D = await faces.render_face(def, def.aspect)
	if is_instance_valid(button):
		button.texture_normal = texture


# --- Aspect slots ---------------------------------------------------------------------------------

func _open_aspect_popup(aspect: int) -> void:
	var head: CardDef = draft.duelist()
	if head == null:
		_open_duelist_picker()
		return
	var height: int = draft.deck.duelist_ids.size()
	if aspect > height + 1:
		_toast("Add Aspect %d first: a stack runs from Aspect 1 with no gaps." % (height + 1), true)
		return
	_aspect_at = aspect
	for child in aspect_options.get_children():
		aspect_options.remove_child(child)
		child.queue_free()
	var options: Array[String] = DeckDraft.aspect_options(Session.library, head.character, aspect)
	if options.is_empty():
		_toast("%s has no Aspect %d printed." % [head.character, aspect], true)
		return
	aspect_heading.text = "%s, Aspect %d" % [head.character, aspect]
	for id in options:
		var def: CardDef = Session.library.defs[id]
		var button: TextureButton = TextureButton.new()
		button.custom_minimum_size = ASPECT_CARD
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var held: bool = draft.deck.duelist_ids.has(id)
		var ring: Panel = Panel.new()
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_theme_stylebox_override("panel", ZenithTheme.box(Color.TRANSPARENT, ZenithTheme.ACCENT, 8, 3, 0, 0))
		ring.visible = held
		button.add_child(ring)
		button.pressed.connect(func() -> void:
			aspect_overlay.visible = false
			_hide_preview()
			if not held:
				_mutate(func() -> String: return "" if draft.set_aspect(id) else "That card cannot join this stack."))
		button.tooltip_text = "In the deck now" if held else "Use this printing"
		var hover_ring: Panel = ring
		button.mouse_entered.connect(func() -> void: hover_ring.visible = true)
		button.mouse_exited.connect(func() -> void: hover_ring.visible = held)
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.add_child(button)
		var caption: Label = Label.new()
		caption.custom_minimum_size = Vector2(ASPECT_CARD.x, 0)
		caption.add_theme_font_size_override("font_size", 20)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.text = def.aspect_title if def.aspect_title != "" else (def.variant if def.variant != "" else def.title)
		caption.add_theme_color_override("font_color", ZenithTheme.TEXT if held else ZenithTheme.TEXT_SOFT)
		box.add_child(caption)
		var tag: Label = Label.new()
		tag.text = "IN DECK"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ZenithTheme.chip(tag, ZenithTheme.ACCENT)
		tag.modulate.a = 1.0 if held else 0.0
		box.add_child(tag)
		aspect_options.add_child(box)
		_fill_texture_button(button, def)
	aspect_remove.add_theme_color_override("font_color", ZenithTheme.WARN)
	aspect_remove.add_theme_color_override("font_hover_color", ZenithTheme.WARN)
	aspect_remove.visible = aspect <= height
	aspect_remove.text = "Take Aspect %d out" % aspect if aspect == height else "Take Aspects %d to %d out" % [aspect, height]
	aspect_overlay.visible = true
	# Centred and large: printings of one Aspect differ in the rules text, which has to be readable.
	aspect_panel.reset_size()
	aspect_panel.position = ((get_viewport_rect().size - aspect_panel.size) * 0.5).round()


func _on_aspect_remove() -> void:
	aspect_overlay.visible = false
	var from: int = _aspect_at
	_mutate(func() -> String:
		var keep: Array[String] = []
		for id in draft.deck.duelist_ids:
			if (Session.library.defs[id] as CardDef).aspect < from:
				keep.append(id)
		draft.deck.set_duelist(keep)
		return "")


# --- Import ---------------------------------------------------------------------------------------

## Opens with the clipboard pasted in when it holds what looks like a deck list or code.
func _open_import() -> void:
	import_dialog.visible = true
	var clip: String = DisplayServer.clipboard_get()
	if paste_edit.text.strip_edges() == "" and clip.length() < 200000 \
			and (clip.contains("\n") or clip.begins_with("{") or clip.begins_with("<") or clip.begins_with(CustomDecks.CODE_PREFIX)):
		paste_edit.text = clip
	paste_edit.grab_focus()


func _on_import() -> void:
	if _index == null:
		_index = SourceIndex.shipped()
	var result: ImportResult = DeckImport.read(paste_edit.text, Session.library, _index)
	if result.error != "":
		_toast(result.error, true)
		return
	import_dialog.visible = false
	if editor.visible and not await _settle_unsaved("Replace this deck?"):
		return
	var next: DeckDraft = DeckDraft.new()
	next.library = Session.library
	next.deck = result.deck
	next.deck.custom = true
	next.deck.id = ""
	_last_import = result
	_load(next)
	_mark_dirty()
	_show_editor()
	paste_edit.text = ""
	_fill_import_notes()
	notes_button.button_pressed = not result.missing().is_empty() or not result.choices().is_empty() or not result.refused().is_empty()
	# Next step after an import: whatever the list could not settle.
	if draft.duelist() == null:
		_open_duelist_picker()
	elif draft.deck.mastery_id == "" and result.choices().is_empty():
		_open_mastery_picker()


## The import notes drawer: lines to pick first, then lines kept out and why, then every line with no
## parallel under one heading, as compact rows.
func _fill_import_notes() -> void:
	for child in notes_list.get_children():
		notes_list.remove_child(child)
		child.queue_free()
	var result: ImportResult = _last_import
	if result == null:
		return
	var open_copies: int = 0
	var open_lines: int = 0
	for line in result.lines:
		if line.status != ImportLine.MATCHED:
			open_copies += line.qty
			open_lines += 1
	notes_button.text = "Notes (%d)" % open_lines if open_lines > 0 else "Notes"
	notes_summary.text = "%d of %d copies came in. %d left to fill from the library." % [result.copies_matched(), result.copies_asked(), open_copies]
	for line in result.choices():
		notes_list.add_child(_note_row(line))
	for line in result.refused():
		notes_list.add_child(_note_row(line))
	# A missing frame card (Mastery, Duelist level, Relic) has an action and stays in view; the
	# Life Deck lines with no parallel fold under one heading, closed until asked for.
	var frame_lines: Array[ImportLine] = []
	var card_lines: Array[ImportLine] = []
	for line in result.missing():
		if line.slot in [ImportLine.MASTERY, ImportLine.DUELIST, ImportLine.RELIC]:
			frame_lines.append(line)
		else:
			card_lines.append(line)
	for line in frame_lines:
		notes_list.add_child(_missing_row(line))
	if not card_lines.is_empty():
		var group: VBoxContainer = VBoxContainer.new()
		group.add_theme_constant_override("separation", 2)
		group.visible = false
		var toggle: Button = Button.new()
		toggle.theme_type_variation = &"CompactButton"
		toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		toggle.toggle_mode = true
		var copies: int = 0
		for line in card_lines:
			copies += line.qty
		var label: String = "NO EIDOLARCH PARALLEL  ·  %d lines, %d copies" % [card_lines.size(), copies]
		toggle.text = "▸  " + label
		toggle.toggled.connect(func(on: bool) -> void:
			group.visible = on
			toggle.text = ("▾  " if on else "▸  ") + label)
		notes_list.add_child(toggle)
		notes_list.add_child(group)
		for line in card_lines:
			group.add_child(_missing_row(line))


## One line with no parallel. A missing Mastery, Duelist level or Relic opens what fills it; a Life
## Deck card has no parallel to look up, so its row only reports.
func _missing_row(line: ImportLine) -> Button:
	var action: Callable = Callable()
	var hint: String = ""
	match line.slot:
		ImportLine.MASTERY:
			action = _open_mastery_picker
			hint = "Choose a Mastery"
		ImportLine.DUELIST:
			action = _open_duelist_picker.bind("")
			hint = "Choose the Duelist"
		ImportLine.RELIC:
			action = _type_only.bind(CardDef.Type.RELIC)
			hint = "Show the Relics"
	var row: Button = Button.new()
	row.flat = action.is_null()
	row.disabled = action.is_null()
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.custom_minimum_size = Vector2(1, 30)
	row.text = "x%d  %s   (line %d)%s" % [line.qty, line.text, line.row, ("   ›  " + hint) if hint != "" else ""]
	row.theme_type_variation = &"CompactButton"
	row.add_theme_color_override("font_disabled_color", ZenithTheme.TEXT_SOFT)
	if not action.is_null():
		row.pressed.connect(action)
	return row


func _note_row(line: ImportLine) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var head: Label = Label.new()
	head.text = "x%d  %s" % [line.qty, line.text]
	head.add_theme_font_size_override("font_size", STRIP_FONT)
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.custom_minimum_size = Vector2(1, 0)
	box.add_child(head)
	var why: Label = Label.new()
	why.theme_type_variation = &"CaptionLabel"
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size = Vector2(1, 0)
	var where: String = "line %d" % line.row
	match line.status:
		ImportLine.REFUSED:
			why.text = "Matched %s, but it stays out: %s (%s)" % [(Session.library.defs[line.id] as CardDef).title, line.reason, where]
		ImportLine.CHOOSE:
			why.text = "Several Eidolarch cards parallel this one. Pick the one you want (%s)." % where
			why.add_theme_color_override("font_color", ZenithTheme.ACCENT)
	box.add_child(why)
	if line.status == ImportLine.CHOOSE:
		var options: HFlowContainer = HFlowContainer.new()
		options.add_theme_constant_override("h_separation", 8)
		for id in line.options:
			var def: CardDef = Session.library.defs[id]
			var pick: Button = Button.new()
			pick.text = def.title
			pick.theme_type_variation = &"CompactButton"
			var choose: Callable = func() -> String: return "" if draft.choose(line, id) else "That pick is no longer open."
			pick.pressed.connect(func() -> void:
				_hide_preview()
				if _mutate(choose):
					_fill_import_notes())
			pick.mouse_entered.connect(func() -> void: _show_preview(def, pick))
			pick.mouse_exited.connect(_hide_preview)
			options.add_child(pick)
		box.add_child(options)
	return box


# --- Saving, sharing, playing ---------------------------------------------------------------------

## True when the deck is saved. A deck with no Duelist is not worth a file yet.
func _on_save() -> bool:
	if draft.duelist() == null:
		_toast("Choose a Duelist before saving.", true, save_button.get_global_rect().position + Vector2(-260, 50))
		return false
	draft.deck.name = CustomDecks.clean_name(name_edit.text)
	name_edit.text = draft.deck.name
	if CustomDecks.save(draft.deck) == "":
		_toast("The deck could not be saved.", true, save_button.get_global_rect().position + Vector2(-200, 50))
		return false
	_dirty = false
	unsaved_chip.visible = false
	_set_save_enabled(false)
	save_as_button.disabled = false
	CustomDecks.clear_draft()
	_draft_owned = false
	_highlight_id = draft.deck.id
	Session.reload_decks()
	var problems: int = draft.problems().size()
	_toast("Saved. Ready for any duel but Ranked." if problems == 0 else "Saved. Fix its %d %s to play it." % [problems, "problem" if problems == 1 else "problems"],
		problems != 0, save_button.get_global_rect().position + Vector2(-330, 50))
	_refresh_deck()
	return true


func _on_share() -> void:
	DisplayServer.clipboard_set(CustomDecks.to_code(draft.deck))
	_toast("Deck code copied. Paste it into Import to load this deck.", false, share_button.get_global_rect().position + Vector2(-260, 50))


## A copy of these cards under a new file; the deck that was open stays as it was saved.
func _on_save_as() -> void:
	var original: String = draft.deck.name
	var old_id: String = draft.deck.id
	var old_text: String = name_edit.text
	draft.deck.id = ""
	if not name_edit.text.ends_with("(copy)") and name_edit.text == original:
		name_edit.text = CustomDecks.clean_name("%s (copy)" % original)
	if _on_save():
		_toast("Saved as a new deck, \"%s\". \"%s\" is unchanged." % [draft.deck.name, original], false,
			save_button.get_global_rect().position + Vector2(-520, 50))
	else:
		# The save failed: this is still the deck that was open.
		draft.deck.id = old_id
		name_edit.text = old_text


## Saves, then opens the duel select with this deck picked: against the AI (`ai_seat` 1) or
## hotseat (-1). The select screen's Back comes back here.
func _on_play(ai_seat: int) -> void:
	if not draft.problems().is_empty():
		_toast("Fix the deck's problems to play it.", true)
		return
	if (_dirty or draft.deck.id == "") and not _on_save():
		return
	Session.leave_adventure()
	Session.ai_seat = ai_seat
	Session.builder_from_select = false
	Session.builder_seat = -1
	Session.preselect_deck_id = draft.deck.id
	Session.builder_deck_id = draft.deck.id
	Session.go_to_select()


func _unhandled_input(event: InputEvent) -> void:
	if confirm.visible:
		return
	var key: InputEventKey = event as InputEventKey
	if editor.visible and key != null and key.pressed and not key.echo and (key.ctrl_pressed or key.meta_pressed):
		match key.keycode:
			KEY_Z:
				if key.shift_pressed:
					_on_redo()
				else:
					_on_undo()
			KEY_Y:
				_on_redo()
			KEY_F:
				search.grab_focus()
				search.select_all()
			KEY_S:
				_on_save()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		for overlay: Control in [import_dialog, aspect_overlay, problems_overlay, mastery_picker]:
			if overlay.visible:
				overlay.visible = false
				_hide_preview()
				return
		if duelist_picker.visible:
			_cancel_duelist_picker()
		elif editor.visible:
			_leave_editor()
		else:
			_leave_shelf()


# --- Dev flags ------------------------------------------------------------------------------------

## `--dev-builder-copy=<deck id>` opens a copy of a shipped deck in the editor,
## `--dev-builder-import=<path>` imports a file, `--dev-builder-save` saves the result (pair it with
## `--dev-scratch=<dir>`), `--dev-builder-picker=duelist[:<character>]|mastery` opens a picker,
## `--dev-builder-search=<text>`, `--dev-builder-showall`, `--dev-builder-reserve` opens the drawer,
## `--dev-builder-problems` the problems list, `--dev-builder-notes` the import notes,
## `--dev-builder-aspect=<n>` the Aspect popup, `--dev-builder-hover=<n>` previews the nth visible
## library card and `--dev-builder-hover-strip=<n>` the nth Life Deck strip,
## `--dev-builder-blank` opens a blank editor and `--dev-builder-confirm` asks the leave question.
## True when a flag opened the editor, so the deck shelf does not.
func _dev_flags() -> bool:
	var args: PackedStringArray = DevArgs.user_args()
	var opened: bool = false
	var copy: String = AdventureDev.flag("--dev-builder-copy=")
	if copy != "":
		for deck in Session.decks:
			if deck.id == copy:
				_load(DeckDraft.of(deck, Session.library))
				await _show_editor()
				opened = true
	var path: String = AdventureDev.flag("--dev-builder-import=")
	if path != "":
		paste_edit.text = FileAccess.get_file_as_string(path)
		await _on_import()
		opened = true
	if args.has("--dev-builder-blank"):
		_load(DeckDraft.blank(Session.library))
		await _show_editor()
		opened = true
	if not opened:
		return false
	if args.has("--dev-builder-save"):
		_on_save()
	var found: String = AdventureDev.flag("--dev-builder-search=")
	if found != "":
		search.text = found
		_filter()
	if args.has("--dev-builder-showall"):
		show_all.button_pressed = true
	if args.has("--dev-builder-reserve"):
		reserve_button.button_pressed = true
	if args.has("--dev-builder-notes"):
		notes_button.button_pressed = true
	var picker: String = AdventureDev.flag("--dev-builder-picker=")
	if picker != "":
		if picker.begins_with("mastery"):
			_open_mastery_picker()
		else:
			_open_duelist_picker(picker.get_slice(":", 1) if picker.contains(":") else "")
	if args.has("--dev-builder-problems"):
		await get_tree().create_timer(0.5).timeout
		_open_problems()
	if args.has("--dev-builder-confirm"):
		_mark_dirty()
		_leave_editor()
	var aspect: String = AdventureDev.flag("--dev-builder-aspect=")
	if aspect != "":
		await get_tree().create_timer(0.5).timeout
		_open_aspect_popup(int(aspect))
	var strip_at: String = AdventureDev.flag("--dev-builder-hover-strip=")
	if strip_at != "":
		await get_tree().create_timer(1.0).timeout
		var rows: Array = _strips.keys().filter(func(k: Variant) -> bool: return str(k).begins_with("life:"))
		if int(strip_at) < rows.size():
			var strip: Button = _strips[rows[int(strip_at)]]
			var def: CardDef = Session.library.defs[str(rows[int(strip_at)]).trim_prefix("life:")]
			_place_preview(def, await faces.render_face(def, def.aspect), strip, "", HINT_STRIP)
			_pin_preview = true
	# `--dev-builder-drag=<n>`: the nth visible library card held mid-drag over the Life Deck.
	var drag_at: String = AdventureDev.flag("--dev-builder-drag=")
	if drag_at != "":
		await get_tree().create_timer(1.0).timeout
		var visible_tiles: Array[BuilderCard] = []
		for tile: BuilderCard in _ordered_tiles():
			if tile.visible:
				visible_tiles.append(tile)
		var held: BuilderCard = visible_tiles[mini(int(drag_at), visible_tiles.size() - 1)]
		held.modulate.a = 0.35
		var card: DragCard = DragCard.make(held.face.texture, _card_size * 0.9)
		card.shrink_zone = deck_panel.get_global_rect()
		add_child(card)
		card.position = list_scroll.get_global_rect().get_center() + Vector2(-120, -60)
		card.pose(0.2)
		_dragging = true
		_hot_zone = "life"
		_paint_drop_zones("pool")
	var hover: String = AdventureDev.flag("--dev-builder-hover=")
	if hover != "":
		await get_tree().create_timer(1.0).timeout
		var n: int = int(hover)
		for tile: BuilderCard in _ordered_tiles():
			if tile.visible:
				if n == 0:
					var def: CardDef = Session.library.defs[tile.card_id]
					tile._hover(true)
					_place_preview(def, await faces.render_face(def, def.aspect), tile, tile.reason, HINT_POOL)
					_pin_preview = true
					break
				n -= 1
	return true
