extends Control
## The card vendor, reached from the adventure start screen: a short shelf sold outright into the
## collection for Motes, and the collection itself, where a spare copy can be dissolved back into
## Motes. Every purchase goes through Session, which owns the wallet and the save.

const ZOOM_SIZE: Vector2 = Vector2(560, 784)
## Six panels across 1600 px with the header and footer intact.
const FACE_SIZE: Vector2 = Vector2(176, 246)

@onready var faces: CardFaceCache = $CardFaceCache
@onready var motes_tile: StatTile = $Margin/Column/TitleRow/Motes
@onready var reroll_button: Button = $Margin/Column/TitleRow/Reroll
@onready var shelf_tab: Button = $Margin/Column/Tabs/Shelf
@onready var collection_tab: Button = $Margin/Column/Tabs/Collection
@onready var shelf_page: VBoxContainer = $Margin/Column/Body/ShelfPage
@onready var shelf_caption: Label = $Margin/Column/Body/ShelfPage/Caption
@onready var shelf_row: HBoxContainer = $Margin/Column/Body/ShelfPage/Center/Row
@onready var shelf_empty: Label = $Margin/Column/Body/ShelfPage/Empty
@onready var collection_page: VBoxContainer = $Margin/Column/Body/CollectionPage
@onready var collection_list: RunDeckList = $Margin/Column/Body/CollectionPage/DeckList
@onready var dissolve_button: Button = $Margin/Column/Body/CollectionPage/Controls/Dissolve
@onready var back_button: Button = $Margin/Column/Footer/Back
@onready var status_label: Label = $Margin/Column/Footer/Status
@onready var inspect: ColorRect = $Inspect
@onready var inspect_face: CardFace = $Inspect/Center/Column/Face

var _stock: Array[String] = []
var _buy_buttons: Array[Button] = []
var _owned_labels: Array[Label] = []
var _selected_id: String = ""
var _dissolve_armed: bool = false
var _zoom: TextureRect = null
var _busy: bool = false


func _ready() -> void:
	theme = SanctumUI.theme()
	# The vendor sits outside any run, so its title carries no school edge.
	MapArt.tint_for_school("")
	SanctumUI.dress(self, $Margin/Column/TitleRow/Title as Label)
	var shelf_frame: PanelContainer = PanelContainer.new()
	shelf_row.get_parent().add_child(shelf_frame)
	shelf_row.reparent(shelf_frame)
	_dev_setup()
	var tabs: ButtonGroup = ButtonGroup.new()
	shelf_tab.button_group = tabs
	collection_tab.button_group = tabs
	shelf_tab.pressed.connect(func() -> void: _show_page(false))
	collection_tab.pressed.connect(func() -> void: _show_page(true))
	reroll_button.pressed.connect(_on_reroll)
	back_button.pressed.connect(_on_back)
	dissolve_button.pressed.connect(_on_dissolve)
	collection_list.card_selected.connect(_on_collection_selected)
	inspect.gui_input.connect(_on_inspect_input)
	inspect.visible = false
	status_label.text = Session.take_dissolve_report()
	reroll_button.text = "Reroll (%d)" % AdventureEconomy.vendor_reroll_fee()
	await _fill_shelf()
	_fill_collection()
	_refresh()
	_dev_after_layout()
	AdventureDev.screenshot(self)


func _show_page(collection: bool) -> void:
	shelf_page.visible = not collection
	collection_page.visible = collection
	status_label.text = ""


# --- The shelf -------------------------------------------------------------------

func _fill_shelf() -> void:
	for child in shelf_row.get_children():
		shelf_row.remove_child(child)
		child.queue_free()
	_buy_buttons.clear()
	_owned_labels.clear()
	_stock = Session.vendor_stock()
	shelf_empty.visible = _stock.is_empty()
	for id in _stock:
		var def: CardDef = Session.library.defs.get(id)
		if def == null:
			continue
		shelf_row.add_child(await _build_stall(def))
	shelf_caption.text = "%d cards on the shelf  ·  a run ends and the shelf rolls over" % _stock.size()


## One card on the shelf: its face, title, band chip, price, how many the collection holds of the
## most it ever will, and Buy.
func _build_stall(def: CardDef) -> Control:
	var tint: Color = Palette.card_ui(def)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ZenithTheme.edged(tint, ZenithTheme.RAISED, ZenithTheme.RADIUS, 12, 12))

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.custom_minimum_size.x = FACE_SIZE.x

	var tex: Texture2D = await faces.render_face(def)
	var button: TextureButton = TextureButton.new()
	button.texture_normal = tex
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.custom_minimum_size = FACE_SIZE
	button.mouse_entered.connect(func() -> void: _show_zoom(button))
	button.mouse_exited.connect(_hide_zoom)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_inspect_click(event):
			_open_inspect(def))
	column.add_child(button)

	var title: Label = Label.new()
	title.text = def.title
	title.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.x = FACE_SIZE.x
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	# One chip per line, so every stall's Buy sits at the same height.
	var band: Label = Label.new()
	band.text = AdventureEconomy.band(def).capitalize()
	band.theme_type_variation = &"CaptionLabel"
	band.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ZenithTheme.chip(band, tint)
	column.add_child(band)
	var price: Label = Label.new()
	price.text = "%d Motes" % AdventureEconomy.price(def)
	price.theme_type_variation = &"CaptionLabel"
	price.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ZenithTheme.chip(price, ZenithTheme.MOTES)
	column.add_child(price)

	var owned: Label = Label.new()
	owned.theme_type_variation = &"MutedLabel"
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned.custom_minimum_size.x = FACE_SIZE.x
	owned.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(owned)
	_owned_labels.append(owned)

	var buy: Button = Button.new()
	buy.custom_minimum_size = Vector2(FACE_SIZE.x, 48)
	buy.text = "Buy"
	buy.pressed.connect(func() -> void: _on_buy(def.id))
	column.add_child(buy)
	_buy_buttons.append(buy)

	panel.add_child(column)
	return panel


func _on_buy(id: String) -> void:
	if _busy:
		return
	status_label.text = ""
	if not Session.buy_card(id):
		status_label.text = "That card could not be bought."
		return
	# Buying slides the next card of the seeded shuffle onto the shelf, so the whole row is rebuilt.
	await _fill_shelf()
	_fill_collection()
	_refresh()


func _on_reroll() -> void:
	if _busy:
		return
	status_label.text = ""
	if not Session.reroll_vendor():
		status_label.text = "Not enough Motes to reroll the shelf."
		return
	await _fill_shelf()
	_refresh()


# --- The collection -----------------------------------------------------------------

## The collection as the shared grouped list: one entry per copy, so the rows carry their counts.
func _fill_collection() -> void:
	var expanded: Array[String] = []
	for id in Session.collection.all_ids():
		for _i in range(Session.collection.copies(id)):
			expanded.append(id)
	collection_list.set_caption("%d cards, %d copies" % [
		Session.collection.all_ids().size(), Session.collection.total_copies()])
	collection_list.show_cards(expanded, Session.library, faces)
	_selected_id = ""
	_disarm_dissolve()


func _on_collection_selected(id: String) -> void:
	_selected_id = id
	status_label.text = ""
	_disarm_dissolve()


## Two-step, the way the stage screen arms Abandon Run: the first press names the price, the
## second spends the copy.
func _on_dissolve() -> void:
	if _busy or _selected_id == "":
		return
	if not _dissolve_armed:
		_dissolve_armed = true
		dissolve_button.text = "Confirm dissolve"
		return
	var paid: int = Session.dissolve_card(_selected_id)
	if paid <= 0:
		status_label.text = "That copy could not be dissolved."
	_fill_collection()
	await _fill_shelf()
	_refresh()


func _disarm_dissolve() -> void:
	_dissolve_armed = false
	var def: CardDef = Session.library.defs.get(_selected_id)
	if def == null:
		dissolve_button.disabled = true
		dissolve_button.text = "Dissolve"
		return
	dissolve_button.disabled = false
	dissolve_button.text = "Dissolve %s (+%d)" % [def.title, AdventureEconomy.dissolve_value(def)]


# --- Shared state ---------------------------------------------------------------------

func _refresh() -> void:
	motes_tile.set_motes(Session.wallet.motes)
	var fee: int = AdventureEconomy.vendor_reroll_fee()
	reroll_button.disabled = not Session.wallet.can_afford(fee)
	reroll_button.tooltip_text = "" if not reroll_button.disabled else "%d Motes short." % (fee - Session.wallet.motes)
	for i in range(_stock.size()):
		if i >= _buy_buttons.size():
			break
		var def: CardDef = Session.library.defs.get(_stock[i])
		if def == null:
			continue
		var cap: int = AdventureCollection.cap(def.id, Session.library)
		var held: int = Session.collection.copies(def.id)
		_owned_labels[i].text = "Owned %d/%d%s" % [held, cap, "  ·  %d max" % cap if held >= cap else ""]
		var price: int = AdventureEconomy.price(def)
		var button: Button = _buy_buttons[i]
		if held >= cap:
			button.disabled = true
			button.text = "Owned"
			button.tooltip_text = "The collection already holds every copy it may: %d max." % cap
		elif not Session.wallet.can_afford(price):
			button.disabled = true
			button.text = "Buy"
			button.tooltip_text = "%d Motes short." % (price - Session.wallet.motes)
		else:
			button.disabled = false
			button.text = "Buy"
			button.tooltip_text = ""


func _on_back() -> void:
	Session.get_tree().change_scene_to_file(Session.ADVENTURE_START_SCENE)


# --- Hover zoom and inspect, the reward screen's own -----------------------------------

func _show_zoom(button: TextureButton) -> void:
	if inspect.visible:
		return
	if _zoom == null:
		_zoom = TextureRect.new()
		_zoom.top_level = true
		_zoom.z_index = 100
		_zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_zoom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_zoom.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_zoom.size = ZOOM_SIZE
		add_child(_zoom)
	_zoom.texture = button.texture_normal
	_zoom.visible = _zoom.texture != null
	var view: Vector2 = get_viewport_rect().size
	var origin: Vector2 = button.global_position
	var pos: Vector2 = Vector2(origin.x + button.size.x * 0.5 - ZOOM_SIZE.x * 0.5, origin.y - ZOOM_SIZE.y - 12.0)
	if pos.y < 8.0:
		pos.y = origin.y + button.size.y + 12.0
	pos.x = clampf(pos.x, 8.0, maxf(8.0, view.x - ZOOM_SIZE.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, view.y - ZOOM_SIZE.y - 8.0))
	_zoom.global_position = pos


func _hide_zoom() -> void:
	if _zoom != null:
		_zoom.visible = false


func _open_inspect(def: CardDef) -> void:
	if def == null:
		return
	_hide_zoom()
	inspect_face.show_def(def)
	inspect.visible = true


func _is_inspect_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT


func _on_inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		inspect.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if inspect.visible and event.is_action_pressed("ui_cancel"):
		inspect.visible = false
		get_viewport().set_input_as_handled()


# --- Dev flags ------------------------------------------------------------------------

## `--dev-vendor` opens the shelf against a scratch wallet of 500 Motes and a small in-memory
## collection, so nothing here reads or writes the player's save.
func _dev_setup() -> void:
	if not AdventureDev.args().has("--dev-vendor"):
		return
	AdventureDev.use_scratch_saves()
	AdventureDev.give_motes(500)
	var ids: Array[String] = []
	for id in AdventureVendor.pool(Session.library):
		if ids.size() >= 5:
			break
		ids.append(id)
	AdventureDev.stock_collection(ids, 1)


## `--dev-tab=collection` opens the collection tab and `--dev-buy=N` buys the Nth card on the
## shelf, so a shot can show the state after a click.
func _dev_after_layout() -> void:
	var buy_arg: String = AdventureDev.flag("--dev-buy=")
	if buy_arg != "":
		var index: int = int(buy_arg)
		if index >= 0 and index < _stock.size():
			await _on_buy(_stock[index])
	if AdventureDev.flag("--dev-tab=") == "collection":
		collection_tab.button_pressed = true
		_show_page(true)
