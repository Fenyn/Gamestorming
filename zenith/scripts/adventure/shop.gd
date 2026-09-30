extends Control
## The Shop node's screen: the stock laid out on a cloth over the counter, each card hanging its
## Mana price on a tag. One click buys, and the Shop stays open until the player leaves. The rules
## live in AdventureShop; buying and saving go through Session.

const SLOT_SCENE: PackedScene = preload("res://scenes/adventure/shop_slot.tscn")

@onready var faces: CardFaceCache = $CardFaceCache
@onready var strip: PanelContainer = $Strip
@onready var run_name_label: Label = $Strip/Row/RunName
@onready var standing_label: Label = $Strip/Row/Standing
@onready var mana_icon: TextureRect = $Strip/Row/ManaBox/ManaIcon
@onready var mana_label: Label = $Strip/Row/ManaBox/ManaValue
@onready var mote_icon: TextureRect = $Strip/Row/MotesBox/MoteIcon
@onready var motes_label: Label = $Strip/Row/MotesBox/MotesValue
@onready var title: Label = $Title
@onready var slot_row: HBoxContainer = $Slots
@onready var leave_button: Button = $Leave
@onready var inspect: ColorRect = $Inspect
@onready var inspect_face: CardFace = $Inspect/Center/Column/Face

var _slots: Array[ShopSlot] = []
var _ids: Array[String] = []
var _dev: bool = false
var _busy: bool = false


func _ready() -> void:
	theme = SanctumUI.theme()
	_dev_setup()
	if Session.run == null or not AdventureShop.is_open(Session.run):
		Session.go_to_adventure()
		return
	AdventureShop.open(Session.run, Session.library)
	var run_deck: DeckList = Session.run.deck()
	MapArt.tint_for_school(run_deck.style if run_deck != null else "")
	SanctumUI.dress(self, title)
	var strip_box: StyleBoxFlat = ZenithTheme.box(ZenithTheme.BG, ZenithTheme.BORDER, 0, 0, ZenithTheme.GAP_L, ZenithTheme.GAP_XS)
	strip_box.border_width_bottom = 1
	strip.add_theme_stylebox_override("panel", strip_box)
	mana_icon.texture = MapArt.ui("mana")
	mote_icon.texture = MapArt.ui("mote")
	ZenithTheme.mana_label(mana_label)
	ZenithTheme.motes_label(motes_label)
	leave_button.pressed.connect(_on_leave)
	inspect.gui_input.connect(_on_inspect_input)
	inspect.visible = false
	_build_slots()
	_busy = true
	await _refresh()
	_busy = false
	SanctumUI.wire_buttons(self)
	await _dev_after_layout()
	AdventureDev.screenshot(self)


func _build_slots() -> void:
	for child in slot_row.get_children():
		slot_row.remove_child(child)
		child.queue_free()
	_slots.clear()
	_ids = AdventureShop.stock(Session.run)
	for i in range(_ids.size()):
		var slot: ShopSlot = SLOT_SCENE.instantiate() as ShopSlot
		slot_row.add_child(slot)
		slot.set_index(i)
		var index: int = i
		slot.pressed.connect(func() -> void: _on_buy(index))
		slot.hovered.connect(func(over: bool) -> void: _on_hover(index, over))
		slot.inspected.connect(func() -> void: _open_inspect(index))
		_slots.append(slot)


func _refresh() -> void:
	var run: AdventureRun = Session.run
	var deck: DeckList = run.deck()
	run_name_label.text = deck.name.trim_suffix(" (Starter)") if deck != null else ""
	standing_label.text = "Act %d   ·   %d won   ·   %d cards" % [
		MapRoute.act_to_show(run, Session.map), run.stage, AdventureForge.deck_size(run)]
	mana_label.text = str(run.mana)
	motes_label.text = str(Session.wallet.motes)
	for i in range(_slots.size()):
		await _refresh_slot(i)


func _refresh_slot(index: int) -> void:
	var run: AdventureRun = Session.run
	var slot: ShopSlot = _slots[index]
	if AdventureShop.is_sold(run, index):
		slot.show_sold()
		return
	var def: CardDef = Session.library.defs.get(_ids[index])
	if def == null:
		slot.show_sold()
		return
	var price: int = AdventureShop.price(Session.library, def.id)
	var reason: String = _block_sentence(AdventureShop.slot_block(run, Session.library, index), price)
	slot.show_card(await faces.render_face(def), price, run.mana < price, reason)


## The short tag from AdventureShop as the sentence a blocked card shows on hover.
func _block_sentence(tag: String, price: int) -> String:
	match tag:
		"":
			return ""
		AdventureShop.BLOCK_MANA:
			return "%d Mana short." % (price - Session.run.mana)
		AdventureShop.BLOCK_LIMIT:
			return "Your deck already holds as many copies as this card allows."
		AdventureShop.BLOCK_FULL:
			return "The deck is at %d cards, the most it can hold." % AdventureForge.max_size(Session.run)
		AdventureShop.BLOCK_ILLEGAL:
			return "This card no longer fits your deck."
	return tag


func _on_buy(index: int) -> void:
	if _busy or inspect.visible or AdventureShop.slot_block(Session.run, Session.library, index) != "":
		return
	_busy = true
	var id: String = _ids[index]
	var done: bool = false
	if _dev:
		done = AdventureShop.buy(Session.run, Session.library, index)
		print("shop: buy %s %s, %d Mana left" % [id, "done" if done else "refused", Session.run.mana])
	else:
		done = Session.shop_buy(index)
	if done:
		await _refresh()
	_busy = false


func _on_leave() -> void:
	if _busy:
		return
	_busy = true
	if _dev:
		AdventureShop.leave(Session.run)
		print("shop: left with %d Mana" % Session.run.mana)
		return
	Session.leave_shop()


# --- Hover and inspect --------------------------------------------------------------------------

func _on_hover(index: int, over: bool) -> void:
	if inspect.visible or index >= _slots.size():
		return
	if AdventureShop.is_sold(Session.run, index):
		return
	_slots[index].lift(over, AdventureDev.reduced_motion())


func _open_inspect(index: int) -> void:
	var def: CardDef = Session.library.defs.get(_ids[index])
	if def == null:
		return
	_slots[index].lift(false, true)
	inspect_face.show_def(def)
	inspect.visible = true


func _hide_inspect() -> void:
	inspect.visible = false


func _on_inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_hide_inspect()


func _unhandled_input(event: InputEvent) -> void:
	if inspect.visible and event.is_action_pressed("ui_cancel"):
		_hide_inspect()
		get_viewport().set_input_as_handled()


# --- Dev flags ----------------------------------------------------------------------------------

## Builds an unsaved run standing in a Shop when the scene is opened directly: `--dev-shop=<starter>`
## begins the run, `--dev-stage=N` wins N duels along the map's first choices first (earning their
## Mana), and `--dev-shop-mana=N` sets the Mana outright. The run is put on the first Shop ahead of
## it, or on the node it stands on when none is ahead.
func _dev_setup() -> void:
	if Session.run != null:
		return
	var starter_id: String = AdventureDev.flag("--dev-shop=")
	if starter_id == "" or not AdventureDev.begin_run(starter_id):
		return
	_dev = true
	var stage_arg: String = AdventureDev.flag("--dev-stage=")
	if stage_arg != "":
		AdventureDev.walk(maxi(0, int(stage_arg)))
	AdventureDev.stand_on_next("shop")
	var mana_arg: String = AdventureDev.flag("--dev-shop-mana=")
	if mana_arg != "":
		Session.run.mana = maxi(0, int(mana_arg))


## `--dev-shop-buy=N` buys the Nth slot, and `--dev-shop-hover=N` hovers the Nth card.
func _dev_after_layout() -> void:
	var buy_arg: String = AdventureDev.flag("--dev-shop-buy=")
	if buy_arg != "":
		await _on_buy(int(buy_arg))
	var hover_arg: String = AdventureDev.flag("--dev-shop-hover=")
	if hover_arg != "":
		await get_tree().process_frame
		_on_hover(int(hover_arg), true)
