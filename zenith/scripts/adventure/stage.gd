extends Control
## The hub between duels: the ladder, the next opponent, the run deck, and the run-over states.
## Opened by Session.go_to_adventure() whenever a run is live.

@onready var faces: CardFaceCache = $CardFaceCache
@onready var title_label: Label = $Margin/Column/TitleRow/Title
@onready var deck_name_label: Label = $Margin/Column/HeaderLine/DeckName
@onready var duelist_label: Label = $Margin/Column/HeaderLine/Duelist
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

## Extra labels grafted onto the reused DeckSheet, alongside its own School/Alignment/Archetype
## chips and identity column, so the sheet needs no edits of its own.
var _next_tier_chip: Label = null
var _next_caption: Label = null
var _next_story: Label = null


func _ready() -> void:
	theme = ZenithTheme.get_theme()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if Session.run == null:
		_dev_bootstrap(args)
		if Session.run == null:
			Session.go_to_adventure()
			return
	next_sheet.setup(1, faces)
	_graft_next_opponent_extras()
	view_deck_button.pressed.connect(_on_view_deck)
	duel_button.pressed.connect(_on_duel)
	abandon_button.pressed.connect(_on_abandon)
	title_button.pressed.connect(_on_title)
	new_run_button.pressed.connect(_on_new_run)
	_refresh()
	_enter()
	if args.has("--dev-deck"):
		_on_view_deck()
	_dev_screenshot()


## Only when the stage scene is opened directly with no run in memory: `--dev-adventure=<id>`
## builds an unsaved run, `--dev-stage=N` sets its stage, `--dev-status=lost|won` forces that state.
func _dev_bootstrap(args: PackedStringArray) -> void:
	var starter_id: String = ""
	for arg in args:
		if arg.begins_with("--dev-adventure="):
			starter_id = arg.get_slice("=", 1)
	if starter_id == "":
		return
	Session.run = AdventureRun.begin(starter_id, 12345)
	Session.ladder = AdventureLadder.load_for(starter_id)
	if Session.run == null or Session.ladder == null:
		Session.run = null
		Session.ladder = null
		return
	for arg in args:
		if arg.begins_with("--dev-stage="):
			# ladder.size() itself is valid: it is where a real win leaves run.stage.
			Session.run.stage = clampi(int(arg.get_slice("=", 1)), 0, Session.ladder.size())
		elif arg.begins_with("--dev-status="):
			Session.run.status = arg.get_slice("=", 1)


## Adds a tier chip into the sheet's own Chips row and a life/Aspects caption plus the hidden
## story slot right after it, so the extra facts sit with the identity block DeckSheet already
## draws instead of floating outside the card.
func _graft_next_opponent_extras() -> void:
	var chips: HFlowContainer = next_sheet.get_node("Column/Chips") as HFlowContainer
	_next_tier_chip = Label.new()
	chips.add_child(_next_tier_chip)

	var column: VBoxContainer = next_sheet.get_node("Column") as VBoxContainer
	var after: int = chips.get_index() + 1
	_next_caption = Label.new()
	_next_caption.theme_type_variation = &"MutedLabel"
	_next_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_next_caption)
	column.move_child(_next_caption, after)

	_next_story = Label.new()
	_next_story.visible = false
	_next_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_next_story)
	column.move_child(_next_story, after + 1)


func _refresh() -> void:
	var run: AdventureRun = Session.run
	var ladder: AdventureLadder = Session.ladder
	var deck: DeckList = run.deck()
	var duelist: CardDef = Session.library.defs.get(deck.duelist_id)

	title_label.text = "The ladder"
	deck_name_label.text = deck.name
	duelist_label.text = duelist.title if duelist != null else deck.duelist_id
	deck_size_label.text = "%d life cards" % deck.cards.size()
	aspects_label.text = "%d aspects" % deck.aspects

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
	var opp_duelist: CardDef = Session.library.defs.get(opp.duelist_id) if opp != null else null
	var cleared: bool = n < run.stage
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
		thumb.texture = CardFace.art_texture(opp_duelist, opp_duelist.lowest_aspect())
	h.add_child(thumb)

	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var title_l: Label = Label.new()
	title_l.text = opp_duelist.title if opp_duelist != null else opponent_id
	col.add_child(title_l)
	var deck_l: Label = Label.new()
	deck_l.text = opp.name if opp != null else ""
	deck_l.theme_type_variation = &"MutedLabel"
	deck_l.add_theme_font_size_override("font_size", 13)
	col.add_child(deck_l)

	var tier_l: Label = Label.new()
	tier_l.text = _tier_of(opponent_id)
	ZenithTheme.chip(tier_l, ZenithTheme.WARN if tier_l.text == "BOSS" else ZenithTheme.MUTED)
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
	var tier: String = _tier_of(opponent_id)
	_next_tier_chip.text = tier
	ZenithTheme.chip(_next_tier_chip, ZenithTheme.WARN if tier == "BOSS" else ZenithTheme.MUTED)
	_next_caption.text = "%d life cards   ·   %d aspects" % [opp.cards.size(), opp.aspects]
	var story: String = str(row_data.get("story", ""))
	_next_story.visible = story != ""
	_next_story.text = story


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


## The tier word an opponent deck id ends in: t1..t5 or boss.
static func _tier_of(opponent_id: String) -> String:
	var parts: PackedStringArray = opponent_id.split("_")
	return parts[parts.size() - 1].to_upper() if parts.size() > 0 else ""


## The ladder and next-opponent panels settle in, matching the versus screen's entrance; skipped
## under --reduced-motion.
func _enter() -> void:
	if OS.get_cmdline_user_args().has("--reduced-motion"):
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


func _dev_screenshot() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--dev-screenshot="):
			var path: String = arg.get_slice("=", 1)
			await get_tree().create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			print("screenshot saved to %s" % path)
			get_tree().quit()
