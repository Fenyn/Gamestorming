class_name DuelHud
extends CanvasLayer

const PLAYER_STATUS: Script = preload("res://scripts/duel/player_status.gd")
## 2D layer over the table: phase strip, log, prompt and overlays. Everything
## it shows comes from a SeatView and a PromptView, never from the engine.

signal reduced_motion_changed(on: bool)
signal option_chosen(opt: OptionView)
signal card_clicked(uid: int)
signal card_hovered(uid: int, over: bool)
signal dev_command(effect: Dictionary)
signal handoff_confirmed
signal rematch_requested
signal select_requested
signal title_requested
signal concede_requested
signal leave_requested
signal give_up_requested
## Ranked between games: this player is ready for the next game.
signal next_game_requested
## Ranked match result: back into the ranked queue.
signal ranked_requested
## The replay bar and its twins in the options menu: &"play", &"pause", &"step", &"back", &"seek"
## (value: the entry to jump to), &"speed" (value: the time scale), &"view" (value: seat 0 or 1, or
## 2 for both hands).
signal replay_command(action: StringName, value: int)

const HAND_CARD_SIZE: Vector2 = Vector2(126, 176)
const FAR_HAND_CARD: Vector2 = Vector2(100, 140)   # a replay's far hand, in the strip over the far crest
const HAND_LIFT: float = 26.0
const MAX_LOG_LINES: int = 300
## The smallest tray face; a short tray widens its faces up to TRAY_CARD_MAX_WIDTH.
const TRAY_CARD_SIZE: Vector2 = Vector2(204, 285)
const TRAY_CARD_MAX_WIDTH: float = 340.0
const TRAY_GAP: float = 12.0          # the tray flow's h_separation in hud.tscn
const TRAY_SIDE_ROOM: float = 180.0   # screen width the tray panel leaves beside it
const TRAY_FRAME: Vector2 = Vector2(6.0, 32.0)   # a face's frame across; frame, gap and caption down
const TRAY_HEIGHT_SHARE: float = 0.57 # of the screen height, for the rows shown before scrolling
const CHOICE_HEIGHT: float = 100.0    # a tray tile that is a wording rather than a card
const LOG_COLLAPSED_BOTTOM: float = 306.0
const LOG_EXPANDED_FRACTION: float = 0.72
const FRAME_TINT: Color = ZenithTheme.FRAME
const TRAY_COLUMNS: int = 6          # cards per row before the tray wraps
const TRAY_ROWS_SHOWN: int = 2       # rows before the tray scrolls
const PILE_ROWS_SHOWN: int = 3       # a browsed pile is only read, so it may be taller
const FOCUS_CAPTION_HEIGHT: float = 32.0
## The response stack laid over the pinned attack, inside the Focus rect. A response is drawn at
## this share of the Focus face, and each level steps up and to the left with a small alternating
## tilt, so the newest card is wholly in view and the one under it still shows its caption strip.
## The stack never needs room of its own, so a decision column can open with the state still up.
const STACK_SCALE: float = 0.8
const STACK_STEP: Vector2 = Vector2(-26.0, -34.0)
const STACK_TILT: float = 1.0          # degrees, sign alternating, so a pile never reads as one card
const STACK_STRIP: float = 26.0        # the caption strip on each card's visible bottom edge
const STACK_MAX: int = 4               # levels that step; deeper responses sit on the last one
const STACK_LEAVE: float = 0.25        # how long a resolved response takes to leave the stack
## Meta on a face the pending list put on the stack, so a later refresh knows which faces are its
## own to take off again and which a replay beat owns.
const PENDING_KEY: StringName = &"pending_key"
## The filament from the pinned card to its target on the table. It is the 2D reading of the same
## cue `DuelFx.show_attack_link` draws between the two cards: one bowed thread in the attack
## colour, a transverse cap when the attack is stopped and a second chevron once it has landed.
const FILAMENT_SAMPLES: int = 24
const FILAMENT_BOW: float = 0.09          # side offset of the curve, as a share of its own length
const FILAMENT_TAIL: float = 8.0          # gap between the card's edge and the start of the thread
const FILAMENT_HEAD: float = 26.0         # gap between the target card's centre and the chevron
const FILAMENT_CHEVRON: Vector2 = Vector2(17.0, 9.0)   # chevron length along and across the thread
const FILAMENT_CAP: float = 13.0          # half-width of the transverse cap on a stopped attack
const CARD_FACE: PackedScene = preload("res://scenes/duel/card_face.tscn")
const CARD_ASPECT: float = 716.0 / 512.0
const DECISION_GAP: float = 12.0
## The rail on the right edge, GUTTER in from it. The focus card always has one size,
## RAIL_CARD_WIDTH, and sits centred between the screen's top and the decision's line (`rail_top`).
## The decision frame stands on that line, PROMPT_BOTTOM up from the screen's bottom edge and level
## with the tucked hand's top, so its buttons keep one home clear of the corner, and it is as tall
## as what it says. A decision too tall for the room under the card lifts the card, no higher than
## RAIL_TOP (under the corner toggles); a longer one may reach over the focus caption strip
## (PROMPT_LONG_RISE), never over the face, and past that its action list scrolls.
const GUTTER: float = 18.0
const RAIL_TOP: float = 82.0
const RAIL_CARD_WIDTH: float = 400.0
const RAIL_LEFT: float = -GUTTER - RAIL_CARD_WIDTH   # from the right edge
const PROMPT_BOTTOM: float = 96.0
const PROMPT_LONG_RISE: float = FOCUS_CAPTION_HEIGHT + DECISION_GAP
## Padding between the decision panel's frame texture edge and its text; the rule itself sits
## about 8 px inside the texture edge.
const PROMPT_PAD: int = 20
const ACTION_HEIGHT: float = 48.0
const SINGLE_ACTION_HEIGHT: float = 56.0   # a lone action is the whole decision, so it stands taller
const DECISION_RESULT_HEIGHT: float = 30.0   # one line at the body size
## Prompt kinds whose card options are browsed in the tray even when the cards are in the hand:
## the decision is about the cards themselves, as in a discard-step keep or a Reserve swap.
const TRAY_KINDS: Array[StringName] = [&"reserve", &"keep", &"discard_choice", &"recover", &"pick_option", &"name_card", &"pick_discard"]
## Tray captions by option type; anything else shows the option's own label.
const TRAY_VERBS: Dictionary = {
	&"reserve_in": "Bring in", &"keep": "Keep", &"discard_choice": "Discard", &"recover": "Recover",
	&"pick_option": "Choose", &"pick_in_play": "Choose", &"name_card": "Name", &"capture": "Capture", &"discard_ally": "Discard",
	&"final_strike": "Discard",
}
## The tray only ever opens for the seat at the table, so its header needs no name.
const TRAY_WHO: String = "YOUR DECISION"
## The over-bright flash a face takes for a beat that happened on it, bone rather than warm.
const PULSE_BRIGHT: Color = Color(1.6, 1.58, 1.5, 1)
## The beat banner laid across the ring between the duelists. One home for every beat: a
## hand-over (Combat opens, the exchange changes hands, a turn starts) sweeps in, an outcome (a
## hit, a stop, a wound) pops, and a quiet beat (a pass, a window that opened on nothing) is a
## thin translucent line that never cuts short a louder banner still being read. Each tier stops
## short of the phase track's notches either side of the ring.
enum Banner { HANDOVER, OUTCOME, QUIET }
const BANNER_HOLD: Array[float] = [1.4, 1.1, 0.6]
const BANNER_HEIGHT: Array[float] = [72.0, 60.0, 40.0]
const BANNER_WIDTH: Array[float] = [640.0, 580.0, 480.0]
const BANNER_FONT: Array[int] = [34, 30, 22]
const BANNER_MIN_FONT: int = 18
const BANNER_ALPHA: Array[float] = [0.92, 0.88, 0.5]
const BANNER_SWEEP: float = 0.25
const BANNER_POP: float = 0.16
const BANNER_FADE: float = 0.25
## A quiet line waits behind a louder banner until that one has been up this long.
const BANNER_MIN_READ: float = 0.6
## The label one lone non-card action carries, by prompt kind then option type. A single button is
## the whole decision, so it says what happens rather than naming the rule it comes from.
const ACTION_LABELS: Dictionary = {
	&"pass": "Pass", &"no_defense": "No Defense", &"decline": "Let it resolve", &"done": "Done",
	&"no_endure": "Take the wound", &"declare": "Declare Combat",
}
const ACTION_LABELS_BY_KIND: Dictionary = {
	&"combat_end": {&"done": "End Combat"}, &"declare": {&"skip": "No Combat"},
}
## Only explicit batch confirmation gets a filled accent. Routine alternatives stay equal.
## Prompt kinds answered by the buttons in the panel even though their options name a card. An
## Endurance choice is a yes or no about one card that is already in a pile, so hunting for it on
## the table to click it is the wrong way to ask.
const BUTTON_KINDS: Array[StringName] = [&"endurance"]
## The confirm button of each options-menu item that asks first.
const MENU_VERBS: Dictionary = {&"concede": "Concede", &"rematch": "Rematch", &"leave": "Leave"}

@onready var reduced_motion_toggle: CheckButton = $Root/OptionsMenu/Column/Items/ReducedMotion
@onready var options_button: Button = $Root/Options
@onready var options_menu: PanelContainer = $Root/OptionsMenu
@onready var options_shade: ColorRect = $Root/OptionsShade
@onready var menu_items: VBoxContainer = $Root/OptionsMenu/Column/Items
@onready var menu_resume: Button = $Root/OptionsMenu/Column/Items/Resume
@onready var menu_concede: Button = $Root/OptionsMenu/Column/Items/Concede
@onready var menu_rematch: Button = $Root/OptionsMenu/Column/Items/Rematch
@onready var menu_leave: Button = $Root/OptionsMenu/Column/Items/Leave
@onready var fullscreen_toggle: CheckButton = $Root/OptionsMenu/Column/Items/Fullscreen
@onready var menu_confirm: VBoxContainer = $Root/OptionsMenu/Column/Confirm
@onready var menu_question: Label = $Root/OptionsMenu/Column/Confirm/Question
@onready var menu_yes: Button = $Root/OptionsMenu/Column/Confirm/Buttons/Yes
@onready var menu_no: Button = $Root/OptionsMenu/Column/Confirm/Buttons/No
@onready var root: Control = $Root
@onready var log_scroll: ScrollContainer = $Root/Log/Column/Scroll
@onready var near_flags: Label = $Root/NearFlags
@onready var far_flags: Label = $Root/FarFlags
@onready var presence_line: Label = $Root/PresenceLine
@onready var log_text: RichTextLabel = $Root/Log/Column/Scroll/Text
@onready var dev_toggle: Button = $Root/OptionsMenu/Column/Items/DevToggle
@onready var dev_panel: DevPanel = $Root/DevPanel
@onready var peek: Control = $Root/Peek
@onready var peek_face: CardFace = $Root/Peek/Face
@onready var peek_forecast: PanelContainer = $Root/Peek/Forecast
@onready var peek_forecast_text: RichTextLabel = $Root/Peek/Forecast/Text
@onready var banner: Control = $Root/Banner
@onready var banner_ribbon: ColorRect = $Root/Banner/Ribbon
@onready var banner_text: Label = $Root/Banner/Text
@onready var log_panel: PanelContainer = $Root/Log
@onready var log_toggle: Button = $Root/Log/Column/Header/Toggle
@onready var inspect: ColorRect = $Root/Inspect
@onready var inspect_face: CardFace = $Root/Inspect/Center/Column/Face
@onready var inspect_status_scroll: ScrollContainer = $Root/Inspect/Center/Column/StatusScroll
@onready var inspect_status: RichTextLabel = $Root/Inspect/Center/Column/StatusScroll/Status
@onready var hand: HBoxContainer = $Root/Hand
@onready var prompt_panel: PanelContainer = $Root/PromptPanel
@onready var prompt_who: Label = $Root/PromptPanel/Column/Who
@onready var prompt_title: Label = $Root/PromptPanel/Column/Title
@onready var exchange_rail: HBoxContainer = $Root/PromptPanel/Column/Exchange
@onready var exchange_state: Label = $Root/PromptPanel/Column/Exchange/Lines/State
@onready var exchange_route: Label = $Root/PromptPanel/Column/Exchange/Lines/Route
@onready var exchange_response: Label = $Root/PromptPanel/Column/Exchange/Lines/Response
@onready var exchange_damage: Label = $Root/PromptPanel/Column/Exchange/Lines/Damage
@onready var exchange_stops: Label = $Root/PromptPanel/Column/Exchange/Lines/Stops
@onready var focus: Control = $Root/Focus
@onready var focus_caption: Label = $Root/Focus/Caption
@onready var focus_face: CardFace = $Root/Focus/Face
@onready var stack: Control = $Root/Focus/Stack
@onready var filament: Control = $Root/FocusFilament
@onready var filament_thread: Line2D = $Root/FocusFilament/Thread
@onready var filament_cap: Line2D = $Root/FocusFilament/Cap
@onready var filament_head: Line2D = $Root/FocusFilament/Head
@onready var filament_head_trail: Line2D = $Root/FocusFilament/HeadTrail
@onready var prompt_outcome: Label = $Root/PromptPanel/Column/Exchange/Lines/Outcome
@onready var prompt_hint: Label = $Root/PromptPanel/Column/Hint
@onready var primary_box: VBoxContainer = $Root/PromptPanel/Column/Actions/Primary
@onready var actions_scroll: ScrollContainer = $Root/PromptPanel/Column/Actions
@onready var prompt_column: VBoxContainer = $Root/PromptPanel/Column
@onready var tray: ColorRect = $Root/Tray
@onready var tray_who: Label = $Root/Tray/Center/Panel/Column/Who
@onready var tray_title: Label = $Root/Tray/Center/Panel/Column/Title
@onready var tray_hint: Label = $Root/Tray/Center/Panel/Column/Hint
@onready var tray_scroll: ScrollContainer = $Root/Tray/Center/Panel/Column/Scroll
@onready var tray_cards: HFlowContainer = $Root/Tray/Center/Panel/Column/Scroll/Cards
@onready var tray_buttons: HFlowContainer = $Root/Tray/Center/Panel/Column/Buttons
@onready var pile: ColorRect = $Root/Pile
@onready var pile_who: Label = $Root/Pile/Center/Panel/Column/Who
@onready var pile_title: Label = $Root/Pile/Center/Panel/Column/Title
@onready var pile_hint: Label = $Root/Pile/Center/Panel/Column/Hint
@onready var pile_scroll: ScrollContainer = $Root/Pile/Center/Panel/Column/Scroll
@onready var pile_cards: HFlowContainer = $Root/Pile/Center/Panel/Column/Scroll/Cards
@onready var pile_close: Button = $Root/Pile/Center/Panel/Column/Buttons/Close
@onready var handoff: ColorRect = $Root/Handoff
@onready var handoff_title: Label = $Root/Handoff/Center/Column/Title
@onready var handoff_ready: Button = $Root/Handoff/Center/Column/Ready
@onready var game_over: ColorRect = $Root/GameOver
@onready var game_over_title: Label = $Root/GameOver/Center/Column/Title
@onready var game_over_reason: Label = $Root/GameOver/Center/Column/Reason
@onready var game_over_note: Label = $Root/GameOver/Center/Column/Note
@onready var rematch_button: Button = $Root/GameOver/Center/Column/Buttons/Rematch
@onready var select_button: Button = $Root/GameOver/Center/Column/Buttons/Select
@onready var title_button: Button = $Root/GameOver/Center/Column/Buttons/Title
@onready var game_over_series: Label = $Root/GameOver/Center/Column/Series
@onready var game_over_rating: Label = $Root/GameOver/Center/Column/Rating
@onready var next_button: Button = $Root/GameOver/Center/Column/Buttons/Next
@onready var ranked_button: Button = $Root/GameOver/Center/Column/Buttons/FindRanked
@onready var series_line: Label = $Root/Series
@onready var loading: ColorRect = $Root/Loading
@onready var prompt_clock: Label = $Root/PromptPanel/Column/Clock
@onready var tray_clock: Label = $Root/Tray/Center/Panel/Column/Clock
@onready var tray_panel: PanelContainer = $Root/Tray/Center/Panel
@onready var fuse: ColorRect = $Root/Fuse
@onready var reconnect: ColorRect = $Root/Reconnect
@onready var reconnect_status: Label = $Root/Reconnect/Center/Column/Status
@onready var reconnect_give_up: Button = $Root/Reconnect/Center/Column/GiveUp
@onready var far_hand: HBoxContainer = $Root/FarHand
@onready var replay_bar: PanelContainer = $Root/ReplayBar
@onready var replay_back: Button = $Root/ReplayBar/Column/Controls/Back
@onready var replay_play: Button = $Root/ReplayBar/Column/Controls/Play
@onready var replay_pause: Button = $Root/ReplayBar/Column/Controls/Pause
@onready var replay_step: Button = $Root/ReplayBar/Column/Controls/Step
@onready var replay_speed: OptionButton = $Root/ReplayBar/Column/Controls/Speed
@onready var replay_position: Label = $Root/ReplayBar/Column/Controls/Position
@onready var replay_turn: OptionButton = $Root/ReplayBar/Column/Jump/Turn
@onready var replay_view: OptionButton = $Root/ReplayBar/Column/Jump/View
@onready var menu_replay_speed: OptionButton = $Root/OptionsMenu/Column/Items/ReplaySpeed/Choice
@onready var menu_replay_view: OptionButton = $Root/OptionsMenu/Column/Items/ReplayView/Choice

var external_hand: bool = false
var scene_flags: bool = false
## The node that can project a table card's centre, `DuelView`. Set from the parent in `_ready`.
var table: Node = null
var _viewer_seat: int = 0
var _log_lines: int = 0
var _current_prompt: PromptView = null
var _view: SeatView = null
var _faces: CardFaceCache = null
var _log_expanded: bool = false
var _batch: PromptView = null          # the prompt behind a multi-select tray, else null
var _selected: Array[int] = []
var _entries: Dictionary = {}          # uid -> {frame, caption, verb} for batch trays
var _confirm: Button = null
var _online: bool = false
var _can_rematch: bool = false         # online: this client may ask for a rematch (`Net.can_rematch`)
var _adventure: bool = false
var _duel_over: bool = false           # the result is up, whether the rules or a concession ended it
var _ranked: bool = false              # a ranked match: Concede loses a game, Leave match the match
## Ranked: a game's result waits for the match to say what follows (`show_between`,
## `show_match_result`) before it offers a button. Off once the connection is gone.
var _series_open: bool = false
var _match_decided: bool = false       # ranked: the match result is up
var _next_at: int = 0                  # ranked between games: ticks msec of the next deal, 0 otherwise
var _menu_action: StringName = &""     # the menu item waiting on its confirm, &"" when none
var _banner: Tween = null
var _banner_tier: int = Banner.QUIET
var _banner_since: int = 0             # ticks when the banner now up appeared
var _fitting_actions: bool = false
var _single_action: Button = null         # the one large action button, null when there isn't one
var _damage_available: bool = false
var _exchange_before_preview: bool = false
var _pile_player: int = -1             # whose pile the browser is showing
var _pile_zone: StringName = &""       # &"discard", &"removed" or &"relic", &"" when the browser is closed
var _pile_uids: Array[int] = []        # the pile as the browser last drew it, top first
var _pile_fill: int = 0                # guards against two fills racing over the same container
var _replay_focus: bool = false
var _owner_marks: Dictionary = {}      # card uid -> " · yours" / " · theirs", set per prompt
var _stack: Array[Control] = []        # responses over the pinned attack, oldest first
var _overflow: Label = null            # the "+N" badge on the top face when the queue is deeper
var _focus_card_uid: int = -1          # the card the Focus slot is holding, -1 when it holds none
var _caption_base: String = ""         # the Focus caption before the wound line is appended
var _wounds_note: String = ""          # "3 wounds" while the attack still owes some, else ""
var _pending_anchor: String = ""       # the pending item this HUD put in the slot, "" when a pin owns it
var _anchor_target: int = -1           # what the anchored item is aimed at, -1 when it is aimed nowhere
var _anchor_uid: int = -1
var _filament_target: int = -1         # the table card the current pending job is aimed at
var _filament_uid: int = -1            # the card that job belongs to, so the stack can source it
var _filament_state: StringName = &"pending"
var inspect_uid: int = -1              # the card the inspect overlay shows, -1 when closed or unknown
var _reserve_outcome: bool = false     # the open decision has option previews, so their row is kept
var _who_color: Color = ZenithTheme.TEXT   # the deciding seat's accent, for the tray header
var _tray_face: Vector2 = TRAY_CARD_SIZE   # the face size of the tray being filled
## Online, per seat: the server's last clock state (`Net.clock_changed`), when it arrived, and for
## the bank the amount it started from, which the fuse burns down from.
var _clocks: Array[Dictionary] = [{}, {}]
var _clock_warned: bool = false
## A recorded duel played back: nothing here answers a decision, and the menu offers the replay's
## own controls instead of Concede and Rematch.
var _match_replay: bool = false
## Inside the panel frame's texture edge, where its rule runs; the fuse burns along it.
const FUSE_INSET: float = 8.0
const FUSE_HEIGHT: float = 4.0


func _ready() -> void:
	root.theme = SanctumUI.theme()
	reduced_motion_toggle.toggled.connect(func(on: bool) -> void: reduced_motion_changed.emit(on))
	# The decision column is a framed plate too, so its text never sits bare on the courtyard.
	prompt_panel.add_theme_stylebox_override("panel", MapArt.panel_box(PROMPT_PAD, FRAME_TINT))
	prompt_panel.minimum_size_changed.connect(_stand_prompt)
	prompt_panel.visibility_changed.connect(_stand_prompt)
	prompt_hint.add_theme_color_override("font_color", ZenithTheme.TEXT_SOFT)
	log_panel.add_theme_stylebox_override("panel", MapArt.panel_box(14, FRAME_TINT))
	# The inspect hint sits on a small framed panel instead of floating over the table.
	var inspect_hint: Label = $Root/Inspect/Center/Column/Hint
	inspect_hint.add_theme_stylebox_override("normal", ZenithTheme.panel(24))
	inspect_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# The caption under the focus card lands on whatever the table has there, so it gets a plate.
	focus_caption.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.BG, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 6, 0))
	table = get_parent()
	handoff_ready.pressed.connect(func() -> void: handoff_confirmed.emit())
	rematch_button.pressed.connect(func() -> void: rematch_requested.emit())
	select_button.pressed.connect(func() -> void: select_requested.emit())
	title_button.pressed.connect(func() -> void: title_requested.emit())
	next_button.pressed.connect(_on_next_game)
	ranked_button.pressed.connect(func() -> void: ranked_requested.emit())
	reconnect_give_up.pressed.connect(func() -> void: give_up_requested.emit())
	log_text.add_theme_color_override("default_color", ZenithTheme.MUTED)
	inspect.visible = false
	inspect.gui_input.connect(_on_inspect_input)
	pile.visible = false
	pile_close.pressed.connect(hide_pile)
	log_toggle.pressed.connect(func() -> void: set_log_expanded(not _log_expanded))
	dev_toggle.pressed.connect(func() -> void:
		dev_panel.visible = not dev_panel.visible
		set_options_open(false))
	options_button.toggled.connect(set_options_open)
	options_menu.add_theme_stylebox_override("panel", MapArt.panel_box(14, FRAME_TINT))
	options_shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			set_options_open(false))
	menu_resume.pressed.connect(set_options_open.bind(false))
	menu_concede.pressed.connect(_ask.bind(&"concede"))
	menu_rematch.pressed.connect(_ask.bind(&"rematch"))
	menu_leave.pressed.connect(_ask.bind(&"leave"))
	menu_yes.pressed.connect(func() -> void: _menu_act(_menu_action))
	menu_no.pressed.connect(_show_menu_question.bind(&""))
	fullscreen_toggle.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	dev_panel.command.connect(func(effect: Dictionary) -> void: dev_command.emit(effect))
	# A transport strip rather than a framed dialog: the flat panel's fill and 1 px edge, tight.
	replay_bar.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG, ZenithTheme.BORDER, ZenithTheme.RADIUS, 1, ZenithTheme.GAP_XS, ZenithTheme.GAP_XS))
	replay_back.pressed.connect(func() -> void: replay_command.emit(&"back", 0))
	replay_play.pressed.connect(func() -> void: replay_command.emit(&"play", 0))
	replay_pause.pressed.connect(func() -> void: replay_command.emit(&"pause", 0))
	replay_step.pressed.connect(func() -> void: replay_command.emit(&"step", 0))
	replay_turn.item_selected.connect(func(index: int) -> void: replay_command.emit(&"seek", replay_turn.get_item_id(index)))
	for choice: OptionButton in [replay_speed, menu_replay_speed]:
		choice.item_selected.connect(_on_replay_speed)
	for choice: OptionButton in [replay_view, menu_replay_view]:
		choice.item_selected.connect(_on_replay_view)
	root.resized.connect(_layout_prompt_column)
	primary_box.minimum_size_changed.connect(_fit_actions)
	prompt_column.minimum_size_changed.connect(_fit_actions)
	_compact_prompt()


## One bounded column: a real card, the decision and its consequence, then offered controls.
## Printed identity and rules remain on the face. The question and terse instruction stay visible
## because a readable card is not enough to say what input the game is waiting for.
func _compact_prompt() -> void:
	# The owner line is only ever "YOUR MOVE": a waiting panel's title already names who decides. A
	# replay says whose decision it was and how it went, so it keeps both lines.
	prompt_who.visible = (_current_prompt != null or _match_replay) and not prompt_who.text.is_empty()
	prompt_title.visible = _current_prompt != null or not focus.visible
	prompt_hint.visible = (_current_prompt != null or _match_replay) and not prompt_hint.text.is_empty()
	exchange_state.hide()
	exchange_route.hide()
	exchange_response.hide()
	_layout_prompt_column()


func _layout_prompt_column() -> void:
	if focus == null or prompt_panel == null:
		return
	focus.offset_left = RAIL_LEFT
	focus.offset_right = -GUTTER
	focus_face.scale = Vector2.ONE * RAIL_CARD_WIDTH / 512.0
	prompt_panel.offset_left = RAIL_LEFT
	prompt_panel.offset_right = -GUTTER
	_place_focus()
	# The response stack lives inside the Focus rect, so it costs the decision column nothing.
	_layout_stack()
	_fit_actions()


## The card face in the Focus slot, in global coordinates, with the caption strip under it left out.
func focus_face_rect() -> Rect2:
	var rect: Rect2 = focus.get_global_rect()
	return Rect2(rect.position, Vector2(rect.size.x, rect.size.x * CARD_ASPECT))


## The focus slot's height: the card face and its caption strip.
func _slot_height() -> float:
	return RAIL_CARD_WIDTH * CARD_ASPECT + FOCUS_CAPTION_HEIGHT


## The focus card's top edge. It is centred between the screen's top and the decision's bottom
## line. A decision too tall to fit under it lifts it only as far as it needs, never above RAIL_TOP.
func rail_top() -> float:
	var line: float = root.size.y - PROMPT_BOTTOM
	var top: float = (line - _slot_height()) * 0.5
	if prompt_panel.visible:
		top = minf(top, line - prompt_panel.get_combined_minimum_size().y - DECISION_GAP - _slot_height())
	return maxf(RAIL_TOP, top)


func _place_focus() -> void:
	focus.offset_top = rail_top()
	focus.offset_bottom = focus.offset_top + _slot_height()


## The highest a decision reaches, at the card's highest place; a longer one scrolls.
func _panel_top() -> float:
	return RAIL_TOP + _slot_height() + DECISION_GAP


## The action list's height. The frame stands on its bottom edge and grows up to fit, so the
## buttons never move; a list that would push the frame past its ceiling scrolls instead.
func _fit_actions() -> void:
	if _fitting_actions or actions_scroll == null:
		return
	_fitting_actions = true
	actions_scroll.visible = primary_box.get_child_count() > 0
	var outside: float = maxf(0.0, prompt_panel.get_combined_minimum_size().y - actions_scroll.get_combined_minimum_size().y)
	var room: float = root.size.y - PROMPT_BOTTOM - (_panel_top() - PROMPT_LONG_RISE)
	var available: float = maxf(SINGLE_ACTION_HEIGHT, room - outside)
	actions_scroll.custom_minimum_size.y = minf(primary_box.get_combined_minimum_size().y, available)
	_fitting_actions = false
	_stand_prompt()


## The frame stands on its bottom edge at exactly its content's height. Set outright, because a
## Control only grows to its minimum on its own, and a hidden one misses the change entirely; a
## frame on its bottom edge that lags shows its buttons below the screen.
func _stand_prompt() -> void:
	prompt_panel.offset_top = prompt_panel.offset_bottom - prompt_panel.get_combined_minimum_size().y
	_place_focus()


func set_loading(on: bool) -> void:
	loading.visible = on


## Online duel: Rematch and Back to lobby where this client can ask for them (`Net.can_rematch`),
## otherwise the other button leaves the table.
func set_online(can_rematch: bool) -> void:
	_online = true
	_can_rematch = can_rematch
	select_button.text = "Back to lobby" if can_rematch else "Leave duel"


## A duel Find a duel paired: the result offers Rematch, Find another duel and Title.
func set_queue_duel() -> void:
	select_button.text = "Find another duel"
	title_button.visible = true


## A game of a ranked match. The menu concedes this game or leaves the match, there is no rematch,
## and `series` ("Game 2 of 3 · 1-0") stands beside the options gear.
func set_ranked(series: String) -> void:
	_ranked = true
	_series_open = true
	series_line.text = series
	series_line.visible = true


## "Game 2 of 3 · 1-0", the viewer's games first. The score is left off until a game has been won.
static func series_text(game: int, best_of: int, mine: int, theirs: int) -> String:
	var text: String = "Game %d of %d" % [game, best_of]
	if mine + theirs > 0:
		text += " · %d-%d" % [mine, theirs]
	return text


## "You win the match 2-1", "You lose the match 0-2", the viewer's games first, or "No result".
static func match_title(winner: int, viewer: int, wins: Array) -> String:
	if winner < 0:
		return "No result"
	var score: String = "%d-%d" % [int(wins[viewer]), int(wins[1 - viewer])]
	return ("You win the match " if winner == viewer else "You lose the match ") + score


## "Rating 112 → 138", or the rating as it stands for a match that was not rated, then
## " · Provisional" while the server says so.
static func rating_change_text(before: int, after: int, provisional: bool, rated: bool) -> String:
	var text: String = "Rating %d → %d" % [before, after] if rated else "Rating %d, not rated" % after
	return text + (" · Provisional" if provisional else "")


## Ranked between games: the result gains the match score over it, a count to the next deal, and
## Next game, which the server deals on at once when both players have pressed it.
func show_between(series: String, next_at: int) -> void:
	game_over_series.text = series
	game_over_series.visible = true
	_next_at = next_at
	next_button.text = "Next game"
	next_button.disabled = false
	next_button.visible = true
	_show_next_count()


func _on_next_game() -> void:
	next_button.disabled = true
	next_button.text = "Waiting for the other player"
	next_game_requested.emit()


## "Next game in 18" while the server's wait runs, then that it is dealing.
func _show_next_count() -> void:
	if _next_at <= 0 or not next_button.visible:
		return
	var seconds: int = ceili(maxi(0, _next_at - Time.get_ticks_msec()) / 1000.0)
	set_game_over_note("Next game in %d" % seconds if seconds > 0 else "Dealing the next game…")


## Ranked: the match is decided. The result becomes the match's, with the rating line, and offers
## Find another ranked duel, Find a duel and Title.
func show_match_result(title: String, reason: String, rating: String) -> void:
	_match_decided = true
	_series_open = false
	_next_at = 0
	game_over_title.text = title
	game_over_reason.text = reason
	game_over_series.visible = false
	game_over_rating.text = rating
	game_over_rating.visible = true
	set_game_over_note("")
	next_button.visible = false
	rematch_button.visible = false
	ranked_button.visible = true
	select_button.text = "Find a duel"
	select_button.visible = true
	title_button.visible = true
	if options_menu.visible:
		set_options_open(true)


## The connection is gone, so neither a next game nor a search can follow from this result: only
## its way back to the title stays, on the select button the table renames.
func drop_series() -> void:
	_series_open = false
	_next_at = 0
	next_button.visible = false
	ranked_button.visible = false
	title_button.visible = false
	select_button.visible = true


## Adventure duel: the select button leads back to the stage screen, not duelist select.
func set_adventure() -> void:
	_adventure = true
	select_button.text = "Continue"


## `live` is the beat's own state (see GameEvent.state) while an update replays, {} otherwise.
func refresh_state(view: SeatView, viewer: int, live: Dictionary = {}) -> void:
	_view = view
	# Hotseat has no fixed viewer: the seat at the table is whoever has to decide.
	var me: int = viewer
	if me < 0:
		me = view.deciding if view.deciding >= 0 else view.active
	_viewer_seat = me
	near_flags.text = " | ".join(PLAYER_STATUS.flags(view.player(me)))
	far_flags.text = " | ".join(PLAYER_STATUS.flags(view.player(1 - me)))
	near_flags.visible = not scene_flags and not near_flags.text.is_empty()
	far_flags.visible = not scene_flags and not far_flags.text.is_empty()
	_reconcile_pending(view, live)
	_read_filament(view)
	_sync_pile()


## The card the Focus slot is holding: the pinned replay card when one is up, otherwise the card
## the open decision is about. -1 when the slot is empty or holds nothing a seat can name.
func focus_uid() -> int:
	if not focus.visible:
		return -1
	if _focus_card_uid >= 0:
		return _focus_card_uid
	return _focus_uid(_current_prompt)


## Where the filament points and what it means, taken once a beat. The line itself is redrawn every
## frame, because the camera can move under a settled state.
func _read_filament(view: SeatView) -> void:
	_filament_target = -1
	_filament_uid = -1
	for item in view.pending:
		if not bool(item.get("current", false)):
			continue
		_filament_target = int(item.get("target", -1))
		_filament_uid = int(item.get("uid", -1))
		break
	# A trigger anchored in the slot without being the engine's `current` job still aims somewhere,
	# and the thread is the only thing that says where. No target anywhere means no thread.
	if _filament_target < 0 and _anchor_target >= 0:
		_filament_target = _anchor_target
		_filament_uid = _anchor_uid
	if bool(view.attack.get("stopped", false)):
		_filament_state = &"stopped"
	elif bool(view.attack.get("landed", false)):
		_filament_state = &"landed"
	else:
		_filament_state = &"pending"


## `SeatView.pending` drives the Focus slot and the stack laid over it, so everything waiting to
## resolve is one pile on the right rather than a second column somewhere else. The anchor is the
## declared attack when there is one and otherwise whatever resolves first; every other job is a
## face stacked over it with the one resolving next on top. A `wounds` job is the attack's own loop
## rather than a card, so it is a line on the anchor's caption instead of a face of its own.
func _reconcile_pending(view: SeatView, live: Dictionary) -> void:
	var queued: Array[Dictionary] = []
	var wounds: String = ""
	for item in view.pending:
		var kind: StringName = StringName(str(item.get("kind", &"")))
		if kind == &"wounds":
			var note: String = str(item.get("note", ""))
			if not note.is_empty():
				wounds = note
			continue
		queued.append(item)
	_wounds_note = wounds
	var anchor: int = -1
	for i in range(queued.size()):
		if StringName(str(queued[i].get("kind", &""))) == &"attack":
			anchor = i
			break
	if anchor < 0 and not queued.is_empty():
		anchor = 0
	var attacker: int = int(live.get("attacker", view.attacker))
	# A declared attack pinned by the replay, or the card an open decision is about, owns the slot
	# and its own caption. Anything this HUD anchored itself is ours to move on or take away.
	var borrowed: bool = focus.visible and _pending_anchor.is_empty()
	var anchor_uid: int = -1
	if borrowed:
		anchor_uid = focus_uid()
	elif anchor >= 0 and _anchor_pending(view, queued[anchor], attacker):
		anchor_uid = int(queued[anchor].get("uid", -1))
	elif not _pending_anchor.is_empty():
		_pending_anchor = ""
		_anchor_target = -1
		_anchor_uid = -1
		hide_focus()
	if borrowed or not _pending_anchor.is_empty():
		_anchor_uid = anchor_uid
		_anchor_target = int(queued[anchor].get("target", -1)) if anchor >= 0 else -1
	_apply_caption()
	_reconcile_stack(view, queued, anchor, anchor_uid, attacker)


## Puts one pending job in the Focus slot as the big face the rest stack over. False when the job
## has no face this seat may look at, which leaves the slot to the next refresh.
func _anchor_pending(view: SeatView, item: Dictionary, attacker: int) -> bool:
	var uid: int = int(item.get("uid", -1))
	var card: SeatCard = view.card(uid)
	if card == null or card.hidden():
		return false
	var def: CardDef = _def(card.def_id)
	if def == null:
		return false
	var owner: int = int(item.get("owner", -1))
	var tint: Color = ZenithTheme.ATTACK if attacker >= 0 and owner == attacker else ZenithTheme.DEFEND
	var key: String = _pending_key(item, 0)
	if key == _pending_anchor and focus.visible:
		# Already the face in the slot. Only the caption can have moved on, and redrawing the card
		# every beat would restart the face for nothing.
		set_focus_caption(_pending_caption(item), tint)
		_pending_anchor = key
		return true
	if not show_replay_card(def, _pending_caption(item), tint, uid):
		return false
	_pending_anchor = key
	return true


## What the anchored job says about itself, from its own kind and the engine's note.
func _pending_caption(item: Dictionary) -> String:
	var note: String = str(item.get("note", ""))
	match StringName(str(item.get("kind", &""))):
		&"attack":
			return "Attack · " + note if not note.is_empty() and note != "nothing" else "Attack"
		&"trigger":
			return "Trigger · " + note if not note.is_empty() else "Trigger"
		&"pending_card":
			return note if not note.is_empty() else "Awaiting a counter"
		&"hidden":
			return "Opponent's trigger"
	return note if not note.is_empty() else "Resolving"


## The caption strip a stacked pending job carries. One word, because the face under it says the rest.
func _pending_strip(kind: StringName, item: Dictionary) -> String:
	match kind:
		&"hidden":
			return "Opponent's trigger"
		&"pending_card":
			var note: String = str(item.get("note", ""))
			return note if not note.is_empty() else "Awaiting a counter"
		&"attack":
			return "Attack"
	return "Trigger"


## A job's identity across refreshes. A masked job has no uid to be named by, so it is counted
## among its owner's masked jobs instead: when the first of them resolves, the last one leaves.
func _pending_key(item: Dictionary, ordinal: int) -> String:
	var kind: String = str(item.get("kind", ""))
	var uid: int = int(item.get("uid", -1))
	if uid >= 0:
		return "%s:%d" % [kind, uid]
	return "%s:%d:%d" % [kind, int(item.get("owner", -1)), ordinal]


## The queue behind the anchor, as faces over it. Pushed in reverse list order so the job resolving
## next ends up on top; faces a replay beat already dealt are left alone, and a job that has left
## the queue without a beat taking its face off goes with the same leaving animation.
func _reconcile_stack(view: SeatView, queued: Array[Dictionary], anchor: int, anchor_uid: int, attacker: int) -> void:
	var want: Array[Dictionary] = []          # last to resolve first, so pushing walks up the pile
	var keys: Array[String] = []
	var wanted: Dictionary = {}
	var masked: Dictionary = {}
	var ordinals: Array[int] = []
	for i in range(queued.size()):
		ordinals.append(int(masked.get(int(queued[i].get("owner", -1)), 0)))
		if int(queued[i].get("uid", -1)) < 0:
			masked[int(queued[i].get("owner", -1))] = ordinals[i] + 1
	for i in range(queued.size() - 1, -1, -1):
		if i == anchor:
			continue
		var uid: int = int(queued[i].get("uid", -1))
		if uid >= 0 and uid == anchor_uid:
			continue
		var key: String = _pending_key(queued[i], ordinals[i])
		want.append(queued[i])
		keys.append(key)
		wanted[key] = true
	for entry in _stack.duplicate():
		if not entry.has_meta(PENDING_KEY):
			continue
		if wanted.has(str(entry.get_meta(PENDING_KEY))):
			continue
		_take_off(entry)
	if not focus.visible or stack == null or tray.visible or inspect.visible:
		_set_overflow(0)
		return
	var fresh: Array[int] = []            # the jobs no face carries yet, furthest from resolving first
	for i in range(want.size()):
		if _entry_for_key(keys[i]) != null:
			continue
		var held: int = int(want[i].get("uid", -1))
		if held >= 0 and has_response(held):
			continue
		fresh.append(i)
	# Deeper than the pile can show: the jobs furthest from resolving give up their faces and are
	# counted on the top one instead.
	var room: int = maxi(0, STACK_MAX - _stack.size())
	var extra: int = maxi(0, fresh.size() - room)
	for n in range(extra, fresh.size()):
		var i: int = fresh[n]
		var key: String = keys[i]
		var uid: int = int(want[i].get("uid", -1))
		var kind: StringName = StringName(str(want[i].get("kind", &"")))
		var owner: int = int(want[i].get("owner", -1))
		var tint: Color = ZenithTheme.ATTACK if attacker >= 0 and owner == attacker else ZenithTheme.DEFEND
		var strip: String = _pending_strip(kind, want[i])
		var entry: Control = null
		var card: SeatCard = view.card(uid) if uid >= 0 else null
		var def: CardDef = _def(card.def_id) if card != null and not card.hidden() else null
		if kind == &"hidden" or def == null:
			entry = _push_back(strip, ZenithTheme.MUTED if kind == &"hidden" else tint)
		else:
			entry = _push_face(def, strip, tint, uid)
		if entry == null:
			continue
		entry.set_meta(PENDING_KEY, key)
	_set_overflow(extra)


func _entry_for_key(key: String) -> Control:
	for entry in _stack:
		if entry.has_meta(PENDING_KEY) and str(entry.get_meta(PENDING_KEY)) == key:
			return entry
	return null


func _entry_for_uid(uid: int) -> Control:
	if uid < 0:
		return null
	for entry in _stack:
		if int(entry.get_meta("uid", -1)) == uid:
			return entry
	return null


## "+3", on the face at the top of the pile, for the jobs queued behind what the stack can hold.
func _set_overflow(count: int) -> void:
	if count <= 0:
		if _overflow != null:
			_overflow.queue_free()
			_overflow = null
		return
	if _overflow == null:
		_overflow = Label.new()
		_overflow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overflow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_overflow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_overflow.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
		_overflow.add_theme_color_override("font_color", ZenithTheme.TEXT_DARK)
		_overflow.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.ACCENT, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 8, 2))
		stack.add_child(_overflow)
	_overflow.text = "+%d" % count
	_layout_stack()


## The beat that just happened, on the ribbon across the table (see `Banner`). A new banner
## replaces the last at once, except that a quiet one never cuts short a louder one still inside
## its `BANNER_MIN_READ`; the quiet beat's chip pulse and log line still happen without it.
func show_banner(text: String, color: Color, tier: int = Banner.OUTCOME) -> void:
	if tier == Banner.QUIET and banner.visible and _banner_tier != Banner.QUIET \
			and _banner_age() < BANNER_MIN_READ:
		return
	_clear_banner()
	_banner_tier = tier
	_banner_since = Time.get_ticks_msec()
	banner.size = Vector2(BANNER_WIDTH[tier], BANNER_HEIGHT[tier])
	banner.pivot_offset = banner.size * 0.5
	_place_banner()
	var mat: ShaderMaterial = banner_ribbon.material
	mat.set_shader_parameter("tint", Color(color, BANNER_ALPHA[tier]))
	mat.set_shader_parameter("rule", 0.0 if tier == Banner.QUIET else 0.05)
	banner_text.text = text
	# A long name steps the size down rather than running into the ribbon's faded ends.
	var font: Font = banner_text.get_theme_font("font")
	var size: int = BANNER_FONT[tier]
	var room: float = banner.size.x * 0.72
	while size > BANNER_MIN_FONT and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room:
		size -= 2
	banner_text.add_theme_font_size_override("font_size", size)
	banner_text.add_theme_color_override("font_color", ZenithTheme.TEXT if tier == Banner.QUIET else ZenithTheme.TEXT_DARK)
	banner.modulate = Color(1, 1, 1, 1)
	banner.scale = Vector2.ONE
	banner_text.modulate = Color(1, 1, 1, 1)
	banner.visible = true
	_banner = create_tween()
	if not reduced_motion_toggle.button_pressed:
		if tier == Banner.HANDOVER:
			# Swept open from the middle of the table, the words arriving as it lands.
			banner.scale = Vector2(0.0, 1.0)
			banner_text.modulate = Color(1, 1, 1, 0)
			_banner.tween_property(banner, "scale", Vector2.ONE, BANNER_SWEEP).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			_banner.tween_property(banner_text, "modulate:a", 1.0, 0.12)
		elif tier == Banner.OUTCOME:
			banner.scale = Vector2(0.85, 0.85)
			_banner.tween_property(banner, "scale", Vector2.ONE, BANNER_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner.tween_interval(BANNER_HOLD[tier])
	if reduced_motion_toggle.button_pressed:
		_banner.tween_callback(func() -> void: banner.visible = false)
		return
	_banner.tween_property(banner, "modulate:a", 0.0, BANNER_FADE if tier != Banner.QUIET else 0.2)
	_banner.tween_callback(func() -> void: banner.visible = false)


## An outcome banner: the attack, what it hit for, a stop, an aspect.
func toast(text: String, color: Color) -> void:
	show_banner(text, color, Banner.OUTCOME)


## A skipped or passed window still gets a beat, so nothing resolves silently.
func quiet_beat(text: String, color: Color) -> void:
	show_banner(text, color, Banner.QUIET)


## A change of hands: Combat opening, the exchange passing to the other seat, a new turn.
func handover(text: String, color: Color) -> void:
	show_banner(text, color, Banner.HANDOVER)


## Seconds of game time the banner now up has been showing. `--dev-fast` speeds the tweens, so the
## age runs at the same rate.
func _banner_age() -> float:
	return float(Time.get_ticks_msec() - _banner_since) / 1000.0 * Engine.time_scale


## The banner's home is the middle of the table, between the two duelists, wherever the camera
## puts that on screen. It sits in the gap the painted ring marks and never covers the rail.
func _place_banner() -> void:
	var centre: Vector2 = root.size * 0.5
	if table != null and table.has_method("table_centre_screen"):
		var point: Vector2 = table.table_centre_screen()
		if point.x >= 0.0:
			centre = point
	var right_limit: float = root.size.x + RAIL_LEFT - GUTTER
	var half: float = banner.size.x * 0.5
	centre.x = clampf(centre.x, half, maxf(half, right_limit - half))
	banner.position = centre - banner.size * 0.5


func _clear_banner() -> void:
	if _banner != null:
		_banner.kill()
		_banner = null
	banner.visible = false


func log_line(text: String) -> void:
	var bar: VScrollBar = log_scroll.get_v_scroll_bar()
	var following: bool = not _log_expanded or bar.value >= bar.max_value - bar.page - 8.0
	if _log_lines >= MAX_LOG_LINES:
		log_text.clear()
		_log_lines = 0
	if text.begins_with("—"):
		log_text.append_text("[color=#%s]%s[/color]\n" % [ZenithTheme.ACCENT.to_html(false), text])
	else:
		log_text.append_text(text + "\n")
	_log_lines += 1
	if following:
		_follow_log.call_deferred()


func _follow_log() -> void:
	await get_tree().process_frame
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


# --- Prompt ---------------------------------------------------------------

## Where each option of a prompt is offered. Four buckets: `primary` buttons in the side panel,
## `browse` tiles in the tray, `finals` behind the Final Strike button, and `click` for options
## the player takes on the card itself, wherever it is drawn. An option in `click` is only
## reachable if the table actually draws that card, so `tests/prompt_reach_tests.gd` checks
## every one of them against the client's own layout. Pure: it reads the views and nothing else.
func routes(p: PromptView, view: SeatView) -> Dictionary:
	var browse: Array[OptionView] = []
	var primary: Array[OptionView] = []
	var finals: Array[OptionView] = []
	var click: Array[OptionView] = []
	for opt in p.options:
		if opt.type == &"final_strike":
			finals.append(opt)
		elif opt.type == &"pick_option" and opt.card < 0:
			# A choice between wordings rather than cards ("all their Allies or all their Drills").
			# It reads as a card-sized tile in the tray, not as a row of small buttons.
			browse.append(opt)
		elif BUTTON_KINDS.has(p.kind) or (opt.card < 0 and opt.type != &"name_card"):
			primary.append(opt)
		elif _needs_tray_in(p, opt, view):
			browse.append(opt)
		else:
			click.append(opt)
	return {"primary": primary, "browse": browse, "finals": finals, "click": click}


func show_prompt(p: PromptView, view: SeatView) -> void:
	hide_pile()   # a decision arrived; the browser is not what the player needs to be looking at
	prompt_panel.show()
	_center_prompt_text(false)
	_view = view
	_current_prompt = p
	_owner_marks = CardText.option_side_marks(p, _viewer_seat)
	# The frame's place on the rail already says the move is ours; the owner line is for waiting.
	prompt_who.text = ""
	_who_color = SeatColors.accent(view, p.player, Session.color_seed)
	prompt_title.text = _prompt_title(p, view)
	# The response stack stays up. It is laid over the pinned attack inside the same rect, so it
	# takes no room from the decision column and the player sees the state they are answering.
	_show_attack(view, p)
	show_focus(_focus_uid(p), _focus_caption(p))
	prompt_hint.text = _hint_for(p)
	prompt_hint.visible = prompt_hint.text != ""
	# A decision whose options carry previews keeps their row from the start, so hovering one
	# fills a line that is already there rather than growing the frame.
	_reserve_outcome = false
	for o in p.options:
		_reserve_outcome = _reserve_outcome or not o.outcome.is_empty()
	_preview_outcome({})
	_compact_prompt()
	# Cards the player can already click in the hand or on the table stay there, highlighted.
	# Cards that need browsing (a Reserve, a look at the deck, a keep) open in the tray.
	# A Final Strike is offered on every hand card and commits the rest of the Combat, so it
	# gets its own button and tray rather than firing from a card click.
	var routed: Dictionary = routes(p, view)
	var browse: Array[OptionView] = routed["browse"]
	var primaries: Array[OptionView] = routed["primary"]
	var finals: Array[OptionView] = routed["finals"]
	var library: Array = p.context.get("library", [])
	if not library.is_empty():
		# A search of the Life Deck: the matches to pick from, then the rest of the deck to read.
		_fill_buttons([], primary_box, true)
		await _show_tray(TRAY_WHO, prompt_title.text, prompt_hint.text, browse, primaries, false, p if p.has_batch() else null, true, library.size())
		await _add_library(library, browse)
	elif browse.is_empty():
		_hide_tray()
		_fill_buttons(primaries, primary_box, true)
		if finals.is_empty() and primaries.size() == 1 and primaries[0].card < 0:
			_make_single_action(p, primaries[0], view)
		if not finals.is_empty():
			var b: Button = Button.new()
			b.text = "Final Strike…"
			b.custom_minimum_size = Vector2(0, ACTION_HEIGHT)
			b.add_theme_font_size_override("font_size", ZenithTheme.SIZE_BODY)
			b.pressed.connect(func() -> void: _show_final_strike(finals))
			primary_box.add_child(b)
			_fit_actions()
	else:
		_fill_buttons([], primary_box, true)
		_show_tray(TRAY_WHO, prompt_title.text, prompt_hint.text, browse, primaries, false, p if p.has_batch() else null)


## One lone action is the whole decision, so it is offered as one large button that says what
## will happen rather than naming the rule behind it. Space takes it. Two or more alternatives
## stay equal-weighted rows, because choosing between them is the decision.
func _make_single_action(p: PromptView, opt: OptionView, view: SeatView) -> void:
	if primary_box.get_child_count() != 1:
		return
	var b: Button = primary_box.get_child(0)
	b.text = _single_action_label(p, opt, view)
	b.custom_minimum_size = Vector2(0, SINGLE_ACTION_HEIGHT)
	b.add_theme_font_size_override("font_size", ZenithTheme.SIZE_ROW)
	b.tooltip_text = opt.label
	_single_action = b
	_fit_actions()


func _single_action_label(p: PromptView, opt: OptionView, view: SeatView) -> String:
	var by_kind: Dictionary = ACTION_LABELS_BY_KIND.get(p.kind, {})
	var text: String = str(by_kind.get(opt.type, ACTION_LABELS.get(opt.type, opt.label)))
	if opt.type == &"pass" and view != null and view.consecutive_passes == 1:
		text += " · ends Combat"
	return text


func _needs_tray(p: PromptView, opt: OptionView) -> bool:
	return _needs_tray_in(p, opt, _view)


func _needs_tray_in(p: PromptView, opt: OptionView, view: SeatView) -> bool:
	if opt.type == &"name_card" or TRAY_KINDS.has(p.kind):
		return true
	var c: SeatCard = view.card(opt.card)
	return c == null or c.zone == &"life_deck" or c.zone == &"reserve"


## A public exchange, not a simulated stack. Pending and resolved quantities stay separate.
func _show_attack(view: SeatView, p: PromptView = null) -> void:
	prompt_outcome.hide()
	_damage_available = false
	var a: Dictionary = view.attack
	var source: String = str(a.get("source_title", ""))
	if source.is_empty() and not a.is_empty():
		source = str(a.get("performer_title", "Attack")) + (" power" if bool(a.get("is_power", false)) else "")
	if source.is_empty() and not a.is_empty():
		source = "Attack"
	var announced: SeatCard = view.card(view.pending_card)
	if source.is_empty() and announced != null and not announced.hidden():
		source = announced.title
	var resolving: PackedStringArray = PackedStringArray()
	for uid in view.resolving:
		var card: SeatCard = view.card(uid)
		if card != null and not card.hidden():
			resolving.append(card.title)
	if source.is_empty() and not resolving.is_empty():
		# One public card names itself; a run of them is the pending pile's job, in order, and the
		# rail only says where to look. `resolving` carries no order to report here.
		source = resolving[0] if resolving.size() == 1 else "Resolving, in order on the right"
	if source.is_empty() and p != null:
		var pending: SeatCard = view.card(int(p.context.get("source", p.context.get("card", -1))))
		if pending != null and not pending.hidden():
			source = pending.title
	if source.is_empty() and a.is_empty() and view.step == GameState.Step.COMBAT and not view.last_attack.is_empty():
		_show_last_exchange(view.last_attack)
		return
	exchange_rail.visible = not source.is_empty() or not a.is_empty()
	if not exchange_rail.visible:
		return
	var stopped: bool = bool(a.get("stopped", false))
	var landed: bool = bool(a.get("landed", false))
	var kind: String = "Final Strike" if bool(a.get("is_final", false)) else ("Strike" if str(a.get("kind", "strike")) == "strike" else "Art")
	if bool(a.get("focused", false)):
		kind = "Focused " + kind
	exchange_state.text = "RESPONSE WINDOW" if a.is_empty() else ("STOPPED" if stopped else ("DAMAGE RESOLVING" if landed else kind.to_upper()))
	exchange_state.add_theme_color_override("font_color", ZenithTheme.DEFEND if stopped else ZenithTheme.ACCENT)
	var target: SeatCard = view.card(int(a.get("target", -1)))
	var defender: int = int(a.get("defender", -1))
	if target == null and defender >= 0 and defender < view.players.size():
		target = view.card(view.player(defender).controlling)
	exchange_route.text = source
	exchange_route.tooltip_text = "\n".join(resolving) if a.is_empty() and announced == null else ""
	if target != null and not target.hidden():
		exchange_route.text += "\n" + String.chr(0x2192) + " " + target.title
	var responder: int = p.player if p != null else view.deciding
	var decision: StringName = p.kind if p != null else view.deciding_kind
	if a.is_empty():
		exchange_state.text = "RESPONSE WINDOW" if decision == &"respond" else "RESOLVING"
	exchange_response.visible = responder >= 0 and responder < view.players.size()
	if exchange_response.visible:
		var who: String = "You" if responder == view.seat else view.player(responder).name
		match decision:
			&"defense":
				exchange_response.text = who + " may defend"
			&"respond":
				exchange_response.text = who + " may respond"
				if not a.is_empty() and announced != null and not announced.hidden() and announced.uid != int(a.get("source", -1)):
					exchange_response.text += " to " + announced.title
			&"endurance":
				exchange_response.text = who + " may use Endurance"
			_:
				exchange_response.text = who + " choosing"
		exchange_response.add_theme_color_override("font_color", ZenithTheme.DEFEND if responder == view.seat else ZenithTheme.MUTED)
	_damage_available = not a.is_empty() and not (decision == &"respond" and announced != null and announced.uid != int(a.get("source", -1)))
	exchange_damage.visible = _damage_available
	if stopped:
		var stopper: String = str(a.get("stopped_by_title", ""))
		exchange_damage.text = "Stopped" + (" by " + stopper if not stopper.is_empty() else "")
	elif landed:
		exchange_damage.text = "Dealt: " + _amount(int(a.get("stages_dealt", 0)), int(a.get("life_dealt", 0)))
		var remaining: int = int(a.get("life_remaining", 0))
		if remaining > 0:
			exchange_damage.text += "\n%s still to resolve" % _wounds(remaining)
	else:
		var damage: Dictionary = a.get("damage", {})
		var label: String = "Incoming: " if int(a.get("defender", -1)) == view.seat else "Deals: "
		exchange_damage.text = label + _amount(int(damage.get("stages", 0)), int(damage.get("wounds", damage.get("life", 0))))
	exchange_damage.add_theme_color_override("font_color", ZenithTheme.DEFEND if stopped else ZenithTheme.TEXT)
	var details: PackedStringArray = PackedStringArray()
	if not a.is_empty() and not stopped and not landed:
		if bool(a.get("empowered", false)):
			details.append("Empowered")
		if bool(a.get("unstoppable", false)):
			details.append("Cannot be stopped")
		else:
			var needed: int = int(a.get("stops_needed", 1))
			var done: int = int(a.get("stop_count", 0))
			if needed > 1 or done > 0:
				details.append("Stops %d / %d | %d more needed" % [done, needed, maxi(0, needed - done)])
		if bool(a.get("no_prevent", false)):
			details.append("Damage cannot be prevented")
	if stopped and int(a.get("stop_count", 0)) > 0:
		details.append("Stops %d / %d | complete" % [int(a.get("stop_count", 0)), int(a.get("stops_needed", 1))])
	if not _damage_available:
		details.clear()
	exchange_stops.text = "\n".join(details)
	exchange_stops.visible = not details.is_empty()
	_reserve_status_height()
	_compact_prompt()


func _reserve_status_height() -> void:
	# Both labels keep a one-line floor. Measuring a wrapping label before its parent has
	# width makes a one-line result hundreds of pixels tall and can push the actions off-screen.
	exchange_damage.custom_minimum_size.y = DECISION_RESULT_HEIGHT
	prompt_outcome.custom_minimum_size.y = DECISION_RESULT_HEIGHT


func _wounds(amount: int) -> String:
	return tr_n("%d wound", "%d wounds", amount) % amount


## Only the parts that are not zero: "5 wounds", "3 Energy", "3 Energy, 2 wounds", "no damage".
func _amount(stages: int, wounds: int) -> String:
	return CardText.damage_amount(maxi(0, stages), maxi(0, wounds))


## The question the panel asks. A defence names the attack it answers, from the public attack.
func _prompt_title(p: PromptView, view: SeatView) -> String:
	if p.kind == &"defense" and view != null and not view.attack.is_empty():
		return "Defend against %s?" % attack_name(view.attack)
	return p.title


## "Enrys' Sword Thrust", "Caedan Vale's Final Strike", "Dame Alder's Power", from public fields.
static func attack_name(a: Dictionary) -> String:
	var performer: String = str(a.get("performer_title", ""))
	var source: String = str(a.get("source_title", ""))
	var kind: String = "Art" if str(a.get("kind", "strike")) == "art" else "Strike"
	if bool(a.get("is_final", false)):
		kind = "Final Strike"
	elif bool(a.get("is_power", false)):
		kind = "Power"
	elif not source.is_empty():
		return source
	if performer.is_empty():
		return "the " + kind
	return "%s%s %s" % [performer, "'" if performer.ends_with("s") else "'s", kind]


func _show_last_exchange(result: Dictionary) -> void:
	exchange_rail.show()
	exchange_state.text = "LAST EXCHANGE / RESOLVED"
	exchange_state.add_theme_color_override("font_color", ZenithTheme.MUTED)
	exchange_route.text = str(result.get("source_title", ""))
	if exchange_route.text.is_empty():
		exchange_route.text = str(result.get("performer_title", "Attack")) + (" power" if bool(result.get("is_power", false)) else "")
	exchange_route.tooltip_text = str(result.get("target_title", ""))
	exchange_response.hide()
	exchange_stops.hide()
	_damage_available = true
	exchange_damage.show()
	if bool(result.get("stopped", false)):
		var stopper: String = str(result.get("stopped_by_title", ""))
		exchange_damage.text = "Last: stopped"
		exchange_damage.tooltip_text = "Stopped by " + stopper if not stopper.is_empty() else ""
		exchange_damage.add_theme_color_override("font_color", ZenithTheme.DEFEND)
	else:
		exchange_damage.text = "Last: dealt " + _amount(int(result.get("stages_dealt", 0)), int(result.get("life_dealt", 0)))
		exchange_damage.add_theme_color_override("font_color", ZenithTheme.MUTED)
	_compact_prompt()


## The outcome of the option a hand or table card would take, when it carries one (defending
## with that card, for instance). {} when the card has no such option.
func _card_outcome(uid: int) -> Dictionary:
	if _current_prompt == null:
		return {}
	for o in _current_prompt.options_for_card(uid):
		if not o.outcome.is_empty():
			return o.outcome
	return {}


## Referee-provided choice outcomes are previews, never replacements for public damage.
func _preview_outcome(outcome: Dictionary) -> void:
	if not prompt_outcome.visible:
		_exchange_before_preview = exchange_rail.visible
	var previewing: bool = outcome.has("stages") or outcome.has("stopped") or outcome.has("life")
	# With no damage line to swap with, a reserved preview row stays up empty between hovers.
	prompt_outcome.visible = previewing or (_reserve_outcome and not _damage_available)
	exchange_rail.visible = true if prompt_outcome.visible else _exchange_before_preview
	exchange_damage.visible = _damage_available and not previewing
	if not previewing:
		prompt_outcome.text = ""
		return
	var stopped: bool = bool(outcome.get("stopped", false))
	if stopped:
		prompt_outcome.text = "Preview: attack stopped"
	elif outcome.has("stages"):
		prompt_outcome.text = "Preview: " + _amount(int(outcome.get("stages", 0)), int(outcome.get("life", 0)))
	else:
		prompt_outcome.text = "Preview: %s" % _wounds(int(outcome.get("life", 0)))
	prompt_outcome.add_theme_color_override("font_color", ZenithTheme.DEFEND)


## "Table 4 (E vs B)  ·  +4 stages Relentless Fury", the total, then what has been dealt so far.
func _damage_text(view: SeatView) -> String:
	var a: Dictionary = view.attack
	if a.is_empty():
		return ""
	var d: Dictionary = a.get("damage", {})
	var strong: String = ZenithTheme.TEXT.to_html(false)
	var muted: String = ZenithTheme.MUTED.to_html(false)
	var lines: PackedStringArray = PackedStringArray()
	if bool(a.get("stopped", false)):
		lines.append("[color=%s]Stopped.[/color]" % ZenithTheme.DEFEND.to_html(false))
	elif not d.is_empty():
		var landed: bool = bool(a.get("landed", false))
		var stages: int = int(a.get("stages", 0)) if landed else int(d.get("stages", 0))
		var life: int = int(a.get("life", 0)) if landed else int(d.get("life", 0))
		var total: String = CardText.damage_amount(stages, life)
		lines.append("[color=%s]%s[/color] [color=%s]%s[/color]" % [muted, "Lands for" if landed else "If it lands:", strong, total])
		lines.append("[color=%s]%s[/color]" % [muted, "  ·  ".join(CardText.breakdown_steps(d))])
	var dealt_stages: int = int(a.get("stages_dealt", 0))
	var dealt_life: int = int(a.get("life_dealt", 0))
	if dealt_stages > 0 or dealt_life > 0:
		var dealt: String = "[color=%s]Dealt[/color] [color=%s]%s[/color]" % [muted, strong, CardText.damage_amount(dealt_stages, dealt_life)]
		if int(a.get("life_remaining", 0)) > 0:
			dealt += "[color=%s], %d more to flip[/color]" % [muted, int(a["life_remaining"])]
		lines.append(dealt)
	return "\n".join(lines)


func _hint_for(p: PromptView) -> String:
	var card_options: int = p.card_uids().size()
	match p.kind:
		&"reserve":
			return "Each one swaps with a random card from your Life Deck."
		&"non_combat":
			return "Click a highlighted card, then Done." if card_options > 0 else ""
		&"combat_end":
			return "Combat is over. These may still be used."
		&"start_play":
			return "This may start the game on the table."
		&"keep":
			return "Everything else goes to the discard pile."
		&"endurance":
			return "Spending it removes it from the game."   # the one thing the number cannot say
		&"recover":
			return "One discard card may go back under the deck."
		&"respond":
			if str(p.context.get("mode", "")) == "declare":
				return "Use a card before they decide on Combat."
			if bool(p.context.get("ally_window", false)):
				if not bool(p.context.get("can_counter", true)):
					return "One Ally may take control before any of it happens."
				return "Counter it, or put one Ally in control first."
			return "Counter it now, or let it resolve."
		&"pay":
			if bool(p.context.get("life_cost", false)):
				return "The extra damage costs the top card of your Life Deck."
			return "Each step paid adds to the wounds."
		&"discard_choice":
			var whose: String = "your opponent's hand" if int(p.context.get("target", p.player)) != p.player else "your hand"
			return "Pick the cards that leave %s." % whose if p.has_batch() else "Pick the card that leaves %s." % whose
		&"pick_in_play":
			return "Pick the card in play the effect hits."
		&"pick_discard":
			return "Cards removed here are out of the game for good."
		&"name_card":
			return "It cannot be played while the Drill stays out."
		&"pick_option":
			if bool(p.context.get("may", false)):
				var text: String = str(p.context.get("text", ""))
				return "%s\nSkip it and the rest of the card still resolves." % text if text != "" else "Skip it and the rest of the card still resolves."
			return ""
		_:
			return ""


## Online: the other player is deciding. The panel says who and roughly what, with no options.
func show_waiting(player_name: String, kind: StringName, view: SeatView) -> void:
	prompt_panel.show()
	_center_prompt_text(true)
	_view = view
	_current_prompt = null
	_reserve_outcome = false
	prompt_who.text = "%s  ·  DECIDING" % player_name.to_upper()
	prompt_who.add_theme_color_override("font_color", ZenithTheme.MUTED)
	prompt_title.text = "Waiting for %s" % player_name
	_show_attack(view, null)
	prompt_who.visible = not exchange_rail.visible
	if exchange_rail.visible:
		prompt_title.text = "Opponent deciding"
	# Whatever they are deciding about, this seat is looking at the same card and the same count.
	show_focus(_focus_uid(null), _focus_caption(null))
	prompt_hint.text = _waiting_hint(kind)
	prompt_hint.visible = prompt_hint.text != ""
	_compact_prompt()
	_hide_tray()
	_fill_buttons([], primary_box, true)


## What the other player is doing, in terms that give nothing hidden away.
func _waiting_hint(kind: StringName) -> String:
	match kind:
		&"reserve":
			return "They are setting up their Reserve."
		&"non_combat":
			return "They may place cards before Combat."
		&"combat_end":
			return "They may use a card as Combat ends."
		&"start_play":
			return "They are setting up the table."
		&"declare":
			return "They are deciding whether to enter Combat."
		&"attack_action":
			return "They are choosing an attack, or passing."
		&"endurance":
			# The flipped card is in a public pile, so naming the decision gives nothing away.
			return "They are deciding whether to spend it and prevent the rest."
		&"defense", &"redirect", &"control":
			return "They are answering your attack."
		&"respond":
			return "They may respond before your card resolves."
		&"keep", &"discard_choice":
			return "They are choosing what to keep."
		&"recover":
			return "They may return a card to their Life Deck."
		_:
			return "They are resolving a card."


## A panel with nothing to choose (waiting on the other player, or on the host) centres its text;
## a decision reads left-aligned above its buttons.
func _center_prompt_text(on: bool) -> void:
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER if on else HORIZONTAL_ALIGNMENT_LEFT
	for label: Label in [prompt_who, prompt_title, prompt_hint, exchange_state, exchange_route, exchange_response, exchange_damage, prompt_outcome, exchange_stops]:
		label.horizontal_alignment = align


## Online joiner: the choice went to the host and its answer is not back yet.
func show_sending() -> void:
	_reserve_outcome = false
	for child in primary_box.get_children():
		(child as Control).hide()
	_fill_buttons([], primary_box, true)
	prompt_panel.show()
	_center_prompt_text(true)
	exchange_rail.hide()
	prompt_outcome.hide()
	_hide_tray()
	prompt_who.text = ""
	prompt_title.text = "…"
	prompt_hint.text = "Sending your choice to the host."
	prompt_hint.visible = true


## One clicked card with more than one legal action: the card, its actions as buttons, and Back.
func show_card_choice(options: Array[OptionView]) -> void:
	var c: SeatCard = _view.card(options[0].card)
	var single: Array[OptionView] = [options[0]]
	# A card whose only action is a Final Strike says so up front, and the button stays quiet:
	# the player came here expecting to play the card, not to discard it and pass.
	var only_final: bool = true
	for o in options:
		if o.type != &"final_strike":
			only_final = false
	var hint: String = ""
	if only_final:
		hint = "This card cannot be played right now. A Final Strike discards it for a bare Strike from the Strike Table, and you pass for the rest of this Combat."
	await _show_tray(TRAY_WHO, c.title if c != null else "Choose an action", hint, single, options, true, null, not only_final)
	if only_final:
		tray_hint.add_theme_color_override("font_color", ZenithTheme.WARN)
	else:
		tray_hint.remove_theme_color_override("font_color")
	if c == null or c.hidden():
		return
	var def: CardDef = _def(c.def_id)
	if def == null:
		return
	var aspect: int = c.aspect
	var uid: int = c.uid
	var b: Button = Button.new()
	b.text = "Inspect"
	b.custom_minimum_size = Vector2(140, 60)
	b.pressed.connect(func() -> void: show_inspect(def, aspect, uid))
	tray_buttons.add_child(b)


## Every hand card as Final Strike fodder, with Back. Reached only through its button.
func _show_final_strike(finals: Array[OptionView]) -> void:
	await _show_tray(TRAY_WHO, "Final Strike: discard a card", "A bare Strike from the Strike Table, plus your Drills and modifiers. Afterwards you pass for the rest of this Combat.", finals, [], false)
	var back: Button = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(140, 60)
	back.pressed.connect(_on_back)
	tray_buttons.add_child(back)


func clear_prompt() -> void:
	hide_pile()
	prompt_panel.hide()
	prompt_outcome.hide()
	_current_prompt = null
	_owner_marks = {}
	hide_peek()
	prompt_who.text = ""
	prompt_title.text = "…"
	exchange_rail.hide()
	prompt_hint.visible = false
	hide_focus()
	_hide_tray()
	_fill_buttons([], primary_box, true)


## Alternatives without a card use equal emphasis; neither passing nor accepting a hit is
## presented as a recommendation. Vertical in the side panel, a row in the tray.
func _fill_buttons(options: Array[OptionView], into: Container, vertical: bool, _first_is_default: bool = false) -> void:
	if into == primary_box:
		_single_action = null
	for child in into.get_children():
		into.remove_child(child)
		child.queue_free()
	for i in range(options.size()):
		var opt: OptionView = options[i]
		var b: Button = Button.new()
		b.text = opt.label + str(_owner_marks.get(opt.card, ""))
		if into == primary_box and _current_prompt != null and _current_prompt.kind == &"endurance" and opt.type == &"endure":
			b.text = "Use Endurance"
			b.tooltip_text = opt.label + "\nRemove this card from play."
			if opt.outcome.has("life"):
				var prevented: int = maxi(0, int(_current_prompt.context.get("remaining", 0)) - int(opt.outcome["life"]))
				b.tooltip_text += "\nPrevents " + _wounds(prevented) + "."
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var text_width: float = root.get_theme_font("font", "Button").get_string_size(opt.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 48.0
		b.custom_minimum_size = Vector2(0.0 if vertical else clampf(text_width, 300.0, minf(520.0, root.size.x - 180.0)), ACTION_HEIGHT if into == primary_box else 60.0)
		b.add_theme_font_size_override("font_size", ZenithTheme.SIZE_BODY)
		b.pressed.connect(func() -> void: option_chosen.emit(opt))
		if not opt.outcome.is_empty():
			# Hovering a choice answers "what does this leave me with" on the number itself.
			b.mouse_entered.connect(func() -> void: _preview_outcome(opt.outcome))
			b.mouse_exited.connect(func() -> void: _preview_outcome({}))
			b.focus_entered.connect(func() -> void: _preview_outcome(opt.outcome))
			b.focus_exited.connect(func() -> void: _preview_outcome({}))
		into.add_child(b)
	# The action area shows itself from the box's minimum-size signal, which is deferred and only
	# fires when the size differs from the last one recorded. Buttons the same size as the ones
	# just removed leave it silent, and the panel would show its question with nothing under it.
	if into == primary_box:
		_fit_actions()


# --- Match replay ---------------------------------------------------------

## A recorded duel played back: the replay bar shows at the foot of the rail, under the decision
## it steps through, where neither the hand nor the stat crest reaches. Its turn list is filled,
## the view switch names the two players, and the result panel's way out leads to the title.
func set_match_replay(names: Array[String], turns: Array[Dictionary], view_index: int) -> void:
	_match_replay = true
	replay_bar.visible = true
	select_button.text = "Back to title"
	replay_turn.clear()
	for t in turns:
		replay_turn.add_item("Turn %d · %s" % [int(t["turn"]), names[int(t["player"])]], int(t["index"]))
		replay_turn.set_item_metadata(replay_turn.item_count - 1, int(t["turn"]))
	for choice: OptionButton in [replay_view, menu_replay_view]:
		for seat in range(2):
			choice.set_item_text(seat, names[seat])
		choice.select(view_index)


## Where the replay stands: the entry count, Play or Pause, and the turn it is in.
func set_replay_state(position: int, total: int, turn: int, playing: bool) -> void:
	replay_position.text = "%d / %d" % [position, total]
	replay_play.visible = not playing
	replay_pause.visible = playing
	replay_play.disabled = position >= total
	replay_step.disabled = position >= total
	replay_back.disabled = position <= 0
	for i in range(replay_turn.item_count):
		if int(replay_turn.get_item_metadata(i)) == turn:
			replay_turn.select(i)


func _on_replay_speed(index: int) -> void:
	for choice: OptionButton in [replay_speed, menu_replay_speed]:
		choice.select(index)
	replay_command.emit(&"speed", 1 << index)


func _on_replay_view(index: int) -> void:
	for choice: OptionButton in [replay_view, menu_replay_view]:
		choice.select(index)
	replay_command.emit(&"view", index)


## A recorded decision, read only: the question as its player saw it, every option they had as a
## row that takes no input, and the one they took lit. `who` heads it; `gap_ms` is how long they
## took over it.
func show_replay_decision(p: PromptView, view: SeatView, entry: Dictionary, who: String, gap_ms: int) -> void:
	hide_pile()
	prompt_panel.show()
	_center_prompt_text(false)
	_view = view
	_current_prompt = p
	_owner_marks = CardText.option_side_marks(p, p.player)
	prompt_who.text = who
	prompt_who.add_theme_color_override("font_color", ZenithTheme.MUTED)
	prompt_title.text = _prompt_title(p, view)
	_show_attack(view, p)
	show_focus(_focus_uid(p), _focus_caption(p))
	prompt_hint.text = "Took %.1f s" % (gap_ms / 1000.0) if gap_ms > 0 else ""
	_reserve_outcome = false
	_preview_outcome({})
	_compact_prompt()
	_hide_tray()
	_fill_buttons([], primary_box, true)
	var taken: Command = Command.from_dict(entry)
	var batch: Array[int] = []
	if entry.get("value") is Array:
		for uid in (entry["value"] as Array):
			batch.append(int(uid))
	var lit: Button = null
	if p.has_batch() and taken.type == p.batch_type and entry.get("value") is Array:
		lit = _recorded_row(p.batch_option(batch).label, true)
	for opt in p.options:
		var chosen: bool = taken.matches(opt.to_command(p.player)) or (opt.type == taken.type and batch.has(opt.card))
		var row: Button = _recorded_row(opt.label + str(_owner_marks.get(opt.card, "")), chosen)
		if chosen and lit == null:
			lit = row
	_fit_actions()
	if lit != null:
		_scroll_to_row(lit)


## Scrolls a long option list to the row taken, once it is laid out and while it is still listed:
## a replay playing on can clear the panel before then.
func _scroll_to_row(row: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(row) and actions_scroll.is_ancestor_of(row):
		actions_scroll.ensure_control_visible(row)


func _recorded_row(text: String, lit: bool) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0.0, ACTION_HEIGHT)
	b.add_theme_font_size_override("font_size", ZenithTheme.SIZE_BODY)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lit:
		b.theme_type_variation = &"AccentButton"
	else:
		b.disabled = true
	primary_box.add_child(b)
	return b


## The end of a replay on the decision panel, with the table still up behind it: who won and how,
## a concession, a clock or a drop included.
func show_replay_result(title: String, reason: String) -> void:
	hide_pile()
	prompt_panel.show()
	_center_prompt_text(true)
	_current_prompt = null
	exchange_rail.hide()
	prompt_outcome.hide()
	_hide_tray()
	_fill_buttons([], primary_box, true)
	prompt_who.text = "RESULT"
	prompt_who.add_theme_color_override("font_color", ZenithTheme.MUTED)
	prompt_title.text = title
	prompt_hint.text = reason
	# A duel can end with wounds still owed; the result, not the attack left pending, is the read.
	hide_focus()


## A replay this client cannot play: the result panel says why, with only the way back to the title.
func show_replay_refused(reason: String) -> void:
	show_game_over("Cannot play this replay", reason, false)
	select_button.text = "Back to title"


func clear_log() -> void:
	log_text.clear()
	_log_lines = 0


## A replay's full view: the other seat's hand face up along the top edge, since the fan beside
## their crest only ever draws backs. Hovering a card reads it in the quick view. [] hides it.
func show_far_hand(cards: Array[SeatCard], faces: CardFaceCache) -> void:
	for child in far_hand.get_children():
		far_hand.remove_child(child)
		child.queue_free()
	for c in cards:
		var def: CardDef = _def(c.def_id)
		if def == null:
			continue
		var face: TextureRect = TextureRect.new()
		face.texture = faces.face(def, c.aspect, seat_backdrop(c.owner), c.owner)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.custom_minimum_size = FAR_HAND_CARD
		var uid: int = c.uid
		var aspect: int = c.aspect
		face.mouse_entered.connect(func() -> void: show_peek(def, aspect, uid))
		face.mouse_exited.connect(hide_peek)
		face.gui_input.connect(func(event: InputEvent) -> void:
			if _is_inspect_click(event):
				show_inspect(def, aspect, uid))
		far_hand.add_child(face)
	far_hand.visible = far_hand.get_child_count() > 0


# --- Tray -----------------------------------------------------------------

## A centred browser over the table: one face per card option with the action as its caption,
## the no-card options as a button row beneath, and Back when this is a sub-choice. `actions`
## become the buttons; with `sub_choice` they act on the single card shown. With `batch`, clicks
## toggle cards and one confirm button sends them all at once.
func _show_tray(who: String, title: String, hint: String, cards: Array[OptionView], actions: Array[OptionView], sub_choice: bool, batch: PromptView = null, accent_first: bool = true, extra: int = 0) -> void:
	_batch = batch
	_selected.clear()
	_entries.clear()
	hide_pile()
	hide_peek()
	hide_focus()   # the tray is the middle of the screen while it is open
	tray_who.text = who
	tray_who.add_theme_color_override("font_color", _who_color)
	tray_title.text = title
	if batch != null:
		var rule: String = "Pick %d." % batch.batch_max if batch.batch_min == batch.batch_max else "Pick up to %d." % batch.batch_max
		hint = (hint + "  " + rule).strip_edges()
	tray_hint.text = hint
	tray_hint.visible = hint != ""
	for child in tray_cards.get_children():
		tray_cards.remove_child(child)
		child.queue_free()
	_tray_face = tray_layout(cards.size() + extra, root.size)["face"]
	for opt in cards:
		var entry: Control = await _tray_entry(opt, sub_choice)
		if entry != null:
			tray_cards.add_child(entry)
	var wordings: bool = not cards.is_empty()
	for opt in cards:
		wordings = wordings and opt.type == &"pick_option" and opt.card < 0
	_size_tray_scroll(cards.size() + extra, CHOICE_HEIGHT + TRAY_FRAME.x if wordings else -1.0)
	_fill_buttons(actions, tray_buttons, false, sub_choice and accent_first)
	if batch != null:
		_confirm = Button.new()
		_confirm.theme_type_variation = &"AccentButton"
		_confirm.custom_minimum_size = Vector2(200, 60)
		_confirm.add_theme_font_size_override("font_size", ZenithTheme.SIZE_BODY)
		_confirm.pressed.connect(func() -> void:
			if _selected.size() >= _batch.batch_min:
				option_chosen.emit(_batch.batch_option(_selected)))
		tray_buttons.add_child(_confirm)
		tray_buttons.move_child(_confirm, 0)
		_refresh_selection()
	if sub_choice:
		var back: Button = Button.new()
		back.text = "Back"
		back.custom_minimum_size = Vector2(140, 60)
		back.pressed.connect(_on_back)
		tray_buttons.add_child(back)
	tray.visible = true
	prompt_panel.visible = false
	hand.visible = false


## The rest of a searched Life Deck, after the pickable matches: one dimmed face per card title
## with how many copies are in the deck. They can be read and hovered, not picked.
func _add_library(library: Array, matches: Array[OptionView]) -> void:
	var listed: Dictionary = {}
	for opt in matches:
		var m: SeatCard = _view.card(opt.card)
		if m != null and not m.hidden():
			listed[m.def_id] = true
	var counts: Dictionary = {}
	var first: Dictionary = {}
	var order: Array[String] = []
	for uid in library:
		var c: SeatCard = _view.card(int(uid))
		if c == null or c.hidden():
			continue
		if not counts.has(c.def_id):
			order.append(c.def_id)
			first[c.def_id] = c
		counts[c.def_id] = int(counts.get(c.def_id, 0)) + 1
	for def_id in order:
		if listed.has(def_id):
			continue
		var c: SeatCard = first[def_id]
		var def: CardDef = _def(def_id)
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		var face: TextureRect = TextureRect.new()
		face.texture = await _faces.render_face(def, c.aspect, seat_backdrop(c.owner), c.owner) if def != null and _faces != null else null
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.custom_minimum_size = _tray_face
		face.modulate = Color(1, 1, 1, 0.45)
		face.mouse_filter = Control.MOUSE_FILTER_STOP
		face.mouse_entered.connect(func() -> void: show_peek(def, c.aspect, c.uid))
		face.mouse_exited.connect(func() -> void: hide_peek())
		column.add_child(face)
		var caption: Label = Label.new()
		caption.text = "In deck ×%d" % int(counts[def_id])
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_color_override("font_color", ZenithTheme.MUTED)
		column.add_child(caption)
		tray_cards.add_child(column)
	_size_tray_scroll(tray_cards.get_child_count())


## How a tray of `count` faces is laid out on a `screen` of that size: the face size, the columns
## and the rows shown before it scrolls. A short tray widens its faces to share the room one row
## has, from TRAY_CARD_SIZE up to TRAY_CARD_MAX_WIDTH and never taller than the rows shown allow.
## Rows are balanced, so seven cards sit four and three rather than six and one.
static func tray_layout(count: int, screen: Vector2) -> Dictionary:
	var room: float = screen.x - TRAY_SIDE_ROOM
	var n: int = maxi(1, count)
	var fit: int = clampi(int((room + TRAY_GAP) / (TRAY_CARD_SIZE.x + TRAY_FRAME.x + TRAY_GAP)), 1, TRAY_COLUMNS)
	var rows: int = ceili(float(n) / fit)
	var columns: int = ceili(float(n) / rows)
	var shown_rows: int = mini(rows, TRAY_ROWS_SHOWN)
	var across: float = (room - TRAY_GAP * (columns - 1)) / columns - TRAY_FRAME.x
	var down: float = (screen.y * TRAY_HEIGHT_SHARE / shown_rows - TRAY_GAP - TRAY_FRAME.y) / CARD_ASPECT
	var width: float = clampf(minf(across, down), TRAY_CARD_SIZE.x, TRAY_CARD_MAX_WIDTH)
	return {"face": Vector2(width, width * CARD_ASPECT), "columns": columns, "rows": shown_rows}


## The tray's scroll area: exactly the balanced columns across, so the flow wraps where the layout
## says, and the rows shown down. `cell_height` replaces a face's height for a tray of wordings.
func _size_tray_scroll(count: int, cell_height: float = -1.0) -> void:
	var grid: Dictionary = tray_layout(count, root.size)
	var cell: Vector2 = (grid["face"] as Vector2) + TRAY_FRAME
	if cell_height > 0.0:
		cell.y = cell_height
	var columns: int = int(grid["columns"])
	var rows: int = int(grid["rows"])
	tray_scroll.custom_minimum_size = Vector2(maxf(720.0, columns * (cell.x + TRAY_GAP) + TRAY_GAP), minf(rows * (cell.y + TRAY_GAP), root.size.y * TRAY_HEIGHT_SHARE))


## Toggles a card in a batch tray. Full trays ignore further picks until one is removed.
func tray_toggle(uid: int) -> void:
	if _batch == null:
		return
	if _selected.has(uid):
		_selected.erase(uid)
	elif _selected.size() < _batch.batch_max:
		_selected.append(uid)
	_refresh_selection()


func _refresh_selection() -> void:
	for uid in _entries.keys():
		var e: Dictionary = _entries[uid]
		var on: bool = _selected.has(uid)
		(e["frame"] as PanelContainer).add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), ZenithTheme.ACCENT if on else Color(0, 0, 0, 0), ZenithTheme.RADIUS, 3, 3, 3))
		(e["caption"] as Label).text = "Selected" if on else str(e["verb"])
		(e["caption"] as Label).add_theme_color_override("font_color", ZenithTheme.ACCENT if on else ZenithTheme.MUTED)
	if _confirm != null:
		var n: int = _selected.size()
		_confirm.text = "%s %d" % [_batch.batch_verb(), n] if n > 0 else _batch.batch_verb()
		_confirm.disabled = n < _batch.batch_min


func _hide_tray() -> void:
	hide_peek()
	# Opening the tray hid the decision panel behind it. Closing it has to put the panel back
	# while a decision is still pending, or the player is left with a prompt and nothing on
	# screen to answer it with. It only ever turns the panel on: the callers that mean to leave
	# it hidden clear the prompt first.
	if tray.visible and _current_prompt != null:
		prompt_panel.visible = true
	tray.visible = false
	hand.visible = not external_hand
	_batch = null
	_confirm = null
	_selected.clear()
	_entries.clear()


## A face with its caption. Clicking the face picks the option unless it is a sub-choice, where
## the buttons decide. Named-card options carry a title instead of a uid and draw from the library.
## A choice with no card behind it, shown at card size with its wording set in the middle, so the
## two halves of "all their Allies or all their Drills" are read side by side and weighed like cards.
func _tray_choice_entry(opt: OptionView) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.BORDER, ZenithTheme.RADIUS, 3, 3, 3))
	frame.pivot_offset = _tray_face * 0.5 + Vector2(3.0, 3.0)
	var b: Button = Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(_tray_face.x, CHOICE_HEIGHT)
	b.text = opt.label
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = false
	b.add_theme_font_size_override("font_size", ZenithTheme.SIZE_BODY)
	b.add_theme_color_override("font_color", ZenithTheme.TEXT)
	b.pressed.connect(func() -> void: option_chosen.emit(opt))
	b.mouse_entered.connect(func() -> void:
		frame.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.ACCENT, ZenithTheme.RADIUS, 3, 3, 3))
		_lift(frame, true))
	b.mouse_exited.connect(func() -> void:
		frame.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.BORDER, ZenithTheme.RADIUS, 3, 3, 3))
		_lift(frame, false))
	frame.add_child(b)
	column.add_child(frame)
	return column


func _tray_entry(opt: OptionView, sub_choice: bool) -> Control:
	if opt.type == &"pick_option" and opt.card < 0:
		return _tray_choice_entry(opt)
	var def: CardDef = null
	var aspect: int = 0
	var uid: int = opt.card
	if opt.type == &"name_card":
		def = _def_by_title(str(opt.value))
	else:
		var c: SeatCard = _view.card(opt.card)
		if c != null and not c.hidden():
			def = _def(c.def_id)
			aspect = c.aspect
	var tex: Texture2D = null
	if def != null and _faces != null:
		tex = await _faces.render_face(def, aspect, _uid_backdrop(uid), _uid_owner(uid))
	elif _faces != null:
		tex = _faces.back()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), ZenithTheme.RADIUS, 3, 3, 3))
	frame.pivot_offset = _tray_face * 0.5 + Vector2(3.0, 3.0)
	var b: TextureButton = TextureButton.new()
	b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.custom_minimum_size = _tray_face
	var batch: bool = _batch != null
	if batch:
		b.pressed.connect(func() -> void: tray_toggle(uid))
	elif not sub_choice:
		b.pressed.connect(func() -> void: option_chosen.emit(opt))
	b.mouse_entered.connect(func() -> void:
		if not _selected.has(uid):
			frame.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), ZenithTheme.HOVER, ZenithTheme.RADIUS, 3, 3, 3))
		_lift(frame, true)
		show_peek(def, aspect, uid)
		if uid >= 0:
			card_hovered.emit(uid, true))
	b.mouse_exited.connect(func() -> void:
		if not _selected.has(uid):
			frame.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), ZenithTheme.RADIUS, 3, 3, 3))
		_lift(frame, false)
		hide_peek()
		if uid >= 0:
			card_hovered.emit(uid, false))
	b.focus_entered.connect(func() -> void: b.mouse_entered.emit())
	b.focus_exited.connect(func() -> void: b.mouse_exited.emit())
	b.gui_input.connect(func(event: InputEvent) -> void:
		if _is_inspect_click(event):
			show_inspect(def, aspect, uid))
	frame.add_child(b)
	column.add_child(frame)
	# Two faces in one tray can be the same card of the same character on opposite sides of the
	# table. The marker says which is which, and appears only when the labels would read alike.
	var mark: String = str(_owner_marks.get(uid, ""))
	if mark != "":
		b.tooltip_text = opt.label + mark
	if not sub_choice:
		var verb: String = str(TRAY_VERBS.get(opt.type, opt.label)) + mark
		var caption: Label = Label.new()
		caption.text = verb
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", ZenithTheme.SIZE_BODY)
		caption.add_theme_color_override("font_color", ZenithTheme.MUTED if batch else ZenithTheme.ACCENT)
		column.add_child(caption)
		if batch:
			_entries[uid] = {"frame": frame, "caption": caption, "verb": verb}
	return column


func _def_by_title(title: String) -> CardDef:
	for def in Session.library.defs.values():
		if (def as CardDef).title == title:
			return def
	return null


func _on_back() -> void:
	if _current_prompt != null:
		show_prompt(_current_prompt, _view)


func _def(def_id: String) -> CardDef:
	return Session.library.defs.get(def_id)


# --- Pile browser ---------------------------------------------------------

## Reads a public pile the way a Life Deck search reads a deck: every card in it, top first,
## with nothing to pick. Discard and Removed are open to both seats, so either seat may open
## either player's pile at any time.
func show_pile(view: SeatView, player: int, zone: StringName) -> void:
	_view = view
	_pile_player = player
	_pile_zone = zone
	var p: SeatPlayer = view.player(player)
	_pile_uids = pile_contents(p, zone)
	pile_who.text = "%s  ·  %s" % [p.name.to_upper(), "YOU" if player == _viewer_seat else "OPPONENT"]
	pile_who.add_theme_color_override("font_color", SeatColors.accent(view, player, Session.color_seed))
	pile_title.text = "Removed from play" if zone == &"removed" else ("Relic and Reserve" if zone == &"relic" else "Discard pile")
	var n: int = _pile_uids.size()
	if n == 0:
		pile_hint.text = "This pile is empty."
	elif zone == &"relic":
		pile_hint.text = _relic_pile_hint(view, p)
	else:
		pile_hint.text = "%d card%s, top of the pile first.  Right-click a card to read it." % [n, "" if n == 1 else "s"]
	pile.visible = true
	await _fill_pile()


func hide_pile() -> void:
	pile.visible = false
	_pile_zone = &""
	_pile_player = -1
	_pile_uids.clear()
	hide_peek()


## A pile top first: Discard keeps its top at the end of the list, Removed has no order that
## matters, and both read most recent first. The Relic pile is the Relic, then its Reserve.
func pile_contents(p: SeatPlayer, zone: StringName) -> Array[int]:
	if zone == &"relic":
		var held: Array[int] = []
		if p.relic >= 0:
			held.append(p.relic)
		held.append_array(p.reserve)
		return held
	var uids: Array[int] = (p.removed if zone == &"removed" else p.discard).duplicate()
	uids.reverse()
	return uids


## What the Relic pile holds, in words. Reserve cards the view keeps hidden are not drawn in the
## browser, so the hint counts them instead of naming them.
func _relic_pile_hint(view: SeatView, p: SeatPlayer) -> String:
	var face_down: int = 0
	for uid in p.reserve:
		var c: SeatCard = view.card(uid)
		if c == null or c.hidden():
			face_down += 1
	var parts: PackedStringArray = PackedStringArray()
	parts.append("The Relic first" if p.relic >= 0 else "No Relic")
	if p.reserve.is_empty():
		parts.append("no Reserve")
	else:
		parts.append("then %d Reserve card%s" % [p.reserve.size(), "" if p.reserve.size() == 1 else "s"])
	var text: String = ", ".join(parts) + "."
	if face_down > 0:
		text += "  %d face down, not shown." % face_down
	return text + "  Right-click a card to read it."


## A usable Relic's pile, clicked: the action sub-choice a hand card opens, with a single use
## named "Use it", and "Inspect Reserve" in place of Inspect, which opens the Relic pile.
func show_relic_choice(options: Array[OptionView], player: int) -> void:
	var c: SeatCard = _view.card(options[0].card)
	var single: Array[OptionView] = [options[0]]
	await _show_tray(TRAY_WHO, c.title if c != null else "Relic", "", single, options, true)
	tray_hint.remove_theme_color_override("font_color")
	if options.size() == 1 and tray_buttons.get_child_count() > 0:
		var use: Button = tray_buttons.get_child(0) as Button
		if use != null:
			use.tooltip_text = use.text
			use.text = "Use it"
	var browse: Button = Button.new()
	browse.text = "Inspect Reserve"
	browse.custom_minimum_size = Vector2(200, 60)
	browse.pressed.connect(func() -> void:
		_on_back()
		show_pile(_view, player, &"relic"))
	tray_buttons.add_child(browse)


## Redraws an open browser when its pile changes under it, and leaves it alone when it has not.
func _sync_pile() -> void:
	if not pile.visible or _pile_zone == &"" or _view == null or _pile_player < 0:
		return
	if pile_contents(_view.player(_pile_player), _pile_zone) == _pile_uids:
		return
	show_pile(_view, _pile_player, _pile_zone)


func _fill_pile() -> void:
	_pile_fill += 1
	var fill: int = _pile_fill
	for child in pile_cards.get_children():
		pile_cards.remove_child(child)
		child.queue_free()
	for i in range(_pile_uids.size()):
		var c: SeatCard = _view.card(_pile_uids[i])
		if c == null or c.hidden():
			continue
		var entry: Control = await _pile_entry(c, i == 0)
		if fill != _pile_fill:
			return   # a newer fill owns the container now
		pile_cards.add_child(entry)
	var shown: int = pile_cards.get_child_count()
	var columns: int = maxi(1, mini(TRAY_COLUMNS, int((root.size.x - 180.0) / (TRAY_CARD_SIZE.x + 18.0))))
	var cols: int = mini(maxi(shown, 1), columns)
	var rows: int = mini(maxi(ceili(float(shown) / columns), 1), PILE_ROWS_SHOWN)
	var cell: Vector2 = TRAY_CARD_SIZE + Vector2(6.0, 6.0 + 6.0 + 20.0)
	pile_scroll.custom_minimum_size = Vector2(maxf(720.0, cols * (cell.x + 12.0) + 12.0), minf(rows * (cell.y + 12.0), root.size.y * 0.57))


## One card in a browsed pile: the face at full strength, hover for the expanded rules,
## right-click to bring it up. Nothing here is clickable, because nothing here is a choice.
func _pile_entry(c: SeatCard, is_top: bool) -> Control:
	var def: CardDef = _def(c.def_id)
	var aspect: int = c.aspect
	var uid: int = c.uid
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var face: TextureRect = TextureRect.new()
	face.texture = await _faces.render_face(def, aspect, seat_backdrop(c.owner), c.owner) if def != null and _faces != null else null
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.custom_minimum_size = TRAY_CARD_SIZE
	face.mouse_filter = Control.MOUSE_FILTER_STOP
	face.mouse_entered.connect(func() -> void: show_peek(def, aspect, uid))
	face.mouse_exited.connect(func() -> void: hide_peek())
	face.gui_input.connect(func(event: InputEvent) -> void:
		if _is_inspect_click(event):
			show_inspect(def, aspect, uid))
	column.add_child(face)
	var caption: Label = Label.new()
	caption.text = "Top" if is_top else ""
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
	caption.add_theme_color_override("font_color", ZenithTheme.ACCENT if is_top else ZenithTheme.MUTED)
	column.add_child(caption)
	return column


# --- Hand -----------------------------------------------------------------

func set_hand(cards: Array[SeatCard], faces: CardFaceCache, legal: Dictionary) -> void:
	_faces = faces
	if external_hand:
		hand.hide()
		return
	for child in hand.get_children():
		child.queue_free()
	for c in cards:
		var def: CardDef = _def(c.def_id)
		if def == null:
			continue
		var is_legal: bool = legal.get(c.uid, false)
		var frame: PanelContainer = PanelContainer.new()
		var border: Color = ZenithTheme.ACCENT if is_legal else Color(0, 0, 0, 0)
		frame.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), border, ZenithTheme.RADIUS, 3, 3, 3))
		frame.pivot_offset = Vector2(HAND_CARD_SIZE.x * 0.5 + 3.0, HAND_CARD_SIZE.y + 6.0)
		var b: TextureButton = TextureButton.new()
		b.texture_normal = faces.face(def, c.aspect, seat_backdrop(c.owner), c.owner)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.custom_minimum_size = HAND_CARD_SIZE
		b.modulate = Color(1, 1, 1, 1) if is_legal else Color(0.6, 0.6, 0.6, 1)
		var uid: int = c.uid
		var aspect: int = c.aspect
		# What this attack would deal right now, worked out by the referee: the sum after the
		# table and every modifier, so the player compares totals rather than printed bonuses.
		var forecast: Dictionary = _view.forecast(uid) if _view != null else {}
		if not forecast.is_empty():
			# A card that can only be thrown away for a Final Strike says so, quietly.
			var final: bool = bool(forecast.get("is_final", false))
			var chip: Label = Label.new()
			chip.text = ("Final: " if final else "") + CardText.short_damage(int(forecast.get("stages", 0)), int(forecast.get("life", 0)))
			chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
			chip.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.RAISED_STRONG if final else ZenithTheme.ATTACK, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 6, 0))
			chip.add_theme_color_override("font_color", ZenithTheme.MUTED if final else ZenithTheme.TEXT_DARK)
			chip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			chip.offset_left = 8.0
			chip.offset_right = -8.0
			chip.offset_top = -36.0
			chip.offset_bottom = -8.0
			b.add_child(chip)
		b.pressed.connect(func() -> void: card_clicked.emit(uid))
		b.gui_input.connect(func(event: InputEvent) -> void:
			if _is_inspect_click(event):
				show_inspect(def, aspect, uid))
		b.mouse_entered.connect(func() -> void:
			card_hovered.emit(uid, true)
			show_peek(def, aspect, uid)
			_preview_outcome(_card_outcome(uid))
			_lift(frame, true))
		b.mouse_exited.connect(func() -> void:
			_preview_outcome({})
			card_hovered.emit(uid, false)
			hide_peek()
			_lift(frame, false))
		frame.add_child(b)
		hand.add_child(frame)


## The in-scene hand owns expansion; this keeps its outcome preview in the decision area.
func preview_hand_card(uid: int, over: bool) -> void:
	card_hovered.emit(uid, over)
	_preview_outcome(_card_outcome(uid) if over else {})
	if not external_hand and over and _view != null:
		var card: SeatCard = _view.card(uid)
		if card != null and not card.hidden():
			show_peek(_def(card.def_id), card.aspect, uid)
	elif not over:
		hide_peek()


func hand_forecast(uid: int) -> String:
	return _forecast_text(uid)


func _lift(frame: Control, up: bool) -> void:
	if reduced_motion_toggle.button_pressed:
		frame.scale = Vector2.ONE
		frame.z_index = 1 if up else 0
		return
	var t: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(frame, "scale", Vector2.ONE * (1.08 if up else 1.0), 0.12)
	frame.z_index = 1 if up else 0


func clear_hand() -> void:
	for child in hand.get_children():
		child.queue_free()


# --- Inspect and overlays -------------------------------------------------

## The colour behind a personality portrait for `owner`'s cards: that seat's deck Mastery hue.
## Each seat has its own, so one duelist on both sides still shows two backdrops.
func seat_backdrop(owner: int) -> Color:
	if owner < 0 or owner >= Session.chosen.size():
		return CardFace.NO_BACKDROP
	return CardFace.mastery_backdrop(Session.chosen[owner], Session.library)


func _uid_backdrop(uid: int) -> Color:
	var c: SeatCard = _view.card(uid) if _view != null and uid >= 0 else null
	return seat_backdrop(c.owner) if c != null else CardFace.NO_BACKDROP


## The seat a card belongs to, for its Strike's numbered base; -1 when the view does not know it.
func _uid_owner(uid: int) -> int:
	var c: SeatCard = _view.card(uid) if _view != null and uid >= 0 else null
	return c.owner if c != null else -1


func _uid_table(def: CardDef, uid: int) -> int:
	return _faces.table_base(def, _uid_owner(uid)) if _faces != null else -1


## Full-size live face over a dimmed table, so keyword hover works. Right-click or Inspect opens
## it; Esc or a click outside closes it.
func show_inspect(def: CardDef, aspect: int = 0, uid: int = -1) -> void:
	if def == null:
		return
	hide_peek()
	hide_focus()
	inspect_face.show_def(def, aspect, _live_energy(uid), _standing(uid), _uid_backdrop(uid), _uid_table(def, uid))
	var standing: SeatPlayer = _standing(uid)
	if standing == null and _view != null:
		for player in _view.players:
			if player.controlling == uid:
				standing = player
	inspect_status_scroll.visible = standing != null
	if standing != null:
		var flags: String = "\n".join(PLAYER_STATUS.flags(standing))
		var controller: SeatCard = _view.card(standing.controlling)
		var lines: PackedStringArray = PackedStringArray()
		if controller != null:
			lines.append("In control: %s | Energy %d" % [controller.title, _view.live_energy(controller.uid)])
		lines.append("Fervor %d / %d | Gain %d | Recover %d" % [standing.fervor, standing.fervor_needed, standing.fervor_gain, standing.recover_gain])
		lines.append("Life %d | Hand %d | Discard %d | Out %d | Reserve %d" % [standing.life_deck.size(), standing.hand.size(), standing.discard.size(), standing.removed.size(), standing.reserve.size()])
		if not flags.is_empty():
			lines.append(flags)
		inspect_status.text = "\n".join(lines)
		inspect_status_scroll.scroll_vertical = 0
	inspect_uid = uid
	inspect.visible = true


## The card a decision is about, held at readable size in the middle of the screen while the
## decision is open: the attack coming in, the life card that could endure, the card asking a
## question. Both seats see it, the one deciding and the one waiting, and it never takes the
## mouse so the table underneath stays clickable.
func show_focus(uid: int, caption: String) -> void:
	var c: SeatCard = _view.card(uid) if _view != null else null
	if c == null or c.hidden() or tray.visible or inspect.visible:
		hide_focus()
		return
	var def: CardDef = Session.library.defs.get(c.def_id)
	if def == null:
		hide_focus()
		return
	_caption_base = caption
	focus_caption.remove_theme_color_override("font_color")
	_apply_caption()
	_replay_focus = false
	_focus_card_uid = uid
	_pending_anchor = ""
	focus_face.show_def(def, c.aspect, _live_energy(uid), _standing(uid), seat_backdrop(c.owner), _uid_table(def, uid))
	focus.visible = true
	_compact_prompt()


## During a replay beat the decision column is empty. The same slot, at the same place, holds the
## card the beat is about: a declared attack pinned for the exchange, or an opponent's card being
## read. The rect never moves, so a prompt's own `show_focus` can take the same card over without
## the face jumping between the two. `uid` names the card when the caller has one, so the pending
## column knows this card is already on screen and the filament knows where to start.
func show_replay_card(def: CardDef, caption: String, color: Color, uid: int = -1) -> bool:
	if def == null or tray.visible or inspect.visible:
		hide_focus()
		return false
	_replay_focus = true
	_focus_card_uid = uid
	_pending_anchor = ""
	focus_face.show_def(def, 0, -1, null, _uid_backdrop(uid), _uid_table(def, uid))
	set_focus_caption(caption, color)
	focus.visible = true
	_compact_prompt()
	return true


## The pinned card stays where it is and only its caption moves on, so one attack reads as one
## continuous thing from declaration to outcome.
func set_focus_caption(caption: String, color: Color) -> void:
	_caption_base = caption
	focus_caption.add_theme_color_override("font_color", color)
	_apply_caption()


## The caption the slot shows: what the anchored card is doing, plus the wound loop the attack still
## owes when there is one. The wounds are the attack's own job rather than a card, so they are a
## line here instead of a face on the pile.
func _apply_caption() -> void:
	var text: String = _caption_base
	if not _wounds_note.is_empty() and focus.visible:
		text += " · %s to resolve" % _wounds_note
	focus_caption.text = text.to_upper()
	# The slot is one card wide and the caption is one clipped line, so a long one steps down to
	# the caption floor before it loses its end to an ellipsis.
	var size: int = ZenithTheme.SIZE_BODY if text.length() <= 24 else ZenithTheme.SIZE_CAPTION
	focus_caption.add_theme_font_size_override("font_size", size)


func hide_focus() -> void:
	focus.visible = false
	if filament != null:
		filament.visible = false
	_focus_card_uid = -1
	_pending_anchor = ""
	_caption_base = ""
	clear_stack()
	if _replay_focus:
		focus_caption.remove_theme_color_override("font_color")
		_replay_focus = false
	_compact_prompt()


## A card answering the pinned attack, pushed onto the stack laid over it. The attack never moves;
## each response covers it from a little further up and to the left, newest on top, so the exchange
## reads as one pile that cards enter and leave. `owner` is `&"attack"` for the attacker's own
## follow-ups and `&"defend"` for the other seat's, and it picks the tint and the leaving direction.
## `uid` is what `pop_response` will name when the beat that resolves this card arrives.
func push_response(def: CardDef, caption: String, owner: StringName, uid: int = -1) -> bool:
	if def == null or stack == null or tray.visible or inspect.visible or not focus.visible:
		return false
	var tint: Color = ZenithTheme.ATTACK if owner == &"attack" else ZenithTheme.DEFEND
	var held: Control = _entry_for_uid(uid)
	if held != null:
		# The pending list already dealt this card. The beat renames the face the player is looking
		# at rather than putting a second copy of the same card on the pile.
		_recaption(held, caption, tint)
		return true
	return _push_face(def, caption, tint, uid) != null


## One face onto the pile, returned so a caller can mark whose it is.
func _push_face(def: CardDef, caption: String, tint: Color, uid: int) -> Control:
	if def == null or stack == null or not focus.visible:
		return null
	var entry: Control = _stack_entry(caption, tint, uid)
	var face: CardFace = CARD_FACE.instantiate()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(face)
	entry.move_child(face, 0)
	stack.add_child(entry)
	# CardFace builds itself from its own @onready children, so it is filled once it is in the tree.
	face.show_def(def, 0, -1, null, _uid_backdrop(uid), _uid_table(def, uid))
	_stack.append(entry)
	_layout_stack()
	return entry


## A masked job's face: the card back under the same caption strip, because a card this seat may
## not read is still a card waiting in the pile.
func _push_back(caption: String, tint: Color) -> Control:
	if stack == null or not focus.visible:
		return null
	var entry: Control = _stack_entry(caption, tint, -1)
	var back: TextureRect = TextureRect.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.texture = _faces.back() if _faces != null else null
	entry.add_child(back)
	entry.move_child(back, 0)
	stack.add_child(entry)
	_stack.append(entry)
	_layout_stack()
	return entry


## The strip and border of a face already on the pile, for a beat that renames what it is doing.
func _recaption(entry: Control, caption: String, tint: Color) -> void:
	entry.set_meta("attacker_side", tint == ZenithTheme.ATTACK)
	var strip: Label = entry.get_node("Strip")
	strip.text = caption.to_upper()
	strip.add_theme_stylebox_override("normal", ZenithTheme.box(tint, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 8, 2))
	var edge: Panel = entry.get_node("Edge")
	edge.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), tint, ZenithTheme.RADIUS, 3, 0, 0))


## One card on the stack: its face, a border in its owner's role colour, and a caption strip on the
## bottom edge, which is the edge that stays visible under the card pushed after it.
func _stack_entry(caption: String, tint: Color, uid: int) -> Control:
	var entry: Control = Control.new()
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.set_meta("uid", uid)
	entry.set_meta("attacker_side", tint == ZenithTheme.ATTACK)
	var edge: Panel = Panel.new()
	edge.name = "Edge"
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), tint, ZenithTheme.RADIUS, 3, 0, 0))
	entry.add_child(edge)
	var strip: Label = Label.new()
	strip.name = "Strip"
	strip.text = caption.to_upper()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strip.clip_text = true
	strip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	strip.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
	strip.add_theme_color_override("font_color", ZenithTheme.TEXT_DARK)
	strip.add_theme_stylebox_override("normal", ZenithTheme.box(tint, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 8, 2))
	entry.add_child(strip)
	return entry


## Where each level of the stack sits inside the Focus rect. Level 0 lies over the lower half of
## the attack and every level after it steps up and to the left, so the attack keeps its caption
## and its top band and the newest response is the one wholly in view.
func _layout_stack() -> void:
	if stack == null or focus == null or _stack.is_empty():
		if _overflow != null and is_instance_valid(_overflow):
			_overflow.visible = false
		return
	var width: float = focus.offset_right - focus.offset_left
	var face_width: float = width * STACK_SCALE
	var face_height: float = face_width * CARD_ASPECT
	var attack_height: float = width * CARD_ASPECT
	var base: Vector2 = Vector2((width - face_width) * 0.5 + 16.0, attack_height - face_height - 6.0)
	for i in range(_stack.size()):
		var entry: Control = _stack[i]
		var level: int = mini(i, STACK_MAX - 1)
		var spot: Vector2 = base + STACK_STEP * float(level)
		entry.size = Vector2(face_width, face_height)
		entry.pivot_offset = entry.size * 0.5
		entry.position = Vector2(maxf(2.0, spot.x), maxf(2.0, spot.y))
		entry.rotation_degrees = STACK_TILT if i % 2 == 0 else -STACK_TILT
		var art: Control = entry.get_child(0)
		if art is CardFace:
			art.scale = Vector2(face_width / 512.0, face_width / 512.0)
		else:
			# A card back is a texture rather than a drawn face, so it takes the size outright.
			art.position = Vector2.ZERO
			art.size = entry.size
		var edge: Control = entry.get_node("Edge")
		edge.position = Vector2.ZERO
		edge.size = entry.size
		var strip: Control = entry.get_node("Strip")
		strip.position = Vector2(0.0, face_height - STACK_STRIP)
		strip.size = Vector2(face_width, STACK_STRIP)
	if _overflow != null and is_instance_valid(_overflow):
		# The badge rides the face on top, because that is the one the eye is already on.
		var top: Control = _stack.back()
		_overflow.visible = true
		_overflow.size = Vector2(52.0, 26.0)
		_overflow.position = top.position + Vector2(top.size.x - 56.0, 4.0)


## The beat that resolves a response takes it off the stack. `key` is the card's uid when the stack
## carries one, and otherwise a level index counted from the bottom. A beat that resolves something
## the stack never held does nothing, which is what a caller replaying a hidden card wants.
func pop_response(key: int) -> bool:
	var index: int = -1
	for i in range(_stack.size()):
		if key >= 0 and int(_stack[i].get_meta("uid", -1)) == key:
			index = i
			break
	if index < 0:
		if key < 0 or key >= _stack.size():
			return false
		index = key
	_take_off(_stack[index])
	return true


## One face off the pile with the same leaving animation, whichever side asked for it: the beat
## that resolved it, or a refresh finding it gone from `SeatView.pending`.
func _take_off(entry: Control) -> void:
	var index: int = _stack.find(entry)
	if index < 0:
		return
	_stack.remove_at(index)
	_leave_stack(entry)
	_layout_stack()


## A resolved response leaves the stack towards the rail its owner's piles sit on, fading as it
## goes. Reduced Motion takes it away at once rather than sliding it.
func _leave_stack(entry: Control) -> void:
	if reduced_motion_toggle.button_pressed:
		entry.queue_free()
		return
	var drift: Vector2 = Vector2(150.0 if bool(entry.get_meta("attacker_side", false)) else -150.0, 46.0)
	var leaving: Tween = create_tween().set_parallel(true)
	leaving.tween_property(entry, "position", entry.position + drift, STACK_LEAVE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	leaving.tween_property(entry, "modulate:a", 0.0, STACK_LEAVE)
	leaving.chain().tween_callback(entry.queue_free)


## Every reset that takes the Focus down empties the stack with it, so nothing goes stale across
## an exchange, a cleared decision or the end of Combat.
func clear_stack() -> void:
	for entry in _stack:
		if is_instance_valid(entry):
			entry.queue_free()
	_stack.clear()
	_set_overflow(0)


func stack_depth() -> int:
	return _stack.size()


func has_response(uid: int) -> bool:
	return _entry_for_uid(uid) != null


## A card already in the Focus slot or on the pile over it, lit where it stands. A trigger firing
## from the slot is read there, so it does not hop on the table as well. False when that card is
## nowhere on the right and the caller should fall back to the table spotlight.
func pulse_pending(uid: int) -> bool:
	if uid < 0 or not focus.visible:
		return false
	var node: Control = _entry_for_uid(uid)
	if node == null and focus_uid() == uid:
		node = focus_face
	if node == null:
		return false
	if reduced_motion_toggle.button_pressed:
		return true
	node.modulate = PULSE_BRIGHT
	var pulse: Tween = create_tween()
	pulse.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.3)
	return true


func _process(_delta: float) -> void:
	_draw_filament()
	if banner.visible:
		_place_banner()
	_show_clock()
	_show_next_count()


# --- Decision clock (online) --------------------------------------------------

## A seat's clock from the server. Offline nothing calls this, and a result already up ignores it.
func set_clock(seat: int, left_ms: int, bank_ms: int, phase: String) -> void:
	if not _online or _duel_over or seat < 0 or seat > 1:
		return
	var span: int = int(_clocks[seat].get("span", bank_ms))
	if phase == DuelClock.BANK and str(_clocks[seat].get("phase", "")) != DuelClock.BANK:
		span = bank_ms
	_clocks[seat] = {"left_ms": left_ms, "bank_ms": bank_ms, "phase": phase, "at": Time.get_ticks_msec(), "span": maxi(1, span)}


func clear_clocks() -> void:
	_clocks = [{}, {}]
	_show_clock()


## `{phase, ms, fraction}`: a seat's clock counted down from the last state the server sent, with
## the fraction the fuse shows (of the warning phase, or of the bank it started from).
func clock_now(seat: int) -> Dictionary:
	var c: Dictionary = _clocks[seat] if seat == 0 or seat == 1 else {}
	var phase: String = str(c.get("phase", DuelClock.OFF))
	if phase == DuelClock.OFF:
		return {"phase": DuelClock.OFF, "ms": 0, "fraction": 0.0}
	var elapsed: int = Time.get_ticks_msec() - int(c["at"])
	if phase == DuelClock.BANK:
		var bank: int = maxi(0, int(c["bank_ms"]) - elapsed)
		return {"phase": phase, "ms": bank, "fraction": float(bank) / float(int(c["span"]))}
	var left: int = maxi(0, int(c["left_ms"]) - elapsed)
	return {"phase": DuelClock.WARN if left <= DuelClock.WARN_MS else DuelClock.RUN, "ms": left,
		"fraction": float(left) / float(DuelClock.WARN_MS)}


## "0:23", whole seconds rounded up, so the last second reads 0:01 rather than 0:00.
static func clock_text(ms: int) -> String:
	var seconds: int = ceili(maxi(0, ms) / 1000.0)
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]


## All the time a seat has left on the decision it owes, timer and bank together, counted from the
## last state the server sent; -1 while no clock runs for it.
func clock_left_ms(seat: int) -> int:
	var c: Dictionary = clock_now(seat)
	var phase: String = str(c["phase"])
	if phase == DuelClock.OFF:
		return -1
	if phase == DuelClock.BANK:
		return int(c["ms"])
	return int(c["ms"]) + int(_clocks[seat]["bank_ms"])


## The other seat's plate while its player is away: `ms` is how long they have to come back.
static func away_text(player_name: String, ms: int) -> String:
	return "%s lost connection. %s to return." % [player_name, clock_text(ms)]


## Server room: this client's connection dropped and it is trying to get back into the duel. The
## overlay covers the table with the time the seat has left and a Give up button.
func show_reconnecting(ms: int) -> void:
	var text: String = "Reconnecting %s" % clock_text(ms)
	if reconnect_status.text != text:
		reconnect_status.text = text
	if reconnect.visible:
		return
	reconnect.visible = true
	set_options_open(false)
	hide_inspect()
	hide_pile()
	hide_peek()


func hide_reconnecting() -> void:
	reconnect.visible = false


## What the other seat's plate says while that seat decides: `{label, time, warn}`, an empty
## label when no clock runs for it.
func plate_clock(seat: int, player_name: String) -> Dictionary:
	var c: Dictionary = clock_now(seat)
	var phase: String = str(c["phase"])
	if phase == DuelClock.OFF:
		return {"label": "", "time": "", "warn": false}
	var label: String = "Time bank" if phase == DuelClock.BANK else "%s is deciding" % player_name
	return {"label": label, "time": clock_text(int(c["ms"])), "warn": phase != DuelClock.RUN}


## This seat's own countdown, on whichever decision panel is up: the prompt panel, or the tray
## when the decision is about cards. In the warning phase and on the bank it turns warning orange
## and a fuse burns along the panel's top edge.
func _show_clock() -> void:
	var c: Dictionary = clock_now(_current_prompt.player) if _current_prompt != null else clock_now(-1)
	var phase: String = str(c["phase"])
	var on: bool = phase != DuelClock.OFF
	var warn: bool = on and phase != DuelClock.RUN
	var text: String = clock_text(int(c["ms"]))
	if phase == DuelClock.BANK:
		text = "Time bank " + text
	for label: Label in [prompt_clock, tray_clock]:
		var shown: bool = on and (label == tray_clock) == tray.visible
		if label.visible != shown:
			label.visible = shown
		if shown and label.text != text:
			label.text = text
		if warn != _clock_warned:
			label.add_theme_color_override("font_color", ZenithTheme.WARN if warn else ZenithTheme.TEXT)
	_clock_warned = warn
	var panel: Control = tray_panel if tray.visible else prompt_panel
	fuse.visible = warn and panel.is_visible_in_tree()
	if fuse.visible:
		var rect: Rect2 = panel.get_global_rect()
		fuse.position = rect.position - root.global_position + Vector2(FUSE_INSET, FUSE_INSET - FUSE_HEIGHT * 0.5)
		fuse.size = Vector2((rect.size.x - FUSE_INSET * 2.0) * clampf(float(c["fraction"]), 0.0, 1.0), FUSE_HEIGHT)


## The thread from the pinned card to what it is aimed at, in the language the 3D link on the table
## already speaks: a bowed line in the attack colour, a transverse cap when the attack is stopped
## and a double chevron once it has landed. It leaves the left edge of the card in the Focus slot,
## or of the response on top of the stack when that response is the job resolving now, so the one
## card on the right is the one the line comes from. Hidden when nothing is pinned, when no job is
## aimed anywhere, or when the table cannot say where the target is.
func _draw_filament() -> void:
	if filament == null:
		return
	# A rail card that is the attacking duelist itself already has the table's own link to the target.
	var performer_shown: bool = _view != null and _focus_card_uid >= 0 and _focus_card_uid == int(_view.attack.get("performer", -2))
	if not focus.visible or performer_shown or _filament_target < 0 or tray.visible or inspect.visible \
		or table == null or not table.has_method("screen_anchor"):
		filament.visible = false
		return
	var target: Vector2 = table.screen_anchor(_filament_target)
	if target.x < 0.0 or target.y < 0.0:
		filament.visible = false
		return
	var origin: Vector2 = _filament_origin()
	var travel: Vector2 = target - origin
	if travel.length() < 32.0:
		filament.visible = false
		return
	var direction: Vector2 = travel.normalized()
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var base: Vector2 = filament.global_position
	var start: Vector2 = origin + direction * FILAMENT_TAIL
	var end: Vector2 = target - direction * FILAMENT_HEAD
	var middle: Vector2 = (start + end) * 0.5 + side * (travel.length() * FILAMENT_BOW)
	var color: Color = ZenithTheme.ATTACK.lightened(0.25)
	if _filament_state == &"stopped":
		color = ZenithTheme.DEFEND
	elif _filament_state == &"landed":
		color = ZenithTheme.ACCENT
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(FILAMENT_SAMPLES + 1):
		var ratio: float = float(i) / float(FILAMENT_SAMPLES)
		points.append(start.lerp(middle, ratio).lerp(middle.lerp(end, ratio), ratio) - base)
	filament_thread.points = points
	filament_thread.default_color = Color(color, 0.38 if _filament_state == &"stopped" else 0.64)
	var stopped: bool = _filament_state == &"stopped"
	filament_cap.visible = stopped
	filament_head.visible = not stopped
	filament_head_trail.visible = _filament_state == &"landed"
	if stopped:
		# A transverse ward closes the path; a stopped attack never gets an arrowhead.
		filament_cap.points = PackedVector2Array([end - side * FILAMENT_CAP - base, end + side * FILAMENT_CAP - base])
		filament_cap.default_color = Color(color, 0.9)
	else:
		filament_head.points = _chevron(end, direction, side, base)
		filament_head.default_color = Color(color, 0.95)
		if filament_head_trail.visible:
			filament_head_trail.points = _chevron(end - direction * FILAMENT_CHEVRON.x * 0.82, direction, side, base)
			filament_head_trail.default_color = Color(color, 0.95)
	filament.visible = true


func _chevron(tip: Vector2, direction: Vector2, side: Vector2, base: Vector2) -> PackedVector2Array:
	var back: Vector2 = tip - direction * FILAMENT_CHEVRON.x
	return PackedVector2Array([
		back + side * FILAMENT_CHEVRON.y - base, tip - base, back - side * FILAMENT_CHEVRON.y - base,
	])


## The left edge of the card the line comes from: the pinned attack, or the response on top of the
## stack when the job resolving now is that response rather than the attack under it.
func _filament_origin() -> Vector2:
	var face: Rect2 = focus_face_rect()
	if _filament_uid >= 0 and not _stack.is_empty():
		var top_entry: Control = _stack.back()
		if is_instance_valid(top_entry) and int(top_entry.get_meta("uid", -1)) == _filament_uid:
			face = Rect2(top_entry.global_position, top_entry.size)
	return Vector2(face.position.x, face.position.y + face.size.y * 0.5)


## The card the prompt is about: one it names outright, one raised by a card's effect, or the
## attack in the air. -1 when the decision is not about a single card.
func _focus_uid(p: PromptView) -> int:
	if p != null:
		if int(p.context.get("card", -1)) >= 0:
			return int(p.context["card"])
		if int(p.context.get("source", -1)) >= 0:
			return int(p.context["source"])
	if _view != null:
		if _view.pending_card >= 0:
			return _view.pending_card
		if not _view.attack.is_empty():
			# A Final Strike has no card of its own, so the rail shows who is making it.
			var source: int = int(_view.attack.get("source", -1))
			return source if source >= 0 else int(_view.attack.get("performer", -1))
		# This list is unordered. Only a single public source is unambiguous to focus.
		if _view.resolving.size() == 1:
			var resolving_card: SeatCard = _view.card(_view.resolving[0])
			if resolving_card != null and not resolving_card.hidden():
				return resolving_card.uid
	return -1


func _focus_caption(p: PromptView) -> String:
	if p == null:
		if _view != null and _view.deciding_kind == &"respond":
			return "Awaiting response"
		if _view != null and int(_view.attack.get("attacker", -1)) == _view.seat:
			return "Your attack"
		return "Incoming"
	match p.kind:
		&"endurance":
			return "Endurance"
		&"defense", &"redirect", &"control":
			# A Final Strike has no card of its own; the rail holds the duelist making it.
			return "Final Strike" if _view != null and bool(_view.attack.get("is_final", false)) else "Incoming"
		&"respond":
			return "Respond"
		&"critical", &"capture_instead":
			return "Your attack"
		&"recover":
			return "Top of your discard"
	if p.context.has("source"):
		return "Asking"
	return "Incoming"


func _live_energy(uid: int) -> int:
	if _view == null or uid < 0:
		return -1
	return _view.live_energy(uid)


func _standing(uid: int) -> SeatPlayer:
	if _view == null or uid < 0:
		return null
	return _view.duelist_owner(uid)


## Dev screenshots: acts as if the pointer were over the nth button in the prompt panel, so the
## hover preview can be caught in a PNG.
func hover_primary(index: int) -> void:
	var buttons: Array[Node] = primary_box.get_children()
	if index >= 0 and index < buttons.size():
		(buttons[index] as Button).mouse_entered.emit()


## The options menu, from the gear or Esc. While it is open the shade under it takes the mouse, so
## nothing on the table or the panels answers, and a click on the shade closes it.
func set_options_open(on: bool) -> void:
	options_button.set_pressed_no_signal(on)
	options_button.queue_redraw()
	options_menu.visible = on
	options_shade.visible = on
	_show_menu_question(&"")
	if on:
		_refresh_menu()


## Read each time the menu opens: Concede only while the duel runs, Rematch outside an adventure
## and a ranked match and, once the result is up, only where its panel offers one too, and one way
## out per mode. A ranked match concedes a game and leaves the match until the match is decided.
func _refresh_menu() -> void:
	menu_concede.visible = not _duel_over and not _match_replay
	menu_concede.text = "Concede this game" if _ranked else "Concede"
	menu_rematch.visible = not _match_replay and not _adventure and not _ranked and (not _online or _can_rematch) and (not _duel_over or rematch_button.visible)
	if _adventure:
		menu_leave.text = "Save and quit to title"
	elif _ranked and not _match_decided:
		menu_leave.text = "Leave match"
	else:
		menu_leave.text = "Leave duel" if _online else "Back to title"
	for row: Control in [menu_replay_speed.get_parent(), menu_replay_view.get_parent()]:
		row.visible = _match_replay
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	fullscreen_toggle.set_pressed_no_signal(mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


## What a menu item asks before it acts, "" when it acts at once. Rematch and leaving only ask
## while the duel runs, and Save and quit never does: the run is saved after every command.
func _menu_question(action: StringName) -> String:
	match action:
		&"concede":
			if _adventure:
				return "Concede: this ends the run."
			if _ranked:
				return "Concede: this loses the game, not the match."
			return "Concede the duel." if _online else "Concede and return to the title."
		&"rematch":
			if _duel_over:
				return ""
			return "Concede this duel and ask for a rematch." if _online else "Abandon this duel and deal a new one."
		&"leave":
			if _ranked and not _match_decided:
				return "Leave the match. This loses it."
			if _duel_over or _adventure or _match_replay:
				return ""
			return "Leave the duel. This concedes it." if _online else "Abandon this duel and return to the title."
	return ""


func _ask(action: StringName) -> void:
	if _menu_question(action) == "":
		_menu_act(action)
	else:
		_show_menu_question(action)


## The confirm in place of the items, or the items again for &"".
func _show_menu_question(action: StringName) -> void:
	_menu_action = action
	menu_items.visible = action == &""
	menu_confirm.visible = action != &""
	if action != &"":
		menu_question.text = _menu_question(action)
		menu_yes.text = str(MENU_VERBS[action])


func _menu_act(action: StringName) -> void:
	set_options_open(false)
	match action:
		&"concede":
			concede_requested.emit()
		&"rematch":
			rematch_requested.emit()
		&"leave":
			leave_requested.emit()


## Debug builds only, and only where the referee lives (hotseat, host).
func set_dev_available(on: bool) -> void:
	dev_toggle.visible = on
	if not on:
		dev_panel.visible = false


## Drops the log down to most of the screen, or back to its strip.
func set_log_expanded(on: bool) -> void:
	_log_expanded = on
	if on:
		hide_peek()
	log_toggle.text = "Close" if on else "History"
	var bottom: float = root.size.y * LOG_EXPANDED_FRACTION if on else LOG_COLLAPSED_BOTTOM
	if reduced_motion_toggle.button_pressed:
		log_panel.offset_bottom = bottom
		return
	var t: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(log_panel, "offset_bottom", bottom, 0.18)


## Expanded rules in the quick view's fixed home on the left, under the log, opposite the rail.
## It never follows the pointer. The expanded log owns that column, so the quick view waits.
func show_peek(def: CardDef, aspect: int = 0, uid: int = -1) -> void:
	if def == null or inspect.visible or _log_expanded:
		return
	peek_face.show_def(def, aspect, _live_energy(uid), _standing(uid), _uid_backdrop(uid), _uid_table(def, uid))
	var forecast: String = _forecast_text(uid)
	peek_forecast.visible = forecast != ""
	peek_forecast_text.text = forecast
	peek.visible = true


## "Would deal 6 Energy" with the steps that add up to it, for a card the viewer could attack
## with now; "" for anything else.
func _forecast_text(uid: int) -> String:
	if _view == null or uid < 0:
		return ""
	var f: Dictionary = _view.forecast(uid)
	if f.is_empty():
		return ""
	var strong: String = ZenithTheme.TEXT.to_html(false)
	var muted: String = ZenithTheme.MUTED.to_html(false)
	var total: String = CardText.short_damage(int(f.get("stages", 0)), int(f.get("life", 0)))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[color=%s]%s would deal[/color] [color=%s]%s[/color]" % [muted, "A Final Strike" if bool(f.get("is_final", false)) else "Now", strong, total])
	lines.append("[color=%s]%s[/color]" % [muted, "  ·  ".join(CardText.breakdown_steps(f))])
	if int(f.get("cost_stages", 0)) > 0:
		lines.append("[color=%s]Costs %d Energy first[/color]" % [muted, int(f["cost_stages"])])
	if f.has("empowered"):
		var emp: Dictionary = f["empowered"]
		lines.append("[color=%s]Empowered:[/color] [color=%s]%s[/color]" % [muted, strong, CardText.short_damage(int(emp.get("stages", 0)), int(emp.get("life", 0)))])
	return "\n".join(lines)


func hide_peek() -> void:
	peek.visible = false


func hide_inspect() -> void:
	inspect.visible = false
	inspect_uid = -1


## What this player has open, for online presence: {look, seat, zone, look_card} in
## `PresenceState` terms. The inspect overlay names its card only when the card is public.
func presence_look(view: SeatView) -> Dictionary:
	if inspect.visible:
		if view != null and PresenceState.is_public(view.card(inspect_uid)):
			return {"look": "inspect", "look_card": inspect_uid}
		return {}
	if pile.visible and _pile_zone != &"":
		return {"look": "pile", "seat": _pile_player, "zone": String(_pile_zone)}
	if tray.visible:
		return {"look": "choice"}
	if _log_expanded:
		return {"look": "log"}
	return {}


## One quiet line on the opponent's side of the screen saying what they have open; "" hides it.
func set_presence_line(text: String, color: Color) -> void:
	presence_line.visible = text != ""
	presence_line.text = text
	presence_line.add_theme_color_override("font_color", color)


func _is_inspect_click(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		return mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT
	return false


func _on_inspect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		hide_inspect()


## Esc closes the options menu, then an inspect view or the pile browser, and otherwise opens the
## menu, unless a tray is open or the hand is raised, which lowers itself on Esc. While the menu is
## open no other key reaches the table: the hand's keys would act on the cards behind it.
func _unhandled_input(event: InputEvent) -> void:
	var cancel: bool = event.is_action_pressed("ui_cancel")
	if cancel and options_menu.visible:
		set_options_open(false)
		get_viewport().set_input_as_handled()
	elif options_menu.visible and event is InputEventKey:
		get_viewport().set_input_as_handled()
	elif inspect.visible and cancel:
		hide_inspect()
		get_viewport().set_input_as_handled()
	elif pile.visible and cancel:
		hide_pile()
		get_viewport().set_input_as_handled()
	elif cancel and not tray.visible and not loading.visible and not reconnect.visible and not _hand_raised():
		set_options_open(true)
		get_viewport().set_input_as_handled()
	elif _space_takes_single_action(event):
		_single_action.pressed.emit()
		get_viewport().set_input_as_handled()


## Space takes the lone offered action, and only that: with two alternatives on screen there is
## nothing for it to mean. A focused button answers Space itself, and the hand answers it while
## keyboard browsing, so neither reaches here.
func _space_takes_single_action(event: InputEvent) -> bool:
	if _single_action == null or not (event is InputEventKey):
		return false
	var key: InputEventKey = event
	if not key.pressed or key.echo or key.keycode != KEY_SPACE:
		return false
	if not _single_action.is_visible_in_tree() or _single_action.disabled:
		return false
	if tray.visible or pile.visible or inspect.visible or handoff.visible or game_over.visible or options_menu.visible or reconnect.visible:
		return false
	if get_viewport().gui_get_focus_owner() != null:
		return false
	return not _hand_browsing()


## True while the in-scene hand owns the keyboard, where Space inspects a card instead.
func _hand_browsing() -> bool:
	var parent: Node = get_parent()
	if parent == null:
		return false
	var raw: Variant = parent.get("hand_3d")
	if not (raw is Node):
		return false
	return bool((raw as Node).get("keyboard_active"))


func _hand_raised() -> bool:
	var parent: Node = get_parent()
	var raw: Variant = parent.get("hand_3d") if parent != null else null
	return raw is Node3D and (raw as Node3D).is_visible_in_tree() and bool((raw as Node3D).get("revealed"))


func show_handoff(player_name: String) -> void:
	handoff_title.text = "Pass the table to %s" % player_name
	handoff.visible = true
	clear_hand()
	hide_pile()
	hide_peek()
	hide_inspect()


func hide_handoff() -> void:
	handoff.visible = false


func show_game_over(title: String, reason: String, rematch_possible: bool = true) -> void:
	_duel_over = true
	clear_clocks()
	hide_reconnecting()
	game_over_title.text = title
	game_over_reason.text = reason
	game_over.visible = true
	SanctumUI.enter($Root/GameOver/Center/Column)
	rematch_button.visible = rematch_possible and (not _online or _can_rematch) and not _ranked
	if _series_open:
		select_button.visible = false
		title_button.visible = false
	clear_prompt()
	clear_hand()
	if options_menu.visible:
		set_options_open(true)


## A line under the result, such as who wants a rematch; "" hides it.
func set_game_over_note(text: String) -> void:
	game_over_note.text = text
	game_over_note.visible = text != ""


## Server room: this seat asked for a rematch and waits for the other one to ask too.
func wait_for_rematch() -> void:
	rematch_button.disabled = true
	set_game_over_note("Waiting for the other player")


## The other player left or the connection dropped, so no rematch can be dealt: Rematch leaves the
## panel and the menu, now and whenever the panel comes up.
func drop_rematch(note: String) -> void:
	_can_rematch = false
	rematch_button.visible = false
	set_game_over_note(note)
