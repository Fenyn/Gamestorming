class_name DuelHud
extends CanvasLayer
## 2D layer over the table: player panels, phase strip, log, hand, prompt, overlays. Everything
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
const LOG_COLLAPSED_BOTTOM: float = 158.0
const LOG_EXPANDED_FRACTION: float = 0.72
const TRAY_COLUMNS: int = 6          # cards per row before the tray wraps
const TRAY_ROWS_SHOWN: int = 2       # rows before the tray scrolls
## Prompt kinds whose card options are browsed in the tray even when the cards are in the hand:
## the decision is about the cards themselves, as in a discard-step keep or a Reserve swap.
const TRAY_KINDS: Array[StringName] = [&"reserve", &"keep", &"discard_choice", &"recover", &"pick_option", &"name_card", &"pick_discard"]
## Tray captions by option type; anything else shows the option's own label.
const TRAY_VERBS: Dictionary = {
	&"reserve_in": "Bring in", &"keep": "Keep", &"discard_choice": "Discard", &"recover": "Recover",
	&"pick_option": "Choose", &"pick_in_play": "Choose", &"name_card": "Name", &"capture": "Capture", &"discard_ally": "Discard",
	&"final_strike": "Discard",
}
const TOAST_HOLD: float = 1.1
const STEP_LABELS: Array[String] = ["Draw", "Place", "Power Up", "Declare", "Combat", "Discard", "Recover"]
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
@onready var top_panel: PlayerPanel = $Root/TopPanel
@onready var bottom_panel: PlayerPanel = $Root/BottomPanel
@onready var phase_panel: PanelContainer = $Root/PhasePanel
@onready var turn_counter: Label = $Root/PhasePanel/Column/Turn/Counter
@onready var turn_who: Label = $Root/PhasePanel/Column/Turn/Who
@onready var steps_box: HBoxContainer = $Root/PhasePanel/Column/Steps
@onready var phase_sub: RichTextLabel = $Root/PhasePanel/Column/Sub
@onready var log_scroll: ScrollContainer = $Root/Log/Column/Scroll
@onready var near_flags: Label = $Root/NearFlags
@onready var far_flags: Label = $Root/FarFlags
@onready var log_text: RichTextLabel = $Root/Log/Column/Scroll/Text
@onready var dev_toggle: Button = $Root/DevToggle
@onready var dev_panel: DevPanel = $Root/DevPanel
@onready var peek: Control = $Root/Peek
@onready var peek_face: CardFace = $Root/Peek/Face
@onready var peek_forecast: PanelContainer = $Root/Peek/Forecast
@onready var peek_forecast_text: RichTextLabel = $Root/Peek/Forecast/Text
@onready var toast_label: Label = $Root/Toast
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
@onready var prompt_banner: Label = $Root/PromptPanel/Column/Banner
@onready var prompt_hero: HBoxContainer = $Root/PromptPanel/Column/Hero
@onready var hero_value: Label = $Root/PromptPanel/Column/Hero/Value
@onready var hero_name: Label = $Root/PromptPanel/Column/Hero/Side/Name
@onready var hero_delta: Label = $Root/PromptPanel/Column/Hero/Side/Delta
@onready var prompt_facts: HBoxContainer = $Root/PromptPanel/Column/Facts
@onready var focus: Control = $Root/Focus
@onready var focus_caption: Label = $Root/Focus/Caption
@onready var focus_face: CardFace = $Root/Focus/Face
@onready var prompt_outcome: Label = $Root/PromptPanel/Column/Outcome
@onready var prompt_hint: Label = $Root/PromptPanel/Column/Hint
@onready var primary_box: VBoxContainer = $Root/PromptPanel/Column/Primary
@onready var tray: ColorRect = $Root/Tray
@onready var tray_who: Label = $Root/Tray/Center/Panel/Column/Who
@onready var tray_title: Label = $Root/Tray/Center/Panel/Column/Title
@onready var tray_hint: Label = $Root/Tray/Center/Panel/Column/Hint
@onready var tray_scroll: ScrollContainer = $Root/Tray/Center/Panel/Column/Scroll
@onready var tray_cards: HFlowContainer = $Root/Tray/Center/Panel/Column/Scroll/Cards
@onready var tray_buttons: HFlowContainer = $Root/Tray/Center/Panel/Column/Buttons
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
var _hero_base: int = -1               # the wound count the hero number sits at with no hover


func _ready() -> void:
	root.theme = ZenithTheme.get_theme()
	reduced_motion_toggle.toggled.connect(func(on: bool) -> void: reduced_motion_changed.emit(on))
	top_panel.hide()
	bottom_panel.hide()
	prompt_panel.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0.025, 0.035, 0.06, 0.88), Color(0.34, 0.48, 0.6, 0.3), 20, 1, 20, 16))
	log_panel.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0.025, 0.035, 0.06, 0.7), Color.TRANSPARENT, 14, 0, 14, 10))
	for name in STEP_LABELS:
		# Each step is a chip with a rule under it, so the strip reads as a progress bar across
		# the turn: filled behind, gold on the step we are in, empty ahead.
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l: Label = Label.new()
		l.text = name
		l.add_theme_font_size_override("font_size", 13)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(l)
		var bar: ColorRect = ColorRect.new()
		bar.custom_minimum_size = Vector2(0, 5)
		column.add_child(bar)
		steps_box.add_child(column)
		_step_labels.append(l)
		_step_bars.append(bar)
	handoff_ready.pressed.connect(func() -> void: handoff_confirmed.emit())
	rematch_button.pressed.connect(func() -> void: rematch_requested.emit())
	select_button.pressed.connect(func() -> void: select_requested.emit())
	log_text.add_theme_color_override("default_color", ZenithTheme.MUTED)
	inspect.visible = false
	inspect.gui_input.connect(_on_inspect_input)
	log_toggle.pressed.connect(func() -> void: set_log_expanded(not _log_expanded))
	dev_toggle.pressed.connect(func() -> void: dev_panel.visible = not dev_panel.visible)
	dev_panel.command.connect(func(effect: Dictionary) -> void: dev_command.emit(effect))


func set_loading(on: bool) -> void:
	loading.visible = on


## Online duel: only the host can call a rematch, and the other button leaves the table.
func set_online(is_host: bool) -> void:
	_online = true
	_is_host = is_host
	select_button.text = "Back to lobby" if is_host else "Leave duel"


## `live` is the beat's own state (see GameEvent.state) while an update replays, {} otherwise.
func refresh_state(view: SeatView, viewer: int, live: Dictionary = {}) -> void:
	_view = view
	# Hotseat has no fixed viewer: the seat at the table is whoever has to decide.
	var me: int = viewer
	if me < 0:
		me = view.deciding if view.deciding >= 0 else view.active
	_viewer_seat = me
	bottom_panel.refresh(view.player(me), view, true, _beat_standing(live, me))
	top_panel.refresh(view.player(1 - me), view, false, _beat_standing(live, 1 - me))
	near_flags.text = bottom_panel.flags_label.text
	far_flags.text = top_panel.flags_label.text
	near_flags.visible = not scene_flags and not near_flags.text.is_empty()
	far_flags.visible = not scene_flags and not far_flags.text.is_empty()
	_refresh_phase(view, me, live)


## One player's slice of a beat's state (see GameEvent.state), {} when the update has none.
static func _beat_standing(live: Dictionary, index: int) -> Dictionary:
	if live.is_empty():
		return {}
	var out: Dictionary = {}
	var fervor: Array = live.get("fervor", [])
	if index < fervor.size():
		out["fervor"] = int(fervor[index])
	# The turn position too, so a panel never flags the next player as active while the beats of
	# this one are still playing.
	for key in ["active", "step", "phase", "attacker"]:
		if live.has(key):
			out[key] = int(live[key])
	var zones: Array = live.get("zones", [])
	if index < zones.size() and (zones[index] as Array).size() >= 4:
		var z: Array = zones[index]
		out["life"] = int(z[0])
		out["hand"] = int(z[1])
		out["discard"] = int(z[2])
		out["removed"] = int(z[3])
	return out


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
	for i in range(_step_labels.size()):
		var l: Label = _step_labels[i]
		var on: bool = i == current and not over
		var done: bool = current >= 0 and i < current and not over
		l.add_theme_color_override("font_color", ZenithTheme.ACCENT if on else ZenithTheme.MUTED)
		l.add_theme_font_size_override("font_size", 15 if on else 13)
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
		phase_sub.visible = false
		phase_panel.add_theme_stylebox_override("panel", ZenithTheme.get_theme().get_stylebox("panel", "PanelContainer"))
		return

	var mine: bool = active == me
	turn_who.text = ("YOUR TURN" if mine else "THEIR TURN") + "  /  " + (STEP_LABELS[current].to_upper() if current >= 0 else "")
	if current < 0:
		turn_counter.text = "PREPARE"
		turn_who.text = "RESERVE"
	turn_who.add_theme_color_override("font_color", ZenithTheme.ACCENT if mine else ZenithTheme.MUTED)
	# A gold left edge while the viewer acts, so the banner itself says whether to reach for a card.
	phase_panel.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0.025, 0.035, 0.06, 0.72), Color.TRANSPARENT, 18, 0, 18, 8))

	var beat: String = _combat_beat(view, me, live)
	phase_sub.visible = beat != ""
	phase_sub.text = "[center]%s[/center]" % beat


## The beat inside Combat as bbcode in the attack and defence colours, "" outside Combat.
func _combat_beat(view: SeatView, me: int, live: Dictionary = {}) -> String:
	if int(live.get("step", view.step)) != GameState.Step.COMBAT:
		return ""
	var att: int = int(live.get("attacker", view.attacker))
	var act: int = int(live.get("active", view.active))
	var attacker: String = "YOU" if att == me else view.player(att).name.to_upper()
	var defender: String = "YOU" if att != me else view.player(1 - att).name.to_upper()
	match int(live.get("phase", view.phase)):
		GameState.Phase.PREPARE_ACTIVE, GameState.Phase.PREPARE_OPPOSING:
			return _tint("ENTERING COMBAT", ZenithTheme.MUTED)
		GameState.Phase.OPPOSING_DRAW:
			var who: String = "YOU DRAW" if act != me else "%s DRAWS" % view.player(1 - act).name.to_upper()
			return _tint(who, ZenithTheme.MUTED)
		GameState.Phase.ATTACK:
			return _tint("%s %s" % [attacker, "ATTACK" if attacker == "YOU" else "ATTACKS"], ZenithTheme.ATTACK)
		GameState.Phase.FIGHT_BACK:
			return _tint("%s %s" % [attacker, "FIGHT BACK" if attacker == "YOU" else "FIGHTS BACK"], ZenithTheme.ATTACK)
		GameState.Phase.DEFEND:
			# Both halves at once: the question here is who is swinging at whom.
			return "%s   %s   %s" % [
				_tint("%s %s" % [attacker, "ATTACK" if attacker == "YOU" else "ATTACKS"], ZenithTheme.ATTACK),
				_tint("·", ZenithTheme.MUTED),
				_tint("%s %s" % [defender, "DEFEND" if defender == "YOU" else "DEFENDS"], ZenithTheme.DEFEND),
			]
		GameState.Phase.BATTLE:
			var whose: String = "YOUR" if att == me else attacker + "'S"
			return _tint("%s ATTACK RESOLVES" % whose, ZenithTheme.ATTACK)
		GameState.Phase.COMBAT_END:
			return _tint("COMBAT ENDS", ZenithTheme.MUTED)
	return ""


func _tint(text: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]


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

func show_prompt(p: PromptView, view: SeatView) -> void:
	prompt_panel.show()
	_view = view
	_current_prompt = p
	var who: SeatPlayer = view.player(p.player)
	prompt_who.text = "%s  ·  YOUR DECISION" % who.name.to_upper()
	prompt_who.add_theme_color_override("font_color", Palette.school_ui(who.style))
	prompt_title.text = p.title
	_show_attack(view, p)
	show_focus(_focus_uid(p), _focus_caption(p))
	prompt_hint.text = _hint_for(p)
	prompt_hint.visible = prompt_hint.text != ""
	# Cards the player can already click in the hand or on the table stay there, highlighted.
	# Cards that need browsing (a Reserve, a look at the deck, a keep) open in the tray.
	# A Final Strike is offered on every hand card and commits the rest of the Combat, so it
	# gets its own button and tray rather than firing from a card click.
	var browse: Array[OptionView] = []
	var primaries: Array[OptionView] = []
	var finals: Array[OptionView] = []
	for opt in p.options:
		if opt.type == &"final_strike":
			finals.append(opt)
		elif opt.type == &"pick_option" and opt.card < 0:
			# A choice between wordings rather than cards ("all their Allies or all their Drills").
			# It reads as a card-sized tile in the tray, not as a row of small buttons.
			browse.append(opt)
		elif BUTTON_KINDS.has(p.kind) or (opt.card < 0 and opt.type != &"name_card"):
			primaries.append(opt)
		elif _needs_tray(p, opt):
			browse.append(opt)
	var library: Array = p.context.get("library", [])
	if not library.is_empty():
		# A search of the Life Deck: the matches to pick from, then the rest of the deck to read.
		_fill_buttons([], primary_box, true)
		await _show_tray(prompt_who.text, p.title, prompt_hint.text, browse, primaries, false, p if p.has_batch() else null)
		await _add_library(library, browse)
	elif browse.is_empty():
		_hide_tray()
		_fill_buttons(primaries, primary_box, true)
		if not finals.is_empty():
			var b: Button = Button.new()
			b.text = "Final Strike…"
			b.custom_minimum_size = Vector2(0, 40)
			b.add_theme_font_size_override("font_size", 24)
			b.pressed.connect(func() -> void: _show_final_strike(finals))
			primary_box.add_child(b)
	else:
		_fill_buttons([], primary_box, true)
		_show_tray(prompt_who.text, p.title, prompt_hint.text, browse, primaries, false, p if p.has_batch() else null)


func _needs_tray(p: PromptView, opt: OptionView) -> bool:
	if opt.type == &"name_card" or TRAY_KINDS.has(p.kind):
		return true
	var c: SeatCard = _view.card(opt.card)
	return c == null or c.zone == &"life_deck" or c.zone == &"reserve"


## The attack in the air, when there is one: a headline chip (kind, source, what makes it hard)
## and the two or three numbers the decision actually turns on, as big tiles. The step-by-step
## damage maths lives under the card in the focus view, not here.
func _show_attack(view: SeatView, p: PromptView = null) -> void:
	prompt_outcome.hide()
	var a: Dictionary = view.attack
	var head: String = _attack_headline(view)
	prompt_banner.visible = head != ""
	prompt_banner.text = head
	var mine: bool = not a.is_empty() and int(a.get("attacker", -1)) == view.seat
	ZenithTheme.chip(prompt_banner, ZenithTheme.ATTACK if mine else ZenithTheme.DEFEND)
	_show_hero(view, p)
	# Keep Energy and stop requirements visible alongside wound previews.
	var facts: Array[Dictionary] = _facts_for(view, p)
	if prompt_hero.visible:
		facts = facts.filter(func(f: Dictionary) -> bool: return str(f["name"]) != "Wounds")
	_fill_facts(facts)


## The one number a damage decision turns on: the life cards about to be lost, counting the
## Energy that would overflow into them. It leads the panel and changes as the player hovers a
## choice. An attack that costs no life cards has no number to lead with, so the panel falls
## back to its tiles rather than showing a large and meaningless zero.
func _show_hero(view: SeatView, p: PromptView) -> void:
	_hero_base = -1
	if not view.attack.is_empty():
		if p != null:
			for o in p.options:
				if o.outcome.has("life"):
					# The worst of them is where the player stands before choosing.
					_hero_base = maxi(_hero_base, int(o.outcome["life"]))
		else:
			# The seat watching the decision sees the same number, without the options.
			_hero_base = _incoming_wounds(view)
	prompt_hero.visible = _hero_base > 0
	if not prompt_hero.visible:
		return
	hero_name.text = "WOUND INCOMING" if _hero_base == 1 else "WOUNDS INCOMING"
	_preview_outcome({})


## Life cards the attack in the air would cost right now: its own wounds plus the Energy that
## overflows past what the target is standing on, or what is left to flip once it is landing.
func _incoming_wounds(view: SeatView) -> int:
	var a: Dictionary = view.attack
	if a.is_empty() or bool(a.get("stopped", false)):
		return 0
	if int(a.get("life_remaining", 0)) > 0:
		return int(a["life_remaining"])
	return int((a.get("damage", {}) as Dictionary).get("wounds", 0))


## The outcome of the option a hand or table card would take, when it carries one (defending
## with that card, for instance). {} when the card has no such option.
func _card_outcome(uid: int) -> Dictionary:
	if _current_prompt == null:
		return {}
	for o in _current_prompt.options_for_card(uid):
		if not o.outcome.is_empty():
			return o.outcome
	return {}


## Draws the hero number for an option the player is hovering, or the standing number for {}.
func _preview_outcome(outcome: Dictionary) -> void:
	# These are referee-provided remaining damage values, not a client simulation of effects.
	prompt_outcome.visible = outcome.has("stages") or outcome.has("stopped")
	if prompt_outcome.visible:
		var stopped: bool = bool(outcome.get("stopped", false))
		prompt_outcome.text = "After choice: Stopped" if stopped else "After choice: %d Energy, %d wounds" % [int(outcome.get("stages", 0)), int(outcome.get("life", 0))]
		prompt_outcome.add_theme_color_override("font_color", ZenithTheme.DEFEND if stopped else ZenithTheme.TEXT)
	if _hero_base < 0:
		return
	var shown: int = int(outcome.get("life", _hero_base))
	var delta: int = shown - _hero_base
	hero_value.text = str(shown)
	hero_value.add_theme_color_override("font_color",
		ZenithTheme.DEFEND if delta < 0 else (ZenithTheme.TEXT if shown == 0 else ZenithTheme.ATTACK))
	hero_delta.visible = not outcome.is_empty()
	hero_delta.text = "From %d to %d" % [_hero_base, shown] if delta != 0 else "Same as incoming"
	hero_delta.add_theme_color_override("font_color", ZenithTheme.DEFEND if delta < 0 else ZenithTheme.MUTED)


## Up to three headline numbers for the decision at hand. Each is {name, value, sub, color}.
func _facts_for(view: SeatView, p: PromptView) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var a: Dictionary = view.attack
	if a.is_empty():
		return out
	if bool(a.get("stopped", false)):
		out.append({"name": "Attack", "value": "Stopped", "sub": "", "color": ZenithTheme.DEFEND})
		return out
	var d: Dictionary = a.get("damage", {})
	var landed: bool = bool(a.get("landed", false))
	var stages: int = int(a.get("stages", 0)) if landed else int(d.get("stages", 0))
	var life: int = int(a.get("life", 0)) if landed else int(d.get("wounds", d.get("life", 0)))
	if stages > 0:
		out.append({"name": "Energy", "value": str(stages), "sub": "off the target", "color": ZenithTheme.ATTACK})
	if life > 0:
		var over: int = int(d.get("overflow", 0))
		out.append({"name": "Wounds", "value": str(life), "sub": "%d from overflow" % over if over > 0 else "life cards", "color": ZenithTheme.ATTACK})
	var remaining: int = int(a.get("life_remaining", 0))
	if remaining > 0:
		out.append({"name": "To flip", "value": str(remaining), "sub": "still coming", "color": ZenithTheme.WARN})
	if p != null and p.kind == &"endurance":
		# The one number this choice is about: how much of what is still coming it buys off.
		var prevents: int = mini(int(p.context.get("endurance", 0)), int(p.context.get("remaining", 0)))
		out = [{"name": "To flip", "value": str(int(p.context.get("remaining", 0))), "sub": "still coming", "color": ZenithTheme.WARN},
			{"name": "Prevents", "value": str(prevents), "sub": "if you spend it", "color": ZenithTheme.DEFEND}]
	elif int(a.get("stops_needed", 1)) > 1:
		out.append({"name": "Stops", "value": str(int(a.get("stops_needed", 1))), "sub": "needed", "color": ZenithTheme.DEFEND})
	return out.slice(0, 3)


func _fill_facts(facts: Array[Dictionary]) -> void:
	for child in prompt_facts.get_children():
		child.queue_free()
	prompt_facts.visible = not facts.is_empty()
	for f in facts:
		var detail: Label = Label.new()
		detail.text = "%s %s" % [str(f["value"]), str(f["name"])] + (" incoming" if str(f["name"]) == "Energy" else "")
		detail.tooltip_text = str(f["sub"])
		detail.add_theme_font_size_override("font_size", 24)
		detail.add_theme_color_override("font_color", f["color"])
		prompt_facts.add_child(detail)


func _attack_headline(view: SeatView) -> String:
	var a: Dictionary = view.attack
	if a.is_empty():
		return ""
	var kind: String = str(a.get("kind", "strike"))
	var parts: PackedStringArray = PackedStringArray()
	var head: String = ("Focused " if bool(a.get("focused", false)) else "") + ("Strike" if kind == "strike" else "Art")
	if bool(a.get("is_final", false)):
		head = "Final Strike"
	var source_title: String = str(a.get("source_title", ""))
	if source_title != "":
		head += ": " + source_title
	elif bool(a.get("is_power", false)):
		var performer: String = str(a.get("performer_title", ""))
		head += " from %s's Power" % (performer if performer != "" else "a personality")
	if bool(a.get("empowered", false)):
		head += " (Empowered)"
	parts.append(head)
	if bool(a.get("unstoppable", false)):
		parts.append("cannot be stopped")
	elif int(a.get("stops_needed", 1)) > 1:
		parts.append("needs %d stops" % int(a.get("stops_needed", 1)))
	if bool(a.get("no_prevent", false)):
		parts.append("damage cannot be prevented")
	var mine: bool = int(a.get("attacker", -1)) == view.seat
	return ("Your " if mine else "Incoming ") + "  ·  ".join(parts)


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
	# Whatever they are deciding about, this seat is looking at the same card and the same count.
	show_focus(_focus_uid(null), _focus_caption(null))
	prompt_hint.text = _waiting_hint(kind)
	prompt_hint.visible = prompt_hint.text != ""
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
	prompt_panel.show()
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
	prompt_panel.hide()
	prompt_outcome.hide()
	_current_prompt = null
	hide_peek()
	prompt_who.text = ""
	prompt_title.text = "…"
	prompt_banner.visible = false
	prompt_hero.visible = false
	_hero_base = -1
	_fill_facts([])
	prompt_hint.visible = false
	hide_focus()
	_hide_tray()
	_fill_buttons([], primary_box, true)


## Alternatives without a card use equal emphasis; neither passing nor accepting a hit is
## presented as a recommendation. Vertical in the side panel, a row in the tray.
func _fill_buttons(options: Array[OptionView], into: Container, vertical: bool, _first_is_default: bool = false) -> void:
	for child in into.get_children():
		into.remove_child(child)
		child.queue_free()
	for i in range(options.size()):
		var opt: OptionView = options[i]
		var b: Button = Button.new()
		b.text = opt.label
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


# --- Tray -----------------------------------------------------------------

## A centred browser over the table: one face per card option with the action as its caption,
## the no-card options as a button row beneath, and Back when this is a sub-choice. `actions`
## become the buttons; with `sub_choice` they act on the single card shown. With `batch`, clicks
## toggle cards and one confirm button sends them all at once.
func _show_tray(who: String, title: String, hint: String, cards: Array[OptionView], actions: Array[OptionView], sub_choice: bool, batch: PromptView = null, accent_first: bool = true) -> void:
	_batch = batch
	_selected.clear()
	_entries.clear()
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
		face.texture = await _faces.render_face(def, c.aspect) if def != null and _faces != null else null
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
		tex = await _faces.render_face(def, aspect)
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
	if not sub_choice:
		var verb: String = str(TRAY_VERBS.get(opt.type, opt.label))
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
		b.texture_normal = faces.face(def, c.aspect)
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

## Full-size live face over a dimmed table, so keyword hover works. Right-click or Inspect opens
## it; Esc or a click outside closes it.
func show_inspect(def: CardDef, aspect: int = 0, uid: int = -1) -> void:
	if def == null:
		return
	hide_peek()
	hide_focus()
	inspect_face.show_def(def, aspect, _live_energy(uid), _standing(uid))
	var standing: SeatPlayer = _standing(uid)
	if standing == null and _view != null:
		for player in _view.players:
			if player.controlling == uid:
				standing = player
	inspect_status_scroll.visible = standing != null
	if standing != null:
		var flags: String = bottom_panel.flags_label.text if standing.index == _viewer_seat else top_panel.flags_label.text
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
	focus_caption.text = caption.to_upper()
	focus_face.show_def(def, c.aspect, _live_energy(uid), _standing(uid))
	focus.visible = true


func hide_focus() -> void:
	focus.visible = false


## The card the prompt is about: one it names outright, one raised by a card's effect, or the
## attack in the air. -1 when the decision is not about a single card.
func _focus_uid(p: PromptView) -> int:
	if p != null:
		if p.context.has("card"):
			return int(p.context["card"])
		if p.context.has("source"):
			return int(p.context["source"])
	if _view != null and not _view.attack.is_empty():
		return int(_view.attack.get("source", -1))
	return -1


func _focus_caption(p: PromptView) -> String:
	if p == null:
		return "Incoming"
	match p.kind:
		&"endurance":
			return "The card you just lost"
		&"defense", &"redirect", &"control":
			return "Incoming"
		&"respond":
			return "Their card"
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
	peek_face.show_def(def, aspect, _live_energy(uid), _standing(uid))
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


func show_handoff(player_name: String) -> void:
	handoff_title.text = "Pass the table to %s" % player_name
	handoff.visible = true
	clear_hand()
	hide_peek()
	hide_inspect()


func hide_handoff() -> void:
	handoff.visible = false


func show_game_over(title: String, reason: String, rematch_possible: bool = true) -> void:
	game_over_title.text = title
	game_over_reason.text = reason
	game_over.visible = true
	rematch_button.visible = rematch_possible and (not _online or _is_host)
	if _online and not _is_host and rematch_possible:
		game_over_reason.text += "\nThe host can call a rematch."
	clear_prompt()
	clear_hand()
