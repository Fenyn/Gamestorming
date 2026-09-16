extends Node3D
## The playspace. Renders one seat's SeatView: a Card3D per uid the view lists, table tweens
## after every update, and every decision routed through the HUD prompt or a card click.
## Hotseat and hosting: a Referee lives here and the viewer's choices go straight to it.
## Hotseat: the camera swings to whichever player has to decide, behind a hand-off overlay.
## Online: the viewer is pinned to this client's seat. The host applies the joiner's commands
## through its Referee and sends seat 1 its update; the joiner holds no engine at all.

const CARD_SCENE: PackedScene = preload("res://scenes/duel/card_3d.tscn")
const SYNC_DURATION: float = 0.3
const CAMERA_SWING: float = 0.7
const LUNGE_DURATION: float = 0.18

@onready var rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera
@onready var zones: TableLayout = $Zones
@onready var cards_root: Node3D = $Cards
@onready var faces: CardFaceCache = $CardFaceCache
@onready var hud: DuelHud = $Hud

var referee: Referee = null          # hotseat and host only
var view: SeatView = null            # what the viewer may see right now
var prompt: PromptView = null        # the viewer's pending decision, null when it is not theirs
var views: Dictionary = {}           # uid -> Card3D
var viewer: int = -1
var busy: bool = false
var online: bool = false
var _face_keys: Dictionary = {}      # uid -> face cache key currently on the quad
var _inbox: Array[Dictionary] = []   # host: joiner commands; joiner: host updates; waiting for the table to settle
var _awaiting_answer: bool = false   # joiner: our choice went to the host, its update is not back yet
var _dev_autoplay: bool = false
var _dev_steps: int = 0
var _dev_screenshot: String = ""
var _dev_hide_hud: bool = false
var _dev_stop_kind: StringName = &""
var _dev_done: bool = false


func _ready() -> void:
	camera.look_at(Vector3(0, 0, 0.2))
	online = Net.active()
	_parse_dev_args()
	hud.option_chosen.connect(_on_option_chosen)
	hud.card_clicked.connect(_on_card_clicked)
	hud.card_hovered.connect(_on_card_hovered)
	hud.handoff_confirmed.connect(_on_handoff_confirmed)
	hud.rematch_requested.connect(_on_rematch)
	hud.select_requested.connect(_on_select)
	hud.set_loading(true)
	if online:
		viewer = Net.local_player
		rig.rotation.y = 0.0 if viewer == 0 else PI
		Net.command_rejected.connect(_on_net_rejected)
		Net.peer_left.connect(_on_peer_left)
		hud.set_online(Net.is_host())
	if not Session.can_start():
		push_warning("Duel opened without a selection; using the first two shipped decks")
		Session.chosen = [Session.decks[0], Session.decks[1 if Session.decks.size() > 1 else 0]]
	if online and not Net.is_host():
		await _ready_joiner()   # presents as soon as the host's first update lands
	else:
		await _ready_referee()
		_present_prompt()


## Hotseat and host: the rules run here.
func _ready_referee() -> void:
	referee = Session.build_referee()
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
		elif arg.begins_with("--dev-seed=") and not online:
			Session.seed_value = int(arg.get_slice("=", 1))
		elif arg == "--dev-hide-hud":
			_dev_hide_hud = true
		elif arg == "--dev-fast":
			Engine.time_scale = 8.0
		elif arg.begins_with("--dev-stop-at="):
			_dev_stop_kind = StringName(arg.get_slice("=", 1))
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
		hud.show_handoff(view.player(view.deciding).name)
		if _dev_autoplay:
			await get_tree().create_timer(0.05).timeout
			_on_handoff_confirmed()
		return
	_show_prompt_for_viewer()
	if online:
		_drain_inbox()


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
	var legal: Dictionary = prompt.card_uids()
	hud.set_hand(_hand_cards(), faces, legal)
	hud.show_prompt(prompt, view)
	_highlight(legal)
	if _dev_autoplay:
		_dev_step()


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
		hud.hide_zoom(true)
		_clear_highlights()
		hud.show_sending()
		Net.send_command(wire)
		return
	await _apply(view.deciding, wire)


## Hotseat and host: run one command through the referee and show what came of it.
func _apply(seat: int, wire: Dictionary) -> void:
	busy = true
	hud.clear_prompt()
	hud.hide_zoom(true)
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


## Replays an update into the log and the table, then adopts its view and prompt.
func _play_update(up: SeatUpdate) -> void:
	view = up.view
	prompt = up.prompt
	await faces.render_missing(view, Session.library)
	_adopt_cards()
	for l in up.lines:
		var line: String = str(l.get("line", ""))
		if line != "":
			hud.log_line(line)
		if str(l.get("type", "")) == "attack_declared":
			await _sync_layout(true)
			await _lunge(int(l.get("player", 0)))
	hud.refresh_state(view, viewer)
	await _sync_layout(true)


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
	var opts: Array[OptionView] = prompt.options_for_card(uid)
	if opts.size() == 1:
		_on_option_chosen(opts[0])
	elif opts.size() > 1:
		hud.show_card_choice(opts)


func _on_card_hovered(uid: int, over: bool) -> void:
	if not over or view == null:
		hud.hide_zoom()
		return
	var c: SeatCard = view.card(uid)
	# A hidden card has no face to zoom; the view never carried one.
	if c == null or c.hidden():
		hud.hide_zoom()
		return
	hud.show_zoom(_def(c), c.tier)


func _def(c: SeatCard) -> CardDef:
	return Session.library.defs.get(c.def_id)


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
			v.hovered.connect(_on_card_hovered)
			views[uid] = v
		if c.hidden():
			continue
		var def: CardDef = _def(c)
		if def == null:
			continue
		var key: String = CardFaceCache.key_for(def, c.tier)
		if str(_face_keys.get(uid, "")) != key:
			v.set_face_texture(faces.face(def, c.tier))
			_face_keys[uid] = key


func _lunge(attacker: int) -> void:
	var v: Card3D = views.get(view.player(attacker).controlling)
	if v == null or not v.visible:
		return
	var rest: Transform3D = v.transform
	var toward: Vector3 = (Vector3.ZERO - rest.origin).normalized() * 0.45 + Vector3(0, 0.15, 0)
	var t: Tween = create_tween()
	t.tween_property(v, "transform:origin", rest.origin + toward, LUNGE_DURATION).set_ease(Tween.EASE_OUT)
	t.tween_property(v, "transform:origin", rest.origin, LUNGE_DURATION).set_ease(Tween.EASE_IN)
	await t.finished


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
		for i in range(p.tokens.size()):
			out[p.tokens[i]] = [zones.slot(p.index, &"token", i, p.tokens.size(), vw), true, true]
		out[p.fighter] = [zones.slot(p.index, &"fighter", 0, 1, vw), true, true]
		if p.mastery >= 0:
			out[p.mastery] = [zones.slot(p.index, &"mastery", 0, 1, vw), true, true]
		var armory_n: int = p.armory.size()
		if p.master >= 0:
			out[p.master] = [zones.slot(p.index, &"master", 0, armory_n, vw), true, true]
		for i in range(armory_n):
			# Armory cards sit face down under the Master; only their owner sees them in the prompt.
			out[p.armory[i]] = [zones.slot(p.index, &"master", i + 1, armory_n, vw), false, true]
	if view.grounds >= 0:
		out[view.grounds] = [zones.slot(0, &"grounds", 0, 1, vw), true, true]
	for uid in view.resolving:
		if not out.has(uid):
			out[uid] = [zones.slot(view.card(uid).owner, &"resolving", 0, 1, vw), true, true]
	return out


func _sync_layout(animated: bool) -> void:
	var targets: Dictionary = _targets()
	zones.set_viewer(viewer if viewer >= 0 else view.active)
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
		"favor":
			return "The king's Favor, at its peak, ends the duel."
		"token":
			return "All seven Royal Tokens held. The king crowns the victor."
		_:
			return "The rival can fight no more."


# --- Dev driving ----------------------------------------------------------

func _dev_step() -> void:
	await get_tree().create_timer(0.05).timeout
	if prompt == null or busy or _awaiting_answer:
		return
	if _dev_stop_kind != &"" and prompt.kind == _dev_stop_kind:
		for arg in OS.get_cmdline_user_args():
			# Open the hover zoom so a face can be read at full size: the first hand card, or
			# `--dev-zoom=fighter` for the viewer's fighter.
			if arg == "--dev-zoom" and not _hand_cards().is_empty():
				_on_card_hovered(_hand_cards()[0].uid, true)
			elif arg == "--dev-zoom=fighter":
				_on_card_hovered(view.player(viewer).fighter, true)
		if OS.get_cmdline_user_args().has("--dev-click"):
			# Open the sub-choice for the first card that has more than one legal action, or in a
			# batch tray pick the first two cards.
			await get_tree().create_timer(0.2).timeout
			if prompt.has_batch():
				var picks: int = 0
				for uid in prompt.card_uids().keys():
					hud.tray_toggle(uid)
					picks += 1
					if picks == 2:
						break
			for uid in prompt.card_uids().keys():
				if prompt.options_for_card(uid).size() > 1:
					hud.show_card_choice(prompt.options_for_card(uid))
					break
		await _dev_finish()
		return
	if _dev_steps > 0 and not online:
		_dev_steps -= 1
		if _dev_steps == 0:
			await _dev_finish()
			return
	var opts: Array[OptionView] = prompt.options
	_on_option_chosen(opts[randi_range(0, opts.size() - 1)])


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


func _dev_finish() -> void:
	_dev_done = true
	if _dev_screenshot != "":
		if _dev_hide_hud:
			hud.visible = false
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_dev_screenshot)
		print("screenshot saved to %s" % _dev_screenshot)
	get_tree().quit()
