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
## Concede this duel, or in a ranked match this game.
signal concede_requested
## Ranked: concede the whole match.
signal concede_match_requested
## Back to title, from the options menu.
signal leave_requested
## The reconnect card's Concede, confirmed.
signal give_up_requested
## Ranked between games: this player is ready for the next game.
signal next_game_requested
## Ranked match result: back into the ranked queue.
signal ranked_requested
## Casual queue result: back into the casual queue.
signal find_requested
## The replay bar and its twins in the options menu: &"play", &"pause", &"step", &"back", &"seek"
## (value: the entry to jump to), &"speed" (value: the time scale), &"view" (value: seat 0 or 1, or
## 2 for both hands).
signal replay_command(action: StringName, value: int)
## The pointer came onto a greyed option (its reason) or left it ("").
signal gated_hover(reason: String)
## A greyed option was clicked (its reason).
signal gated_clicked(reason: String)

const HAND_CARD_SIZE: Vector2 = Vector2(126, 176)
const FAR_HAND_CARD: Vector2 = Vector2(100, 140)   # a replay's far hand, in the strip over the far crest
const HAND_LIFT: float = 26.0
const MAX_LOG_LINES: int = 300
const LOG_KEY: Key = KEY_L
## The smallest tray face; a short tray widens its faces up to TRAY_CARD_MAX_WIDTH.
const TRAY_CARD_SIZE: Vector2 = Vector2(204, 285)
const TRAY_CARD_MAX_WIDTH: float = 340.0
const TRAY_GAP: float = 12.0          # the tray flow's h_separation in hud.tscn
const TRAY_SIDE_ROOM: float = 180.0   # screen width the tray panel leaves beside it
const TRAY_FRAME: Vector2 = Vector2(6.0, 32.0)   # a face's frame across; frame, gap and caption down
const TRAY_HEIGHT_SHARE: float = 0.57 # of the screen height, for the rows shown before scrolling
const CHOICE_HEIGHT: float = 100.0    # a tray tile that is a wording rather than a card
const LOG_EXPANDED_FRACTION: float = 0.72
const FRAME_TINT: Color = ZenithTheme.FRAME
const TRAY_COLUMNS: int = 6          # cards per row before the tray wraps
const TRAY_ROWS_SHOWN: int = 2       # rows before the tray scrolls
const PILE_ROWS_SHOWN: int = 3       # a browsed pile is only read, so it may be taller
const FOCUS_CAPTION_HEIGHT: float = 32.0
## The response stack over the pinned attack, inside the Focus rect. Scale and steps are shares of
## the Focus card's width, which narrows with the column.
const STACK_SCALE: float = 0.8
const STACK_STEP: Vector2 = Vector2(-0.065, -0.085)
const STACK_INSET: float = 0.04
const STACK_TILT: float = 1.0          # degrees, sign alternating, so a pile never reads as one card
const STACK_STRIP: float = 26.0        # the caption strip on each card's visible bottom edge
const STACK_MAX: int = 4               # levels that step; deeper responses sit on the last one
const STACK_LEAVE: float = 0.25        # how long a resolved response takes to leave the stack
## Meta on a face the pending list put on the stack, so a later refresh knows which faces are its
## own to take off again and which a replay beat owns.
const PENDING_KEY: StringName = &"pending_key"
## The filament from the pinned card to its target on the table, the 2D twin of
## `DuelFx.show_attack_link`.
const FILAMENT_SAMPLES: int = 24
const FILAMENT_BOW: float = 0.09          # side offset of the curve, as a share of its own length
const FILAMENT_TAIL: float = 8.0          # gap between the card's edge and the start of the thread
const FILAMENT_HEAD: float = 26.0         # gap between the target card's centre and the chevron
const FILAMENT_CHEVRON: Vector2 = Vector2(17.0, 9.0)   # chevron length along and across the thread
const FILAMENT_CAP: float = 13.0          # half-width of the transverse cap on a stopped attack
const CARD_FACE: PackedScene = preload("res://scenes/duel/card_face.tscn")
const CARD_ASPECT: float = 716.0 / 512.0
const DECISION_GAP: float = 10.0
## The right-edge rail. The decision frame's top stands DECISION_GAP under the card's home
## (`panel_top`) whether or not a card is showing, and scrolls once it would pass GUTTER from the bottom.
const GUTTER: float = 18.0
const RAIL_TOP: float = 74.0
const RAIL_WIDTH: float = 400.0
const RAIL_LEFT: float = -GUTTER - RAIL_WIDTH   # from the right edge
const RAIL_CARD_WIDTH: float = 400.0
## Padding between the decision panel's frame texture edge and its text; the rule itself sits
## about 8 px inside the texture edge.
const PROMPT_PAD: int = 16
## The history strip on the left edge: the latest log events that name a card, as faces, newest
## on top. Hovering one shows its line beside it; the full log opens over it.
const HISTORY_MAX: int = 7
const HISTORY_THUMB: Vector2 = Vector2(48, 67)
const HISTORY_TIP_GAP: float = 8.0
const HISTORY_OLD_ALPHA: float = 0.82
const ACTION_HEIGHT: float = 48.0
const SINGLE_ACTION_HEIGHT: float = 56.0
const DECISION_RESULT_HEIGHT: float = 30.0   # one line at the body size
## Prompt kinds whose card options are browsed in the tray even when the cards are in the hand.
const TRAY_KINDS: Array[StringName] = [&"reserve", &"keep", &"discard_choice", &"recover", &"pick_option", &"name_card", &"pick_discard", &"order"]
## Tray captions by option type; anything else shows the option's own label.
const TRAY_VERBS: Dictionary = {
	&"reserve_in": "Bring in", &"keep": "Keep", &"discard_choice": "Discard", &"recover": "Recover",
	&"pick_option": "Choose", &"pick_in_play": "Choose", &"name_card": "Name", &"capture": "Capture",
	&"final_strike": "Discard",
}
## An order entry's height beyond its face: the rank chip, the description and the arrow buttons.
const ORDER_EXTRA: float = 180.0
const ORDER_MIN_WIDTH: float = 880.0   # the order tray's width at least, so its hint keeps to one line
const ORDER_LINES: int = 4             # description lines shown under an order entry's face
const ORDER_GHOST: float = 0.55        # the dragged face's scale under the pointer
## The tray only ever opens for the seat at the table, so its header needs no name.
const TRAY_WHO: String = "YOUR DECISION"
## The over-bright flash a face takes for a beat that happened on it, bone rather than warm.
const PULSE_BRIGHT: Color = Color(1.6, 1.58, 1.5, 1)
## The beat banner across the ring. A hand-over sweeps in, an outcome pops, and a quiet line never
## cuts short a louder banner. Widths stop short of the phase track's notches either side of the ring.
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
## The label a lone non-card action carries, by option type; ACTION_LABELS_BY_KIND overrides by prompt kind.
const ACTION_LABELS: Dictionary = {
	&"pass": "Pass", &"no_defense": "No Defense", &"decline": "Let it resolve", &"done": "Done",
	&"no_endure": "Take the wound", &"declare": "Declare Combat",
}
const ACTION_LABELS_BY_KIND: Dictionary = {
	&"combat_end": {&"done": "End Combat"}, &"declare": {&"skip": "No Combat"},
	&"follow_up": {&"decline": "Use nothing"},
}
## Prompt kinds answered by panel buttons even though their options name a card.
const BUTTON_KINDS: Array[StringName] = [&"endurance"]
## The confirm button of each options-menu item that asks first.
const MENU_VERBS: Dictionary = {&"concede": "Concede", &"concede_match": "Concede", &"rematch": "Rematch", &"leave": "Back to title"}
## How this duel was reached, which decides the result's buttons, the menu and whether clocks run.
## CODE is a share-code room on the server or a LAN duel; QUEUE a casual pairing; RANKED a match.
enum Mode { LOCAL, ADVENTURE, CODE, QUEUE, RANKED, REPLAY, TUTORIAL }
## What the result card shows. NONE while a game runs. GAME_PENDING: a ranked game is over and the
## server has not yet said what follows. BETWEEN: the match goes on to its next game. MATCH: the
## match is decided. RESULT: a duel is over. LOST: the connection is gone for good.
enum ResultState { NONE, GAME_PENDING, BETWEEN, MATCH, RESULT, LOST }
## What takes the card's place: the reconnect card while this client is cut off from its seat.
enum Overlay { NONE, RECONNECTING }
## The result card's nodes each state may show. A label shows only with text, a button only where
## the mode offers it (`result_buttons`).
const RESULT_NODES: Dictionary = {
	ResultState.NONE: [],
	ResultState.GAME_PENDING: [&"Title", &"Note"],
	ResultState.BETWEEN: [&"Title", &"Body", &"Note", &"Ready"],
	ResultState.MATCH: [&"Title", &"Body", &"Rating", &"Primary", &"Leave"],
	ResultState.RESULT: [&"Title", &"Body", &"Note", &"Primary", &"Rematch", &"Leave"],
	ResultState.LOST: [&"Title", &"Body", &"Leave"],
}
## Server reasons that are not the rules; a result names them. Any other reason is a rules win.
const OFF_RULES: Array[String] = ["concede", "concede_match", "timeout", "left", "abandoned"]
## The card's frame to its 540 px of content, for a 612 px card.
const CARD_PAD: int = 36
## A decision clock turns to the warning, with the fuse, once timer and bank together are this low.
const CLOCK_WARN_MS: int = 10000

@onready var reduced_motion_toggle: CheckButton = $Root/OptionsMenu/Column/Items/ReducedMotion
@onready var options_button: Button = $Root/Options
@onready var options_menu: PanelContainer = $Root/OptionsMenu
@onready var options_shade: ColorRect = $Root/OptionsShade
@onready var menu_items: VBoxContainer = $Root/OptionsMenu/Column/Items
@onready var menu_resume: Button = $Root/OptionsMenu/Column/Items/Resume
@onready var menu_concede: Button = $Root/OptionsMenu/Column/Items/Concede
@onready var menu_concede_match: Button = $Root/OptionsMenu/Column/Items/ConcedeMatch
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
@onready var history: PanelContainer = $Root/History
@onready var history_open: Button = $Root/History/Column/Open
@onready var history_thumbs: VBoxContainer = $Root/History/Column/Thumbs
@onready var history_tip: PanelContainer = $Root/HistoryTip
@onready var history_tip_text: Label = $Root/HistoryTip/Text
@onready var resonance_tip: PanelContainer = $Root/ResonanceTip
@onready var resonance_tip_name: Label = $Root/ResonanceTip/Column/Name
@onready var resonance_tip_effect: Label = $Root/ResonanceTip/Column/Effect
@onready var resonance_tip_penalty: Label = $Root/ResonanceTip/Column/Penalty
@onready var inspect: ColorRect = $Root/Inspect
@onready var inspect_face: CardFace = $Root/Inspect/Center/Column/Face
@onready var inspect_status_scroll: ScrollContainer = $Root/Inspect/Center/Column/StatusScroll
@onready var inspect_status: RichTextLabel = $Root/Inspect/Center/Column/StatusScroll/Status
@onready var hand: HBoxContainer = $Root/Hand
@onready var prompt_panel: PanelContainer = $Root/PromptPanel
@onready var prompt_head: VBoxContainer = $Root/PromptPanel/Column/Head
@onready var prompt_who: Label = $Root/PromptPanel/Column/Head/Row/Who
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
@onready var tray_head: VBoxContainer = $Root/Tray/Center/Panel/Column/Head
@onready var tray_who: Label = $Root/Tray/Center/Panel/Column/Head/Row/Who
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
## The one centred card over the scrim: the result (`GameOver`) or the reconnect card, never both.
@onready var modal: ColorRect = $Root/Modal
@onready var result_card: PanelContainer = $Root/Modal/Center/Card
@onready var game_over: VBoxContainer = $Root/Modal/Center/Card/GameOver
@onready var game_over_title: Label = $Root/Modal/Center/Card/GameOver/Title
@onready var game_over_body: Label = $Root/Modal/Center/Card/GameOver/Body
@onready var game_over_rating: Label = $Root/Modal/Center/Card/GameOver/Rating
@onready var game_over_note: Label = $Root/Modal/Center/Card/GameOver/Note
@onready var ready_button: Button = $Root/Modal/Center/Card/GameOver/Ready
@onready var primary_button: Button = $Root/Modal/Center/Card/GameOver/Primary
@onready var game_over_actions: HBoxContainer = $Root/Modal/Center/Card/GameOver/Actions
@onready var rematch_button: Button = $Root/Modal/Center/Card/GameOver/Actions/Rematch
@onready var leave_button: Button = $Root/Modal/Center/Card/GameOver/Actions/Leave
@onready var reconnect: VBoxContainer = $Root/Modal/Center/Card/Reconnect
@onready var reconnect_status: Label = $Root/Modal/Center/Card/Reconnect/Status
@onready var reconnect_give_up: Button = $Root/Modal/Center/Card/Reconnect/GiveUp
@onready var reconnect_confirm: VBoxContainer = $Root/Modal/Center/Card/Reconnect/Confirm
@onready var reconnect_question: Label = $Root/Modal/Center/Card/Reconnect/Confirm/Question
@onready var reconnect_yes: Button = $Root/Modal/Center/Card/Reconnect/Confirm/Buttons/Yes
@onready var reconnect_no: Button = $Root/Modal/Center/Card/Reconnect/Confirm/Buttons/No
@onready var series_line: Label = $Root/Series
@onready var loading: ColorRect = $Root/Loading
@onready var prompt_clock: Label = $Root/PromptPanel/Column/Head/Row/Clock
@onready var prompt_fuse: ProgressBar = $Root/PromptPanel/Column/Head/Fuse
@onready var tray_clock: Label = $Root/Tray/Center/Panel/Column/Head/Row/Clock
@onready var tray_fuse: ProgressBar = $Root/Tray/Center/Panel/Column/Head/Fuse
@onready var tray_balance: Control = $Root/Tray/Center/Panel/Column/Head/Row/Balance
@onready var tray_panel: PanelContainer = $Root/Tray/Center/Panel
## Once a second: the between-games count, the away and rejoin lines, and the rival's tab.
@onready var tick: Timer = $Tick
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
var _history: Array[Dictionary] = []   # the history strip, newest first: {text, def_id, aspect, owner}
var _batch: PromptView = null          # the prompt behind a multi-select tray, else null
var _selected: Array[int] = []
var _entries: Dictionary = {}          # uid -> {frame, caption, verb} for batch trays
var _confirm: Button = null
var _mode: Mode = Mode.LOCAL
var _can_rematch: bool = true          # this client may ask for a rematch and the lobby (`Net.can_rematch`)
var _clocked: bool = false             # a server room, where the server runs decision clocks
var _duel_over: bool = false           # a result is up, whether the rules or a concession ended it
var _result: ResultState = ResultState.NONE
var _facts: Dictionary = {}            # what `apply_result` was last told
var _overlay: Overlay = Overlay.NONE
var _button_actions: Dictionary = {}   # result button node name -> the action it asks for
## The away line while the panel waits on a rival who is cut off, "" otherwise; and after a rejoin,
## until this seat answers, the time its decision has left goes under the hint.
var _away_line: String = ""
var _rejoined: bool = false
var _hint_base: String = ""            # the prompt hint before either line is added
var _title_base: String = ""           # the waiting panel's own title, "" when the panel is not waiting
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
var _order_ids: Array[int] = []        # the order tray's arrangement by effect id, first to resolve first
var _order_entries: Dictionary = {}    # effect id -> {entry, frame, rank, earlier, later}
var _order_goal: Array[int] = []       # an arrangement the player confirmed, sent one move per prompt
## Server room, per seat: the server's last clock state (`Net.clock_changed`) and when it arrived.
var _clocks: Array[Dictionary] = [{}, {}]
## A recorded duel played back: nothing here answers a decision, and the menu offers the replay's
## own controls instead of Concede and Rematch.
var _match_replay: bool = false
## The tutorial's gate on the prompt shown: `enabled` and `reasons` per option index, `library`
## for a searched deck's cards that are not choices. {} opens every option.
var _gate: Dictionary = {}


func _ready() -> void:
	root.theme = SanctumUI.theme()
	reduced_motion_toggle.toggled.connect(func(on: bool) -> void: reduced_motion_changed.emit(on))
	prompt_panel.add_theme_stylebox_override("panel", MapArt.panel_box(PROMPT_PAD, FRAME_TINT))
	prompt_panel.minimum_size_changed.connect(_stand_prompt)
	prompt_panel.visibility_changed.connect(_stand_prompt)
	prompt_hint.add_theme_color_override("font_color", ZenithTheme.TEXT_SOFT)
	log_panel.add_theme_stylebox_override("panel", MapArt.panel_box(14, FRAME_TINT))
	history.add_theme_stylebox_override("panel", ZenithTheme.box(Color(ZenithTheme.BG, 0.72), ZenithTheme.BORDER, ZenithTheme.RADIUS, 1, 6, 6))
	history_tip.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG, ZenithTheme.BORDER, ZenithTheme.RADIUS, 1, 12, 8))
	resonance_tip.add_theme_stylebox_override("panel", MapArt.panel_box(18, FRAME_TINT))
	resonance_tip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	(resonance_tip.get_child(0) as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resonance_tip_name.add_theme_color_override("font_color", ZenithTheme.TEXT)
	resonance_tip_effect.add_theme_color_override("font_color", ZenithTheme.TEXT)
	resonance_tip_penalty.add_theme_color_override("font_color", ZenithTheme.PENALTY)
	history_open.pressed.connect(func() -> void: set_log_expanded(not _log_expanded))
	var inspect_hint: Label = $Root/Inspect/Center/Column/Hint
	inspect_hint.add_theme_stylebox_override("normal", ZenithTheme.panel(24))
	inspect_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	focus_caption.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.BG, Color(0, 0, 0, 0), ZenithTheme.RADIUS, 0, 6, 0))
	table = get_parent()
	for scrim: ColorRect in [tray, pile, modal]:
		scrim.color = ZenithTheme.SCRIM
	inspect.color = ZenithTheme.SCRIM_STRONG
	options_shade.color = ZenithTheme.SCRIM_LIGHT
	handoff.color = ZenithTheme.BG_SCREEN
	loading.color = ZenithTheme.BG_SCREEN
	result_card.add_theme_stylebox_override("panel", ZenithTheme.panel(CARD_PAD))
	game_over_note.custom_minimum_size.y = game_over_note.get_theme_font("font").get_height(game_over_note.get_theme_font_size("font_size"))
	handoff_ready.pressed.connect(func() -> void: handoff_confirmed.emit())
	for button: Button in [primary_button, rematch_button, leave_button]:
		button.pressed.connect(_on_result_button.bind(button))
	ready_button.pressed.connect(_on_ready)
	reconnect_give_up.pressed.connect(_show_reconnect_confirm.bind(true))
	reconnect_no.pressed.connect(_show_reconnect_confirm.bind(false))
	reconnect_yes.pressed.connect(func() -> void: give_up_requested.emit())
	tick.timeout.connect(_on_tick)
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
	menu_concede_match.pressed.connect(_ask.bind(&"concede_match"))
	menu_rematch.pressed.connect(_ask.bind(&"rematch"))
	menu_leave.pressed.connect(_ask.bind(&"leave"))
	menu_yes.pressed.connect(func() -> void: _menu_act(_menu_action))
	menu_no.pressed.connect(_show_menu_question.bind(&""))
	fullscreen_toggle.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	dev_panel.command.connect(func(effect: Dictionary) -> void: dev_command.emit(effect))
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


func _compact_prompt() -> void:
	# A waiting panel's title already names who decides; a replay keeps both lines.
	prompt_who.visible = (_current_prompt != null or _match_replay) and not prompt_who.text.is_empty()
	prompt_title.visible = _current_prompt != null or not focus.visible
	prompt_hint.visible = (_current_prompt != null or _match_replay) and not prompt_hint.text.is_empty()
	exchange_state.hide()
	exchange_route.hide()
	exchange_response.hide()
	_refresh_hint()
	_sync_head()
	_layout_prompt_column()


func _layout_prompt_column() -> void:
	if focus == null or prompt_panel == null:
		return
	prompt_panel.offset_left = RAIL_LEFT
	prompt_panel.offset_right = -GUTTER
	_place_focus()
	_fit_actions()


## The card face in the Focus slot, in global coordinates, with the caption strip under it left out.
func focus_face_rect() -> Rect2:
	var rect: Rect2 = focus.get_global_rect()
	return Rect2(rect.position, Vector2(rect.size.x, rect.size.x * CARD_ASPECT))


## The focus slot's height: the card face and its caption strip.
func _slot_height() -> float:
	return RAIL_CARD_WIDTH * CARD_ASPECT + FOCUS_CAPTION_HEIGHT


## The focus card's top edge, which never moves.
func rail_top() -> float:
	return RAIL_TOP


## The decision frame's top edge: DECISION_GAP under the card's home, card or no card.
func panel_top() -> float:
	return RAIL_TOP + _slot_height() + DECISION_GAP


## The lowest the frame reaches; a longer one scrolls.
func panel_floor() -> float:
	return root.size.y - GUTTER


func _place_focus() -> void:
	focus.offset_left = RAIL_LEFT + (RAIL_WIDTH - RAIL_CARD_WIDTH) * 0.5
	focus.offset_right = focus.offset_left + RAIL_CARD_WIDTH
	focus.offset_top = rail_top()
	focus.offset_bottom = focus.offset_top + _slot_height()
	focus_face.scale = Vector2.ONE * RAIL_CARD_WIDTH / 512.0
	_layout_stack()


## The action list's height; a list that would push the frame past its floor scrolls.
func _fit_actions() -> void:
	if _fitting_actions or actions_scroll == null:
		return
	_fitting_actions = true
	actions_scroll.visible = primary_box.get_child_count() > 0
	var outside: float = maxf(0.0, prompt_panel.get_combined_minimum_size().y - actions_scroll.get_combined_minimum_size().y)
	var room: float = panel_floor() - panel_top()
	var available: float = maxf(SINGLE_ACTION_HEIGHT, room - outside)
	actions_scroll.custom_minimum_size.y = minf(primary_box.get_combined_minimum_size().y, available)
	_fitting_actions = false
	_stand_prompt()


## Set outright: a Control only grows to its minimum on its own, and a hidden one misses the change.
func _stand_prompt() -> void:
	prompt_panel.offset_top = panel_top()
	prompt_panel.offset_bottom = prompt_panel.offset_top + prompt_panel.get_combined_minimum_size().y


func set_loading(on: bool) -> void:
	loading.visible = on


## How this duel was reached (`Mode`), whether this client may ask for a rematch and the lobby
## (`Net.can_rematch`), and whether the server runs decision clocks here. A clocked panel keeps its
## head row as tall as the clock and its fuse, so neither moves the panel when it appears.
func set_mode(mode: Mode, can_rematch: bool = true, clocked: bool = false) -> void:
	_mode = mode
	_can_rematch = can_rematch
	_clocked = clocked
	var head: float = 0.0
	if clocked:
		head = prompt_clock.get_combined_minimum_size().y + prompt_head.get_theme_constant("separation") + ZenithTheme.FUSE_HEIGHT
	prompt_head.custom_minimum_size.y = head
	tray_head.custom_minimum_size.y = head
	tray_balance.visible = clocked
	_sync_head()
	apply_result(_result, _facts)


## "Game 2 of 3 · 1-0", the viewer's games first, as the series chip beside the gear reads. The
## score is left off until a game has been won.
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


## A ranked game's heading: "You win game 1" or "Bram Ashmark wins game 1".
static func game_heading(winner: int, viewer: int, names: Array, game: int) -> String:
	if winner < 0:
		return "Game %d has no winner" % game
	if winner == viewer:
		return "You win game %d" % game
	return "%s wins game %d" % [str(names[winner]), game]


## The match score from the leader's side: "You lead 1-0.", "Bram Ashmark leads 1-0." or "The
## match is tied 1-1."
static func lead_line(viewer: int, names: Array, wins: Array) -> String:
	var mine: int = int(wins[viewer])
	var theirs: int = int(wins[1 - viewer])
	if mine == theirs:
		return "The match is tied %d-%d." % [mine, theirs]
	if mine > theirs:
		return "You lead %d-%d." % [mine, theirs]
	return "%s leads %d-%d." % [str(names[1 - viewer]), theirs, mine]


## "Game 2 starts in 18 seconds.", never below one second: once the deal is due, or both players
## are ready and it is on its way, the last count stays.
static func countdown_line(game: int, next_at: int, now: int) -> String:
	var seconds: int = maxi(1, ceili((next_at - now) / 1000.0))
	return "Game %d starts in %d %s." % [game, seconds, "second" if seconds == 1 else "seconds"]


## How a duel, a game or a match ended outside the rules, naming the player it happened to. "" for a
## rules finish, and for the viewer's own concession, which the viewer already knows.
static func reason_line(reason: String, winner: int, viewer: int, names: Array) -> String:
	if not OFF_RULES.has(reason):
		return ""
	if winner < 0:
		return "Both clocks ran out at the same moment."
	var loser: int = 1 - winner
	var who: String = "You" if loser == viewer else str(names[loser])
	match reason:
		"concede", "concede_match":
			return "" if loser == viewer else "%s conceded." % who
		"timeout":
			return "%s ran out of time." % who
		"left":
			return "%s left." % who
	return ""


## "Your rating rose by 42 to 138.", "Your rating fell by 18 to 120." or "Your rating is unchanged."
static func rating_line(before: int, after: int) -> String:
	if after > before:
		return "Your rating rose by %d to %d." % [after - before, after]
	if after < before:
		return "Your rating fell by %d to %d." % [before - after, after]
	return "Your rating is unchanged."


## The words the result card shows in `state` for `facts` (see `apply_result`): {Title, Body,
## Rating, Note}, "" where a label says nothing. `now` is the ticks msec the count is read at.
static func result_texts(state: ResultState, mode: Mode, facts: Dictionary, now: int) -> Dictionary:
	var viewer: int = int(facts.get("viewer", -1))
	var names: Array = facts.get("names", ["", ""])
	var winner: int = int(facts.get("winner", -1))
	var reason: String = str(facts.get("reason", ""))
	var game: int = maxi(1, int(facts.get("game", 1)))
	var wins: Array = facts.get("wins", [0, 0])
	var texts: Dictionary = {&"Title": "", &"Body": "", &"Rating": "", &"Note": ""}
	match state:
		ResultState.GAME_PENDING:
			texts[&"Title"] = game_heading(winner, viewer, names, game)
			texts[&"Note"] = "Waiting for the result."
		ResultState.BETWEEN:
			texts[&"Title"] = game_heading(winner, viewer, names, game)
			texts[&"Body"] = lead_line(viewer, names, wins)
			texts[&"Note"] = countdown_line(game + 1, int(facts.get("next_at", now)), now)
		ResultState.MATCH:
			var payload: Dictionary = facts.get("match", {})
			var match_winner: int = int(payload.get("winner", -1))
			var match_wins: Array = payload.get("wins", wins)
			texts[&"Title"] = match_title(match_winner, viewer, match_wins)
			texts[&"Body"] = reason_line(str(payload.get("reason", "")), match_winner, viewer, names)
			var before: Array = payload.get("shown_before", [])
			var after: Array = payload.get("shown_after", [])
			if viewer >= 0 and before.size() == 2 and after.size() == 2:
				texts[&"Rating"] = rating_line(int(before[viewer]), int(after[viewer]))
		ResultState.RESULT:
			if mode == Mode.LOCAL or mode == Mode.ADVENTURE or viewer < 0:
				texts[&"Title"] = "No winner" if winner < 0 else "%s wins" % str(names[winner])
				texts[&"Body"] = str(facts.get("rules_text", ""))
			else:
				texts[&"Title"] = "No result" if winner < 0 else ("You win" if winner == viewer else "You lose")
				texts[&"Body"] = reason_line(reason, winner, viewer, names)
			if bool(facts.get("rival_gone", false)):
				texts[&"Note"] = str(facts.get("gone_note", ""))
			elif bool(facts.get("rematch_sent", false)) and viewer >= 0:
				texts[&"Note"] = "Waiting for %s." % str(names[1 - viewer])
		ResultState.LOST:
			texts[&"Title"] = str(facts.get("heading", "Connection lost"))
			texts[&"Body"] = str(facts.get("text", ""))
	return texts


## The result card's buttons in `state` for `facts`: node name -> [label, action], where the action
## is &"rematch", &"select" (Choose duelists, Continue, Back to lobby), &"find", &"ranked" or
## &"title".
static func result_buttons(state: ResultState, mode: Mode, can_rematch: bool, facts: Dictionary) -> Dictionary:
	var to_title: Array = ["Back to title", &"title"]
	match state:
		ResultState.MATCH:
			return {&"Primary": ["Find another ranked match", &"ranked"], &"Leave": to_title}
		ResultState.LOST:
			return {&"Leave": to_title}
		ResultState.RESULT:
			var gone: bool = bool(facts.get("rival_gone", false))
			var rematch: Array = ["Accept rematch" if bool(facts.get("rival_asked", false)) else "Rematch", &"rematch"]
			match mode:
				Mode.LOCAL:
					return {&"Primary": ["Rematch", &"rematch"], &"Leave": ["Choose duelists", &"select"]}
				Mode.ADVENTURE:
					return {&"Primary": ["Continue", &"select"]}
				Mode.QUEUE:
					var queue: Dictionary = {&"Primary": ["Find another duel", &"find"], &"Leave": to_title}
					if not gone:
						queue[&"Rematch"] = rematch
					return queue
				Mode.CODE:
					if can_rematch and not gone:
						return {&"Rematch": rematch, &"Leave": ["Back to lobby", &"select"]}
			return {&"Leave": to_title}
	return {}


## Sets every node of the result card, and the series chip, for `state` from `facts`, reading what
## to show from `RESULT_NODES`, `result_texts` and `result_buttons`. Entering a result from NONE
## clears the decision, the hand and the clocks. `facts`:
## - viewer: the seat at this table, -1 in hotseat; names: both seats' names; winner: the seat that
##   won the duel or game, -1 for none; reason: how it ended, a server word (see `OFF_RULES`) or a
##   rules one; rules_text: offline, the line for a rules finish.
## - game, wins, best_of: ranked, the game being played or just over and games won per seat;
##   next_at: between games, ticks msec of the next deal; ready: this seat pressed Ready.
## - match: the `Net.match_over` payload once the match is decided.
## - rival_asked, rematch_sent, rival_gone: a rematch the rival asked for, one this seat asked for,
##   and a rival who left, which takes Rematch away; gone_note: the line saying so.
## - heading, text: LOST's heading (default "Connection lost") and its sentence.
func apply_result(state: ResultState, facts: Dictionary = {}) -> void:
	var entering: bool = _result == ResultState.NONE and state != ResultState.NONE
	_result = state
	_facts = facts
	_duel_over = state != ResultState.NONE
	if entering:
		clear_clocks()
		clear_prompt()
		clear_hand()
	var shown: Array = RESULT_NODES[state]
	var texts: Dictionary = result_texts(state, _mode, facts, Time.get_ticks_msec())
	for pair: Array in [[&"Title", game_over_title], [&"Body", game_over_body], [&"Rating", game_over_rating], [&"Note", game_over_note]]:
		var label: Label = pair[1]
		var text: String = str(texts[pair[0]])
		if label.text != text:
			label.text = text
		# The note keeps its line even when empty, so a later note does not move the card.
		label.visible = shown.has(pair[0]) and (text != "" or label == game_over_note)
	var buttons: Dictionary = result_buttons(state, _mode, _can_rematch, facts)
	_button_actions.clear()
	for pair: Array in [[&"Primary", primary_button], [&"Rematch", rematch_button], [&"Leave", leave_button]]:
		var button: Button = pair[1]
		var spec: Array = buttons.get(pair[0], [])
		button.visible = shown.has(pair[0]) and not spec.is_empty()
		if button.visible:
			button.text = str(spec[0])
			_button_actions[pair[0]] = spec[1]
	rematch_button.disabled = bool(facts.get("rematch_sent", false))
	ready_button.visible = shown.has(&"Ready")
	ready_button.disabled = bool(facts.get("ready", false))
	game_over_actions.visible = rematch_button.visible or leave_button.visible
	var wins: Array = facts.get("wins", [0, 0])
	var viewer: int = int(facts.get("viewer", -1))
	var game: int = int(facts.get("game", 0))
	series_line.visible = _mode == Mode.RANKED and state == ResultState.NONE and game >= 1 and viewer >= 0
	if series_line.visible:
		var text: String = series_text(game, int(facts.get("best_of", 3)), int(wins[viewer]), int(wins[1 - viewer]))
		if series_line.text != text:
			series_line.text = text
	_show_modal()
	if options_menu.visible:
		set_options_open(true)


## The count to the next game; the rest of the card stands until the facts change.
func _show_next_count() -> void:
	if _result != ResultState.BETWEEN:
		return
	var text: String = str(result_texts(_result, _mode, _facts, Time.get_ticks_msec())[&"Note"])
	if game_over_note.text != text:
		game_over_note.text = text


func _on_ready() -> void:
	ready_button.disabled = true
	next_game_requested.emit()


func _on_result_button(button: Button) -> void:
	match _button_actions.get(StringName(button.name), &""):
		&"rematch":
			rematch_requested.emit()
		&"select":
			select_requested.emit()
		&"find":
			find_requested.emit()
		&"ranked":
			ranked_requested.emit()
		&"title":
			title_requested.emit()


func _on_tick() -> void:
	_show_next_count()
	_show_clock()
	_refresh_hint()


## The reconnect card while this client is cut off from its seat, counting down `left_ms`, the time
## the seat has before it loses; NONE gives the card back to the result, if one is up.
func set_overlay(overlay: Overlay, left_ms: int = 0) -> void:
	if overlay == Overlay.RECONNECTING:
		var text: String = "You lose if you are not back in %s." % clock_text(left_ms)
		if reconnect_status.text != text:
			reconnect_status.text = text
		if _overlay != overlay:
			reconnect_question.text = "Concede the match?" if _mode == Mode.RANKED else "Concede the duel?"
			_show_reconnect_confirm(false)
			set_options_open(false)
			hide_inspect()
			hide_pile()
			hide_peek()
	_overlay = overlay
	_show_modal()


## The reconnect card's Concede asks first, in place of its button.
func _show_reconnect_confirm(on: bool) -> void:
	reconnect_confirm.visible = on
	reconnect_give_up.visible = not on


## One card over the scrim: the reconnect card while it is up, otherwise the result when there is one.
func _show_modal() -> void:
	var reconnecting: bool = _overlay == Overlay.RECONNECTING
	reconnect.visible = reconnecting
	game_over.visible = not reconnecting and _result != ResultState.NONE
	var up: bool = reconnecting or game_over.visible
	if up and not modal.visible:
		SanctumUI.enter(result_card)
	modal.visible = up


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
	# An anchored trigger that is not the engine's `current` job still aims somewhere.
	if _filament_target < 0 and _anchor_target >= 0:
		_filament_target = _anchor_target
		_filament_uid = _anchor_uid
	if bool(view.attack.get("stopped", false)):
		_filament_state = &"stopped"
	elif bool(view.attack.get("landed", false)):
		_filament_state = &"landed"
	else:
		_filament_state = &"pending"


## `SeatView.pending` drives the Focus slot and its stack. The anchor is the declared attack, else the
## first job; the rest stack over it, next to resolve on top. A `wounds` job is a caption line, not a face.
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
	# A replay pin or the open decision's card owns the slot; only a HUD-anchored item is ours to move.
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
		# Already in the slot: only the caption can have moved on.
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


## The caption strip a stacked pending job carries.
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


## The beat for a skipped or passed window.
func quiet_beat(text: String, color: Color) -> void:
	show_banner(text, color, Banner.QUIET)


## A change of hands: Combat opening, the exchange passing to the other seat, a new turn.
func handover(text: String, color: Color) -> void:
	show_banner(text, color, Banner.HANDOVER)


## Seconds of game time the banner now up has been showing. `--dev-fast` speeds the tweens, so the
## age runs at the same rate.
func _banner_age() -> float:
	return float(Time.get_ticks_msec() - _banner_since) / 1000.0 * Engine.time_scale


## The table's centre on screen, clamped clear of the rail.
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


## One line into the full log. `card` is the card the line names, which also puts the line on the
## history strip; null for a line that names none.
func log_line(text: String, card: SeatCard = null) -> void:
	if card != null and not card.hidden():
		_history.push_front({"text": text, "def_id": card.def_id, "aspect": card.aspect, "owner": card.owner})
		if _history.size() > HISTORY_MAX:
			_history.resize(HISTORY_MAX)
		_fill_history()
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


## The card a log entry names, for the history strip: the event's own card or attack source when
## this seat's view shows its face and the line prints its title. Null for a line naming no card,
## such as a draw the seat may not read.
static func log_card(entry: Dictionary, view: SeatView) -> SeatCard:
	if view == null:
		return null
	var data: Dictionary = entry.get("data", {})
	var line: String = str(entry.get("line", ""))
	for key: String in ["card", "source"]:
		var c: SeatCard = view.card(int(data.get(key, -1)))
		if c != null and not c.hidden() and c.title != "" and line.contains(c.title):
			return c
	return null


func _fill_history() -> void:
	for child in history_thumbs.get_children():
		history_thumbs.remove_child(child)
		child.queue_free()
	history_tip.hide()
	for i in range(_history.size()):
		history_thumbs.add_child(_history_thumb(_history[i], i == 0))


## One face on the strip: the card's face, a thin edge lit on the newest, and its line on hover.
func _history_thumb(entry: Dictionary, newest: bool) -> Control:
	var thumb: Control = Control.new()
	thumb.custom_minimum_size = HISTORY_THUMB
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	thumb.mouse_filter = Control.MOUSE_FILTER_STOP
	thumb.modulate.a = 1.0 if newest else HISTORY_OLD_ALPHA
	var face: TextureRect = TextureRect.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumb.add_child(face)
	var edge: Panel = Panel.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), ZenithTheme.ACCENT if newest else ZenithTheme.BORDER, ZenithTheme.RADIUS, 2 if newest else 1, 0, 0))
	thumb.add_child(edge)
	var text: String = str(entry["text"])
	thumb.mouse_entered.connect(func() -> void: _show_history_tip(thumb, text))
	thumb.mouse_exited.connect(history_tip.hide)
	_history_face(face, entry)
	return thumb


func _history_face(face: TextureRect, entry: Dictionary) -> void:
	var def: CardDef = _def(str(entry["def_id"]))
	if def == null or _faces == null:
		return
	var owner: int = int(entry["owner"])
	var tex: Texture2D = await _faces.render_face(def, int(entry["aspect"]), seat_backdrop(owner), owner)
	if is_instance_valid(face):
		face.texture = tex


## A Resonance sigil on the board is under the pointer: its name, sentence and penalty in a framed
## tip under `anchor` (the sigil's screen rect), its right edge on the sigil's so it leaves the Life
## Deck beside the row alone, and above the sigil when there is no room below. The rival's is
## point-mirrored: `far`, with `anchor` the whole row clear of their hand fan
## (`DuelistDisplay.far_tip_anchor`), opens over the row from that left edge, and under it only when
## there is no room above. "" hides it.
func show_resonance_tip(id: String, anchor: Rect2, far: bool = false) -> void:
	if id == "" or not ResonanceData.has(id):
		resonance_tip.hide()
		return
	resonance_tip_name.text = ResonanceData.name_of(id)
	resonance_tip_effect.text = ResonanceData.effect_of(id)
	resonance_tip_penalty.text = ResonanceData.penalty_of(id)
	resonance_tip_penalty.visible = resonance_tip_penalty.text != ""
	resonance_tip.reset_size()
	var tip: Vector2 = resonance_tip.get_combined_minimum_size()
	var at: Vector2 = Vector2(anchor.end.x - tip.x, anchor.end.y + HISTORY_TIP_GAP)
	if far:
		at = Vector2(anchor.position.x + HISTORY_TIP_GAP, anchor.position.y - tip.y - HISTORY_TIP_GAP)
		# Pulled back left it would lie over the hand fan, so a tip without room goes under the row.
		if at.y < HISTORY_TIP_GAP or at.x + tip.x > root.size.x - HISTORY_TIP_GAP:
			at.y = anchor.end.y + HISTORY_TIP_GAP
	elif at.y + tip.y > root.size.y - HISTORY_TIP_GAP:
		at.y = anchor.position.y - tip.y - HISTORY_TIP_GAP
	at.x = clampf(at.x, HISTORY_TIP_GAP, maxf(HISTORY_TIP_GAP, root.size.x - tip.x - HISTORY_TIP_GAP))
	at.y = clampf(at.y, HISTORY_TIP_GAP, maxf(HISTORY_TIP_GAP, root.size.y - tip.y - HISTORY_TIP_GAP))
	resonance_tip.position = at
	resonance_tip.show()


## The hovered face's line, beside the strip and level with that face.
func _show_history_tip(thumb: Control, text: String) -> void:
	history_tip_text.text = text
	history_tip.reset_size()
	var top: float = clampf(thumb.get_global_rect().position.y, 0.0, maxf(0.0, root.size.y - history_tip.size.y))
	history_tip.position = Vector2(history.get_global_rect().end.x + HISTORY_TIP_GAP, top)
	history_tip.show()


# --- Prompt ---------------------------------------------------------------

## Where each option of a prompt is offered. Four buckets: `primary` buttons in the side panel,
## `browse` tiles in the tray, `finals` behind the Final Strike button, and `click` for options
## the player takes on the card itself. A `click` option is reachable only if the table draws that
## card; `tests/prompt_reach_tests.gd` checks each. Pure: it reads the views and nothing else.
func routes(p: PromptView, view: SeatView) -> Dictionary:
	var browse: Array[OptionView] = []
	var primary: Array[OptionView] = []
	var finals: Array[OptionView] = []
	var click: Array[OptionView] = []
	for opt in p.options:
		if opt.type == &"final_strike":
			finals.append(opt)
		elif opt.type == &"pick_option" and opt.card < 0:
			# A choice between wordings rather than cards, shown as card-sized tray tiles.
			browse.append(opt)
		elif BUTTON_KINDS.has(p.kind) or (opt.card < 0 and opt.type != &"name_card"):
			primary.append(opt)
		elif _needs_tray_in(p, opt, view):
			browse.append(opt)
		else:
			click.append(opt)
	return {"primary": primary, "browse": browse, "finals": finals, "click": click}


## Greys every option of the next prompt shown that `gate` does not open, each with its reason.
## {} opens them all again.
func set_gate(gate: Dictionary) -> void:
	_gate = gate


func option_open(opt: OptionView) -> bool:
	if _gate.is_empty() or _current_prompt == null:
		return true
	var i: int = _current_prompt.options.find(opt)
	var enabled: Array = _gate.get("enabled", [])
	return i < 0 or i >= enabled.size() or bool(enabled[i])


func option_reason(opt: OptionView) -> String:
	if _current_prompt == null:
		return ""
	var i: int = _current_prompt.options.find(opt)
	var reasons: Array = _gate.get("reasons", [])
	return str(reasons[i]) if i >= 0 and i < reasons.size() else ""


## A greyed control says why on hover, through `gated_hover`, and a click on it is reported.
func _explain_on_hover(control: Control, reason: String) -> void:
	control.tooltip_text = reason
	control.mouse_entered.connect(func() -> void: gated_hover.emit(reason))
	control.mouse_exited.connect(func() -> void: gated_hover.emit(""))
	control.gui_input.connect(func(event: InputEvent) -> void:
		var press: InputEventMouseButton = event as InputEventMouseButton
		if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
			gated_clicked.emit(reason))


## The screen rectangle of the control that offers an option `match` accepts, an open one before
## a greyed one: a decision button, or with `in_tray` a face or button of the tray. Rect2() when
## none is shown.
func option_rect(match: Callable, in_tray: bool = false) -> Rect2:
	var found: Rect2 = Rect2()
	var boxes: Array[Control] = []
	if in_tray and tray.visible:
		boxes.append_array([tray_cards, tray_buttons])
	elif not in_tray and prompt_panel.visible and not tray.visible:
		boxes.append(primary_box)
	for box in boxes:
		for child in box.get_children():
			var c: Control = child as Control
			if c == null or not c.visible or not c.has_meta("option"):
				continue
			var opt: OptionView = c.get_meta("option")
			if not bool(match.call(opt)):
				continue
			if option_open(opt):
				return c.get_global_rect()
			if not found.has_area():
				found = c.get_global_rect()
	return found


## Room kept free over the tray, so a note docked above it covers nothing. 0 gives it back.
func reserve_top(pixels: float) -> void:
	($Root/Tray/Center as Control).offset_top = pixels


func show_prompt(p: PromptView, view: SeatView) -> void:
	hide_pile()
	prompt_panel.show()
	_center_prompt_text(false)
	_view = view
	_current_prompt = p
	_owner_marks = CardText.option_side_marks(p, _viewer_seat)
	# The owner line is only for a waiting panel.
	prompt_who.text = ""
	_who_color = SeatColors.accent(view, p.player, Session.color_seed)
	prompt_title.text = _prompt_title(p, view)
	_show_attack(view, p)
	show_focus(_focus_uid(p), _focus_caption(p))
	_hint_base = _hint_for(p)
	_title_base = ""
	prompt_hint.text = _hint_base
	prompt_hint.visible = prompt_hint.text != ""
	# Options with previews reserve their row up front, so hovering one does not grow the frame.
	_reserve_outcome = false
	for o in p.options:
		_reserve_outcome = _reserve_outcome or not o.outcome.is_empty()
	_preview_outcome({})
	_compact_prompt()
	var routed: Dictionary = routes(p, view)
	var browse: Array[OptionView] = routed["browse"]
	var primaries: Array[OptionView] = routed["primary"]
	var finals: Array[OptionView] = routed["finals"]
	var library: Array = p.context.get("library", [])
	if p.kind == &"order":
		_fill_buttons([], primary_box, true)
		await _show_order(p)
		return
	_order_goal.clear()
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
			b.set_meta("option", finals[0])
			b.custom_minimum_size = Vector2(0, ACTION_HEIGHT)
			b.add_theme_font_size_override("font_size", ZenithTheme.SIZE_BODY)
			b.pressed.connect(func() -> void: _show_final_strike(finals))
			var open_final: bool = false
			for f in finals:
				open_final = open_final or option_open(f)
			if not open_final:
				b.disabled = true
				_explain_on_hover(b, option_reason(finals[0]))
			primary_box.add_child(b)
			_fit_actions()
	else:
		_fill_buttons([], primary_box, true)
		_show_tray(TRAY_WHO, prompt_title.text, prompt_hint.text, browse, primaries, false, p if p.has_batch() else null)


## A lone action becomes one large accent button that says what will happen; Space takes it.
func _make_single_action(p: PromptView, opt: OptionView, view: SeatView) -> void:
	if primary_box.get_child_count() != 1:
		return
	var b: Button = primary_box.get_child(0)
	b.text = _single_action_label(p, opt, view)
	b.theme_type_variation = &"AccentButton"
	b.custom_minimum_size = Vector2(0, SINGLE_ACTION_HEIGHT)
	b.add_theme_font_size_override("font_size", ZenithTheme.SIZE_ROW)
	if option_open(opt):
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


## The exchange rail, from the public attack. Pending and resolved amounts stay separate.
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
		# `resolving` carries no order; the pending pile shows a run of them in order.
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
	# A fixed one-line floor: a wrapping label measured before its parent has width comes out
	# hundreds of pixels tall.
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
			return "Spending it removes it from the game."
		&"defense":
			if bool(p.context.get("try", false)):
				return "Some of these cards cannot stop this attack. Played anyway, they resolve their other effects and the attack still lands."
			return ""
		&"order":
			if str(p.context.get("purpose", "")) == "shields":
				return "The Shield on the left stops the attack first and is spent. Drag a card to a new place, or use its arrows."
			return "The card on the left resolves first. Drag a card to a new place, or use its arrows."
		&"follow_up":
			if bool(p.context.get(DuelEngine.USE_WHEN_NEEDED, false)):
				return "A use-when-needed card may be used here, between the steps of the attack or outside Combat."
			return ""
		&"recover":
			return "One discard card may go back under the deck."
		&"respond":
			if str(p.context.get("mode", "")) == "declare":
				return "Use a card before they decide on Combat."
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
			if str(p.context.get("purpose", "")) == "wild_might":
				var line: String = str(p.context.get("text", ""))
				var counted: String = "higher" if str(p.context.get("runs_on", "higher")) == "higher" else "not higher"
				if line == "":
					return "Wild Might has no number, so you decide. Counted as higher, the card's Might bonuses apply."
				return "Wild Might has no number, so you decide. Counted as %s, the card does this: %s" % [counted, line]
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
	_order_goal.clear()
	prompt_who.text = "%s  ·  DECIDING" % player_name.to_upper()
	prompt_who.add_theme_color_override("font_color", ZenithTheme.MUTED)
	prompt_title.text = "Waiting for %s" % player_name
	_show_attack(view, null)
	prompt_who.visible = not exchange_rail.visible
	if exchange_rail.visible:
		prompt_title.text = "Opponent deciding"
	_title_base = prompt_title.text
	show_focus(_focus_uid(null), _focus_caption(null))
	_hint_base = _waiting_hint(kind)
	prompt_hint.text = _hint_base
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
		&"order":
			return "They are choosing the order of their effects."
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
	_rejoined = false
	_title_base = ""
	_hint_base = "Sending your choice to the host."
	prompt_hint.text = _hint_base
	prompt_hint.visible = true


## One clicked card with more than one legal action: the card, its actions as buttons, and Back.
func show_card_choice(options: Array[OptionView]) -> void:
	var c: SeatCard = _view.card(options[0].card)
	var single: Array[OptionView] = [options[0]]
	# A card whose only action is a Final Strike warns up front, and its button is not the default.
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
	_title_base = ""
	_owner_marks = {}
	hide_peek()
	prompt_who.text = ""
	prompt_title.text = "…"
	exchange_rail.hide()
	prompt_hint.visible = false
	hide_focus()
	_hide_tray()
	_fill_buttons([], primary_box, true)


## Equal-emphasis buttons: vertical in the side panel, a row in the tray.
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
		b.set_meta("option", opt)
		b.pressed.connect(func() -> void: option_chosen.emit(opt))
		if not option_open(opt):
			b.disabled = true
			_explain_on_hover(b, option_reason(opt))
		elif not opt.outcome.is_empty():
			b.mouse_entered.connect(func() -> void: _preview_outcome(opt.outcome))
			b.mouse_exited.connect(func() -> void: _preview_outcome({}))
			b.focus_entered.connect(func() -> void: _preview_outcome(opt.outcome))
			b.focus_exited.connect(func() -> void: _preview_outcome({}))
		into.add_child(b)
	# The box's minimum-size signal is deferred and stays silent when the new buttons match the old
	# size, so the fit is called outright.
	if into == primary_box:
		_fit_actions()


# --- Match replay ---------------------------------------------------------

## A recorded duel played back: shows the replay bar, fills its turn list and names both views.
func set_match_replay(names: Array[String], turns: Array[Dictionary], view_index: int) -> void:
	_match_replay = true
	_mode = Mode.REPLAY
	replay_bar.visible = true
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
	_hint_base = "Took %.1f s" % (gap_ms / 1000.0) if gap_ms > 0 else ""
	prompt_hint.text = _hint_base
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
	_hint_base = reason
	prompt_hint.text = reason
	# A duel can end with wounds still owed; the attack left pending is not shown.
	hide_focus()


## A replay this client cannot play: the result panel says why, with only the way back to the title.
func show_replay_refused(reason: String) -> void:
	apply_result(ResultState.LOST, {"heading": "Cannot play this replay", "text": reason})


func clear_log() -> void:
	log_text.clear()
	_log_lines = 0
	_history.clear()
	_fill_history()


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
	hide_focus()
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
		var not_a_choice: String = str(_gate.get("library", ""))
		if not not_a_choice.is_empty():
			_explain_on_hover(face, not_a_choice)
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
	# Only ever turns the panel back on; callers that want it hidden clear the prompt first.
	if tray.visible and _current_prompt != null:
		prompt_panel.visible = true
	tray.visible = false
	hand.visible = not external_hand
	_batch = null
	_confirm = null
	_selected.clear()
	_entries.clear()
	_order_entries.clear()


## A choice with no card behind it, as a card-sized tile with its wording in the middle.
func _tray_choice_entry(opt: OptionView) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.set_meta("option", opt)
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
	if not option_open(opt):
		b.disabled = true
		b.add_theme_color_override("font_disabled_color", ZenithTheme.TEXT_DISABLED)
		_explain_on_hover(b, option_reason(opt))
		frame.add_child(b)
		column.add_child(frame)
		return column
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


## A face with its caption. Clicking it picks the option unless it is a sub-choice. A named-card
## option carries a title instead of a uid.
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
	column.set_meta("option", opt)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), ZenithTheme.RADIUS, 3, 3, 3))
	frame.pivot_offset = _tray_face * 0.5 + Vector2(3.0, 3.0)
	var b: TextureButton = TextureButton.new()
	b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.custom_minimum_size = _tray_face
	var batch: bool = _batch != null
	var open: bool = option_open(opt)
	if not open:
		b.modulate = Color(1, 1, 1, 0.45)
		_explain_on_hover(b, option_reason(opt))
	elif batch:
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
	# The owner mark is set only when two faces' labels would read alike.
	var mark: String = str(_owner_marks.get(uid, ""))
	if mark != "":
		b.tooltip_text = opt.label + mark
	if not sub_choice:
		var verb: String = str(TRAY_VERBS.get(opt.type, opt.label)) + mark
		var caption: Label = Label.new()
		caption.text = verb if open else ""
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", ZenithTheme.SIZE_BODY)
		caption.add_theme_color_override("font_color", ZenithTheme.MUTED if batch or not open else ZenithTheme.ACCENT)
		column.add_child(caption)
		if batch:
			_entries[uid] = {"frame": frame, "caption": caption, "verb": verb}
	return column


# --- Order stack ----------------------------------------------------------

## The order prompt as a row of the effects in the order they will resolve, first on the left. The
## player rearranges it here by dragging a card or with its arrows, and nothing is sent until the
## confirm button; then one move goes per prompt (`order_step`) until the engine's sequence matches,
## and the confirm last. A prompt that comes back mid-way shows the arrangement being sent.
func _show_order(p: PromptView) -> void:
	var ids: Array[int] = _ints(p.context.get("ids", []))
	if not _order_goal.is_empty() and order_step(ids, _order_goal) < 0:
		_order_goal.clear()
	var sending: bool = not _order_goal.is_empty()
	_order_ids = _order_goal.duplicate() if sending else ids.duplicate()
	_order_entries.clear()
	await _show_tray(TRAY_WHO, prompt_title.text, prompt_hint.text, [], [], false)
	var cards: Array = p.context.get("cards", [])
	var titles: Array = p.context.get("order", [])
	var lines: Array = p.context.get("lines", [])
	var layout: Dictionary = order_layout(ids.size(), root.size)
	var face: Vector2 = layout["face"]
	for i in range(ids.size()):
		var uid: int = int(cards[i]) if i < cards.size() else -1
		var title: String = str(titles[i]) if i < titles.size() else ""
		var line: String = str(lines[i]) if i < lines.size() else ""
		var parts: Dictionary = await _order_entry(ids[i], uid, title, line, face)
		if p != _current_prompt:
			return
		_order_entries[ids[i]] = parts
		tray_cards.add_child(parts["entry"] as Control)
	_arrange_order()
	var cell: Vector2 = face + Vector2(TRAY_FRAME.x, ORDER_EXTRA)
	var columns: int = int(layout["columns"])
	tray_scroll.custom_minimum_size = Vector2(maxf(ORDER_MIN_WIDTH, columns * (cell.x + TRAY_GAP) + TRAY_GAP),
		minf(int(layout["rows"]) * (cell.y + TRAY_GAP), root.size.y * TRAY_HEIGHT_SHARE))
	var confirm: Button = Button.new()
	confirm.text = "Resolve in this order"
	confirm.theme_type_variation = &"AccentButton"
	confirm.custom_minimum_size = Vector2(320, 60)
	confirm.add_theme_font_size_override("font_size", ZenithTheme.SIZE_BODY)
	var shown: OptionView = p.find(&"order_confirm")
	if shown != null:
		confirm.set_meta("option", shown)
		confirm.tooltip_text = "Resolve %s." % ", then ".join(PackedStringArray(_order_titles(p)))
		if not option_open(shown):
			confirm.disabled = true
			_explain_on_hover(confirm, option_reason(shown))
	confirm.pressed.connect(func() -> void:
		_order_goal = _order_ids.duplicate()
		_send_order_step(p))
	tray_buttons.add_child(confirm)
	if sending:
		_send_order_step.call_deferred(p)


## The titles in the tray's arrangement.
func _order_titles(p: PromptView) -> Array[String]:
	var ids: Array[int] = _ints(p.context.get("ids", []))
	var titles: Array = p.context.get("order", [])
	var out: Array[String] = []
	for id in _order_ids:
		var i: int = ids.find(id)
		out.append(str(titles[i]) if i >= 0 and i < titles.size() else "")
	return out


## The face size, columns and rows of an order row of `count` effects: the tray's layout, with each
## face short enough that its rank, description and arrows fit under the rows shown.
static func order_layout(count: int, screen: Vector2) -> Dictionary:
	var grid: Dictionary = tray_layout(count, screen)
	var rows: int = int(grid["rows"])
	var down: float = (screen.y * TRAY_HEIGHT_SHARE / rows - TRAY_GAP - ORDER_EXTRA) / CARD_ASPECT
	var width: float = clampf(minf((grid["face"] as Vector2).x, down), TRAY_CARD_SIZE.x, TRAY_CARD_MAX_WIDTH)
	return {"face": Vector2(width, width * CARD_ASPECT), "columns": int(grid["columns"]), "rows": rows}


## The next answer toward the arrangement `goal` from the engine's sequence `ids`: the position (from
## 1) of the `order_up` that brings the first misplaced effect one place nearer, 0 when the sequence
## already matches and only the confirm is left, or -1 when `goal` is not an order of `ids`.
static func order_step(ids: Array[int], goal: Array[int]) -> int:
	if ids.size() != goal.size():
		return -1
	for k in range(goal.size()):
		if ids[k] == goal[k]:
			continue
		var at: int = ids.find(goal[k])
		return at if at > k else -1
	return 0


func _send_order_step(p: PromptView) -> void:
	if p == null or p != _current_prompt or _order_goal.is_empty():
		return
	var step: int = order_step(_ints(p.context.get("ids", [])), _order_goal)
	var opt: OptionView = null
	if step == 0:
		opt = p.find(&"order_confirm")
		_order_goal.clear()
	elif step > 0:
		opt = p.find(&"order_up", -1, step)
	if opt == null or not option_open(opt):
		_order_goal.clear()
		return
	option_chosen.emit(opt)


## One effect in the order row: its rank, its face (or its name, for a standing effect with no
## card), what it will do, and the arrows that move it a place.
func _order_entry(id: int, uid: int, title: String, line: String, face_size: Vector2) -> Dictionary:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", ZenithTheme.GAP_XS)
	column.custom_minimum_size = Vector2(face_size.x + TRAY_FRAME.x, 0.0)
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	var rank: Label = Label.new()
	rank.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rank.add_theme_font_size_override("font_size", ZenithTheme.SIZE_BODY)
	column.add_child(rank)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _order_frame(false))
	frame.pivot_offset = face_size * 0.5 + Vector2(3.0, 3.0)
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	var c: SeatCard = _view.card(uid) if _view != null and uid >= 0 else null
	var def: CardDef = _def(c.def_id) if c != null and not c.hidden() else null
	var face: Control = null
	if def != null and _faces != null:
		var tex: TextureRect = TextureRect.new()
		tex.texture = await _faces.render_face(def, c.aspect, _uid_backdrop(uid), _uid_owner(uid))
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		var aspect: int = c.aspect
		tex.mouse_entered.connect(func() -> void:
			show_peek(def, aspect, uid)
			card_hovered.emit(uid, true))
		tex.mouse_exited.connect(func() -> void:
			hide_peek()
			card_hovered.emit(uid, false))
		tex.gui_input.connect(func(event: InputEvent) -> void:
			if _is_inspect_click(event):
				show_inspect(def, aspect, uid))
		face = tex
	else:
		var tile: Label = Label.new()
		tile.text = title
		tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.add_theme_font_size_override("font_size", ZenithTheme.SIZE_ROW)
		tile.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.BORDER, ZenithTheme.RADIUS, 1, 12, 12))
		face = tile
	face.custom_minimum_size = face_size
	face.mouse_filter = Control.MOUSE_FILTER_STOP
	face.mouse_default_cursor_shape = Control.CURSOR_DRAG
	face.tooltip_text = "Drag %s to a new place in the order." % (title if title != "" else "this card")
	var dropped: Callable = func(_at: Vector2, data: Variant) -> void: _order_drop(id, data)
	var droppable: Callable = func(_at: Vector2, data: Variant) -> bool: return _order_can_drop(id, data)
	face.set_drag_forwarding(func(_at: Vector2) -> Variant: return _order_drag(id, face), droppable, dropped)
	column.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, droppable, dropped)
	frame.add_child(face)
	column.add_child(frame)
	var text: Label = Label.new()
	text.text = line
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.max_lines_visible = ORDER_LINES
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.custom_minimum_size = Vector2(face_size.x, 0.0)
	text.add_theme_font_size_override("font_size", ZenithTheme.SIZE_CAPTION)
	text.add_theme_color_override("font_color", ZenithTheme.TEXT_SOFT)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if line != "":
		text.tooltip_text = line
		text.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(text)
	var arrows: HBoxContainer = HBoxContainer.new()
	arrows.add_theme_constant_override("separation", ZenithTheme.GAP_XS)
	var earlier: Button = _order_arrow("‹ Earlier", "Resolve %s one place earlier." % title, func() -> void: _order_move(id, -1))
	var later: Button = _order_arrow("Later ›", "Resolve %s one place later." % title, func() -> void: _order_move(id, 1))
	arrows.add_child(earlier)
	arrows.add_child(later)
	column.add_child(arrows)
	return {"entry": column, "frame": frame, "rank": rank, "earlier": earlier, "later": later}


func _order_arrow(text: String, tip: String, pressed: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.tooltip_text = tip
	b.theme_type_variation = &"CompactButton"
	b.custom_minimum_size = Vector2(0.0, 40.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(pressed)
	return b


func _order_frame(lit: bool) -> StyleBoxFlat:
	return ZenithTheme.box(Color(0, 0, 0, 0), ZenithTheme.ACCENT if lit else Color(0, 0, 0, 0), ZenithTheme.RADIUS, 3, 3, 3)


func _order_drag(id: int, source: Control) -> Variant:
	if not _order_entries.has(id) or not _order_goal.is_empty():
		return null
	hide_peek()
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ghost: Control = source.duplicate(0)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = source.size
	ghost.scale = Vector2.ONE * ORDER_GHOST
	ghost.position = -source.size * ORDER_GHOST * 0.5
	ghost.modulate = Color(1, 1, 1, 0.85)
	holder.add_child(ghost)
	source.set_drag_preview(holder)
	return {"order_id": id}


func _order_can_drop(id: int, data: Variant) -> bool:
	if not (data is Dictionary) or not (data as Dictionary).has("order_id") or not _order_entries.has(id):
		return false
	var ok: bool = int((data as Dictionary)["order_id"]) != id
	for key in _order_entries.keys():
		((_order_entries[key] as Dictionary)["frame"] as PanelContainer).add_theme_stylebox_override("panel", _order_frame(ok and int(key) == id))
	return ok


func _order_drop(id: int, data: Variant) -> void:
	if not _order_can_drop(id, data):
		return
	var from: int = _order_ids.find(int((data as Dictionary)["order_id"]))
	var to: int = _order_ids.find(id)
	if from < 0 or to < 0:
		return
	var moved: int = _order_ids[from]
	_order_ids.remove_at(from)
	_order_ids.insert(to, moved)
	_arrange_order()


func _order_move(id: int, step: int) -> void:
	var at: int = _order_ids.find(id)
	var to: int = at + step
	if at < 0 or to < 0 or to >= _order_ids.size() or not _order_goal.is_empty():
		return
	_order_ids[at] = _order_ids[to]
	_order_ids[to] = id
	_arrange_order()
	var parts: Dictionary = _order_entries[id]
	var arrow: Button = parts["earlier"] if step < 0 else parts["later"]
	if arrow.disabled:
		arrow = parts["later"] if step < 0 else parts["earlier"]
	arrow.grab_focus()


## Puts the entries in the tray's arrangement and renumbers them; the first is marked in full.
func _arrange_order() -> void:
	var last: int = _order_ids.size() - 1
	for k in range(_order_ids.size()):
		var id: int = _order_ids[k]
		if not _order_entries.has(id):
			continue
		var parts: Dictionary = _order_entries[id]
		tray_cards.move_child(parts["entry"] as Control, k)
		var rank: Label = parts["rank"]
		rank.text = ordinal(k + 1)
		ZenithTheme.chip(rank, ZenithTheme.ACCENT, k == 0)
		(parts["frame"] as PanelContainer).add_theme_stylebox_override("panel", _order_frame(false))
		(parts["earlier"] as Button).disabled = k == 0
		(parts["later"] as Button).disabled = k == last


static func ordinal(n: int) -> String:
	var tens: int = n % 100
	if tens >= 11 and tens <= 13:
		return "%dth" % n
	match n % 10:
		1:
			return "%dst" % n
		2:
			return "%dnd" % n
		3:
			return "%drd" % n
	return "%dth" % n


static func _ints(v: Variant) -> Array[int]:
	var out: Array[int] = []
	if v is Array:
		for x in v:
			out.append(int(x))
	return out


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

## Reads a public pile top first, with nothing to pick. Either seat may open either player's pile.
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


## One card in a browsed pile: hover for the quick view, right-click to inspect.
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
	var first_faces: bool = _faces == null and faces != null
	_faces = faces
	if first_faces and not _history.is_empty():
		_fill_history()
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
		# The referee's total after the table and every modifier.
		var forecast: Dictionary = _view.forecast(uid) if _view != null else {}
		if not forecast.is_empty():
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
	inspect_face.show_def(def, aspect, _live_energy(uid), _standing(uid), _uid_backdrop(uid), _uid_table(def, uid), _live_might(uid))
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


## The card a decision is about, in the Focus slot on the rail. Both seats see it, and it never
## takes the mouse.
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
	focus_face.show_def(def, c.aspect, _live_energy(uid), _standing(uid), seat_backdrop(c.owner), _uid_table(def, uid), _live_might(uid))
	focus.visible = true
	_compact_prompt()


## A replay beat's card in the same Focus slot. `uid`, when known, tells the pending stack and the
## filament which card is up.
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


## Recaptions the pinned card without redrawing it.
func set_focus_caption(caption: String, color: Color) -> void:
	_caption_base = caption
	focus_caption.add_theme_color_override("font_color", color)
	_apply_caption()


## The slot's caption, plus the wound loop the attack still owes.
func _apply_caption() -> void:
	var text: String = _caption_base
	if not _wounds_note.is_empty() and focus.visible:
		text += " · %s to resolve" % _wounds_note
	focus_caption.text = text.to_upper()
	# One clipped line one card wide: a long caption drops to the caption size.
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


## A response pushed onto the stack over the pinned attack. `owner` (`&"attack"` or `&"defend"`)
## picks the tint and the leaving direction; `pop_response` later names it by `uid`.
func push_response(def: CardDef, caption: String, owner: StringName, uid: int = -1) -> bool:
	if def == null or stack == null or tray.visible or inspect.visible or not focus.visible:
		return false
	var tint: Color = ZenithTheme.ATTACK if owner == &"attack" else ZenithTheme.DEFEND
	var held: Control = _entry_for_uid(uid)
	if held != null:
		# Already dealt by the pending list: rename it rather than stack a copy.
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


## A masked job's face: the card back under the same caption strip.
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


## Level 0 lies over the attack's lower half; each level after steps up and left, newest on top.
func _layout_stack() -> void:
	if stack == null or focus == null or _stack.is_empty():
		if _overflow != null and is_instance_valid(_overflow):
			_overflow.visible = false
		return
	var width: float = focus.offset_right - focus.offset_left
	var face_width: float = width * STACK_SCALE
	var face_height: float = face_width * CARD_ASPECT
	var attack_height: float = width * CARD_ASPECT
	var base: Vector2 = Vector2((width - face_width) * 0.5 + width * STACK_INSET, attack_height - face_height - 6.0)
	for i in range(_stack.size()):
		var entry: Control = _stack[i]
		var level: int = mini(i, STACK_MAX - 1)
		var spot: Vector2 = base + STACK_STEP * width * float(level)
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
		var top: Control = _stack.back()
		_overflow.visible = true
		_overflow.size = Vector2(52.0, 26.0)
		_overflow.position = top.position + Vector2(top.size.x - 56.0, 4.0)


## The beat that resolves a response takes it off the stack. `key` is the card's uid when the stack
## carries one, and otherwise a level index counted from the bottom. False when the stack never held it.
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


## One face off the pile with the leaving animation, from a beat or a refresh.
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


## Lights a card in the Focus slot or on its stack. False when it is not on the rail, so the caller
## falls back to the table spotlight.
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


# --- Decision clock (online) --------------------------------------------------

## A seat's clock from the server. Only a clocked HUD takes it, and a result already up ignores it.
func set_clock(seat: int, left_ms: int, bank_ms: int, phase: String) -> void:
	if not _clocked or _duel_over or seat < 0 or seat > 1:
		return
	_clocks[seat] = {"left_ms": left_ms, "bank_ms": bank_ms, "phase": phase, "at": Time.get_ticks_msec()}
	_show_clock()


func clear_clocks() -> void:
	_clocks = [{}, {}]
	_show_clock()


## A seat's clock counted down from the last state the server sent: `phase` DuelClock.RUN on the
## timer (the server's warning phase included) or DuelClock.BANK, `ms` the timer or the bank as
## that phase shows it, `bank` the bank behind the timer, `total` both together (-1 when no clock
## runs), and `fraction` the share of the last 10 s still left, which the fuse burns down.
func clock_now(seat: int) -> Dictionary:
	var c: Dictionary = _clocks[seat] if seat == 0 or seat == 1 else {}
	var phase: String = str(c.get("phase", DuelClock.OFF))
	if phase == DuelClock.OFF:
		return {"phase": DuelClock.OFF, "ms": 0, "bank": 0, "total": -1, "fraction": 0.0}
	var elapsed: int = Time.get_ticks_msec() - int(c["at"])
	var ms: int = 0
	var bank: int = 0
	if phase == DuelClock.BANK:
		ms = maxi(0, int(c["bank_ms"]) - elapsed)
		bank = ms
	else:
		ms = maxi(0, int(c["left_ms"]) - elapsed)
		bank = maxi(0, int(c["bank_ms"]))
		phase = DuelClock.RUN
	var total: int = ms if phase == DuelClock.BANK else ms + bank
	return {"phase": phase, "ms": ms, "bank": bank, "total": total,
		"fraction": clampf(float(total) / float(CLOCK_WARN_MS), 0.0, 1.0)}


## This seat's own clock in words: "0:23 + bank 1:10" on the timer, "Bank 0:48" on the bank, and
## "You lose in 0:09." once timer and bank together are 10 s or less.
static func clock_line(clock: Dictionary) -> String:
	var total: int = int(clock["total"])
	if total <= CLOCK_WARN_MS:
		return "You lose in %s." % clock_text(total)
	if str(clock["phase"]) == DuelClock.BANK:
		return "Bank %s" % clock_text(int(clock["ms"]))
	if int(clock["bank"]) <= 0:
		return clock_text(int(clock["ms"]))
	return "%s + bank %s" % [clock_text(int(clock["ms"])), clock_text(int(clock["bank"]))]


## "0:23", whole seconds rounded up, so the last second reads 0:01 rather than 0:00.
static func clock_text(ms: int) -> String:
	var seconds: int = ceili(maxi(0, ms) / 1000.0)
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]


## All the time a seat has left on the decision it owes, timer and bank together, counted from the
## last state the server sent; -1 while no clock runs for it.
func clock_left_ms(seat: int) -> int:
	return int(clock_now(seat)["total"])


## The rival's tab by their duelist, `{tab, text, warn}` with `tab` a `DuelistReadout.Tab`: AWAY
## while their connection is down ("Disconnected 1:16", `away_ms` being Net's grace for them, -1
## while they are here, or their clock when it ends first), BANK while they spend their bank ("Time
## bank 0:48", warning in its last 10 s), NONE while they decide on their timer or not at all.
func rival_tab(seat: int, away_ms: int) -> Dictionary:
	var none: Dictionary = {"tab": DuelistReadout.Tab.NONE, "text": "", "warn": false}
	if not _clocked or _duel_over:
		return none
	var c: Dictionary = clock_now(seat)
	if away_ms >= 0:
		var left: int = away_ms if int(c["total"]) < 0 else mini(away_ms, int(c["total"]))
		return {"tab": DuelistReadout.Tab.AWAY, "text": "Disconnected %s" % clock_text(left), "warn": true}
	if str(c["phase"]) == DuelClock.BANK:
		return {"tab": DuelistReadout.Tab.BANK, "text": "Time bank %s" % clock_text(int(c["ms"])),
			"warn": int(c["total"]) <= CLOCK_WARN_MS}
	return none


## The prompt's line while it waits on a rival whose connection dropped: "Sable Draik has 1:16 to
## come back.", `ms` their grace or their clock, whichever ends first.
static func away_line(player_name: String, ms: int) -> String:
	return "%s has %s to come back." % [player_name, clock_text(ms)]


## The waiting panel's away line (`away_line`), "" once the rival is back.
func set_rival_away(line: String) -> void:
	if line == _away_line:
		return
	_away_line = line
	_refresh_hint()


## This client is back in a duel it dropped from: until it answers, its decision's hint also says
## how long it has.
func set_rejoined(on: bool) -> void:
	_rejoined = on
	_refresh_hint()


## The waiting panel's title and a decision's hint plus the clock's line. The away line replaces the
## waiting title; after a rejoin, "You have 0:34 left." goes under the hint until it is answered.
func _refresh_hint() -> void:
	if prompt_hint == null or not prompt_panel.visible:
		return
	if _title_base != "" and _current_prompt == null and not _match_replay:
		var title: String = _away_line if _away_line != "" else _title_base
		if prompt_title.text != title:
			prompt_title.text = title
		return
	var line: String = ""
	if _rejoined and _current_prompt != null and not _match_replay:
		var left: int = clock_left_ms(_current_prompt.player)
		if left >= 0:
			line = "You have %s left." % clock_text(left)
	var text: String = _hint_base
	if line != "":
		text = line if _hint_base == "" else "%s\n%s" % [_hint_base, line]
	elif prompt_hint.text == _hint_base:
		return
	if prompt_hint.text != text:
		prompt_hint.text = text
	prompt_hint.visible = text != ""


## This seat's countdown in the prompt panel's or the tray's head row. Redrawn on the 1 s tick and
## when a clock state arrives, never per frame.
func _show_clock() -> void:
	if not _clocked:
		return
	var seat: int = _current_prompt.player if _current_prompt != null and not _match_replay else -1
	var c: Dictionary = clock_now(seat)
	var on: bool = _clocked and str(c["phase"]) != DuelClock.OFF
	var warn: bool = on and int(c["total"]) <= CLOCK_WARN_MS
	var text: String = clock_line(c) if on else ""
	var variation: StringName = &"ClockWarnLabel" if warn else &"ClockLabel"
	for pair: Array in [[prompt_clock, prompt_fuse, false], [tray_clock, tray_fuse, true]]:
		var label: Label = pair[0]
		var fuse: ProgressBar = pair[1]
		var shown: bool = on and bool(pair[2]) == tray.visible
		# The tray's clock keeps its place while clocked, balancing the spacer that centres its owner line.
		var kept: bool = shown or (label == tray_clock and _clocked)
		if label.visible != kept:
			label.visible = kept
		var words: String = text if shown else ""
		if label.text != words:
			label.text = words
		if label.theme_type_variation != variation:
			label.theme_type_variation = variation
		var burning: bool = shown and warn
		if fuse.visible != burning:
			fuse.visible = burning
		if burning:
			fuse.value = float(c["fraction"])
	_sync_head()


## The prompt panel's head row shows while it has an owner line or a clock, and in a clocked duel
## while this seat decides, so the clock arriving does not move the panel.
func _sync_head() -> void:
	if prompt_head == null:
		return
	var shown: bool = prompt_who.visible or prompt_clock.visible or (_clocked and _current_prompt != null and not _match_replay)
	if prompt_head.visible != shown:
		prompt_head.visible = shown


## The thread from the pinned card to its target: a cap when stopped, a double chevron once landed.
## Hidden when nothing is aimed or the table cannot place the target.
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
	var color: Color = ZenithTheme.ATTACK.lightened(0.25)
	if _filament_state == &"stopped":
		color = ZenithTheme.DEFEND
	elif _filament_state == &"landed":
		color = ZenithTheme.ACCENT
	filament_thread.points = bezier(start - base, end - base, side * (travel.length() * FILAMENT_BOW))
	filament_thread.default_color = Color(color, 0.38 if _filament_state == &"stopped" else 0.64)
	var stopped: bool = _filament_state == &"stopped"
	filament_cap.visible = stopped
	filament_head.visible = not stopped
	filament_head_trail.visible = _filament_state == &"landed"
	if stopped:
		filament_cap.points = PackedVector2Array([end - side * FILAMENT_CAP - base, end + side * FILAMENT_CAP - base])
		filament_cap.default_color = Color(color, 0.9)
	else:
		filament_head.points = chevron(end - base, direction)
		filament_head.default_color = Color(color, 0.95)
		if filament_head_trail.visible:
			filament_head_trail.points = chevron(end - direction * FILAMENT_CHEVRON.x * 0.82 - base, direction)
			filament_head_trail.default_color = Color(color, 0.95)
	filament.visible = true


## The filament's curve, shared with the tutorial's tether: a quadratic bezier from `start` to
## `end` whose control point stands `bend` off their midpoint.
static func bezier(start: Vector2, end: Vector2, bend: Vector2, samples: int = FILAMENT_SAMPLES) -> PackedVector2Array:
	var middle: Vector2 = (start + end) * 0.5 + bend
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(samples + 1):
		var ratio: float = float(i) / float(samples)
		points.append(start.lerp(middle, ratio).lerp(middle.lerp(end, ratio), ratio))
	return points


## An open arrowhead at `tip`, pointing along `direction` (a unit vector).
static func chevron(tip: Vector2, direction: Vector2, extent: Vector2 = FILAMENT_CHEVRON) -> PackedVector2Array:
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var back: Vector2 = tip - direction * extent.x
	return PackedVector2Array([back + side * extent.y, tip, back - side * extent.y])


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


## The Might of a personality in play, -1 for anything else.
func _live_might(uid: int) -> int:
	if _live_energy(uid) < 0:
		return -1
	return _view.card(uid).might


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


## The options menu, from the gear or Esc. Its shade takes the mouse while open; a click on it closes the menu.
func set_options_open(on: bool) -> void:
	options_button.set_pressed_no_signal(on)
	options_button.queue_redraw()
	options_menu.visible = on
	options_shade.visible = on
	_show_menu_question(&"")
	if on:
		_refresh_menu()


## Read each time the menu opens. While a game runs: Concede (game and match when ranked), Rematch
## in hotseat and vs AI, and Back to title offline. Between ranked games only Concede match. Once a
## result is up only Back to title.
func _refresh_menu() -> void:
	var running: bool = _result == ResultState.NONE and not _match_replay
	var between: bool = _result == ResultState.GAME_PENDING or _result == ResultState.BETWEEN
	var online: bool = _mode == Mode.CODE or _mode == Mode.QUEUE or _mode == Mode.RANKED
	menu_concede.visible = running and _mode != Mode.TUTORIAL
	menu_concede.text = "Concede game" if _mode == Mode.RANKED else "Concede"
	menu_concede_match.visible = _mode == Mode.RANKED and (running or between)
	menu_rematch.visible = running and _mode == Mode.LOCAL
	menu_leave.visible = not between and not (running and online)
	menu_leave.text = "Back to title"
	for row: Control in [menu_replay_speed.get_parent(), menu_replay_view.get_parent()]:
		row.visible = _match_replay
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	fullscreen_toggle.set_pressed_no_signal(mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


## What a menu item asks before it acts, "" when it acts at once. Only what ends or loses something
## asks: a concession, and abandoning a hotseat or vs-AI duel still running. An adventure's Back to
## title never does, since the run is saved after every command.
func _menu_question(action: StringName) -> String:
	var running: bool = _result == ResultState.NONE and not _match_replay
	match action:
		&"concede":
			if _mode == Mode.ADVENTURE:
				return "Conceding ends the run."
			if _mode == Mode.RANKED:
				var viewer: int = int(_facts.get("viewer", -1))
				var wins: Array = _facts.get("wins", [0, 0])
				var needed: int = ceili(int(_facts.get("best_of", 3)) / 2.0)
				if viewer >= 0 and int(wins[1 - viewer]) >= needed - 1:
					return "Conceding this game ends the match."
				return "Concede game %d?" % maxi(1, int(_facts.get("game", 1)))
			return "Concede the duel?"
		&"concede_match":
			return "Concede the match?"
		&"rematch":
			return "Abandon this duel and deal a new one?" if running else ""
		&"leave":
			if running and _mode == Mode.TUTORIAL:
				return "Leave the training? You pick up again at the start of this lesson."
			return "Abandon this duel and return to the title?" if running and _mode == Mode.LOCAL else ""
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
		&"concede_match":
			concede_match_requested.emit()
		&"rematch":
			rematch_requested.emit()
		&"leave":
			leave_requested.emit()


## Debug builds only, and only where the referee lives (hotseat, host).
func set_dev_available(on: bool) -> void:
	dev_toggle.visible = on
	if not on:
		dev_panel.visible = false


## Opens the full log over the history strip, most of the screen tall, or closes it.
func set_log_expanded(on: bool) -> void:
	_log_expanded = on
	history_tip.hide()
	history.visible = not on
	if not on:
		log_panel.hide()
		return
	hide_peek()
	log_panel.offset_bottom = root.size.y * LOG_EXPANDED_FRACTION
	log_panel.show()
	_follow_log.call_deferred()
	if reduced_motion_toggle.button_pressed:
		log_panel.modulate.a = 1.0
		return
	log_panel.modulate.a = 0.0
	create_tween().tween_property(log_panel, "modulate:a", 1.0, 0.14)


## Expanded rules in the quick view's fixed home on the left. The open log owns that column, so the
## quick view waits.
func show_peek(def: CardDef, aspect: int = 0, uid: int = -1) -> void:
	if def == null or inspect.visible or _log_expanded:
		return
	peek_face.show_def(def, aspect, _live_energy(uid), _standing(uid), _uid_backdrop(uid), _uid_table(def, uid), _live_might(uid))
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


## Esc closes the options menu, then an inspect view, the pile browser or the full log, and
## otherwise opens the menu, unless a tray is open or the hand is raised, which lowers itself on
## Esc. L opens and closes the full log. While the menu is open no other key reaches the table: the
## hand's keys would act on the cards behind it.
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
	elif _log_expanded and cancel:
		set_log_expanded(false)
		get_viewport().set_input_as_handled()
	elif _log_key(event):
		set_log_expanded(not _log_expanded)
		get_viewport().set_input_as_handled()
	elif cancel and not tray.visible and not loading.visible and _overlay == Overlay.NONE and not _hand_raised():
		set_options_open(true)
		get_viewport().set_input_as_handled()
	elif _space_takes_single_action(event):
		_single_action.pressed.emit()
		get_viewport().set_input_as_handled()


## Space takes the lone offered action. A focused button and the keyboard-browsing hand take Space first.
func _space_takes_single_action(event: InputEvent) -> bool:
	if _single_action == null or not (event is InputEventKey):
		return false
	var key: InputEventKey = event
	if not key.pressed or key.echo or key.keycode != KEY_SPACE:
		return false
	if not _single_action.is_visible_in_tree() or _single_action.disabled:
		return false
	if tray.visible or pile.visible or inspect.visible or handoff.visible or modal.visible or options_menu.visible:
		return false
	if get_viewport().gui_get_focus_owner() != null:
		return false
	return not _hand_browsing()


func _log_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key: InputEventKey = event
	if not key.pressed or key.echo or key.keycode != LOG_KEY:
		return false
	return not (tray.visible or pile.visible or inspect.visible or handoff.visible or modal.visible)


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
