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

const HAND_CARD_SIZE: Vector2 = Vector2(126, 176)
const HAND_LIFT: float = 26.0
const MAX_LOG_LINES: int = 300
const TRAY_CARD_SIZE: Vector2 = Vector2(204, 285)
const LOG_COLLAPSED_BOTTOM: float = 132.0
const LOG_EXPANDED_FRACTION: float = 0.72
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
const DECISION_BOTTOM_MARGIN: float = 24.0
const DECISION_RESULT_HEIGHT: float = 54.0
## Prompt kinds whose card options are browsed in the tray even when the cards are in the hand:
## the decision is about the cards themselves, as in a discard-step keep or a Reserve swap.
const TRAY_KINDS: Array[StringName] = [&"reserve", &"keep", &"discard_choice", &"recover", &"pick_option", &"name_card", &"pick_discard"]
## Tray captions by option type; anything else shows the option's own label.
const TRAY_VERBS: Dictionary = {
	&"reserve_in": "Bring in", &"keep": "Keep", &"discard_choice": "Discard", &"recover": "Recover",
	&"pick_option": "Choose", &"pick_in_play": "Choose", &"name_card": "Name", &"capture": "Capture", &"discard_ally": "Discard",
	&"final_strike": "Discard",
}
## How long the newly lit Combat sub-chip takes to come up, when Reduced Motion is off.
const CHIP_FADE: float = 0.15
const TOAST_HOLD: float = 1.1
const QUIET_HOLD: float = 0.6
const STEP_LABELS: Array[String] = ["Draw", "Place", "Power Up", "Declare", "Combat", "Discard", "Recover"]
## Keys for `mark_phase_event`, one per chip of the top strip, in STEP_LABELS order.
const STEP_KEYS: Array[StringName] = [&"draw", &"place", &"power_up", &"declare", &"combat", &"discard", &"recover"]
const COMBAT_INDEX: int = 4          # which STEP_LABELS chip expands into the combat sub-strip
## The Combat step as the player meets it. Every beat of a Combat lands on one of these. Combat is
## attack and defend back and forth, so a fight back is the same Attack chip with the other seat
## named under it rather than a step of its own.
const SUB_LABELS: Array[String] = ["Enter", "Attack", "Defend", "Resolve", "End"]
const SUB_KEYS: Array[StringName] = [&"enter", &"attack", &"defend", &"resolve", &"end"]
const SUB_PHASES: Array = [
	[GameState.Phase.PREPARE_ACTIVE, GameState.Phase.PREPARE_OPPOSING, GameState.Phase.OPPOSING_DRAW],
	[GameState.Phase.ATTACK, GameState.Phase.FIGHT_BACK], [GameState.Phase.DEFEND],
	[GameState.Phase.BATTLE], [GameState.Phase.COMBAT_END],
]
## A glyph where one helps, `-1` where the word is the whole chip.
const SUB_GLYPHS: Array[int] = [-1, CardDef.Type.STRIKE, CardDef.Type.COMBAT, CardDef.Type.ART, -1]
## Index into SUB_LABELS, so the code says which chip it means.
const SUB_ATTACK: int = 1
const SUB_DEFEND: int = 2
const SUB_RESOLVE: int = 3
const SUB_END: int = 4
## Room for the sub-chips, in canvas pixels. A chip that carries a seat name is wider, because a
## 14-character duelist name has to sit under Attack or Defend without touching the next chip.
const SUB_WIDTH: float = 76.0
const SUB_NAME_WIDTH: float = 112.0
const SUB_GAP: int = 16
## The battle sequence in six readable groups: pay, defend, shields, damage, wounds, after.
## Each entry is the first and last `SeatView.battle_step` inside that group.
const BATTLE_GROUPS: Array[Vector2i] = [
	Vector2i(2, 3), Vector2i(4, 5), Vector2i(7, 8), Vector2i(9, 12), Vector2i(13, 13), Vector2i(14, 16),
]
## The label one lone non-card action carries, by prompt kind then option type. A single button is
## the whole decision, so it says what happens rather than naming the rule it comes from.
const ACTION_LABELS: Dictionary = {
	&"pass": "Pass", &"no_defense": "No Defense", &"decline": "Let it resolve", &"done": "Done",
	&"no_endure": "Take the wound", &"declare": "Declare Combat",
}
const ACTION_LABELS_BY_KIND: Dictionary = {
	&"combat_end": {&"done": "End Combat"}, &"declare": {&"skip": "No Combat"},
}
const STEP_ORDER: Array[int] = [
	GameState.Step.DRAW, GameState.Step.NON_COMBAT, GameState.Step.POWER_UP, GameState.Step.DECLARE,
	GameState.Step.COMBAT, GameState.Step.DISCARD, GameState.Step.RECOVER,
]
## Only explicit batch confirmation gets a filled accent. Routine alternatives stay equal.
## Prompt kinds answered by the buttons in the panel even though their options name a card. An
## Endurance choice is a yes or no about one card that is already in a pile, so hunting for it on
## the table to click it is the wrong way to ask.
const BUTTON_KINDS: Array[StringName] = [&"endurance"]

@onready var reduced_motion_toggle: CheckButton = $Root/ReducedMotion
@onready var root: Control = $Root
@onready var phase_panel: PanelContainer = $Root/PhasePanel
@onready var turn_counter: Label = $Root/PhasePanel/Column/Turn/Counter
@onready var turn_who: Label = $Root/PhasePanel/Column/Turn/Who
@onready var steps_box: HBoxContainer = $Root/PhasePanel/Column/Steps
@onready var log_scroll: ScrollContainer = $Root/Log/Column/Scroll
@onready var near_flags: Label = $Root/NearFlags
@onready var far_flags: Label = $Root/FarFlags
@onready var presence_line: Label = $Root/PresenceLine
@onready var log_text: RichTextLabel = $Root/Log/Column/Scroll/Text
@onready var dev_toggle: Button = $Root/DevToggle
@onready var dev_panel: DevPanel = $Root/DevPanel
@onready var peek: Control = $Root/Peek
@onready var peek_face: CardFace = $Root/Peek/Face
@onready var peek_forecast: PanelContainer = $Root/Peek/Forecast
@onready var peek_forecast_text: RichTextLabel = $Root/Peek/Forecast/Text
@onready var toast_label: Label = $Root/Toast
@onready var quiet_label: Label = $Root/QuietBeat
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
@onready var rematch_button: Button = $Root/GameOver/Center/Column/Buttons/Rematch
@onready var select_button: Button = $Root/GameOver/Center/Column/Buttons/Select
@onready var loading: ColorRect = $Root/Loading

var external_hand: bool = false
var scene_flags: bool = false
## The node that can project a table card's centre, `DuelView`. Set from the parent in `_ready`.
var table: Node = null
var _viewer_seat: int = 0
var _log_lines: int = 0
var _current_prompt: PromptView = null
var _view: SeatView = null
var _step_labels: Array[Label] = []
var _step_bars: Array[ColorRect] = []   # the progress rule under each step chip
var _faces: CardFaceCache = null
var _log_expanded: bool = false
var _batch: PromptView = null          # the prompt behind a multi-select tray, else null
var _selected: Array[int] = []
var _entries: Dictionary = {}          # uid -> {frame, caption, verb} for batch trays
var _confirm: Button = null
var _online: bool = false
var _is_host: bool = false
var _toast: Tween = null
var _quiet: Tween = null
var _fitting_actions: bool = false
var _step_columns: Array[VBoxContainer] = []
var _combat_strip: HBoxContainer = null   # the five Combat sub-chips, inside the Combat chip
var _sub_chips: Array[VBoxContainer] = []
var _sub_labels: Array[Label] = []
var _sub_icons: Array[TypeIcon] = []
var _sub_notes: Array[Label] = []
var _battle_dots: Array[ColorRect] = []
var _exchange_chip: Label = null          # "Exchange 3", so a long Combat reads as a series
var _last_sub_active: int = -1            # the sub-chip lit on the previous refresh, -1 when closed
var _last_attacker: int = -1              # who was attacking then, so a hand-over can be noticed
var _pulses: Dictionary = {}              # chip -> Tween, so a second pulse replaces the first
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


func _ready() -> void:
	root.theme = SanctumUI.theme()
	reduced_motion_toggle.toggled.connect(func(on: bool) -> void: reduced_motion_changed.emit(on))
	prompt_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	log_panel.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0.065, 0.065, 0.065, 0.96), Color(0.20, 0.20, 0.20), 2, 1, 14, 10))
	for name in STEP_LABELS:
		# Each step is a chip with a rule under it, so the strip reads as a progress bar across
		# the turn: filled behind, gold on the step we are in, empty ahead.
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l: Label = Label.new()
		l.text = name
		l.add_theme_font_size_override("font_size", 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(l)
		var bar: ColorRect = ColorRect.new()
		bar.custom_minimum_size = Vector2(0, 5)
		column.add_child(bar)
		steps_box.add_child(column)
		_step_labels.append(l)
		_step_bars.append(bar)
		_step_columns.append(column)
	_build_combat_strip()
	table = get_parent()
	handoff_ready.pressed.connect(func() -> void: handoff_confirmed.emit())
	rematch_button.pressed.connect(func() -> void: rematch_requested.emit())
	select_button.pressed.connect(func() -> void: select_requested.emit())
	log_text.add_theme_color_override("default_color", ZenithTheme.MUTED)
	inspect.visible = false
	inspect.gui_input.connect(_on_inspect_input)
	pile.visible = false
	pile_close.pressed.connect(hide_pile)
	log_toggle.pressed.connect(func() -> void: set_log_expanded(not _log_expanded))
	dev_toggle.pressed.connect(func() -> void: dev_panel.visible = not dev_panel.visible)
	dev_panel.command.connect(func(effect: Dictionary) -> void: dev_command.emit(effect))
	root.resized.connect(_layout_prompt_column)
	primary_box.minimum_size_changed.connect(_fit_actions)
	prompt_column.minimum_size_changed.connect(_fit_actions)
	_compact_prompt()


## The Combat chip carries the whole Combat inside it: five sub-chips in the order the engine
## works through them, and a six-dot rule under Resolve for the battle sequence. It is built once
## and hidden until the turn reaches Combat, where it takes the Combat chip's place.
func _build_combat_strip() -> void:
	_combat_strip = HBoxContainer.new()
	_combat_strip.add_theme_constant_override("separation", SUB_GAP)
	_combat_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_combat_strip.visible = false
	_exchange_chip = Label.new()
	_exchange_chip.add_theme_font_size_override("font_size", 13)
	_exchange_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_exchange_chip.add_theme_color_override("font_color", ZenithTheme.MUTED)
	_combat_strip.add_child(_exchange_chip)
	for i in range(SUB_LABELS.size()):
		var chip: VBoxContainer = VBoxContainer.new()
		chip.add_theme_constant_override("separation", 1)
		# Five chips share the room seven used to. Attack and Defend reserve enough width for a
		# long seat name, the rest only need their word, and the gap keeps neighbours apart.
		chip.custom_minimum_size = Vector2(SUB_NAME_WIDTH if i == SUB_ATTACK or i == SUB_DEFEND else SUB_WIDTH, 0)
		var head: HBoxContainer = HBoxContainer.new()
		head.add_theme_constant_override("separation", 3)
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon: TypeIcon = TypeIcon.new()
		icon.custom_minimum_size = Vector2(15, 15)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if SUB_GLYPHS[i] >= 0:
			icon.set("type", SUB_GLYPHS[i])
		else:
			icon.visible = false
		head.add_child(icon)
		var l: Label = Label.new()
		l.text = SUB_LABELS[i]
		l.add_theme_font_size_override("font_size", 18)
		head.add_child(l)
		chip.add_child(head)
		var note: Label = Label.new()
		note.add_theme_font_size_override("font_size", 13)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.visible = false
		chip.add_child(note)
		if SUB_PHASES[i].has(GameState.Phase.BATTLE):
			var dots: HBoxContainer = HBoxContainer.new()
			dots.add_theme_constant_override("separation", 3)
			dots.alignment = BoxContainer.ALIGNMENT_CENTER
			for d in range(BATTLE_GROUPS.size()):
				var dot: ColorRect = ColorRect.new()
				dot.custom_minimum_size = Vector2(5, 5)
				dot.color = ZenithTheme.RAISED_STRONG
				dots.add_child(dot)
				_battle_dots.append(dot)
			chip.add_child(dots)
		_combat_strip.add_child(chip)
		_sub_chips.append(chip)
		_sub_labels.append(l)
		_sub_icons.append(icon)
		_sub_notes.append(note)
	_step_columns[COMBAT_INDEX].add_child(_combat_strip)
	_step_columns[COMBAT_INDEX].move_child(_combat_strip, 1)


## One bounded column: a real card, the decision and its consequence, then offered controls.
## Printed identity and rules remain on the face. The question and terse instruction stay visible
## because a readable card is not enough to say what input the game is waiting for.
func _compact_prompt() -> void:
	prompt_who.hide()
	prompt_title.visible = _current_prompt != null or not focus.visible
	prompt_hint.visible = _current_prompt != null and not prompt_hint.text.is_empty()
	exchange_state.hide()
	exchange_route.hide()
	exchange_response.hide()
	_layout_prompt_column()


func _layout_prompt_column() -> void:
	if focus == null or prompt_panel == null:
		return
	prompt_panel.offset_left = focus.offset_left
	prompt_panel.offset_right = focus.offset_right
	# Use the authored rail width rather than a transient child minimum. CardFace renders from a
	# 512x716 source and may report that unscaled minimum for a frame while the layout settles.
	var focus_width: float = focus.offset_right - focus.offset_left
	var focus_bottom: float = focus.offset_top + FOCUS_CAPTION_HEIGHT + focus_width * CARD_ASPECT
	# The response stack lives inside the Focus rect, so it costs the decision column nothing.
	_layout_stack()
	var top: float = focus_bottom + DECISION_GAP if focus.visible else 210.0
	prompt_panel.offset_top = top
	# Let the VBox determine height again after a larger prior decision.
	prompt_panel.offset_bottom = prompt_panel.offset_top
	_fit_actions()


func _fit_actions() -> void:
	if _fitting_actions or actions_scroll == null:
		return
	_fitting_actions = true
	var outside: float = maxf(0.0, prompt_column.get_combined_minimum_size().y - actions_scroll.get_combined_minimum_size().y)
	var available: float = maxf(0.0, root.size.y - prompt_panel.offset_top - outside - DECISION_BOTTOM_MARGIN)
	var desired: float = minf(primary_box.get_combined_minimum_size().y, minf(260.0, available))
	actions_scroll.custom_minimum_size.y = desired
	actions_scroll.visible = primary_box.get_child_count() > 0
	_fitting_actions = false


func set_loading(on: bool) -> void:
	loading.visible = on


## Online duel: only the host can call a rematch, and the other button leaves the table.
func set_online(is_host: bool) -> void:
	_online = true
	_is_host = is_host
	select_button.text = "Back to lobby" if is_host else "Leave duel"


## Adventure duel: the select button leads back to the stage screen, not duelist select.
func set_adventure() -> void:
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
	_refresh_phase(view, me, live)
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
		_overflow.add_theme_font_size_override("font_size", 19)
		_overflow.add_theme_color_override("font_color", ZenithTheme.TEXT_DARK)
		_overflow.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.ACCENT, Color(0, 0, 0, 0), 8, 0, 8, 2))
		stack.add_child(_overflow)
	_overflow.text = "+%d" % count
	_layout_stack()


## The banner over the table. Whose turn it is and which step of it, both at a size that reads
## from across the room; the strip under them is the turn as a progress rail, and the line below
## is the beat inside Combat, in the attack and defence colours.
func _refresh_phase(view: SeatView, me: int, live: Dictionary = {}) -> void:
	var over: bool = view.is_over()
	# While an update replays, the banner reads the beat's own position in the turn. Without this
	# it draws where the turn ends up, so an update that closes Combat says DISCARD over the
	# combat beats still playing underneath it.
	var turn: int = int(live.get("turn", view.turn))
	var step: int = int(live.get("step", view.step))
	var active: int = int(live.get("active", view.active))
	var current: int = STEP_ORDER.find(step)
	var in_combat: bool = current == COMBAT_INDEX and not over
	_refresh_combat_strip(view, me, live, in_combat)
	for i in range(_step_labels.size()):
		var l: Label = _step_labels[i]
		var on: bool = i == current and not over
		var done: bool = current >= 0 and i < current and not over
		l.add_theme_color_override("font_color", ZenithTheme.ACCENT if on else ZenithTheme.MUTED)
		# The sub-chips need the middle of the strip while Combat runs, so the surrounding steps
		# give up size rather than their words.
		l.add_theme_font_size_override("font_size", 14 if in_combat else (20 if on else 18))
		var bar: ColorRect = _step_bars[i]
		if on:
			bar.color = ZenithTheme.ACCENT
		elif done:
			bar.color = ZenithTheme.ACCENT_SOFT
		else:
			bar.color = ZenithTheme.RAISED_STRONG

	turn_counter.text = "TURN %d" % turn
	ZenithTheme.chip(turn_counter, ZenithTheme.MUTED)
	if over:
		turn_who.text = "DUEL OVER"
		turn_who.add_theme_color_override("font_color", ZenithTheme.TEXT)
		phase_panel.add_theme_stylebox_override("panel", ZenithTheme.get_theme().get_stylebox("panel", "PanelContainer"))
		return

	var mine: bool = active == me
	turn_who.text = ("YOUR TURN" if mine else "THEIR TURN") + "  /  " + (STEP_LABELS[current].to_upper() if current >= 0 else "")
	if current < 0:
		turn_counter.text = "PREPARE"
		turn_who.text = "RESERVE"
	turn_who.add_theme_color_override("font_color", ZenithTheme.ACCENT if mine else ZenithTheme.MUTED)
	# A gold left edge while the viewer acts, so the banner itself says whether to reach for a card.
	phase_panel.add_theme_stylebox_override("panel", SanctumUI.panel())


## While the turn is in Combat, the Combat chip becomes the whole sequence: which sub-step we are
## in, who is attacking and who is answering, how far the battle sequence has run, and the warning
## that the next pass closes Combat. Everything is read from the beat's own state first.
func _refresh_combat_strip(view: SeatView, me: int, live: Dictionary, on: bool) -> void:
	_combat_strip.visible = on
	# Inside Combat the sub-chips take the middle of the strip, so the turn's other steps keep
	# their words and step down a size rather than falling back to bare rules. The Combat word
	# itself goes, because the five sub-chips under it say the same thing in more detail.
	_step_labels[COMBAT_INDEX].visible = not on
	if not on:
		_last_sub_active = -1
		_last_attacker = -1
		return
	var phase: int = int(live.get("phase", view.phase))
	var att: int = int(live.get("attacker", view.attacker))
	var battle: int = int(live.get("battle_step", view.battle_step))
	var exchange: int = int(live.get("attack_phase_count", view.attack_phase_count))
	_exchange_chip.text = "Exchange %d" % (exchange + 1)
	var active: int = -1
	for i in range(SUB_PHASES.size()):
		if SUB_PHASES[i].has(phase):
			active = i
	# A hand-over keeps the same Attack chip and swaps the names under Attack and Defend. Without
	# the pulse the chip looks exactly as it did during the previous exchange, which is what made
	# Combat look frozen.
	var handover: bool = active == SUB_ATTACK and _last_attacker >= 0 and att != _last_attacker
	if handover:
		_sub_chips[SUB_ATTACK].modulate = Color(1, 1, 1, 1)
		mark_phase_event(&"attack")
	elif active >= 0 and active != _last_sub_active:
		_light_sub_chip(active)
	_last_sub_active = active
	_last_attacker = att
	for i in range(_sub_labels.size()):
		var here: bool = i == active
		var done: bool = active >= 0 and i < active
		var color: Color = ZenithTheme.ACCENT if here else (ZenithTheme.MUTED if done else Color(ZenithTheme.MUTED, 0.55))
		if here and i == SUB_ATTACK:
			color = ZenithTheme.ATTACK
		elif here and i == SUB_DEFEND:
			color = ZenithTheme.DEFEND
		_sub_labels[i].add_theme_color_override("font_color", color)
		_sub_labels[i].add_theme_font_size_override("font_size", 20 if here else 18)
		_sub_icons[i].color = color
		_sub_notes[i].add_theme_color_override("font_color", color)
	var attacker_name: String = "You" if att == me else view.player(att).name if att >= 0 else ""
	var defender_name: String = "You" if att >= 0 and att != me else (view.player(1 - att).name if att >= 0 else "")
	_set_sub_note(SUB_ATTACK, attacker_name, ZenithTheme.ATTACK if active == SUB_ATTACK else Color(ZenithTheme.MUTED, 0.8), "")
	_set_sub_note(SUB_DEFEND, defender_name, ZenithTheme.DEFEND if active == SUB_DEFEND else Color(ZenithTheme.MUTED, 0.8), "")
	var passes: int = view.consecutive_passes
	_set_sub_note(SUB_END, "1 more pass" if passes == 1 else "", ZenithTheme.WARN,
		"One more pass ends Combat." if passes == 1 else "")
	for d in range(BATTLE_GROUPS.size()):
		var group: Vector2i = BATTLE_GROUPS[d]
		var dot: ColorRect = _battle_dots[d]
		if active != SUB_RESOLVE:
			dot.color = ZenithTheme.RAISED_STRONG
		elif battle > group.y:
			dot.color = ZenithTheme.ACCENT_SOFT
		elif battle >= group.x:
			dot.color = ZenithTheme.ACCENT
		else:
			dot.color = ZenithTheme.RAISED_STRONG


## The beat moved to another sub-chip. It comes up rather than appearing, so the eye follows the
## Combat along the strip. Reduced Motion gets the same chip, lit at once.
func _light_sub_chip(index: int) -> void:
	var chip: VBoxContainer = _sub_chips[index]
	var running: Variant = _pulses.get(chip)
	if running is Tween:
		(running as Tween).kill()
		_pulses.erase(chip)
	if reduced_motion_toggle.button_pressed:
		chip.modulate = Color(1, 1, 1, 1)
		return
	chip.modulate = Color(1, 1, 1, 0.3)
	var t: Tween = create_tween()
	t.tween_property(chip, "modulate", Color(1, 1, 1, 1), CHIP_FADE)
	_pulses[chip] = t


func _set_sub_note(index: int, text: String, color: Color, tip: String) -> void:
	var note: Label = _sub_notes[index]
	note.text = text
	note.visible = text != ""
	note.add_theme_color_override("font_color", color)
	_sub_chips[index].tooltip_text = tip
	_sub_chips[index].mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE


## Pulses one chip of the strip, for a beat that happened inside a step rather than moving to the
## next one. A Combat sub-chip key wins over a turn-step key of the same name while Combat is open.
func mark_phase_event(phase_key: StringName) -> void:
	var chip: Control = null
	if _combat_strip.visible:
		var sub: int = SUB_KEYS.find(phase_key)
		if sub >= 0:
			chip = _sub_chips[sub]
	if chip == null:
		var step: int = STEP_KEYS.find(phase_key)
		if step >= 0:
			chip = _step_columns[step]
	if chip == null or reduced_motion_toggle.button_pressed:
		return
	var running: Variant = _pulses.get(chip)
	if running is Tween:
		(running as Tween).kill()
	chip.modulate = Color(1.7, 1.6, 1.2, 1)
	var t: Tween = create_tween()
	t.tween_property(chip, "modulate", Color(1, 1, 1, 1), 0.32)
	_pulses[chip] = t


## A short banner over the table for the beat that just happened: the attack, what it hit for,
## a stop, an aspect. It pops in, holds, and fades; a new one replaces the last at once.
func toast(text: String, color: Color) -> void:
	_clear_toast()
	toast_label.text = text
	toast_label.add_theme_stylebox_override("normal", ZenithTheme.box(color, Color(0, 0, 0, 0), 10, 0, 22, 8))
	toast_label.add_theme_color_override("font_color", ZenithTheme.TEXT_DARK)
	toast_label.modulate = Color(1, 1, 1, 1)
	toast_label.scale = Vector2.ONE if reduced_motion_toggle.button_pressed else Vector2(0.7, 0.7)
	toast_label.visible = true
	_toast = create_tween()
	if not reduced_motion_toggle.button_pressed:
		_toast.tween_property(toast_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast.tween_interval(TOAST_HOLD)
	_toast.tween_property(toast_label, "modulate:a", 0.0, 0.3)
	_toast.tween_callback(func() -> void: toast_label.visible = false)


## A skipped or passed window still gets a beat, so nothing resolves silently. Quieter and shorter
## than `toast`, it sits under the toast slot and never interrupts a toast that is still up.
func quiet_beat(text: String, color: Color) -> void:
	if _quiet != null:
		_quiet.kill()
		_quiet = null
	quiet_label.text = text
	quiet_label.add_theme_stylebox_override("normal", ZenithTheme.box(Color(color, 0.20), Color(0, 0, 0, 0), 8, 0, 16, 4))
	quiet_label.add_theme_color_override("font_color", color.lightened(0.15))
	quiet_label.modulate = Color(1, 1, 1, 1)
	quiet_label.visible = true
	_quiet = create_tween()
	_quiet.tween_interval(QUIET_HOLD)
	if reduced_motion_toggle.button_pressed:
		_quiet.tween_callback(func() -> void: quiet_label.visible = false)
		return
	_quiet.tween_property(quiet_label, "modulate:a", 0.0, 0.2)
	_quiet.tween_callback(func() -> void: quiet_label.visible = false)


func _clear_toast() -> void:
	if _toast != null:
		_toast.kill()
		_toast = null
	toast_label.visible = false


func log_line(text: String) -> void:
	var bar: VScrollBar = log_scroll.get_v_scroll_bar()
	var following: bool = not _log_expanded or bar.value >= bar.max_value - bar.page - 8.0
	if _log_lines >= MAX_LOG_LINES:
		log_text.clear()
		_log_lines = 0
	if text.begins_with("—"):
		log_text.append_text("[color=#dbb045]%s[/color]\n" % text)
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
	_view = view
	_current_prompt = p
	_owner_marks = CardText.option_side_marks(p, _viewer_seat)
	var who: SeatPlayer = view.player(p.player)
	prompt_who.text = "%s  ·  YOUR DECISION" % who.name.to_upper()
	prompt_who.add_theme_color_override("font_color", SeatColors.accent(view, p.player, Session.color_seed))
	prompt_title.text = p.title
	# The response stack stays up. It is laid over the pinned attack inside the same rect, so it
	# takes no room from the decision column and the player sees the state they are answering.
	_show_attack(view, p)
	prompt_who.visible = not exchange_rail.visible
	show_focus(_focus_uid(p), _focus_caption(p))
	prompt_hint.text = _hint_for(p)
	prompt_hint.visible = prompt_hint.text != ""
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
		await _show_tray(prompt_who.text, p.title, prompt_hint.text, browse, primaries, false, p if p.has_batch() else null)
		await _add_library(library, browse)
	elif browse.is_empty():
		_hide_tray()
		_fill_buttons(primaries, primary_box, true)
		if finals.is_empty() and primaries.size() == 1 and primaries[0].card < 0:
			_make_single_action(p, primaries[0], view)
		if not finals.is_empty():
			var b: Button = Button.new()
			b.text = "Final Strike…"
			b.custom_minimum_size = Vector2(0, 40)
			b.add_theme_font_size_override("font_size", 24)
			b.pressed.connect(func() -> void: _show_final_strike(finals))
			primary_box.add_child(b)
			_fit_actions()
	else:
		_fill_buttons([], primary_box, true)
		_show_tray(prompt_who.text, p.title, prompt_hint.text, browse, primaries, false, p if p.has_batch() else null)


## One lone action is the whole decision, so it is offered as one large button that says what
## will happen rather than naming the rule behind it. Space takes it. Two or more alternatives
## stay equal-weighted rows, because choosing between them is the decision.
func _make_single_action(p: PromptView, opt: OptionView, view: SeatView) -> void:
	if primary_box.get_child_count() != 1:
		return
	var b: Button = primary_box.get_child(0)
	b.text = _single_action_label(p, opt, view)
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 28)
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
		exchange_damage.text = "Dealt %d Energy / %s" % [int(a.get("stages_dealt", 0)), _wounds(int(a.get("life_dealt", 0)))]
		var remaining: int = int(a.get("life_remaining", 0))
		if remaining > 0:
			exchange_damage.text += "\n%s still to resolve" % _wounds(remaining)
	else:
		var damage: Dictionary = a.get("damage", {})
		exchange_damage.text = "%d Energy / %s" % [int(damage.get("stages", 0)), _wounds(int(damage.get("wounds", damage.get("life", 0))))]
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
	# Both labels occupy one stable two-line slot. Measuring a wrapping label before its parent has
	# width makes a one-line result hundreds of pixels tall and can push the actions off-screen.
	exchange_damage.custom_minimum_size.y = DECISION_RESULT_HEIGHT
	prompt_outcome.custom_minimum_size.y = DECISION_RESULT_HEIGHT


func _wounds(amount: int) -> String:
	return tr_n("%d wound", "%d wounds", amount) % amount


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
		exchange_damage.text = "Last: %d Energy / %s dealt" % [int(result.get("stages_dealt", 0)), _wounds(int(result.get("life_dealt", 0)))]
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
	prompt_outcome.visible = outcome.has("stages") or outcome.has("stopped") or outcome.has("life")
	exchange_rail.visible = true if prompt_outcome.visible else _exchange_before_preview
	exchange_damage.visible = _damage_available and not prompt_outcome.visible
	if not prompt_outcome.visible:
		return
	var stopped: bool = bool(outcome.get("stopped", false))
	if stopped:
		prompt_outcome.text = "Preview: attack stopped"
	elif outcome.has("stages"):
		prompt_outcome.text = "Preview: %d Energy / %s" % [int(outcome.get("stages", 0)), _wounds(int(outcome.get("life", 0)))]
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
		&"attack_action":
			return "Click a highlighted card, or choose below."
		&"defense":
			return "Click a highlighted card to stop it." if card_options > 0 else ""
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
	_view = view
	_current_prompt = null
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


## Online joiner: the choice went to the host and its answer is not back yet.
func show_sending() -> void:
	for child in primary_box.get_children():
		(child as Control).hide()
	_fill_buttons([], primary_box, true)
	prompt_panel.show()
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
	await _show_tray(prompt_who.text, c.title if c != null else "Choose an action", hint, single, options, true, null, not only_final)
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
	await _show_tray(prompt_who.text, "Final Strike: discard a card", "A bare Strike from the Strike Table, plus your Drills and modifiers. Afterwards you pass for the rest of this Combat.", finals, [], false)
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
		b.custom_minimum_size = Vector2(0.0 if vertical else clampf(text_width, 300.0, minf(520.0, root.size.x - 180.0)), 60)
		b.add_theme_font_size_override("font_size", 24)
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


# --- Tray -----------------------------------------------------------------

## A centred browser over the table: one face per card option with the action as its caption,
## the no-card options as a button row beneath, and Back when this is a sub-choice. `actions`
## become the buttons; with `sub_choice` they act on the single card shown. With `batch`, clicks
## toggle cards and one confirm button sends them all at once.
func _show_tray(who: String, title: String, hint: String, cards: Array[OptionView], actions: Array[OptionView], sub_choice: bool, batch: PromptView = null, accent_first: bool = true) -> void:
	_batch = batch
	_selected.clear()
	_entries.clear()
	hide_pile()
	hide_peek()
	hide_focus()   # the tray is the middle of the screen while it is open
	tray_who.text = who
	tray_who.add_theme_color_override("font_color", prompt_who.get_theme_color("font_color"))
	tray_title.text = title
	if batch != null:
		var rule: String = "Pick %d." % batch.batch_max if batch.batch_min == batch.batch_max else "Pick up to %d." % batch.batch_max
		hint = (hint + "  " + rule).strip_edges()
	tray_hint.text = hint
	tray_hint.visible = hint != ""
	for child in tray_cards.get_children():
		tray_cards.remove_child(child)
		child.queue_free()
	for opt in cards:
		var entry: Control = await _tray_entry(opt, sub_choice)
		if entry != null:
			tray_cards.add_child(entry)
	# Wide enough for a full row, tall enough for two; anything past that scrolls down.
	var shown: int = tray_cards.get_child_count()
	var columns: int = maxi(1, mini(TRAY_COLUMNS, int((root.size.x - 180.0) / (TRAY_CARD_SIZE.x + 18.0))))
	var cols: int = mini(shown, columns)
	var rows: int = mini(ceili(float(shown) / columns), TRAY_ROWS_SHOWN)
	var cell: Vector2 = TRAY_CARD_SIZE + Vector2(6.0, 6.0 + 6.0 + 20.0)   # frame pad, caption
	tray_scroll.custom_minimum_size = Vector2(maxf(720.0, cols * (cell.x + 12.0) + 12.0), minf(rows * (cell.y + 12.0), root.size.y * 0.57))
	_fill_buttons(actions, tray_buttons, false, sub_choice and accent_first)
	if batch != null:
		_confirm = Button.new()
		_confirm.theme_type_variation = &"AccentButton"
		_confirm.custom_minimum_size = Vector2(200, 60)
		_confirm.add_theme_font_size_override("font_size", 24)
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
		face.texture = await _faces.render_face(def, c.aspect, seat_backdrop(c.owner)) if def != null and _faces != null else null
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_SCALE
		face.custom_minimum_size = TRAY_CARD_SIZE
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
	var shown: int = tray_cards.get_child_count()
	var columns: int = maxi(1, mini(TRAY_COLUMNS, int((root.size.x - 180.0) / (TRAY_CARD_SIZE.x + 18.0))))
	var cols: int = mini(shown, columns)
	var rows: int = mini(ceili(float(shown) / columns), TRAY_ROWS_SHOWN)
	var cell: Vector2 = TRAY_CARD_SIZE + Vector2(6.0, 6.0 + 6.0 + 20.0)
	tray_scroll.custom_minimum_size = Vector2(maxf(720.0, cols * (cell.x + 12.0) + 12.0), minf(rows * (cell.y + 12.0), root.size.y * 0.57))


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
		(e["frame"] as PanelContainer).add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), ZenithTheme.ACCENT if on else Color(0, 0, 0, 0), 10, 3, 3, 3))
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
	frame.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.BORDER, 10, 3, 3, 3))
	frame.pivot_offset = Vector2(TRAY_CARD_SIZE.x * 0.5 + 3.0, TRAY_CARD_SIZE.y * 0.5 + 3.0)
	var b: Button = Button.new()
	b.flat = true
	b.custom_minimum_size = Vector2(TRAY_CARD_SIZE.x, 100)
	b.text = opt.label
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = false
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", ZenithTheme.TEXT)
	b.pressed.connect(func() -> void: option_chosen.emit(opt))
	b.mouse_entered.connect(func() -> void:
		frame.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.ACCENT, 10, 3, 3, 3))
		_lift(frame, true))
	b.mouse_exited.connect(func() -> void:
		frame.add_theme_stylebox_override("panel", ZenithTheme.box(ZenithTheme.BG_INPUT, ZenithTheme.BORDER, 10, 3, 3, 3))
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
		tex = await _faces.render_face(def, aspect, _uid_backdrop(uid))
	elif _faces != null:
		tex = _faces.back()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 10, 3, 3, 3))
	frame.pivot_offset = Vector2(TRAY_CARD_SIZE.x * 0.5 + 3.0, TRAY_CARD_SIZE.y * 0.5 + 3.0)
	var b: TextureButton = TextureButton.new()
	b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.custom_minimum_size = TRAY_CARD_SIZE
	var batch: bool = _batch != null
	if batch:
		b.pressed.connect(func() -> void: tray_toggle(uid))
	elif not sub_choice:
		b.pressed.connect(func() -> void: option_chosen.emit(opt))
	b.mouse_entered.connect(func() -> void:
		if not _selected.has(uid):
			frame.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), ZenithTheme.HOVER, 10, 3, 3, 3))
		_lift(frame, true)
		show_peek(def, aspect, uid)
		if uid >= 0:
			card_hovered.emit(uid, true))
	b.mouse_exited.connect(func() -> void:
		if not _selected.has(uid):
			frame.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 10, 3, 3, 3))
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
		caption.add_theme_font_size_override("font_size", 22)
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
	await _show_tray(prompt_who.text, c.title if c != null else "Relic", "", single, options, true)
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
	face.texture = await _faces.render_face(def, aspect, seat_backdrop(c.owner)) if def != null and _faces != null else null
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
	caption.add_theme_font_size_override("font_size", 20)
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
		frame.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), border, 10, 3, 3, 3))
		frame.pivot_offset = Vector2(HAND_CARD_SIZE.x * 0.5 + 3.0, HAND_CARD_SIZE.y + 6.0)
		var b: TextureButton = TextureButton.new()
		b.texture_normal = faces.face(def, c.aspect, seat_backdrop(c.owner))
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
			chip.add_theme_font_size_override("font_size", 13)
			chip.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.RAISED_STRONG if final else ZenithTheme.ATTACK, Color(0, 0, 0, 0), 6, 0, 8, 2))
			chip.add_theme_color_override("font_color", ZenithTheme.MUTED if final else ZenithTheme.TEXT_DARK)
			chip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			chip.offset_left = 8.0
			chip.offset_right = -8.0
			chip.offset_top = -30.0
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


## Full-size live face over a dimmed table, so keyword hover works. Right-click or Inspect opens
## it; Esc or a click outside closes it.
func show_inspect(def: CardDef, aspect: int = 0, uid: int = -1) -> void:
	if def == null:
		return
	hide_peek()
	hide_focus()
	inspect_face.show_def(def, aspect, _live_energy(uid), _standing(uid), _uid_backdrop(uid))
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
	focus_face.show_def(def, c.aspect, _live_energy(uid), _standing(uid), seat_backdrop(c.owner))
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
	focus_face.show_def(def, 0, -1, null, _uid_backdrop(uid))
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
	# The slot is one card wide and the caption is one clipped line, so a long one steps down a
	# size rather than losing its end to an ellipsis.
	var size: int = 22
	if text.length() > 34:
		size = 15
	elif text.length() > 26:
		size = 18
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
	face.show_def(def, 0, -1, null, _uid_backdrop(uid))
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
	strip.add_theme_stylebox_override("normal", ZenithTheme.box(tint, Color(0, 0, 0, 0), 6, 0, 8, 2))
	var edge: Panel = entry.get_node("Edge")
	edge.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), tint, 10, 3, 0, 0))


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
	edge.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), tint, 10, 3, 0, 0))
	entry.add_child(edge)
	var strip: Label = Label.new()
	strip.name = "Strip"
	strip.text = caption.to_upper()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strip.clip_text = true
	strip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	strip.add_theme_font_size_override("font_size", 17)
	strip.add_theme_color_override("font_color", ZenithTheme.TEXT_DARK)
	strip.add_theme_stylebox_override("normal", ZenithTheme.box(tint, Color(0, 0, 0, 0), 6, 0, 8, 2))
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
	var base: Vector2 = Vector2((width - face_width) * 0.5 + 16.0,
		FOCUS_CAPTION_HEIGHT + attack_height - face_height - 6.0)
	for i in range(_stack.size()):
		var entry: Control = _stack[i]
		var level: int = mini(i, STACK_MAX - 1)
		var spot: Vector2 = base + STACK_STEP * float(level)
		entry.size = Vector2(face_width, face_height)
		entry.pivot_offset = entry.size * 0.5
		entry.position = Vector2(maxf(2.0, spot.x), maxf(FOCUS_CAPTION_HEIGHT - 2.0, spot.y))
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
	node.modulate = Color(1.7, 1.6, 1.2, 1)
	var pulse: Tween = create_tween()
	pulse.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.3)
	return true


func _process(_delta: float) -> void:
	_draw_filament()


## The thread from the pinned card to what it is aimed at, in the language the 3D link on the table
## already speaks: a bowed line in the attack colour, a transverse cap when the attack is stopped
## and a double chevron once it has landed. It leaves the left edge of the card in the Focus slot,
## or of the response on top of the stack when that response is the job resolving now, so the one
## card on the right is the one the line comes from. Hidden when nothing is pinned, when no job is
## aimed anywhere, or when the table cannot say where the target is.
func _draw_filament() -> void:
	if filament == null:
		return
	if not focus.visible or _filament_target < 0 or tray.visible or inspect.visible \
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
	var rect: Rect2 = focus.get_global_rect()
	var face: Rect2 = Rect2(Vector2(rect.position.x, rect.position.y + FOCUS_CAPTION_HEIGHT),
		Vector2(rect.size.x, rect.size.x * CARD_ASPECT))
	if _filament_uid >= 0 and not _stack.is_empty():
		var top_entry: Control = _stack.back()
		if is_instance_valid(top_entry) and int(top_entry.get_meta("uid", -1)) == _filament_uid:
			face = Rect2(top_entry.global_position, top_entry.size)
	return Vector2(face.position.x, face.position.y + face.size.y * 0.5)


## The card the prompt is about: one it names outright, one raised by a card's effect, or the
## attack in the air. -1 when the decision is not about a single card.
func _focus_uid(p: PromptView) -> int:
	if p != null:
		if p.context.has("card"):
			return int(p.context["card"])
		if p.context.has("source"):
			return int(p.context["source"])
	if _view != null:
		if _view.pending_card >= 0:
			return _view.pending_card
		if not _view.attack.is_empty():
			return int(_view.attack.get("source", -1))
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
			return "Incoming"
		&"respond":
			return "Respond"
		&"critical", &"capture_instead":
			return "Your attack"
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


## Debug builds only, and only where the referee lives (hotseat, host).
func set_dev_available(on: bool) -> void:
	dev_toggle.visible = on
	if not on:
		dev_panel.visible = false


## Drops the log down to most of the screen, or back to its strip.
func set_log_expanded(on: bool) -> void:
	_log_expanded = on
	log_toggle.text = "Close" if on else "History"
	var bottom: float = root.size.y * LOG_EXPANDED_FRACTION if on else LOG_COLLAPSED_BOTTOM
	if reduced_motion_toggle.button_pressed:
		log_panel.offset_bottom = bottom
		return
	var t: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(log_panel, "offset_bottom", bottom, 0.18)


## Expanded rules beside the object being inspected, bounded away from the decision actions.
func show_peek(def: CardDef, aspect: int = 0, uid: int = -1) -> void:
	if def == null or inspect.visible:
		return
	peek_face.show_def(def, aspect, _live_energy(uid), _standing(uid), _uid_backdrop(uid))
	var forecast: String = _forecast_text(uid)
	peek_forecast.visible = forecast != ""
	peek_forecast_text.text = forecast
	# Place expanded details next to the hovered object, clamped above the hand.
	var pointer: Vector2 = root.get_local_mouse_position()
	peek.position = Vector2(clampf(pointer.x - 390.0, 20.0, root.size.x - 800.0), clampf(pointer.y - 560.0, 116.0, root.size.y - 660.0))
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


func _unhandled_input(event: InputEvent) -> void:
	if inspect.visible and event.is_action_pressed("ui_cancel"):
		hide_inspect()
		get_viewport().set_input_as_handled()
	elif pile.visible and event.is_action_pressed("ui_cancel"):
		hide_pile()
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
	if tray.visible or pile.visible or inspect.visible or handoff.visible or game_over.visible:
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
	game_over_title.text = title
	game_over_reason.text = reason
	game_over.visible = true
	SanctumUI.enter($Root/GameOver/Center/Column)
	rematch_button.visible = rematch_possible and (not _online or _is_host)
	if _online and not _is_host and rematch_possible:
		game_over_reason.text += "\nThe host can call a rematch."
	clear_prompt()
	clear_hand()
