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
	theme = ZenithTheme.get_theme()
	if Session.run == null:
		_dev_bootstrap()
		if Session.run == null:
			Session.go_to_adventure()
			return
	next_sheet.setup(1, faces)
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
	for n in range(ladder.size()):
		ladder_list.add_child(_ladder_row(n, ladder.stage(n), run))


## One ladder row: stage number, opponent portrait, title, deck name, tier, and an Aspect marker
## when the stage grants one. Cleared rows carry a chip, the current stage is edge-lit, later
## stages are dimmed but stay on screen.
func _ladder_row(n: int, row_data: Dictionary, run: AdventureRun) -> PanelContainer:
	var opponent_id: String = str(row_data.get("opponent", ""))
	var opp: DeckList = DeckList.resolve(opponent_id)
	var opp_duelist: CardDef = Session.library.defs.get(opp.duelist_face_id()) if opp != null else null
	var cleared: bool = n < run.stage
	var tier: String = AdventureLadder.tier_of(opponent_id)
	var current: bool = n == run.stage and run.status != "won"
	var tint: Color = Palette.school_ui(opp.style) if opp != null else ZenithTheme.MUTED

	var row: PanelContainer = PanelContainer.new()
	var edge: Color = ZenithTheme.ACCENT if current else Color(tint, 0.35)
	var bg: Color = ZenithTheme.BG_ACTIVE if current else ZenithTheme.RAISED
	row.add_theme_stylebox_override("panel", ZenithTheme.edged(edge, bg, 10, 12, 8))
	row.modulate = Color(1, 1, 1, 1.0) if (cleared or current) else Color(1, 1, 1, 0.55)

	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)

	var num: Label = Label.new()
	num.text = str(n + 1)
	num.custom_minimum_size = Vector2(26, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(num)

	var thumb: TextureRect = TextureRect.new()
	thumb.custom_minimum_size = Vector2(48, 64)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if opp_duelist != null:
		thumb.texture = CardFace.art_texture(opp_duelist, opp_duelist.aspect)
	h.add_child(thumb)

	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var title_l: Label = Label.new()
	title_l.text = AdventureLadder.opponent_name(opponent_id, Session.library)
	col.add_child(title_l)
	var deck_l: Label = Label.new()
	deck_l.text = opp.name if opp != null else ""
	deck_l.theme_type_variation = &"MutedLabel"
	deck_l.add_theme_font_size_override("font_size", 13)
	col.add_child(deck_l)

	var tier_l: Label = Label.new()
	tier_l.text = tier
	ZenithTheme.chip(tier_l, _tier_color(tier))
	h.add_child(tier_l)

	if str(row_data.get("grant", "")) == "aspect":
		var mark: Label = Label.new()
		mark.text = "ASPECT"
		ZenithTheme.chip(mark, ZenithTheme.ACCENT)
		h.add_child(mark)

	if cleared:
		var cleared_l: Label = Label.new()
		cleared_l.text = "CLEARED"
		ZenithTheme.chip(cleared_l, ZenithTheme.MUTED)
		h.add_child(cleared_l)

	return row


func _show_next_opponent(row_data: Dictionary) -> void:
	var opponent_id: String = str(row_data.get("opponent", ""))
	var opp: DeckList = DeckList.resolve(opponent_id)
	if opp == null:
		return
	next_sheet.show_deck(opp, "NEXT OPPONENT")
	var tier: String = AdventureLadder.tier_of(opponent_id)
	next_sheet.clear_extra_chips()
	next_sheet.add_chip(tier, _tier_color(tier))
	next_sheet.set_note("%d life cards   ·   %d aspects" % [opp.cards.size(), opp.aspects])
	next_sheet.set_story(str(row_data.get("story", "")))


func _show_run_over(run: AdventureRun, ladder: AdventureLadder) -> void:
	if run.status == "won":
		run_over_heading.text = "Run complete"
		run_over_reached.text = "Cleared all %d stages." % ladder.size()
	else:
		run_over_heading.text = "Run over"
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
