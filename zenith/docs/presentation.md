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
  readable face at the right edge.
- **Decision column**: the focused card sits near the right edge with question, consequence,
  instruction and actions in one bounded column that fits at 1280x720 without scrolling. Damage and
  outcome previews use a fixed two-line result slot. Hovering or keyboard-focusing an offered
  defense or Endurance choice shows a labelled preview from the referee and never changes the game.
  Stop progress shows when more than one stop is needed. Once damage resolves, dealt damage and
  remaining wounds are shown apart.
- **Pending cards**: an announced card awaiting a response is `SeatView.pending_card`, with its
  public face; other hand cards stay private. The resolving-zone list is not an ordering contract.
- **Backline**: one compact rail. Empty Mastery, Relic, Discard, Out and Reserve wells disappear;
  occupied ones stay browsable in one click. Recent history is about two lines with full History
  expandable; the phase strip is one compact top-centre line. Reduced Motion is a small peripheral
  control.
- **Scale policy**: 1920x1080 canvas base, expanded across aspect ratios. At 1280x720 decision text
  is about 16 displayed pixels, supporting text about 14, click targets at least 40 high.

Feedback vocabulary: declaration slides and scales into the lane; a legal response carries an aura;
a stop flashes defense colour; a hit shakes and flashes the target with its numbers over it; a wound
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
  braziers, dust, a school-tinted portal) in a capped-resolution SubViewport. The same architecture
  surrounds Combat without a second camera or WorldEnvironment.
- **Arena**: teal slate surface with bronze inlays, school-tinted edges, mist beyond the table and
  four crystal posts. School colours come from the public `SeatView` and stay with the physical
  seats when the hotseat camera swings.

Tuning files:

- `assets/arcane_backdrop.gdshader`: selection stone, sigils, mist, motes.
- `assets/arena_surface.gdshader`, `assets/arena_mist.gdshader`: combat surface and atmosphere.
- `scripts/ui/effect_blocks.gd`, `scripts/duel/duel_fx.gd`: pack integration, impact, ward and ascension.
- `scripts/duel/arena_atmosphere.gd`: posts, crystals, perimeter particles.
- `scripts/ui/sanctum_set.gd` (geometry, lights, particles), `scripts/ui/sanctum_ui.gd` (theme and
  menu feedback), `scripts/adventure/tournament_route.gd` (route).
- `scenes/duel/hud.tscn`, `scripts/duel/duel_hud.gd`: phase, history, prompt, focus, overlays.
- `scenes/duel/backline_rail.tscn`, `scripts/duel/backline_rail.gd`: the pile rail.
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
for a ward. Freezing mid-animation reports resources still alive at exit; that is expected.
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
