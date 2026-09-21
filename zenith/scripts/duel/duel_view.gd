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
const LIFE_FLY_POP: float = 0.10
const LIFE_FLY_REVEAL: float = 0.18
const LIFE_FLY_SETTLE: float = 0.22
const BEAT: float = 0.22              # pause after a hit or a flipped card, so each one reads
const TOAST_BEAT: float = 0.35
const SPOTLIGHT_BEAT: float = 0.45    # hold on the card whose effect is about to resolve
const OPPONENT_USE_READ: float = 1.8
const OPPONENT_DEFENSE_READ: float = 2.2
const OPPONENT_STOP_READ: float = 3.2
const DRAW_BEAT: float = 0.10         # between cards of the same draw, so they arrive one by one
const WOUND_BEAT: float = 0.5         # between life cards, long enough to read what each one cost
const AI_MIN_THINK: float = 0.45      # seconds the AI appears to think, so its plays do not snap
const STALL_MS: int = 1200            # a hidden decision panel this long is a stall, not a beat
const ATTACH_OFFSET: Vector3 = Vector3(0.30, 0.004, -0.22)   # a corner of the attachment peeks past its host
const ATTACH_SCALE: float = 0.78
const RAIL_DEPTH: float = 3.2         # camera distance the backline cards are pinned at
const RAIL_STACK_PX: float = 0.7      # a pile's cards fan by this much so a stack reads as one

@onready var rig: Node3D = $CameraRig
@onready var camera: TableCamera = $CameraRig/Camera
@onready var zones: TableLayout = $Zones
@onready var cards_root: Node3D = $Cards
@onready var fx: DuelFx = $Fx
@onready var faces: CardFaceCache = $CardFaceCache
@onready var hud: DuelHud = $Hud
@onready var hand_3d: Hand3D = $CameraRig/Camera/Hand3D
@onready var near_duelist: DuelistDisplay = $NearDuelist
@onready var far_duelist: DuelistDisplay = $FarDuelist
@onready var focus_card: Sprite3D = $CameraRig/Camera/FocusCard

var duel_host: DuelHost = null       # the rules, where they run here (hotseat, hosting)
var view: SeatView = null            # what the viewer may see right now
var prompt: PromptView = null        # the viewer's pending decision, null when it is not theirs
var views: Dictionary = {}           # uid -> Card3D
var _markers: Dictionary = {}        # uid -> StatusMarkers on personalities in play
var viewer: int = -1
var busy: bool = false
var online: bool = false
var authority: bool = true           # the rules run in this process
var ai_seat: int = -1
var _face_keys: Dictionary = {}      # uid -> face cache key currently on the quad
var _inbox: Array[Dictionary] = []   # host: joiner commands; joiner: host updates; waiting for the table to settle
var _awaiting_answer: bool = false   # joiner: our choice went to the host, its update is not back yet
var _draining_inbox: bool = false
var _dev_autoplay: bool = false
var _dev_steps: int = 0
var _dev_screenshot: String = ""
var _dev_hide_hud: bool = false
var _dev_stop_kind: StringName = &""
var _dev_camera: String = ""         # "dx,dz,notches": pan and zoom before the screenshot
var _dev_policy: String = ""         # "attack": autoplay fights instead of picking at random
var _dev_freeze: StringName = &""    # event type whose beat the screenshot catches mid-air
var _dev_done: bool = false
var _dev_quit_after_replay: bool = false
var _wounds: int = 0                 # life cards flipped by the attack being replayed
var _replaying: StringName = &""     # the event whose beat is playing now
## The table numbers as they stood at the beat now playing (`GameEvent.state`). While it holds
## something, the markers and the player panels read it instead of the update's final view, so a
## card that charges up and is drained again in the same update reads as two beats, not one jump.
var _live: Dictionary = {}
var _attack_cue: Dictionary = {}   # public attack currently replaying, never the future update outcome
var _focus_key: String = ""
var _replay_focus_def: CardDef = null
var _reduced_motion: bool = false
var _stall_since: int = 0            # when the viewer was first owed a decision with no panel up


func _ready() -> void:
	online = Net.active()
	authority = not online or Net.is_authority()
	_parse_dev_args()
	hud.external_hand = true
	hud.scene_flags = true
	hud.reduced_motion_changed.connect(_set_reduced_motion)
	hud.focus_face.visible = false
	hand_3d.clicked.connect(_on_card_clicked)
	hand_3d.inspected.connect(_on_card_inspected)
	hand_3d.hovered.connect(_on_hand_hovered)
	for fixture in [near_duelist, far_duelist]:
		fixture.clicked.connect(_on_card_clicked)
		fixture.inspected.connect(_on_card_inspected)
		fixture.hovered.connect(_on_card_hovered)
	_set_reduced_motion(OS.get_cmdline_user_args().has("--reduced-motion"))
	hud.option_chosen.connect(_on_option_chosen)
	hud.card_clicked.connect(_on_card_clicked)
	hud.handoff_confirmed.connect(_on_handoff_confirmed)
	hud.rematch_requested.connect(_on_rematch)
	hud.select_requested.connect(_on_select)
	hud.dev_command.connect(_on_dev_command)
	hud.pile_opened.connect(_on_pile_clicked)
	hud.set_loading(true)
	if online:
		viewer = Net.local_player
		rig.rotation.y = 0.0 if viewer == 0 else PI
		Net.command_rejected.connect(_on_net_rejected)
		Net.peer_left.connect(_on_peer_left)
		hud.set_online(authority)
	elif Session.ai_seat >= 0:
		ai_seat = Session.ai_seat
		viewer = 1 - ai_seat
		rig.rotation.y = 0.0 if viewer == 0 else PI
	if Session.in_adventure():
		hud.set_adventure()
	if not Session.can_start():
		push_warning("Duel opened without a selection; using the first two shipped decks")
		Session.chosen = [Session.decks[0], Session.decks[1 if Session.decks.size() > 1 else 0]]
	hud.set_dev_available(OS.is_debug_build() and authority)
	if authority:
		await _ready_host()
		_present_prompt()
	else:
		await _ready_joiner()   # presents as soon as the authority's first update lands


func _set_reduced_motion(on: bool) -> void:
	_reduced_motion = on
	fx.reduced_motion = on
	hand_3d.reduced_motion = on
	near_duelist.reduced_motion = on
	far_duelist.reduced_motion = on
	hud.reduced_motion_toggle.set_pressed_no_signal(on)
	for card in views.values():
		(card as Card3D).reduced_motion = on


func _process(_delta: float) -> void:
	if not is_instance_valid(hud):
		return
	var overlay: bool = hud.tray.visible or hud.pile.visible or hud.inspect.visible or hud.handoff.visible or hud.loading.visible or hud.game_over.visible
	hand_3d.set_available(view != null and viewer >= 0 and not overlay)
	hand_3d.enabled = _can_choose()
	camera.hand_navigation = hand_3d.keyboard_active or overlay
	var hand_blocks: bool = _hand_blocks_board()
	var preview_blocks: bool = _preview_blocks_point(hud.root.get_global_mouse_position())
	var board_interactive: bool = not overlay and not hand_blocks and not preview_blocks
	near_duelist.interactive = board_interactive
	far_duelist.interactive = board_interactive
	for value in views.values():
		var board_card: Card3D = value
		if board_card.pick.input_ray_pickable != board_interactive:
			board_card.pick.input_ray_pickable = board_interactive
		if not board_interactive and board_card._hovering:
			board_card.set_hovered(false)
	if hand_blocks or preview_blocks:
		hud.hide_peek()
	_watch_for_stall(overlay)
	_layout_fixtures()
	focus_card.visible = hud.focus.visible and not overlay
	if focus_card.visible and view != null:
		var shown_def: CardDef = _replay_focus_def
		var aspect: int = 1
		if shown_def == null:
			var card: SeatCard = view.card(hud._focus_uid(prompt))
			if card != null and not card.hidden():
				shown_def = _def(card)
				aspect = card.aspect
		if shown_def != null:
			var key: String = CardFaceCache.key_for(shown_def, aspect)
			if _focus_key != key:
				focus_card.texture = faces.face(shown_def, aspect)
				_focus_key = key
		else:
			focus_card.visible = false


## Safety net, not a mechanism. The table runs on awaits, and a decision panel that never comes
## back reads as a softlock: the viewer owes a move and there is nothing on screen to make it
## with. Nothing should reach this, so it says so and puts the prompt back rather than leaving
## the duel stuck.
func _watch_for_stall(overlay: bool) -> void:
	var owed: bool = view != null and not view.is_over() and prompt != null and viewer >= 0 		and view.deciding == viewer and prompt.player == viewer
	if not owed or busy or _awaiting_answer or overlay or _dev_done or hud.prompt_panel.visible:
		_stall_since = 0
		return
	if _stall_since == 0:
		_stall_since = Time.get_ticks_msec()
		return
	if Time.get_ticks_msec() - _stall_since < STALL_MS:
		return
	_stall_since = 0
	push_warning("Decision panel was missing for a %s prompt; showing it again" % String(prompt.kind))
	_show_prompt_for_viewer()


## Resource fixtures follow the actual field cards, with a clear opening over each face.
func _layout_fixtures() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var depth: float = 3.0
	var units: float = camera.project_position(Vector2(1, 0), depth).distance_to(camera.project_position(Vector2.ZERO, depth))
	var width: float = minf(460.0, size.x * 0.275)
	for fixture: DuelistDisplay in [near_duelist, far_duelist]:
		var card: Card3D = views.get(fixture.duelist_uid)
		fixture.visible = card != null and card.visible and not camera.is_position_behind(card.global_position)
		if not fixture.visible:
			continue
		fixture.global_position = card.global_position
		var card_depth: float = -camera.to_local(card.global_position).z
		var card_units: float = camera.project_position(Vector2(1, 0), card_depth).distance_to(camera.project_position(Vector2.ZERO, card_depth))
		fixture.surface.pixel_size = width / 760.0 * card_units
		var owner: int = view.card(fixture.duelist_uid).owner
		var count: int = view.player(owner).life_deck.size()
		fixture.life_transform = zones.global_transform * zones.slot(owner, &"life_deck", maxi(0, count - 1), count, viewer)
		fixture.anchor_to_card(card, camera)
	if viewer >= 0 and near_duelist.visible:
		var near_card: Card3D = views.get(near_duelist.duelist_uid)
		var life_x: float = camera.unproject_position(near_duelist.life_transform.origin).x
		var fighter_screen: Vector2 = camera.unproject_position(near_card.global_position)
		var pixel_scale: float = near_duelist.surface.pixel_size * near_duelist.global_basis.get_scale().x
		var scale_pixels: float = fighter_screen.distance_to(camera.unproject_position(near_card.global_position + camera.global_basis.x * pixel_scale))
		near_duelist.readout.update_layout()
		var hero_bottom: float = fighter_screen.y
		for hit_rect: Rect2 in near_duelist.readout.stat_hit_rects:
			hero_bottom = maxf(hero_bottom, fighter_screen.y + hit_rect.end.y * scale_pixels)
		hand_3d.set_hero_bounds(life_x - size.x * 0.035, fighter_screen.x + size.x * 0.09, hero_bottom)
	var decision_rect: Rect2 = Rect2()
	if hud.prompt_panel.visible:
		decision_rect = hud.prompt_panel.get_global_rect()
	if hud.focus.visible:
		decision_rect = decision_rect.merge(hud.focus.get_global_rect()) if decision_rect.has_area() else hud.focus.get_global_rect()
	hand_3d.set_decision_rect(decision_rect)
	if not hud.focus.visible:
		return
	var focus_rect: Rect2 = hud.focus.get_global_rect()
	var focus_width: float = focus_rect.size.x
	focus_card.position = camera.to_local(camera.project_position(Vector2(focus_rect.get_center().x, focus_rect.position.y + 32.0 + focus_width * 716.0 / 512.0 * 0.5), depth))
	focus_card.pixel_size = focus_width / 512.0 * units


func _refresh_displays() -> void:
	if view == null:
		return
	var me: int = viewer if viewer >= 0 else (view.deciding if view.deciding >= 0 else view.active)
	near_duelist.refresh(view, me, me, _live)
	far_duelist.refresh(view, 1 - me, me, _live)
	# Status exceptions are already part of the fixtures; keep HUD copies for inspection only.
	hud.near_flags.hide()
	hud.far_flags.hide()


func _set_hand(legal: Dictionary) -> void:
	var cards: Array[SeatCard] = _hand_cards()
	hud.set_hand(cards, faces, legal)
	hand_3d.set_hand(cards, faces, legal, view, prompt)


func _on_hand_hovered(uid: int, on: bool) -> void:
	if on:
		hud.hide_peek()
	hud.preview_hand_card(uid, on)
	var forecast: Dictionary = view.forecast(uid) if on and view != null else {}
	near_duelist.preview_energy(int(forecast.get("cost_stages", 0)))


## Hotseat and hosting: the rules run here, behind a DuelHost that also serves the remote seat.
func _ready_host() -> void:
	duel_host = DuelHost.new()
	duel_host.setup(Session.build_referee(), Net.remote_seats(), Session.build_ai() if not online else null, Session.ai_seat)
	duel_host.send = Net.send_update
	duel_host.reject = Net.reject_command
	for d in Session.chosen:
		await faces.render_deck(d, Session.library)
	hud.set_loading(false)
	hud.log_line("Seed %d" % Session.last_seed)
	if online:
		hud.log_line("Online duel. You are hosting as %s." % Session.player_names[viewer])
		Net.command_received.connect(_on_net_command)
	var updates: Array[SeatUpdate] = duel_host.start()
	await _play_update(updates[maxi(viewer, 0)])


## A client of a host or server: nothing but views. Faces for the other seat's deck render as
## cards appear.
func _ready_joiner() -> void:
	await faces.render_deck(Session.chosen[viewer], Session.library)
	await faces.render_deck(Session.chosen[1 - viewer], Session.library, true)
	hud.set_loading(false)
	hud.log_line("Online duel. You are %s." % Session.player_names[viewer])
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
		elif arg.begins_with("--dev-seed=") and not online and not Session.in_adventure():
			Session.seed_value = int(arg.get_slice("=", 1))
		elif arg == "--dev-hide-hud":
			_dev_hide_hud = true
		elif arg == "--dev-fast":
			Engine.time_scale = 8.0
		elif arg.begins_with("--dev-stop-at="):
			_dev_stop_kind = StringName(arg.get_slice("=", 1))
		elif arg.begins_with("--dev-ai") and not online and not Session.in_adventure():
			# `--dev-ai` or `--dev-ai=hard`: seat 1 is played by the AI.
			Session.ai_seat = 1
			if arg.contains("="):
				Session.ai_profile = arg.get_slice("=", 1)
		elif arg.begins_with("--dev-policy="):
			_dev_policy = arg.get_slice("=", 1)
		elif arg.begins_with("--dev-freeze="):
			_dev_freeze = StringName(arg.get_slice("=", 1))
		elif arg.begins_with("--dev-pick=") and not online and not Session.in_adventure():
			# Online the lobby already agreed on both decks and the seed.
			var picks: PackedStringArray = arg.get_slice("=", 1).split(",")
			if picks.size() == 2:
				Session.chosen = [Session.decks[int(picks[0])], Session.decks[int(picks[1])]]


# --- Turn flow ------------------------------------------------------------

func _present_prompt() -> void:
	if _dev_done or view == null:
		return
	if view.is_over():
		_clear_highlights()
		hud.refresh_state(view, viewer)
		hud.show_game_over("%s wins" % view.player(view.winner).name, _reason_text(view.win_reason), not Session.in_adventure())
		if _dev_autoplay:
			if Session.in_adventure():
				Session.record_stage(view.winner == viewer)
				print("adventure stage result: %s, status=%s" % ["won" if view.winner == viewer else "lost", Session.run.status])
			await _dev_finish()
		return
	if view.deciding != viewer:
		hud.refresh_state(view, viewer)
		_clear_highlights()
		if online:
			_set_hand({})
			hud.show_waiting(view.player(view.deciding).name, view.deciding_kind, view)
			_drain_inbox()
			return
		if duel_host.ai != null and view.deciding == ai_seat:
			_set_hand({})
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
## host is not mutated from here until it returns. Browsing uses the client's public view.
func _ai_turn() -> void:
	busy = true
	var started: int = Time.get_ticks_msec()
	var answer: Array[Dictionary] = [{}]
	var task: int = WorkerThreadPool.add_task(func() -> void: answer[0] = duel_host.ai_choice())
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	var rest: float = AI_MIN_THINK - (Time.get_ticks_msec() - started) / 1000.0
	if rest > 0.0:
		await get_tree().create_timer(rest).timeout
	busy = false
	if answer[0].is_empty():
		# The host answers for a stuck AI, so an empty answer here means the decision moved on
		# while we were thinking. Present whatever is pending now instead of standing still.
		push_warning("The AI had no answer for %s" % String(view.deciding_kind))
		_present_prompt()
		return
	await _apply(ai_seat, answer[0])


## Hotseat: the next player sits down, so the table re-reads the state from their seat.
func _on_handoff_confirmed() -> void:
	busy = true
	viewer = view.deciding
	view = duel_host.view_for(viewer)
	prompt = duel_host.prompt_for(viewer)
	# Replace private textures before uncovering the new seat, including during camera motion.
	_set_hand({})
	hud.hide_handoff()
	_adopt_cards()
	await _swing_camera(viewer)
	await _sync_layout(true)
	busy = false
	_show_prompt_for_viewer()


func _show_prompt_for_viewer() -> void:
	hud.refresh_state(view, viewer)
	var legal: Dictionary = _legal_uids()
	_set_hand(legal)
	hud.show_prompt(prompt, view)
	_highlight(legal)
	# The card the decision is about is held in the middle of the screen by the HUD's focus
	# view, so the quick view on the left stays free for whatever the player hovers.
	hud.hide_peek()
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


func _can_choose() -> bool:
	return not busy and not _awaiting_answer and view != null and not view.is_over() \
		and prompt != null and viewer >= 0 and view.deciding == viewer and prompt.player == viewer


func _on_option_chosen(opt: OptionView) -> void:
	if not _can_choose():
		return
	var wire: Dictionary = opt.to_command(viewer).to_dict()
	if not authority:
		_awaiting_answer = true
		hud.clear_prompt()
		hud.hide_inspect()
		_clear_highlights()
		hud.show_sending()
		Net.send_command(wire)
		return
	await _apply(view.deciding, wire)


## Dev panel: one effect for the viewer through the host, then the table replays as usual.
func _on_dev_command(effect: Dictionary) -> void:
	if duel_host == null or busy or view == null:
		return
	var seat: int = viewer if viewer >= 0 else view.active
	var result: Dictionary = duel_host.dev(seat, effect)
	var problem: String = str(result["problem"])
	hud.dev_panel.report(problem)
	if problem != "":
		return
	busy = true
	hud.clear_prompt()
	hud.hide_inspect()
	_clear_highlights()
	var updates: Array[SeatUpdate] = result["updates"]
	await _play_update(updates[maxi(viewer, 0)])
	busy = false
	_present_prompt()


## Hotseat and hosting: run one command through the host and show what came of it. A remote
## seat's refusal goes back to it from the host; a local one lands in the log.
func _apply(seat: int, wire: Dictionary) -> void:
	busy = true
	hud.clear_prompt()
	if seat == viewer:
		hud.hide_inspect()
	_clear_highlights()
	var result: Dictionary = duel_host.apply(seat, wire)
	var problem: String = str(result["problem"])
	if problem != "":
		if not duel_host.is_remote(seat):
			hud.log_line(problem)
		busy = false
		_present_prompt()
		return
	var updates: Array[SeatUpdate] = result["updates"]
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
			# The beat draws the table as it stood when the event fired, not as it stands now.
			_live = l.get("state", {})
			hud.refresh_state(view, viewer, _live)
			_refresh_displays()
			await _replay(_replaying, int(l.get("player", -1)), l["data"], targets)
			_replaying = &""
	_live = {}
	_attack_cue = view.attack.duplicate(true)
	hud.refresh_state(view, viewer)
	_refresh_displays()
	_refresh_roles()
	await _sync_layout(true)
	if _dev_quit_after_replay:
		_dev_shutdown()


# --- Event beats ----------------------------------------------------------

## One animated event. `data` carries only the public fields the referee lists for its type.
func _replay(type: StringName, player: int, data: Dictionary, targets: Dictionary) -> void:
	# A card leaving the hand should not remain as a second copy during its board animation.
	var leaving: int = int(data.get("card", data.get("source", data.get("discarded", -1))))
	if viewer >= 0 and leaving >= 0 and not view.player(viewer).hand.has(leaving):
		var pose: Variant = hand_3d.world_card_transform(leaving)
		var moving: Card3D = views.get(leaving)
		if pose is Transform3D and moving != null:
			moving.global_transform = pose
			moving.visible = true
		hand_3d.remove_uid(leaving)
	match type:
		&"attack_declared":
			_wounds = 0
			_attack_cue = {"attacker": player, "defender": 1 - player,
				"source": int(data.get("source", -1)), "performer": _controlling_uid(player),
				"target": _controlling_uid(1 - player)}
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
			var defense_uid: int = int(data.get("card", -1))
			if viewer >= 0 and player != viewer:
				var stopped: bool = bool(data.get("stopped", false))
				var caption: String = "YOUR ATTACK STOPPED" if stopped else "OPPONENT DEFENSE"
				if type == &"defense_power":
					caption = "OPPONENT DEFENSE POWER"
				elif type == &"shield":
					caption = "OPPONENT SHIELD"
				await _opponent_card_beat(defense_uid, player, targets, caption, OPPONENT_STOP_READ if stopped else OPPONENT_DEFENSE_READ, ZenithTheme.DEFEND, str(data.get("id", "")))
			else:
				await _sync_layout(true)
			var defender: int = 1 - int(_live.get("attacker", view.attacker))
			fx.ward(_card_pos(_controlling_uid(defender)), ZenithTheme.DEFEND)
			if type != &"defense_played":
				fx.float_text(_card_pos(int(data.get("card", -1))), "Shield", ZenithTheme.DEFEND, 48)
			await _beat(BEAT)
		&"remain":
			# The card stays on the table instead of going to the discard pile. Without a beat it
			# would slide into the Remain row during the closing sync with nothing said about it.
			await _sync_layout(true)
			var uses: int = int(data.get("uses", 1))
			fx.float_text(_card_pos(int(data.get("card", -1))), "Remain %d" % uses, ZenithTheme.ACCENT, 48)
			await _beat(BEAT)
		&"attack_stopped":
			_attack_cue["stopped"] = true
			_refresh_attack_link()
			var defender: int = 1 - int(_live.get("attacker", view.attacker))
			fx.ward(_card_pos(_controlling_uid(defender)), ZenithTheme.DEFEND)
			fx.float_text(_card_pos(_controlling_uid(defender)), "STOPPED", ZenithTheme.DEFEND, 72)
			hud.toast("Stopped", ZenithTheme.DEFEND)
			await _beat(TOAST_BEAT)
		&"modified_damage":
			var stages: int = int(data.get("stages", 0))
			var life: int = int(data.get("life", 0))
			hud.toast("Hits for %s" % CardText.short_damage(stages, life), ZenithTheme.ATTACK)
			await _beat(TOAST_BEAT)
		&"damage_stages":
			var stages: int = int(data.get("stages", 0))
			var target: int = int(data.get("target", -1))
			_attack_cue["target"] = target
			_attack_cue["landed"] = true
			_refresh_attack_link()
			if stages <= 0:
				return
			var v: Card3D = views.get(target)
			var pos: Vector3 = _card_pos(target)
			fx.impact(pos, ZenithTheme.ATTACK, 1.0)
			fx.float_text(pos, "-%d Energy" % stages, ZenithTheme.WARN, 80)
			if v != null:
				v.flash(ZenithTheme.ATTACK)
				await v.shake()
			_refresh_markers()
			await _beat(BEAT)
		&"life_card_flipped":
			_wounds += 1
			_attack_cue["landed"] = true
			_refresh_attack_link()
			var uid: int = int(data.get("card", -1))
			await _fly_life_loss(uid, player, targets, "Wound %d" % _wounds)
			var v: Card3D = views.get(uid)
			if v != null:
				v.flash(ZenithTheme.ATTACK)
			# Wounds come in runs, so each one names the card it cost and holds long enough to
			# read before the next lands.
			var lost: SeatCard = view.card(uid)
			var title: String = lost.title if lost != null and not lost.hidden() else "a card"
			hud.toast("Wound %d  ·  %s" % [_wounds, title], ZenithTheme.ATTACK)
			await _beat(WOUND_BEAT)
		&"life_card_lost":
			await _fly_life_loss(int(data.get("card", -1)), player, targets, "-1 Life")
		&"final_strike", &"hand_discarded", &"in_play_discarded", &"card_moved", &"critical_ally":
			var uid: int = int(data.get("card", data.get("discarded", -1)))
			await _fly(uid, targets)
		&"card_used", &"card_placed":
			var used_uid: int = int(data.get("card", -1))
			if type == &"card_used" and viewer >= 0 and player != viewer:
				await _opponent_card_beat(used_uid, player, targets, "OPPONENT PLAYS", OPPONENT_USE_READ, ZenithTheme.ACCENT, str(data.get("id", "")))
			else:
				await _sync_layout(true)   # the card lands in play before its text does anything
				await _spotlight(used_uid)
		&"endurance_used":
			var defender: int = 1 - int(_live.get("attacker", view.attacker))
			var pos: Vector3 = _card_pos(_controlling_uid(defender))
			fx.ward(pos, ZenithTheme.DEFEND, 0.8)
			fx.float_text(pos, "Endurance %d" % int(data.get("prevented", 0)), ZenithTheme.DEFEND, 56)
			var card_uid: int = int(data.get("card", -1))
			var used: SeatCard = view.card(card_uid)
			var used_title: String = used.title if used != null and not used.hidden() else "the wound"
			hud.toast("Endurance %d  ·  %s" % [int(data.get("prevented", 0)), used_title], ZenithTheme.DEFEND)
			await _fly(card_uid, targets)
			await _beat(TOAST_BEAT)
		&"endurance_declined":
			# The other side watched the choice being offered, so it sees the answer too.
			var uid: int = int(data.get("card", -1))
			var pos: Vector3 = _card_pos(uid)
			fx.float_text(pos, "Endurance declined", ZenithTheme.MUTED, 48)
			hud.toast("Endurance declined  ·  %d to come" % int(data.get("remaining", 0)), ZenithTheme.MUTED)
			await _beat(TOAST_BEAT)
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
			_attack_cue.clear()
			fx.clear_attack_link()
		&"combat_end":
			_attack_cue.clear()
			fx.clear_attack_link()
			_refresh_roles()
		&"trigger_fired":
			# The card doing the work holds the table for a moment before its effects land, the
			# way MTG Arena stops on a trigger. Everything after this beat is that card's doing.
			await _spotlight(int(data.get("card", -1)))
		&"draw":
			var uid: int = int(data.get("card", -1))
			if player == viewer and view.player(viewer).hand.has(uid):
				var origin: Vector3 = zones.slot(viewer, &"life_deck").origin
				hand_3d.receive_card(view.card(uid), faces, view, zones.to_global(origin))
			else:
				await _fly(uid, targets)
			await _beat(DRAW_BEAT)
		&"recover":
			# A card coming back from the discard pile to the Life Deck, not an Energy gain.
			await _fly(int(data.get("card", -1)), targets)
			await _beat(DRAW_BEAT)
		&"power_up":
			var uid: int = view.player(player).duelist
			var gain: int = int(data.get("gain", 0))
			if gain > 0:
				await _number(uid, "+%d Energy" % gain, ZenithTheme.ENERGY)
			# Allies power up too, and only the event knows what each of them gained.
			for key in data.get("energies", {}).keys():
				var ally: int = int(key)
				if ally != uid:
					fx.float_text(_card_pos(ally), "+1 Energy", ZenithTheme.ENERGY, 44)
			await _beat(BEAT)
		&"energy_changed":
			var delta: int = int(data.get("to", 0)) - int(data.get("from", 0))
			if delta != 0:
				fx.resource_pulse(_card_pos(int(data.get("card", -1))), ZenithTheme.ENERGY, delta > 0)
				_source_pulse(int(data.get("source", -1)))
				await _number(int(data.get("card", -1)), "%+d Energy" % delta, ZenithTheme.ENERGY if delta > 0 else ZenithTheme.WARN)
				await _beat(BEAT)
		&"gain_blocked":
			# A gain swallowed by a standing effect. Without this the card that asked for it
			# looks like it did nothing.
			var uid: int = int(data.get("card", -1))
			fx.float_text(_card_pos(uid), "Gain blocked", ZenithTheme.WARN, 52)
			var v: Card3D = views.get(uid)
			if v != null:
				v.flash(ZenithTheme.WARN)
			hud.toast("Cannot gain Energy", ZenithTheme.WARN)
			await _beat(TOAST_BEAT)
		&"fervor_changed":
			var delta: int = int(data.get("to", 0)) - int(data.get("from", 0))
			if delta != 0:
				fx.resource_pulse(_card_pos(view.player(player).duelist), ZenithTheme.ACCENT, delta > 0)
				_source_pulse(int(data.get("source", -1)))
				await _number(view.player(player).duelist, "%+d Fervor" % delta, ZenithTheme.ACCENT if delta > 0 else ZenithTheme.WARN)
				await _beat(BEAT)
		&"fervor_shielded":
			fx.float_text(_card_pos(view.player(player).duelist), "Shielded", ZenithTheme.DEFEND, 48)
			await _beat(BEAT)
		&"aspect_up", &"aspect_down":
			var uid: int = view.player(player).duelist
			var pos: Vector3 = _card_pos(uid)
			var up: bool = type == &"aspect_up"
			fx.ascend(pos, ZenithTheme.ACCENT if up else ZenithTheme.WARN, up)
			var v: Card3D = views.get(uid)
			if v != null:
				v.flash(ZenithTheme.ACCENT if up else ZenithTheme.WARN)
			hud.toast("%s %s to %s" % [view.player(player).name, "rises" if up else "falls", CardText.stack_aspect_name(int(data.get("aspect", 1)), _duelist_stack(player))], ZenithTheme.ACCENT if up else ZenithTheme.WARN)
			if v != null:
				await v.hop(0.2)
			await _beat(TOAST_BEAT)
		&"countered":
			var target: int = int(data.get("target", -1))
			fx.ward(_card_pos(target), ZenithTheme.DEFEND, 0.8)
			fx.float_text(_card_pos(target), "Countered", ZenithTheme.DEFEND, 48)
			await _beat(BEAT)


## The attacker's controlling card lunges at the defender's, with a streak between them and
## sparks where it lands.
func _swing(attacker: int) -> void:
	var v: Card3D = views.get(_controlling_uid(attacker))
	var target: Card3D = views.get(_controlling_uid(1 - attacker))
	if v == null or not v.visible or target == null:
		return
	var from: Vector3 = v.global_position
	var to: Vector3 = target.global_position
	var dir: Vector3 = to - from
	dir.y = 0.0
	v.lunge(dir)
	await get_tree().create_timer(Card3D.LUNGE_TIME * 0.8).timeout
	fx.slash(from + dir.normalized() * 0.3, to - dir.normalized() * 0.3, ZenithTheme.ATTACK)
	await _beat(Card3D.LUNGE_TIME * 1.2)


func _controlling_uid(seat: int) -> int:
	var controlling: Array = _live.get("controlling", [])
	return int(controlling[seat]) if seat >= 0 and seat < controlling.size() else view.player(seat).controlling


## A number over a card that just changed, with a hop and a flash in the same colour.
## The card about to do something holds the table: it lifts, flashes and names itself, so the
## effects that follow read as its doing rather than as the table changing by itself.
func _spotlight(uid: int) -> void:
	var v: Card3D = views.get(uid)
	var c: SeatCard = view.card(uid)
	if v == null or not v.visible or c == null or c.hidden():
		return
	v.flash(ZenithTheme.ACCENT)
	fx.ring(v.global_position, ZenithTheme.ACCENT, 0.7)
	hud.toast(c.title, ZenithTheme.ACCENT)
	await v.hop(0.16)
	await _beat(SPOTLIGHT_BEAT)


## Public opponent cards get a short reading beat before their effects replay. A spent card
## visits its owner's resolving slot, then flies to its final pile after the hold.
func _opponent_card_beat(uid: int, player: int, targets: Dictionary, caption: String, hold: float, color: Color, public_id: String = "") -> void:
	var c: SeatCard = view.card(uid)
	var v: Card3D = views.get(uid)
	var def: CardDef = _def(c) if c != null and not c.hidden() else Session.library.defs.get(public_id)
	if def == null or player < 0 or player >= view.players.size():
		await _sync_layout(true)
		return
	if not faces.has_face(def, c.aspect if c != null and not c.hidden() else 1):
		await faces.render_def(def)
	var spent: bool = c != null and not c.hidden() and v != null and c.zone in [&"discard", &"removed"] and targets.has(uid)
	await _sync_layout(true, uid if spent else -1)
	if spent:
		var seat: int = viewer if viewer >= 0 else view.active
		var pile: Transform3D = targets[uid][0]
		if not v.visible or v.transform.origin.distance_to(pile.origin) < 0.02:
			v.transform = zones.slot(player, &"hand", 0, 1, seat)
		v.visible = true
		v.face_up = true
		var exchange: Transform3D = zones.slot(player, &"resolving", 0, 1, seat)
		var enter: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		enter.tween_property(v, "transform", exchange, FLY_TIME)
		await enter.finished
	_replay_focus_def = def
	var shown: bool = hud.show_replay_card(def, caption, color)
	if v != null and v.visible and c != null and not c.hidden():
		v.flash(color)
		fx.ring(v.global_position, color, 0.7)
	hud.toast("Opponent plays %s" % def.title, color)
	if v != null and v.visible and c != null and not c.hidden():
		await v.hop(0.16)
	var maximum: float = 5.5 if caption == "YOUR ATTACK STOPPED" else 4.0
	var read_time: float = clampf(1.2 + float(def.text.length()) * 0.025, hold, maximum)
	await _beat(read_time if shown else BEAT)
	if shown:
		hud.hide_focus()
	_replay_focus_def = null
	if spent:
		await _fly(uid, targets)


## A quiet pulse on the card an effect came from, while the effect itself lands somewhere else.
func _source_pulse(uid: int) -> void:
	if uid < 0:
		return
	var v: Card3D = views.get(uid)
	var c: SeatCard = view.card(uid)
	if v == null or not v.visible or c == null or c.hidden():
		return
	v.flash(ZenithTheme.ACCENT)
	fx.ring(v.global_position, ZenithTheme.ACCENT, 0.45)


func _number(uid: int, text: String, color: Color) -> void:
	var v: Card3D = views.get(uid)
	if v == null or not v.visible:
		return
	fx.float_text(_card_pos(uid), text, color, 60)
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
	if _reduced_motion:
		v.transform = target
		return
	if v.transform.origin.distance_to(target.origin) < 0.0005 and v.transform.basis.is_equal_approx(target.basis):
		return
	var start: Transform3D = v.transform
	var mid: Transform3D = start.interpolate_with(target, 0.5)
	mid.origin.y += FLY_LIFT
	var t: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(v, "transform", mid, FLY_TIME * 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property(v, "transform", target, FLY_TIME * 0.5).set_ease(Tween.EASE_IN)
	await t.finished


## A lost Life card has a visible source: the top of its owner's Life Deck. Lift that same
## Card3D, reveal it briefly over the table, and then send it to its public pile in the rail.
## Other destinations (notably a bypassed Seal) keep the ordinary zone transition.
func _fly_life_loss(uid: int, player: int, targets: Dictionary, label: String) -> void:
	var card: SeatCard = view.card(uid)
	var v: Card3D = views.get(uid)
	if player < 0 or player >= view.players.size() or card == null or card.hidden() or v == null or not targets.has(uid) or card.zone not in [&"discard", &"removed"]:
		await _fly(uid, targets)
		return
	var entry: Array = targets[uid]
	if not bool(entry[2]):
		return
	var target: Transform3D = entry[0]
	var counts: Array = _live.get("zones", [])
	var seat_counts: Array = counts[player] if player < counts.size() else []
	var remaining: int = int(seat_counts[0]) if not seat_counts.is_empty() else view.player(player).life_deck.size()
	var source: Transform3D = zones.slot(player, &"life_deck", maxi(0, remaining), 1, viewer if viewer >= 0 else view.active)
	source.basis = source.basis * Basis(Vector3.RIGHT, PI)
	v.transform = source
	v.visible = true
	v.face_up = true
	var deck_pos: Vector3 = zones.to_global(source.origin)
	fx.impact(deck_pos, ZenithTheme.ATTACK, 0.55)
	fx.float_text(deck_pos + Vector3.UP * 0.65, label, ZenithTheme.ATTACK, 56)
	var fixture: DuelistDisplay = near_duelist if near_duelist.duelist_uid == view.player(player).duelist else far_duelist
	fixture.pulse_life_loss()
	if _reduced_motion:
		v.transform = target
		return
	var lift: Transform3D = source
	lift.origin.y += 0.38
	lift.basis = source.basis.scaled(Vector3.ONE * 1.08)
	# The rail lives in camera space. A world-height apex can leave the screen as the camera
	# tilts, so position and size this short reveal in screen space instead.
	var source_screen: Vector2 = camera.unproject_position(deck_pos)
	var target_screen: Vector2 = camera.unproject_position(cards_root.to_global(target.origin))
	var reveal_screen: Vector2 = source_screen.lerp(target_screen, 0.38) + Vector2(0, -42)
	var source_depth: float = -camera.to_local(deck_pos).z
	var target_depth: float = -camera.to_local(cards_root.to_global(target.origin)).z
	var reveal_depth: float = lerpf(source_depth, target_depth, 0.38)
	var reveal_scale: float = 112.0 * _units_per_pixel(reveal_depth) / TableLayout.CARD_SIZE.y
	var reveal: Transform3D = Transform3D(target.basis.orthonormalized().scaled(Vector3.ONE * reveal_scale), camera.project_position(reveal_screen, reveal_depth))
	var launch: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	launch.tween_property(v, "transform", lift, LIFE_FLY_POP).set_ease(Tween.EASE_OUT)
	launch.tween_property(v, "transform", reveal, LIFE_FLY_REVEAL).set_ease(Tween.EASE_OUT)
	await launch.finished
	await _beat(0.08)
	var settle: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	settle.tween_property(v, "transform", target, LIFE_FLY_SETTLE).set_ease(Tween.EASE_IN)
	await settle.finished


## A pause between beats. `--dev-freeze=<event>` takes the screenshot here instead, with the
## event's effects still in the air.
func _beat(seconds: float) -> void:
	if _dev_freeze != &"" and _replaying == _dev_freeze and not _dev_done:
		await _dev_finish(0.03, true)
		return
	await get_tree().create_timer(seconds).timeout


func _card_pos(uid: int) -> Vector3:
	var v: Card3D = views.get(uid)
	if v == null or not v.visible:
		return Vector3.ZERO
	# Personality effects rise above the foreground hand while staying over their source.
	var card: SeatCard = view.card(uid)
	if card != null and card.controller == viewer and card.zone in [&"duelist", &"ally"]:
		return v.global_position + Vector3.UP * 1.0
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


## Endpoints come only from visible public cards; an unavailable source falls back
## to its named performer, then the controller. An explicit redirected target wins.
static func attack_link_cards(state: SeatView, attack: Dictionary, controlling: Array = []) -> Vector2i:
	if state == null or attack.is_empty() or state.players.size() != 2:
		return Vector2i(-1, -1)
	var attacker: int = int(attack.get("attacker", -1))
	var defender: int = int(attack.get("defender", 1 - attacker))
	if attacker not in [0, 1] or defender not in [0, 1]:
		return Vector2i(-1, -1)
	var source: int = int(attack.get("source", -1))
	var card: SeatCard = state.card(source)
	# The final view may already have spent the attack card. A route from its rail pile
	# back across the screen would pull attention away from the two fighters.
	if card == null or card.hidden() or card.zone not in [&"resolving", &"duelist", &"ally"]:
		source = int(attack.get("performer", -1))
		card = state.card(source)
	if card == null or card.hidden():
		source = int(controlling[attacker]) if controlling.size() == 2 else state.player(attacker).controlling
	var target: int = int(attack.get("target", -1))
	card = state.card(target)
	if card == null or card.hidden():
		target = int(controlling[defender]) if controlling.size() == 2 else state.player(defender).controlling
	for uid in [source, target]:
		card = state.card(uid)
		if card == null or card.hidden():
			return Vector2i(-1, -1)
	return Vector2i(source, target)


func _refresh_attack_link() -> void:
	var endpoints: Vector2i = attack_link_cards(view, _attack_cue, _live.get("controlling", []))
	var source: Card3D = views.get(endpoints.x)
	var target: Card3D = views.get(endpoints.y)
	if source == null or target == null or not source.visible or not target.visible:
		fx.clear_attack_link()
		return
	var state: StringName = &"stopped" if bool(_attack_cue.get("stopped", false)) else (&"landed" if bool(_attack_cue.get("landed", false)) else &"pending")
	fx.show_attack_link(source.global_position, target.global_position, state)


# --- Online ---------------------------------------------------------------

## Hosting: a remote seat asks to apply a command.
func _on_net_command(seat: int, d: Dictionary) -> void:
	_inbox.append({"seat": seat, "cmd": d})
	_drain_inbox()


## Client: the authority sent what our seat may see now.
func _on_net_update(d: Dictionary) -> void:
	_inbox.append(d)
	_drain_inbox()


## Works through queued network traffic once the table is idle.
func _drain_inbox() -> void:
	if busy or _draining_inbox:
		return
	_draining_inbox = true
	while not busy and not _dev_done and not _inbox.is_empty():
		await _drain_one_message()
	_draining_inbox = false


func _drain_one_message() -> void:
	var d: Dictionary = _inbox.pop_front()
	if authority:
		await _apply(int(d["seat"]), d["cmd"])
		return
	var update: SeatUpdate = SeatUpdate.from_dict(d)
	# While both seats decide at once (the Reserve swap, the Discard step), the other seat's
	# moves arrive as updates too. Only an update carrying our own command answers the one we
	# sent, and one that leaves our decision as it was plays underneath the open prompt, so the
	# panel, the tray selection and the highlights stay put.
	var mine: bool = _carries_command(update, viewer)
	var same_prompt: bool = not mine and not _awaiting_answer and prompt != null and update.prompt != null \
		and prompt.to_dict() == update.prompt.to_dict()
	busy = true
	if not same_prompt:
		hud.clear_prompt()
		_clear_highlights()
	if _awaiting_answer and mine:
		_awaiting_answer = false
	await _play_update(update)
	busy = false
	if await _dev_count_update():
		return
	if same_prompt:
		return
	if _awaiting_answer:
		hud.refresh_state(view, viewer)
		hud.show_sending()
		return
	_present_prompt()


static func _carries_command(update: SeatUpdate, seat: int) -> bool:
	for line in update.lines:
		if str(line.get("type", "")) == "command" and int(line.get("player", -1)) == seat:
			return true
	return false


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
		if Net.is_authority():
			Net.back_to_lobby()
		else:
			Net.leave()
			Session.go_to_title()
	elif Session.in_adventure():
		Session.finish_stage(view.winner == viewer)
	else:
		Session.go_to_select()


# --- Cards ----------------------------------------------------------------

func _hand_blocks_board() -> bool:
	return hand_3d.visible and (hand_3d.keyboard_active or hand_3d.blocks_pointer(get_viewport().get_mouse_position()))


## The camera-facing preview and its attached choices own this patch of the screen.
## Transparent presentation must not let the field underneath produce hover tooltips.
func _preview_blocks_point(point: Vector2) -> bool:
	if hud.tray.visible or hud.pile.visible or hud.inspect.visible or hud.handoff.visible or hud.loading.visible or hud.game_over.visible:
		return false
	return (hud.focus.is_visible_in_tree() and hud.focus.get_global_rect().has_point(point)) \
		or (hud.prompt_panel.is_visible_in_tree() and hud.prompt_panel.get_global_rect().has_point(point))


func _on_card_clicked(uid: int) -> void:
	if _preview_blocks_point(hud.root.get_global_mouse_position()) and not (hand_3d.keyboard_active and view != null and viewer >= 0 and view.player(viewer).hand.has(uid)):
		return
	if _hand_blocks_board() and (view == null or viewer < 0 or not view.player(viewer).hand.has(uid)):
		return
	# A card sitting in a public pile with nothing to choose about it opens that whole pile to
	# be read, the way a Life Deck search shows a deck. A pile card that is part of the pending
	# decision stays a choice, so the decision wins.
	var pile: Vector2i = _pile_of(uid)
	if pile.x >= 0 and (not _can_choose() or prompt.options_for_card(uid).is_empty()):
		hud.show_pile(view, pile.x, &"removed" if pile.y == 1 else &"discard")
		return
	if not _can_choose():
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


## A click on the felt of a Discard or Removed pile, including its count label: read the pile.
## A pile whose cards the pending decision offers keeps its cards as choices, so the click is
## left to the card under the pointer.
func _on_pile_clicked(player: int, zone: StringName) -> void:
	if view == null or hud.pile.visible:
		return
	if _hand_blocks_board() or _preview_blocks_point(hud.root.get_global_mouse_position()):
		return
	var p: SeatPlayer = view.player(player)
	if _can_choose():
		for uid in (p.removed if zone == &"removed" else p.discard):
			if not prompt.options_for_card(uid).is_empty():
				return
	hud.show_pile(view, player, zone)


## Which public pile a card is sitting in: (player, 0) for a Discard, (player, 1) for Removed,
## (-1, -1) for anywhere else. A standing effect's source is lifted out of the Removed pile and
## stood beside its owner, so it answers for itself rather than for the pile it came from.
func _pile_of(uid: int) -> Vector2i:
	if view == null or _standing_uids().has(uid):
		return Vector2i(-1, -1)
	for p in view.players:
		if p.discard.has(uid):
			return Vector2i(p.index, 0)
		if p.removed.has(uid):
			return Vector2i(p.index, 1)
	return Vector2i(-1, -1)


func _on_card_hovered(uid: int, over: bool) -> void:
	if _hand_blocks_board() or _preview_blocks_point(hud.root.get_global_mouse_position()):
		hud.hide_peek()
		var board_card: Card3D = views.get(uid)
		if board_card != null and board_card._hovering:
			board_card.set_hovered(false)
		return
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
	if _preview_blocks_point(hud.root.get_global_mouse_position()) and not (hand_3d.keyboard_active and viewer >= 0 and view.player(viewer).hand.has(uid)):
		return
	if _hand_blocks_board() and (viewer < 0 or not view.player(viewer).hand.has(uid)):
		return
	var c: SeatCard = view.card(uid)
	if c == null or c.hidden():
		return
	hud.show_inspect(_def(c), c.aspect, uid)


func _def(c: SeatCard) -> CardDef:
	return Session.library.defs.get(c.def_id)


## The duelist's Aspect stack for a seat, for its Aspect titles. The announced ladder is public,
## so the view carries its card ids on the duelist's SeatCard. Null while the view has no card.
func _duelist_stack(player: int) -> PersonalityStack:
	var c: SeatCard = view.card(view.player(player).duelist)
	if c == null or c.ladder.is_empty():
		return null
	return PersonalityStack.from_ids(Session.library, c.ladder)


## One Card3D per uid the view knows, with the face the view allows (a back for hidden cards).
func _adopt_cards() -> void:
	var ghosts: Dictionary = _standing_uids()
	for uid in view.cards.keys():
		var c: SeatCard = view.card(uid)
		var v: Card3D = views.get(uid)
		if v == null:
			v = CARD_SCENE.instantiate()
			v.uid = uid
			v.reduced_motion = _reduced_motion
			v.visible = false
			cards_root.add_child(v)
			v.set_textures(null, faces.back())
			v.clicked.connect(_on_card_clicked)
			v.inspected.connect(_on_card_inspected)
			v.hovered.connect(_on_card_hovered)
			views[uid] = v
		v.set_ghost(ghosts.has(uid))
		if c.hidden():
			continue
		var def: CardDef = _def(c)
		if def == null:
			continue
		var key: String = CardFaceCache.key_for(def, c.aspect)
		if str(_face_keys.get(uid, "")) != key:
			v.set_face_texture(faces.face(def, c.aspect))
			_face_keys[uid] = key


## Source card uid -> [owner, index within that owner's ghosts] for every effect that outlasts
## the Combat. One card can carry more than one standing effect, so it takes only one slot.
func _standing_uids() -> Dictionary:
	var out: Dictionary = {}
	var per_owner: Array[int] = [0, 0]
	for s in view.standing:
		var uid: int = int(s.get("source", -1))
		var owner: int = int(s.get("owner", -1))
		if uid < 0 or owner < 0 or out.has(uid) or view.card(uid) == null:
			continue
		out[uid] = [owner, per_owner[owner]]
		per_owner[owner] += 1
	return out


## Where a backline card sits: pinned over its row in the screen-edge rail rather than on the
## felt. The transform is built in camera space, so the card keeps its size at any window size
## and the table underneath is left to the fighters.
func _rail_slot(player: int, zone: StringName, index: int) -> Transform3D:
	var rail: BacklineRail = hud.near_backline if player == (viewer if viewer >= 0 else view.active) else hud.far_backline
	var anchor: Vector2 = rail.row_anchor(zone) + Vector2(RAIL_STACK_PX, -RAIL_STACK_PX) * index
	var units: float = _units_per_pixel(RAIL_DEPTH)
	var origin: Vector3 = camera.project_position(anchor, RAIL_DEPTH)
	var scale_factor: float = rail.well_height() * units / TableLayout.CARD_SIZE.y
	# A table card's face points along its own +Y because it lies flat. Turning the camera basis
	# a quarter turn about X stands it up to face the lens instead of showing its edge.
	var facing: Basis = camera.global_basis * Basis(Vector3.RIGHT, PI * 0.5)
	return Transform3D(facing.scaled(Vector3.ONE * scale_factor), origin)


## World units one screen pixel covers at `depth`, the same measure the hand lays itself out with.
func _units_per_pixel(depth: float) -> float:
	return camera.project_position(Vector2.ZERO, depth).distance_to(camera.project_position(Vector2(1, 0), depth))


## Every card's target slot for the current view. Cards not listed are hidden.
func _targets() -> Dictionary:
	var out: Dictionary = {}
	var vw: int = viewer if viewer >= 0 else view.active
	for p in view.players:
		var n: int = p.life_deck.size()
		for i in range(n):
			out[p.life_deck[i]] = [zones.slot(p.index, &"life_deck", n - 1 - i, 1, vw), false, true]
		# The piles and the two used cards live in the screen-edge rail, not on the felt, so the
		# table is left to the fighters. They are still real cards pinned over their rail row,
		# which keeps every arc and stack reading the way it did on the table.
		for i in range(p.discard.size()):
			out[p.discard[i]] = [_rail_slot(p.index, &"discard", i), true, true]
		for i in range(p.removed.size()):
			out[p.removed[i]] = [_rail_slot(p.index, &"removed", i), true, true]
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
		for i in range(p.remain.size()):
			out[p.remain[i]] = [zones.slot(p.index, &"remain", i, p.remain.size(), vw), true, true]
		out[p.duelist] = [zones.slot(p.index, &"duelist", 0, 1, vw), true, true]
		if p.mastery >= 0:
			out[p.mastery] = [_rail_slot(p.index, &"mastery", 0), true, true]
		var reserve_n: int = p.reserve.size()
		if p.relic >= 0:
			out[p.relic] = [_rail_slot(p.index, &"relic", 0), true, true]
		for i in range(reserve_n):
			# Reserve cards sit face down under the Relic; only their owner sees them in the prompt.
			out[p.reserve[i]] = [_rail_slot(p.index, &"relic", i + 1), false, true]
	# An attachment has no zone of its own: it rides the card it is attached to, tucked behind it
	# and a little smaller. Without this it is in play and drawn nowhere, so an effect that asks
	# the player to pick it has nothing to click.
	for p in view.players:
		for uid in p.attachments:
			var host: SeatCard = view.card(uid)
			if host == null or not out.has(host.attached_to):
				continue
			var seat_entry: Array = out[host.attached_to]
			var base: Transform3D = seat_entry[0]
			var tucked: Transform3D = Transform3D(base.basis.scaled(Vector3.ONE * ATTACH_SCALE), base.origin)
			tucked.origin += base.basis * ATTACH_OFFSET
			out[uid] = [tucked, true, bool(seat_entry[2])]
	# A standing effect's source card is in the Removed pile; it is lifted out of that stack and
	# stood beside its owner instead, so the passive has something on the table to hover.
	var ghosts: Dictionary = _standing_uids()
	for uid in ghosts:
		out[uid] = [zones.slot(int(ghosts[uid][0]), &"standing", int(ghosts[uid][1]), 1, vw), true, true]
	if view.grounds >= 0:
		out[view.grounds] = [zones.slot(0, &"grounds", 0, 1, vw), true, true]
	for uid in view.resolving:
		if not out.has(uid):
			out[uid] = [zones.slot(view.card(uid).owner, &"resolving", 0, 1, vw), true, true]
	return out


## Energy marks on duelists and Allies in play, Fervor on the duelist.
func _refresh_markers() -> void:
	var live_energy: Dictionary = _live.get("energy", {})
	var live_might: Dictionary = _live.get("might", {})
	var live_fervor: Array = _live.get("fervor", [])
	var wanted: Dictionary = {}   # uid -> [energy, SeatPlayer or null, fervor or -1, might]
	for p in view.players:
		var fervor: int = int(live_fervor[p.index]) if p.index < live_fervor.size() else -1
		wanted[p.duelist] = [_live_energy(live_energy, p.duelist), p, fervor, -1]
		for uid in p.allies:
			wanted[uid] = [_live_energy(live_energy, uid), null, -1, _live_might(live_might, uid)]
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
		m.set_status(int(wanted[uid][0]), wanted[uid][1] as SeatPlayer, int(wanted[uid][2]), int(wanted[uid][3]))


## The Energy to draw for a card: what the beat says, else what the view ends on. The map is
## keyed by uid, and JSON brings its keys back as strings.
func _live_energy(live: Dictionary, uid: int) -> int:
	if live.has(uid):
		return int(live[uid])
	if live.has(str(uid)):
		return int(live[str(uid)])
	var c: SeatCard = view.card(uid)
	return c.energy if c != null else 0


## The same for Might, which the beat carries whenever a modifier moved it.
func _live_might(live: Dictionary, uid: int) -> int:
	if live.has(uid):
		return int(live[uid])
	if live.has(str(uid)):
		return int(live[str(uid)])
	var c: SeatCard = view.card(uid)
	return c.might if c != null else 0


func _sync_layout(animated: bool, pinned_uid: int = -1) -> void:
	var targets: Dictionary = _targets()
	zones.set_viewer(viewer if viewer >= 0 else view.active)
	zones.refresh_occupancy(view)
	_refresh_displays()
	_refresh_markers()
	var tween: Tween = null
	var moved: bool = false
	for uid in views.keys():
		if uid == pinned_uid:
			continue
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
	_refresh_attack_link()


func _swing_camera(player: int) -> void:
	var target: float = 0.0 if player == 0 else PI
	camera.return_home()
	if _reduced_motion:
		rig.rotation.y = target
		return
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
	if _dev_done or prompt == null or busy or _awaiting_answer:
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
				hand_3d.preview_index(0)
			elif arg == "--dev-peek=duelist":
				_on_card_hovered(view.player(viewer).duelist, true)
			elif arg.begins_with("--dev-hover="):
				hud.hover_primary(int(arg.get_slice("=", 1)))
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
	if _dev_policy == "attack" or _dev_policy == "showcase":
		var choices: Array[StringName] = [&"attack", &"declare", &"no_defense", &"no_endure"]
		if _dev_policy == "showcase":
			choices = [&"attack", &"declare", &"defend", &"power_defend", &"endure", &"no_defense", &"no_endure"]
		for wanted in choices:
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
	_set_hand({})
	await _dev_finish()
	return true


func _dev_finish(settle: float = 0.6, after_replay: bool = false) -> void:
	_dev_done = true
	if _dev_screenshot != "":
		if _dev_hide_hud:
			hud.visible = false
		var cam: PackedStringArray = _dev_camera.split(",")
		if cam.size() == 3:
			camera.dev_set(Vector2(float(cam[0]), float(cam[1])), int(cam[2]))
		# `--dev-pile=mine:discard` (or `theirs`, `removed`) opens the pile browser for the shot,
		# the same view a click on that pile gives.
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--dev-pile=") and view != null:
				var parts: PackedStringArray = arg.get_slice("=", 1).split(":")
				var seat: int = viewer if viewer >= 0 else view.active
				var player: int = seat if parts[0] != "theirs" else 1 - seat
				await hud.show_pile(view, player, &"removed" if parts.size() > 1 and parts[1] == "removed" else &"discard")
		await get_tree().create_timer(settle).timeout
		# Window startup can deliver late pointer motion after the requested hand preview.
		# Freeze only this screenshot's presentation after settling; normal input is unchanged.
		for arg in OS.get_cmdline_user_args():
			var hand_preview: bool = arg == "--dev-peek" or (arg.begins_with("--dev-peek=") and arg.get_slice("=", 1).is_valid_int())
			if hand_preview and hand_3d.visible:
				hand_3d.preview_index(int(arg.get_slice("=", 1)) if arg.contains("=") else 0)
				hand_3d._layout(true)
				hand_3d.set_process(false)
				hand_3d.set_process_unhandled_input(false)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_dev_screenshot)
		print("screenshot saved to %s" % _dev_screenshot)
	if after_replay:
		_dev_quit_after_replay = true
	else:
		_dev_shutdown()


## A CLI capture must release its scene, renderer nodes and bound tweens before the
## engine shuts down. SceneTree frees queued nodes at this frame's end; the next
## process_frame signal is the first point at which quitting is safe.
func _dev_shutdown() -> void:
	var tree: SceneTree = get_tree()
	tree.process_frame.connect(tree.quit, CONNECT_ONE_SHOT)
	queue_free()
