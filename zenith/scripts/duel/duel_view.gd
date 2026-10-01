extends Node3D
## The playspace. Renders one seat's SeatView: a Card3D per uid the view lists, table tweens
## after every update, and every decision routed through the HUD prompt or a card click.
## Hotseat and hosting: a Referee lives here and the viewer's choices go straight to it.
## Hotseat: the camera swings to whichever player has to decide, behind a hand-off overlay.
## Against the AI: the viewer is pinned to the person's seat and an AiPlayer answers for the other.
## Online: the viewer is pinned to this client's seat. The host applies the joiner's commands
## through its Referee and sends seat 1 its update; the joiner holds no engine at all.

const CARD_SCENE: PackedScene = preload("res://scenes/duel/card_3d.tscn")
const MARKERS_SCENE: PackedScene = preload("res://scenes/duel/status_markers.tscn")
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
## Option types that use their card itself; the rest name a card as a target or a pick.
const USE_TYPES: Array[StringName] = [&"use", &"power", &"power_defend", &"attack", &"relic",
	&"counter", &"defend", &"endure"]
const OPPONENT_USE_READ: float = 1.8
const OPPONENT_DEFENSE_READ: float = 2.2
const OPPONENT_STOP_READ: float = 3.2
## A declared attack holds in the Focus slot this long before the next beat, even when `no_defense`
## follows at once. Own attacks hold less.
const ATTACK_READ: float = 2.2
const ATTACK_READ_OWN: float = 1.0
## The same hold for an own card that answers from the stack, before the beat that resolves it.
const ANSWER_READ_OWN: float = 1.0
## The pinned attack stays this long after the exchange is settled, then the slot clears.
const FOCUS_RELEASE: float = 0.6
## The hold for a card with rules text used outside an attack.
const CARD_USE_READ: float = 0.8
const DRAW_BEAT: float = 0.10         # between cards of the same draw
const WOUND_BEAT: float = 0.5         # between life cards
const AI_MIN_THINK: float = 0.45      # minimum seconds the AI appears to think
const AI_GRACE_MS: int = 3000         # past the profile's think budget, the AI's decision falls back
const LEAVE_FLUSH: float = 0.25       # real seconds a concession gets to go out before the connection closes
const REJOIN_RETRY_MS: int = 3000     # between attempts to get back into a server duel after a drop
const DEV_LINGER: float = 4.0         # real seconds a dev client stays up after its shot, for the other side's shot
const DEV_CONCEDE_WAIT: float = 3.0   # `--dev-concede`: real seconds the conceding client stays connected
const STALL_MS: int = 1200            # a hidden decision panel this long is a stall, not a beat
## An attachment lies under its host and peeks past the host's outer edge, away from the centre line.
const ATTACH_OFFSET: Vector3 = Vector3(0.0, -0.002, 0.26)
const ATTACH_SCALE: float = 0.78
const PILE_ZONES: Array[StringName] = [&"discard", &"removed", &"relic"]   # indexed by _pile_of().y
## Zones a used card can be in by the time its beat replays. A card that stays in play is never held.
const HOLD_ZONES: Array[StringName] = [&"resolving", &"discard", &"removed", &"life_deck"]
const ARENA_FADE: float = 0.35        # seconds for the table to dim or come back around an exchange
const ARENA_COMBAT: float = 0.6       # the veil through a Combat, between exchanges
const HANDOVER_BEAT: float = 0.8      # a change of hands: Combat opening, a fight back, a new turn
const HANDOVER_FLOOR: float = 0.4     # a busy queue shortens a hand-over no further than this
## Hit weight from `hit_tier`, indexing impact size, card shake, contact-frame pause, float size.
enum { CHIP, SOLID, HEAVY }
const HIT_IMPACT: Array[float] = [0.6, 1.0, 1.5]
const HIT_SHAKE: Array[float] = [0.03, 0.05, 0.08]
const HIT_STOP: Array[float] = [0.0, 0.05, 0.12]
const HIT_FLOAT: Array[int] = [64, 80, 104]
const LETHAL_HOLD: float = 0.6        # after the wound that empties a Life Deck
const GAME_OVER_HOLD: float = 1.0     # before the result covers the table
const OVERFLOW_SLIDE: float = 0.4
const FLAG_ROW_INSET: float = 0.3     # the chips start this far inside the first Ally slot's centre
const FLAG_ROW_EDGE: float = 2.86     # and stop this far from the duelist's centre line, at the row's end
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
@onready var lead_in_overlay: LeadInOverlay = $LeadInOverlay
@onready var tutorial_panel: TutorialPanel = $TutorialLayer/TutorialPanel

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
## Fixed when the scene is built, because Net forgets its room when the connection drops.
var _mode: DuelHud.Mode = DuelHud.Mode.LOCAL
## Ranked: game and score at the deal, then `Net.last_game_over` and `Net.last_match` once this
## game ended. Both wait for the game's own result to be up.
var _ranked: bool = false
var _series_game: int = 0
var _series_wins: Array[int] = [0, 0]
var _series_over: Dictionary = {}
var _match_payload: Dictionary = {}
## The facts the result card is drawn from (`_sync_result`). `_shown`: this game's result is up.
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
## Server room cut off mid-duel: rejoin deadline and next attempt (ticks msec), 0 while connected.
var _reconnect_until: int = 0
var _reconnect_next: int = 0
## Online: the duel ended outside the rules (concession, leaver, lost connection); no more decisions.
var _ended: bool = false
var _ai_generation: int = 0          # bumped per AI decision, so a coroutine for an older one stands down
var _ai_task: int = -1               # the AI search on the worker pool, -1 when none is running
var _wounds: int = 0                 # life cards flipped by the attack being replayed
var _hit_tier: int = -1              # the replayed attack's weight once its damage is known, else -1
var _hit_said: String = ""           # what the "Hits for" banner named
var _replaying: StringName = &""     # the event whose beat is playing now
var _second_wind_returning: Dictionary = {} # public cards lost and recovered in this update
## Cards the replayed exchange used, held face up in their owner's Play slot: uid -> {"seat": int,
## "until": StringName}. `until` is &"attack" (released at `attack_end`), &"defense" (at
## `attack_stopped` / `attack_successful`) or &"beat" (end of the beat that used it). The engine has
## already moved the card on, so `_targets` puts it in the Play slot and `_fly` leaves it there. A
## hold outlives the update when a decision interrupts the exchange.
var _held: Dictionary = {}
## The table numbers at the beat now playing (`GameEvent.state`). While set, markers and player
## panels read it instead of the update's final view.
var _live: Dictionary = {}
var _attack_cue: Dictionary = {}   # public attack currently replaying, never the future update outcome
var _focus_key: String = ""
var _replay_focus_def: CardDef = null
## The attack pinned in the Focus slot. It outlives an update, because the defender decides between
## two of them, and is released FOCUS_RELEASE after `attack_end`.
var _pinned_attack: int = -1
var _pinned_def: CardDef = null
var _pinned_caption: String = ""
var _pinned_color: Color = ZenithTheme.ATTACK
var _answer_title: String = ""      # what last answered the pinned attack, for the stop caption
## Stack responses that resolve with the attack rather than on their own beat: defenses and defense Powers.
var _defense_uids: Array[int] = []
var _window_skips: int = 0           # skipped response windows in the update being replayed
var _fast_triggers: Dictionary = {}  # line index -> run length, for a batched run of triggers
var _shown_stats: Dictionary = {}    # player -> [energy, might, duelist uid] as last floated
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
## Online presence (`PresenceState`), both directions. Off in hotseat, vs AI and adventure.
var _presence_on: bool = false
var _hover_uid: int = -1             # the table card under our own pointer, -1 for none
var _their_presence: Dictionary = {} # the other player's last sanitised state
var _presence_drawn_view: SeatView = null
var _presence_card: int = -1         # the table card carrying their highlight
var _presence_demo: String = ""      # `--dev-presence-demo[=card|hand|look]`: a scripted pointer
const PRESENCE_DEMO_LINGER: float = 4.0   # real seconds a demo sender stays up after its last step
const PRESENCE_ZONES: Dictionary = {"discard": "Discard", "removed": "Out pile", "relic": "Relic pile"}
## `--dev-replay`: the cursor holds the only referee; no AI, no Net, no decisions.
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
var _dev_resonance_tip: int = -1      # `--dev-resonance-tip=N`: hover the viewer's Nth sigil before the shot
var _dev_resonance_tip_far: bool = false  # `--dev-resonance-tip=far:N`: the rival's sigil instead
## The tutorial: its director, null in every other duel, the action the table stands on, the
## gate on the player's prompt, the ring targets up now and the lesson last announced.
var _tutorial: TutorialDirector = null
var _tutorial_action: Dictionary = {}
var _gate: Dictionary = {}
var _tutorial_ring: Array[String] = []
var _tutorial_lesson: int = 0
var _dummy_rocked: bool = false      # the practice dummy already rocked under the attack replaying
var _dev_shot_delay: float = -1.0    # `--dev-shot-delay=<s>`: a tutorial shot this long after its step
var _dev_shot_fan: bool = false      # `--dev-shot-fan`: a ring on a card's number opens the fan first
var _dev_shot_greyed: bool = false   # `--dev-shot-greyed`: the shot shows a greyed option's reason
const TUTORIAL_RIVAL_BEAT: float = 0.35   # the rival's pause before a scripted quiet answer
const TUTORIAL_WINDUP: float = 0.5        # the rival gathers itself this long before a scripted move
const TUTORIAL_END_HOLD: float = 2.0      # the "Session ended" banner's stay before the table closes
const TUTORIAL_SHOT_DELAY: float = 2.4    # `--dev-screenshot` waits this long after the step is up
const TUTORIAL_HOLD_WAIT: float = 2.0     # `--dev-autoplay` clicks on a held stop after this long
const TUTORIAL_TRAY_ROOM: float = 150.0   # kept free over the tray for Vale's box
const BARK_MARGIN: float = 0.1            # of a duelist card's height, kept clear above and below it
const STRAW: Color = Color(0.86, 0.74, 0.42)
const PLATE_GREY: Color = Color(0.72, 0.76, 0.82)
const NUMBER_BADGE: Rect2 = Rect2(0.05, 0.48, 0.26, 0.15)   # a Strike or Art face's attack badge, in face fractions
const TEXT_BOX: Rect2 = Rect2(0.03, 0.72, 0.94, 0.25)       # and its rules text box
const ASPECT_BOX: Rect2 = Rect2(0.06, 0.03, 0.12, 0.065)    # a personality face's Aspect number box
const FERVOR_TAB: Rect2 = Rect2(0.25, -0.025, 0.5, 0.058)   # the Fervor tab on its top edge, clear of the name


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
		fixture.resonance_hovered.connect(hud.show_resonance_tip)
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
		# The deal cleared these, so any facts here belong to this game.
		_series_over = Net.last_game_over.duplicate()
		_match_payload = Net.last_match.duplicate()
		_room_code = Net.room_code
		# A duel that ended while this scene loaded signalled the previous scene; read what Net kept.
		var ended: Dictionary = Net.last_duel_ended
		if not ended.is_empty():
			_game_winner = int(ended.get("winner", -1))
			_game_reason = str(ended.get("reason", ""))
			_rival_gone = _game_reason == "left" and _game_winner == viewer
		if not ended.is_empty() or not _match_payload.is_empty():
			_end_table()
	elif Session.in_tutorial():
		_tutorial = Session.tutorial
		viewer = TutorialDirector.PLAYER
		tutorial_panel.locate = _tutorial_locate
		tutorial_panel.keepouts = _tutorial_keepouts
		tutorial_panel.preview = _tutorial_preview
		tutorial_panel.modal = func() -> Rect2: return hud.tray_panel.get_global_rect() if hud.tray.visible else Rect2()
		tutorial_panel.holding = func() -> bool: return hud.inspect.visible
		tutorial_panel.filament_shown = func() -> bool: return hud.filament.visible
		tutorial_panel.reduced_motion = _reduced_motion
		tutorial_panel.advanced.connect(_on_tutorial_advanced)
		hud.gated_hover.connect(tutorial_panel.show_reason)
		hud.gated_clicked.connect(tutorial_panel.refuse)
		hud.reserve_top(TUTORIAL_TRAY_ROOM)
	elif Session.ai_seat >= 0:
		ai_seat = Session.ai_seat
		viewer = 1 - ai_seat
		rig.rotation.y = 0.0 if viewer == 0 else PI
	if _tutorial != null:
		_mode = DuelHud.Mode.TUTORIAL
		hud.set_mode(_mode, false)
	elif Session.in_adventure():
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
	hud.set_dev_available(OS.is_debug_build() and authority and _tutorial == null)
	if authority:
		await _ready_host()
		_present_prompt()
	else:
		await _ready_joiner()   # presents as soon as the authority's first update lands


## Plays Session's adventure lead-in in place of the loading screen. False when there is none.
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


func _on_lead_in_closed() -> void:
	camera.land(INTRO_LAND)
	if not _faces_ready:
		hud.visible = true
		hud.set_loading(true)


## Saves the shot and quits; under `--dev-autoplay` it saves `<png>_lead_in.png` and autoplay goes on.
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
	tutorial_panel.reduced_motion = on
	hud.reduced_motion_toggle.set_pressed_no_signal(on)
	for card in views.values():
		(card as Card3D).reduced_motion = on


func _process(_delta: float) -> void:
	if not is_instance_valid(hud):
		return
	var overlay: bool = hud.tray.visible or hud.pile.visible or hud.inspect.visible or hud.handoff.visible or hud.loading.visible \
		or hud.modal.visible or _hands_hidden
	# The options menu takes the input but hides nothing.
	var menu: bool = hud.options_menu.visible
	hand_3d.set_available(view != null and viewer >= 0 and not overlay)
	hand_3d.enabled = _can_choose()
	camera.hand_navigation = hand_3d.keyboard_active or overlay or menu
	var hand_blocks: bool = _hand_blocks_board()
	var preview_blocks: bool = _preview_blocks_point(hud.root.get_global_mouse_position())
	var board_interactive: bool = not overlay and not menu and not hand_blocks and not preview_blocks
	near_duelist.interactive = board_interactive
	far_duelist.interactive = board_interactive
	if not board_interactive and _dev_resonance_tip < 0:
		near_duelist.hover_sigil(-1, null)
		far_duelist.hover_sigil(-1, null)
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
	# The target thread would cross the hand's preview.
	hud.filament.modulate.a = FILAMENT_HAND_ALPHA if hand_3d.revealed else 1.0
	focus_card.visible = hud.focus.visible and not overlay
	# A new rail card fades in once; the same card returning from under an overlay does not.
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


## How far the table recedes: fully during an exchange, ARENA_COMBAT through the rest of Combat,
## none outside it. Keyed on phase so the veil stays down between exchanges.
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


## Veils the table to `level`; at full level the camera leans in, and the ring pulses as Combat
## opens. Reduced motion keeps the dimming and drops the moves.
func _set_arena(level: float) -> void:
	camera.arena_focus = level >= 1.0 and not _reduced_motion
	if is_equal_approx(level, _arena_amount):
		return
	var from: float = _arena_amount
	_arena_amount = level
	if _arena_fade != null and _arena_fade.is_valid():
		_arena_fade.kill()
	var veil: ShaderMaterial = arena_veil.material_override
	arena_veil.visible = true
	if _reduced_motion:
		veil.set_shader_parameter("amount", level)
		arena_veil.visible = level > 0.0
		return
	var shown: float = float(veil.get_shader_parameter("amount")) if veil.get_shader_parameter("amount") != null else from
	_arena_fade = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arena_fade.tween_method(func(value: float) -> void: veil.set_shader_parameter("amount", value), shown, level, ARENA_FADE)
	if level <= 0.0:
		_arena_fade.chain().tween_callback(func() -> void: arena_veil.visible = false)
		return
	if from <= 0.0:
		fx.ring(TABLE_CENTRE, ZenithTheme.ACCENT, 1.6)


## Safety net: re-shows a decision panel that stayed hidden STALL_MS while the viewer owes a move.
func _watch_for_stall(overlay: bool) -> void:
	var owed: bool = view != null and not view.is_over() and prompt != null and viewer >= 0 		and view.deciding == viewer and prompt.player == viewer
	if not owed or busy or _awaiting_answer or overlay or _dev_done or hud.prompt_panel.visible or _cursor != null or not _tutorial_asks():
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


## Resource fixtures follow the field cards.
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
		fixture.status_home = zones.to_global(zones.status_point(owner))
		fixture.anchor_to_card(card, camera)
	if viewer >= 0 and near_duelist.visible:
		near_duelist.readout.update_layout()
		hand_3d.set_crest_rect(near_duelist.screen_rect(camera))
	if not hud.focus.visible:
		return
	var face_rect: Rect2 = hud.focus_face_rect()
	focus_card.position = camera.to_local(camera.project_position(face_rect.get_center(), depth))
	focus_card.pixel_size = face_rect.size.x / 512.0 * units


## The line a seat's status chips sit on, along its Ally row. World points, inner end first.
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
	# The fixtures draw the status flags.
	hud.near_flags.hide()
	hud.far_flags.hide()


## Floats the signed change in a fighter's Energy or Might, as read from its readout.
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
	anchor += Vector3.UP * 0.1
	if energy != int(previous[0]):
		var gained: bool = energy > int(previous[0])
		fx.float_text(anchor, "%+d Energy" % (energy - int(previous[0])), ZenithTheme.ENERGY if gained else ZenithTheme.WARN, 52)
	if might != int(previous[1]):
		var stronger: bool = might > int(previous[1])
		# Offset sideways to clear a wide Energy hit number on the card.
		fx.float_text(anchor + camera.global_basis.x * 1.5 - camera.global_basis.y * 0.2,"%+d Might" % (might - int(previous[1])), ZenithTheme.ENERGY if stronger else ZenithTheme.WARN, 52)


func _set_hand(legal: Dictionary) -> void:
	var cards: Array[SeatCard] = _hand_cards()
	hud.set_hand(cards, faces, legal)
	hand_3d.set_hand(cards, faces, legal, view, prompt, remain_ghosts(view, viewer))


## The viewer's Remain cards with uses left, which the hand fan draws again as ghosts.
static func remain_ghosts(state: SeatView, seat: int) -> Array[SeatCard]:
	var out: Array[SeatCard] = []
	if state == null or seat < 0 or seat >= state.players.size():
		return out
	for uid in state.player(seat).remain:
		var c: SeatCard = state.card(uid)
		if c != null and not c.hidden() and c.remain > 0:
			out.append(c)
	return out


## Table cards the viewer's prompt offers to use, as opposed to pick. These wear the blue frame.
static func usable_uids(p: PromptView, state: SeatView, seat: int) -> Dictionary:
	var out: Dictionary = {}
	if p == null or state == null or seat < 0 or seat >= state.players.size() or p.player != seat:
		return out
	var hand: Array[int] = state.player(seat).hand
	for o in p.options:
		if o.card >= 0 and o.type in USE_TYPES and not hand.has(o.card):
			out[o.card] = true
	return out


func _in_fan(uid: int) -> bool:
	return view != null and viewer >= 0 and (view.player(viewer).hand.has(uid) or hand_3d.has_uid(uid))


func _on_hand_hovered(uid: int, on: bool) -> void:
	if on:
		hud.hide_peek()
	hud.preview_hand_card(uid, on)
	if _tutorial != null and not _gate.is_empty() and prompt != null:
		var greyed: String = ""
		for o in prompt.options_for_card(uid):
			if _option_open(o):
				greyed = ""
				break
			greyed = _option_reason(o)
		tutorial_panel.show_reason(greyed if on else "")
	var forecast: Dictionary = view.forecast(uid) if on and view != null else {}
	var marks: StatusMarkers = _markers.get(near_duelist.duelist_uid)
	if marks != null:
		marks.preview_energy(int(forecast.get("cost_stages", 0)))


## Hotseat and hosting: the rules run here, behind a DuelHost that also serves the remote seat.
func _ready_host() -> void:
	duel_host = DuelHost.new()
	if _tutorial != null:
		duel_host.setup(Session.tutorial_referee, [])
	else:
		duel_host.setup(Session.build_referee(), Net.remote_seats(), Session.build_ai() if not online else null, Session.ai_seat)
		Session.keep_record(duel_host)
	duel_host.send = Net.send_update
	duel_host.reject = Net.reject_command
	for d in Session.chosen:
		await faces.render_deck(d, Session.library)
	_faces_ready = true
	hud.set_loading(false)
	if _tutorial == null:
		hud.log_line("Seed %d" % Session.last_seed)
	if online:
		hud.log_line("Online duel. You are hosting as %s." % Session.player_names[viewer])
		Net.command_received.connect(_on_net_command)
	var updates: Array[SeatUpdate] = duel_host.start()
	# A tutorial opened at a later lesson was played there headless: the table opens on where it
	# stands, with this turn's log, and nothing that led there is animated again.
	if _tutorial != null and Session.tutorial_resumed:
		await _play_update(duel_host.referee.catch_up(viewer))
	else:
		await _play_update(updates[maxi(viewer, 0)])
	await _end_lead_in()


## Under a lead-in, hands and HUD wait until it has closed and the camera has landed.
func _end_lead_in() -> void:
	if not _hands_hidden:
		return
	if lead_in_overlay.playing():
		await lead_in_overlay.finished
	await camera.landed()
	_hands_hidden = false
	hud.visible = true
	_sync_layout(false)


## A client of a host or server: views only, no engine.
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
		elif arg.begins_with("--dev-shot-delay="):
			_dev_shot_delay = float(arg.get_slice("=", 1))
		elif arg == "--dev-shot-fan":
			_dev_shot_fan = true
		elif arg == "--dev-shot-greyed":
			_dev_shot_greyed = true
		elif arg.begins_with("--dev-resonance-tip="):
			var tip_arg: String = arg.get_slice("=", 1)
			_dev_resonance_tip_far = tip_arg.begins_with("far:")
			_dev_resonance_tip = int(tip_arg.trim_prefix("far:"))
	# `--dev-resonances=<ids>` gives player 1 those Resonances, as an adventure run would, and
	# `--dev-resonances-far=<ids>` gives them to player 2, as an Elite holds them. Read after
	# `--dev-pick`, whatever the order on the command line.
	var resonance_args: Array[String] = ["", ""]
	for arg in DevArgs.user_args():
		if arg.begins_with("--dev-resonances="):
			resonance_args[0] = arg.get_slice("=", 1)
		elif arg.begins_with("--dev-resonances-far="):
			resonance_args[1] = arg.get_slice("=", 1)
	for seat in range(2):
		if resonance_args[seat] == "" or online or Session.in_adventure() or Session.decks.is_empty():
			continue
		if not Session.can_start():
			Session.chosen = [Session.decks[0], Session.decks[1 if Session.decks.size() > 1 else 0]]
		var seat_deck: DeckList = Session.chosen[seat]
		var dressed: DeckList = DeckList.resolve(seat_deck.id) if seat_deck.id != "" else seat_deck
		dressed.resonances.clear()
		for id in resonance_args[seat].split(",", false):
			if ResonanceData.has(id):
				dressed.resonances.append(id)
		Session.chosen[seat] = dressed


# --- Turn flow ------------------------------------------------------------

func _present_prompt() -> void:
	if _dev_done or view == null or _ended:
		return
	if _tutorial != null:
		await _tutorial_next()
		return
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


## The AI seat's decision, searched on a worker thread against `DuelHost.ai_snapshot`. One search
## at a time, because the AiPlayer is not thread-safe. An empty answer, or none by `think.budget_ms`
## plus AI_GRACE_MS, falls back to a quiet option; a late result is never read.
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
		# The AI seat owes nothing, so this view is stale.
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
	hud.set_gate(_gate)
	hud.show_prompt(prompt, view)
	if online:
		Net.prompt_shown(prompt.kind)
	_highlight(legal)
	hud.hide_peek()
	if _dev_autoplay:
		_dev_step()


## Cards a click acts on. Final Strike is excluded; the HUD offers it through its own button.
func _legal_uids() -> Dictionary:
	var out: Dictionary = {}
	for o in prompt.options:
		if o.card >= 0 and o.type != &"final_strike" and _option_open(o):
			out[o.card] = true
	return out


## False only for an option the tutorial greys out on the prompt now shown.
func _option_open(o: OptionView) -> bool:
	if _gate.is_empty() or prompt == null:
		return true
	var i: int = prompt.options.find(o)
	var enabled: Array = _gate.get("enabled", [])
	return i < 0 or i >= enabled.size() or bool(enabled[i])


func _option_reason(o: OptionView) -> String:
	var i: int = prompt.options.find(o) if prompt != null else -1
	var reasons: Array = _gate.get("reasons", [])
	return str(reasons[i]) if i >= 0 and i < reasons.size() else ""


func _hand_cards() -> Array[SeatCard]:
	var out: Array[SeatCard] = []
	for uid in view.player(viewer).hand:
		out.append(view.card(uid))
	return out


func _can_choose() -> bool:
	return _cursor == null and not busy and not _awaiting_answer and not _ended and _reconnect_until == 0 and view != null and not view.is_over() \
		and prompt != null and viewer >= 0 and view.deciding == viewer and prompt.player == viewer and _tutorial_asks()


## Outside the tutorial always; in it, only while the script is on one of the player's decisions,
## so nothing is chosen while Caedan is still talking.
func _tutorial_asks() -> bool:
	return _tutorial == null or str(_tutorial_action.get("do", "")) in ["player", "mismatch"]


func _on_option_chosen(opt: OptionView) -> void:
	if not _can_choose():
		return
	var wire: Dictionary = opt.to_command(viewer).to_dict()
	if _tutorial != null:
		if not _option_open(opt):
			tutorial_panel.refuse(_option_reason(opt))
			return
		await _tutorial_apply(viewer, wire, _tutorial_action)
		return
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


## Hotseat and hosting: run one command through the host. A local refusal lands in the log.
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


## Replays an update into the log and the table, one beat per event line against the update's
## final layout, then syncs whatever the beats did not move.
func _play_update(up: SeatUpdate) -> void:
	view = up.view
	faces.set_matchups(view, Session.library, Session.strike_table)
	$Atmosphere.set_schools(Palette.school_ui(view.player(0).style), Palette.school_ui(view.player(1).style))
	prompt = up.prompt
	var seat_backdrops: Array[Color] = [hud.seat_backdrop(0), hud.seat_backdrop(1)]
	await faces.render_missing(view, Session.library, seat_backdrops)
	_adopt_cards()
	# An exchange spans the defender's decision, so the pinned attack returns before the first beat.
	_restore_pin()
	zones.set_viewer(viewer if viewer >= 0 else view.active)
	phase_track.set_viewer(viewer if viewer >= 0 else view.active)
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
			hud.log_line(line, DuelHud.log_card(l, view))
		if l.has("data") and (index > bulk_recover_end or not bulk_cards.is_empty()):
			_replaying = StringName(str(l.get("type", "")))
			_live = (l.get("state", {}) as Dictionary).duplicate(true)
			if not bulk_cards.is_empty():
				# Hold the emptied Life number until the pile reaches the deck.
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
		_held.clear()
	_attack_cue = view.attack.duplicate(true)
	_refresh_state()
	_refresh_displays()
	_refresh_roles()
	await _sync_layout(true)
	if _dev_quit_after_replay:
		_dev_shutdown()


## Per-update pacing, before it plays: BATCH_TRIGGERS triggers in a row resolve as one batch, and
## CROWD_WINDOWS skipped windows drop their beats.
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


## The Second Wind reset: a contiguous run of one player's Recover events followed by `second_wind`.
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
	# Take a card leaving the hand out of the fan, so it is not drawn twice.
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
			# Held in the Play slot until the exchange ends, wherever the rules have already sent it.
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
			await _swing(player)
			hud.toast(head, ZenithTheme.ATTACK)
			await _read_beat(ATTACK_READ_OWN if player == viewer else ATTACK_READ)
		&"defense_played", &"defense_power", &"shield":
			var defense_uid: int = int(data.get("card", -1))
			var stopped: bool = bool(data.get("stopped", false))
			var caption: String = "Defense"
			if type == &"shield":
				caption = "Shield"
			elif type == &"defense_power":
				caption = "Power"
			# A defense holds until the attack is settled; a Shield leaves at the end of its own beat.
			await _hold(defense_uid, player, &"beat" if type == &"shield" else &"defense", str(data.get("id", "")))
			await _answer_card_beat(defense_uid, player, targets, caption, stopped, str(data.get("id", "")))
			if type == &"shield":
				hud.pop_response(defense_uid)
			elif hud.has_response(defense_uid):
				_defense_uids.append(defense_uid)
			var defender: int = 1 - int(_live.get("attacker", view.attacker))
			fx.ward(_card_pos(_controlling_uid(defender)), ZenithTheme.DEFEND)
			await _beat(BEAT)
			await _release_held(&"beat", defense_uid)
		&"remain":
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
			# The attacker is thrown back from the fighter who stopped it.
			var thrown: Card3D = views.get(_controlling_uid(attacker_seat))
			var stopper: Card3D = views.get(_controlling_uid(defender))
			if thrown != null and stopper != null and thrown.visible and thrown != stopper:
				var away: Vector3 = thrown.global_position - stopper.global_position
				away.y = 0.0
				thrown.knock(away)
			await _beat(TOAST_BEAT)
			_pop_defenses()
			await _release_held(&"defense")
		&"attack_successful":
			_pop_defenses()
			await _release_held(&"defense")
		&"modified_damage":
			var stages: int = int(data.get("stages", 0))
			var life: int = int(data.get("life", 0))
			_hit_tier = hit_tier(stages, life)
			_hit_said = CardText.short_damage(stages, life)
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
			var attacker_card: Card3D = views.get(_controlling_uid(int(_live.get("attacker", view.attacker))))
			if attacker_card != null and attacker_card.visible and v != null and attacker_card != v:
				var toward: Vector3 = v.global_position - attacker_card.global_position
				toward.y = 0.0
				attacker_card.jab(toward, HIT_STOP[tier])
				await get_tree().create_timer(Card3D.STRIKE_TIME).timeout
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
			if v != null and _is_dummy(target):
				_dummy_rocked = true
				fx.burst(pos, STRAW, 12 + 6 * tier, 1.6)
				await v.wobble(1.0 + tier)
			elif v != null:
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
			var lethal: bool = life_left == 0
			var label: String = "Wound %d" % _wounds
			await _fly_life_loss(uid, player, targets, "", str(data.get("id", "")))
			var v: Card3D = views.get(uid)
			if v != null:
				v.flash(ZenithTheme.ATTACK)
			var struck: int = view.player(player).duelist if player >= 0 else -1
			if not _dummy_rocked and _is_dummy(struck) and views.has(struck):
				_dummy_rocked = true
				fx.burst(_card_pos(struck), STRAW, 18, 1.6)
				(views[struck] as Card3D).wobble(1.0)
			if lethal:
				fx.impact(_card_pos(view.player(player).duelist), ZenithTheme.ATTACK, HIT_IMPACT[HEAVY])
				if not _reduced_motion:
					camera.kick(Vector2(0, -1) if _is_far(view.player(player).duelist) else Vector2(0, 1))
			var lost: SeatCard = view.card(uid)
			var public_def: CardDef = Session.library.defs.get(str(data.get("id", "")))
			var title: String = lost.title if lost != null and not lost.hidden() else (public_def.title if public_def != null else "a card")
			hud.toast("%s  ·  %s" % [label, title], ZenithTheme.ATTACK)
			await _beat(WOUND_BEAT)
			if lethal:
				await _read_beat(LETHAL_HOLD)
		&"life_card_lost":
			await _fly_life_loss(int(data.get("card", -1)), player, targets, "-1 Life", str(data.get("id", "")))
		&"final_strike", &"hand_discarded", &"in_play_discarded", &"card_moved":
			var uid: int = int(data.get("card", data.get("discarded", -1)))
			await _fly(uid, targets)
		&"card_used", &"card_placed":
			var used_uid: int = int(data.get("card", -1))
			# Held in the Play slot even when the rules already sent it face down to the Life Deck.
			var held_use: bool = false
			if type == &"card_used":
				held_use = await _hold(used_uid, player, &"beat", str(data.get("id", "")))
			if type == &"card_used" and viewer >= 0 and player != viewer:
				await _opponent_card_beat(used_uid, player, targets, "OPPONENT PLAYS", OPPONENT_USE_READ, ZenithTheme.ACCENT, str(data.get("id", "")))
			else:
				await _sync_layout(true)
				await _spotlight(used_uid)
				await _read_card(used_uid, "You play" if player == viewer else "In play")
				if held_use and _pinned_attack >= 0 and _held.has(used_uid):
					# A pinned attack keeps the Focus slot, so the card is read in place.
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
			hud.pop_response(card_uid)
		&"endurance_declined":
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
				# Only when an Endurance changed the total "Hits for" named.
				if dealt != _hit_said:
					hud.toast("Dealt %s" % dealt, ZenithTheme.ATTACK)
					await _beat(TOAST_BEAT)
			elif was_stopped:
				_pin_caption(_stopped_caption(), ZenithTheme.DEFEND)
			else:
				_pin_caption("Dealt nothing", ZenithTheme.MUTED)
			await _beat(FOCUS_RELEASE)
			_release_pin()
			_wounds = 0
			_dummy_rocked = false
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
			# A card already on the rail is read there; otherwise it gets the table spotlight.
			var fired: int = int(data.get("card", -1))
			if hud.pulse_pending(fired):
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
			# Discard pile to Life Deck, not an Energy gain.
			await _fly(int(data.get("card", -1)), targets)
			await _beat(DRAW_BEAT)
		&"power_up":
			var uid: int = view.player(player).duelist
			var gain: int = int(data.get("gain", 0))
			if gain > 0:
				await _number(uid, "+%d Energy" % gain, ZenithTheme.ENERGY)
			# Allies power up too; only the event lists what each gained.
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
			# A gain swallowed by a standing effect.
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
			var whose: String = "Your turn" if player == viewer else "%s's turn" % view.player(player).name
			await _handover(whose, ZenithTheme.ACCENT if player == viewer else ZenithTheme.FRAME, &"draw")
		&"turn_end":
			await _quiet("Turn ends", ZenithTheme.MUTED, &"turn_end", QUIET_BEAT)
		&"recover_step":
			var eligible: int = int(data.get("eligible", 0))
			await _quiet("Recover" if eligible <= 0 else "Recover · %d" % eligible, ZenithTheme.ENERGY, &"recover", QUIET_BEAT)
		&"combat_declared":
			_combat_opening = true
			var declared: String = "COMBAT  ·  forced" if bool(data.get("forced", false)) else "COMBAT"
			# One banner for the opening when this update already names the first attacker.
			_opening_said = _opening_attacker >= 0
			if _opening_said:
				declared += "  ·  " + _first_attacker_words(_opening_attacker)
			await _handover(declared, ZenithTheme.ATTACK, &"declare")
		&"combat_begin":
			# Names the first attacker only when the opening banner could not.
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
			# The beat's state predates the attacker flip, so the next attacker comes from the event.
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
			# The caption fits a 320px slot, so it takes the short form.
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
		&"script_dealt":
			# New cards come onto the table from off its edge and slide onto the Life Deck.
			var from: Vector3 = _offstage_point(player, &"life_deck")
			for uid in data.get("cards", []):
				var dealt: Card3D = views.get(int(uid))
				if dealt != null and not dealt.visible:
					dealt.global_position = from
					dealt.visible = true
			await _sync_layout(true)
			await _beat(BEAT)
		&"script_swap":
			# The whole side is carried off the table's far edge, then the new one slides in.
			var off: Vector3 = _offstage_point(player, &"duelist")
			var carry: Tween = null
			for uid in data.get("gone", []):
				var old: Card3D = views.get(int(uid))
				if old == null or not old.visible:
					continue
				if carry == null:
					carry = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				carry.tween_property(old, "global_position", off, SYNC_DURATION * 2.0)
			if carry != null:
				await carry.finished
			for uid in data.get("gone", []):
				var gone: Card3D = views.get(int(uid))
				if gone != null:
					gone.visible = false
			for uid in data.get("arrived", []):
				var fresh: Card3D = views.get(int(uid))
				if fresh != null and not fresh.visible:
					fresh.global_position = off
					fresh.visible = true
			_refresh_displays()
			await _sync_layout(true)
			await _handover("%s takes the other side" % view.player(player).name, ZenithTheme.ACCENT, &"draw")
		&"countered":
			var target: int = int(data.get("target", -1))
			fx.ward(_card_pos(target), ZenithTheme.DEFEND, 0.8)
			fx.float_text(_card_pos(target), "Countered", ZenithTheme.DEFEND, 48)
			# The countered card leaves the stack at once; the counter follows after its read hold.
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


## The attacker's controlling card lunges at the defender's.
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
	await get_tree().create_timer(Card3D.WINDUP_TIME).timeout
	fx.slash(from + dir.normalized() * 0.3, to - dir.normalized() * 0.3, ZenithTheme.ATTACK)
	await _beat(Card3D.STRIKE_TIME + Card3D.RECOIL_TIME)


## Hit weight from Energy stages and wounds; three stages weigh one wound. Heavy starts at three
## wounds' worth, so the camera punch stays rare.
static func hit_tier(stages: int, life: int) -> int:
	var weight: int = stages + 3 * life
	if weight >= 9:
		return HEAVY
	return SOLID if weight >= 3 else CHIP


func _is_far(uid: int) -> bool:
	var card: SeatCard = view.card(uid)
	return card != null and viewer >= 0 and card.controller != viewer


## Where a number over a card starts. Far-seat numbers start on the card's near half, clear of its plaque.
func _float_pos(uid: int) -> Vector3:
	var pos: Vector3 = _card_pos(uid)
	if not _is_far(uid) or pos == Vector3.ZERO:
		return pos
	var toward_viewer: Vector3 = camera.global_basis.z
	toward_viewer.y = 0.0
	return pos + toward_viewer.normalized() * 0.45


func _float_rise(uid: int) -> float:
	return DuelFx.TEXT_RISE * (0.35 if _is_far(uid) else 1.0)


## Overflow into wounds, slid from the fighter to its owner's Life Deck.
func _overflow_slide(target: int, overflow: int) -> void:
	var card: SeatCard = view.card(target)
	if card == null:
		return
	var deck: Vector3 = zones.to_global(zones.slot(card.owner, &"life_deck", 0, 1, viewer if viewer >= 0 else view.active).origin)
	fx.slide_text(_card_pos(target), deck, "+%d wound%s" % [overflow, "" if overflow == 1 else "s"], ZenithTheme.WARN, OVERFLOW_SLIDE)


func _controlling_uid(seat: int) -> int:
	var controlling: Array = _live.get("controlling", [])
	return int(controlling[seat]) if seat >= 0 and seat < controlling.size() else view.player(seat).controlling


## The card about to act lifts, flashes and names itself before its effects land.
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


## A trigger inside a batched run: the run is announced once, then each card gets a short spotlight.
func _batched_spotlight(uid: int, index: int) -> void:
	if not _fast_triggers.has(index):
		await _spotlight(uid)
		return
	var run: int = int(_fast_triggers[index])
	if run > 0:
		await _quiet("Resolving %d triggers" % run, ZenithTheme.ACCENT, &"resolve", QUIET_BEAT)
	await _spotlight(uid, BATCH_SPOTLIGHT)


## A small banner for an event that changed nothing, and the phase strip moves.
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
## `HANDOVER_FLOOR`; Space still skips.
func _handover(text: String, color: Color, phase_key: StringName) -> void:
	hud.handover(text, color)
	_mark_phase(phase_key)
	await _beat(maxf(HANDOVER_BEAT * _pending_scale(), HANDOVER_FLOOR), false)


func _mark_phase(phase_key: StringName) -> void:
	phase_track.pulse(phase_key)


## Refreshes the HUD and phase track. `live` is the beat's own stamp while replaying.
func _refresh_state(live: Dictionary = {}) -> void:
	hud.refresh_state(view, viewer, live)
	if phase_track == null:
		return   # a scriptless probe of this view has no table
	phase_track.set_viewer(viewer if viewer >= 0 else view.active)
	phase_track.refresh(view, live)


## The referee's own wording for a quiet event when it gave one, else the short form.
func _quiet_line(line: String, fallback: String) -> String:
	var trimmed: String = line.strip_edges()
	return fallback if trimmed.is_empty() or trimmed.length() > 48 else trimmed


## The table ring's screen position, for the HUD's beat banner. (-1, -1) before the camera exists.
func table_centre_screen() -> Vector2:
	if camera == null or camera.is_position_behind(TABLE_CENTRE):
		return Vector2(-1, -1)
	return camera.unproject_position(TABLE_CENTRE)


## A card's screen-space centre, (-1, -1) when it is missing, hidden or behind the lens.
func screen_anchor(uid: int) -> Vector2:
	var v: Card3D = views.get(uid)
	if v == null or not v.visible or camera == null or camera.is_position_behind(v.global_position):
		return Vector2(-1, -1)
	return camera.unproject_position(v.global_position)


## Pins the declared attack's public face in the Focus slot until shortly after `attack_end`.
func _pin_attack(uid: int, attacker: int, data: Dictionary) -> void:
	_release_pin()
	var def: CardDef = _attack_def(uid, data)
	var named: bool = def != null
	if not named:
		# An attack with no card of its own shows the personality making it.
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


## The card an attack was declared with, or null. Falls back on the declaration's public id when
## the final view has already hidden the card (e.g. under the Life Deck).
func _attack_def(uid: int, data: Dictionary) -> CardDef:
	if uid < 0:
		return null
	var card: SeatCard = view.card(uid)
	if card != null and not card.hidden():
		return _def(card)
	return Session.library.defs.get(str(data.get("id", "")))


## "Kestrel attacks · Riven Blade". An empty title is an attack with no card behind it.
func _attack_caption(title: String, attacker: int, data: Dictionary) -> String:
	var who: String = "Your attack" if attacker == viewer else "%s attacks" % view.player(attacker).name
	if not title.is_empty():
		return "%s · %s power" % [who, title] if bool(data.get("is_power", false)) else "%s · %s" % [who, title]
	var what: String = "a Power" if bool(data.get("is_power", false)) \
		else ("Strike" if str(data.get("kind", "strike")) == "strike" else "Art")
	if bool(data.get("is_final", false)):
		what = "Final Strike"
	elif bool(data.get("focused", false)):
		what = "Focused " + what
	return "%s · %s" % [who, what]


## Sets the pinned attack's caption, re-showing the slot if something took it down.
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


## Puts the pinned attack back after a prompt or a cleared panel took the slot.
func _restore_pin() -> void:
	if _pinned_attack < 0 or _pinned_def == null:
		return
	_replay_focus_def = _pinned_def
	hud.show_replay_card(_pinned_def, _pinned_caption, _pinned_color, _pinned_attack)


func _stopped_caption() -> String:
	# Names the stopper only when the stack no longer shows it.
	if _answer_title == "" or hud.stack_depth() > 0:
		return "Stopped"
	return "Stopped by %s" % _answer_title


## The attack is settled, so the cards that answered it leave the stack.
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


## Pushes a card answering the pinned attack onto the stack. False when there is nothing public to show.
func _push_response(uid: int, caption: String, player: int, public_id: String = "") -> bool:
	if _pinned_attack < 0:
		return false
	var card: SeatCard = view.card(uid)
	var def: CardDef = _def(card) if card != null and not card.hidden() else Session.library.defs.get(public_id)
	if def == null:
		return false
	_answer_title = def.title
	return hud.push_response(def, caption, _response_role(player), uid)


## Which side of the exchange a response belongs to.
func _response_role(player: int) -> StringName:
	var attacker: int = int(_live.get("attacker", view.attacker))
	return &"attack" if attacker >= 0 and player == attacker else &"defend"


## A card answering the pinned attack goes onto the stack over it and holds; the opponent's longer.
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
		# The opponent's answer visits their resolving slot before the pile.
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


## Shows a card with rules text in the Focus slot for CARD_USE_READ, unless a pinned attack owns it.
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


## A card's arc to its slot in the new layout. Skips a card already there, held, or not visible to this seat.
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


## Holds a used card in its owner's Play slot (see `_held`); the caller's next `_sync_layout` moves
## it. A hidden card shows its event's public face. False when it stays in play or has no public face.
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
	# A card already at its final slot starts from its owner's hand instead.
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


## Releases held cards matching `until` (every one for &"") to where the view says they went.
## `only` narrows it to one card.
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


## Sweeps a discarded Life Deck back into place in one motion for Second Wind.
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


## A lost Life card lifts off its owner's Life Deck, reveals briefly, then flies to its pile. Other
## destinations (a bypassed Seal) take the ordinary `_fly`. `label` floats over the deck; "" for none.
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
	# The reveal is placed in screen space, facing the lens; a world-height apex can leave the screen.
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


## A pause between beats. `--dev-freeze=<event>` takes the screenshot here instead.
func _beat(seconds: float, scaled: bool = true) -> void:
	if _dev_freeze != &"" and _replaying == _dev_freeze and not _dev_done:
		await _dev_finish(0.03, true)
		return
	await get_tree().create_timer(_beat_length(seconds, scaled)).timeout


## A reading hold: the pending queue does not shorten it. Space, `--dev-fast` and `--dev-freeze` still apply.
func _read_beat(seconds: float) -> void:
	await _beat(seconds, false)


## How long a beat holds: scaled down by the pending queue, SKIP_BEAT while Space is held, unscaled
## under `--dev-freeze`.
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


## Hold Space to skip a replay. Off while the viewer can choose, and while keyboard hand browsing
## uses Space to inspect.
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
	# The viewer's personalities: lifted above the foreground hand.
	var card: SeatCard = view.card(uid)
	if card != null and card.controller == viewer and card.zone in [&"duelist", &"ally"]:
		return v.global_position + Vector3.UP * 1.0
	return v.global_position


## The attacking personality carries the red role glow through the combat role phases. The defender
## gets none, because blue on a table card means usable.
func _refresh_roles() -> void:
	if view == null:
		return
	var attacker: int = -1
	if not _live.is_empty():
		# Mid-replay the beat's stamp says who is swinging; the view already holds the end.
		if int(_live.get("phase", -1)) in COMBAT_ROLE_PHASES:
			attacker = int(_live.get("attacker", -1))
	else:
		attacker = int(view.attack.get("attacker", -1)) if not view.attack.is_empty() else -1
		# The role outlives the attack dictionary through COMBAT_ROLE_PHASES.
		if attacker < 0 and int(view.phase) in COMBAT_ROLE_PHASES:
			attacker = view.attacker
	for p in view.players:
		var color: Color = Color(0, 0, 0, 0)
		if attacker >= 0 and p.index == attacker:
			color = ZenithTheme.ATTACK
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
	# A spent attack card links from its performer instead of its pile.
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


## `--dev-replay`. A record from another version is refused in release; debug plays it and says
## where it stops applying.
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


## Shows the decision the next step answers, read-only with the choice lit, or the result at the end.
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


## Play and Pause act at once. Everything else stops Play and waits for the current step.
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


## A jump: clears held and pinned cards, then plays the catch-up update.
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

## Every Net signal this scene listens to, disconnected in `_exit_tree` so the next scene's loading
## cannot reach this one.
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
	# When both seats decide at once, the other seat's moves arrive as updates too. Only one carrying
	# our command answers ours; one that leaves our prompt unchanged plays under the open panel.
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


## The other player left. A result already up loses only its Rematch; a running duel ends here.
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
		_gone_note = "" if _game_reason == "left" else "%s left." % other
		_sync_result()
		return
	_lost = {"heading": "%s left the duel" % other, "text": ""}
	_end_table()


## Online: the duel ended outside the rules (concession, clock, or a seat that did not come back).
func _on_duel_ended(winner_seat: int, reason: String) -> void:
	if not is_inside_tree() or _finished():
		return
	_game_winner = winner_seat
	_game_reason = reason
	if reason == "left" and winner_seat == viewer:
		_rival_gone = true
	_end_table()


## Ranked: a game is over and the match is not.
func _on_series_game_over(_game: int, _wins: Array, _next_in_s: int) -> void:
	if not is_inside_tree():
		return
	_series_over = Net.last_game_over.duplicate()
	_sync_result()


## Ranked: the match is decided, possibly by a concession between games.
func _on_match_over(payload: Dictionary) -> void:
	if not is_inside_tree():
		return
	_match_payload = payload.duplicate()
	if not _shown and not busy and (view == null or not view.is_over()):
		_end_table()
		return
	_sync_result()


## Redraws the result card from the facts this scene holds. Every handler calls it, so arrival
## order does not matter.
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


## Ranked match result: requeue on the same connection and wait on the title.
func _on_find_ranked() -> void:
	TITLE.set_ranked_search(true)
	await Net.find_ranked()
	Session.go_to_title()


## Casual queue result: requeue on the same connection and wait on the title.
func _on_find_another() -> void:
	TITLE.set_ranked_search(false)
	await Net.find_duel()
	Session.go_to_title()


## Server room: a seat's clock. The rival's is drawn on their tab (`_on_tick`).
func _on_clock(seat: int, left_ms: int, bank_ms: int, phase: String) -> void:
	if not is_inside_tree() or _finished():
		return
	hud.set_clock(seat, left_ms, bank_ms, phase)
	_on_tick()
	if _dev_clock_shot != "" and _dev_clock_shot != "warn" and phase == _dev_clock_shot and not _dev_done:
		_dev_finish()


## Each second and on clock or presence changes: the rival's tab and their away line.
func _on_tick() -> void:
	if not online or viewer < 0:
		return
	# `--dev-clock-shot=warn`: the shot once either clock (timer plus bank) is at CLOCK_WARN_MS.
	if _dev_clock_shot == "warn" and not _dev_done and not _finished():
		for seat: int in [0, 1]:
			var left: int = hud.clock_left_ms(seat)
			if left >= 0 and left <= DuelHud.CLOCK_WARN_MS:
				_dev_finish()
				break
	var rival: int = 1 - viewer
	var away: int = Net.away_left_ms(rival) if not _finished() else -1
	var tab: Dictionary = hud.rival_tab(rival, away)
	far_duelist.set_tab(int(tab["tab"]) as DuelistReadout.Tab, str(tab["text"]), bool(tab["warn"]))
	var line: String = ""
	if away >= 0:
		var clock: int = hud.clock_left_ms(rival)
		line = DuelHud.away_line(_seat_name(rival), away if clock < 0 else mini(away, clock))
	hud.set_rival_away(line)


## Online: the connection was lost or refused, and Net has already left. A server duel (or a ranked
## match between games) tries to rejoin; a finished duel keeps its result without Rematch.
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


## True while the rejoin file exists and time is left. The deadline is the server's grace or this
## seat's clock, whichever runs out first.
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


## Every frame while cut off: count down, retry when due, give up at the deadline.
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


## Success lands through `_rpc_resume`, which loads a fresh duel scene.
func _try_rejoin() -> void:
	var problem: String = await Net.rejoin()
	if problem != "" and _reconnect_until > 0:
		_on_connection_failed(problem)


## The reconnect card's Concede: concedes (the whole match when ranked) and leaves.
func _on_give_up() -> void:
	_reconnect_until = 0
	if Net.give_up():
		await get_tree().create_timer(LEAVE_FLUSH, true, false, true).timeout
	Net.leave()
	Net.last_error = ""
	Session.go_to_title()


## Server room: the other seat's connection dropped.
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


## Online, a rematch during a running duel concedes first, because the server only deals one for a
## finished duel. A server room waits for both seats to ask.
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


## Back to title from a result. Closing the connection also gives up the room.
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


## Ranked: concede the whole match.
func _on_concede_match() -> void:
	Net.leave_match()


## The menu's Back to title. Online it concedes a running duel first.
func _on_leave() -> void:
	if _tutorial != null:
		Session.abandon_tutorial()
		return
	if _replay_file != "":
		Engine.time_scale = 1.0
	if online:
		if not _finished():
			Net.concede()
			await get_tree().create_timer(LEAVE_FLUSH, true, false, true).timeout
		Net.leave()
	Session.go_to_title()


# --- Presence -------------------------------------------------------------

## This player's `PresenceState`. A hand hover sends a slot index only, a table card only when both
## seats see it, and the pointer only while it is over the felt in a focused window.
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


## A HUD control is under the pointer. The full-screen HUD root passes clicks through, so it does not count.
func _pointer_over_hud() -> bool:
	var over: Control = get_viewport().gui_get_hovered_control()
	return over != null and over != hud.root


## `--dev-presence-demo`: a scripted pointer. `=card` circles our Mastery, `=hand` reads a hand
## slot, `=look` opens the rival's Discard; the bare flag cycles through the three.
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
	# The Mastery, because no role glow covers its hover.
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


## The other player's presence, sanitised again here whatever the relay did.
func _on_presence(raw: Dictionary) -> void:
	if not is_inside_tree():
		return
	var clean: Dictionary = PresenceState.sanitise(raw)
	if clean.is_empty():
		return
	_their_presence = clean
	_draw_presence(true)


## Draws the other player's presence against our view. `heard` is false for a redraw after our
## view changed, which must not refresh the pointer's fade clock.
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
	return ""


# --- Cards ----------------------------------------------------------------

func _hand_blocks_board() -> bool:
	return hand_3d.visible and (hand_3d.keyboard_active or hand_3d.blocks_pointer(get_viewport().get_mouse_position()))


## The focus preview or prompt panel covers `point`, so the table under it must not take hovers.
func _preview_blocks_point(point: Vector2) -> bool:
	if hud.tray.visible or hud.pile.visible or hud.inspect.visible or hud.handoff.visible or hud.loading.visible or hud.modal.visible:
		return false
	return (hud.focus.is_visible_in_tree() and hud.focus.get_global_rect().has_point(point)) \
		or (hud.prompt_panel.is_visible_in_tree() and hud.prompt_panel.get_global_rect().has_point(point))


func _on_card_clicked(uid: int) -> void:
	if _preview_blocks_point(hud.root.get_global_mouse_position()) and not (hand_3d.keyboard_active and _in_fan(uid)):
		return
	if _hand_blocks_board() and not _in_fan(uid):
		return
	# A pile card opens its pile unless the pending decision offers it.
	var pile: Vector2i = _pile_of(uid)
	if pile.x >= 0 and PILE_ZONES[pile.y] == &"relic":
		_open_relic_pile(pile.x)
		return
	if pile.x >= 0 and (not _can_choose() or prompt.options_for_card(uid).is_empty()):
		hud.show_pile(view, pile.x, PILE_ZONES[pile.y])
		return
	if not _can_choose():
		return
	var offered: Array[OptionView] = prompt.options_for_card(uid)
	var all: Array[OptionView] = []
	for o in offered:
		if _option_open(o):
			all.append(o)
	if all.is_empty() and not offered.is_empty():
		tutorial_panel.refuse(_option_reason(offered[0]))
		return
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


## A click on a pile's felt or caption opens the pile. Card pick boxes sit above the felt, so it
## only hears clicks that miss every card.
func _on_pile_clicked(player: int, zone: StringName) -> void:
	if view == null or hud.pile.visible:
		return
	if _hand_blocks_board() or _preview_blocks_point(hud.root.get_global_mouse_position()):
		return
	if zone == &"relic":
		_open_relic_pile(player)
		return
	hud.show_pile(view, player, zone)


## The Relic and its Reserve are one pile. A usable Relic asks whether to use it or read the pile.
func _open_relic_pile(player: int) -> void:
	var relic: int = view.player(player).relic
	var uses: Array[OptionView] = []
	if _can_choose() and relic >= 0:
		uses = prompt.options_for_card(relic)
	if uses.is_empty():
		hud.show_pile(view, player, &"relic")
	else:
		hud.show_relic_choice(uses, player)


## Which pile a card is in: (player, i) with i indexing PILE_ZONES, else (-1, -1). A standing
## effect's source is drawn outside the Removed pile, so it counts as in none.
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
	if _preview_blocks_point(hud.root.get_global_mouse_position()) and not (hand_3d.keyboard_active and _in_fan(uid)):
		return
	if _hand_blocks_board() and not _in_fan(uid):
		return
	var c: SeatCard = view.card(uid)
	if c == null or c.hidden():
		return
	hud.show_inspect(_def(c), c.aspect, uid)


func _def(c: SeatCard) -> CardDef:
	return Session.library.defs.get(c.def_id)


## The duelist's Aspect stack from the public ladder on its SeatCard, for Aspect titles. Null when absent.
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


## Source uid -> [owner, index among that owner's ghosts] for standing effects. One slot per card,
## however many effects it carries.
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
		# Public piles face up, last in list on top.
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
		# An adventure boss's power shares the Mastery row.
		var mastery_n: int = int(p.mastery >= 0) + int(p.boss_power >= 0)
		if p.mastery >= 0:
			out[p.mastery] = [zones.slot(p.index, &"mastery", 0, mastery_n, vw), true, true]
		if p.boss_power >= 0:
			out[p.boss_power] = [zones.slot(p.index, &"mastery", mastery_n - 1, mastery_n, vw), true, true]
		var reserve_n: int = p.reserve.size()
		if p.relic >= 0:
			out[p.relic] = [zones.slot(p.index, &"relic", 0, reserve_n + 1, vw), true, true]
		for i in range(reserve_n):
			# Reserve cards sit face down under the Relic.
			out[p.reserve[i]] = [zones.slot(p.index, &"relic", i + 1, reserve_n + 1, vw), false, true]
	# An attachment has no zone of its own; it rides its host, tucked behind and smaller.
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
	# A standing effect's source is lifted out of the Removed pile and stood beside its owner.
	var ghosts: Dictionary = _standing_uids()
	for uid in ghosts:
		out[uid] = [zones.slot(int(ghosts[uid][0]), &"standing", int(ghosts[uid][1]), 1, vw), true, true]
	if view.grounds >= 0:
		out[view.grounds] = [zones.slot(0, &"grounds", 0, 1, vw), true, true]
	_exchange_live = not view.resolving.is_empty() or not _held.is_empty()
	# Resolving and held cards read on the HUD rail, so they wait unseen in the Play slot and leave
	# from there.
	for uid in view.resolving:
		if not out.has(uid):
			out[uid] = [zones.slot(view.card(uid).owner, &"resolving", 0, 1, vw), true, false]
	for key in _held.keys():
		out[int(key)] = [zones.slot(int((_held[key] as Dictionary).get("seat", 0)), &"resolving", 0, 1, vw), true, false]
	return out


## `StatusMarkers` on every personality in play, and the school ring on the deciding seat's duelist.
func _refresh_markers() -> void:
	var live_energy: Dictionary = _live.get("energy", {})
	var live_might: Dictionary = _live.get("might", {})
	var live_aspect: Dictionary = _live.get("aspect", {})
	var fervors: Array = _live.get("fervor", [])
	var wanted: Dictionary = {}   # uid -> the owning SeatPlayer
	for p in view.players:
		wanted[p.duelist] = p
		for uid in p.allies:
			wanted[uid] = p
	for uid in _markers.keys():
		var old: Variant = _markers[uid]
		if not is_instance_valid(old) or not wanted.has(uid) or not views.has(uid):
			if is_instance_valid(old):
				(old as StatusMarkers).queue_free()
			_markers.erase(uid)
	for uid: int in wanted.keys():
		var v: Card3D = views.get(uid)
		var c: SeatCard = view.card(uid)
		var def: CardDef = Session.library.get_def(c.def_id) if c != null else null
		if v == null or def == null:
			continue
		var p: SeatPlayer = wanted[uid]
		var m: StatusMarkers = _markers.get(uid)
		if m == null:
			m = MARKERS_SCENE.instantiate()
			m.reduced_motion = _reduced_motion
			v.surface.add_child(m)
			_markers[uid] = m
		m.setup(faces.ladder_rect())
		m.show_card(def, _live_stat(live_aspect, uid, c.aspect), hud.seat_backdrop(p.index))
		var energy: int = _live_stat(live_energy, uid, c.energy)
		var might: int = _live_stat(live_might, uid, c.might)
		if uid != p.duelist:
			m.set_ally(energy, might, p.index != (viewer if viewer >= 0 else view.active))
			continue
		var fervor: int = int(fervors[p.index]) if p.index < fervors.size() else p.fervor
		var controller: SeatCard = view.card(_controlling_uid(p.index))
		var control: String = "%s IN CONTROL" % controller.title.to_upper() if controller != null and controller.uid != uid else ""
		m.set_duelist(energy, might, CardFace.recover_reach(energy, p), fervor, p.fervor_needed, control)


## A number the beat stamps for a card, else the view's. Keys may be strings after JSON.
func _live_stat(live: Dictionary, uid: int, settled: int) -> int:
	if live.has(uid):
		return int(live[uid])
	if live.has(str(uid)):
		return int(live[str(uid)])
	return settled


func _sync_layout(animated: bool, pinned_uid: int = -1) -> void:
	var targets: Dictionary = _targets()
	zones.set_viewer(viewer if viewer >= 0 else view.active)
	phase_track.set_viewer(viewer if viewer >= 0 else view.active)
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
	var usable: Dictionary = usable_uids(prompt, view, viewer)
	for uid in views.keys():
		var v: Card3D = views[uid]
		v.set_usable(usable.has(uid) and v.visible)
		v.set_highlight(legal.has(uid) and not usable.has(uid) and v.visible)


func _clear_highlights() -> void:
	for uid in views.keys():
		var v: Card3D = views[uid]
		v.set_usable(false)
		v.set_highlight(false)


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
	# Online, an update can play under our open decision without presenting it again; wait it out.
	while busy and online and not _dev_done:
		await get_tree().process_frame
	if _dev_done or prompt == null or busy or _awaiting_answer:
		return
	if _dev_stop_kind != &"" and _dev_stop_matches():
		for arg in DevArgs.user_args():
			if arg == "--dev-zoom" and not _hand_cards().is_empty():
				_on_card_inspected(_hand_cards()[0].uid)
			elif arg == "--dev-zoom=duelist":
				_on_card_inspected(view.player(viewer).duelist)
			elif arg == "--dev-zoom=rival":
				_on_card_inspected(view.player(1 - viewer).duelist)
			elif arg.begins_with("--dev-zoom="):
				# Any visible card by definition id.
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
			# A batch tray picks two cards; otherwise click the first hand card with several actions
			# (with `=final`, the first whose only action is a Final Strike).
			await get_tree().create_timer(0.2).timeout
			if prompt.has_batch():
				var picks: int = 0
				for uid in prompt.card_uids().keys():
					hud.tray_toggle(uid)
					picks += 1
					if picks == 2:
						break
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


## Random by default. `--dev-policy=attack` declares, attacks and never defends; `showcase` also defends.
## In the tutorial, the first option the lesson opens.
func _dev_pick(opts: Array[OptionView]) -> OptionView:
	if _tutorial != null:
		for o in opts:
			if _option_open(o):
				return o
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
## `option:<type>` stops on any prompt offering an option of that type, `remain` on any prompt
## while the viewer has a card out in Remain, and `remain:<type>` when one of those options uses it.
## `usable` stops when a table card other than the viewer's duelist can be used.
func _dev_stop_matches() -> bool:
	var kind: String = String(_dev_stop_kind).get_slice(":", 0)
	var flag: String = String(_dev_stop_kind).get_slice(":", 1) if String(_dev_stop_kind).contains(":") else ""
	if kind == "option":
		return prompt.find(StringName(flag)) != null
	if kind == "usable":
		var usable: Dictionary = usable_uids(prompt, view, viewer)
		usable.erase(view.player(viewer).duelist)
		return not usable.is_empty()
	if kind == "remain":
		for uid in view.player(viewer).remain:
			if flag == "" or prompt.find(StringName(flag), uid) != null:
				return true
		return false
	return String(prompt.kind) == kind and (flag == "" or bool(prompt.context.get(flag, false)))


## Online the budget counts updates, so two clients with the same budget stop on the same state.
## True when this update was the last.
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
	# Ranked runs take their shots and end in `_dev_series`.
	if _ranked and not _finished() and (_dev_concede or _dev_leave_match):
		if _dev_leave_match:
			Net.leave_match()
		else:
			Net.concede()
		return
	if _ranked and _finished():
		return
	if _dev_concede and online and not _finished():
		# Stay connected for the other client's shot of the result.
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
		# `--dev-pile=mine:discard` (or `theirs`, `removed`, `relic`) opens the pile browser.
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
		# Window startup can deliver late pointer motion that moves the requested hand preview, so
		# freeze the hand for the shot.
		for arg in DevArgs.user_args():
			var hand_preview: bool = arg == "--dev-peek" or (arg.begins_with("--dev-peek=") and arg.get_slice("=", 1).is_valid_int())
			if hand_preview and hand_3d.visible:
				hand_3d.preview_index(int(arg.get_slice("=", 1)) if arg.contains("=") else 0)
				hand_3d._layout(true)
				hand_3d.set_process(false)
				hand_3d.set_process_unhandled_input(false)
		# `--dev-resonance-tip=N` (or `far:N`): the viewer's (or the rival's) Nth Resonance sigil as if
		# hovered, pointer frozen.
		var tip_seat: DuelistDisplay = far_duelist if _dev_resonance_tip_far else near_duelist
		if _dev_resonance_tip >= 0 and tip_seat.readout.sigil_rects.size() > _dev_resonance_tip:
			near_duelist.set_process_unhandled_input(false)
			far_duelist.set_process_unhandled_input(false)
			tip_seat.hover_sigil(_dev_resonance_tip, camera)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_dev_screenshot)
		print("screenshot saved to %s" % _dev_screenshot)
	if _presence_on and _presence_demo != "":
		await get_tree().create_timer(PRESENCE_DEMO_LINGER, true, false, true).timeout
	elif online and Net.resumed:
		# Leaving at once would spoil the other instance's shot of this seat's return.
		await get_tree().create_timer(DEV_LINGER, true, false, true).timeout
	if after_replay:
		_dev_quit_after_replay = true
	elif find_another:
		_on_find_another()
	else:
		_dev_shutdown()


## Ranked dev runs. Between games: saves `<png>_game<N>.png` and, under `--dev-next-game`, presses
## Ready. Match result: saves `<png>` and quits after DEV_LINGER.
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


# --- Tutorial ---------------------------------------------------------------

## One action of the tutorial script, asked of its director with the two seats' views: a stop to
## play, a line in passing, a board adjustment, a rival move, or the player's prompt with only the
## taught move open.
func _tutorial_next() -> void:
	var referee: Referee = duel_host.referee
	var action: Dictionary = _tutorial.next_for(referee)
	_tutorial_action = action
	_announce_lesson()
	match str(action["do"]):
		"say":
			_tutorial_say(action["step"])
		"bark":
			_tutorial_bark(TutorialDirector.lines_of(action["step"]))
			_tutorial.done(action)
			_tutorial_action = {}
			_present_prompt()
		"op":
			await _tutorial_op(action)
		"rival":
			await _tutorial_rival(action)
		"player":
			_tutorial_prompt(action)
		"end":
			await _tutorial_finish()
		_:
			push_warning("Tutorial: %s" % str(action.get("why", "the script stalled")))
			if referee.prompt_for(viewer) != null:
				_tutorial_prompt(action)
			elif referee.prompt_for(TutorialDirector.RIVAL) != null:
				var quiet: OptionView = TutorialDirector.quiet_option(referee.prompt_for(TutorialDirector.RIVAL))
				await _tutorial_apply(TutorialDirector.RIVAL, quiet.to_command(TutorialDirector.RIVAL).to_dict(), {})


## A new lesson: its title as a banner over the table, in the panel's corner, and in the save.
func _announce_lesson() -> void:
	var n: int = _tutorial.lesson()
	if n == _tutorial_lesson or n <= 0:
		return
	# A table opened partway into a lesson (a dev flag) only names it in the corner.
	var opening_midway: bool = _tutorial_lesson == 0 and _tutorial.index > _tutorial.lesson_start(n)
	_tutorial_lesson = n
	var heading: String = "Lesson %d · %s" % [n, _tutorial.lesson_title(n)]
	tutorial_panel.set_lesson(heading)
	if not opening_midway:
		hud.show_banner(heading, ZenithTheme.ACCENT, DuelHud.Banner.HANDOVER)
	Session.tutorial_reached(n)


## A stop: the decision panel stays down while its lines play, and the table waits for them.
func _tutorial_say(step: Dictionary) -> void:
	_gate = {}
	hud.set_gate({})
	hud.clear_prompt()
	_clear_highlights()
	_refresh_state()
	_refresh_roles()
	_set_hand({})
	var lines: Array[Dictionary] = []
	_tutorial_ring = []
	for l in TutorialDirector.lines_of(step):
		var line: Dictionary = _tutorial_line(l)
		lines.append(line)
		if _tutorial_ring.is_empty():
			_tutorial_ring = line["rings"]
	if str(step.get("fx", "")) == "plate":
		_plate_moment()
	var hold: bool = bool(step.get("hold", false))
	tutorial_panel.play_stop(lines, hold)
	_tutorial_shot()
	if _dev_autoplay and hold:
		await get_tree().create_timer(TUTORIAL_HOLD_WAIT).timeout
		tutorial_panel.advance()


## The player's decision, with Vale's instruction beside the move. A keep with no words of its own
## takes the box down.
func _tutorial_prompt(action: Dictionary) -> void:
	_gate = action.get("gate", {})
	var step: Dictionary = action.get("step", {})
	_tutorial_ring = _ring_list(step.get("ring", []))
	tutorial_panel.instruct(str(step.get("callout", "")), _speaker_face(_tutorial.speaker("vale")), _tutorial_ring)
	_show_prompt_for_viewer()
	_tutorial_shot()


## Lines said in passing while play goes on.
func _tutorial_bark(lines: Array[Dictionary]) -> void:
	for l in lines:
		var line: Dictionary = _tutorial_line(l)
		tutorial_panel.bark(str(line["at"]), str(line["text"]), line["face"], line["rings"])


## A scripted line as the panel shows it: where (`at`), the words, Vale's face for the coach box,
## and what it rings.
func _tutorial_line(l: Dictionary) -> Dictionary:
	var who: Dictionary = _tutorial.speaker(str(l.get("who", "")))
	var at: String = str(who.get("at", "coach"))
	return {"at": at, "text": str(l.get("text", "")), "face": _speaker_face(who) if at == "coach" else null,
		"rings": _ring_list(l.get("ring", []))}


func _speaker_face(who: Dictionary) -> Texture2D:
	var card_id: String = str(who.get("card", ""))
	return CardFace.art_texture(Session.library.get_def(card_id)) if card_id != "" and Session.library.has(card_id) else null


static func _ring_list(ring: Variant) -> Array[String]:
	var out: Array[String] = []
	for r in (ring if ring is Array else [ring]):
		if str(r) != "":
			out.append(str(r))
	return out


## A rival move the script names comes after a wind-up: the rival's card rises and glows, and any
## line it carries is said. A quiet answer only pauses.
func _tutorial_rival(action: Dictionary) -> void:
	var step: Dictionary = action.get("step", {})
	var says: Dictionary = TutorialDirector.says_of(step)
	if not says.is_empty():
		var said: Array[Dictionary] = [says]
		_tutorial_bark(said)
	if not bool(action.get("advance", false)):
		await get_tree().create_timer(0.05).timeout
	else:
		var move: StringName = StringName(str((action["wire"] as Dictionary).get("type", "")))
		var rival: Card3D = views.get(view.player(TutorialDirector.RIVAL).duelist)
		if rival != null and not TutorialDirector.QUIET.has(move):
			await rival.gather(TUTORIAL_WINDUP)
		else:
			await get_tree().create_timer(TUTORIAL_RIVAL_BEAT).timeout
	await _tutorial_apply(TutorialDirector.RIVAL, action["wire"], action)


## The tutorial's practice dummy, which rocks and sheds straw when hit.
func _is_dummy(uid: int) -> bool:
	if _tutorial == null or uid < 0 or view == null:
		return false
	var c: SeatCard = view.card(uid)
	return c != null and c.def_id == _tutorial.dummy()


## Lesson 3's climb: grey light sweeps Emrys' card with the caption that names it.
func _plate_moment() -> void:
	var uid: int = view.player(viewer).duelist
	var v: Card3D = views.get(uid)
	if v == null:
		return
	v.sheen(PLATE_GREY.lightened(0.2))
	var pos: Vector3 = _card_pos(uid)
	fx.ring(pos, PLATE_GREY, 1.1)
	fx.burst(pos, PLATE_GREY, 26, 1.4)


func _on_tutorial_advanced() -> void:
	if _tutorial == null or str(_tutorial_action.get("do", "")) != "say" or busy:
		return
	_tutorial.done(_tutorial_action)
	_tutorial_action = {}
	_tutorial_ring = []
	_present_prompt()


func _tutorial_op(action: Dictionary) -> void:
	busy = true
	hud.clear_prompt()
	_clear_highlights()
	_tutorial_ring = []
	var result: Dictionary = duel_host.script(action["op"])
	var problem: String = str(result["problem"])
	if problem != "":
		push_error("Tutorial board adjustment refused: %s" % problem)
		busy = false
		return
	_tutorial.done(action)
	var updates: Array[SeatUpdate] = result["updates"]
	await _play_update(updates[maxi(viewer, 0)])
	busy = false
	_present_prompt()


## One move through the host, for either seat. The director moves on only once it has applied.
func _tutorial_apply(seat: int, wire: Dictionary, action: Dictionary) -> void:
	busy = true
	hud.clear_prompt()
	hud.hide_inspect()
	_clear_highlights()
	_gate = {}
	hud.set_gate({})
	if seat == viewer:
		_tutorial_ring = []
		tutorial_panel.leave()
		var says: Dictionary = TutorialDirector.says_of(action.get("step", {}))
		if not says.is_empty():
			var said: Array[Dictionary] = [says]
			_tutorial_bark(said)
	var result: Dictionary = duel_host.apply(seat, wire)
	var problem: String = str(result["problem"])
	if problem != "":
		push_error("Tutorial move refused: %s" % problem)
		busy = false
		return
	if not action.is_empty():
		_tutorial.done(action)
	var updates: Array[SeatUpdate] = result["updates"]
	await _play_update(updates[maxi(viewer, 0)])
	busy = false
	_present_prompt()


## The script is over: the session ends with no winner, and the table closes to where the tutorial
## was started from.
func _tutorial_finish() -> void:
	_ended = true
	_tutorial_ring = []
	tutorial_panel.clear()
	hud.clear_prompt()
	hud.show_banner("Session ended", ZenithTheme.ACCENT, DuelHud.Banner.HANDOVER)
	await get_tree().create_timer(TUTORIAL_END_HOLD).timeout
	if _dev_autoplay:
		print("tutorial finished at lesson %d" % _tutorial.lesson())
		_dev_shutdown()
		return
	Session.finish_tutorial()


## `--dev-screenshot` in a tutorial: the shot of the first step shown, once the table has settled
## (`--dev-shot-delay` seconds, 2.4 by default). With `--dev-shot-fan` a ring on a card's number is
## shown with the fan open on that card, and with `--dev-shot-greyed` the box shows the reason of
## the first greyed option.
func _tutorial_shot() -> void:
	if _dev_screenshot == "" or _dev_done or _dev_autoplay:
		return
	_dev_done = true
	if _dev_shot_greyed:
		var reasons: Array = _gate.get("reasons", [])
		for reason in reasons:
			if str(reason) != "":
				await get_tree().create_timer(0.6, true, false, true).timeout
				tutorial_panel.show_reason(str(reason))
				break
	await get_tree().create_timer(_dev_shot_delay if _dev_shot_delay >= 0.0 else TUTORIAL_SHOT_DELAY, true, false, true).timeout
	# Wherever the desktop pointer happens to rest, its quick view is not part of the shot.
	hud.hide_peek()
	# The hand is frozen so late window motion cannot close the fan before the shot.
	for target in _tutorial_ring:
		if _dev_shot_fan and target.begins_with("number:"):
			var fan: Array[int] = _fan_uids(view.player(viewer))
			var shown: int = fan.find(_viewer_card(target.get_slice(":", 1), fan))
			if shown >= 0:
				hand_3d.preview_index(shown)
				hand_3d._layout(true)
				hand_3d.set_process(false)
				hand_3d.set_process_unhandled_input(false)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dev_screenshot)
	print("screenshot saved to %s" % _dev_screenshot)
	_dev_shutdown()


## Where a ring target or a bubble's anchor is on screen, for the panel: {"ring": what to ring,
## "body": what to stand clear of}. A mark on a duelist card stands clear of the card and its piles,
## a hand card of its place in the fan (the preview may stand in for it), a button of the panel.
func _tutorial_locate(target: String) -> Dictionary:
	var out: Dictionary = {"ring": Rect2(), "body": Rect2()}
	if view == null or viewer < 0:
		return out
	var ring: Rect2 = _ring_rect(target)
	var body: Rect2 = ring
	var what: String = target.get_slice(":", 0)
	var arg: String = target.get_slice(":", 1) if target.contains(":") else ""
	var seat: int = 1 - viewer if arg == "rival" else viewer
	match what:
		"ladder", "power", "fervor", "aspect", "duelist":
			body = _duelist_cluster(seat)
		"hand", "number", "text":
			if arg != "" and arg != "rival":
				var fan_rect: Rect2 = hand_3d.fan_rect_of(_viewer_card(arg, _fan_uids(view.player(viewer))))
				body = fan_rect if fan_rect.has_area() else ring
		"prompt":
			body = hud.prompt_panel.get_global_rect() if hud.prompt_panel.visible else ring
		"bark":
			# The Fervor tab and the Aspect caption stand just past the card's edges.
			body = ring.grow_individual(0.0, ring.size.y * BARK_MARGIN, 0.0, ring.size.y * BARK_MARGIN) if ring.has_area() else ring
	out["ring"] = ring
	out["body"] = body if body.has_area() else ring
	return out


## A duelist card with its Life Deck, discard, out pile and Relic slot around it.
func _duelist_cluster(seat: int) -> Rect2:
	var out: Rect2 = _card_rect(view.player(seat).duelist)
	if view.player(seat).mastery >= 0:
		out = out.merge(_card_rect(view.player(seat).mastery))
	for zone: StringName in [&"life_deck", &"discard", &"removed", &"relic"]:
		var r: Rect2 = _zone_rect(seat, zone)
		if r.has_area():
			out = r if not out.has_area() else out.merge(r)
	return out


## A table zone's slot on screen, card or no card.
func _zone_rect(seat: int, zone: StringName) -> Rect2:
	if camera == null:
		return Rect2()
	var slot: Transform3D = zones.global_transform * zones.slot(seat, zone, 0, 1, viewer)
	if camera.is_position_behind(slot.origin):
		return Rect2()
	var size: Vector2 = TableLayout.CARD_SIZE
	var bounds: Rect2 = Rect2()
	var corners: Array[Vector2] = [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
	for i in range(corners.size()):
		var point: Vector2 = camera.unproject_position(slot * Vector3(corners[i].x * size.x, 0.0, corners[i].y * size.y))
		bounds = Rect2(point, Vector2.ZERO) if i == 0 else bounds.expand(point)
	return bounds


## What Vale's box and the bubbles keep off: the decision panel, the rail, both duelist cards and
## their piles, the viewer's hand and the rival's, and the options button.
func _tutorial_keepouts() -> Array[Rect2]:
	var found: Array[Rect2] = []
	var out: Array[Rect2] = []
	if view == null or viewer < 0:
		return out
	for control: Control in [hud.prompt_panel, hud.focus, hud.options_button]:
		if control.is_visible_in_tree():
			found.append(control.get_global_rect())
	for seat in range(2):
		found.append(_card_rect(view.player(seat).duelist))
		if view.player(seat).mastery >= 0:
			found.append(_card_rect(view.player(seat).mastery))
		for zone: StringName in [&"life_deck", &"discard", &"removed", &"relic"]:
			found.append(_zone_rect(seat, zone))
		for drill in view.player(seat).drills:
			found.append(_card_rect(drill))
	found.append(hand_3d.fan_screen_rect())
	found.append(_ring_rect("hand:rival"))
	# The phase track runs across the gap between the two duelist cards.
	var near: Rect2 = _card_rect(view.player(viewer).duelist)
	var far: Rect2 = _card_rect(view.player(1 - viewer).duelist)
	if near.has_area() and far.has_area():
		var gap_top: float = minf(near.position.y, far.position.y) + minf(near.size.y, far.size.y)
		var gap_bottom: float = maxf(near.position.y, far.position.y)
		found.append(Rect2(near.position.x - near.size.x * 0.85, gap_top, near.size.x * 2.7, gap_bottom - gap_top))
	for r in found:
		if r.has_area():
			out.append(r)
	return out


## The hand's enlarged preview card while one is up.
func _tutorial_preview() -> Rect2:
	var hovered: int = hand_3d.hovered_uid()
	return hand_3d.screen_rect_of(hovered) if hand_3d.revealed and hovered >= 0 else Rect2()


## What a ring target names, on screen: `life_deck`, `discard`, `ladder`, `power`, `fervor`,
## `aspect` and `duelist` (the card, as is `bark`) take `:you` or `:rival`; `hand` alone is the
## viewer's fan, `hand:rival` the rival's, and `hand:<card id>`, `number:<card id>` and
## `text:<card id>` one card in the viewer's fan; `drill:<card id>` a Drill in play; `prompt` the
## decision panel and `prompt:<option type>` its open button of that type; `tray:<card id or value>`
## the tray's face or tile for that option.
func _ring_rect(target: String) -> Rect2:
	var what: String = target.get_slice(":", 0)
	var arg: String = target.get_slice(":", 1) if target.contains(":") else ""
	var seat: int = 1 - viewer if arg == "rival" else viewer
	var p: SeatPlayer = view.player(seat)
	match what:
		"life_deck":
			return _card_rect(p.life_deck[0]) if not p.life_deck.is_empty() else Rect2()
		"discard":
			return _card_rect(p.discard.back()) if not p.discard.is_empty() else Rect2()
		"ladder":
			var ladder: Rect2 = faces.ladder_rect()
			return _card_rect(p.duelist, Rect2(ladder.position / Hand3D.FACE_SIZE, ladder.size / Hand3D.FACE_SIZE))
		"power":
			return _card_rect(p.duelist, Rect2(0.03, 0.79, 0.94, 0.19))
		"fervor":
			return _card_rect(p.duelist, FERVOR_TAB)
		"aspect":
			return _card_rect(p.duelist, ASPECT_BOX)
		"duelist", "bark":
			return _card_rect(p.duelist)
		"hand":
			if arg == "rival":
				return far_duelist.screen_rect_of(far_duelist.readout.hand_fan_rect(), camera)
			if arg == "":
				return hand_3d.fan_screen_rect()
			return hand_3d.screen_rect_of(_viewer_card(arg, _fan_uids(p)))
		"number", "text":
			# The attack badge over the art, or the rules text box. While the fan is tucked neither
			# is on screen, so the ring goes round the card until the pointer opens it.
			var shown: int = _viewer_card(arg, _fan_uids(p))
			var part: Rect2 = NUMBER_BADGE if what == "number" else TEXT_BOX
			var inner: Rect2 = hand_3d.screen_rect_of(shown, part)
			if inner.size.y > 4.0 and inner.end.y < get_viewport().get_visible_rect().size.y - 1.0:
				return inner
			return hand_3d.screen_rect_of(shown)
		"drill":
			return _card_rect(_viewer_card(arg, p.drills))
		"prompt":
			if arg == "":
				return hud.prompt_panel.get_global_rect() if hud.prompt_panel.visible else Rect2()
			return hud.option_rect(func(o: OptionView) -> bool: return String(o.type) == arg)
		"tray":
			var names: Callable = func(o: OptionView) -> bool:
				var c: SeatCard = view.card(o.card) if o.card >= 0 else null
				return (c != null and c.def_id == arg) or (o.value != null and str(o.value) == arg)
			return hud.option_rect(names, true)
	return Rect2()


## What the fan draws: the hand, then the Remain cards as ghosts.
static func _fan_uids(p: SeatPlayer) -> Array[int]:
	var out: Array[int] = p.hand.duplicate()
	out.append_array(p.remain)
	return out


## A point off the table's edge beyond `seat`'s `zone`, lifted a little, where cards come on from
## and go off to when the tutorial adjusts the board.
func _offstage_point(seat: int, zone: StringName) -> Vector3:
	var vw: int = viewer if viewer >= 0 else view.active
	var at: Vector3 = (zones.global_transform * zones.slot(seat, zone, 0, 1, vw)).origin
	var outward: Vector3 = Vector3(at.x, 0.0, at.z)
	outward = outward.normalized() if outward.length() > 0.01 else Vector3(0, 0, -1)
	return at + outward * 4.0 + Vector3(0, 0.6, 0)


## The first of `uids` showing card `id`, -1 for none.
func _viewer_card(id: String, uids: Array[int]) -> int:
	for uid in uids:
		var c: SeatCard = view.card(uid)
		if c != null and c.def_id == id:
			return uid
	return -1


## A table card's screen rectangle, or the part of it given in face fractions (top left 0,0).
func _card_rect(uid: int, part: Rect2 = Rect2(0, 0, 1, 1)) -> Rect2:
	var v: Card3D = views.get(uid)
	if v == null or not v.visible or camera == null or camera.is_position_behind(v.global_position):
		return Rect2()
	var size: Vector2 = TableLayout.CARD_SIZE
	var corners: Array[Vector2] = [part.position, Vector2(part.end.x, part.position.y), part.end, Vector2(part.position.x, part.end.y)]
	var bounds: Rect2 = Rect2()
	for i in range(corners.size()):
		var local: Vector3 = Vector3((corners[i].x - 0.5) * size.x, 0.0, (corners[i].y - 0.5) * size.y)
		var point: Vector2 = camera.unproject_position(v.surface.global_transform * local)
		bounds = Rect2(point, Vector2.ZERO) if i == 0 else bounds.expand(point)
	return bounds


## Quits on the next process_frame, after queue_free has released the scene, so renderer nodes and
## tweens are gone before shutdown.
func _dev_shutdown() -> void:
	var tree: SceneTree = get_tree()
	tree.process_frame.connect(tree.quit, CONNECT_ONE_SHOT)
	queue_free()
