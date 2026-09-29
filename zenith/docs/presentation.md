# Client presentation

How the duel and menu screens look and behave, and where to tune them. Consolidated 2026-09-22
from the interface redesign (2026-09-19), the combat UX revamp (2026-09-20 to 21), the combat
presentation notes and the two ambience passes. The engine-facing detail (views, forecasts, event
data) is in `../README.md` under Client.

## Direction

The duel reads as a focused fighter-versus-fighter card duel. The two duelist cards, their five
core values (Life, Energy, Might, Aspect, Fervor) and the cards exchanged in Combat own the centre
of the screen. Piles, history, settings and status sit at the edges and grow only when opened or
when they bear on the current decision. Fighters stay cards: feedback uses card movement, scale,
colour, shader flashes, particles and floating values, never bespoke character animation. Clients
still render only from `SeatView` and `PromptView`, and every calculated outcome comes from the
referee's presentation data.

## Duel layout

- **Hand and incoming attack** are Sprite3D card faces. Table cards are `Card3D`. Decision text,
  inspection, history and trays stay Control UI.
- **Each fighter is one unit**: a larger duelist card, a Life Deck tucked beside it carrying the
  one prominent Life number, and a three-column readout of Energy, Might and Fervor with Aspect in
  its header. Identity, You/Opponent and a controlling Ally live in that readout. The readout is a
  Node3D fixture rendered through a transparent SubViewport, anchored to the projected card corners
  so it follows perspective and zoom.
- **Combat lane**: the declared attack and any response card sit in stable slots on their owner's
  side of the gap between the fighters. A filament links source to target; a transverse cap marks
  a stop and a double arrow marks damage landing. Public opponent cards used in Combat also get a
  readable face at the right edge. A used card stays in its owner's Play slot until its part of
  the exchange is over (`DuelView._held`), even when the rules already sent it to a pile or the
  bottom of the Life Deck, and only then flies there.
- **Read hold and the pinned pair**: every declared attack pins its public face in the Focus slot
  (`Root/Focus`) and holds there before the next beat, `ATTACK_READ` 2.2 s for an opponent's card
  and `ATTACK_READ_OWN` 1.0 s for the viewer's own, so an attack the defender cannot meet is read
  rather than glimpsed. An attack with no card of its own (a duelist Power, a Final Strike from
  the fighter) pins that personality instead. The card stays in the slot for the whole exchange,
  across the update boundary the defender's decision sits on, and its caption moves on with it:
  "Your attack · <title>", "Incoming" while the viewer is asked to defend, "No defense · <reason>",
  "Stopped", "Hits for N Energy / M wounds", "Dealt …", then the slot clears `FOCUS_RELEASE`
  0.6 s after `attack_end`. The prompt's own focus card is the same card in the same rect, so the
  hand-over between a replay beat and a decision does not move it.
- **Response stack**: a card that answers the attack (a defense, a defense Power, a Shield, a
  counter, an Endurance) is laid **over** the anchored attack rather than under it, in
  `Root/Focus/Stack`, which is clipped to the Focus rect and so costs the decision column nothing.
  Each response is a face at `STACK_SCALE` 0.8 of the Focus face, stepped `STACK_STEP` (-26, -34)
  up and to the left per level with a ±`STACK_TILT` 2.5° alternating tilt, newest drawn on top, so
  the attack keeps its caption and its top band and every card under the newest one still shows the
  caption strip on its bottom edge: "Defense", "Power", "Shield", "Counter", "Endurance". The strip
  and border take the owner's role colour, attack red for the attacker's own follow-ups and defend
  blue for the other seat's. A response holds on top for `OPPONENT_DEFENSE_READ` 2.2 s
  (`OPPONENT_STOP_READ` 3.2 s for a stop) when it is the opponent's and `ANSWER_READ_OWN` 1.0 s
  when it is the viewer's own, then the beat that resolves it takes it off again: a countered card
  at `countered` and the counter itself right after its hold, a defense at `attack_stopped` or, if
  it did not stop the attack, at `attack_successful`, a Shield at its `shield` beat, an Endurance at
  `endurance_used`. Leaving is a 0.25 s drift towards its owner's rail with a fade, snapped under
  Reduced Motion. A beat that resolves something the stack never held does nothing. The attack
  leaves last, at `attack_end`. Because the stack takes no room of its own, a decision opens with it
  still up: the player answering sees the attack and whatever already answered it under the prompt's
  own Focus caption, with the prompt panel below the same rect. These holds run through `_beat`, so Space-skip,
  `--dev-fast` and `--dev-freeze` all still work, but they do not take the queue's pacing scale:
  reading time is not pacing. Reduced Motion keeps them for the same reason. Outside an attack, a
  card used or a trigger fired puts its face in the slot for `CARD_USE_READ` 0.8 s when it carries
  rules text, so a used card is never only a hop and a name.
- **Decision column**: the focused card sits near the right edge with question, consequence,
  instruction and actions in one bounded column that fits at 1280x720 without scrolling. Damage and
  outcome previews use a fixed two-line result slot. Hovering or keyboard-focusing an offered
  defense or Endurance choice shows a labelled preview from the referee and never changes the game.
  Stop progress shows when more than one stop is needed. Once damage resolves, dealt damage and
  remaining wounds are shown apart. When the only offered action is one non-card option, it is
  rendered as a single large button labelled by what it does ("Pass", "No Defense", "Let it
  resolve", "No Combat"), with " · ends Combat" appended when the next pass would close Combat;
  Space takes it. Two or more alternatives stay equal-weight rows and Space does nothing.
- **Everything pending, on the right**: there is no second column anywhere on the screen. The Focus
  slot and the stack over it are the one place a waiting card appears, and `DuelHud.refresh_state`
  reconciles that pile against `SeatView.pending` on every beat. The anchor, the big face in the
  slot, is the `attack` item when there is one and otherwise whatever resolves first; a trigger
  anchor is captioned "Trigger · <note>", a pending card "Awaiting a counter", and an attack anchor
  keeps the caption that walks with the exchange. Every other job is a face stacked over the anchor,
  pushed in reverse list order so the one resolving **next** is on top: a `trigger` with the strip
  "Trigger" in its owner's role colour, a `hidden` job as a card back reading "Opponent's trigger".
  A `wounds` job is the attack's own loop rather than a card, so it is no face at all, only
  "· 3 wounds to resolve" appended to the anchor's caption. Faces the queue dealt are keyed, so a
  refresh takes one off with the same leaving drift when its job is gone and no beat popped it, and
  a replay beat naming a card already on the pile renames that face rather than dealing a second
  copy of it. Past `STACK_MAX` 4 faces the jobs furthest from resolving give up their faces for a
  "+N" badge on the top one. An emptied queue with no pinned attack clears the slot. A trigger whose
  card is already in the slot or on the pile is lit and read where it stands for `CARD_USE_READ` and
  then leaves the pile; only a card that is nowhere on the right still hops on the table. The
  filament to the target comes off the anchored card: a HUD-layer line (`Root/FocusFilament`) from
  the left edge of the Focus face, or of the topmost stacked response when that response is the job
  resolving now, to `DuelView.screen_anchor` of the current pending item's target, or of the
  anchor's own target when no item is flagged `current`. It is the 2D reading of the same cue the
  table draws, a bowed thread in the attack colour with a transverse cap when `attack.stopped` and a
  double chevron once `landed`, and it is redrawn every frame because the camera can move under a
  settled state. No target or no anchored card means no line.
- **Pending cards**: an announced card awaiting a response is `SeatView.pending_card`, with its
  public face; other hand cards stay private. `SeatView.pending` is the ordered list of what
  resolves next, first element first, and it **is** an ordering contract: the engine works through
  it top to bottom, so it can be drawn in order. Items are `{kind, uid, title, owner, target,
  note, current}`, `kind` one of `attack`, `pending_card`, `trigger`, `hidden`, `wounds`, with one
  item flagged `current`. A `hidden` item stands for a rival job this seat may not see and carries
  its owner alone. The resolving-zone list is still not an ordering contract.
- **Off-field cards** sit on the felt, not in a screen-edge rail: Discard under the Life Deck,
  the Mastery beside the duelist, Out and the Relic (with its Reserve under it) flanking the stat
  crest. Empty piles keep their outline and caption; every pile is browsable in one click. Recent
  history is about two lines with full History expandable. Reduced Motion and Dev sit behind the
  options gear at the top right.
- **Phase track** (2026-09-25, replaced the top phase bar): the turn is printed on the table along
  the waist between the duelists as Kenney board-game icons (`scenes/duel/phase_track.tscn`,
  `PhaseTrack`): Draw, Place, Power Up and Declare in the left notch, Enter, Attack, Defend,
  Resolve and End across the ring, Discard, Recover and End turn in the right notch, ordered for
  whoever sits at the table. The step the beat stands on is lit (larger, with a halo; Attack in
  the attack colour, Defend in the table's defence slate), steps behind are dimmed, steps ahead
  faint, and End warms when one more pass ends Combat. PREPARE_* and OPPOSING_DRAW read as Enter,
  FIGHT_BACK as Attack. A beat inside a step pulses its icon. There is no text: whose turn it is
  shows as a soft light along the inside edge of the active seat's half of the mat
  (`playmat.gdshader` `active_lobe`), which crosses the table at a turn change.
  Everything is read from the beat's own state first, so a replaying update never draws ahead of
  the cards on the table.
- **Beat banner**: one ribbon across the ring (`Root/Banner`, `DuelHud.show_banner`), fading at
  both ends and stopping short of the notches. Hand-overs (Combat opening with its first attacker,
  "X attacks", "Combat over", a new turn) sweep open; outcomes (the attack's name,
  "Stopped", a wound) pop; quiet beats are a translucent line that never cuts short a louder
  banner younger than 0.6 s. Bone is the act-here colour, so the rival's turn banner is grey.
- **Scale policy**: 1920x1080 canvas base, expanded across aspect ratios. At 1280x720 decision text
  is about 16 displayed pixels, supporting text about 14, click targets at least 40 high.

Feedback vocabulary: declaration slides and scales into the lane and pins its face in the Focus
slot with a caption that follows the exchange to its outcome; an answering card is pushed onto the
stack over it and drifts off again when the beat that resolves it arrives, so action and reaction
are on screen together and the exchange reads as one pile emptying; a legal response carries an aura;
a stop flashes defense colour and knocks the attacker back; a skipped or passed window gets a quiet
banner so nothing resolves silently; the attacker jabs as the damage lands and both fighters hold
on the contact frame for the hit's weight (`hit_tier`: chip, solid, or heavy at three wounds'
worth, which also punches the camera once), then the target shakes with its number over it;
Energy that spills over slides "+N wounds" to the Life Deck; a wound
pulses the Life number as the card lifts, reveals and flies to its pile; Second Wind returns the
discard in one shuffle beat; ascension raises a power-up effect. Reduced Motion keeps every state
distinction through position, border, icon and text, snaps card flights, freezes mist and inlays,
and hides the animated portal and particles.

## Controls

Move the pointer to the bottom of the screen to raise the hand; it retracts when the pointer
returns to the field, leaving the top 15% of the faces visible. Hover a hand card to enlarge it in
a lane beside the fighter, click to choose a legal action, right-click to inspect. Hand browsing
blocks board picking and tooltips. **H** raises the hand for keyboard browsing with Left/Right,
Enter chooses, Space inspects, Escape leaves. Scroll over the hand to page. Board hover, hand
browsing, inspection, history and camera movement stay available while the AI thinks, events
replay or the network is pending; commands need a settled prompt addressed to the viewer.
Hold **Space** while an update replays to run the rest of its beats at the 0.05 s floor; letting
go restores the ordinary pacing. It never answers a prompt, and it is ignored while the hand is
open for keyboard browsing, where Space inspects.
`--reduced-motion` enables Reduced Motion at launch.

## Menus and ambience

Art constraint: **no AI-generated artwork**. Environments are Godot meshes, shaders, lights and
particles, plus four stone material maps whose sources are in `../assets/materials/SOURCES.md`.
EffectBlocks v4 supplies the hall's layered fire, smoke, dust and portal, arena-edge fireflies,
and combat sparks, resolved-hit impacts, protection and ascension. Eight native Godot scenes
and their dependencies are imported; provenance is in
[`../PolyBlocks/EffectBlocks/SOURCES.md`](../PolyBlocks/EffectBlocks/SOURCES.md).
The old custom portal and ritual-wave shaders have been removed. Instance materials are private,
demo keyboard scripts are detached, and combat effects clean up after their animation.

- **Selection** (duel and adventure starter) puts a large featured portrait on the left with deck
  identity, Aspect and Mastery beside it, and a compact searchable roster on the right. Panels use
  neutral charcoal fills; school and combat-state colours carry information only. The Mastery is a
  fixed 250x350 rectangle under an independently scrolling identity area. Only the choosing seat's
  school tints the screen.
- **Tournament hub** shows the eight-stage ladder as a connected route with opponent portraits,
  completed rounds, a current-round marker, the Aspect grant and a distinct final node. Selecting
  any round previews its opponent without touching the run; only the current round can enter.
- **Sanctum**: menus and the matchup share a live 3D hall (tiled stone, columns, bronze inlays,
  braziers, dust, a school-tinted portal) in a capped-resolution SubViewport.
- **Arena** (2026-09-23): a ruined courtyard under an overcast sky. The cards lie on a plain
  charcoal felt playmat with an oxblood bound edge (`Table/Inlay` and `Table/MatEdge` in
  `duel.tscn`), inset on a grey flagstone table so a band of stone shows round it; the stone
  alone was too busy under the cards. The table stands on a brick plinth, in a cobbled yard walled on three sides by broken, mossy stone, with a
  few standing columns, one fallen, ferns and rubble along the walls and trees past them. Leaves
  drift across and two faint shafts of daylight fall into the yard. Every texture and model is
  PSX library art copied in by `tools/import_courtyard_art.py` (sources and licences in
  `../assets/courtyard/SOURCES.md`). The courtyard is the same for every matchup; school colour
  lives on the cards and the HUD. Board state sits on the board (2026-09-23): each duelist's
  Energy, Might and Fervor are on its own card since 2026-09-28 (`StatusMarkers`: the Might
  ladder as a gauge with the Surge rail, Fervor pips on a tab over the top edge, and a ring in the
  school colour on the duelist whose seat is deciding), status chips and Seal sets are printed flat
  along the seat's Ally row (at the status spot under the Seals while an Ally is in play), the
  rival's hand is printed flat on the felt, and the Life count lies on its pile. Text a banner
  already says is not floated on the table as well: no "STOPPED", "Wound N", "Endurance", "Gain
  blocked" or "Shield" labels. Zone names and outlines are ivory ink. Meta
  information (log, prompt, inspect) stays on screen in framed panels; the phase track is on the felt. Table effects draw the HUD's defence blue and accent gold in
  pale slate and old ivory (`DuelFx.tone`), because the saturated pair glowed like neon on stone.

Tuning files:

- `assets/arcane_backdrop.gdshader`: selection stone, sigils, mist, motes.
- `scripts/ui/effect_blocks.gd`, `scripts/duel/duel_fx.gd`: pack integration, impact, ward and ascension.
- `scripts/duel/arena_atmosphere.gd`: dresses the table in courtyard stone and adds the set.
- `scripts/duel/courtyard_set.gd`: the courtyard's geometry, sky, fog, sun, leaves and light shafts.
- `scripts/ui/sanctum_set.gd` (geometry, lights, particles), `scripts/ui/sanctum_ui.gd` (theme and
  menu feedback), `scripts/adventure/tournament_route.gd` (route).
- `scenes/duel/phase_track.tscn`, `scripts/duel/phase_track.gd`: the phase track on the table.
  Its icons come from `tools/import_map_art.py` (`assets/ui/phase_icons/SOURCES.md`).
- `scenes/duel/hud.tscn`, `scripts/duel/duel_hud.gd`: history, options gear, prompt, the single
  action button, the beat banner (`show_banner`, `toast`, `quiet_beat`, `handover`), the `Root/Focus` slot
  and the `Root/Focus/Stack` over it (`show_focus`, `show_replay_card`, `set_focus_caption`,
  `push_response`, `pop_response`, `clear_stack`, `focus_uid`, `pulse_pending`), the reconcile of
  that stack against `SeatView.pending` (`_reconcile_pending`, `_reconcile_stack`, `STACK_MAX`, the
  "+N" badge), the `Root/FocusFilament` line from that slot to the target on the table, overlays.
- `scenes/duel/duelist_display.tscn`, `scripts/duel/duelist_display.gd`,
  `scripts/duel/duelist_readout.gd`: the fighter unit.
- `scripts/duel/hand_3d.gd`: hand reveal, enlargement, paging, keyboard navigation.
- `scripts/duel/duel_view.gd`: focus card, event sequencing, screen-space anchors.

## Verification

Headless: `tests/run_tests.gd`, `tests/presentation_data_tests.gd`, `tests/ui_redesign_smoke.gd`,
`tests/combat_presentation_tests.gd`, `tests/ambience_smoke.gd`, `tests/sanctum_ui_smoke.gd`.
Windowed: `tests/select_ui_smoke.gd`. Check rendered states at 1280x720 and 1600x900.

Captures use the duel scene with the dev flags in the README: `--dev-stop-at=defense` for a
defense window, `--dev-stop-at=endurance --dev-hover=0` for an Endurance preview,
`--dev-stop-at=respond` for a response window, `--dev-policy=showcase --dev-freeze=attack_stopped`
for a ward and a defense stacked on the anchored attack, `--dev-freeze=attack_end` for the same
attack with the stack emptied, `--dev-policy=attack --dev-freeze=attack_declared`
for the pinned attack on its own and `--dev-freeze=no_defense` for the same card with its caption
moved on. For the one pile on the right: `--dev-policy=showcase --dev-stop-at=defense` (nothing in
the band left of the table, the filament from the Focus card),
`--dev-policy=showcase --dev-freeze=trigger_fired` (the trigger as a face on the pile) and
`--dev-policy=attack --dev-stop-at=endurance` (the wound count on the anchor's caption). Freezing mid-animation reports resources still alive at exit; that is expected.
Reference captures live in `../screenshots/`.
EffectBlocks captures: [starter](../screenshots/effectblocks-starter.png),
[combat](../screenshots/effectblocks-combat.png), [tournament](../screenshots/effectblocks-tournament.png).

## Open

- Validation matrix: only the attack-action prompt and an Energy-only defense have reviewed
  captures. Still to capture at both resolutions: overflow wounds, multi-stop defense, a stop,
  an unstoppable attack, Endurance with hover, a response window, Final Strike sub-choice,
  fight-back, a controlling Ally on each side, Fervor gain and Aspect change, a crowded hand and
  crowded permanents, multiple restrictions, the Reserve and search trays, expanded history and
  pile browser, keyboard-only play, Reduced Motion, and the AI, replay and network waiting states.
- Lower-end GPU performance has not been profiled.
