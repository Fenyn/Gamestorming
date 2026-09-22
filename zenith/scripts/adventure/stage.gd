extends Control
## The hub between duels: the ladder, the next opponent, the run deck, and the run-over states.
## Opened by Session.go_to_adventure() whenever a run is live.

@onready var faces: CardFaceCache = $CardFaceCache
@onready var deck_name_label: Label = $Margin/Column/HeaderLine/DeckName
@onready var duelist_label: Label = $Margin/Column/HeaderLine/Duelist
@onready var motes_tile: StatTile = $Margin/Column/HeaderLine/Motes
@onready var stage_status_label: Label = $Margin/Column/HeaderLine/StageStatus
@onready var deck_size_label: Label = $Margin/Column/SubHeader/DeckSize
@onready var aspects_label: Label = $Margin/Column/SubHeader/Aspects
@onready var ladder_column: VBoxContainer = $Margin/Column/Body/Ladder
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


func _ready() -> void:
	theme = SanctumUI.theme()
	if Session.run == null:
		_dev_bootstrap()
		if Session.run == null:
			Session.go_to_adventure()
			return
	next_sheet.setup(1, faces)
	# Keep room for the tournament header and footer around the card preview.
	next_sheet.portrait.custom_minimum_size = Vector2(314, 440)
	next_sheet.portrait_caption.custom_minimum_size.x = 314
	next_sheet.mastery.custom_minimum_size = Vector2(240, 336)
	next_sheet.mastery_caption.custom_minimum_size.x = 240
	view_deck_button.pressed.connect(_on_view_deck)
	duel_button.pressed.connect(_on_duel)
	abandon_button.pressed.connect(_on_abandon)
	title_button.pressed.connect(_on_title)
	new_run_button.pressed.connect(_on_new_run)
	_refresh()
	_enter()
	if AdventureDev.args().has("--dev-deck"):
		_on_view_deck()
	AdventureDev.screenshot(self)
	SanctumUI.wire_buttons(self)


## Only when the stage scene is opened directly with no run in memory: `--dev-adventure=<id>`
## builds an unsaved run, `--dev-stage=N` sets its stage, `--dev-status=lost|won` forces that state.
func _dev_bootstrap() -> void:
	var starter_id: String = AdventureDev.flag("--dev-adventure=")
	if starter_id == "" or not AdventureDev.begin_run(starter_id):
		return
	var stage_arg: String = AdventureDev.flag("--dev-stage=")
	if stage_arg != "":
		# ladder.size() itself is valid: it is where a real win leaves run.stage.
		Session.run.stage = clampi(int(stage_arg), 0, Session.ladder.size())
	var status_arg: String = AdventureDev.flag("--dev-status=")
	if status_arg != "":
		Session.run.status = status_arg


func _refresh() -> void:
	var run: AdventureRun = Session.run
	var ladder: AdventureLadder = Session.ladder
	var deck: DeckList = run.deck()
	var duelist: CardDef = Session.library.defs.get(deck.duelist_face_id())
	$Background.set_school(Palette.school_ui(deck.style), true)

	deck_name_label.text = deck.name
	duelist_label.text = duelist.title if duelist != null else deck.duelist_face_id()
	motes_tile.set_stat("Motes", str(Session.wallet.motes), "", ZenithTheme.ACCENT)
	deck_size_label.text = "%d life cards" % deck.cards.size()
	# The run's own Duelist, rung by rung, rather than a bare count. The opponents' sheets below
	# keep the count, since the run does not get to read the other side's stack.
	var rungs: String = ",  ".join(CardText.stack_rungs(deck.duelist_stack(Session.library)))
	aspects_label.text = rungs if rungs != "" else "%d aspects" % deck.aspects

	match run.status:
		"won":
			stage_status_label.text = "RUN COMPLETE"
		"lost":
			stage_status_label.text = "RUN OVER"
		_:
			stage_status_label.text = "STAGE %d OF %d" % [run.stage + 1, ladder.size()]

	_build_ladder(run, ladder)

	var live: bool = run.status == "stage"
	next_sheet.visible = live
	run_over_panel.visible = not live
	if live:
		_show_next_opponent(ladder.stage(run.stage))
	else:
		_show_run_over(run, ladder)

	duel_button.visible = live
	abandon_button.visible = live
	new_run_button.visible = not live
	_abandon_armed = false
	abandon_button.text = "Abandon Run"


func _build_ladder(run: AdventureRun, ladder: AdventureLadder) -> void:
	for child in ladder_list.get_children():
		child.queue_free()
	var route: TournamentRoute = TournamentRoute.new()
	ladder_list.add_child(route)
	route.setup(run, ladder)
	route.stage_selected.connect(func(index: int) -> void:
		if Session.run.status != "stage":
			return
		_show_next_opponent(Session.ladder.stage(index))
		next_sheet.tag.text = "NEXT CHALLENGER" if index == Session.run.stage else "ROUND %02d  /  SCOUTING" % (index + 1)
		duel_button.disabled = index != Session.run.stage
		duel_button.text = "Enter the arena" if index == Session.run.stage else "Select the current round to duel"
		SanctumUI.enter(next_sheet)
	)


func _show_next_opponent(row_data: Dictionary) -> void:
	var opponent_id: String = str(row_data.get("opponent", ""))
	var opp: DeckList = DeckList.resolve(opponent_id)
	if opp == null:
		return
	next_sheet.show_deck(opp, "NEXT CHALLENGER")
	$Background.set_rival(Palette.school_ui(opp.style))
	var tier: String = AdventureLadder.tier_of(opponent_id)
	next_sheet.clear_extra_chips()
	next_sheet.add_chip(tier, _tier_color(tier))
	next_sheet.set_note("%d life cards   ·   %d aspects" % [opp.cards.size(), opp.aspects])
	next_sheet.set_story(str(row_data.get("story", "")))


func _show_run_over(run: AdventureRun, ladder: AdventureLadder) -> void:
	if run.status == "won":
		run_over_heading.text = "Tournament conquered"
		run_over_reached.text = "Cleared all %d stages." % ladder.size()
	else:
		run_over_heading.text = "Your ascent ends here"
		run_over_reached.text = "Fell at stage %d of %d." % [mini(run.stage + 1, ladder.size()), ladder.size()]


func _on_duel() -> void:
	Session.begin_stage()


## Two-step: the first press only arms the button, the second commits.
func _on_abandon() -> void:
	if not _abandon_armed:
		_abandon_armed = true
		abandon_button.text = "Confirm abandon"
		return
	Session.abandon_run()
	Session.go_to_title()


func _on_title() -> void:
	Session.leave_adventure()
	Session.go_to_title()


func _on_new_run() -> void:
	Session.abandon_run()
	Session.go_to_adventure()


func _on_view_deck() -> void:
	deck_panel.open(Session.run.deck(), DeckInfo.might_max_of(Session.decks), faces)


## A boss tier is called out in orange; every other tier is a quiet chip.
static func _tier_color(tier: String) -> Color:
	return ZenithTheme.WARN if tier == "BOSS" else ZenithTheme.MUTED


## The ladder and next-opponent panels settle in, matching the versus screen's entrance; skipped
## under --reduced-motion.
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
