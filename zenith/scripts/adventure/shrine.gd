extends Control
## The Shrine's screen: the Resonances the run holds on the left with "Leave the Shrine", and three
## offers. One click takes an offer and returns to the map. The same screen is the claim after a won
## Elite, titled "Claim a Resonance" with "Take nothing" to leave. The rules live in AdventureShrine;
## taking, leaving and saving go through Session.

const CLAIM_TITLE: String = "Claim a Resonance"
const CLAIM_SUBTITLE: String = "You beat an Elite. Take one Resonance, and it stays with you for the rest of the run."
const CLAIM_LEAVE: String = "Take nothing"

const ROW_SCENE: PackedScene = preload("res://scenes/adventure/resonance_row.tscn")

@onready var strip: PanelContainer = $Strip
@onready var run_name_label: Label = $Strip/Row/RunName
@onready var standing_label: Label = $Strip/Row/Standing
@onready var mana_icon: TextureRect = $Strip/Row/ManaBox/ManaIcon
@onready var mana_label: Label = $Strip/Row/ManaBox/ManaValue
@onready var mote_icon: TextureRect = $Strip/Row/MotesBox/MoteIcon
@onready var motes_label: Label = $Strip/Row/MotesBox/MotesValue
@onready var title: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var held_panel: PanelContainer = $Row/Held
@onready var held_list: VBoxContainer = $Row/Held/Column/Scroll/List
@onready var empty_note: Label = $Row/Held/Column/Scroll/List/Empty
@onready var leave_button: Button = $Row/Held/Column/Leave
@onready var offers: Array[ShrineOffer] = [$Row/Offer0, $Row/Offer1, $Row/Offer2]

var _dev: bool = false
var _busy: bool = false


func _ready() -> void:
	theme = SanctumUI.theme()
	_dev_setup()
	if Session.run == null or not AdventureShrine.is_open(Session.run):
		Session.go_to_adventure()
		return
	_dev = _dev or AdventureDev.in_memory
	AdventureShrine.open(Session.run)
	if AdventureShrine.is_claim(Session.run):
		title.text = CLAIM_TITLE
		subtitle.text = CLAIM_SUBTITLE
		leave_button.text = CLAIM_LEAVE
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
	held_panel.add_theme_stylebox_override("panel", MapArt.panel_box(22))
	held_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	(held_panel.get_child(0) as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	(held_panel.get_node("Column/Heading") as Label).add_theme_font_override("font", ZenithTheme.TITLE_FONT)
	leave_button.pressed.connect(_on_leave)
	for i in range(offers.size()):
		var index: int = i
		offers[i].pressed.connect(func() -> void: _on_take(index))
		offers[i].hovered.connect(func(over: bool) -> void: _on_hover(index, over))
	_refresh()
	SanctumUI.wire_buttons(self)
	await _dev_after_layout()
	AdventureDev.screenshot(self)


func _refresh() -> void:
	var run: AdventureRun = Session.run
	var deck: DeckList = run.deck()
	run_name_label.text = deck.name.trim_suffix(" (Starter)") if deck != null else ""
	standing_label.text = "Act %d   ·   %d won   ·   %d cards" % [
		MapRoute.act_to_show(run, Session.map), run.stage, AdventureForge.deck_size(run)]
	mana_label.text = str(run.mana)
	motes_label.text = str(Session.wallet.motes)
	for child in held_list.get_children():
		if child != empty_note:
			held_list.remove_child(child)
			child.queue_free()
	empty_note.visible = run.resonances.is_empty()
	for id in run.resonances:
		var row: HBoxContainer = ROW_SCENE.instantiate() as HBoxContainer
		held_list.add_child(row)
		(row.get_node("Sigil") as ResonanceSigil).resonance = id
		var name_label: Label = row.get_node("Name") as Label
		name_label.text = ResonanceData.name_of(id)
		name_label.add_theme_color_override("font_color", ZenithTheme.TEXT)
	for i in range(offers.size()):
		offers[i].visible = i < run.shrine_offers.size()
		if offers[i].visible:
			var id: String = run.shrine_offers[i]
			offers[i].show_offer(id, AdventureShrine.chip_tag(run, id))


func _on_take(index: int) -> void:
	if _busy or index >= Session.run.shrine_offers.size():
		return
	_busy = true
	if _dev:
		var id: String = Session.run.shrine_offers[index]
		var done: bool = AdventureShrine.take(Session.run, index)
		print("shrine: take %d (%s) %s, status %s" % [index, id, "done" if done else "refused", Session.run.status])
		return
	if not Session.shrine_take(index):
		_busy = false


func _on_leave() -> void:
	if _busy:
		return
	_busy = true
	if _dev:
		AdventureShrine.leave(Session.run)
		print("shrine: leave, status %s" % Session.run.status)
		return
	Session.leave_shrine()


func _on_hover(index: int, over: bool) -> void:
	offers[index].lift(over, AdventureDev.reduced_motion())


# --- Dev flags ----------------------------------------------------------------------------------

## Builds an unsaved run standing on a Shrine when the scene is opened directly:
## `--dev-shrine=<starter>` begins the run, `--dev-stage=N` wins N duels first, and
## `--dev-shrine-held=<ids>` hands it those Resonances (comma-separated) before the offers roll.
## `--dev-claim=<starter>` instead wins the next Elite and stands on its claim.
func _dev_setup() -> void:
	if Session.run != null:
		return
	var claim_id: String = AdventureDev.flag("--dev-claim=")
	var starter_id: String = claim_id if claim_id != "" else AdventureDev.flag("--dev-shrine=")
	if starter_id == "" or not AdventureDev.begin_run(starter_id):
		return
	_dev = true
	var stage_arg: String = AdventureDev.flag("--dev-stage=")
	if stage_arg != "":
		AdventureDev.walk(maxi(0, int(stage_arg)))
	if claim_id != "":
		AdventureDev.claim_next_elite()
	else:
		AdventureDev.stand_on_next(AdventureShrine.STATUS)
	var run: AdventureRun = Session.run
	run.shrine_offers.clear()
	for id in AdventureDev.flag("--dev-shrine-held=").split(",", false):
		if ResonanceData.has(id) and not run.resonances.has(id):
			run.resonances.append(id)


## `--dev-shrine-hover=N` hovers the Nth offer and `--dev-shrine-take=N` takes it.
func _dev_after_layout() -> void:
	var hover_arg: String = AdventureDev.flag("--dev-shrine-hover=")
	if hover_arg != "":
		await get_tree().process_frame
		_on_hover(int(hover_arg), true)
	var take_arg: String = AdventureDev.flag("--dev-shrine-take=")
	if take_arg != "":
		_on_take(int(take_arg))
		_refresh()
