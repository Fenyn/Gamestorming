class_name DuelHud
extends CanvasLayer
## 2D layer over the table: player panels, phase strip, log, hand, prompt, overlays. Everything
## it shows comes from a SeatView and a PromptView, never from the engine.

signal option_chosen(opt: OptionView)
signal card_clicked(uid: int)
signal card_hovered(uid: int, over: bool)
signal handoff_confirmed
signal rematch_requested
signal select_requested

const HAND_CARD_SIZE: Vector2 = Vector2(126, 176)
const HAND_LIFT: float = 26.0
const MAX_LOG_LINES: int = 300
const TRAY_CARD_SIZE: Vector2 = Vector2(160, 224)
const ZOOM_GRACE: float = 0.3        # seconds the zoom waits for the pointer to reach it
const TRAY_COLUMNS: int = 7          # cards per row before the tray wraps
const TRAY_ROWS_SHOWN: int = 2       # rows before the tray scrolls
## Prompt kinds whose card options are browsed in the tray even when the cards are in the hand:
## the decision is about the cards themselves, as in a discard-step keep or an Armory swap.
const TRAY_KINDS: Array[StringName] = [&"armory", &"keep", &"discard_choice", &"recover", &"pick_option", &"name_card"]
## Tray captions by option type; anything else shows the option's own label.
const TRAY_VERBS: Dictionary = {
	&"armory_in": "Bring in", &"keep": "Keep", &"discard_choice": "Discard", &"recover": "Recover",
	&"pick_option": "Choose", &"pick_in_play": "Choose", &"name_card": "Name", &"capture": "Capture",
}
const STEP_LABELS: Array[String] = ["Draw", "Place", "Power Up", "Declare", "Combat", "Discard", "Recover"]
const STEP_ORDER: Array[int] = [
	GameState.Step.DRAW, GameState.Step.NON_COMBAT, GameState.Step.POWER_UP, GameState.Step.DECLARE,
	GameState.Step.COMBAT, GameState.Step.DISCARD, GameState.Step.RECOVER,
]
## Options that move the game along rather than commit a card. They sit under the card list and
## the ones here get the accent style; the rest (skip, decline, no capture) stay quiet.
const ACCENT_TYPES: Array[StringName] = [&"declare", &"pass", &"done", &"endure", &"recover", &"no_defense", &"armory_done", &"decline", &"pick_none"]
## Prompt kinds answered by the defender while an attack is in the air; they show the attack banner.
const DEFENDER_KINDS: Array[StringName] = [&"defense", &"endurance", &"redirect", &"control", &"respond"]

@onready var root: Control = $Root
@onready var top_panel: PlayerPanel = $Root/TopPanel
@onready var bottom_panel: PlayerPanel = $Root/BottomPanel
@onready var steps_box: HBoxContainer = $Root/PhasePanel/Column/Steps
@onready var phase_sub: Label = $Root/PhasePanel/Column/Sub
@onready var log_text: RichTextLabel = $Root/Log/Column/Scroll/Text
@onready var zoom: Control = $Root/Zoom
@onready var zoom_face: CardFace = $Root/Zoom/Face
@onready var hand: HBoxContainer = $Root/Hand
@onready var prompt_panel: PanelContainer = $Root/PromptPanel
@onready var prompt_who: Label = $Root/PromptPanel/Column/Who
@onready var prompt_title: Label = $Root/PromptPanel/Column/Title
@onready var prompt_banner: Label = $Root/PromptPanel/Column/Banner
@onready var prompt_hint: Label = $Root/PromptPanel/Column/Hint
@onready var primary_box: VBoxContainer = $Root/PromptPanel/Column/Primary
@onready var tray: ColorRect = $Root/Tray
@onready var tray_who: Label = $Root/Tray/Center/Panel/Column/Who
@onready var tray_title: Label = $Root/Tray/Center/Panel/Column/Title
@onready var tray_hint: Label = $Root/Tray/Center/Panel/Column/Hint
@onready var tray_scroll: ScrollContainer = $Root/Tray/Center/Panel/Column/Scroll
@onready var tray_cards: HFlowContainer = $Root/Tray/Center/Panel/Column/Scroll/Cards
@onready var tray_buttons: HBoxContainer = $Root/Tray/Center/Panel/Column/Buttons
@onready var handoff: ColorRect = $Root/Handoff
@onready var handoff_title: Label = $Root/Handoff/Center/Column/Title
@onready var handoff_ready: Button = $Root/Handoff/Center/Column/Ready
@onready var game_over: ColorRect = $Root/GameOver
@onready var game_over_title: Label = $Root/GameOver/Center/Column/Title
@onready var game_over_reason: Label = $Root/GameOver/Center/Column/Reason
@onready var rematch_button: Button = $Root/GameOver/Center/Column/Buttons/Rematch
@onready var select_button: Button = $Root/GameOver/Center/Column/Buttons/Select
@onready var loading: ColorRect = $Root/Loading

var _log_lines: int = 0
var _current_prompt: PromptView = null
var _view: SeatView = null
var _step_labels: Array[Label] = []
var _faces: CardFaceCache = null
var _zoom_hide_token: int = 0        # bumps to cancel a pending zoom hide
var _batch: PromptView = null          # the prompt behind a multi-select tray, else null
var _selected: Array[int] = []
var _entries: Dictionary = {}          # uid -> {frame, caption, verb} for batch trays
var _confirm: Button = null
var _online: bool = false
var _is_host: bool = false


func _ready() -> void:
	root.theme = ZenithTheme.get_theme()
	for name in STEP_LABELS:
		var l: Label = Label.new()
		l.text = name
		l.add_theme_font_size_override("font_size", 13)
		steps_box.add_child(l)
		_step_labels.append(l)
	handoff_ready.pressed.connect(func() -> void: handoff_confirmed.emit())
	rematch_button.pressed.connect(func() -> void: rematch_requested.emit())
	select_button.pressed.connect(func() -> void: select_requested.emit())
	log_text.add_theme_color_override("default_color", ZenithTheme.MUTED)
	zoom.visible = false
	zoom.mouse_exited.connect(_on_zoom_mouse_exited)


func set_loading(on: bool) -> void:
	loading.visible = on


## Online duel: only the host can call a rematch, and the other button leaves the table.
func set_online(is_host: bool) -> void:
	_online = true
	_is_host = is_host
	select_button.text = "Back to lobby" if is_host else "Leave duel"


func refresh_state(view: SeatView, viewer: int) -> void:
	_view = view
	var me: int = viewer if viewer >= 0 else view.active
	bottom_panel.refresh(view.player(me), view, viewer >= 0)
	top_panel.refresh(view.player(1 - me), view, false)
	_refresh_phase(view)


func _refresh_phase(view: SeatView) -> void:
	var current: int = STEP_ORDER.find(view.step)
	for i in range(_step_labels.size()):
		var l: Label = _step_labels[i]
		var on: bool = i == current and not view.is_over()
		l.add_theme_color_override("font_color", ZenithTheme.ACCENT if on else ZenithTheme.MUTED)
		if on:
			l.add_theme_stylebox_override("normal", ZenithTheme.box(ZenithTheme.ACCENT_SOFT, Color(0, 0, 0, 0), 5, 0, 8, 2))
		else:
			l.add_theme_stylebox_override("normal", ZenithTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 5, 0, 8, 2))
	if view.is_over():
		phase_sub.text = "Duel over"
		return
	var text: String = "Turn %d  ·  %s's turn" % [view.turn, view.player(view.active).name]
	if view.step == GameState.Step.COMBAT:
		match view.phase:
			GameState.Phase.PREPARE_ACTIVE, GameState.Phase.PREPARE_OPPOSING:
				text += "  ·  entering Combat"
			GameState.Phase.OPPOSING_DRAW:
				text += "  ·  %s draws" % view.player(1 - view.active).name
			GameState.Phase.ATTACK, GameState.Phase.FIGHT_BACK:
				text += "  ·  %s to attack" % view.player(view.attacker).name
			GameState.Phase.DEFEND:
				text += "  ·  %s defends" % view.player(1 - view.attacker).name
			GameState.Phase.BATTLE:
				text += "  ·  %s's attack resolves" % view.player(view.attacker).name
	phase_sub.text = text


func log_line(text: String) -> void:
	if _log_lines >= MAX_LOG_LINES:
		log_text.clear()
		_log_lines = 0
	if text.begins_with("—"):
		log_text.append_text("[color=#dbb045]%s[/color]\n" % text)
	else:
		log_text.append_text(text + "\n")
	_log_lines += 1


# --- Prompt ---------------------------------------------------------------

func show_prompt(p: PromptView, view: SeatView) -> void:
	_view = view
	_current_prompt = p
	var who: SeatPlayer = view.player(p.player)
	prompt_who.text = "%s  ·  YOUR DECISION" % who.name.to_upper()
	prompt_who.add_theme_color_override("font_color", Palette.guild_ui(who.focus))
	prompt_title.text = p.title
	var banner: String = _incoming_text(view) if DEFENDER_KINDS.has(p.kind) else ""
	prompt_banner.visible = banner != ""
	prompt_banner.text = banner
	ZenithTheme.chip(prompt_banner, ZenithTheme.ATTACK)
	prompt_hint.text = _hint_for(p)
	prompt_hint.visible = prompt_hint.text != ""
	# Cards the player can already click in the hand or on the table stay there, highlighted.
	# Cards that need browsing (an Armory, a look at the deck, a keep) open in the tray.
	var browse: Array[OptionView] = []
	var primaries: Array[OptionView] = []
	for opt in p.options:
		if opt.card < 0 and opt.type != &"name_card":
			primaries.append(opt)
		elif _needs_tray(p, opt):
			browse.append(opt)
	if browse.is_empty():
		_hide_tray()
		_fill_buttons(primaries, primary_box, true)
	else:
		_fill_buttons([], primary_box, true)
		_show_tray(prompt_who.text, p.title, prompt_hint.text, browse, primaries, false, p if p.has_batch() else null)


func _needs_tray(p: PromptView, opt: OptionView) -> bool:
	if opt.type == &"name_card" or TRAY_KINDS.has(p.kind):
		return true
	var c: SeatCard = _view.card(opt.card)
	return c == null or c.zone == &"life_deck" or c.zone == &"armory"


## One line about the attack the defender is answering: kind, source, and what makes it hard.
func _incoming_text(view: SeatView) -> String:
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
	parts.append(head)
	if bool(a.get("unstoppable", false)):
		parts.append("cannot be stopped")
	elif int(a.get("stops_needed", 1)) > 1:
		parts.append("needs %d stops" % int(a.get("stops_needed", 1)))
	if bool(a.get("no_prevent", false)):
		parts.append("damage cannot be prevented")
	return "Incoming " + "  ·  ".join(parts)


func _hint_for(p: PromptView) -> String:
	var card_options: int = p.card_uids().size()
	match p.kind:
		&"armory":
			return "Each card you bring in swaps with a random card from your Life Deck."
		&"non_combat":
			return "Click a highlighted card to place it, then Done." if card_options > 0 else ""
		&"attack_action":
			return "Click a highlighted card, or choose below."
		&"defense":
			return "Click a highlighted card to defend, or take the hit." if card_options > 0 else ""
		&"keep":
			return "Everything else goes to the discard pile."
		&"endurance":
			return "The flipped card can prevent %d more wounds. It leaves the game if used." % int(p.context.get("endurance", 0))
		&"recover":
			return "No Combat this turn, so one discard card may return to the deck bottom."
		&"respond":
			if str(p.context.get("mode", "")) == "declare":
				return "Your opponent is about to decide on Combat. Use a card now or let them choose."
			return "Your opponent played a Combat card. Counter it now or let it resolve."
		&"pay":
			return "Each step of Vigor paid adds to the wounds dealt."
		&"discard_choice":
			var whose: String = "your opponent's hand" if int(p.context.get("target", p.player)) != p.player else "your hand"
			return "Pick the cards that leave %s." % whose if p.has_batch() else "Pick the card that leaves %s." % whose
		&"pick_in_play":
			return "Pick the card in play the effect hits."
		&"name_card":
			return "The named card cannot be played or used while the Drill stays in play."
		_:
			return ""


## Online: the other player is deciding. The panel says who and roughly what, with no options.
func show_waiting(player_name: String, kind: StringName, view: SeatView) -> void:
	_view = view
	_current_prompt = null
	prompt_who.text = "%s  ·  DECIDING" % player_name.to_upper()
	prompt_who.add_theme_color_override("font_color", ZenithTheme.MUTED)
	prompt_title.text = "Waiting for %s" % player_name
	var banner: String = _incoming_text(view) if DEFENDER_KINDS.has(kind) else ""
	prompt_banner.visible = banner != ""
	prompt_banner.text = banner
	ZenithTheme.chip(prompt_banner, ZenithTheme.ATTACK)
	prompt_hint.text = _waiting_hint(kind)
	prompt_hint.visible = prompt_hint.text != ""
	_hide_tray()
	_fill_buttons([], primary_box, true)


## What the other player is doing, in terms that give nothing hidden away.
func _waiting_hint(kind: StringName) -> String:
	match kind:
		&"armory":
			return "They are setting up their Armory."
		&"non_combat":
			return "They may place cards before deciding on Combat."
		&"declare":
			return "They are deciding whether to enter Combat."
		&"attack_action":
			return "They are choosing an attack, or passing."
		&"defense", &"endurance", &"redirect", &"control":
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
	_hide_tray()
	prompt_who.text = ""
	prompt_title.text = "…"
	prompt_hint.text = "Sending your choice to the host."
	prompt_hint.visible = true


## One clicked card with more than one legal action: the card, its actions as buttons, and Back.
func show_card_choice(options: Array[OptionView]) -> void:
	var c: SeatCard = _view.card(options[0].card)
	var single: Array[OptionView] = [options[0]]
	_show_tray(prompt_who.text, c.title if c != null else "Choose an action", "", single, options, true)


func clear_prompt() -> void:
	_current_prompt = null
	prompt_who.text = ""
	prompt_title.text = "…"
	prompt_banner.visible = false
	prompt_hint.visible = false
	_hide_tray()
	_fill_buttons([], primary_box, true)


## Options without a card (pass, declare, done, pay N). The ones that move the game on get the
## accent; skips and declines stay quiet. Vertical in the side panel, a row in the tray.
func _fill_buttons(options: Array[OptionView], into: Container, vertical: bool, first_is_default: bool = false) -> void:
	for child in into.get_children():
		into.remove_child(child)
		child.queue_free()
	for i in range(options.size()):
		var opt: OptionView = options[i]
		var b: Button = Button.new()
		b.text = opt.label
		b.custom_minimum_size = Vector2(0 if vertical else 150, 40)
		b.add_theme_font_size_override("font_size", 16)
		if ACCENT_TYPES.has(opt.type) or (first_is_default and i == 0):
			b.theme_type_variation = &"AccentButton"
		b.pressed.connect(func() -> void: option_chosen.emit(opt))
		into.add_child(b)


# --- Tray -----------------------------------------------------------------

## A centred browser over the table: one face per card option with the action as its caption,
## the no-card options as a button row beneath, and Back when this is a sub-choice. `actions`
## become the buttons; with `sub_choice` they act on the single card shown. With `batch`, clicks
## toggle cards and one confirm button sends them all at once.
func _show_tray(who: String, title: String, hint: String, cards: Array[OptionView], actions: Array[OptionView], sub_choice: bool, batch: PromptView = null) -> void:
	_batch = batch
	_selected.clear()
	_entries.clear()
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
	var cols: int = mini(shown, TRAY_COLUMNS)
	var rows: int = mini(ceili(float(shown) / TRAY_COLUMNS), TRAY_ROWS_SHOWN)
	var cell: Vector2 = TRAY_CARD_SIZE + Vector2(6.0, 6.0 + 6.0 + 20.0)   # frame pad, caption
	tray_scroll.custom_minimum_size = Vector2(cols * (cell.x + 12.0) + 12.0, rows * (cell.y + 12.0))
	_fill_buttons(actions, tray_buttons, false, sub_choice)
	if batch != null:
		_confirm = Button.new()
		_confirm.theme_type_variation = &"AccentButton"
		_confirm.custom_minimum_size = Vector2(180, 40)
		_confirm.add_theme_font_size_override("font_size", 16)
		_confirm.pressed.connect(func() -> void:
			if _selected.size() >= _batch.batch_min:
				option_chosen.emit(_batch.batch_option(_selected)))
		tray_buttons.add_child(_confirm)
		tray_buttons.move_child(_confirm, 0)
		_refresh_selection()
	if sub_choice:
		var back: Button = Button.new()
		back.text = "Back"
		back.custom_minimum_size = Vector2(120, 40)
		back.pressed.connect(_on_back)
		tray_buttons.add_child(back)
	tray.visible = true
	prompt_panel.visible = false
	hand.visible = false


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
	tray.visible = false
	prompt_panel.visible = true
	hand.visible = true
	_batch = null
	_confirm = null
	_selected.clear()
	_entries.clear()


## A face with its caption. Clicking the face picks the option unless it is a sub-choice, where
## the buttons decide. Named-card options carry a title instead of a uid and draw from the library.
func _tray_entry(opt: OptionView, sub_choice: bool) -> Control:
	var def: CardDef = null
	var tier: int = 0
	var uid: int = opt.card
	if opt.type == &"name_card":
		def = _def_by_title(str(opt.value))
	else:
		var c: SeatCard = _view.card(opt.card)
		if c != null and not c.hidden():
			def = _def(c.def_id)
			tier = c.tier
	var tex: Texture2D = null
	if def != null and _faces != null:
		tex = await _faces.render_face(def, tier)
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
		if uid >= 0:
			card_hovered.emit(uid, true)
		elif def != null:
			show_zoom(def, tier))
	b.mouse_exited.connect(func() -> void:
		if not _selected.has(uid):
			frame.add_theme_stylebox_override("panel", ZenithTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 10, 3, 3, 3))
		_lift(frame, false)
		if uid >= 0:
			card_hovered.emit(uid, false)
		else:
			hide_zoom())
	frame.add_child(b)
	column.add_child(frame)
	if not sub_choice:
		var verb: String = str(TRAY_VERBS.get(opt.type, opt.label))
		var caption: Label = Label.new()
		caption.text = verb
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 13)
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
		b.texture_normal = faces.face(def, c.tier)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.custom_minimum_size = HAND_CARD_SIZE
		b.modulate = Color(1, 1, 1, 1) if is_legal else Color(0.6, 0.6, 0.6, 1)
		var uid: int = c.uid
		b.pressed.connect(func() -> void: card_clicked.emit(uid))
		b.mouse_entered.connect(func() -> void:
			card_hovered.emit(uid, true)
			_lift(frame, true))
		b.mouse_exited.connect(func() -> void:
			card_hovered.emit(uid, false)
			_lift(frame, false))
		frame.add_child(b)
		hand.add_child(frame)


func _lift(frame: Control, up: bool) -> void:
	var t: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(frame, "scale", Vector2.ONE * (1.08 if up else 1.0), 0.12)
	frame.z_index = 1 if up else 0


func clear_hand() -> void:
	for child in hand.get_children():
		child.queue_free()


# --- Zoom and overlays ----------------------------------------------------

## The zoom is a live face, so its keywords answer to the mouse. It stays open while the pointer is
## over it and goes when the pointer leaves, so a player can slide from a card onto the zoom.
func show_zoom(def: CardDef, tier: int = 0) -> void:
	_zoom_hide_token += 1
	if def == null:
		zoom.visible = false
		return
	zoom_face.show_def(def, tier)
	zoom.visible = true


func hide_zoom(now: bool = false) -> void:
	if not zoom.visible:
		return
	_zoom_hide_token += 1
	if now:
		zoom.visible = false
		return
	var token: int = _zoom_hide_token
	await get_tree().create_timer(ZOOM_GRACE).timeout
	if token != _zoom_hide_token or not is_inside_tree():
		return
	if zoom.get_global_rect().has_point(zoom.get_global_mouse_position()):
		return
	zoom.visible = false


func _on_zoom_mouse_exited() -> void:
	if zoom.visible:
		_zoom_hide_token += 1
		zoom.visible = false


func show_handoff(player_name: String) -> void:
	handoff_title.text = "Pass the table to %s" % player_name
	handoff.visible = true
	clear_hand()
	hide_zoom()


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
