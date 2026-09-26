extends Control
## The hub between duels: the run's node map on the left, and on the right a side panel with the
## run's standing (deck, act, duels won, Motes) over a preview of the node being scouted. Opened by
## Session.go_to_adventure() whenever a run is live.

@onready var faces: CardFaceCache = $CardFaceCache
@onready var deck_name_label: Label = $Margin/Column/Body/Right/RunInfo/Row/Titles/DeckName
@onready var stage_status_label: Label = $Margin/Column/Body/Right/RunInfo/Row/Titles/StageStatus
@onready var mote_icon: TextureRect = $Margin/Column/Body/Right/RunInfo/Row/MotesBox/MoteIcon
@onready var motes_label: Label = $Margin/Column/Body/Right/RunInfo/Row/MotesBox/MotesValue
@onready var run_info: PanelContainer = $Margin/Column/Body/Right/RunInfo
@onready var ladder_column: VBoxContainer = $Margin/Column/Body/Ladder
@onready var ladder_scroll: ScrollContainer = $Margin/Column/Body/Ladder/Scroll
@onready var ladder_list: VBoxContainer = $Margin/Column/Body/Ladder/Scroll/List
@onready var right_column: VBoxContainer = $Margin/Column/Body/Right
@onready var next_sheet: DeckSheet = $Margin/Column/Body/Right/NextOpponent
@onready var run_over_panel: PanelContainer = $Margin/Column/Body/Right/RunOver
@onready var run_over_heading: Label = $Margin/Column/Body/Right/RunOver/Center/Column/Heading
@onready var run_over_reached: Label = $Margin/Column/Body/Right/RunOver/Center/Column/Reached
@onready var view_deck_button: Button = $Margin/Column/Footer/ViewDeck
@onready var duel_button: Button = $Margin/Column/Footer/Duel
@onready var abandon_button: Button = $Margin/Column/Footer/Abandon
@onready var new_run_button: Button = $Margin/Column/Footer/NewRun
@onready var title_button: Button = $Margin/Column/Footer/TitleButton
@onready var deck_panel: StageDeckPanel = $DeckPanel

var _abandon_armed: bool = false
var _route: MapRoute = null
## The scouted node's marker, over the note a non-fighting node shows.
var _node_icon: TextureRect = null
## A small warning line under that note, for what is not built yet.
var _dev_note: Label = null


func _ready() -> void:
	if Session.run == null:
		_dev_bootstrap()
		if Session.run == null:
			theme = SanctumUI.theme()
			Session.go_to_adventure()
			return
	# The run's school colour marks the map's walked road.
	var run_deck: DeckList = Session.run.deck()
	MapArt.tint_for_school(run_deck.style if run_deck != null else "")
	theme = SanctumUI.theme()
	next_sheet.setup(1, faces)
	next_sheet.portrait.custom_minimum_size = Vector2(314, 440)
	next_sheet.portrait_caption.custom_minimum_size.x = 314
	next_sheet.mastery.custom_minimum_size = Vector2(240, 336)
	next_sheet.mastery_caption.custom_minimum_size.x = 240
	# The map and the side panel's pieces are all framed panels. Pixel frames keep hard edges;
	# their contents stay smooth.
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", MapArt.panel_box(22))
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var at: int = ladder_scroll.get_index()
	ladder_column.add_child(frame)
	ladder_column.move_child(frame, at)
	# Inside the board: the legend inlaid down its left wall, a divider, then the scrolling map.
	var board_row: HBoxContainer = HBoxContainer.new()
	board_row.add_theme_constant_override("separation", 18)
	board_row.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.add_child(board_row)
	board_row.add_child(_legend())
	board_row.add_child(VSeparator.new())
	ladder_scroll.reparent(board_row)
	ladder_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The preview's tag rides the title banner, and dividers set the sheet's text off from its
	# cards. Only this screen's copy of the sheet is dressed; the matchup screen keeps its own.
	next_sheet.tag.add_theme_stylebox_override("normal", MapArt.banner_box("banner", 36, 12, 16))
	next_sheet.tag.add_theme_color_override("font_color", ZenithTheme.TEXT_DARK)
	next_sheet.tag.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
	next_sheet.tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_sheet.tag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var chip_rule: HSeparator = HSeparator.new()
	next_sheet.chips.get_parent().add_child(chip_rule)
	next_sheet.chips.get_parent().move_child(chip_rule, next_sheet.note_label.get_index())
	var sheet_rule: HSeparator = HSeparator.new()
	next_sheet.cards.get_parent().add_child(sheet_rule)
	next_sheet.cards.get_parent().move_child(sheet_rule, next_sheet.cards.get_index())
	# The placeholder panel fits its content instead of stretching down the side.
	run_over_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_frame(run_info, 28)
	_frame(run_over_panel, 30)
	_frame(next_sheet, 26)
	mote_icon.texture = MapArt.ui("mote")
	ZenithTheme.motes_label(motes_label)
	_node_icon = TextureRect.new()
	_node_icon.custom_minimum_size = Vector2(112, 112)
	_node_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_node_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var note_column: VBoxContainer = run_over_panel.get_node("Center/Column")
	note_column.add_child(_node_icon)
	note_column.move_child(_node_icon, 0)
	var crest: TextureRect = MapArt.ornament("crest_small", 22.0)
	note_column.add_child(crest)
	note_column.move_child(crest, run_over_heading.get_index())
	var note_rule: HSeparator = HSeparator.new()
	note_column.add_child(note_rule)
	note_column.move_child(note_rule, run_over_reached.get_index())
	_dev_note = Label.new()
	_dev_note.theme_type_variation = &"WarnLabel"
	_dev_note.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
	_dev_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_column.add_child(_dev_note)
	view_deck_button.pressed.connect(_on_view_deck)
	duel_button.pressed.connect(_on_duel)
	abandon_button.pressed.connect(_on_abandon)
	title_button.pressed.connect(_on_title)
	($Margin/Column/Footer/Journal as Button).pressed.connect(Session.go_to_journal)
	new_run_button.pressed.connect(_on_new_run)
	_refresh()
	_enter()
	if AdventureDev.args().has("--dev-deck"):
		_on_view_deck()
	AdventureDev.screenshot(self)
	SanctumUI.wire_buttons(self)


## The iron panel on one side-panel piece, with its first child kept smooth.
func _frame(panel: PanelContainer, content: int) -> void:
	panel.add_theme_stylebox_override("panel", MapArt.panel_box(content))
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if panel.get_child_count() > 0:
		(panel.get_child(0) as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## Only when the stage scene is opened directly with no run in memory: `--dev-adventure=<id>`
## builds an unsaved run, `--dev-stage=N` wins N duels along the first choices,
## `--dev-status=lost|won` forces that state.
func _dev_bootstrap() -> void:
	var starter_id: String = AdventureDev.flag("--dev-adventure=")
	if starter_id == "" or not AdventureDev.begin_run(starter_id):
		return
	var stage_arg: String = AdventureDev.flag("--dev-stage=")
	if stage_arg != "":
		AdventureDev.walk(maxi(0, int(stage_arg)))
	var status_arg: String = AdventureDev.flag("--dev-status=")
	if status_arg != "":
		Session.run.status = status_arg


func _refresh() -> void:
	var run: AdventureRun = Session.run
	var map: AdventureMap = Session.map
	var deck: DeckList = run.deck()
	deck_name_label.text = deck.name.trim_suffix(" (Starter)")
	motes_label.text = str(Session.wallet.motes)
	motes_label.tooltip_text = "Motes"
	mote_icon.tooltip_text = "Motes"
	match run.status:
		"won":
			stage_status_label.text = "Run complete"
		"lost":
			stage_status_label.text = "Run over"
		_:
			stage_status_label.text = "Act %d   ·   %d won" % [MapRoute.act_to_show(run, map), run.stage]

	_build_route(run, map)

	var live: bool = run.status == "map" or run.status == "stage"
	duel_button.visible = live
	abandon_button.visible = live
	new_run_button.visible = not live
	_abandon_armed = false
	abandon_button.text = "Abandon Run"
	# A finished run's map steps back behind the result.
	_route.modulate.a = 1.0 if live else 0.5
	if live:
		_show_node(_route.selected())
	else:
		next_sheet.visible = false
		run_over_panel.visible = true
		_show_run_over(run, map)


func _build_route(run: AdventureRun, map: AdventureMap) -> void:
	for child in ladder_list.get_children():
		child.queue_free()
	_route = MapRoute.new()
	ladder_list.add_child(_route)
	_route.setup(run, map)
	_scroll_to_focus.call_deferred()
	_route.node_selected.connect(func(id: String) -> void:
		var status: String = Session.run.status
		if status != "map" and status != "stage":
			return
		_show_node(id)
		SanctumUI.enter(next_sheet if next_sheet.visible else run_over_panel)
	)


## Brings the run's position into view, a little below the middle so the road ahead shows.
func _scroll_to_focus() -> void:
	await get_tree().process_frame
	if _route == null or not is_instance_valid(_route):
		return
	ladder_scroll.scroll_vertical = int(_route.focus_y() - ladder_scroll.size.y * 0.6)


## One marker and name per node type, stacked down the board's left wall, so the map reads without
## hovering.
func _legend() -> VBoxContainer:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for type in ["duel", "elite", "key", "boss", "relic", "shop", "shrine", "forge"]:
		var cell: HBoxContainer = HBoxContainer.new()
		cell.add_theme_constant_override("separation", 12)
		var icon: TextureRect = TextureRect.new()
		icon.texture = MapArt.marker(type)
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(icon)
		var name_label: Label = Label.new()
		name_label.text = AdventureMap.type_name(type)
		name_label.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(name_label)
		row.add_child(cell)
	return row


## Shows the node being scouted: the opponent's sheet for a fight, a short note for anything else.
## The duel button commits only a node the run may take: the fight it stands on, or a choice.
func _show_node(id: String) -> void:
	var run: AdventureRun = Session.run
	var map: AdventureMap = Session.map
	var type: String = str(map.node(id).get("type", ""))
	var duel: Dictionary = map.duel_for(id)
	var standing: bool = run.status == "stage" and id == run.node_id
	var choice: bool = run.choices(map).has(id)
	next_sheet.visible = not duel.is_empty()
	run_over_panel.visible = duel.is_empty()
	if duel.is_empty():
		_node_icon.texture = MapArt.marker(type)
		_node_icon.visible = _node_icon.texture != null
		run_over_heading.text = AdventureMap.type_name(type) if type != "" else "The road ahead"
		run_over_reached.text = AdventureMap.type_blurb(type)
		_dev_note.text = "Not built yet: passing through does nothing."
		_dev_note.visible = type != ""
	else:
		_show_next_opponent(duel)
		var tag: String = "NEXT CHALLENGER" if standing else ("%s  /  CHOOSE" if choice else "%s  /  SCOUTING") % AdventureMap.type_name(type).to_upper()
		next_sheet.tag.text = tag
	duel_button.disabled = not (standing or choice)
	if standing or (choice and not duel.is_empty()):
		duel_button.text = "Enter the arena"
	elif choice:
		duel_button.text = "Go here"
	else:
		duel_button.text = "Choose a lit node"


func _show_next_opponent(row_data: Dictionary) -> void:
	var opponent_id: String = str(row_data.get("opponent", ""))
	var opp: DeckList = DeckList.resolve(opponent_id)
	if opp == null:
		return
	next_sheet.show_deck(opp, "NEXT CHALLENGER")
	# show_deck sets its own panel every call; the stage screen frames it like the rest.
	next_sheet.add_theme_stylebox_override("panel", MapArt.panel_box(26))
	var tier: String = AdventureDecks.tier_of(opponent_id)
	var boss: bool = str(row_data.get("node", "")) == "boss"
	next_sheet.clear_extra_chips()
	next_sheet.add_chip("BOSS" if boss else tier, _tier_color(boss))
	var lives: int = AdventureRules.lives_for(row_data)[1]
	next_sheet.set_note("%d life cards   ·   %d aspects   ·   %s" % [opp.cards.size(), opp.aspects, _lives_text(lives)])
	next_sheet.set_story(str(row_data.get("story", "")))


func _show_run_over(run: AdventureRun, map: AdventureMap) -> void:
	_dev_note.visible = false
	_node_icon.texture = MapArt.marker("boss")
	_node_icon.visible = _node_icon.texture != null
	if run.status == "won":
		run_over_heading.text = "Tournament conquered"
		run_over_reached.text = "Cleared all %d acts." % map.acts
	else:
		run_over_heading.text = "Your ascent ends here"
		run_over_reached.text = "Fell at %s." % map.place_of(run.node_id)


func _on_duel() -> void:
	if Session.run.status == "stage":
		Session.begin_stage()
	else:
		Session.enter_node(_route.selected())


## Two-step: the first press only arms the button, the second commits.
func _on_abandon() -> void:
	if not _abandon_armed:
		_abandon_armed = true
		abandon_button.text = "Confirm abandon"
		return
	Session.abandon_run()
	Session.go_to_adventure()   # with no run left, this is the character select


func _on_title() -> void:
	Session.leave_adventure()
	Session.go_to_title()


func _on_new_run() -> void:
	Session.abandon_run()
	Session.go_to_adventure()


func _on_view_deck() -> void:
	deck_panel.open(Session.run.deck(), DeckInfo.might_max_of(Session.decks), faces)


## "2 lives" for a boss, "1 life" for anyone else; the player always has two.
static func _lives_text(lives: int) -> String:
	return "%d %s (you have %d)" % [lives, "life" if lives == 1 else "lives", AdventureRules.PLAYER_LIVES]


## A boss is called out in the warning colour; every other tier is a quiet chip.
static func _tier_color(boss: bool) -> Color:
	return ZenithTheme.WARN if boss else ZenithTheme.MUTED


## The map and the side panel settle in, matching the versus screen's entrance; skipped under
## --reduced-motion.
func _enter() -> void:
	if AdventureDev.reduced_motion():
		return
	var panels: Array[Control] = [ladder_column, right_column]
	for panel in panels:
		panel.modulate.a = 0.0
	await get_tree().process_frame
	if not is_inside_tree():
		return
	for i in range(panels.size()):
		var panel: Control = panels[i]
		var dy: float = 18.0
		panel.position.y += dy
		var t: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(panel, "position:y", panel.position.y - dy, 0.3).set_delay(i * 0.05)
		t.tween_property(panel, "modulate:a", 1.0, 0.3).set_delay(i * 0.05)
