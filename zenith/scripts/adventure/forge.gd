extends Control
## The Forge node's screen. Step one picks the action, Cut or Copy, or leaves; step two picks the
## card from the run deck, with a large preview saying what the action does to the deck. The rules
## live in AdventureForge; applying and saving go through Session.

const ACTIONS: Array[String] = [AdventureForge.ACTION_CUT, AdventureForge.ACTION_COPY]
const FACE_SIZE: Vector2 = Vector2(140, 196)
## The space round a face that the picked ring draws in, so picking never shifts the grid.
const RING_PAD: int = 4
const BLOCKED_TINT: Color = Color(0.42, 0.42, 0.42)

@onready var faces: CardFaceCache = $CardFaceCache
@onready var strip: PanelContainer = $Strip
@onready var run_name_label: Label = $Strip/Row/RunName
@onready var standing_label: Label = $Strip/Row/Standing
@onready var mote_icon: TextureRect = $Strip/Row/MotesBox/MoteIcon
@onready var motes_label: Label = $Strip/Row/MotesBox/MotesValue
@onready var choice_step: CenterContainer = $Body/ChoiceStep
@onready var choice_title: Label = $Body/ChoiceStep/Column/Title
@onready var tile_buttons: Array[Button] = [$Body/ChoiceStep/Column/Tiles/Cut, $Body/ChoiceStep/Column/Tiles/Copy]
@onready var description_label: Label = $Body/ChoiceStep/Column/Description
@onready var constraint_label: Label = $Body/ChoiceStep/Column/Constraint
@onready var leave_button: Button = $Body/ChoiceStep/Column/Leave
@onready var pick_step: VBoxContainer = $Body/PickStep
@onready var pick_title: Label = $Body/PickStep/Title
@onready var grid_panel: PanelContainer = $Body/PickStep/Center/Group/GridPanel
@onready var grid_caption: Label = $Body/PickStep/Center/Group/GridPanel/Column/Caption
@onready var grid: GridContainer = $Body/PickStep/Center/Group/GridPanel/Column/Scroll/Grid
@onready var preview_panel: PanelContainer = $Body/PickStep/Center/Group/PreviewPanel
@onready var preview_face: TextureRect = $Body/PickStep/Center/Group/PreviewPanel/Column/Face
@onready var preview_name: Label = $Body/PickStep/Center/Group/PreviewPanel/Column/Name
@onready var preview_change: Label = $Body/PickStep/Center/Group/PreviewPanel/Column/Change
@onready var preview_size: Label = $Body/PickStep/Center/Group/PreviewPanel/Column/Size
@onready var back_button: Button = $Body/PickStep/Buttons/Back
@onready var act_button: Button = $Body/PickStep/Buttons/Act
@onready var inspect: ColorRect = $Inspect
@onready var inspect_face: CardFace = $Inspect/Center/Column/Face

## The action step two is picking for, "" on step one.
var _action: String = ""
## Grid order: the deck's distinct cards, grouped by type and sorted by title.
var _ids: Array[String] = []
## Per grid entry: why it cannot be picked for `_action`, "" when it can.
var _blocks: Array[String] = []
var _rings: Array[PanelContainer] = []
var _picked: int = -1
var _dev: bool = false
var _busy: bool = false


func _ready() -> void:
	theme = SanctumUI.theme()
	_dev_setup()
	if Session.run == null:
		Session.go_to_adventure()
		return
	var run_deck: DeckList = Session.run.deck()
	MapArt.tint_for_school(run_deck.style if run_deck != null else "")
	for title: Label in [choice_title, pick_title]:
		SanctumUI.dress(self, title)
		title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var strip_box: StyleBoxFlat = ZenithTheme.box(ZenithTheme.BG, ZenithTheme.BORDER, 0, 0, ZenithTheme.GAP_L, ZenithTheme.GAP_XS)
	strip_box.border_width_bottom = 1
	strip.add_theme_stylebox_override("panel", strip_box)
	mote_icon.texture = MapArt.ui("mote")
	ZenithTheme.motes_label(motes_label)
	for panel: PanelContainer in [grid_panel, preview_panel]:
		panel.add_theme_stylebox_override("panel", MapArt.panel_box(22))
		# Pixel frames keep hard edges; the faces inside stay smooth.
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		(panel.get_child(0) as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for i in range(ACTIONS.size()):
		var tile: Button = tile_buttons[i]
		var icon: TextureRect = tile.get_node("Content/Icon")
		icon.texture = MapArt.ui("card_remove" if ACTIONS[i] == AdventureForge.ACTION_CUT else "card_add")
		var action: String = ACTIONS[i]
		tile.pressed.connect(func() -> void: _open_pick(action))
		tile.mouse_entered.connect(func() -> void: _describe(action))
		tile.focus_entered.connect(func() -> void: _describe(action))
	leave_button.pressed.connect(_on_leave)
	back_button.pressed.connect(_show_choice)
	act_button.pressed.connect(_on_act)
	inspect.gui_input.connect(_on_inspect_input)
	inspect.visible = false
	_refresh_strip()
	_show_choice()
	SanctumUI.wire_buttons(self)
	await _dev_after_layout()
	AdventureDev.screenshot(self)


func _refresh_strip() -> void:
	var run: AdventureRun = Session.run
	var deck: DeckList = run.deck()
	run_name_label.text = deck.name.trim_suffix(" (Starter)") if deck != null else ""
	standing_label.text = "Act %d   ·   %d won   ·   %d cards" % [
		MapRoute.act_to_show(run, Session.map), run.stage, AdventureForge.deck_size(run)]
	motes_label.text = str(Session.wallet.motes)


# --- Step one: the action -----------------------------------------------------------------

func _show_choice() -> void:
	_action = ""
	_hide_inspect()
	choice_step.visible = true
	pick_step.visible = false
	var first_open: String = ""
	for i in range(ACTIONS.size()):
		var reason: String = _action_block(ACTIONS[i])
		var tile: Button = tile_buttons[i]
		tile.disabled = reason != "" or _busy
		tile.tooltip_text = reason
		var icon: TextureRect = tile.get_node("Content/Icon")
		var name_label: Label = tile.get_node("Content/Name")
		var tint: Color = ZenithTheme.TEXT_DISABLED if reason != "" else ZenithTheme.ACCENT
		icon.self_modulate = tint
		name_label.add_theme_color_override("font_color", tint)
		if reason == "" and first_open == "":
			first_open = ACTIONS[i]
	_describe(first_open if first_open != "" else ACTIONS[0])


## The hovered tile's line and its limit under the pair. A closed tile says why in the limit's place.
func _describe(action: String) -> void:
	var run: AdventureRun = Session.run
	var reason: String = _action_block(action)
	if action == AdventureForge.ACTION_CUT:
		description_label.text = "Remove one card from your deck."
		constraint_label.text = "The deck can go no lower than %d cards." % AdventureForge.floor_size(run)
	else:
		description_label.text = "Add one more copy of a card already in your deck."
		constraint_label.text = "The deck can hold no more than %d cards." % AdventureForge.max_size(run)
	if reason != "":
		constraint_label.text = reason
	constraint_label.theme_type_variation = &"WarnLabel" if reason != "" else &"MutedLabel"
	constraint_label.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)


func _action_block(action: String) -> String:
	if action == AdventureForge.ACTION_CUT:
		return AdventureForge.cut_block(Session.run)
	return AdventureForge.copy_block(Session.run, Session.library)


func _on_leave() -> void:
	if _busy:
		return
	_busy = true
	if _dev:
		AdventureForge.leave(Session.run)
		print("forge: left without acting")
		return
	Session.leave_forge()


# --- Step two: the card -----------------------------------------------------------------------

func _open_pick(action: String) -> void:
	if _busy or _action_block(action) != "":
		return
	_action = action
	choice_step.visible = false
	pick_step.visible = true
	var cut: bool = action == AdventureForge.ACTION_CUT
	pick_title.text = "Cut a card" if cut else "Copy a card"
	act_button.text = "Cut it" if cut else "Copy it"
	grid_caption.text = "Right-click a card to inspect it." if cut \
		else "A greyed card cannot take another copy. Right-click a card to inspect it."
	await _fill_grid()
	_pick(-1)


func _fill_grid() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_rings.clear()
	_blocks.clear()
	_ids = _grid_order(Session.run.cards)
	for i in range(_ids.size()):
		var def: CardDef = Session.library.defs[_ids[i]]
		_blocks.append(_card_block(_ids[i]))
		grid.add_child(await _build_cell(def, i))


## Distinct ids grouped in DeckInfo's type order, each group sorted by title.
func _grid_order(cards: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for type: CardDef.Type in DeckInfo.TYPE_ORDER:
		var group: Array[String] = []
		for id in cards:
			var def: CardDef = Session.library.defs.get(id)
			if def != null and def.type == type and not group.has(id):
				group.append(id)
		group.sort_custom(func(a: String, b: String) -> bool:
			return (Session.library.defs[a] as CardDef).title < (Session.library.defs[b] as CardDef).title)
		out.append_array(group)
	return out


func _card_block(id: String) -> String:
	if _action == AdventureForge.ACTION_COPY:
		return AdventureForge.card_copy_block(Session.run, Session.library, id)
	return AdventureForge.cut_block(Session.run)


## One grid entry: the face in a ring that lights when picked, its copy count, and under it why it
## cannot be picked, if it cannot.
func _build_cell(def: CardDef, index: int) -> Control:
	var blocked: bool = _blocks[index] != ""
	var cell: VBoxContainer = VBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)
	var ring: PanelContainer = PanelContainer.new()
	ring.add_theme_stylebox_override("panel", _ring_style(false))
	cell.add_child(ring)
	_rings.append(ring)
	var wrap: Control = Control.new()
	wrap.custom_minimum_size = FACE_SIZE
	ring.add_child(wrap)
	var button: TextureButton = TextureButton.new()
	button.texture_normal = await faces.render_face(def)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.self_modulate = BLOCKED_TINT if blocked else Color.WHITE
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if blocked else Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: _pick(index))
	button.mouse_entered.connect(func() -> void: _show_preview(index))
	button.mouse_exited.connect(func() -> void: _show_preview(_picked))
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_inspect_click(event):
			_open_inspect(def))
	wrap.add_child(button)
	var badge: Label = Label.new()
	badge.text = "x%d" % Session.run.cards.count(def.id)
	badge.theme_type_variation = &"CaptionLabel"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ZenithTheme.chip(badge, ZenithTheme.TEXT_DISABLED if blocked else ZenithTheme.FRAME, true)
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	wrap.add_child(badge)
	var reason: Label = Label.new()
	reason.text = _blocks[index] if _action == AdventureForge.ACTION_COPY else ""
	reason.theme_type_variation = &"MutedLabel"
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.custom_minimum_size.x = FACE_SIZE.x + RING_PAD * 2
	reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(reason)
	return cell


func _ring_style(picked: bool) -> StyleBoxFlat:
	var edge: Color = ZenithTheme.ACCENT if picked else Color(0, 0, 0, 0)
	return ZenithTheme.box(Color(0, 0, 0, 0), edge, ZenithTheme.RADIUS, 2, RING_PAD, RING_PAD)


## Picks a grid entry, or clears the pick with -1. A blocked card is never picked.
func _pick(index: int) -> void:
	if index >= 0 and (index >= _ids.size() or _blocks[index] != ""):
		return
	_picked = index
	for i in range(_rings.size()):
		_rings[i].add_theme_stylebox_override("panel", _ring_style(i == _picked))
	act_button.disabled = _picked < 0 or _busy
	_show_preview(_picked)


## The large face and, in words, what the action would do with it. With `index` -1 the panel asks
## for a pick.
func _show_preview(index: int) -> void:
	preview_face.visible = index >= 0 and index < _ids.size()
	if not preview_face.visible:
		preview_face.texture = null
		preview_name.text = "Pick a card to cut" if _action == AdventureForge.ACTION_CUT else "Pick a card to copy"
		preview_change.text = ""
		preview_size.text = ""
		return
	var id: String = _ids[index]
	var def: CardDef = Session.library.defs[id]
	preview_name.text = def.title
	var reason: String = _blocks[index]
	var copies: int = Session.run.cards.count(id)
	var size: int = AdventureForge.deck_size(Session.run)
	if reason != "":
		preview_change.text = _block_sentence(reason)
		preview_change.add_theme_color_override("font_color", ZenithTheme.WARN)
		preview_size.text = ""
	elif _action == AdventureForge.ACTION_COPY:
		preview_change.text = "From %s to %d in your deck" % [_copies_text(copies), copies + 1]
		preview_change.add_theme_color_override("font_color", ZenithTheme.ENERGY)
		preview_size.text = "Deck grows from %d to %d cards" % [size, size + 1]
	else:
		preview_change.text = "From %s to %d in your deck" % [_copies_text(copies), copies - 1]
		preview_change.add_theme_color_override("font_color", ZenithTheme.WARN)
		preview_size.text = "Deck shrinks from %d to %d cards" % [size, size - 1]
	var tex: Texture2D = await faces.render_face(def)
	if preview_name.text == def.title:
		preview_face.texture = tex


static func _copies_text(count: int) -> String:
	return "1 copy" if count == 1 else "%d copies" % count


## The grid's short tag as a sentence for the preview.
func _block_sentence(tag: String) -> String:
	match tag:
		AdventureForge.BLOCK_PERSONALITY:
			return "A personality is never copied."
		AdventureForge.BLOCK_SEAL:
			return "A Seal is never copied."
		AdventureForge.BLOCK_LIMIT:
			return "This card is at its copy limit."
		AdventureForge.BLOCK_FULL:
			return "The deck is at %d cards, the most it can hold." % AdventureForge.max_size(Session.run)
	return tag


func _on_act() -> void:
	if _busy or _picked < 0:
		return
	var id: String = _ids[_picked]
	var cut: bool = _action == AdventureForge.ACTION_CUT
	_busy = true
	act_button.disabled = true
	var done: bool = false
	if _dev:
		done = AdventureForge.cut(Session.run, Session.library, id) if cut \
			else AdventureForge.copy(Session.run, Session.library, id)
		print("forge: %s %s %s" % [_action, id, "done" if done else "refused"])
		if done:
			_refresh_strip()
		return
	done = Session.forge_cut(id) if cut else Session.forge_copy(id)
	if not done:
		_busy = false
		act_button.disabled = false
		preview_change.text = "That card could not be %s." % ("cut" if cut else "copied")
		preview_change.add_theme_color_override("font_color", ZenithTheme.WARN)


# --- Inspect, the reward screen's own -------------------------------------------------------

func _open_inspect(def: CardDef) -> void:
	if def == null:
		return
	inspect_face.show_def(def)
	inspect.visible = true


func _hide_inspect() -> void:
	inspect.visible = false


func _is_inspect_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT


func _on_inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_hide_inspect()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if inspect.visible:
		_hide_inspect()
	elif pick_step.visible and not _busy:
		_show_choice()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Dev flags ----------------------------------------------------------------------------------

## Builds an unsaved run standing on a Forge when the scene is opened directly:
## `--dev-forge=<starter_id>` begins the run, `--dev-stage=N` wins N duels along the map's first
## choices first, and `--dev-forge-floor` cuts the deck to its floor so Cut is closed. The run is
## put on the first Forge ahead of it, or on the node it stands on when none is ahead.
func _dev_setup() -> void:
	if Session.run != null:
		return
	var starter_id: String = AdventureDev.flag("--dev-forge=")
	if starter_id == "" or not AdventureDev.begin_run(starter_id):
		return
	_dev = true
	var stage_arg: String = AdventureDev.flag("--dev-stage=")
	if stage_arg != "":
		AdventureDev.walk(maxi(0, int(stage_arg)))
	AdventureDev.stand_on_next("forge")
	var run: AdventureRun = Session.run
	if AdventureDev.has_flag("--dev-forge-floor"):
		while AdventureRewards.can_cut(run):
			if not AdventureRewards.apply_cut(run, Session.library, run.cards[0]):
				break


## `--dev-forge-hover=cut|copy` shows that tile's lines, `--dev-forge-step=cut|copy` opens step
## two for it, and `--dev-forge-pick=N` picks the Nth card of the grid.
func _dev_after_layout() -> void:
	var hover: String = AdventureDev.flag("--dev-forge-hover=")
	if hover in ACTIONS:
		_describe(hover)
	var step: String = AdventureDev.flag("--dev-forge-step=")
	if step in ACTIONS:
		await _open_pick(step)
		var pick_arg: String = AdventureDev.flag("--dev-forge-pick=")
		if pick_arg != "":
			_pick(int(pick_arg))
