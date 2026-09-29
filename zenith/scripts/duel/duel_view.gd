extends Node3D
## The playspace. Renders one seat's SeatView: a Card3D per uid the view lists, table tweens
## after every update, and every decision routed through the HUD prompt or a card click.
## Hotseat and hosting: a Referee lives here and the viewer's choices go straight to it.
## Hotseat: the camera swings to whichever player has to decide, behind a hand-off overlay.
## Against the AI: the viewer is pinned to the person's seat and an AiPlayer answers for the other.
## Online: the viewer is pinned to this client's seat. The host applies the joiner's commands
## through its Referee and sends seat 1 its update; the joiner holds no engine at all.

const CARD_SCENE: PackedScene = preload("res://scenes/duel/card_3d.tscn")
## The title screen's script, which keeps which queue a client sent back to it waits in.
const TITLE: Script = preload("res://scripts/main.gd")
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
const AI_GRACE_MS: int = 3000         # past the profile's think budget, the AI's decision falls back
const LEAVE_FLUSH: float = 0.25       # real seconds a concession gets to go out before the connection closes
const REJOIN_RETRY_MS: int = 3000     # between attempts to get back into a server duel after a drop
const DEV_LINGER: float = 4.0         # real seconds a dev client stays up after its shot, so the other side's shot is not spoiled
const DEV_CONCEDE_WAIT: float = 3.0   # `--dev-concede`: real seconds the conceding client stays connected
const STALL_MS: int = 1200            # a hidden decision panel this long is a stall, not a beat
## An attachment lies under its host and peeks past the host's outer edge, the one away from the
## centre line: its sides hold the Mastery and the Ally wing, its inner edge meets the rival's card.
const ATTACH_OFFSET: Vector3 = Vector3(0.0, -0.002, 0.26)
const ATTACH_SCALE: float = 0.78
const PILE_ZONES: Array[StringName] = [&"discard", &"removed", &"relic"]   # indexed by _pile_of().y
## Where a used card can be by the time its beat replays. A card that stays in play (an Ally, a
## Drill, a Remain card) is never held: its own zone is where it is read.
const HOLD_ZONES: Array[StringName] = [&"resolving", &"discard", &"removed", &"life_deck"]
const ARENA_FADE: float = 0.35        # seconds for the table to dim or come back around an exchange
## The stat plaques stand up through the veil and their numbers change during exchanges, so they
## only dim a little.
const PLATE_DIM: Color = Color(0.85, 0.85, 0.85)
const ARENA_COMBAT: float = 0.6       # the veil through a Combat, between exchanges
const HANDOVER_BEAT: float = 0.8      # a change of hands: Combat opening, a fight back, a new turn
const HANDOVER_FLOOR: float = 0.4     # a busy queue shortens a hand-over no further than this
## Hit weight, from `hit_tier`: a chip, a solid hit, a heavy one. Each tier's impact size, card
## shake, pause on the contact frame, and damage number size.
enum { CHIP, SOLID, HEAVY }
const HIT_IMPACT: Array[float] = [0.6, 1.0, 1.5]
const HIT_SHAKE: Array[float] = [0.03, 0.05, 0.08]
const HIT_STOP: Array[float] = [0.0, 0.05, 0.12]
const HIT_FLOAT: Array[int] = [64, 80, 104]
const LETHAL_HOLD: float = 0.6        # the wound that empties a Life Deck holds before anything moves on
const GAME_OVER_HOLD: float = 1.0     # the table stays in view a moment before the result covers it
const OVERFLOW_SLIDE: float = 0.4
const FLAG_ROW_INSET: float = 0.3     # the chips start this far inside the first Ally slot's centre
const FLAG_ROW_EDGE: float = 2.5      # and stop this far from the duelist's centre line, at the row's end
const FOCUS_FADE_TIME: float = 0.18   # a new rail card's fade-in; it never changes size
const FILAMENT_HAND_ALPHA: float = 0.3
const TABLE_CENTRE: Vector3 = Vector3(0, 0.02, 0)

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
@onready var phase_track: PhaseTrack = $PhaseTrack
@onready var turn_token: TurnToken = $TurnToken
@onready var lead_in_overlay: LeadInOverlay = $LeadInOverlay

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
var _dev_concede: bool = false       # `--dev-concede`: online, concede when the step budget runs out
var _dev_find_another: bool = false  # `--dev-find-another`: a finished queue duel presses Find another duel
var _dev_stall: int = -1             # `--dev-stall=N`: online autoplay answers N decisions, then none
var _dev_answered: int = 0
var _dev_clock_shot: String = ""     # `--dev-clock-shot=<phase>`: the screenshot once a clock reaches that phase
var _dev_away_shot: String = ""      # `--dev-away-shot=<png>`: a shot when the rival drops, another when they are back
var _dev_next_game: bool = false     # `--dev-next-game`: ranked, press Next game as soon as it shows
var _dev_leave_match: bool = false   # `--dev-leave-match=N`: ranked, leave the match when the step budget runs out
var _room_code: String = ""          # server room: the room this duel runs in
## How this duel was reached, fixed when the scene is built: Net forgets its room when the
## connection drops, and the result still has to know which buttons it offers.
var _mode: DuelHud.Mode = DuelHud.Mode.LOCAL
## Ranked: this duel is a game of a match. The game and score as the match stood at the deal, then
## what the match has said since this game ended: the score between games (`Net.last_game_over`)
## and the decided match (`Net.last_match`). Both wait for the game's own result to be up.
var _ranked: bool = false
var _series_game: int = 0
var _series_wins: Array[int] = [0, 0]
var _series_over: Dictionary = {}
var _match_payload: Dictionary = {}
## The facts the result card is drawn from (`_sync_result`). `_shown`: this game's result is up.
## How it ended, the rules' line for it offline, and what the rival and this seat have done since.
var _shown: bool = false
var _game_winner: int = -1
var _game_reason: String = ""
var _rules_text: String = ""
var _rival_asked: bool = false       # the rival asked for a rematch
var _rematch_sent: bool = false      # this seat asked, in a server room where the server waits for both
var _rival_gone: bool = false        # the rival left, or the connection did, so no rematch can be dealt
var _gone_note: String = ""
var _ready_sent: bool = false        # ranked between games: this seat pressed Ready
var _lost: Dictionary = {}           # the connection is gone for good: {"text"} or {"heading", "text"}
var _dev_seen: int = DuelHud.ResultState.NONE   # the last result state the dev shots saw
## Server room, cut off mid-duel: when this client stops trying to get back in and when it tries
## next (ticks msec), 0 while connected.
var _reconnect_until: int = 0
var _reconnect_next: int = 0
## Online: the duel ended outside the rules (a concession, the other player leaving, a lost
## connection). The table stops where it stands and nothing presents a decision again.
var _ended: bool = false
var _ai_generation: int = 0          # bumped per AI decision, so a coroutine for an older one stands down
var _ai_task: int = -1               # the AI search on the worker pool, -1 when none is running
var _wounds: int = 0                 # life cards flipped by the attack being replayed
var _hit_tier: int = -1              # the replayed attack's weight once its damage is known, else -1
var _hit_said: String = ""           # what "Hits for" banner named, so the result is not said twice
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
var _arena_amount: float = 0.0       # how far the table is dimmed now (`_set_arena`)
var _combat_opening: bool = false    # Combat was declared and its first exchange has not begun
var _opening_attacker: int = -1      # who attacks first, when this update also opens the Combat
var _opening_said: bool = false      # the Combat banner already named the first attacker
var _arena_fade: Tween = null
var _focus_fade: Tween = null
var _focus_faded_uid: int = -1       # the rail card that last faded in, so it fades once
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
## A recorded duel played back (`--dev-replay`): the cursor holds the only referee, and there is no
## AI, no Net and no decision to make. The table plays the cursor's updates as it played live ones.
var _cursor: ReplayCursor = null
var _replay_file: String = ""        # `--dev-replay=<path>[:<record id>]`
var _replay_id: String = ""
var _replay_index: int = 0           # the cursor update shown: seat 0, seat 1 or ReplayCursor.ALL
var _replay_to: int = -1             # `--dev-replay-to=N`: open at entry N
var _replay_playing: bool = false
const REPLAY_READ: float = 0.7       # while playing, each recorded decision stays up this long first
const INTRO_FLIGHT: float = 7.0      # the camera's flight in under an adventure lead-in
const INTRO_LAND: float = 0.8        # what is left of that flight once the lead-in closes
var _faces_ready: bool = false       # the opening decks' faces have rendered
var _hands_hidden: bool = false      # a lead-in is up: both hands stay off the table
var _dev_lead_in_shot: float = -1.0  # `--dev-lead-in-shot=<seconds>`: a shot that far into the lead-in


func _ready() -> void:
	online = Net.active()
	authority = not online or Net.is_authority()
	_parse_dev_args()
	hud.external_hand = true
	hud.scene_flags = true
	hud.reduced_motion_changed.connect(_set_reduced_motion)
	hud.focus_face.visible = false
	hand_3d.rail_clear = -hud.RAIL_LEFT
	hand_3d.clicked.connect(_on_card_clicked)
	hand_3d.inspected.connect(_on_card_inspected)
	hand_3d.hovered.connect(_on_hand_hovered)
	for fixture in [near_duelist, far_duelist]:
		fixture.clicked.connect(_on_card_clicked)
		fixture.inspected.connect(_on_card_inspected)
		fixture.hovered.connect(_on_card_hovered)
	_set_reduced_motion(ArcaneBackdrop.motion_reduced())
	fx.prewarm()
	hud.option_chosen.connect(_on_option_chosen)
	hud.card_clicked.connect(_on_card_clicked)
	hud.handoff_confirmed.connect(_on_handoff_confirmed)
	hud.rematch_requested.connect(_on_rematch)
	hud.select_requested.connect(_on_select)
	hud.title_requested.connect(_on_title)
	hud.find_requested.connect(_on_find_another)
	hud.concede_requested.connect(_on_concede)
	hud.concede_match_requested.connect(_on_concede_match)
	hud.leave_requested.connect(_on_leave)
	hud.dev_command.connect(_on_dev_command)
	zones.pile_clicked.connect(_on_pile_clicked)
	if not _start_lead_in():
		hud.set_loading(true)
	if _replay_file != "":
		await _ready_replay()
		return
	if online:
		viewer = Net.local_player
		rig.rotation.y = 0.0 if viewer == 0 else PI
		Net.command_rejected.connect(_on_net_rejected)
		Net.peer_left.connect(_on_peer_left)
		Net.duel_ended.connect(_on_duel_ended)
		Net.connection_failed.connect(_on_connection_failed)
		Net.rematch_requested.connect(_on_rematch_requested)
		Net.clock_changed.connect(_on_clock)
		Net.peer_away.connect(_on_peer_away)
		Net.peer_back.connect(_on_peer_back)
		Net.game_over.connect(_on_series_game_over)
		Net.match_over.connect(_on_match_over)
		hud.give_up_requested.connect(_on_give_up)
		hud.next_game_requested.connect(_on_next_game)
		hud.ranked_requested.connect(_on_find_ranked)
		hud.tick.timeout.connect(_on_tick)
		_ranked = Net.ranked_room()
		_mode = DuelHud.Mode.RANKED if _ranked else (DuelHud.Mode.QUEUE if Net.queue_room() else DuelHud.Mode.CODE)
		hud.set_mode(_mode, Net.can_rematch(), Net.server_room())
		_series_game = maxi(1, Net.series_game) if _ranked else 0
		_series_wins = [Net.series_wins[0], Net.series_wins[1]]
		# Facts that arrived before this scene was built belong to this game: the deal cleared them.
		_series_over = Net.last_game_over.duplicate()
		_match_payload = Net.last_match.duplicate()
		_room_code = Net.room_code
		# A duel or a match that ended while this scene was loading: its signal went to the scene
		# before, so the result is taken from the facts Net kept.
		var ended: Dictionary = Net.last_duel_ended
		if not ended.is_empty():
			_game_winner = int(ended.get("winner", -1))
			_game_reason = str(ended.get("reason", ""))
			_rival_gone = _game_reason == "left" and _game_winner == viewer
		if not ended.is_empty() or not _match_payload.is_empty():
			_end_table()
	elif Session.ai_seat >= 0:
		ai_seat = Session.ai_seat
		viewer = 1 - ai_seat
		rig.rotation.y = 0.0 if viewer == 0 else PI
	if Session.in_adventure():
		_mode = DuelHud.Mode.ADVENTURE
		hud.set_mode(_mode, false)
	_sync_result()
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


## Plays the adventure lead-in Session holds over the table while the camera flies in and the
## faces render, in place of the loading screen. False when there is none to play.
func _start_lead_in() -> bool:
	var scene: Dictionary = Session.lead_in
	Session.lead_in = {}
	if scene.is_empty() or online or _replay_file != "" or (_dev_autoplay and _dev_lead_in_shot < 0.0):
		return false
	hud.visible = false
	_hands_hidden = true
	lead_in_overlay.finished.connect(_on_lead_in_closed)
	lead_in_overlay.play(scene, Session.library)
	if not _reduced_motion:
		camera.fly_in(INTRO_FLIGHT)
	if _dev_lead_in_shot >= 0.0:
		_dev_lead_in_screenshot()
	return true


## The flight finishes quickly. A player who closed the lead-in before the faces were ready sees
## the loading screen for what is left.
func _on_lead_in_closed() -> void:
	camera.land(INTRO_LAND)
	if not _faces_ready:
		hud.visible = true
		hud.set_loading(true)


## Alone it saves the shot and quits. Under `--dev-autoplay` the shot goes to `<png>_lead_in.png`,
## the lead-in closes and autoplay goes on to its own shot.
func _dev_lead_in_screenshot() -> void:
	await get_tree().create_timer(_dev_lead_in_shot).timeout
	await RenderingServer.frame_post_draw
	var path: String = _dev_screenshot.get_basename() + "_lead_in.png" if _dev_autoplay else _dev_screenshot
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved to %s" % path)
	if _dev_autoplay:
		lead_in_overlay.close()
	else:
		_dev_shutdown()


func _set_reduced_motion(on: bool) -> void:
	_reduced_motion = on
	ArcaneBackdrop.reduced_motion = on
	$Atmosphere.reduced_motion = on
	fx.reduced_motion = on
	presence.reduced_motion = on
	phase_track.reduced_motion = on
	hand_3d.reduced_motion = on
	near_duelist.reduced_motion = on
	far_duelist.reduced_motion = on
	hud.reduced_motion_toggle.set_pressed_no_signal(on)
	for card in views.values():
		(card as Card3D).reduced_motion = on


func _process(_delta: float) -> void:
	if not is_instance_valid(hud):
		return
	var overlay: bool = hud.tray.visible or hud.pile.visible or hud.inspect.visible or hud.handoff.visible or hud.loading.visible \
		or hud.modal.visible or _hands_hidden
	# The options menu takes the input (its shade the mouse, the HUD the keys) but hides nothing.
	var menu: bool = hud.options_menu.visible
	hand_3d.set_available(view != null and viewer >= 0 and not overlay)
	hand_3d.enabled = _can_choose()
	camera.hand_navigation = hand_3d.keyboard_active or overlay or menu
	var hand_blocks: bool = _hand_blocks_board()
	var preview_blocks: bool = _preview_blocks_point(hud.root.get_global_mouse_position())
	var board_interactive: bool = not overlay and not menu and not hand_blocks and not preview_blocks
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
	if _reconnect_until > 0:
		_keep_reconnecting()
	# The thread to the target would cross the hand's reading preview, so it steps back while the
	# hand is open.
	hud.filament.modulate.a = FILAMENT_HAND_ALPHA if hand_3d.revealed else 1.0
	focus_card.visible = hud.focus.visible and not overlay
	# A new card on the rail fades in at its full, fixed size, so it is noticed without moving. The
	# same card coming back from under an overlay is not new.
	if not hud.focus.visible:
		_focus_faded_uid = -1
	if focus_card.visible and hud._focus_card_uid != _focus_faded_uid:
		_focus_faded_uid = hud._focus_card_uid
		if _focus_fade != null and _focus_fade.is_valid():
			_focus_fade.kill()
		focus_card.modulate.a = 1.0 if _reduced_motion else 0.0
		if not _reduced_motion:
			_focus_fade = create_tween()
			_focus_fade.tween_property(focus_card, "modulate:a", 1.0, FOCUS_FADE_TIME)
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
	_set_arena(_arena_level())


## How far the table recedes, from the phase the beat belongs to: part way for the whole of a
## Combat, fully while an exchange holds a card in play, not at all outside Combat. Following the
## phase rather than the held card keeps the veil down between exchanges instead of pumping.
func _arena_level() -> float:
	if view == null or view.is_over():
		return 0.0
	# A Final Strike or a Power attack holds no card, so the attack in the air counts too.
	if _exchange_live or not _attack_cue.is_empty():
		return 1.0
	var step: int = int(_live.get("step", view.step))
	var phase: int = int(_live.get("phase", view.phase))
	var in_combat: bool = step == GameState.Step.COMBAT and phase != GameState.Phase.NONE
	return ARENA_COMBAT if in_combat or _combat_opening else 0.0


## The table recedes behind a veil to `level`, the camera leans in on the ring at full level, and
## the ring pulses once as Combat opens. The focus card and the decision stay on the rail. Reduced
## motion keeps the dimming and drops the moves.
func _set_arena(level: float) -> void:
	camera.arena_focus = level >= 1.0 and not _reduced_motion
	if is_equal_approx(level, _arena_amount):
		return
	var from: float = _arena_amount
	_arena_amount = level
	if _arena_fade != null and _arena_fade.is_valid():
		_arena_fade.kill()
	var veil: ShaderMaterial = arena_veil.material_override
	var plate_tint: Color = Color.WHITE.lerp(PLATE_DIM, level)
	arena_veil.visible = true
	if _reduced_motion:
		veil.set_shader_parameter("amount", level)
		arena_veil.visible = level > 0.0
		for fixture: DuelistDisplay in [near_duelist, far_duelist]:
			fixture.plate_face.modulate = plate_tint
		return
	var shown: float = float(veil.get_shader_parameter("amount")) if veil.get_shader_parameter("amount") != null else from
	_arena_fade = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arena_fade.tween_method(func(value: float) -> void: veil.set_shader_parameter("amount", value), shown, level, ARENA_FADE)
	for fixture: DuelistDisplay in [near_duelist, far_duelist]:
		_arena_fade.tween_property(fixture.plate_face, "modulate", plate_tint, ARENA_FADE)
	if level <= 0.0:
		_arena_fade.chain().tween_callback(func() -> void: arena_veil.visible = false)
		return
	if from <= 0.0:
		fx.ring(TABLE_CENTRE, ZenithTheme.ACCENT, 1.6)


## Safety net, not a mechanism. The table runs on awaits, and a decision panel that never comes
## back reads as a softlock: the viewer owes a move and there is nothing on screen to make it
## with. Nothing should reach this, so it says so and puts the prompt back rather than leaving
## the duel stuck.
func _watch_for_stall(overlay: bool) -> void:
	var owed: bool = view != null and not view.is_over() and prompt != null and viewer >= 0 		and view.deciding == viewer and prompt.player == viewer
	if not owed or busy or _awaiting_answer or overlay or _dev_done or hud.prompt_panel.visible or _cursor != null:
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
		fixture.flag_row = _flag_row(owner)
		fixture.plate_home = zones.to_global(zones.plate_point(owner))
		fixture.anchor_to_card(card, camera)
	if viewer >= 0 and near_duelist.visible:
		near_duelist.readout.update_layout()
		hand_3d.set_crest_rect(near_duelist.screen_rect(camera))
	if not hud.focus.visible:
		return
	var face_rect: Rect2 = hud.focus_face_rect()
	focus_card.position = camera.to_local(camera.project_position(face_rect.get_center(), depth))
	focus_card.pixel_size = face_rect.size.x / 512.0 * units


## Where a seat's status chips are printed: along its Ally row, the row the fewest decks use, from
## the inside edge of its first slot out to the row's far end. World points, inner end first.
func _flag_row(owner: int) -> PackedVector3Array:
	var first: Vector3 = zones.slot(owner, &"ally", 0, 3, viewer).origin
	var last: Vector3 = zones.slot(owner, &"ally", 2, 3, viewer).origin
	var outward: float = signf(last.x - first.x)
	var inner: Vector3 = Vector3(first.x - outward * FLAG_ROW_INSET, 0.0, first.z)
	var outer: Vector3 = Vector3(outward * FLAG_ROW_EDGE, 0.0, first.z)
	return PackedVector3Array([zones.to_global(inner), zones.to_global(outer)])


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
	Session.keep_record(duel_host)
	duel_host.send = Net.send_update
	duel_host.reject = Net.reject_command
	for d in Session.chosen:
		await faces.render_deck(d, Session.library)
	_faces_ready = true
	hud.set_loading(false)
	hud.log_line("Seed %d" % Session.last_seed)
	if online:
		hud.log_line("Online duel. You are hosting as %s." % Session.player_names[viewer])
		Net.command_received.connect(_on_net_command)
	var updates: Array[SeatUpdate] = duel_host.start()
	await _play_update(updates[maxi(viewer, 0)])
	await _end_lead_in()


## Under a lead-in the opening lays the board out while the camera flies; the hands and the HUD
## wait until the lead-in has closed and the camera has landed.
func _end_lead_in() -> void:
	if not _hands_hidden:
		return
	if lead_in_overlay.playing():
		await lead_in_overlay.finished
	await camera.landed()
	_hands_hidden = false
	hud.visible = true
	_sync_layout(false)


## A client of a host or server: nothing but views. Faces for the other seat's deck render as
## cards appear.
func _ready_joiner() -> void:
	await faces.render_deck(Session.chosen[viewer], Session.library)
	await faces.render_deck(Session.chosen[1 - viewer], Session.library, true)
	hud.set_loading(false)
	hud.log_line("Online duel. You are %s." % Session.player_names[viewer])
	if Net.resumed:
		hud.log_line("You are back in the duel.")
		hud.set_rejoined(true)
		if Net.away_left_ms(1 - viewer) >= 0:
			hud.log_line("%s lost connection." % _seat_name(1 - viewer))
	elif _dev_autoplay and _dev_steps > 0:
		_dev_steps += 1   # the setup update is not a command; the host does not count it either
	for u in Net.take_pending_updates():
		_inbox.append(u)
	Net.update_received.connect(_on_net_update)
	await _drain_inbox()


func _parse_dev_args() -> void:
	for arg in DevArgs.user_args():
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
		elif arg.begins_with("--dev-lead-in-shot="):
			_dev_lead_in_shot = float(arg.get_slice("=", 1))
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
		elif arg == "--dev-concede" or arg.begins_with("--dev-concede="):
			_dev_concede = true
			if arg.contains("="):
				_dev_steps = int(arg.get_slice("=", 1))
		elif arg == "--dev-find-another":
			_dev_find_another = true
		elif arg == "--dev-next-game":
			_dev_next_game = true
		elif arg.begins_with("--dev-leave-match="):
			_dev_leave_match = true
			_dev_steps = int(arg.get_slice("=", 1))
		elif arg == "--dev-presence-demo" or arg.begins_with("--dev-presence-demo="):
			_presence_demo = arg.get_slice("=", 1) if arg.contains("=") else "cycle"
		elif arg.begins_with("--dev-stall="):
			_dev_stall = int(arg.get_slice("=", 1))
		elif arg.begins_with("--dev-clock-shot="):
			_dev_clock_shot = arg.get_slice("=", 1)
		elif arg.begins_with("--dev-away-shot="):
			_dev_away_shot = arg.get_slice("=", 1)
		elif arg.begins_with("--dev-replay="):
			_replay_file = arg.substr("--dev-replay=".length())
			# A trailing ":<16 hex>" picks one record out of a `.jsonl`; a drive letter is not one.
			var tail: String = _replay_file.get_slice(":", _replay_file.get_slice_count(":") - 1)
			if _replay_file.get_slice_count(":") > 1 and tail.length() == 16 and tail.is_valid_hex_number():
				_replay_id = tail
				_replay_file = _replay_file.left(_replay_file.length() - 17)
		elif arg.begins_with("--dev-replay-seat="):
			var which: String = arg.get_slice("=", 1)
			_replay_index = ReplayCursor.ALL if which == "all" else clampi(int(which) - 1, 0, 1)
		elif arg.begins_with("--dev-replay-to="):
			_replay_to = int(arg.get_slice("=", 1))
		elif arg.begins_with("--dev-pick=") and not online and not Session.in_adventure():
			# Online the lobby already agreed on both decks and the seed.
			var picks: PackedStringArray = arg.get_slice("=", 1).split(",")
			if picks.size() == 2:
				Session.chosen = [Session.decks[int(picks[0])], Session.decks[int(picks[1])]]


# --- Turn flow ------------------------------------------------------------

func _present_prompt() -> void:
	if _dev_done or view == null or _ended:
		return
	# A prompt draws its own card into the slot, so the replay's pinned face stops overriding it.
	_replay_focus_def = null
	if view.is_over():
		_release_pin()
		if not _held.is_empty():
			_held.clear()
			_sync_layout(false)
		_clear_highlights()
		_refresh_state()
		if online:
			Net.forget_rejoin()
		_game_winner = view.winner
		_game_reason = view.win_reason
		_rules_text = _reason_text(view.win_reason)
		_shown = true
		_sync_result()
		if _dev_autoplay:
			if Session.in_adventure():
				print("adventure stage result: %s, status=%s" % ["won" if view.winner == viewer else "lost", Session.run.status])
			await _dev_finish()
		return
	if view.deciding != viewer:
		_refresh_state()
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


## The AI seat's decision. The search runs on a worker thread against `DuelHost.ai_snapshot`, so
## the table keeps drawing and only this thread touches the live referee. One search runs at a
## time, because the AiPlayer is not shared between threads: a decision that finds an older search
## still running waits for it. An empty answer (no prompt in the sampled world, or a script error
## in the search) or no answer by the profile's `think.budget_ms` plus AI_GRACE_MS falls back on
## this thread to a quiet option of the current prompt, and the late result is never read.
func _ai_turn() -> void:
	busy = true
	_ai_generation += 1
	var generation: int = _ai_generation
	var started: int = Time.get_ticks_msec()
	var deadline: int = started + duel_host.ai.profile.think_int("budget_ms") + AI_GRACE_MS
	var answer: Array[Dictionary] = [{}]
	var mine: bool = false
	while Time.get_ticks_msec() < deadline:
		if _ai_task >= 0 and WorkerThreadPool.is_task_completed(_ai_task):
			WorkerThreadPool.wait_for_task_completion(_ai_task)
			_ai_task = -1
			if mine:
				break
		if _ai_task < 0:
			var host: DuelHost = duel_host
			var snapshot: Referee = host.ai_snapshot()
			_ai_task = WorkerThreadPool.add_task(func() -> void: answer[0] = host.ai_choice(snapshot))
			mine = true
		await get_tree().process_frame
		if not _ai_current(generation):
			return
	if mine and _ai_task >= 0 and WorkerThreadPool.is_task_completed(_ai_task):
		WorkerThreadPool.wait_for_task_completion(_ai_task)
		_ai_task = -1
	var finished: bool = mine and _ai_task < 0
	var rest: float = AI_MIN_THINK - (Time.get_ticks_msec() - started) / 1000.0
	if rest > 0.0:
		await get_tree().create_timer(rest).timeout
		if not _ai_current(generation):
			return
	busy = false
	var wire: Dictionary = answer[0] if finished else {}
	if wire.is_empty():
		push_warning("The AI %s for %s; the host answers with a quiet option" % ["had no answer" if finished else "ran past its time", String(view.deciding_kind)])
		wire = duel_host.fallback_choice(ai_seat)
	if wire.is_empty():
		# The AI seat owes nothing, so the view that sent us here is stale: read it again.
		view = duel_host.view_for(viewer)
		prompt = duel_host.prompt_for(viewer)
		if view.deciding == ai_seat:
			push_error("The AI seat's %s decision has no options" % String(view.deciding_kind))
			return
		_present_prompt()
		return
	await _apply(ai_seat, wire)


func _ai_current(generation: int) -> bool:
	return is_inside_tree() and generation == _ai_generation


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
	_refresh_state()
	_refresh_roles()
	var legal: Dictionary = _legal_uids()
	_set_hand(legal)
	hud.show_prompt(prompt, view)
	if online:
		Net.prompt_shown(prompt.kind)
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
	return _cursor == null and not busy and not _awaiting_answer and not _ended and _reconnect_until == 0 and view != null and not view.is_over() \
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
	phase_track.rotation.y = PI if (viewer if viewer >= 0 else view.active) == 1 else 0.0
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
			_refresh_state(_live)
			_refresh_displays()
			_refresh_roles()
			if not bulk_cards.is_empty():
				await _fly_recover_batch(bulk_cards, targets)
				_live = up.lines[bulk_recover_end].get("state", {})
				_refresh_state(_live)
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
	_refresh_state()
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
	# Combat's opening and its first attacker share one banner when they arrive together.
	_opening_attacker = -1
	for l in lines:
		if str(l.get("type", "")) == "combat_begin":
			_opening_attacker = int((l.get("data", {}) as Dictionary).get("attacker", l.get("player", -1)))
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
			_hit_tier = -1
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
			_pin_attack(int(data.get("source", -1)), player, data)
			# The swing crosses the ring first; the banner names it once the blow is thrown.
			await _swing(player)
			hud.toast(head, ZenithTheme.ATTACK)
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
			var attacker_seat: int = int(_live.get("attacker", view.attacker))
			var defender: int = 1 - attacker_seat
			fx.ward(_card_pos(_controlling_uid(defender)), ZenithTheme.DEFEND)
			_pin_caption(_stopped_caption(), ZenithTheme.DEFEND)
			hud.toast("Stopped", ZenithTheme.DEFEND)
			# The blow bounces: the attacker is thrown back from the fighter who stopped it.
			var thrown: Card3D = views.get(_controlling_uid(attacker_seat))
			var stopper: Card3D = views.get(_controlling_uid(defender))
			if thrown != null and stopper != null and thrown.visible and thrown != stopper:
				var away: Vector3 = thrown.global_position - stopper.global_position
				away.y = 0.0
				thrown.knock(away)
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
			_hit_tier = hit_tier(stages, life)
			_hit_said = CardText.short_damage(stages, life)
			# Under the attack card rather than across the ring, where the blow is about to land.
			_pin_caption("Hits for %s" % _hit_said, ZenithTheme.ATTACK)
			await _beat(TOAST_BEAT)
		&"damage_stages":
			var stages: int = int(data.get("stages", 0))
			var overflow: int = int(data.get("overflow", 0))
			var target: int = int(data.get("target", -1))
			_attack_cue["target"] = target
			_attack_cue["landed"] = true
			_refresh_attack_link()
			if stages <= 0:
				return
			var tier: int = _hit_tier if _hit_tier >= 0 else hit_tier(stages, overflow)
			var v: Card3D = views.get(target)
			var pos: Vector3 = _card_pos(target)
			# The blow lands here, not at the declaration: the attacker jabs, the hit holds on the
			# contact frame for its weight, and the target takes it.
			var attacker_card: Card3D = views.get(_controlling_uid(int(_live.get("attacker", view.attacker))))
			if attacker_card != null and attacker_card.visible and v != null and attacker_card != v:
				var toward: Vector3 = v.global_position - attacker_card.global_position
				toward.y = 0.0
				attacker_card.jab(toward, HIT_STOP[tier])
				await get_tree().create_timer(Card3D.STRIKE_TIME).timeout
			# Contact: the flash and the burst land, then both fighters hold for the hit's weight
			# before the target reels and the number rises.
			fx.impact(pos, ZenithTheme.ATTACK, HIT_IMPACT[tier])
			if v != null:
				v.flash(ZenithTheme.ATTACK)
			if tier == HEAVY and not _reduced_motion:
				camera.kick(Vector2(0, -1) if _is_far(target) else Vector2(0, 1))
			if HIT_STOP[tier] > 0.0 and not _reduced_motion:
				await get_tree().create_timer(HIT_STOP[tier]).timeout
			fx.float_text(_float_pos(target), "-%d Energy" % stages, ZenithTheme.WARN, HIT_FLOAT[tier], _float_rise(target))
			if overflow > 0:
				_overflow_slide(target, overflow)
			if v != null:
				await v.shake(HIT_SHAKE[tier])
			_refresh_markers()
			await _beat(BEAT)
		&"life_card_flipped":
			_wounds += 1
			_attack_cue["landed"] = true
			_refresh_attack_link()
			var uid: int = int(data.get("card", -1))
			var counts: Array = _live.get("zones", [])
			var life_left: int = int((counts[player] as Array)[0]) if player >= 0 and player < counts.size() and not (counts[player] as Array).is_empty() else -1
			# The wound that empties the Life Deck costs the duel or a point, so it lands heavier
			# and holds.
			var lethal: bool = life_left == 0
			var label: String = "Wound %d" % _wounds
			# The banner below names the wound, so the card flies without a label of its own.
			await _fly_life_loss(uid, player, targets, "", str(data.get("id", "")))
			var v: Card3D = views.get(uid)
			if v != null:
				v.flash(ZenithTheme.ATTACK)
			if lethal:
				fx.impact(_card_pos(view.player(player).duelist), ZenithTheme.ATTACK, HIT_IMPACT[HEAVY])
				if not _reduced_motion:
					camera.kick(Vector2(0, -1) if _is_far(view.player(player).duelist) else Vector2(0, 1))
			# Wounds come in runs, so each one names the card it cost and holds long enough to
			# read before the next lands.
			var lost: SeatCard = view.card(uid)
			var public_def: CardDef = Session.library.defs.get(str(data.get("id", "")))
			var title: String = lost.title if lost != null and not lost.hidden() else (public_def.title if public_def != null else "a card")
			hud.toast("%s  ·  %s" % [label, title], ZenithTheme.ATTACK)
			await _beat(WOUND_BEAT)
			if lethal:
				await _read_beat(LETHAL_HOLD)
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
				var dealt: String = CardText.short_damage(stages, life)
				_pin_caption("Dealt %s" % dealt, ZenithTheme.ATTACK)
				# "Hits for" already said it unless something (an Endurance) changed the total.
				if dealt != _hit_said:
					hud.toast("Dealt %s" % dealt, ZenithTheme.ATTACK)
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
			_hit_tier = -1
			_hit_said = ""
			_attack_cue.clear()
			fx.clear_attack_link()
			await _release_held(&"")
		&"game_over":
			await _read_beat(GAME_OVER_HOLD)
		&"combat_end":
			_combat_opening = false
			_release_pin()
			await _release_held(&"")
			_attack_cue.clear()
			fx.clear_attack_link()
			_live["phase"] = GameState.Phase.NONE
			_refresh_roles()
			await _handover("Combat over", ZenithTheme.FRAME, &"end")
		&"trigger_fired":
			# The card doing the work holds for a moment before its effects land, the way MTG Arena
			# stops on a trigger. Everything after this beat is that card's doing. A card already
			# anchored in the Focus slot or stacked over it is read where it stands and then leaves
			# the pile; only a card that is nowhere on the right gets the table's spotlight hop.
			var fired: int = int(data.get("card", -1))
			if hud.pulse_pending(fired):
				# The card is already on the rail with its title, so no banner repeats it.
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
				var word: String = CardText.fervor_word(data.merged({"player": player}))
				await _number(view.player(player).duelist, word if word != "" else "%+d Fervor" % delta, ZenithTheme.FERVOR_TEXT if delta > 0 else ZenithTheme.WARN)
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
			# Bone is the act-here colour, so only the viewer's own turn wears it.
			await _handover(whose, ZenithTheme.ACCENT if player == viewer else ZenithTheme.FRAME, &"draw")
		&"turn_end":
			await _quiet("Turn ends", ZenithTheme.MUTED, &"turn_end", QUIET_BEAT)
		&"recover_step":
			var eligible: int = int(data.get("eligible", 0))
			await _quiet("Recover" if eligible <= 0 else "Recover · %d" % eligible, ZenithTheme.ENERGY, &"recover", QUIET_BEAT)
		&"combat_declared":
			_combat_opening = true
			var declared: String = "COMBAT  ·  forced" if bool(data.get("forced", false)) else "COMBAT"
			# One banner for the opening when the first attacker is already known in this update.
			_opening_said = _opening_attacker >= 0
			if _opening_said:
				declared += "  ·  " + _first_attacker_words(_opening_attacker)
			await _handover(declared, ZenithTheme.ATTACK, &"declare")
		&"combat_begin":
			# The fighters light in their roles as the first attack phase opens. Who swings first is said
			# here only when the opening banner could not say it.
			_combat_opening = false
			var first: int = int(data.get("attacker", player))
			_live["attacker"] = first
			_live["phase"] = GameState.Phase.ATTACK
			_refresh_state(_live)
			_refresh_roles()
			if _opening_said:
				_opening_said = false
				_mark_phase(&"attack")
			else:
				await _handover(_first_attacker_words(first), ZenithTheme.ATTACK, &"attack")
		&"combat_skipped":
			var reason: String = str(data.get("reason", ""))
			var why: String = "Combat skipped"
			if reason == "grounds":
				why = "Combat skipped · Grounds"
			elif reason == "forbidden":
				why = "Combat skipped · Forbidden"
			await _quiet(why, ZenithTheme.MUTED, &"declare", QUIET_BEAT)
		&"entering_combat":
			# Each seat prepares in turn; the opening banner already said Combat, so the strip and
			# the log carry this one.
			_mark_phase(&"enter")
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
			# The exchange changes hands. The beat is stamped before the engine flips the attacker,
			# so the strip and the role glows take the next attacker from the event itself.
			var next_seat: int = int(data.get("next", -1))
			if next_seat >= 0:
				_live["attacker"] = next_seat
				_live["phase"] = GameState.Phase.ATTACK
				_refresh_state(_live)
				_refresh_roles()
			var whose: String = "Your attack"
			if next_seat != viewer:
				whose = "%s attacks" % view.player(next_seat).name if next_seat >= 0 else "They attack"
			await _handover(whose, ZenithTheme.ATTACK, &"attack")
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
	# The streak leaves as the strike snaps out, after the wind-up.
	await get_tree().create_timer(Card3D.WINDUP_TIME).timeout
	fx.slash(from + dir.normalized() * 0.3, to - dir.normalized() * 0.3, ZenithTheme.ATTACK)
	await _beat(Card3D.STRIKE_TIME + Card3D.RECOIL_TIME)


## How heavy an attack's damage lands, from the Energy stages it takes and the wounds it deals.
## Three stages of Energy weigh about one wound; only a hit worth three wounds or more is heavy,
## so the camera punch stays rare.
static func hit_tier(stages: int, life: int) -> int:
	var weight: int = stages + 3 * life
	if weight >= 9:
		return HEAVY
	return SOLID if weight >= 3 else CHIP


func _is_far(uid: int) -> bool:
	var card: SeatCard = view.card(uid)
	return card != null and viewer >= 0 and card.controller != viewer


## Where a number over a card starts. The far seat's stat plaque stands above its duelist on
## screen, so a number there starts on the card's near half and rises less, and stays clear of it.
func _float_pos(uid: int) -> Vector3:
	var pos: Vector3 = _card_pos(uid)
	if not _is_far(uid) or pos == Vector3.ZERO:
		return pos
	var toward_viewer: Vector3 = camera.global_basis.z
	toward_viewer.y = 0.0
	return pos + toward_viewer.normalized() * 0.45


func _float_rise(uid: int) -> float:
	return DuelFx.TEXT_RISE * (0.35 if _is_far(uid) else 1.0)


## Energy the hit could not absorb spills into wounds: the spill slides from the fighter to its
## owner's Life Deck, where the wounds are about to come from.
func _overflow_slide(target: int, overflow: int) -> void:
	var card: SeatCard = view.card(target)
	if card == null:
		return
	var deck: Vector3 = zones.to_global(zones.slot(card.owner, &"life_deck", 0, 1, viewer if viewer >= 0 else view.active).origin)
	fx.slide_text(_card_pos(target), deck, "+%d wound%s" % [overflow, "" if overflow == 1 else "s"], ZenithTheme.WARN, OVERFLOW_SLIDE)


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


func _first_attacker_words(seat: int) -> String:
	return "You attack first" if seat == viewer else "%s attacks first" % view.player(seat).name


## A change of hands, swept across the table. A busy queue shortens it, never below
## `HANDOVER_FLOOR`, since it is the one beat that says whose move the next one is; Space still skips.
func _handover(text: String, color: Color, phase_key: StringName) -> void:
	hud.handover(text, color)
	_mark_phase(phase_key)
	await _beat(maxf(HANDOVER_BEAT * _pending_scale(), HANDOVER_FLOOR), false)


func _mark_phase(phase_key: StringName) -> void:
	phase_track.pulse(phase_key)


## Everything that draws where the turn stands: the HUD, the phase track on the table, and the
## turn token on the owner's side of the centre line. `live` is the beat's own stamp while replaying.
func _refresh_state(live: Dictionary = {}) -> void:
	hud.refresh_state(view, viewer, live)
	if phase_track == null:
		return   # a scriptless probe of this view has no table
	phase_track.refresh(view, live)
	_place_turn_token(-1 if view.is_over() else int(live.get("active", view.active)))


## The token rests on the turn owner's half, in their Mastery school's colour, and hops across
## when the turn passes.
func _place_turn_token(active: int) -> void:
	var side: float = 0.0
	var color: Color = ZenithTheme.ACCENT
	if active >= 0:
		var duelist: Vector3 = zones.to_global(zones.slot(active, &"duelist", 0, 1, viewer if viewer >= 0 else active).origin)
		side = signf(duelist.z)
		color = Palette.school_ui(view.player(active).style)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var viewer_sign: float = 1.0 if camera == null or camera.global_position.z >= 0.0 else -1.0
	turn_token.show_turn(side, viewer_sign, color, _reduced_motion)


## The referee's own wording for a quiet event when it gave one, else the short form.
func _quiet_line(line: String, fallback: String) -> String:
	var trimmed: String = line.strip_edges()
	return fallback if trimmed.is_empty() or trimmed.length() > 48 else trimmed


## Where the middle of the table (the painted ring between the duelists) is on screen, for the
## HUD's beat banner. (-1, -1) before the camera exists.
func table_centre_screen() -> Vector2:
	if camera == null or camera.is_position_behind(TABLE_CENTRE):
		return Vector2(-1, -1)
	return camera.unproject_position(TABLE_CENTRE)


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
		var resolving: Transform3D = zones.slot(player, &"resolving", 0, 1, seat)
		if _reduced_motion:
			v.transform = resolving
		else:
			var enter: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			enter.tween_property(v, "transform", resolving, FLY_TIME)
			await enter.finished
	var shown: bool = _push_response(uid, caption, player, public_id)
	if v != null and v.visible and card != null and not card.hidden():
		v.flash(ZenithTheme.DEFEND)
		fx.ring(v.global_position, ZenithTheme.DEFEND, 0.7)
	if def != null:
		hud.toast("%s %s" % ["You play" if player == viewer else "%s plays" % view.player(player).name, def.title], ZenithTheme.DEFEND)
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
		if _reduced_motion:
			v.transform = exchange
		else:
			var enter: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			enter.tween_property(v, "transform", exchange, FLY_TIME)
			await enter.finished
	_replay_focus_def = def
	var shown: bool = hud.show_replay_card(def, caption, color, uid)
	if v != null and v.visible and c != null and not c.hidden():
		v.flash(color)
		fx.ring(v.global_position, color, 0.7)
	hud.toast("%s plays %s" % [view.player(player).name, def.title], color)
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
## Other destinations (notably a bypassed Seal) keep the ordinary zone transition. `label` floats
## over the deck; "" when a banner already says it.
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
	if label != "":
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
	var attacker: int = -1
	if not _live.is_empty():
		# Mid-replay the beat's own stamp says who is swinging; the view already holds the end.
		if int(_live.get("phase", -1)) in COMBAT_ROLE_PHASES:
			attacker = int(_live.get("attacker", -1))
	else:
		attacker = int(view.attack.get("attacker", -1)) if not view.attack.is_empty() else -1
		# The roles outlive the attack dictionary: whoever is swinging and whoever is answering keep
		# their glow for the whole of the Attack, Defend, Battle and Fight Back phases.
		if attacker < 0 and int(view.phase) in COMBAT_ROLE_PHASES:
			attacker = view.attacker
	for p in view.players:
		var color: Color = Color(0, 0, 0, 0)
		if attacker >= 0:
			color = ZenithTheme.ATTACK if p.index == attacker else ZenithTheme.DEFEND
		# What the seat can act with in a response window wears the legal-choice border, card by
		# card; the role aura stays the fight role.
		var personalities: Array[int] = [p.duelist]
		personalities.append_array(p.allies)
		for uid in personalities:
			var v: Card3D = views.get(uid)
			if v == null:
				continue
			var carries: bool = uid == _controlling_uid(p.index)
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


# --- Match replay ---------------------------------------------------------

## "" when this client can play `record`, else the sentence the viewer shows instead.
static func replay_refusal(record: MatchRecord) -> String:
	return ReplayCursor.version_problem(record, Net.PROTOCOL, Net.catalog_fingerprint(),
		str(ProjectSettings.get_setting("application/config/version", "")))


## `--dev-replay`: a recorded duel instead of a dealt one. A record from another version stops here
## in a release build; a debug build plays it anyway and says where it stops applying, if it does.
func _ready_replay() -> void:
	hud.set_dev_available(false)
	hud.replay_command.connect(_on_replay_command)
	var record: MatchRecord = MatchRecord.load_file(_replay_file, _replay_id)
	if record == null:
		hud.set_loading(false)
		hud.show_replay_refused("This replay cannot be read: %s." % MatchRecord.file_problem(_replay_file, _replay_id))
		return
	var refusal: String = replay_refusal(record)
	var decks: Array[DeckList] = ReplayCursor.decks_of(record)
	if (refusal != "" and not OS.is_debug_build()) or decks.has(null):
		hud.set_loading(false)
		hud.show_replay_refused(refusal if refusal != "" else "This replay needs a deck this build does not have.")
		return
	_cursor = ReplayCursor.new(record, Session.library, Session.strike_table)
	Session.chosen = decks
	Session.color_seed = record.color_seed
	viewer = 1 if _replay_index == 1 else 0
	rig.rotation.y = 0.0 if viewer == 0 else PI
	var names: Array[String] = [str(record.seats[0]["name"]), str(record.seats[1]["name"])]
	hud.set_match_replay(names, _cursor.turns, _replay_index)
	for d in Session.chosen:
		await faces.render_deck(d, Session.library)
	hud.set_loading(false)
	hud.log_line("Seed %d" % record.seed_value)
	if refusal != "":
		hud.log_line(refusal)
		hud.toast(refusal, ZenithTheme.WARN)
	if _cursor.stopped != "":
		hud.log_line("The replay stops applying at %s" % _cursor.stopped)
	busy = true
	var updates: Array[SeatUpdate] = _cursor.seek(_replay_to) if _replay_to > 0 else _cursor.opening
	await _play_update(updates[_replay_index])
	busy = false
	_present_replay()
	if _dev_screenshot == "":
		return
	for _i in range(_dev_steps):
		await _replay_step()
	await _dev_finish()


## The decision the next step answers, read only with the choice lit, or the result once the record
## is played out. A seat's own view shows the other seat deciding the way it saw that live.
func _present_replay() -> void:
	_replay_focus_def = null
	_refresh_state()
	_refresh_roles()
	_clear_highlights()
	_set_hand({})
	var far: Array[SeatCard] = []
	if _replay_index == ReplayCursor.ALL:
		for uid in view.player(1 - viewer).hand:
			far.append(view.card(uid))
	hud.show_far_hand(far, faces)
	hud.set_replay_state(_cursor.position, _cursor.total, _cursor.current_turn(), _replay_playing)
	if _cursor.at_end:
		_release_pin()
		if not _held.is_empty():
			_held.clear()
			_sync_layout(false)
		var result: PackedStringArray = _replay_result_text()
		hud.show_replay_result(result[0], result[1])
		return
	var entry: Dictionary = _cursor.next_entry()
	var seat: int = int(entry.get("player", 0))
	if entry.has("dev") or prompt == null or prompt.player != seat:
		hud.show_waiting(view.player(seat).name, view.deciding_kind, view)
		return
	hud.show_replay_decision(prompt, view, entry, "%s · DECISION" % view.player(seat).name.to_upper(), _cursor.next_gap_ms())
	var uid: int = int(entry.get("card", -1))
	if uid >= 0:
		_highlight({uid: true})


## Title and reason for the end of the record, a concession, a clock or a drop included.
func _replay_result_text() -> PackedStringArray:
	if _cursor.total < _cursor.record.commands.size():
		return PackedStringArray(["The replay stops here", _cursor.stopped])
	var result: Dictionary = _cursor.record.result
	var winner: int = int(result.get("winner", -1))
	if winner < 0:
		return PackedStringArray(["No winner", "The duel ended with no winner."])
	var loser: String = view.player(1 - winner).name
	var reason: String = _reason_text(str(result.get("reason", "")))
	match str(result.get("reason", "")):
		"concede":
			reason = "%s conceded." % loser
		"timeout":
			reason = "%s ran out of time." % loser
		"left":
			reason = "%s left the duel." % loser
	return PackedStringArray(["%s wins" % view.player(winner).name, reason])


## Play and Pause act at once. Everything else stops a running Play and waits for the step on the
## table to finish first.
func _on_replay_command(action: StringName, value: int) -> void:
	if _cursor == null:
		return
	match action:
		&"speed":
			Engine.time_scale = float(value)
			return
		&"play":
			_replay_play()
			return
		&"pause":
			_replay_playing = false
			hud.set_replay_state(_cursor.position, _cursor.total, _cursor.current_turn(), false)
			return
	_replay_playing = false
	while busy and is_inside_tree():
		await get_tree().process_frame
	match action:
		&"step":
			await _replay_step()
		&"back":
			await _replay_seek(_cursor.position - 1)
		&"seek":
			await _replay_seek(value)
		&"view":
			await _replay_switch_view(value)


func _replay_play() -> void:
	if _replay_playing or _cursor.at_end:
		return
	_replay_playing = true
	hud.set_replay_state(_cursor.position, _cursor.total, _cursor.current_turn(), true)
	while _replay_playing and not _cursor.at_end and is_inside_tree():
		await get_tree().create_timer(REPLAY_READ).timeout
		if not _replay_playing or not is_inside_tree():
			break
		await _replay_step()
	_replay_playing = false
	if is_inside_tree():
		hud.set_replay_state(_cursor.position, _cursor.total, _cursor.current_turn(), false)


## One recorded entry, played with every beat the live update had.
func _replay_step() -> void:
	if busy or _cursor.at_end:
		return
	busy = true
	hud.clear_prompt()
	hud.hide_inspect()
	_clear_highlights()
	var updates: Array[SeatUpdate] = _cursor.step()
	if not updates.is_empty():
		await _play_update(updates[_replay_index])
	busy = false
	if is_inside_tree():
		_present_replay()


## A jump: the table drops whatever the last beats left on it and shows the catch-up, with nothing
## to animate but the cards moving to where they now stand.
func _replay_seek(index: int) -> void:
	if busy:
		return
	busy = true
	hud.clear_prompt()
	hud.hide_inspect()
	hud.clear_log()
	_clear_highlights()
	_release_pin()
	_held.clear()
	_attack_cue = {}
	_combat_opening = false
	var updates: Array[SeatUpdate] = _cursor.seek(index)
	if not updates.is_empty():
		await _play_update(updates[_replay_index])
	busy = false
	if is_inside_tree():
		_present_replay()


## Seat 1, seat 2 or both hands: the table turns to that side and shows the same moment from there.
func _replay_switch_view(index: int) -> void:
	if index == _replay_index:
		return
	_replay_index = index
	var seat: int = 1 if index == 1 else 0
	if seat != viewer:
		viewer = seat
		_swing_camera(viewer)
	await _replay_seek(_cursor.position)


# --- Online ---------------------------------------------------------------

## Every Net signal this scene listens to, so `_exit_tree` can let them all go: a signal that fires
## while the next scene loads must not reach this one.
func _net_links() -> Array[Array]:
	return [
		[Net.command_received, _on_net_command], [Net.update_received, _on_net_update],
		[Net.command_rejected, _on_net_rejected], [Net.peer_left, _on_peer_left],
		[Net.duel_ended, _on_duel_ended], [Net.connection_failed, _on_connection_failed],
		[Net.rematch_requested, _on_rematch_requested], [Net.clock_changed, _on_clock],
		[Net.peer_away, _on_peer_away], [Net.peer_back, _on_peer_back],
		[Net.game_over, _on_series_game_over], [Net.match_over, _on_match_over],
		[Net.presence_received, _on_presence],
	]


func _exit_tree() -> void:
	for link: Array in _net_links():
		var sig: Signal = link[0]
		var handler: Callable = link[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)


## Hosting: a remote seat asks to apply a command. Like the update below it is only connected while
## the scene is in the tree (`_exit_tree`); anything that comes later is the next scene's.
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
		_refresh_state()
		hud.show_sending()
		return
	_present_prompt()


static func _carries_command(update: SeatUpdate, seat: int) -> bool:
	for line in update.lines:
		if str(line.get("type", "")) == "command" and int(line.get("player", -1)) == seat:
			return true
	return false


func _on_net_rejected(reason: String) -> void:
	if not is_inside_tree():
		return
	_awaiting_answer = false
	hud.log_line("The host refused that choice: %s" % reason)
	if not busy:
		_present_prompt()


## The other player left. A result already up stays, and only loses its Rematch; a LAN duel still
## running is over for this client.
func _on_peer_left() -> void:
	if not is_inside_tree():
		return
	_their_presence = {}
	_draw_presence(false)
	if _dev_done:
		return
	var other: String = _seat_name(1 - viewer)
	_rival_gone = true
	if _finished():
		# A result that already says they left needs no second line saying so.
		_gone_note = "" if _game_reason == "left" else "%s left." % other
		_sync_result()
		return
	_lost = {"heading": "%s left the duel" % other, "text": ""}
	_end_table()


## Online: the duel ended outside the rules, by a concession, on the clock, or a seat that dropped
## and did not come back.
func _on_duel_ended(winner_seat: int, reason: String) -> void:
	if not is_inside_tree() or _finished():
		return
	_game_winner = winner_seat
	_game_reason = reason
	if reason == "left" and winner_seat == viewer:
		_rival_gone = true
	_end_table()


## Ranked: a game is over and the match is not. The score and the count to the next deal replace
## the game's result once it is up.
func _on_series_game_over(_game: int, _wins: Array, _next_in_s: int) -> void:
	if not is_inside_tree():
		return
	_series_over = Net.last_game_over.duplicate()
	_sync_result()


## Ranked: the match is decided, after its last game's result or, for a match conceded between
## games, over the between-games card.
func _on_match_over(payload: Dictionary) -> void:
	if not is_inside_tree():
		return
	_match_payload = payload.duplicate()
	if not _shown and not busy and (view == null or not view.is_over()):
		_end_table()
		return
	_sync_result()


## The result card from the facts this scene holds, which every handler above keeps up to date:
## nothing while the game runs, the game's result once it is up, and for a ranked game what the
## match has said since. Called again from every handler, so a card always says what the facts
## now say, whatever order they came in.
func _sync_result() -> void:
	if not is_inside_tree() or not is_instance_valid(hud):
		return
	var state: DuelHud.ResultState = _result_state()
	hud.apply_result(state, _result_facts())
	if state != _dev_seen:
		_dev_seen = state
		if state == DuelHud.ResultState.BETWEEN:
			_dev_series(false)
		elif state == DuelHud.ResultState.MATCH:
			_dev_series(true)


func _result_state() -> DuelHud.ResultState:
	if not _lost.is_empty():
		return DuelHud.ResultState.LOST
	if not _shown:
		return DuelHud.ResultState.NONE
	if not _ranked:
		return DuelHud.ResultState.RESULT
	if not _match_payload.is_empty():
		return DuelHud.ResultState.MATCH
	if not _series_over.is_empty():
		return DuelHud.ResultState.BETWEEN
	return DuelHud.ResultState.GAME_PENDING


## The facts `DuelHud.apply_result` reads.
func _result_facts() -> Dictionary:
	var game: int = _series_game
	var wins: Array = [_series_wins[0], _series_wins[1]]
	var next_at: int = 0
	if not _series_over.is_empty():
		game = int(_series_over.get("game", game))
		wins = _series_over.get("wins", wins)
		next_at = int(_series_over.get("at_msec", 0)) + int(_series_over.get("next_in_s", 0)) * 1000
	var facts: Dictionary = {
		"viewer": viewer, "names": [_seat_name(0), _seat_name(1)], "winner": _game_winner,
		"reason": _game_reason, "rules_text": _rules_text, "game": game, "wins": wins,
		"best_of": Net.RANKED_BEST_OF, "next_at": next_at, "ready": _ready_sent, "match": _match_payload,
		"rival_asked": _rival_asked, "rematch_sent": _rematch_sent, "rival_gone": _rival_gone,
		"gone_note": _gone_note,
	}
	for key: String in _lost:
		facts[key] = _lost[key]
	return facts


## Ranked between games: Ready asks the server for the next game now.
func _on_next_game() -> void:
	_ready_sent = true
	Net.next_game_ready()
	_sync_result()


## Ranked match result: the same connection goes back into the ranked queue, and the title waits.
func _on_find_ranked() -> void:
	TITLE.set_ranked_search(true)
	await Net.find_ranked()
	Session.go_to_title()


## Casual queue result: the same connection goes back into the casual queue, and the title waits.
func _on_find_another() -> void:
	TITLE.set_ranked_search(false)
	await Net.find_duel()
	Session.go_to_title()


## Server room: a seat's clock. The HUD counts it down on this seat's own decision panel; the other
## seat's goes on their plate's tab (`_on_tick`).
func _on_clock(seat: int, left_ms: int, bank_ms: int, phase: String) -> void:
	if not is_inside_tree() or _finished():
		return
	hud.set_clock(seat, left_ms, bank_ms, phase)
	_on_tick()
	if _dev_clock_shot != "" and _dev_clock_shot != "warn" and phase == _dev_clock_shot and not _dev_done:
		_dev_finish()


## Once a second, and at once when a clock or a seat's presence changes: the rival's plate tab and,
## while they are cut off, the waiting panel's line saying how long they have.
func _on_tick() -> void:
	if not online or viewer < 0:
		return
	# `--dev-clock-shot=warn`: the shot once either seat's clock shows its warning, timer and bank
	# together at 10 s or less.
	if _dev_clock_shot == "warn" and not _dev_done and not _finished():
		for seat: int in [0, 1]:
			var left: int = hud.clock_left_ms(seat)
			if left >= 0 and left <= DuelHud.CLOCK_WARN_MS:
				_dev_finish()
				break
	var rival: int = 1 - viewer
	var away: int = Net.away_left_ms(rival) if not _finished() else -1
	var tab: Dictionary = hud.plate_tab(rival, away)
	far_duelist.set_tab(int(tab["tab"]) as DuelistReadout.PlateTab, str(tab["text"]), bool(tab["warn"]))
	var line: String = ""
	if away >= 0:
		var clock: int = hud.clock_left_ms(rival)
		line = DuelHud.away_line(_seat_name(rival), away if clock < 0 else mini(away, clock))
	hud.set_rival_away(line)


## Online: this client lost or was refused its connection, and Net has already left. In a server
## duel it keeps trying to get back in while the server keeps its seat, which a ranked match does
## between games too, since its next game is dealt to the same seat. A finished duel keeps its
## result without Rematch; anything still to be played ends here.
func _on_connection_failed(reason: String) -> void:
	if not is_inside_tree():
		return
	hud.set_loading(false)
	if (not _finished() or (_ranked and _match_payload.is_empty())) and _reconnecting():
		return
	_reconnect_until = 0
	hud.set_overlay(DuelHud.Overlay.NONE)
	_rival_gone = true
	_gone_note = reason
	if _finished() and (not _ranked or not _match_payload.is_empty()):
		_sync_result()
		return
	_lost = {"text": reason}
	if _finished():
		_sync_result()
		return
	_end_table()


## True while this client still holds the seat's rejoin file and the seat's time is not gone; the
## next attempt is then due in REJOIN_RETRY_MS. The first drop starts the countdown from the
## server's grace, or from this seat's own clock when that runs out sooner.
func _reconnecting() -> bool:
	if _room_code == "" or not Net.can_rejoin(_room_code):
		return false
	var now: int = Time.get_ticks_msec()
	if _reconnect_until == 0:
		var left: int = Net.REJOIN_GRACE_MS
		var own: int = hud.clock_left_ms(viewer)
		if own >= 0:
			left = mini(left, own)
		_reconnect_until = now + left
		_awaiting_answer = false
		_clear_highlights()
		hud.clear_prompt()
		hud.log_line("Connection lost. Reconnecting.")
		if _dev_away_shot != "":
			_dev_snap(_dev_away_shot.get_basename() + "_reconnecting.png", 2.0)
	if now >= _reconnect_until:
		return false
	_reconnect_next = now + REJOIN_RETRY_MS
	return true


## Every frame while cut off: the overlay counts down, an attempt goes out when one is due, and once
## the time is gone the duel is over for this client.
func _keep_reconnecting() -> void:
	var now: int = Time.get_ticks_msec()
	if now >= _reconnect_until:
		Net.forget_rejoin()
		Net.leave()
		_on_connection_failed("Could not get back into the duel in time.")
		return
	hud.set_overlay(DuelHud.Overlay.RECONNECTING, _reconnect_until - now)
	if _reconnect_next > 0 and now >= _reconnect_next:
		_reconnect_next = 0
		_try_rejoin()


## One attempt. It lands through `_rpc_resume`, which loads a fresh duel scene, or comes back as a
## failed connection.
func _try_rejoin() -> void:
	var problem: String = await Net.rejoin()
	if problem != "" and _reconnect_until > 0:
		_on_connection_failed(problem)


## The reconnect card's Concede, confirmed: a concession (of the whole match in a ranked one) when
## the connection is back, otherwise the seat is forgotten and the concession goes out on its own.
func _on_give_up() -> void:
	_reconnect_until = 0
	if Net.give_up():
		await get_tree().create_timer(LEAVE_FLUSH, true, false, true).timeout
	Net.leave()
	Net.last_error = ""
	Session.go_to_title()


## Server room: the other seat's connection dropped. Their plate and the waiting panel count down
## how long they have (`_on_tick`).
func _on_peer_away(seat: int, _grace_ms: int) -> void:
	if not is_inside_tree():
		return
	_their_presence = {}
	_draw_presence(false)
	hud.log_line("%s lost connection." % _seat_name(seat))
	_on_tick()
	if _dev_away_shot != "":
		_dev_snap(_dev_away_shot, 2.0)


func _on_peer_back(seat: int) -> void:
	if not is_inside_tree():
		return
	hud.log_line("%s is back." % _seat_name(seat))
	_on_tick()
	if _dev_away_shot != "":
		_dev_snap(_dev_away_shot.get_basename() + "_back.png", 1.5)


## Server room: the rival asked for a rematch, so Rematch reads Accept rematch.
func _on_rematch_requested(_seat: int) -> void:
	if not is_inside_tree():
		return
	_rival_asked = true
	_sync_result()


## The table stops where it stands and the result covers it.
func _end_table() -> void:
	_ended = true
	busy = true
	_shown = true
	_clear_highlights()
	hud.clear_prompt()
	_sync_result()
	if _dev_autoplay and not _dev_done:
		await _dev_finish()


func _finished() -> bool:
	return _ended or (view != null and view.is_over())


func _seat_name(seat: int) -> String:
	return view.player(seat).name if view != null else Session.player_names[seat]


## Offline a rematch deals again at once. Online one asked for while the duel runs concedes it
## first, since the server only deals one for a finished duel; in a server room the result then
## waits for the rival to ask too.
func _on_rematch() -> void:
	if not online:
		get_tree().reload_current_scene()
		return
	if not _finished():
		Net.concede()
	Net.rematch()
	if Net.server_room():
		_rematch_sent = true
		_sync_result()


## Choose duelists offline, Continue in an adventure, Back to lobby in a share-code room.
func _on_select() -> void:
	match _mode:
		DuelHud.Mode.ADVENTURE:
			Session.finish_stage(view.winner == viewer)
		DuelHud.Mode.CODE:
			Net.back_to_lobby()
		_:
			Session.go_to_select()


## Back to title from a result: the connection closes, which also gives up the room.
func _on_title() -> void:
	if _replay_file != "":
		Engine.time_scale = 1.0
	if online:
		Net.leave()
	Session.go_to_title()


func _on_concede() -> void:
	if online:
		Net.concede()
	else:
		Session.concede_duel()


## Ranked: the whole match, during a game or between games. The match result follows.
func _on_concede_match() -> void:
	Net.leave_match()


## The menu's Back to title. The menu offers it online only once a result is up; offline and in a
## replay it leaves at once, and an adventure's run is saved after every command anyway.
func _on_leave() -> void:
	if _replay_file != "":
		Engine.time_scale = 1.0
	if online:
		if not _finished():
			Net.concede()
			await get_tree().create_timer(LEAVE_FLUSH, true, false, true).timeout
		Net.leave()
	Session.go_to_title()


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
	if not is_inside_tree():
		return
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
	# A rival making a choice needs no line: the decision panel already says it waits on them.
	return ""


# --- Cards ----------------------------------------------------------------

func _hand_blocks_board() -> bool:
	return hand_3d.visible and (hand_3d.keyboard_active or hand_3d.blocks_pointer(get_viewport().get_mouse_position()))


## The camera-facing preview and its attached choices own this patch of the screen.
## Transparent presentation must not let the field underneath produce hover tooltips.
func _preview_blocks_point(point: Vector2) -> bool:
	if hud.tray.visible or hud.pile.visible or hud.inspect.visible or hud.handoff.visible or hud.loading.visible or hud.modal.visible:
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
			# A replay's full view carries the far hand's faces, so its fan shows them.
			var shown: bool = _cursor != null and not view.card(p.hand[i]).hidden()
			out[p.hand[i]] = [zones.slot(p.index, &"hand", i, hn, vw), shown, p.index != viewer and not _hands_hidden]
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
			var outward: float = -1.0 if base.origin.z < 0.0 else 1.0
			tucked.origin += Vector3(ATTACH_OFFSET.x, ATTACH_OFFSET.y, ATTACH_OFFSET.z * outward) * base.basis.get_scale().x
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
	# A card in play, or one the exchange is still using (`_held`), reads on the HUD rail and its
	# stack, so the table keeps no second copy in the Play slot. It waits there unseen, so it
	# leaves from the right place when it goes.
	for uid in view.resolving:
		if not out.has(uid):
			out[uid] = [zones.slot(view.card(uid).owner, &"resolving", 0, 1, vw), true, false]
	for key in _held.keys():
		out[int(key)] = [zones.slot(int((_held[key] as Dictionary).get("seat", 0)), &"resolving", 0, 1, vw), true, false]
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
	phase_track.rotation.y = PI if (viewer if viewer >= 0 else view.active) == 1 else 0.0
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
		for arg in DevArgs.user_args():
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
		for arg in DevArgs.user_args():
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
	if online and _dev_stall >= 0:
		if _dev_answered >= _dev_stall:
			return
		_dev_answered += 1
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
	if not (online and _dev_autoplay and _dev_steps > 0) or _dev_done:
		return false
	_dev_steps -= 1
	if _dev_steps > 0:
		return false
	_set_hand({})
	await _dev_finish()
	return true


func _dev_finish(settle: float = 0.6, after_replay: bool = false) -> void:
	_dev_done = true
	# A ranked match goes on past a game's result: the between-games panel and the match result
	# take the shots and end the run (`_dev_series`).
	if _ranked and not _finished() and (_dev_concede or _dev_leave_match):
		if _dev_leave_match:
			Net.leave_match()
		else:
			Net.concede()
		return
	if _ranked and _finished():
		return
	if _dev_concede and online and not _finished():
		# Stay connected long enough for the other client to take its shot of the result.
		Net.concede()
		await get_tree().create_timer(DEV_CONCEDE_WAIT, true, false, true).timeout
	# `--dev-find-another`: the result goes to `<png>_result.png`, and the title takes `<png>` once
	# the client is waiting in the queue again.
	var find_another: bool = _dev_find_another and online and Net.queue_room() and _finished()
	if find_another and _dev_screenshot != "":
		_dev_screenshot = _dev_screenshot.get_basename() + "_result.png"
	if _dev_screenshot != "":
		if _dev_hide_hud:
			hud.visible = false
		var cam: PackedStringArray = _dev_camera.split(",")
		if cam.size() == 3:
			camera.dev_set(Vector2(float(cam[0]), float(cam[1])), int(cam[2]))
		# `--dev-pile=mine:discard` (or `theirs`, `removed`) opens the pile browser for the shot,
		# the same view a click on that pile gives.
		for arg in DevArgs.user_args():
			if arg.begins_with("--dev-pile=") and view != null:
				var parts: PackedStringArray = arg.get_slice("=", 1).split(":")
				var seat: int = viewer if viewer >= 0 else view.active
				var player: int = seat if parts[0] != "theirs" else 1 - seat
				var zone: StringName = StringName(parts[1]) if parts.size() > 1 and parts[1] in ["removed", "relic"] else &"discard"
				await hud.show_pile(view, player, zone)
		if DevArgs.user_args().has("--dev-menu"):
			hud.set_options_open(true)
		await get_tree().create_timer(settle).timeout
		# Window startup can deliver late pointer motion after the requested hand preview.
		# Freeze only this screenshot's presentation after settling; normal input is unchanged.
		for arg in DevArgs.user_args():
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
	elif online and Net.resumed:
		# Leaving at once would drop the seat again under the other instance's shot of its return.
		await get_tree().create_timer(DEV_LINGER, true, false, true).timeout
	if after_replay:
		_dev_quit_after_replay = true
	elif find_another:
		_on_find_another()
	else:
		_dev_shutdown()


## Ranked dev runs. The between-games card saves `<png>_game<N>.png` and, under `--dev-next-game`,
## presses Ready; the match result saves `<png>` and, on an autoplay or screenshot run, quits
## after DEV_LINGER, so the other client's shot of its own result is not spoiled by this one leaving.
func _dev_series(decided: bool) -> void:
	if decided:
		if _dev_screenshot != "":
			await _dev_snap(_dev_screenshot, 0.8)
		if _dev_autoplay or _dev_screenshot != "":
			_dev_done = true
			await get_tree().create_timer(DEV_LINGER, true, false, true).timeout
			_dev_shutdown()
		return
	if _dev_screenshot != "":
		await _dev_snap("%s_game%d.png" % [_dev_screenshot.get_basename(), int(_series_over["game"])], 0.8)
	if _dev_next_game and hud.ready_button.visible and not hud.ready_button.disabled:
		hud.ready_button.pressed.emit()


## A screenshot `settle` real seconds from now that leaves the duel running.
func _dev_snap(path: String, settle: float) -> void:
	await get_tree().create_timer(settle, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved to %s" % path)


## A CLI capture must release its scene, renderer nodes and bound tweens before the
## engine shuts down. SceneTree frees queued nodes at this frame's end; the next
## process_frame signal is the first point at which quitting is safe.
func _dev_shutdown() -> void:
	var tree: SceneTree = get_tree()
	tree.process_frame.connect(tree.quit, CONNECT_ONE_SHOT)
	queue_free()
