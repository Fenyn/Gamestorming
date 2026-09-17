extends Node3D
## The playspace. Renders one seat's SeatView: a Card3D per uid the view lists, table tweens
## after every update, and every decision routed through the HUD prompt or a card click.
## Hotseat and hosting: a Referee lives here and the viewer's choices go straight to it.
## Hotseat: the camera swings to whichever player has to decide, behind a hand-off overlay.
## Against the AI: the viewer is pinned to the person's seat and an AiPlayer answers for the other.
## Online: the viewer is pinned to this client's seat. The host applies the joiner's commands
## through its Referee and sends seat 1 its update; the joiner holds no engine at all.

const CARD_SCENE: PackedScene = preload("res://scenes/duel/card_3d.tscn")
const SYNC_DURATION: float = 0.3
const CAMERA_SWING: float = 0.7
const FLY_TIME: float = 0.34          # a card's arc from one zone to another
const FLY_LIFT: float = 0.6
const BEAT: float = 0.22              # pause after a hit or a flipped card, so each one reads
const TOAST_BEAT: float = 0.35
const AI_MIN_THINK: float = 0.45      # seconds the AI appears to think, so its plays do not snap

@onready var rig: Node3D = $CameraRig
@onready var camera: TableCamera = $CameraRig/Camera
@onready var zones: TableLayout = $Zones
@onready var cards_root: Node3D = $Cards
@onready var fx: DuelFx = $Fx
@onready var faces: CardFaceCache = $CardFaceCache
@onready var hud: DuelHud = $Hud

var referee: Referee = null          # hotseat and host only
var view: SeatView = null            # what the viewer may see right now
var prompt: PromptView = null        # the viewer's pending decision, null when it is not theirs
var views: Dictionary = {}           # uid -> Card3D
var _markers: Dictionary = {}        # uid -> StatusMarkers on personalities in play
var viewer: int = -1
var busy: bool = false
var online: bool = false
var ai: AiPlayer = null              # drives Session.ai_seat when the duel is against the AI
var ai_seat: int = -1
var _face_keys: Dictionary = {}      # uid -> face cache key currently on the quad
var _inbox: Array[Dictionary] = []   # host: joiner commands; joiner: host updates; waiting for the table to settle
var _awaiting_answer: bool = false   # joiner: our choice went to the host, its update is not back yet
var _dev_autoplay: bool = false
var _dev_steps: int = 0
var _dev_screenshot: String = ""
var _dev_hide_hud: bool = false
var _dev_stop_kind: StringName = &""
var _dev_camera: String = ""         # "dx,dz,notches": pan and zoom before the screenshot
var _dev_policy: String = ""         # "attack": autoplay fights instead of picking at random
var _dev_freeze: StringName = &""    # event type whose beat the screenshot catches mid-air
var _dev_done: bool = false
var _wounds: int = 0                 # life cards flipped by the attack being replayed
var _replaying: StringName = &""     # the event whose beat is playing now


func _ready() -> void:
	online = Net.active()
	_parse_dev_args()
	hud.option_chosen.connect(_on_option_chosen)
	hud.card_clicked.connect(_on_card_clicked)
	hud.handoff_confirmed.connect(_on_handoff_confirmed)
	hud.rematch_requested.connect(_on_rematch)
	hud.select_requested.connect(_on_select)
	hud.dev_command.connect(_on_dev_command)
	hud.set_loading(true)
	if online:
		viewer = Net.local_player
		rig.rotation.y = 0.0 if viewer == 0 else PI
		Net.command_rejected.connect(_on_net_rejected)
		Net.peer_left.connect(_on_peer_left)
		hud.set_online(Net.is_host())
	elif Session.ai_seat >= 0:
		ai_seat = Session.ai_seat
		viewer = 1 - ai_seat
		rig.rotation.y = 0.0 if viewer == 0 else PI
	if not Session.can_start():
		push_warning("Duel opened without a selection; using the first two shipped decks")
		Session.chosen = [Session.decks[0], Session.decks[1 if Session.decks.size() > 1 else 0]]
	hud.set_dev_available(OS.is_debug_build() and (not online or Net.is_host()))
	if online and not Net.is_host():
		await _ready_joiner()   # presents as soon as the host's first update lands
	else:
		await _ready_referee()
		_present_prompt()


## Hotseat and host: the rules run here.
func _ready_referee() -> void:
	referee = Session.build_referee()
	ai = Session.build_ai() if not online else null
	for d in Session.chosen:
		await faces.render_deck(d, Session.library)
	hud.set_loading(false)
	hud.log_line("Seed %d" % Session.last_seed)
	if online:
		hud.log_line("Online duel. You are hosting as %s." % Session.player_names[0])
		Net.command_received.connect(_on_net_command)
	referee.start()
	var updates: Array[SeatUpdate] = referee.take_updates()
	if online:
		Net.send_update(updates[1].to_dict())
	await _play_update(updates[maxi(viewer, 0)])


## Joiner: nothing but views. Faces for the other seat's deck render as cards appear.
func _ready_joiner() -> void:
	await faces.render_deck(Session.chosen[1], Session.library)
	await faces.render_deck(Session.chosen[0], Session.library, true)
	hud.set_loading(false)
	hud.log_line("Online duel. You are %s." % Session.player_names[1])
	if _dev_autoplay and _dev_steps > 0:
		_dev_steps += 1   # the setup update is not a command; the host does not count it either
	for u in Net.take_pending_updates():
		_inbox.append(u)
	Net.update_received.connect(_on_net_update)
	await _drain_inbox()


func _parse_dev_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--dev-autoplay":
			_dev_autoplay = true
		elif arg.begins_with("--dev-steps="):
			_dev_steps = int(arg.get_slice("=", 1))
		elif arg.begins_with("--dev-screenshot="):
			_dev_screenshot = arg.get_slice("=", 1)
		elif arg.begins_with("--dev-camera="):
			_dev_camera = arg.get_slice("=", 1)
		elif arg.begins_with("--dev-seed=") and not online:
			Session.seed_value = int(arg.get_slice("=", 1))
		elif arg == "--dev-hide-hud":
			_dev_hide_hud = true
		elif arg == "--dev-fast":
			Engine.time_scale = 8.0
		elif arg.begins_with("--dev-stop-at="):
			_dev_stop_kind = StringName(arg.get_slice("=", 1))
		elif arg.begins_with("--dev-ai") and not online:
			# `--dev-ai` or `--dev-ai=hard`: seat 1 is played by the AI.
			Session.ai_seat = 1
			if arg.contains("="):
				Session.ai_profile = arg.get_slice("=", 1)
		elif arg.begins_with("--dev-policy="):
			_dev_policy = arg.get_slice("=", 1)
		elif arg.begins_with("--dev-freeze="):
			_dev_freeze = StringName(arg.get_slice("=", 1))
		elif arg.begins_with("--dev-pick=") and not online:
			# Online the lobby already agreed on both decks and the seed.
			var picks: PackedStringArray = arg.get_slice("=", 1).split(",")
			if picks.size() == 2:
				Session.chosen = [Session.decks[int(picks[0])], Session.decks[int(picks[1])]]


# --- Turn flow ------------------------------------------------------------

func _present_prompt() -> void:
	if view == null:
		return
	if view.is_over():
		_clear_highlights()
		hud.refresh_state(view, viewer)
		hud.show_game_over("%s wins" % view.player(view.winner).name, _reason_text(view.win_reason))
		if _dev_autoplay:
			await _dev_finish()
		return
	if view.deciding != viewer:
		hud.refresh_state(view, viewer)
		_clear_highlights()
		if online:
			hud.set_hand(_hand_cards(), faces, {})
			hud.show_waiting(view.player(view.deciding).name, view.deciding_kind, view)
			_drain_inbox()
			return
		if ai != null and view.deciding == ai_seat:
			hud.set_hand(_hand_cards(), faces, {})
			hud.show_waiting(view.player(view.deciding).name, view.deciding_kind, view)
			await _ai_turn()
			return
		hud.show_handoff(view.player(view.deciding).name)
		if _dev_autoplay:
			await get_tree().create_timer(0.05).timeout
			_on_handoff_confirmed()
		return
	_show_prompt_for_viewer()
	if online:
		_drain_inbox()


## The AI seat's decision. The search runs on a worker thread so the table keeps drawing; the
## referee is not touched from here until it returns, because `busy` holds every other input.
func _ai_turn() -> void:
	busy = true
	var started: int = Time.get_ticks_msec()
	var answer: Array[Dictionary] = [{}]
	var task: int = WorkerThreadPool.add_task(func() -> void: answer[0] = ai.choose(referee, ai_seat))
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	var rest: float = AI_MIN_THINK - (Time.get_ticks_msec() - started) / 1000.0
	if rest > 0.0:
		await get_tree().create_timer(rest).timeout
	busy = false
	if answer[0].is_empty():
		push_warning("The AI had no answer for %s" % String(view.deciding_kind))
		return
	await _apply(ai_seat, answer[0])


## Hotseat: the next player sits down, so the table re-reads the state from their seat.
func _on_handoff_confirmed() -> void:
	hud.hide_handoff()
	viewer = view.deciding
	view = referee.view_for(viewer)
	prompt = referee.prompt_for(viewer)
	_adopt_cards()
	await _swing_camera(viewer)
	await _sync_layout(true)
	_show_prompt_for_viewer()


func _show_prompt_for_viewer() -> void:
	hud.refresh_state(view, viewer)
	var legal: Dictionary = _legal_uids()
	hud.set_hand(_hand_cards(), faces, legal)
	hud.show_prompt(prompt, view)
	_highlight(legal)
	# A decision about one card's effect keeps that card's face in the quick view for context.
	hud.hide_peek()
	var source: SeatCard = view.card(int(prompt.context.get("source", -1)))
	if source != null and not source.hidden():
		hud.show_peek(_def(source), source.aspect, source.uid)
	if _dev_autoplay:
		_dev_step()


## Cards a click acts on. A Final Strike is offered on every hand card but commits the rest of
## the Combat, so it is never a bare click; the HUD offers it through its own button.
func _legal_uids() -> Dictionary:
	var out: Dictionary = {}
	for o in prompt.options:
		if o.card >= 0 and o.type != &"final_strike":
			out[o.card] = true
	return out


func _hand_cards() -> Array[SeatCard]:
	var out: Array[SeatCard] = []
	for uid in view.player(viewer).hand:
		out.append(view.card(uid))
	return out


func _on_option_chosen(opt: OptionView) -> void:
	if busy or _awaiting_answer or prompt == null:
		return
	var wire: Dictionary = opt.to_command(viewer).to_dict()
	if online and not Net.is_host():
		_awaiting_answer = true
		hud.clear_prompt()
		hud.hide_inspect()
		_clear_highlights()
		hud.show_sending()
		Net.send_command(wire)
		return
	await _apply(view.deciding, wire)


## Dev panel: one effect for the viewer through the referee, then the table replays as usual.
func _on_dev_command(effect: Dictionary) -> void:
	if referee == null or busy or view == null:
		return
	var seat: int = viewer if viewer >= 0 else view.active
	var problem: String = referee.dev({"player": seat, "effect": effect})
	hud.dev_panel.report(problem)
	if problem != "":
		return
	busy = true
	hud.clear_prompt()
	hud.hide_inspect()
	_clear_highlights()
	var updates: Array[SeatUpdate] = referee.take_updates()
	if online:
		Net.send_update(updates[1].to_dict())
	await _play_update(updates[maxi(viewer, 0)])
	busy = false
	_present_prompt()


## Hotseat and host: run one command through the referee and show what came of it.
func _apply(seat: int, wire: Dictionary) -> void:
	busy = true
	hud.clear_prompt()
	hud.hide_inspect()
	_clear_highlights()
	var problem: String = referee.submit(seat, wire)
	if problem != "":
		if online and seat != viewer:
			Net.reject_command(problem)
		else:
			hud.log_line(problem)
		busy = false
		_present_prompt()
		return
	var updates: Array[SeatUpdate] = referee.take_updates()
	if online:
		Net.send_update(updates[1].to_dict())
	await _play_update(updates[maxi(viewer, 0)])
	busy = false
	if await _dev_count_update():
		return
	_present_prompt()


## Replays an update into the log and the table, then adopts its view and prompt. Each event
## line plays its own beat (a card in flight, a hit, a number) against the update's final
## layout; the sync at the end catches whatever the beats did not move.
func _play_update(up: SeatUpdate) -> void:
	view = up.view
	prompt = up.prompt
	await faces.render_missing(view, Session.library)
	_adopt_cards()
	zones.set_viewer(viewer if viewer >= 0 else view.active)
	var targets: Dictionary = _targets()
	for l in up.lines:
		var line: String = str(l.get("line", ""))
		if line != "":
			hud.log_line(line)
		if l.has("data"):
			_replaying = StringName(str(l.get("type", "")))
			await _replay(_replaying, int(l.get("player", -1)), l["data"], targets)
			_replaying = &""
	hud.refresh_state(view, viewer)
	_refresh_roles()
	await _sync_layout(true)


# --- Event beats ----------------------------------------------------------

## One animated event. `data` carries only the public fields the referee lists for its type.
func _replay(type: StringName, player: int, data: Dictionary, targets: Dictionary) -> void:
	match type:
		&"attack_declared":
			_wounds = 0
			await _sync_layout(true)   # the attack card rises to the Play slot before the swing
			_refresh_roles()
			var kind: String = str(data.get("kind", "strike"))
			var head: String = "Final Strike" if bool(data.get("is_final", false)) else ("Focused " if bool(data.get("focused", false)) else "") + ("Strike" if kind == "strike" else "Art")
			var src: SeatCard = view.card(int(data.get("source", -1)))
			if src != null and not src.hidden():
				head += ": " + src.title
			elif bool(data.get("is_power", false)):
				head += " from a Power"
			hud.toast(head, ZenithTheme.ATTACK)
			await _swing(player)
		&"defense_played", &"defense_power", &"shield":
			await _sync_layout(true)
			var defender: int = 1 - view.attacker
			fx.ring(_card_pos(view.player(defender).controlling), ZenithTheme.DEFEND)
			if type != &"defense_played":
				fx.float_text(_card_pos(int(data.get("card", -1))), "Shield", ZenithTheme.DEFEND, 48)
			await _beat(BEAT)
		&"attack_stopped":
			var defender: int = 1 - view.attacker
			fx.float_text(_card_pos(view.player(defender).controlling), "STOPPED", ZenithTheme.DEFEND, 72)
			hud.toast("Stopped", ZenithTheme.DEFEND)
			await _beat(TOAST_BEAT)
		&"modified_damage":
			var stages: int = int(data.get("stages", 0))
			var life: int = int(data.get("life", 0))
			hud.toast("Hits for %s" % CardText.short_damage(stages, life), ZenithTheme.ATTACK)
			await _beat(TOAST_BEAT)
		&"damage_stages":
			var stages: int = int(data.get("stages", 0))
			if stages <= 0:
				return
			var target: int = int(data.get("target", -1))
			var v: Card3D = views.get(target)
			var pos: Vector3 = _card_pos(target)
			fx.burst(pos, ZenithTheme.ATTACK)
			fx.float_text(pos, "-%d Energy" % stages, ZenithTheme.WARN, 80)
			if v != null:
				v.flash(ZenithTheme.ATTACK)
				await v.shake()
			_refresh_markers()
			await _beat(BEAT)
		&"life_card_flipped":
			_wounds += 1
			var uid: int = int(data.get("card", -1))
			await _fly(uid, targets)
			var pos: Vector3 = _card_pos(uid)
			fx.burst(pos, ZenithTheme.ATTACK, 14, 1.4)
			fx.float_text(pos, "Wound %d" % _wounds, ZenithTheme.ATTACK, 56)
			await _beat(BEAT)
		&"life_card_lost", &"final_strike", &"hand_discarded", &"in_play_discarded", &"card_moved", &"critical_ally":
			var uid: int = int(data.get("card", data.get("discarded", -1)))
			await _fly(uid, targets)
		&"card_used", &"card_placed":
			await _sync_layout(true)   # the card lands in play before its text does anything
		&"endurance_used":
			var defender: int = 1 - view.attacker
			var pos: Vector3 = _card_pos(view.player(defender).controlling)
			fx.ring(pos, ZenithTheme.DEFEND, 0.8)
			fx.float_text(pos, "Endurance %d" % int(data.get("prevented", 0)), ZenithTheme.DEFEND, 56)
			await _fly(int(data.get("card", -1)), targets)
		&"seal_bypassed":
			fx.float_text(_card_pos(int(data.get("card", -1))), "Seal stays", ZenithTheme.ACCENT, 48)
			await _beat(BEAT)
		&"seal_captured":
			var uid: int = int(data.get("card", -1))
			await _fly(uid, targets)
			var pos: Vector3 = _card_pos(uid)
			fx.ring(pos, ZenithTheme.ACCENT, 0.7)
			fx.burst(pos, ZenithTheme.ACCENT, 20, 1.6)
			hud.toast("Seal captured", ZenithTheme.ACCENT)
			await _beat(TOAST_BEAT)
		&"critical_fervor":
			hud.toast("Critical damage", ZenithTheme.WARN)
			await _beat(TOAST_BEAT)
		&"attack_end":
			var stages: int = int(data.get("stages_dealt", 0))
			var life: int = int(data.get("life_dealt", 0))
			if not bool(data.get("stopped", false)) and (stages > 0 or life > 0):
				hud.toast("Dealt %s" % CardText.short_damage(stages, life), ZenithTheme.ATTACK)
				await _beat(TOAST_BEAT)
			_wounds = 0
		&"combat_end":
			_refresh_roles()
		&"power_up", &"recover":
			var uid: int = view.player(player).duelist
			await _number(uid, "+%d Energy" % int(data.get("gain", 0)), ZenithTheme.ENERGY)
		&"energy_changed":
			var delta: int = int(data.get("to", 0)) - int(data.get("from", 0))
			if delta != 0:
				await _number(int(data.get("card", -1)), "%+d Energy" % delta, ZenithTheme.ENERGY if delta > 0 else ZenithTheme.WARN)
		&"fervor_changed":
			var delta: int = int(data.get("to", 0)) - int(data.get("from", 0))
			if delta != 0:
				await _number(view.player(player).duelist, "%+d Fervor" % delta, ZenithTheme.ACCENT if delta > 0 else ZenithTheme.WARN)
		&"fervor_shielded":
			fx.float_text(_card_pos(view.player(player).duelist), "Shielded", ZenithTheme.DEFEND, 48)
		&"aspect_up", &"aspect_down":
			var uid: int = view.player(player).duelist
			var pos: Vector3 = _card_pos(uid)
			var up: bool = type == &"aspect_up"
			fx.ring(pos, ZenithTheme.ACCENT if up else ZenithTheme.WARN, 1.3)
			fx.burst(pos, ZenithTheme.ACCENT if up else ZenithTheme.WARN, 36, 2.6)
			var v: Card3D = views.get(uid)
			if v != null:
				v.flash(ZenithTheme.ACCENT if up else ZenithTheme.WARN)
			hud.toast("%s %s to %s" % [view.player(player).name, "rises" if up else "falls", CardText.aspect_name(int(data.get("aspect", 1)), _duelist_def(player))], ZenithTheme.ACCENT if up else ZenithTheme.WARN)
			if v != null:
				await v.hop(0.2)
			await _beat(TOAST_BEAT)
		&"countered":
			var target: int = int(data.get("target", -1))
			fx.ring(_card_pos(target), ZenithTheme.DEFEND, 0.8)
			fx.float_text(_card_pos(target), "Countered", ZenithTheme.DEFEND, 48)
			await _beat(BEAT)


## The attacker's controlling card lunges at the defender's, with a streak between them and
## sparks where it lands.
func _swing(attacker: int) -> void:
	var v: Card3D = views.get(view.player(attacker).controlling)
	var target: Card3D = views.get(view.player(1 - attacker).controlling)
	if v == null or not v.visible or target == null:
		return
	var from: Vector3 = v.global_position
	var to: Vector3 = target.global_position
	var dir: Vector3 = to - from
	dir.y = 0.0
	v.lunge(dir)
	await get_tree().create_timer(Card3D.LUNGE_TIME * 0.8).timeout
	fx.slash(from + dir.normalized() * 0.3, to - dir.normalized() * 0.3, ZenithTheme.ATTACK)
	fx.burst(to, ZenithTheme.ATTACK, 18, 1.8)
	await _beat(Card3D.LUNGE_TIME * 1.2)


## A number over a card that just changed, with a hop and a flash in the same colour.
func _number(uid: int, text: String, color: Color) -> void:
	var v: Card3D = views.get(uid)
	if v == null or not v.visible:
		return
	fx.float_text(v.global_position, text, color, 60)
	v.flash(color)
	_refresh_markers()
	await v.hop()


## A card's arc from where it sits to its slot in the new layout, turning to its new facing on
## the way. Nothing happens for a card already there, or one this seat may not see land.
func _fly(uid: int, targets: Dictionary) -> void:
	var v: Card3D = views.get(uid)
	if v == null or not targets.has(uid):
		return
	var entry: Array = targets[uid]
	if not bool(entry[2]):
		return
	var slot_t: Transform3D = entry[0]
	var face_up: bool = bool(entry[1])
	var basis: Basis = slot_t.basis if face_up else slot_t.basis * Basis(Vector3.RIGHT, PI)
	var target: Transform3D = Transform3D(basis, slot_t.origin)
	v.face_up = face_up
	v.visible = true   # a card leaving this seat's hand starts from the hand slot it was kept at
	if v.transform.origin.distance_to(target.origin) < 0.0005 and v.transform.basis.is_equal_approx(target.basis):
		return
	var start: Transform3D = v.transform
	var mid: Transform3D = start.interpolate_with(target, 0.5)
	mid.origin.y += FLY_LIFT
	var t: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(v, "transform", mid, FLY_TIME * 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property(v, "transform", target, FLY_TIME * 0.5).set_ease(Tween.EASE_IN)
	await t.finished


## A pause between beats. `--dev-freeze=<event>` takes the screenshot here instead, with the
## event's effects still in the air.
func _beat(seconds: float) -> void:
	if _dev_freeze != &"" and _replaying == _dev_freeze and not _dev_done:
		await _dev_finish(0.03)
		return
	await get_tree().create_timer(seconds).timeout


func _card_pos(uid: int) -> Vector3:
	var v: Card3D = views.get(uid)
	if v == null or not v.visible:
		return Vector3.ZERO
	return v.global_position


## While an attack is in the air its two personalities carry their role glow (attacker red,
## defender blue); outside one, nothing does.
func _refresh_roles() -> void:
	var attacker: int = int(view.attack.get("attacker", -1)) if not view.attack.is_empty() else -1
	for p in view.players:
		var color: Color = Color(0, 0, 0, 0)
		if attacker >= 0:
			color = ZenithTheme.ATTACK if p.index == attacker else ZenithTheme.DEFEND
		var personalities: Array[int] = [p.duelist]
		personalities.append_array(p.allies)
		for uid in personalities:
			var v: Card3D = views.get(uid)
			if v != null:
				v.set_role(color if uid == p.controlling else Color(0, 0, 0, 0))


# --- Online ---------------------------------------------------------------

## Host: the joiner asks to apply a command.
func _on_net_command(d: Dictionary) -> void:
	_inbox.append(d)
	_drain_inbox()


## Joiner: the host sent what seat 1 may see now.
func _on_net_update(d: Dictionary) -> void:
	_inbox.append(d)
	_drain_inbox()


## Works through queued network traffic once the table is idle.
func _drain_inbox() -> void:
	if busy or _inbox.is_empty():
		return
	var d: Dictionary = _inbox.pop_front()
	if Net.is_host():
		await _apply(Net.remote_player(), d)
		return
	busy = true
	hud.clear_prompt()
	_clear_highlights()
	_awaiting_answer = false
	await _play_update(SeatUpdate.from_dict(d))
	busy = false
	if await _dev_count_update():
		return
	_present_prompt()


func _on_net_rejected(reason: String) -> void:
	_awaiting_answer = false
	hud.log_line("The host refused that choice: %s" % reason)
	if not busy:
		_present_prompt()


func _on_peer_left() -> void:
	if _dev_done:
		return
	busy = true
	hud.clear_prompt()
	var other: String = view.player(1 - viewer).name if view != null else "The other player"
	hud.show_game_over("%s left the duel" % other, "The connection closed.", false)


func _on_rematch() -> void:
	if online:
		Net.rematch()
	else:
		get_tree().reload_current_scene()


func _on_select() -> void:
	if online:
		if Net.is_host():
			Net.back_to_lobby()
		else:
			Net.leave()
			Session.go_to_title()
	else:
		Session.go_to_select()


# --- Cards ----------------------------------------------------------------

func _on_card_clicked(uid: int) -> void:
	if busy or _awaiting_answer or prompt == null:
		return
	var all: Array[OptionView] = prompt.options_for_card(uid)
	var opts: Array[OptionView] = []
	for o in all:
		if o.type != &"final_strike":
			opts.append(o)
	if opts.size() == 1:
		_on_option_chosen(opts[0])
	elif opts.size() > 1:
		hud.show_card_choice(opts)
	elif not all.is_empty():
		hud.show_card_choice(all)   # only a Final Strike: it needs a confirming click in the tray


func _on_card_hovered(uid: int, over: bool) -> void:
	if not over or view == null:
		hud.hide_peek()
		return
	var c: SeatCard = view.card(uid)
	if c == null or c.hidden():
		hud.hide_peek()
		return
	hud.show_peek(_def(c), c.aspect, uid)


func _on_card_inspected(uid: int) -> void:
	if view == null:
		return
	var c: SeatCard = view.card(uid)
	if c == null or c.hidden():
		return
	hud.show_inspect(_def(c), c.aspect, uid)


func _def(c: SeatCard) -> CardDef:
	return Session.library.defs.get(c.def_id)


## The duelist card of a seat, for its Aspect titles. Null while the view has no such card.
func _duelist_def(player: int) -> CardDef:
	var c: SeatCard = view.card(view.player(player).duelist)
	return _def(c) if c != null else null


## One Card3D per uid the view knows, with the face the view allows (a back for hidden cards).
func _adopt_cards() -> void:
	for uid in view.cards.keys():
		var c: SeatCard = view.card(uid)
		var v: Card3D = views.get(uid)
		if v == null:
			v = CARD_SCENE.instantiate()
			v.uid = uid
			v.visible = false
			cards_root.add_child(v)
			v.set_textures(null, faces.back())
			v.clicked.connect(_on_card_clicked)
			v.inspected.connect(_on_card_inspected)
			v.hovered.connect(_on_card_hovered)
			views[uid] = v
		if c.hidden():
			continue
		var def: CardDef = _def(c)
		if def == null:
			continue
		var key: String = CardFaceCache.key_for(def, c.aspect)
		if str(_face_keys.get(uid, "")) != key:
			v.set_face_texture(faces.face(def, c.aspect))
			_face_keys[uid] = key


## Every card's target slot for the current view. Cards not listed are hidden.
func _targets() -> Dictionary:
	var out: Dictionary = {}
	var vw: int = viewer if viewer >= 0 else view.active
	for p in view.players:
		var n: int = p.life_deck.size()
		for i in range(n):
			out[p.life_deck[i]] = [zones.slot(p.index, &"life_deck", n - 1 - i, 1, vw), false, true]
		for i in range(p.discard.size()):
			out[p.discard[i]] = [zones.slot(p.index, &"discard", i, 1, vw), true, true]
		for i in range(p.removed.size()):
			out[p.removed[i]] = [zones.slot(p.index, &"removed", i, 1, vw), true, true]
		var hn: int = p.hand.size()
		for i in range(hn):
			out[p.hand[i]] = [zones.slot(p.index, &"hand", i, hn, vw), false, p.index != viewer]
		for i in range(p.allies.size()):
			out[p.allies[i]] = [zones.slot(p.index, &"ally", i, p.allies.size(), vw), true, true]
		for i in range(p.drills.size()):
			out[p.drills[i]] = [zones.slot(p.index, &"drill", i, p.drills.size(), vw), true, true]
		for i in range(p.non_combats.size()):
			out[p.non_combats[i]] = [zones.slot(p.index, &"non_combat", i, p.non_combats.size(), vw), true, true]
		for i in range(p.seals.size()):
			out[p.seals[i]] = [zones.slot(p.index, &"seal", i, p.seals.size(), vw), true, true]
		out[p.duelist] = [zones.slot(p.index, &"duelist", 0, 1, vw), true, true]
		if p.mastery >= 0:
			out[p.mastery] = [zones.slot(p.index, &"mastery", 0, 1, vw), true, true]
		var pages_n: int = p.pages.size()
		if p.grimoire >= 0:
			out[p.grimoire] = [zones.slot(p.index, &"grimoire", 0, pages_n, vw), true, true]
		for i in range(pages_n):
			# Pages cards sit face down under the Grimoire; only their owner sees them in the prompt.
			out[p.pages[i]] = [zones.slot(p.index, &"grimoire", i + 1, pages_n, vw), false, true]
	if view.grounds >= 0:
		out[view.grounds] = [zones.slot(0, &"grounds", 0, 1, vw), true, true]
	for uid in view.resolving:
		if not out.has(uid):
			out[uid] = [zones.slot(view.card(uid).owner, &"resolving", 0, 1, vw), true, true]
	return out


## Energy marks on duelists and Allies in play, Fervor on the duelist.
func _refresh_markers() -> void:
	var wanted: Dictionary = {}   # uid -> [energy, SeatPlayer or null]
	for p in view.players:
		wanted[p.duelist] = [view.card(p.duelist).energy, p]
		for uid in p.allies:
			wanted[uid] = [view.card(uid).energy, null]
	for uid in _markers.keys():
		if not wanted.has(uid):
			(_markers[uid] as StatusMarkers).queue_free()
			_markers.erase(uid)
	for uid in wanted.keys():
		var v: Card3D = views.get(uid)
		if v == null:
			continue
		var m: StatusMarkers = _markers.get(uid)
		if m == null:
			m = StatusMarkers.new()
			v.body.add_child(m)
			m.setup(faces.ladder_rects())
			_markers[uid] = m
		m.set_status(int(wanted[uid][0]), wanted[uid][1] as SeatPlayer)


func _sync_layout(animated: bool) -> void:
	var targets: Dictionary = _targets()
	zones.set_viewer(viewer if viewer >= 0 else view.active)
	_refresh_markers()
	var tween: Tween = null
	var moved: bool = false
	for uid in views.keys():
		var v: Card3D = views[uid]
		if not targets.has(uid):
			v.visible = false
			continue
		var entry: Array = targets[uid]
		var slot_t: Transform3D = entry[0]
		var face_up: bool = entry[1]
		var visible: bool = entry[2]
		var basis: Basis = slot_t.basis if face_up else slot_t.basis * Basis(Vector3.RIGHT, PI)
		var target: Transform3D = Transform3D(basis, slot_t.origin)
		v.face_up = face_up
		if not visible:
			v.visible = false
			v.transform = target
			continue
		var was_visible: bool = v.visible
		v.visible = true
		if not was_visible or not animated:
			v.transform = target
			continue
		if v.transform.origin.distance_to(target.origin) < 0.0005 and v.transform.basis.is_equal_approx(target.basis):
			continue
		if tween == null:
			tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(v, "transform", target, SYNC_DURATION)
		moved = true
	if moved:
		await tween.finished


func _swing_camera(player: int) -> void:
	var target: float = 0.0 if player == 0 else PI
	camera.return_home()
	if is_equal_approx(rig.rotation.y, target):
		return
	var t: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(rig, "rotation:y", target, CAMERA_SWING)
	await t.finished


func _highlight(legal: Dictionary) -> void:
	for uid in views.keys():
		var v: Card3D = views[uid]
		v.set_highlight(legal.has(uid) and v.visible)


func _clear_highlights() -> void:
	for uid in views.keys():
		views[uid].set_highlight(false)


func _reason_text(reason: String) -> String:
	match reason:
		"ascension":
			return "Full Ascension. The site answers to its Eidolarch."
		"seal":
			return "All seven Seals carved. The gate opens for its Eidolarch."
		_:
			return "The rival's mind gives out."


# --- Dev driving ----------------------------------------------------------

func _dev_step() -> void:
	await get_tree().create_timer(0.05).timeout
	if prompt == null or busy or _awaiting_answer:
		return
	if _dev_stop_kind != &"" and _dev_stop_matches():
		for arg in OS.get_cmdline_user_args():
			# Open the inspect view so a face can be read at full size: the first hand card, or
			# `--dev-zoom=duelist` for the viewer's duelist, `--dev-zoom=rival` for the other one.
			if arg == "--dev-zoom" and not _hand_cards().is_empty():
				_on_card_inspected(_hand_cards()[0].uid)
			elif arg == "--dev-zoom=duelist":
				_on_card_inspected(view.player(viewer).duelist)
			elif arg == "--dev-zoom=rival":
				_on_card_inspected(view.player(1 - viewer).duelist)
			elif arg.begins_with("--dev-zoom="):
				# Any visible card by definition id, for face checks of cards not in hand.
				for c in view.visible_cards():
					if c.def_id == arg.get_slice("=", 1):
						_on_card_inspected(c.uid)
						break
			elif arg == "--dev-peek" and not _hand_cards().is_empty():
				_on_card_hovered(_hand_cards()[0].uid, true)
			elif arg == "--dev-peek=duelist":
				_on_card_hovered(view.player(viewer).duelist, true)
			elif arg == "--dev-log":
				hud.set_log_expanded(true)
			elif arg == "--dev-panel":
				hud.dev_panel.visible = true
		var click: String = ""
		for arg in OS.get_cmdline_user_args():
			if arg == "--dev-click" or arg.begins_with("--dev-click="):
				click = arg.get_slice("=", 1) if arg.contains("=") else "any"
		if click != "":
			# Open the sub-choice for the first card that has more than one legal action (with
			# `=final`, the first card whose only action is a Final Strike), or in a batch tray
			# pick the first two cards.
			await get_tree().create_timer(0.2).timeout
			if prompt.has_batch():
				var picks: int = 0
				for uid in prompt.card_uids().keys():
					hud.tray_toggle(uid)
					picks += 1
					if picks == 2:
						break
			# The same path a real click takes, on the first hand card that opens a tray.
			for c in _hand_cards():
				var direct: int = 0
				for o in prompt.options_for_card(c.uid):
					if o.type != &"final_strike":
						direct += 1
				var wanted: bool = direct == 0 if click == "final" else direct != 1
				if wanted and not prompt.options_for_card(c.uid).is_empty():
					_on_card_clicked(c.uid)
					break
		await _dev_finish()
		return
	if _dev_steps > 0 and not online:
		_dev_steps -= 1
		if _dev_steps == 0:
			await _dev_finish()
			return
	var opts: Array[OptionView] = prompt.options
	_on_option_chosen(_dev_pick(opts))


## Random by default. `--dev-policy=attack` declares Combat, attacks whenever it can, and never
## defends, so a short run shows damage and a fight back instead of a string of passes.
func _dev_pick(opts: Array[OptionView]) -> OptionView:
	if _dev_policy == "attack":
		for wanted in [&"attack", &"declare", &"no_defense"]:
			for o in opts:
				if o.type == wanted:
					return o
		for o in opts:
			if o.type != &"pass":
				return o
	return opts[randi_range(0, opts.size() - 1)]


## `--dev-stop-at=kind` or `kind:flag`, the latter only for prompts whose context sets that flag.
func _dev_stop_matches() -> bool:
	var kind: String = String(_dev_stop_kind).get_slice(":", 0)
	var flag: String = String(_dev_stop_kind).get_slice(":", 1) if String(_dev_stop_kind).contains(":") else ""
	return String(prompt.kind) == kind and (flag == "" or bool(prompt.context.get(flag, false)))


## Online the budget counts every update played here, so two clients started with the same
## budget stop on the same game state. Returns true when this update was the last.
func _dev_count_update() -> bool:
	if not (online and _dev_autoplay and _dev_steps > 0):
		return false
	_dev_steps -= 1
	if _dev_steps > 0:
		return false
	hud.set_hand(_hand_cards(), faces, {})
	await _dev_finish()
	return true


func _dev_finish(settle: float = 0.6) -> void:
	_dev_done = true
	if _dev_screenshot != "":
		if _dev_hide_hud:
			hud.visible = false
		var cam: PackedStringArray = _dev_camera.split(",")
		if cam.size() == 3:
			camera.dev_set(Vector2(float(cam[0]), float(cam[1])), int(cam[2]))
		await get_tree().create_timer(settle).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_dev_screenshot)
		print("screenshot saved to %s" % _dev_screenshot)
	get_tree().quit()
