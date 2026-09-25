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
const BULK_RECOVER_TIME: float = 0.42 # a full Life Deck reset moves as one shuffle
const FLY_LIFT: float = 0.6
const LIFE_FLY_POP: float = 0.10
const LIFE_FLY_REVEAL: float = 0.18
const LIFE_FLY_SETTLE: float = 0.22
const BEAT: float = 0.22              # pause after a hit or a flipped card, so each one reads
const TOAST_BEAT: float = 0.35
const SPOTLIGHT_BEAT: float = 0.45    # hold on the card whose effect is about to resolve
const QUIET_BEAT: float = 0.3         # a window that opened on nothing still gets its moment
const WINDOW_BEAT: float = 0.15       # a skipped response window, the shortest thing said out loud
const BANNER_BEAT: float = 0.8        # a turn change sweeps wider than an ordinary toast
const BATCH_SPOTLIGHT: float = 0.15   # a long trigger run resolves at a glance, not card by card
const SKIP_BEAT: float = 0.05         # the floor every beat scales down to, and the hold-to-skip wait
const BATCH_TRIGGERS: int = 4         # this many triggers in a row become one "Resolving N" run
const CROWD_WINDOWS: int = 3          # this many skipped windows in one update drop their beats
## Which chip of the HUD's phase strip each skipped window belongs to (`DuelHud.SUB_KEYS`).
const WINDOW_PHASE: Dictionary = {&"respond": &"resolve", &"entering_combat": &"enter",
	&"after_damage": &"resolve", &"combat_end": &"end", &"late_stop": &"resolve"}
## The phases where the attacker and the defender keep their role cues, attack dictionary or not.
const COMBAT_ROLE_PHASES: Array[int] = [GameState.Phase.ATTACK, GameState.Phase.DEFEND,
	GameState.Phase.BATTLE, GameState.Phase.FIGHT_BACK]
const OPPONENT_USE_READ: float = 1.8
const OPPONENT_DEFENSE_READ: float = 2.2
const OPPONENT_STOP_READ: float = 3.2
## Every declared attack pins its card in the Focus slot and holds there before the next beat, so
## the card can be read even when the defender has nothing and `no_defense` follows at once. Own
## attacks hold less, because the player who declared one already knows what it says.
const ATTACK_READ: float = 2.2
const ATTACK_READ_OWN: float = 1.0
## The same for the card that answers from the stack: a defense, a Power, a Shield, a counter, an
## Endurance. It holds on top of the stack before the beat that resolves it takes it off again.
const ANSWER_READ_OWN: float = 1.0
## The pinned attack stays this long after the exchange is settled, then the slot clears.
const FOCUS_RELEASE: float = 0.6
## A card used outside an attack still gets long enough to be read when it carries rules text.
const CARD_USE_READ: float = 0.8
const DRAW_BEAT: float = 0.10         # between cards of the same draw, so they arrive one by one
const WOUND_BEAT: float = 0.5         # between life cards, long enough to read what each one cost
const AI_MIN_THINK: float = 0.45      # seconds the AI appears to think, so its plays do not snap
const STALL_MS: int = 1200            # a hidden decision panel this long is a stall, not a beat
const ATTACH_OFFSET: Vector3 = Vector3(0.30, 0.004, -0.22)   # a corner of the attachment peeks past its host
const ATTACH_SCALE: float = 0.78
const PILE_ZONES: Array[StringName] = [&"discard", &"removed", &"relic"]   # indexed by _pile_of().y
## Where a used card can be by the time its beat replays. A card that stays in play (an Ally, a
## Drill, a Remain card) is never held: its own zone is where it is read.
const HOLD_ZONES: Array[StringName] = [&"resolving", &"discard", &"removed", &"life_deck"]
const ARENA_FADE: float = 0.35        # seconds for the table to dim or come back around an exchange
const PLATE_DIM: Color = Color(0.45, 0.45, 0.45)   # the stat plaques, which stand up through the veil
const FOCUS_POP_FROM: float = 0.9     # the centre-stage card's scale as it appears
const FOCUS_POP_TIME: float = 0.22
const HELD_STEP: float = 0.004       # a second held card of the same seat sits just above the first

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
@onready var arena_veil: MeshInstance3D = $ArenaVeil
@onready var presence: DuelPresence = $Presence

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
var _second_wind_returning: Dictionary = {} # public cards lost and recovered in this update
## Cards the exchange being replayed has used, held face up in their owner's Play slot until their
## part is over: uid -> {"seat": int, "until": StringName}. `until` is &"attack" (released at
## `attack_end`), &"defense" (at `attack_stopped` / `attack_successful`) or &"beat" (at the end of
## the beat that used it). The engine moves a used card on at once, and when the whole exchange
## arrives in one update the final view already has it in a pile or face down in the Life Deck, so
## `_targets` puts a held card in the Play slot instead and `_fly` leaves it there. A hold outlives
## the update when a decision interrupts the exchange.
var _held: Dictionary = {}
## The table numbers as they stood at the beat now playing (`GameEvent.state`). While it holds
## something, the markers and the player panels read it instead of the update's final view, so a
## card that charges up and is drained again in the same update reads as two beats, not one jump.
var _live: Dictionary = {}
var _attack_cue: Dictionary = {}   # public attack currently replaying, never the future update outcome
var _focus_key: String = ""
var _replay_focus_def: CardDef = null
## The attack pinned in the Focus slot for the exchange being replayed: its uid, the face to draw,
## and the caption it currently carries. It outlives a single update, because the defender's
## decision arrives between two of them, and is released a short hold after `attack_end`.
var _pinned_attack: int = -1
var _pinned_def: CardDef = null
var _pinned_caption: String = ""
var _pinned_color: Color = ZenithTheme.ATTACK
var _answer_title: String = ""      # what last answered the pinned attack, for the stop caption
## Responses on the stack that resolve with the attack itself rather than on a beat of their own:
## a defense and a defense Power. A Shield, a counter and an Endurance leave at their own beat.
var _defense_uids: Array[int] = []
var _window_skips: int = 0           # skipped response windows in the update being replayed
var _fast_triggers: Dictionary = {}  # line index -> run length, for a batched run of triggers
var _shown_stats: Dictionary = {}    # player -> [energy, might] as the readout last drew them
var _reduced_motion: bool = false
var _exchange_live: bool = false     # the exchange holds a card in play, as of the last `_targets`
var _arena_on: bool = false          # the table is dimmed for a live exchange (`_set_arena`)
var _arena_fade: Tween = null
var _focus_pop: Tween = null
var _stall_since: int = 0           # when the viewer was first owed a decision with no panel up
## Online presence (`PresenceState`): what the other player is doing, drawn here, and what this
## one is doing, sent from here. Off in hotseat, vs AI and adventure.
var _presence_on: bool = false
var _hover_uid: int = -1             # the table card under our own pointer, -1 for none
var _their_presence: Dictionary = {} # the other player's last sanitised state
var _presence_drawn_view: SeatView = null
var _presence_card: int = -1         # the table card carrying their highlight
var _presence_demo: String = ""      # `--dev-presence-demo[=card|hand|look]`: a scripted pointer
const PRESENCE_DEMO_LINGER: float = 4.0   # real seconds a demo sender stays up after its last step
const PRESENCE_ZONES: Dictionary = {"discard": "Discard", "removed": "Out pile", "relic": "Relic pile"}


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
	_set_reduced_motion(ArcaneBackdrop.motion_reduced())
	hud.option_chosen.connect(_on_option_chosen)
	hud.card_clicked.connect(_on_card_clicked)
	hud.handoff_confirmed.connect(_on_handoff_confirmed)
	hud.rematch_requested.connect(_on_rematch)
	hud.select_requested.connect(_on_select)
	hud.dev_command.connect(_on_dev_command)
	zones.pile_clicked.connect(_on_pile_clicked)
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
	_presence_on = online and not Session.in_adventure() and viewer >= 0
	if _presence_on:
		presence.set_color(Session.seat_color(1 - viewer))
		Net.presence_received.connect(_on_presence)
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
	ArcaneBackdrop.reduced_motion = on
	$Atmosphere.reduced_motion = on
	fx.reduced_motion = on
	presence.reduced_motion = on
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
	zones.set_pickable(board_interactive)
	for value in views.values():
		var board_card: Card3D = value
		if board_card.pick.input_ray_pickable != board_interactive:
			board_card.pick.input_ray_pickable = board_interactive
		if not board_interactive and board_card._hovering:
			board_card.set_hovered(false)
	if hand_blocks or preview_blocks:
		hud.hide_peek()
	_watch_for_stall(overlay)
	if _presence_on and view != null:
		presence.offer(_demo_presence() if _presence_demo != "" else _local_presence(board_interactive))
		if view != _presence_drawn_view:
			_presence_drawn_view = view
			_draw_presence(false)
	_layout_fixtures()
	var focus_was: bool = focus_card.visible
	focus_card.visible = hud.focus.visible and not overlay
	# On centre stage the card arrives with a small push toward the viewer.
	if focus_card.visible and not focus_was and _arena_on and not _reduced_motion:
		if _focus_pop != null and _focus_pop.is_valid():
			_focus_pop.kill()
		focus_card.scale = Vector3.ONE * FOCUS_POP_FROM
		_focus_pop = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_focus_pop.tween_property(focus_card, "scale", Vector3.ONE, FOCUS_POP_TIME)
	if focus_card.visible and view != null:
		var shown_def: CardDef = _replay_focus_def
		var aspect: int = 1
		var backdrop: Color = hud._uid_backdrop(hud._focus_card_uid)
		var focus_seat_card: SeatCard = view.card(hud._focus_card_uid)
		var seat_of: int = focus_seat_card.owner if focus_seat_card != null else -1
		if shown_def == null:
			var card: SeatCard = view.card(hud._focus_uid(prompt))
			if card != null and not card.hidden():
				shown_def = _def(card)
				aspect = card.aspect
				backdrop = hud.seat_backdrop(card.owner)
				seat_of = card.owner
		if shown_def != null:
			var key: String = faces.key_of(shown_def, aspect, backdrop, seat_of)
			if _focus_key != key:
				focus_card.texture = faces.face(shown_def, aspect, backdrop, seat_of)
				_focus_key = key
		else:
			focus_card.visible = false
	_set_arena(_exchange_live)


## While an exchange is live the table recedes behind a veil, the camera leans in on the ring, the
## ring pulses once, and the HUD's focus card takes centre stage over it. Reduced motion keeps the
## dimming and the centred card and drops the moves.
func _set_arena(on: bool) -> void:
	camera.arena_focus = on and not _reduced_motion
	if on == _arena_on:
		return
	_arena_on = on
	hud.centre_stage = on
	if _arena_fade != null and _arena_fade.is_valid():
		_arena_fade.kill()
	var veil: ShaderMaterial = arena_veil.material_override
	var plate_tint: Color = PLATE_DIM if on else Color.WHITE
	arena_veil.visible = true
	if _reduced_motion:
		veil.set_shader_parameter("amount", 1.0 if on else 0.0)
		arena_veil.visible = on
		for fixture: DuelistDisplay in [near_duelist, far_duelist]:
			fixture.plate_face.modulate = plate_tint
		return
	_arena_fade = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arena_fade.tween_method(func(value: float) -> void: veil.set_shader_parameter("amount", value), 0.0 if on else 1.0, 1.0 if on else 0.0, ARENA_FADE)
	for fixture: DuelistDisplay in [near_duelist, far_duelist]:
		_arena_fade.tween_property(fixture.plate_face, "modulate", plate_tint, ARENA_FADE)
	if not on:
		_arena_fade.chain().tween_callback(func() -> void: arena_veil.visible = false)
		return
	fx.ring(Vector3(0, 0.02, 0), ZenithTheme.ACCENT, 1.6)


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
	for fixture: DuelistDisplay in [near_duelist, far_duelist]:
		var card: Card3D = views.get(fixture.duelist_uid)
		fixture.visible = card != null and card.visible and not camera.is_position_behind(card.global_position)
		if not fixture.visible:
			continue
		fixture.global_position = card.global_position
		var owner: int = view.card(fixture.duelist_uid).owner
		var count: int = view.player(owner).life_deck.size()
		fixture.life_transform = zones.global_transform * zones.slot(owner, &"life_deck", maxi(0, count - 1), count, viewer)
		fixture.anchor_to_card(card, camera)
	if viewer >= 0 and near_duelist.visible:
		var near_card: Card3D = views.get(near_duelist.duelist_uid)
		var life_x: float = camera.unproject_position(near_duelist.life_transform.origin).x
		var fighter_screen: Vector2 = camera.unproject_position(near_card.global_position)
		near_duelist.readout.update_layout()
		var crest: Rect2 = near_duelist.screen_rect(camera)
		var hero_bottom: float = maxf(fighter_screen.y, crest.end.y)
		hand_3d.set_hero_bounds(life_x - size.x * 0.035, fighter_screen.x + size.x * 0.09, hero_bottom)
		hand_3d.set_crest_rect(crest)
	var rival_life: Rect2 = Rect2()
	if far_duelist.visible and not camera.is_position_behind(far_duelist.life_transform.origin):
		rival_life = Rect2(camera.unproject_position(far_duelist.life_transform.origin), Vector2.ZERO)
		for x: float in [-0.315, 0.315]:
			for z: float in [-0.44, 0.44]:
				rival_life = rival_life.expand(camera.unproject_position(far_duelist.life_transform * Vector3(x, 0, z)))
	hud.avoid_rect = rival_life
	var decision_rect: Rect2 = Rect2()
	if hud.prompt_panel.visible:
		decision_rect = hud.prompt_panel.get_global_rect()
	# On centre stage the card sits over the table's middle; the open hand rises over its lower
	# edge rather than stepping aside, and only the decision beside it is kept clear.
	if hud.focus.visible and not hud.centre_stage:
		decision_rect = decision_rect.merge(hud.focus.get_global_rect()) if decision_rect.has_area() else hud.focus.get_global_rect()
	hand_3d.set_decision_rect(decision_rect)
	if not hud.focus.visible:
		return
	var face_rect: Rect2 = hud.focus_face_rect()
	focus_card.position = camera.to_local(camera.project_position(face_rect.get_center(), depth))
	focus_card.pixel_size = face_rect.size.x / 512.0 * units


func _refresh_displays() -> void:
	if view == null:
		return
	var me: int = viewer if viewer >= 0 else (view.deciding if view.deciding >= 0 else view.active)
	near_duelist.refresh(view, me, me, _live)
	far_duelist.refresh(view, 1 - me, me, _live)
	_float_stat_delta(near_duelist, me)
	_float_stat_delta(far_duelist, 1 - me)
	# Status exceptions are already part of the fixtures; keep HUD copies for inspection only.
	hud.near_flags.hide()
	hud.far_flags.hide()


## The signed change in a fighter's Energy or Might, floated over its readout in the colour the
## readout itself now draws that number in. The numbers come from the readout, which reads the
## beat's own state; nothing here works out what they should be.
func _float_stat_delta(fixture: DuelistDisplay, player: int) -> void:
	if player < 0 or player >= view.players.size():
		return
	var energy: int = fixture.readout.energy_value()
	var might: int = fixture.readout.might_value()
	var previous: Array = _shown_stats.get(player, [])
	_shown_stats[player] = [energy, might, fixture.duelist_uid]
	if previous.size() != 3 or int(previous[2]) != fixture.duelist_uid or _replaying == &"" or not fixture.visible:
		return
	var anchor: Vector3 = _card_pos(fixture.duelist_uid)
	if anchor == Vector3.ZERO:
		return
	# Just off the card's own numbers, so this reads as the readout changing, not a second hit.
	anchor += Vector3.UP * 0.1
	if energy != int(previous[0]):
		var gained: bool = energy > int(previous[0])
		fx.float_text(anchor, "%+d Energy" % (energy - int(previous[0])), ZenithTheme.ENERGY if gained else ZenithTheme.WARN, 52)
	if might != int(previous[1]):
		var stronger: bool = might > int(previous[1])
		# Beside, not above: the far seat's readout sits over its card, so a stacked number lands on it.
		# Far enough across that a wide Energy hit number on the card itself stays clear of it.
		fx.float_text(anchor + camera.global_basis.x * 1.5 - camera.global_basis.y * 0.2,"%+d Might" % (might - int(previous[1])), ZenithTheme.ENERGY if stronger else ZenithTheme.WARN, 52)


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
		elif arg == "--dev-presence-demo" or arg.begins_with("--dev-presence-demo="):
			_presence_demo = arg.get_slice("=", 1) if arg.contains("=") else "cycle"
		elif arg.begins_with("--dev-pick=") and not online and not Session.in_adventure():
			# Online the lobby already agreed on both decks and the seed.
			var picks: PackedStringArray = arg.get_slice("=", 1).split(",")
			if picks.size() == 2:
				Session.chosen = [Session.decks[int(picks[0])], Session.decks[int(picks[1])]]


# --- Turn flow ------------------------------------------------------------

func _present_prompt() -> void:
	if _dev_done or view == null:
		return
	# A prompt draws its own card into the slot, so the replay's pinned face stops overriding it.
	_replay_focus_def = null
	if view.is_over():
		_release_pin()
		if not _held.is_empty():
			_held.clear()
			_sync_layout(false)
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
		_refresh_roles()
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
	faces.set_matchups(view, Session.library, Session.strike_table)
	var seat_backdrops: Array[Color] = [hud.seat_backdrop(0), hud.seat_backdrop(1)]
	await faces.render_missing(view, Session.library, seat_backdrops)
	# Replace private textures before uncovering the new seat, including during camera motion.
	_set_hand({})
	hud.hide_handoff()
	_adopt_cards()
	await _swing_camera(viewer)
	await _sync_layout(true)
	busy = false
	_show_prompt_for_viewer()


func _show_prompt_for_viewer() -> void:
	_replay_focus_def = null
	hud.refresh_state(view, viewer)
	_refresh_roles()
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
	faces.set_matchups(view, Session.library, Session.strike_table)
	$Atmosphere.set_schools(Palette.school_ui(view.player(0).style), Palette.school_ui(view.player(1).style))
	prompt = up.prompt
	var seat_backdrops: Array[Color] = [hud.seat_backdrop(0), hud.seat_backdrop(1)]
	await faces.render_missing(view, Session.library, seat_backdrops)
	_adopt_cards()
	# An exchange spans the updates on either side of the defender's decision. The panel was
	# cleared to play this one, so the attack goes back in its slot before the first beat.
	_restore_pin()
	zones.set_viewer(viewer if viewer >= 0 else view.active)
	var targets: Dictionary = _targets()
	var bulk_recover_end: int = -1
	_scan_batches(up.lines)
	_second_wind_returning.clear()
	for index in range(up.lines.size()):
		for uid in _second_wind_cards(up.lines, index):
			_second_wind_returning[uid] = true
	for index in range(up.lines.size()):
		var l: Dictionary = up.lines[index]
		var bulk_cards: Array[int] = []
		if index > bulk_recover_end:
			bulk_cards = _second_wind_cards(up.lines, index)
			if not bulk_cards.is_empty():
				bulk_recover_end = index + bulk_cards.size() - 1
		var line: String = str(l.get("line", ""))
		# One Second Wind line describes the full reset; its per-card Recover lines are noise.
		if line != "" and (index > bulk_recover_end or str(l.get("type", "")) != "recover"):
			hud.log_line(line)
		if l.has("data") and (index > bulk_recover_end or not bulk_cards.is_empty()):
			_replaying = StringName(str(l.get("type", "")))
			# The beat draws the table as it stood when the event fired, not as it stands now.
			_live = (l.get("state", {}) as Dictionary).duplicate(true)
			if not bulk_cards.is_empty():
				# Hold the emptied Life number until the pile actually reaches the deck.
				var counts: Array = _live.get("zones", [])
				var player: int = int(l.get("player", -1))
				if player >= 0 and player < counts.size():
					var seat_counts: Array = counts[player]
					if not seat_counts.is_empty():
						seat_counts[0] = 0
			hud.refresh_state(view, viewer, _live)
			_refresh_displays()
			if not bulk_cards.is_empty():
				await _fly_recover_batch(bulk_cards, targets)
				_live = up.lines[bulk_recover_end].get("state", {})
				hud.refresh_state(view, viewer, _live)
				_refresh_displays()
			else:
				await _replay(_replaying, int(l.get("player", -1)), l["data"], targets, line, index)
			_replaying = &""
	_live = {}
	_second_wind_returning.clear()
	if view.is_over():
		# The duel ended mid-exchange; nothing is left to finish, so the closing sync lays it all out.
		_held.clear()
	_attack_cue = view.attack.duplicate(true)
	hud.refresh_state(view, viewer)
	_refresh_displays()
	_refresh_roles()
	await _sync_layout(true)
	if _dev_quit_after_replay:
		_dev_shutdown()


## Two pacing decisions taken once per update, before any of it plays. A run of four or more
## triggers resolves as one announced batch instead of four holds, and an update that skips three
## or more response windows drops their beats: a card-heavy turn would otherwise crawl through
## windows that said nothing.
func _scan_batches(lines: Array[Dictionary]) -> void:
	_fast_triggers.clear()
	_window_skips = 0
	var run_start: int = -1
	for index in range(lines.size() + 1):
		var is_trigger: bool = index < lines.size() and str(lines[index].get("type", "")) == "trigger_fired"
		if index < lines.size() and str(lines[index].get("type", "")) == "window_skipped":
			_window_skips += 1
		if is_trigger:
			if run_start < 0:
				run_start = index
			continue
		if run_start >= 0:
			var length: int = index - run_start
			if length >= BATCH_TRIGGERS:
				for i in range(run_start, index):
					_fast_triggers[i] = length if i == run_start else 0
			run_start = -1


## The survival reset is a contiguous run of public Recover events followed by Second Wind.
## Other recovery effects keep their one-card beats, even when they recover several cards.
func _second_wind_cards(lines: Array[Dictionary], start: int) -> Array[int]:
	var cards: Array[int] = []
	if start >= lines.size() or str(lines[start].get("type", "")) != "recover":
		return cards
	var player: int = int(lines[start].get("player", -1))
	var index: int = start
	while index < lines.size() and str(lines[index].get("type", "")) == "recover" and int(lines[index].get("player", -1)) == player:
		var data: Dictionary = lines[index].get("data", {})
		cards.append(int(data.get("card", -1)))
		index += 1
	if index >= lines.size() or str(lines[index].get("type", "")) != "second_wind" or int(lines[index].get("player", -1)) != player:
		cards.clear()
	return cards


# --- Event beats ----------------------------------------------------------

## One animated event. `data` carries only the public fields the referee lists for its type.
func _replay(type: StringName, player: int, data: Dictionary, targets: Dictionary, line: String = "", index: int = -1) -> void:
	# A card leaving the hand should not remain as a second copy during its board animation.
	var leaving: int = int(data.get("card", data.get("source", data.get("discarded", -1))))
	if viewer >= 0 and leaving >= 0 and not _held.has(leaving) and not view.player(viewer).hand.has(leaving):
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
			# The attack card rises to the Play slot before the swing and stays there until the
			# exchange ends, wherever the rules have already sent it.
			await _hold(int(data.get("source", -1)), player, &"attack", str(data.get("id", "")))
			await _sync_layout(true)
			_refresh_roles()
			var kind: String = str(data.get("kind", "strike"))
			var head: String = "Final Strike" if bool(data.get("is_final", false)) else ("Focused " if bool(data.get("focused", false)) else "") + ("Strike" if kind == "strike" else "Art")
			var src_def: CardDef = _attack_def(int(data.get("source", -1)), data)
			if src_def != null:
				head += ": " + src_def.title
			elif bool(data.get("is_power", false)):
				head += " from a Power"
			hud.toast(head, ZenithTheme.ATTACK)
			_pin_attack(int(data.get("source", -1)), player, data)
			await _swing(player)
			# The card holds here whether or not anything answers it, so an attack the defender
			# cannot meet is still read rather than glimpsed on its way to the damage.
			await _read_beat(ATTACK_READ_OWN if player == viewer else ATTACK_READ)
		&"defense_played", &"defense_power", &"shield":
			var defense_uid: int = int(data.get("card", -1))
			var stopped: bool = bool(data.get("stopped", false))
			# The strip on the card's own edge says what it is; the attack's caption over the stack
			# carries the outcome, so the two never say the same thing twice.
			var caption: String = "Defense"
			if type == &"shield":
				caption = "Shield"
			elif type == &"defense_power":
				caption = "Power"
			# A defense stays in its owner's Play slot until the attack it answers is settled; a
			# Shield resolves on its own beat and leaves at the end of it.
			await _hold(defense_uid, player, &"beat" if type == &"shield" else &"defense", str(data.get("id", "")))
			await _answer_card_beat(defense_uid, player, targets, caption, stopped, str(data.get("id", "")))
			if type == &"shield":
				# A Shield resolves on its own beat, so it leaves the stack once it has been read.
				hud.pop_response(defense_uid)
			elif hud.has_response(defense_uid):
				# A defense stands until the attack it answers is stopped or goes through.
				_defense_uids.append(defense_uid)
			var defender: int = 1 - int(_live.get("attacker", view.attacker))
			fx.ward(_card_pos(_controlling_uid(defender)), ZenithTheme.DEFEND)
			if type != &"defense_played":
				fx.float_text(_card_pos(int(data.get("card", -1))), "Shield", ZenithTheme.DEFEND, 48)
			await _beat(BEAT)
			await _release_held(&"beat", defense_uid)
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
			_pin_caption(_stopped_caption(), ZenithTheme.DEFEND)
			await _beat(TOAST_BEAT)
			# The defense has done its job, so it leaves the stack and the table. The attack stays.
			_pop_defenses()
			await _release_held(&"defense")
		&"attack_successful":
			# Nothing stopped it. Whatever answered it is spent, so it leaves the stack here.
			_pop_defenses()
			await _release_held(&"defense")
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
			await _fly_life_loss(uid, player, targets, "Wound %d" % _wounds, str(data.get("id", "")))
			var v: Card3D = views.get(uid)
			if v != null:
				v.flash(ZenithTheme.ATTACK)
			# Wounds come in runs, so each one names the card it cost and holds long enough to
			# read before the next lands.
			var lost: SeatCard = view.card(uid)
			var public_def: CardDef = Session.library.defs.get(str(data.get("id", "")))
			var title: String = lost.title if lost != null and not lost.hidden() else (public_def.title if public_def != null else "a card")
			hud.toast("Wound %d  ·  %s" % [_wounds, title], ZenithTheme.ATTACK)
			await _beat(WOUND_BEAT)
		&"life_card_lost":
			await _fly_life_loss(int(data.get("card", -1)), player, targets, "-1 Life", str(data.get("id", "")))
		&"final_strike", &"hand_discarded", &"in_play_discarded", &"card_moved", &"critical_ally":
			var uid: int = int(data.get("card", data.get("discarded", -1)))
			await _fly(uid, targets)
		&"card_used", &"card_placed":
			var used_uid: int = int(data.get("card", -1))
			# A used card is read in its owner's Play slot before it goes where the rules sent it,
			# even when that is face down in the Life Deck.
			var held_use: bool = false
			if type == &"card_used":
				held_use = await _hold(used_uid, player, &"beat", str(data.get("id", "")))
			if type == &"card_used" and viewer >= 0 and player != viewer:
				await _opponent_card_beat(used_uid, player, targets, "OPPONENT PLAYS", OPPONENT_USE_READ, ZenithTheme.ACCENT, str(data.get("id", "")))
			else:
				await _sync_layout(true)   # the card lands in play before its text does anything
				await _spotlight(used_uid)
				# The viewer's own card is a hop and a name otherwise; one with rules text is put
				# in the slot for long enough to be read.
				await _read_card(used_uid, "You play" if player == viewer else "In play")
				if held_use and _pinned_attack >= 0 and _held.has(used_uid):
					# A pinned attack keeps the Focus slot, so the card is read where it stands.
					await _read_beat(CARD_USE_READ)
			await _release_held(&"beat", used_uid)
		&"endurance_used":
			var defender: int = 1 - int(_live.get("attacker", view.attacker))
			var pos: Vector3 = _card_pos(_controlling_uid(defender))
			fx.ward(pos, ZenithTheme.DEFEND, 0.8)
			fx.float_text(pos, "Endurance %d" % int(data.get("prevented", 0)), ZenithTheme.DEFEND, 56)
			var card_uid: int = int(data.get("card", -1))
			var used: SeatCard = view.card(card_uid)
			var used_title: String = used.title if used != null and not used.hidden() else "the wound"
			hud.toast("Endurance %d  ·  %s" % [int(data.get("prevented", 0)), used_title], ZenithTheme.DEFEND)
			var endured: bool = _push_response(card_uid, "Endurance", player)
			await _fly(card_uid, targets)
			await _read_beat(ANSWER_READ_OWN if player == viewer or not endured else OPPONENT_DEFENSE_READ)
			# Endurance is spent by the wound it prevents, so it leaves once it has been read.
			hud.pop_response(card_uid)
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
			var was_stopped: bool = bool(data.get("stopped", false))
			if not was_stopped and (stages > 0 or life > 0):
				hud.toast("Dealt %s" % CardText.short_damage(stages, life), ZenithTheme.ATTACK)
				_pin_caption("Dealt %s" % CardText.short_damage(stages, life), ZenithTheme.ATTACK)
				await _beat(TOAST_BEAT)
			elif was_stopped:
				_pin_caption(_stopped_caption(), ZenithTheme.DEFEND)
			else:
				_pin_caption("Dealt nothing", ZenithTheme.MUTED)
			# The outcome stays under the card that caused it for a moment before the slot clears.
			await _beat(FOCUS_RELEASE)
			# The pinned face and the card on the table are the same card, so they go together.
			_release_pin()
			_wounds = 0
			_attack_cue.clear()
			fx.clear_attack_link()
			await _release_held(&"")
		&"combat_end":
			_release_pin()
			await _release_held(&"")
			_attack_cue.clear()
			fx.clear_attack_link()
			_refresh_roles()
		&"trigger_fired":
			# The card doing the work holds for a moment before its effects land, the way MTG Arena
			# stops on a trigger. Everything after this beat is that card's doing. A card already
			# anchored in the Focus slot or stacked over it is read where it stands and then leaves
			# the pile; only a card that is nowhere on the right gets the table's spotlight hop.
			var fired: int = int(data.get("card", -1))
			if hud.pulse_pending(fired):
				var fired_card: SeatCard = view.card(fired)
				if fired_card != null and not fired_card.hidden():
					hud.toast(fired_card.title, ZenithTheme.ACCENT)
				await _read_beat(BATCH_SPOTLIGHT if _fast_triggers.has(index) else CARD_USE_READ)
				hud.pop_response(fired)
			else:
				await _batched_spotlight(fired, index)
				if not _fast_triggers.has(index):
					await _read_card(fired, "Triggered")
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
				fx.resource_pulse(_card_pos(view.player(player).duelist), ZenithTheme.FERVOR, delta > 0)
				_source_pulse(int(data.get("source", -1)))
				await _number(view.player(player).duelist, "%+d Fervor" % delta, ZenithTheme.FERVOR_TEXT if delta > 0 else ZenithTheme.WARN)
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
		&"turn_start":
			# A turn change sweeps wider than an ordinary beat, the way Arena banners one.
			var whose: String = "Your turn" if player == viewer else "%s's turn" % view.player(player).name
			hud.toast(whose, ZenithTheme.ACCENT)
			_mark_phase(&"draw")   # a turn opens on its Draw step
			await _beat(BANNER_BEAT)
		&"turn_end":
			await _quiet("Turn %d ends" % int(data.get("turn", view.turn)), ZenithTheme.MUTED, &"turn_end", QUIET_BEAT)
		&"recover_step":
			var eligible: int = int(data.get("eligible", 0))
			await _quiet("Recover" if eligible <= 0 else "Recover · %d" % eligible, ZenithTheme.ENERGY, &"recover", QUIET_BEAT)
		&"combat_declared":
			var declared: String = "Combat forced" if bool(data.get("forced", false)) else "Combat"
			await _quiet(_quiet_line(line, declared), ZenithTheme.ATTACK, &"declare", QUIET_BEAT)
		&"combat_skipped":
			var reason: String = str(data.get("reason", ""))
			var why: String = "Combat skipped"
			if reason == "grounds":
				why = "Combat skipped · Grounds"
			elif reason == "forbidden":
				why = "Combat skipped · Forbidden"
			await _quiet(why, ZenithTheme.MUTED, &"declare", QUIET_BEAT)
		&"entering_combat":
			await _quiet("Entering Combat", ZenithTheme.MUTED, &"enter", QUIET_BEAT)
		&"pass":
			var consecutive: int = int(data.get("consecutive", 0))
			var said: String = "Passes"
			if consecutive >= 2:
				said = "Passes · Combat ends"
			elif bool(data.get("forced", false)):
				said = "Passes · forced"
			await _quiet(said, ZenithTheme.MUTED, &"attack", QUIET_BEAT)
		&"attack_phase_skipped":
			await _quiet("Skips the attack", ZenithTheme.MUTED, &"attack", QUIET_BEAT)
		&"fight_back":
			# The exchange changes hands. Combat is attack and defend either way, so this pulses the
			# same Attack chip and the state that follows swaps the names under Attack and Defend.
			var next_seat: int = int(data.get("next", -1))
			var whose: String = "Your attack"
			if next_seat != viewer:
				whose = "%s attacks" % view.player(next_seat).name if next_seat >= 0 else "They attack"
			await _quiet(whose, ZenithTheme.ATTACK, &"attack", QUIET_BEAT)
		&"no_defense":
			var defense_reason: String = str(data.get("reason", ""))
			var no_defense: String = "No defense"
			if defense_reason == "standing":
				no_defense = "No defense · Standing"
			elif defense_reason == "none":
				no_defense = "No defense · nothing playable"
			elif defense_reason == "final_strike":
				no_defense = "No defense · Final Strike"
			elif defense_reason == "countered":
				no_defense = "No defense · countered"
			elif defense_reason == "unstoppable":
				no_defense = "No defense · cannot be stopped"
			# The caption sits over a 320px slot, so it takes the short form of the same reason
			# while the quiet banner under the toast carries the full wording.
			var short_reason: String = "No defense"
			if defense_reason == "none":
				short_reason = "No defense · none playable"
			elif defense_reason == "unstoppable":
				short_reason = "No defense · unstoppable"
			elif defense_reason != "":
				short_reason = no_defense
			_pin_caption(short_reason, ZenithTheme.DEFEND)
			await _quiet(no_defense, ZenithTheme.DEFEND, &"defend", QUIET_BEAT)
		&"declined_counter":
			await _quiet("Counter declined", ZenithTheme.DEFEND, &"resolve", QUIET_BEAT)
		&"window_skipped":
			var window: StringName = StringName(str(data.get("window", "respond")))
			var chip: StringName = WINDOW_PHASE.get(window, &"resolve")
			_mark_phase(chip)
			# A card-heavy turn opens these by the handful; past a few they are only noise.
			if _window_skips < CROWD_WINDOWS:
				await _quiet("Nothing to answer with", ZenithTheme.MUTED, chip, WINDOW_BEAT)
		&"control":
			await _quiet(_quiet_line(line, "Takes control"), ZenithTheme.ACCENT, &"attack", 0.0)
			await _spotlight(int(data.get("card", -1)))
		&"power_used":
			await _quiet(_quiet_line(line, "Power"), ZenithTheme.ACCENT, &"attack", 0.0)
			await _spotlight(int(data.get("card", -1)))
		&"relic_used":
			await _quiet(_quiet_line(line, "Relic"), ZenithTheme.ACCENT, &"attack", 0.0)
			await _spotlight(int(data.get("card", -1)))
		&"countered":
			var target: int = int(data.get("target", -1))
			fx.ward(_card_pos(target), ZenithTheme.DEFEND, 0.8)
			fx.float_text(_card_pos(target), "Countered", ZenithTheme.DEFEND, 48)
			# The card that was countered is finished with, so it leaves the stack at once; the
			# counter itself stays on top for its read hold and then follows it off.
			hud.pop_response(target)
			_defense_uids.erase(target)
			await _release_held(&"", target)
			var counter_uid: int = int(data.get("card", -1))
			if await _hold(counter_uid, player, &"beat"):
				await _sync_layout(true)
			var shown_counter: bool = _push_response(counter_uid, "Counter", player)
			if shown_counter:
				await _read_beat(ANSWER_READ_OWN if player == viewer else OPPONENT_DEFENSE_READ)
				hud.pop_response(counter_uid)
			else:
				await _beat(BEAT)
			await _release_held(&"beat", counter_uid)


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
func _spotlight(uid: int, hold: float = SPOTLIGHT_BEAT) -> void:
	var v: Card3D = views.get(uid)
	var c: SeatCard = view.card(uid)
	if v == null or not v.visible or c == null or c.hidden():
		return
	v.flash(ZenithTheme.ACCENT)
	fx.ring(v.global_position, ZenithTheme.ACCENT, 0.7)
	hud.toast(c.title, ZenithTheme.ACCENT)
	await v.hop(0.16)
	await _beat(hold)


## A trigger inside a long run. The run announces itself once and then each card gets a glance
## rather than a full hold, so twelve triggers do not cost twelve spotlights.
func _batched_spotlight(uid: int, index: int) -> void:
	if not _fast_triggers.has(index):
		await _spotlight(uid)
		return
	var run: int = int(_fast_triggers[index])
	if run > 0:
		await _quiet("Resolving %d triggers" % run, ZenithTheme.ACCENT, &"resolve", QUIET_BEAT)
	await _spotlight(uid, BATCH_SPOTLIGHT)


## A window that opened on nothing, said out loud. The HUD's own small banner when it has one,
## the ordinary toast until the HUD grows it, and the phase strip moves either way.
func _quiet(text: String, color: Color, phase_key: StringName, seconds: float) -> void:
	if hud.has_method("quiet_beat"):
		hud.quiet_beat(text, color)
	else:
		hud.toast(text, color)
	_mark_phase(phase_key)
	if seconds > 0.0:
		await _beat(seconds)


func _mark_phase(phase_key: StringName) -> void:
	if hud.has_method("mark_phase_event"):
		hud.mark_phase_event(phase_key)


## The referee's own wording for a quiet event when it gave one, else the short form.
func _quiet_line(line: String, fallback: String) -> String:
	var trimmed: String = line.strip_edges()
	return fallback if trimmed.is_empty() or trimmed.length() > 48 else trimmed


## The screen-space centre of a card, for the HUD to point at. (-1, -1) when there is nothing
## to point at: no such card, not drawn, or behind the lens.
func screen_anchor(uid: int) -> Vector2:
	var v: Card3D = views.get(uid)
	if v == null or not v.visible or camera == null or camera.is_position_behind(v.global_position):
		return Vector2(-1, -1)
	return camera.unproject_position(v.global_position)


## Pins the declared attack's public face in the Focus slot for the whole exchange. It stays there
## through the defender's decision and the damage, its caption moving on as the exchange does, and
## is released a short hold after `attack_end`.
func _pin_attack(uid: int, attacker: int, data: Dictionary) -> void:
	_release_pin()
	var def: CardDef = _attack_def(uid, data)
	var named: bool = def != null
	if not named:
		# An attack with no card of its own (a duelist's Power, a Final Strike made from the
		# fighter) still gets a face to read: the personality making it.
		var fighter: SeatCard = view.card(_controlling_uid(attacker))
		if fighter == null or fighter.hidden():
			return
		uid = fighter.uid
		def = _def(fighter)
	if def == null:
		return
	_pinned_attack = uid
	_pinned_def = def
	_answer_title = ""
	_pin_caption(_attack_caption(def.title if named else "", attacker, data), ZenithTheme.ATTACK)


## The card an attack was declared with, or null when it has none. The update's view is read after
## the whole update ran, and by then the card can be somewhere this seat cannot see (a Steel attack
## that goes to the bottom of the Life Deck after use), so the id the declaration carried, public
## the moment it was declared, names it when the view no longer does.
func _attack_def(uid: int, data: Dictionary) -> CardDef:
	if uid < 0:
		return null
	var card: SeatCard = view.card(uid)
	if card != null and not card.hidden():
		return _def(card)
	return Session.library.defs.get(str(data.get("id", "")))


## "Kestrel attacks · Riven Blade", "Your attack · Riven Blade", with Final Strike and a Power
## attack keeping the wording the toast uses. An empty title is an attack with no card behind it.
func _attack_caption(title: String, attacker: int, data: Dictionary) -> String:
	var who: String = "Your attack" if attacker == viewer else "%s attacks" % view.player(attacker).name
	# A named card puts its own title, type and text under the caption, so the caption does not
	# repeat the kind as well; the toast says "Final Strike: X" in the same beat. An attack with
	# no card of its own has only the caption to say what it is.
	if not title.is_empty():
		return "%s · %s power" % [who, title] if bool(data.get("is_power", false)) else "%s · %s" % [who, title]
	var what: String = "a Power" if bool(data.get("is_power", false)) \
		else ("Strike" if str(data.get("kind", "strike")) == "strike" else "Art")
	if bool(data.get("is_final", false)):
		what = "Final Strike"
	elif bool(data.get("focused", false)):
		what = "Focused " + what
	return "%s · %s" % [who, what]


## The caption over the pinned attack, and the slot itself if a prompt or an update boundary took
## it down in between. Nothing happens when no attack is pinned.
func _pin_caption(caption: String, color: Color) -> void:
	if _pinned_attack < 0 or _pinned_def == null:
		return
	_pinned_caption = caption
	_pinned_color = color
	_replay_focus_def = _pinned_def
	if hud.focus.visible and hud._replay_focus:
		hud.set_focus_caption(caption, color)
	else:
		hud.show_replay_card(_pinned_def, caption, color, _pinned_attack)


## Puts the pinned attack back after a prompt or a cleared panel took the slot, so one exchange
## reads as one continuous thing across the updates it spans.
func _restore_pin() -> void:
	if _pinned_attack < 0 or _pinned_def == null:
		return
	_replay_focus_def = _pinned_def
	hud.show_replay_card(_pinned_def, _pinned_caption, _pinned_color, _pinned_attack)


func _stopped_caption() -> String:
	# The stack already names the card that stopped this, so the attack's own caption only says by
	# what when nothing is left on the stack to say it.
	if _answer_title == "" or hud.stack_depth() > 0:
		return "Stopped"
	return "Stopped by %s" % _answer_title


## The attack has been settled one way or the other, so the cards that answered it leave the stack.
## A beat that resolves something the stack never held is simply nothing.
func _pop_defenses() -> void:
	for uid in _defense_uids:
		hud.pop_response(uid)
	_defense_uids.clear()


func _release_pin() -> void:
	hud.clear_stack()
	_defense_uids.clear()
	if _pinned_attack < 0:
		return
	_pinned_attack = -1
	_pinned_def = null
	_pinned_caption = ""
	_answer_title = ""
	_replay_focus_def = null
	hud.hide_focus()


## The card that answered the pinned attack, pushed onto the stack laid over it. False when there
## is nothing public to show, so the caller can keep its ordinary beat.
func _push_response(uid: int, caption: String, player: int, public_id: String = "") -> bool:
	if _pinned_attack < 0:
		return false
	var card: SeatCard = view.card(uid)
	var def: CardDef = _def(card) if card != null and not card.hidden() else Session.library.defs.get(public_id)
	if def == null:
		return false
	_answer_title = def.title
	return hud.push_response(def, caption, _response_role(player), uid)


## Which side of the exchange a response belongs to: the attacker's own follow-up wears the attack
## colour, anything the other seat plays wears the defence colour.
func _response_role(player: int) -> StringName:
	var attacker: int = int(_live.get("attacker", view.attacker))
	return &"attack" if attacker >= 0 and player == attacker else &"defend"


## A defense, a Power, a Shield or a counter answering the pinned attack. It goes onto the stack
## over the attack, so action and reaction are on screen together, and holds on top long enough to
## be read: the opponent's answer longer than the viewer's own, which they just chose.
func _answer_card_beat(uid: int, player: int, targets: Dictionary, caption: String, stopped: bool, public_id: String = "") -> void:
	var card: SeatCard = view.card(uid)
	var v: Card3D = views.get(uid)
	# A held card already waits in the Play slot and leaves when the attack is settled.
	var spent: bool = card != null and not card.hidden() and v != null and card.zone in [&"discard", &"removed"] and targets.has(uid) and not _held.has(uid)
	var def: CardDef = _def(card) if card != null and not card.hidden() else Session.library.defs.get(public_id)
	if def != null and not faces.has_face(def, card.aspect if card != null and not card.hidden() else 1, hud.seat_backdrop(player), player):
		await faces.render_def(def, hud.seat_backdrop(player), player)
	await _sync_layout(true, uid if spent and player != viewer else -1)
	if spent and player != viewer:
		# The opponent's answer visits their resolving slot before the pile, so it is seen leaving
		# the hand rather than appearing in a rail.
		var seat: int = viewer if viewer >= 0 else view.active
		var pile: Transform3D = targets[uid][0]
		if not v.visible or v.transform.origin.distance_to(pile.origin) < 0.02:
			v.transform = zones.slot(player, &"hand", 0, 1, seat)
		v.visible = true
		v.face_up = true
		var enter: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		enter.tween_property(v, "transform", zones.slot(player, &"resolving", 0, 1, seat), FLY_TIME)
		await enter.finished
	var shown: bool = _push_response(uid, caption, player, public_id)
	if v != null and v.visible and card != null and not card.hidden():
		v.flash(ZenithTheme.DEFEND)
		fx.ring(v.global_position, ZenithTheme.DEFEND, 0.7)
	if def != null:
		hud.toast("%s %s" % ["You play" if player == viewer else "Opponent plays", def.title], ZenithTheme.DEFEND)
	var hold: float = ANSWER_READ_OWN
	if player != viewer:
		hold = OPPONENT_STOP_READ if stopped else OPPONENT_DEFENSE_READ
		if def != null:
			hold = clampf(1.2 + float(def.text.length()) * 0.025, hold, 5.5 if stopped else 4.0)
	if shown:
		await _read_beat(hold)
	else:
		await _beat(BEAT)
	if spent and player != viewer:
		await _fly(uid, targets)


## A card that just acted, put in the slot long enough to be read when it carries rules text.
## A pinned attack owns the slot, so a beat inside a Combat keeps its spotlight and nothing else.
func _read_card(uid: int, caption: String) -> void:
	if _pinned_attack >= 0 or hud.focus.visible:
		return
	var card: SeatCard = view.card(uid)
	if card == null or card.hidden():
		return
	var def: CardDef = _def(card)
	if def == null or def.text.strip_edges().is_empty():
		return
	_replay_focus_def = def
	var shown: bool = hud.show_replay_card(def, "%s · %s" % [caption, def.title], ZenithTheme.ACCENT, uid)
	if shown:
		await _read_beat(CARD_USE_READ)
		hud.hide_focus()
	_replay_focus_def = null


## Public opponent cards get a short reading beat before their effects replay. A spent card
## visits its owner's resolving slot, then flies to its final pile after the hold.
func _opponent_card_beat(uid: int, player: int, targets: Dictionary, caption: String, hold: float, color: Color, public_id: String = "") -> void:
	var c: SeatCard = view.card(uid)
	var v: Card3D = views.get(uid)
	var def: CardDef = _def(c) if c != null and not c.hidden() else Session.library.defs.get(public_id)
	if def == null or player < 0 or player >= view.players.size():
		await _sync_layout(true)
		return
	if not faces.has_face(def, c.aspect if c != null and not c.hidden() else 1, hud.seat_backdrop(player), player):
		await faces.render_def(def, hud.seat_backdrop(player), player)
	var spent: bool = c != null and not c.hidden() and v != null and c.zone in [&"discard", &"removed"] and targets.has(uid) and not _held.has(uid)
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
	var shown: bool = hud.show_replay_card(def, caption, color, uid)
	if v != null and v.visible and c != null and not c.hidden():
		v.flash(color)
		fx.ring(v.global_position, color, 0.7)
	hud.toast("Opponent plays %s" % def.title, color)
	if v != null and v.visible and c != null and not c.hidden():
		await v.hop(0.16)
	var maximum: float = 5.5 if caption == "YOUR ATTACK STOPPED" else 4.0
	var read_time: float = clampf(1.2 + float(def.text.length()) * 0.025, hold, maximum)
	if shown:
		await _read_beat(read_time)
	else:
		await _beat(BEAT)
	_replay_focus_def = null
	if shown and _pinned_attack < 0:
		hud.hide_focus()
	# A card used inside a Combat borrowed the slot; the attack it interrupted takes it back.
	_restore_pin()
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
	if v == null or not targets.has(uid) or _held.has(uid):
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


## Holds a card the exchange just used in its owner's Play slot (see `_held`). The caller's next
## `_sync_layout` carries it there. The face is the view's while the view shows the card, else the
## one its event made public. False when the card is not one to hold (it stays in play, or there
## is no public face for it), so the beat keeps its ordinary path.
func _hold(uid: int, seat: int, until: StringName, public_id: String = "") -> bool:
	var v: Card3D = views.get(uid)
	var card: SeatCard = view.card(uid) if uid >= 0 else null
	if v == null or card == null or seat < 0 or seat >= view.players.size():
		return false
	if _held.has(uid):
		return true
	if card.zone not in HOLD_ZONES:
		return false
	if card.hidden():
		var public_def: CardDef = Session.library.defs.get(public_id)
		if public_def != null:
			if not faces.has_face(public_def, 0, CardFace.NO_BACKDROP, card.owner):
				await faces.render_def(public_def, CardFace.NO_BACKDROP, card.owner)
			var key: String = faces.key_of(public_def, 0, CardFace.NO_BACKDROP, card.owner)
			if str(_face_keys.get(uid, "")) != key:
				v.set_face_texture(faces.face(public_def, 0, CardFace.NO_BACKDROP, card.owner))
				_face_keys[uid] = key
		elif not _face_keys.has(uid):
			return false
	# A card the closing layout already put where the exchange leaves it starts from its owner's
	# hand instead, so it is seen coming into play rather than out of a pile.
	var vw: int = viewer if viewer >= 0 else view.active
	var targets: Dictionary = _targets()
	var resting: bool = false
	if targets.has(uid) and card.zone != &"resolving":
		var final_slot: Transform3D = targets[uid][0]
		resting = v.transform.origin.distance_to(final_slot.origin) < 0.02
	if not v.visible or resting:
		v.transform = zones.slot(seat, &"hand", 0, 1, vw)
		v.visible = true
	_held[uid] = {"seat": seat, "until": until}
	return true


## Lets go of the held cards whose part is over (`until`, or every one for &"") and sends each
## where the view says it went: a pile on the felt, or a short flight to its Life Deck, where it
## turns face down and joins the pile. `only` narrows it to one card.
func _release_held(until: StringName, only: int = -1) -> void:
	var going: Array[int] = []
	for key in _held.keys():
		var uid: int = int(key)
		var entry: Dictionary = _held[key]
		if (only < 0 or uid == only) and (until == &"" or StringName(str(entry.get("until", ""))) == until):
			going.append(uid)
	if going.is_empty():
		return
	for uid in going:
		_held.erase(uid)
	var targets: Dictionary = _targets()
	for uid in going:
		var v: Card3D = views.get(uid)
		if v == null:
			continue
		if not targets.has(uid) or not bool(targets[uid][2]):
			v.visible = false
			continue
		await _fly(uid, targets)


## Sweep a discarded Life Deck back into place in one motion. The lost-Life reveal has already
## played; this beat only communicates that the whole pile was reshuffled for Second Wind.
func _fly_recover_batch(cards: Array[int], targets: Dictionary) -> void:
	var tween: Tween = null
	for uid in cards:
		var v: Card3D = views.get(uid)
		if v == null or not targets.has(uid):
			continue
		var entry: Array = targets[uid]
		if not bool(entry[2]):
			continue
		var slot_t: Transform3D = entry[0]
		var target: Transform3D = Transform3D(slot_t.basis * Basis(Vector3.RIGHT, PI), slot_t.origin)
		v.face_up = false
		v.visible = true
		if _reduced_motion:
			v.transform = target
			continue
		if tween == null:
			tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(v, "transform", target, BULK_RECOVER_TIME)
	if tween != null:
		await tween.finished
	elif not _reduced_motion:
		await _beat(BULK_RECOVER_TIME)


## A lost Life card has a visible source: the top of its owner's Life Deck. Lift that same
## Card3D, reveal it briefly over the table, and then send it to its public pile on the felt.
## Other destinations (notably a bypassed Seal) keep the ordinary zone transition.
func _fly_life_loss(uid: int, player: int, targets: Dictionary, label: String, public_id: String = "") -> void:
	var card: SeatCard = view.card(uid)
	var v: Card3D = views.get(uid)
	var returning: bool = _second_wind_returning.has(uid)
	if player < 0 or player >= view.players.size() or card == null or (card.hidden() and not returning) or v == null or not targets.has(uid) or (card.zone not in [&"discard", &"removed"] and not returning):
		await _fly(uid, targets)
		return
	var entry: Array = targets[uid]
	if not bool(entry[2]):
		return
	var counts: Array = _live.get("zones", [])
	var seat_counts: Array = counts[player] if player < counts.size() else []
	var target: Transform3D = zones.slot(player, &"discard", maxi(0, int(seat_counts[2]) - 1), 1, viewer if viewer >= 0 else view.active) if returning and seat_counts.size() > 2 else entry[0]
	if returning and card.hidden() and public_id != "":
		var public_def: CardDef = Session.library.defs.get(public_id)
		if public_def != null:
			if not faces.has_face(public_def, 0, CardFace.NO_BACKDROP, card.owner):
				await faces.render_def(public_def, CardFace.NO_BACKDROP, card.owner)
			v.set_face_texture(faces.face(public_def, 0, CardFace.NO_BACKDROP, card.owner))
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
	# A world-height apex can leave the screen as the camera tilts, so position and size this
	# short reveal in screen space, standing up to face the lens, instead.
	var source_screen: Vector2 = camera.unproject_position(deck_pos)
	var target_screen: Vector2 = camera.unproject_position(cards_root.to_global(target.origin))
	var reveal_screen: Vector2 = source_screen.lerp(target_screen, 0.38) + Vector2(0, -42)
	var source_depth: float = -camera.to_local(deck_pos).z
	var target_depth: float = -camera.to_local(cards_root.to_global(target.origin)).z
	var reveal_depth: float = lerpf(source_depth, target_depth, 0.38)
	var reveal_scale: float = 112.0 * _units_per_pixel(reveal_depth) / TableLayout.CARD_SIZE.y
	var facing: Basis = camera.global_basis * Basis(Vector3.RIGHT, PI * 0.5)
	var reveal: Transform3D = Transform3D(facing.scaled(Vector3.ONE * reveal_scale), camera.project_position(reveal_screen, reveal_depth))
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
func _beat(seconds: float, scaled: bool = true) -> void:
	if _dev_freeze != &"" and _replaying == _dev_freeze and not _dev_done:
		await _dev_finish(0.03, true)
		return
	await get_tree().create_timer(_beat_length(seconds, scaled)).timeout


## A hold that exists so a card can be read, rather than to pace an animation. A queue of pending
## work does not shorten it: a busy Combat is exactly when the card most needs its time. Space,
## `--dev-fast` and `--dev-freeze` all still apply.
func _read_beat(seconds: float) -> void:
	await _beat(seconds, false)


## How long a beat actually holds. A queue of work shortens every beat in it, so a turn with ten
## jobs pending does not take ten times as long to watch as a turn with one, and holding Space
## through a replay drops straight to the floor. A frozen capture keeps the authored timing.
func _beat_length(seconds: float, scaled: bool = true) -> float:
	if _dev_freeze != &"":
		return seconds
	if _skip_held():
		return SKIP_BEAT
	return maxf(SKIP_BEAT, seconds * (_pending_scale() if scaled else 1.0))


func _pending_scale() -> float:
	var queued: int = view.pending.size() if view != null else 0
	if queued >= 6:
		return 0.35
	if queued >= 3:
		return 0.6
	return 1.0


## Hold to skip: Space runs the rest of a replay at the floor. It is never a way to answer a
## prompt, so it does nothing while the viewer is being asked something or while the hand is
## being browsed from the keyboard, where Space inspects.
func _skip_held() -> bool:
	if _replaying == &"" or _dev_autoplay or hand_3d.keyboard_active:
		return false
	if _can_choose():
		return false
	return Input.is_key_pressed(KEY_SPACE)


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
	if view == null:
		return
	var attacker: int = int(view.attack.get("attacker", -1)) if not view.attack.is_empty() else -1
	# The roles outlive the attack dictionary: whoever is swinging and whoever is answering keep
	# their glow for the whole of the Attack, Defend, Battle and Fight Back phases.
	if attacker < 0 and int(view.phase) in COMBAT_ROLE_PHASES:
		attacker = view.attacker
	var deciding: int = view.deciding if view.deciding_kind == &"respond" else -1
	for p in view.players:
		var color: Color = Color(0, 0, 0, 0)
		if attacker >= 0:
			color = ZenithTheme.ATTACK if p.index == attacker else ZenithTheme.DEFEND
		# The act-here gold outranks the role colour while this seat owes a response.
		if p.index == deciding:
			color = ZenithTheme.ACCENT
		var personalities: Array[int] = [p.duelist]
		personalities.append_array(p.allies)
		for uid in personalities:
			var v: Card3D = views.get(uid)
			if v == null:
				continue
			var carries: bool = uid == p.controlling
			v.set_role(color if carries else Color(0, 0, 0, 0))


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
	# The final view may already have spent the attack card. A route from its discard pile
	# back across the table would pull attention away from the two fighters.
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
	_their_presence = {}
	_draw_presence(false)
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


# --- Presence -------------------------------------------------------------

## What this player is doing right now, in `PresenceState` terms. A hand hover is a slot index
## only; a table card is named only when both seats can see it; the pointer is a point on the
## felt in the shared layout, and is left off while it is over the HUD, an overlay, the hand, or
## outside a window that has lost focus.
func _local_presence(board_interactive: bool) -> Dictionary:
	var state: Dictionary = PresenceState.idle()
	if view == null or viewer < 0:
		return state
	var look: Dictionary = hud.presence_look(view)
	for key in look.keys():
		state[key] = look[key]
	var mouse: Vector2 = get_viewport().get_mouse_position()
	if not get_window().has_focus() or not get_viewport().get_visible_rect().has_point(mouse):
		return state
	var hand_uid: int = hand_3d.hovered_uid()
	if hand_uid >= 0 and _hand_blocks_board():
		state["hand"] = view.player(viewer).hand.find(hand_uid)
		return state
	if not board_interactive or _pointer_over_hud():
		return state
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit == null:
		return state
	var point: Vector3 = hit
	var shared: Vector2 = Vector2(point.x, point.z)
	if not PresenceState.TABLE_BOUNDS.has_point(shared):
		return state
	state["on"] = true
	state["x"] = shared.x
	state["z"] = shared.y
	if _hover_uid >= 0 and PresenceState.is_public(view.card(_hover_uid)):
		state["card"] = _hover_uid
	return state


## A HUD control with its own mouse handling is under the pointer (the log, the phase strip, a
## button). The full-screen HUD root passes the table through, so it does not count.
func _pointer_over_hud() -> bool:
	var over: Control = get_viewport().gui_get_hovered_control()
	return over != null and over != hud.root


## `--dev-presence-demo`: a scripted pointer instead of the mouse, for a screenshot on the other
## instance. `=card` circles over our own Mastery, `=hand` reads a hand slot, `=look` has the
## rival's Discard open; the bare flag cycles through the three.
func _demo_presence() -> Dictionary:
	var state: Dictionary = PresenceState.idle()
	if view == null or viewer < 0:
		return state
	var t: float = Time.get_ticks_msec() / 1000.0
	var phase: String = _presence_demo
	if phase == "cycle":
		var at: float = fmod(t, 5.0)
		phase = "card" if at < 2.5 else ("hand" if at < 4.0 else "look")
	var hand: Array[int] = view.player(viewer).hand
	if phase == "hand" and not hand.is_empty():
		state["hand"] = mini(1, hand.size() - 1)
		return state
	if phase == "look":
		state["look"] = "pile"
		state["seat"] = 1 - viewer
		state["zone"] = "discard"
		return state
	# Our own Mastery when there is one: a public card with no fight role glowing over the hover.
	var target: int = view.player(viewer).mastery if view.player(viewer).mastery >= 0 else view.player(1 - viewer).duelist
	var card: Card3D = views.get(target)
	if card == null:
		return state
	var centre: Vector3 = card.global_position
	var shared: Vector2 = Vector2(centre.x + cos(t * 1.7) * 0.15, centre.z + sin(t * 2.3) * 0.2)
	state["on"] = true
	state["x"] = shared.x
	state["z"] = shared.y
	state["card"] = target
	return state


## The other player's presence arrived. Sanitised here again whatever the relay did.
func _on_presence(raw: Dictionary) -> void:
	var clean: Dictionary = PresenceState.sanitise(raw)
	if clean.is_empty():
		return
	_their_presence = clean
	_draw_presence(true)


## Draws the other player's presence against our own view: their card highlight, the face-down
## hand card they are reading, the pointer and the line saying what they have open. `heard` is
## false for a redraw after our view changed, which must not refresh the pointer's fade clock.
func _draw_presence(heard: bool) -> void:
	var state: Dictionary = PresenceState.for_view(_their_presence, view)
	var drawable: bool = not state.is_empty() and view != null and viewer >= 0
	var rival: int = 1 - viewer
	var color: Color = Session.seat_color(rival) if drawable else Color.TRANSPARENT
	var slot: int = -1
	var card_uid: int = -1
	if drawable:
		if int(state["hand"]) < view.player(rival).hand.size():
			slot = int(state["hand"])
		card_uid = int(state["card"])
		if not views.has(card_uid) or not (views[card_uid] as Card3D).visible:
			card_uid = -1
	# Their hand is the fan of backs on their fixture; the slot they read rises in it.
	far_duelist.readout.set_peek(slot)
	if card_uid != _presence_card:
		if views.has(_presence_card):
			(views[_presence_card] as Card3D).set_presence(Color.TRANSPARENT)
		_presence_card = card_uid
	if views.has(card_uid):
		(views[card_uid] as Card3D).set_presence(color)
	if not drawable:
		presence.clear()
		hud.set_presence_line("", Color.WHITE)
		return
	if heard:
		var fan: Variant = far_duelist.peek_screen(slot, camera) if slot >= 0 else null
		var over_fan: Variant = null
		if fan != null:
			over_fan = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(fan), camera.project_ray_normal(fan))
		if over_fan != null:
			presence.place(over_fan)
		elif bool(state["on"]):
			presence.place(Vector3(float(state["x"]), 0.0, float(state["z"])))
		else:
			presence.place(null)
	hud.set_presence_line(_presence_text(state, rival), color)


func _presence_text(state: Dictionary, rival: int) -> String:
	var who: String = view.player(rival).name
	match str(state["look"]):
		"pile":
			var whose: String = "their" if int(state["seat"]) == rival else "your"
			return "%s is viewing %s %s" % [who, whose, str(PRESENCE_ZONES.get(str(state["zone"]), "pile"))]
		"inspect":
			var c: SeatCard = view.card(int(state["look_card"]))
			return "%s is reading %s" % [who, c.title] if c != null else ""
		"log":
			return "%s is reading the log" % who
		"choice":
			return "%s is choosing" % who
	return ""


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
	if pile.x >= 0 and PILE_ZONES[pile.y] == &"relic":
		_open_relic_pile(pile.x)
		return
	if pile.x >= 0 and (not _can_choose() or prompt.options_for_card(uid).is_empty()):
		hud.show_pile(view, pile.x, PILE_ZONES[pile.y])
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


## A click on the felt of a pile (Discard, Removed, or the Relic with its Reserve), including its
## caption: read the pile. The felt only hears clicks that miss every card, since a card's own
## pick box sits above it, so a pile card that is a choice still answers for itself.
func _on_pile_clicked(player: int, zone: StringName) -> void:
	if view == null or hud.pile.visible:
		return
	if _hand_blocks_board() or _preview_blocks_point(hud.root.get_global_mouse_position()):
		return
	if zone == &"relic":
		_open_relic_pile(player)
		return
	hud.show_pile(view, player, zone)


## The Relic and its Reserve are one pile. A Relic usable now carries the legal-card frame, and a
## click on its pile asks whether to use it or read the pile; otherwise the click reads the pile.
func _open_relic_pile(player: int) -> void:
	var relic: int = view.player(player).relic
	var uses: Array[OptionView] = []
	if _can_choose() and relic >= 0:
		uses = prompt.options_for_card(relic)
	if uses.is_empty():
		hud.show_pile(view, player, &"relic")
	else:
		hud.show_relic_choice(uses, player)


## Which pile a card is sitting in: (player, i) with i indexing PILE_ZONES, (-1, -1) for
## anywhere else. A standing effect's source is lifted out of the Removed pile and stood beside
## its owner, so it answers for itself rather than for the pile it came from.
func _pile_of(uid: int) -> Vector2i:
	if view == null or _standing_uids().has(uid):
		return Vector2i(-1, -1)
	for p in view.players:
		if p.discard.has(uid):
			return Vector2i(p.index, 0)
		if p.removed.has(uid):
			return Vector2i(p.index, 1)
		if p.relic == uid or p.reserve.has(uid):
			return Vector2i(p.index, 2)
	return Vector2i(-1, -1)


func _on_card_hovered(uid: int, over: bool) -> void:
	if over:
		_hover_uid = uid
	elif _hover_uid == uid:
		_hover_uid = -1
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
		var backdrop: Color = hud.seat_backdrop(c.owner)
		var key: String = faces.key_of(def, c.aspect, backdrop, c.owner)
		if str(_face_keys.get(uid, "")) != key:
			v.set_face_texture(faces.face(def, c.aspect, backdrop, c.owner))
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
		# The two public piles are stacks on the felt beside the Life Deck, face up, the last
		# card in each list on top.
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
		for i in range(p.remain.size()):
			out[p.remain[i]] = [zones.slot(p.index, &"remain", i, p.remain.size(), vw), true, true]
		out[p.duelist] = [zones.slot(p.index, &"duelist", 0, 1, vw), true, true]
		# An adventure boss's special power stands beside its Mastery, face up and clickable.
		var mastery_n: int = int(p.mastery >= 0) + int(p.boss_power >= 0)
		if p.mastery >= 0:
			out[p.mastery] = [zones.slot(p.index, &"mastery", 0, mastery_n, vw), true, true]
		if p.boss_power >= 0:
			out[p.boss_power] = [zones.slot(p.index, &"mastery", mastery_n - 1, mastery_n, vw), true, true]
		var reserve_n: int = p.reserve.size()
		if p.relic >= 0:
			out[p.relic] = [zones.slot(p.index, &"relic", 0, reserve_n + 1, vw), true, true]
		for i in range(reserve_n):
			# Reserve cards sit face down under the Relic, their edges fanned out behind it; only
			# their owner sees them, in the prompt.
			out[p.reserve[i]] = [zones.slot(p.index, &"relic", i + 1, reserve_n + 1, vw), false, true]
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
	# While the exchange holds a card in play the arena is live (`_set_arena`).
	_exchange_live = not view.resolving.is_empty() or not _held.is_empty()
	var in_play_slot: Array[int] = [0, 0]
	for uid in view.resolving:
		if not out.has(uid):
			var owner: int = view.card(uid).owner
			out[uid] = [zones.slot(owner, &"resolving", 0, 1, vw), true, true]
			if not _held.has(uid) and owner >= 0 and owner < in_play_slot.size():
				in_play_slot[owner] += 1
	# A card the exchange is still using stays in its owner's Play slot, face up, wherever the view
	# says it has gone (`_held`). A second one of the same seat stacks just above the first.
	for key in _held.keys():
		var entry: Dictionary = _held[key]
		var seat: int = int(entry.get("seat", 0))
		var held_slot: Transform3D = zones.slot(seat, &"resolving", 0, 1, vw)
		if seat >= 0 and seat < in_play_slot.size():
			held_slot.origin.y += HELD_STEP * in_play_slot[seat]
			in_play_slot[seat] += 1
		out[int(key)] = [held_slot, true, true]
	return out


## Energy marks on duelists and Allies in play. Fervor lives on the stat tracker only.
func _refresh_markers() -> void:
	var live_energy: Dictionary = _live.get("energy", {})
	var live_might: Dictionary = _live.get("might", {})
	var wanted: Dictionary = {}   # uid -> [energy, SeatPlayer or null, might, owner]
	for p in view.players:
		wanted[p.duelist] = [_live_energy(live_energy, p.duelist), p, -1, p.index]
		for uid in p.allies:
			wanted[uid] = [_live_energy(live_energy, uid), null, _live_might(live_might, uid), p.index]
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
			m.setup(faces.ladder_rects(), CardFace.lit_color(hud.seat_backdrop(int(wanted[uid][3])), true))
			_markers[uid] = m
		m.set_status(int(wanted[uid][0]), wanted[uid][1] as SeatPlayer, int(wanted[uid][2]))


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
	# Online, while both seats decide at once, the other seat's update can play underneath our
	# open decision and never presents it again, so a step that lands in it waits it out.
	while busy and online and not _dev_done:
		await get_tree().process_frame
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
				var zone: StringName = StringName(parts[1]) if parts.size() > 1 and parts[1] in ["removed", "relic"] else &"discard"
				await hud.show_pile(view, player, zone)
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
	if _presence_on and _presence_demo != "":
		# A demo sender stays up a little, so the other instance can screenshot what it sends.
		await get_tree().create_timer(PRESENCE_DEMO_LINGER, true, false, true).timeout
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
