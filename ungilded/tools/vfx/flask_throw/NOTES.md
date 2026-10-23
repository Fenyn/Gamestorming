# Flask throw: round log

Effect: the Friend throws a Lesser Acid Flask; the flask lobs from her hand to the target's impact
point, tumbling, and on arrival the game spawns the acid splash (`scenes/fx/acid_splash.tscn`,
not part of this scene). The brief is `%TEMP%\vfx_studio\ungilded\flask_throw\brief.md` and the
sheets are in `%TEMP%\vfx_studio\ungilded\flask_throw\rNN{c,g,l,hg,hc}\sheet.png`.

HD-2D pixel art: the flask, the drops and the shadow are drawn by code on a locked palette, one
texel = 0.02 m at scale 1 (the Prologue sprites' PixelSize), sampled nearest.

State: r09 is on disk (it won blind review 3 against r07). Its scripts are also in
`%TEMP%\vfx_studio\ungilded\flask_throw\keep\r09\`.

## Files

- `build_flask_throw.gd` writes `res://scenes/fx/flask_throw.tscn` and attaches
  `res://scripts/fx/FlaskThrow.cs` when it exists. With `-- --handoff=1` it also writes
  `handoff_test.tscn` in this folder, a review scene only (the throw plus the acid splash on the
  rat, set up as the presenter sets it for a rat: ImpactHeight 0.318, Body scale 0.713). The game
  never loads it.
- `draw_flask.py` writes `res://assets/fx/flask_throw/{flask,trail,shadow}.png` and their `.import`
  files (compress/mode=0, mipmaps/generate=false, detect_3d/compress_to=0), and checks every
  pixel against the palette: acid 425A26 779539 A9BF58 E2E5A9, glass 9CADAF C3D0CE EEE5D2, cork
  523B2B 76543C 977253, shadow 000000. Index 0 is transparent. An off-list colour fails the run.
- Flask sprite: drawn, not cropped. The pack flask in the Friend's hand
  (`design/hero-sprites/masters/work/friend/layers/arm_far__relaxed__off_flask_{front,rear}.png`)
  is 5 x 7 texels, a 4 x 4 bulb under a 1 texel glass neck with no cork and no rim, because the
  hand covers them. Alone it reads as a green dot on a stick. The drawn flask keeps its palette
  and bulb shading (pale spot top left, body, mid, dark bottom right) and adds the cork and a
  glass rim: a 7 x 7 pixel-circle bulb, a 2 x 2 glass neck (C3D0CE lit side, 9CADAF far side) and
  a 3 x 2 cork, 7 x 11 upright (since r09; r01 to r05 had a 1 x 2 neck, r06 to r08 a 3 x 1 collar).
  Eight frames at 45 degree steps in 17 x 17 cells; the
  bulb is the same in every frame, the stopper is placed by hand for up and up-right and turned
  by exact quarter turns; the light stays at the top left of the screen.
- Shaders: `res://assets/shaders/vfx/vfx_essential_pixel_lit.gdshader` (flask, drops), unchanged.

## Commands (same every round)

`%TEMP%\vfx_studio\ungilded\flask_throw\round.sh rNN` runs all of these in order:

```
G=G:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64_console.exe
S=C:/Users/Midge/.claude/skills/vfx-studio
W=%TEMP%/vfx_studio/ungilded/flask_throw
python tools/vfx/flask_throw/draw_flask.py --preview $W/frames
$G --path . --headless --import
$G --path . --headless -s res://tools/vfx/flask_throw/build_flask_throw.gd --log-file $W/build.log -- --handoff=1
$G --path . --headless -s $S/scripts/audit_effect.gd --log-file $W/audit.log -- --scene=res://scenes/fx/flask_throw.tscn --length=0.65 --particles=6 --lights=0
PROPS="--prop=res://assets/sprites/heroes/friend/rest_1.png --prop-px=0.02 --prop-feet=6 --prop2=res://assets/sprites/enemies/rat_v1/idle_1.png --prop2-px=0.02 --prop2-feet=4 --prop2-at=4,0,0 --prop2-flip=1"
TIMES=0.033,0.067,0.1,0.15,0.2,0.233,0.267,0.3,0.35,0.4,0.433,0.467
# close view, neutral stage, the whole arc from the front, 29 degrees down
$G --path . --fixed-fps 60 --position -4000,-4000 -s $W/tools/capture_flask.gd -- --scene=res://scenes/fx/flask_throw.tscn --out=$W/rNNc --label=rNNc --cam=2.0,4.0,6.0 --look=2.0,0.7,0.0 --fov=40 --tile=460 --cols=4 --times=$TIMES --warmup=0.6 --strip-script=1 --frames=1 $PROPS
# game view: the 24 m orbit camera; FOV 12.4 on a 600 px tile is a crop of the 1080p frame at FOV 22
$G --path . --fixed-fps 60 --position -4000,-4000 -s $W/tools/capture_flask.gd -- --scene=res://scenes/fx/flask_throw.tscn --out=$W/rNNg --label=rNNg --cam=12.9,18.4,10.9 --look=2.0,0.5,0.0 --fov=12.4 --tile=600 --cols=3 --times=0.033,0.1,0.15,0.2,0.233,0.283,0.35,0.417,0.467 --warmup=0.6 --strip-script=1 --env=res://scenes/looks/sewer.tscn $PROPS
# lit view: dim cool key, a warm torch behind the middle of the path, shaded floor, sewer look
$G --path . --fixed-fps 60 --position -4000,-4000 -s $W/tools/capture_flask.gd -- --scene=res://scenes/fx/flask_throw.tscn --out=$W/rNNl --label=rNNl --cam=2.0,4.0,6.0 --look=2.0,0.7,0.0 --fov=40 --tile=460 --cols=4 --times=$TIMES --warmup=0.6 --strip-script=1 --lit=1 --torch=2.0,1.8,-1.2 --env=res://scenes/looks/sewer.tscn $PROPS
python $W/tools/crop_strip.py $W/rNNc $W/rNNc/strip.png
# handoff (from r05): the throw, then the acid splash on the rat from the arrival
HO="--scene=res://tools/vfx/flask_throw/handoff_test.tscn --delayed=Splash --delay=0.45 --warmup=2.2 --strip-script=1"
$G --path . --fixed-fps 60 --position -4000,-4000 -s $W/tools/capture_flask.gd -- $HO --out=$W/rNNhg --label=rNNhg --cam=12.9,18.4,10.9 --look=2.0,0.5,0.0 --fov=12.4 --tile=600 --cols=3 --times=0.1,0.2,0.3,0.4,0.433,0.483,0.55,0.7,1.0 --env=res://scenes/looks/sewer.tscn $PROPS
$G --path . --fixed-fps 60 --position -4000,-4000 -s $W/tools/capture_flask.gd -- $HO --out=$W/rNNhc --label=rNNhc --cam=2.0,4.0,6.0 --look=2.0,0.7,0.0 --fov=40 --tile=460 --cols=3 --times=0.1,0.2,0.3,0.4,0.433,0.483,0.55,0.7,1.0 $PROPS
```

- Stand-ins: the Friend's `rest_1.png` at the origin and the rat's `idle_1.png` (mirrored) at
  (4, 0, 0), both at 0.02 m a pixel, the game's PixelSize. The sheets use `--strip-script=1`, because
  `FlaskThrow.cs` would move the flask itself and free the scene after the flight.
- The game view's FOV 12.4 keeps the 24 m camera of the other effects' game views but shows the
  flask at the pixel density of a 1920 x 1080 window (117 px a metre); at FOV 22 a 600 px tile shows
  it at 0.56 of that.
- `crop_strip.py` cuts a 64 px square round the flask's projected position from each close frame
  and tiles them at 4x (`rNNc/strip.png`).

## Tool changes (work folder only; the skill is unchanged)

- `$W/tools/capture_flask.gd`: a copy of the skill's `capture_sheet.gd`. The stand-in code moved
  into `_add_prop`, with a second stand-in `--prop2`, `--prop2-at`, `--prop2-px`, `--prop2-feet` and
  `--prop2-flip` (and `--prop-flip`), so the sheets show the creature the flask lands on.
- `$W/tools/crop_strip.py`: the flask crop strip.
- `capture_flask.gd` (r05): `--delayed=<node> --delay=<s>` starts that subtree's emitters and
  players at the delay instead of at 0 (the splash in the handoff scene), and `--strip-script=1`
  strips the script of every node in the scene (the skill's script strips the root's).
- `$W/tools/adapter_test.gd`: renders `FlaskThrow.cs` moving the real scene (script kept, `Aim()`
  called before `add_child`, the thrower at (1, 0, 2)), prints the aimed values, the game time of
  `Arrived` and of leaving the tree; `--left=1` throws toward -X, screen-left in the game camera.
- `$W/tools/lifecycle_test.gd`: headless, three throws 0.2 s apart, the second freed mid-flight.

## Hook (FlaskThrow : OneShotFx, integrated 2026-10-22)

To see it in the game: F9 "Encounter 3", the Friend's turn, Abilities, Throw Acid Flask at Rat C.

- Scene `res://scenes/fx/flask_throw.tscn`, root `Node3D` named FlaskThrow with
  `res://scripts/fx/FlaskThrow.cs`. Nodes the game touches, all unique names: `%Ground` (y 0.015)
  holds `%Shadow` (Sprite3D, flat, 6 frames); `%Body` holds `%Flask` (GPUParticles3D, one particle,
  8-frame tumble played 1.75 times over its life, lit pixel material), which holds `%Trail`
  (GPUParticles3D, world coordinates, 3 alive, 0.22 s); `%Anim` (AnimationPlayer, animation
  `play`). There is no light since r02.
- `%Anim` is for the sheets only. Its `play` flies the fixed 4-tile throw by keying
  `Body/Flask:position`, `Ground/Shadow:position`, `:frame`, `:modulate`, `:visible` and
  `Body/Flask/Trail:emitting`. The game never plays it.
- `BombActions.ExecuteThrow` sets `BombEventKeys.Thrown` on the throw's one AttackRolled, which
  comes before its DamageDealt events and on a miss or a critical miss too.
  `GodotPresenter3D` (AttackRolled) faces and lunges the thrower as for a Strike, waits the lunge
  gate, then, in place of the melee accent, `ThrowFlask`: it instances `FxLibrary.FlaskThrowScene`,
  calls `Aim(thrower.Position, target.Position, thrower.GlowBodyHeight * 0.6, target.HpBarHeight *
  0.6)` (`HandHeightFraction`, `ImpactHeightFraction`), sets `BodyPixelSize` from the thrower's
  `SpritePixelSize`, sets `SurfaceHeight` to its `SurfaceY`, spawns it with `SpawnFx` at the
  thrower's feet and awaits `FlightSeconds` unpaced. The miss dodge and MISS floater, and the
  DamageDealt splash, follow the flight. One throw per flask action.
  `FxLibrary.PreloadEncounterEffects` loads the scene as the board builds.
- `SurfaceY` (presenter) is the drawn board surface at a board-space point:
  `TerrainCutaway.CutTopY` (the stub top or foot of masonry the wall cut takes down this frame,
  pillars included) when the cut takes that tile down, else `TerrainHeightMap.SampleY` on the
  tile's own triangle. `CombatScene.StartEncounter` hands the presenter the stage's cutaway.
- Positions are in the parent's space, the same space as `Position`. `Aim` puts
  the hand `HandForward` (0.15 m) toward the target and sets `FlightSeconds` and `ApexHeight` from
  the tiles thrown (feet to feet, 1 tile = 1 m): flight 0.4 s at 3 tiles plus 0.03 s a tile,
  clamped to 0.3 to 0.65 s; apex 0.3 m a tile, clamped to 0.5 to 2.0 m.
- `Build` sets `Lifetime = FlightSeconds`, scales `%Flask` and `%Shadow` by `BodyPixelSize /
  FramePixelSize` (1 for the Prologue's 0.02 m sprites), copies `%Trail`'s process material with
  the drop direction turned along the throw, copies `%Flask`'s with a negative anim speed when the
  throw flies screen-left (the frames turn clockwise), restarts `%Flask`, and runs one method tween
  over the flight that moves `%Flask` on the arc (straight from Start to End plus 4 h s (1 - s))
  and `%Shadow` under it. `%Trail` emits from 10 to 50 percent of the flight. On every tween step
  the shadow takes the `SurfaceHeight` sample at its own XZ (no interpolation between samples), so
  it moves onto a pillar top or down a step at once and never sits partway up a wall face; it lies
  15 mm above that surface (the `%Ground` node's own height). Its frame and alpha come from the
  flask's height above that surface; the alpha moves at most `ShadowAlphaPerSecond` (3 a second)
  so a step does not jump it, and it fades to 0 over the last 1.0 m of the ground track before the
  target (`ShadowGoneMetres` 0, `ShadowFadeMetres` 1.0). Without a sampler (the contact sheets) the
  shadow runs on the straight line between the two feet heights.
- Arrival: `Arrived` fires at `FlightSeconds` and the node frees itself in the same frame. The
  presenter awaits the known `FlightSeconds` (decided 2026-10-22), not the signal, because a signal
  await hangs if the node is freed early (scene teardown). The signal stays. The splash is not in
  this scene: the DamageDealt event that follows spawns it as today.
- Emitter list (keep in step with `FlaskThrow.cs`): `%Flask`, `%Trail`; plus `%Shadow`.
- Adapter test (r08 scene, `adapter_test.gd`): 4 tiles gives flight 0.43 s and apex 1.2 m; `Arrived`
  and leaving the tree both at the end of the flight; a throw toward -X gets anim speed -1.5 and
  turns counter-clockwise on screen. Turning `%Flask` along the throw turned the billboards edge-on
  for the -X throw, which is why the drop direction is turned on the material instead.
- Lifecycle (headless, `lifecycle_test.gd`): three throws 0.2 s apart, the second freed
  mid-flight: 2 arrivals, nothing left in the tree, no errors.
- Longest lifetime: `FlightSeconds`, 0.65 s at most. Drops still alive at arrival are freed with
  the node; they are 1-texel specks by then.
- Quality dial: `%Trail` can be hidden; the flask and the shadow carry the read.
- Spike: `scripts/dev/PrologueRunSpike.FlaskThrow.cs` (`WatchFlaskThrows()`,
  `StopWatchingFlaskThrows()`, `CheckFlaskThrows()`, called from `PrologueRunSpike.cs`). Rendered, it
  saves the first Encounter 3 throw at 0.5 and 0.95 of its flight (`flask_throw.png`,
  `flask_throw_late.png`) and the Encounter 4 throw at 0.5 (`flask_throw_e4.png`). At 0.25, 0.5 and
  0.75 of every flight it checks that the shadow sits above the drawn surface at its XZ by less
  than 2 cm and shows (alpha 0.1 or more) while the flask is over 0.3 m up outside the fade, and
  prints the tile, surface, alpha and screen position of each sample. The freed-on-time check subtracts the frame the node left in: a capture
  just before the arrival stretched that frame, and the first rendered run read 0.62 s of life for
  a 0.50 s flight. A third shot at 0.12 of the flight (one test run) showed the flask at the
  Player's hand and no shadow, so it was taken out.
- Prologue run (2026-10-22): E3 flights 0.50 s (Rat C) and 0.39 s, E4 0.60 s (the Tyrant); every
  throw leaves from the Friend's feet and ends on its target's axis (end gap 0.000), and the splash
  spawns 0.004 to 0.006 s after the arrival when no capture runs. Every shadow sample lies on open
  floor at height 0 (shadow 0.015): no Prologue flight passes over a pillar, a stub or a channel,
  so the step behaviour above is not exercised by the Prologue. Until the terrain pass the adapter
  also put the shadow level with the floor (it took `%Ground`'s height off again).

## Known limits

- In the sewer (`dev_shots/flask_throw.png`, `flask_throw_late.png`, the first E3 throw at Rat C)
  the flask reads at the game camera: a pale green bulb, a light neck and a brown cork against the
  dark stone, high over a pillar on screen at mid-flight and just above Rat C at 0.95. The pillar
  is only behind it in the picture: the shadow's ground point at 0.5 is on tile (5,4), under Rat
  A's sprite and the Player's shield, so the shadow is covered there; at 0.95 it has faded. In
  `flask_throw_e4.png` the shadow lies on the dark sludge band, where an alpha 0.4 black disc is a
  faint mark.
- The Friend has no throw pose, so the flask appears beside her shoulder at the hand height the
  presenter passes. At 0.12 of the E3 throw it passes the Player's outstretched hand.
- A shadow that runs onto a pillar overhangs the edge by up to half its width for a frame or two,
  because the whole disc moves with its centre's sample.
- The board's tile overlays (the team footprints, alpha-blended at render priority 0) draw over
  the shadow (priority -1) where they meet: a light team tint and the border line. Read from the
  materials; no shot shows the two together.
- The shadow fades over the last 1.0 m, so the last part of the fall has a weaker ground cue. With
  no fade the floor shadow behind the target shows as a black tuft on its head at 0.40 s (r09 test,
  `r09t_hg`). Render order cannot hide it: the tokens' `lit_sprite` is alpha-scissor in the opaque
  pass, the shadow is already below them (priority -1 against 1), and the tuft lies outside the
  target's outline. The fade was set for a one-tile target and not checked on the Sewer Tyrant.
- The shadow's darkness hardly changes with height (review 3): the size carries the height.
- At 24 m the drops are 1 to 2 px specks. The flask reads as a green flask with a cork, about 16 px
  across at 1080p.
- The tumble is 1.75 turns for every flight, so long throws turn slower. When the neck points down
  (135 to 225 degrees) the flask can read as a drumstick (review 3).
- The drops hang as a dotted line of specks at 24 m and never visibly arc (check 8, every review).
- The neutral stage overexposes the lit bulb (near DAEA82); the lit and game views keep the palette.

## Rounds

```
r01  changed: first build. Flask (1 particle, 8 tumble frames, 1.5 turns, lit, self glow 0.35),
              Trail (3 alive, 0.22 s, emitting from 10 to 50 percent of the flight), Shadow (Sprite3D,
              discs 8 to 3 texels, alpha 0.55 to 0.25), Light (A9BF58, 0.3, range 1.2)
     expected: a corked flask tumbling on an arc from the Friend's hand to the rat, drops behind it,
              a shadow under it
     sheet: r01c, r01g, r01l   score: 6/10   failed: 10, 13, 15
     cold read: a girl throws a small green ball in a flat arc and it lands on the rat; close up it is
              a corked flask turning over. Game view: a green dot with a hint of cork slides from her
              chest to the rat.
     notes: the shadow is a barely visible smudge on every view (10), so at 24 m the lob reads as a
              slide (15); the bulb blooms into a soft halo on the neutral stage (13); the light lights
              nothing visible in flight, and it stays at the end point after the flask dies and turns
              the rat green with a halo at 0.43 to 0.47 s (in the game the node is freed at arrival).

r02  changed: shadow discs 11 down to 5 texels, alpha 0.7 to 0.35; Light cut; self glow 0.35 -> 0.2
     expected: a shadow under the flask on every view; no green rat; no halo round the bulb
     sheet: r02c, r02g, r02l   score: 6.5/10   failed: 10, 15
     result: no green rat, smaller halo. The shadow reads near the ends of the flight and is lost
              near the apex at 24 m (6 texels, alpha 0.36).

r03  changed: shadow alpha 0.75 to 0.55, no disc under 7 texels
     expected: the shadow visible at every game tile, apex included
     sheet: r03c, r03g, r03l   score: 7/10   failed: 2 (borderline: a green ball with a cork fleck at 24 m)
     cold read: she throws a little green flask in an arc; its shadow runs along the floor to the
              rat; it lands on the rat.

r04  changed: drop frames a size up (2 x 3 bead, 2 x 2 drop, 1 x 3 streak)
     expected: drops of 3 to 5 px below and behind the flask in the game view
     sheet: r04c, r04g, r04l (recaptured; the first r04 capture showed the r03 drops, cause not found)
     result: no visible difference at 24 m; frame 0 sits behind the flask. Reverted to r03.

r05  changed: nothing in the effect (r03 state); new handoff views rNNhg and rNNhc
     sheet: r05c, r05g, r05l, r05hg, r05hc   score: 7/10
     cold read (handoff): she throws a green flask in an arc at the rat; it shatters on the rat in a
              white flash and acid splashes over it and the floor round it. The splash flash at
              0.483 s sits where the flask was at 0.433 s.

review 1 (after r05, opus, labels masked: A = r05, B = r02, close, zoom, game, lit, handoff)
     scores: A 7/10 (failed 8), B 6/10 (failed 8, 15). A and B differ only in the shadow.
     verdict: A, because its shadow reads on every game tile and tracks the ground under the flask;
              B's shadow drops out at the apex at 24 m.
     failed 8 on both: the drops hang where they are shed and sink slowly; a dotted trail in the air.
     top changes: (1) the stopper touching the bulb in every frame (the diagonal corks floated on
              one pale texel, the upside-down frame read as a tree or lollipop), a 9CADAF rim with
              E2E5A9 only inside; (2) a narrower darkness range on the shadow (about 30 against a
              floor of 45 at the apex, no darker than 27 at the ends), size from 100 to about 55
              percent, and a fade as it enters the target's tile.
     other defects: the shadow shows as a black tuft above the rat's head and back at 0.40 to
              0.417 s; the bulb renders near DAEA82 on the neutral stage, white running to the
              silhouette; tile 1 shows the flask tilted, 0.3 m above the rest-pose hand; the cork's
              dark half matches the warm floor on the lit sheet; drops are dust at 24 m.

r06  changed: 3-texel glass collar on the bulb and the cork on it (7-texel block on the diagonals),
              bulb rim C3D0CE -> 9CADAF; shadow 11 down to 6 texels at alpha 0.6 to 0.5, faded over
              the last 12 percent of the flight
     expected: one connected flask in all 8 frames; a smaller apex shadow; a lighter landing shadow;
              no tuft at 0.417 s
     sheet: r06c, r06g, r06l, r06hg, r06hc   score: 7.5/10   failed: 8
     result: the flask reads as a potion bottle in every frame (zoom). Apex shadow 28 on a floor of
              45, landing 27 (was 23), the 0.417 s patch is gone (35.7, the rat's own darkest
              level). The tuft still shows at 0.40 s in the handoff view.

r07  changed: shadow fade over the last 1.0 m of the ground track; drops inherit_velocity_ratio
              0.15 -> 0.5
     expected: no tuft at 0.40 s; drops arcing forward
     sheet: r07c, r07g, r07l, r07hg, r07hc   score: 7.5/10   failed: 8
     result: the tuft is a faint grey at 0.40 s (kept). The drops sit in the same places as r06:
              inherit_velocity_ratio has no visible effect here (replaced in r08).

r08  changed: shadow gone within 0.45 m of the target, full beyond 1.25 m; drops thrown forward and
              up at 1.5 to 3 m/s (direction (1, 0.35, 0), spread 25), no inherited velocity
     expected: no tuft at 0.40 s; drops that move forward and fall behind the flask
     sheet: r08c, r08g, r08l, r08hg, r08hc   score: 7.5/10   failed: 8 (borderline)
     result: no tuft at 0.40 s. The drops move 10 to 20 px further forward and up on the close
              sheet, but at 1 to 2 texels they still read as specks.

review 2 (after r08, opus, labels masked: A = r07, B = r08)
     scores: A 7/10 (failed 10: the shadow fades during the fall), B 6/10 (failed 8: the drops hang
              level; failed 10: the shadow is gone while the flask is still 0.84 m up).
     verdict: A. r08 is reverted (shadow fade back to the last 1.0 m, drops back to falling).
     top changes: a shadow from height alone, kept until the splash; a 2-texel glass neck (the
              diagonal and cork-down frames read as an apple with a stalk, or a tree); about 1.75
              turns so every tile shows a new frame (0.400 and 0.433 s showed the same frame).

r09  changed (on r07): 2 x 2 glass neck between bulb and cork; 1.75 turns; shadow with no end fade
              (test), then back to r07's fade over the last 1.0 m
     expected: bulb, neck and cork as three parts in every frame; a new frame on every tile; no tuft
     test: with no end fade the 0.40 s handoff tile shows a full black tuft on the rat's head
              (`r09t_hg`). Render order cannot hide it (see Known limits), so r09 keeps r07's fade.
     sheet: r09c, r09g, r09l, r09hg, r09hc   score: 7.5/10   failed: 8
     result: every tile a new frame; three parts in every frame; the neck shows at 24 m as a pale
              tick between bulb and cork.

review 3 (after r09, opus, labels masked: A = r09, B = r07)
     scores: A 7/10 (failed 8), B 6/10 (failed 8). A and B differ only inside the flask's box.
     verdict: A. r09 kept, the scene on disk is built from it.
     reasons: A advances one 45 degree frame every 1/30 s and the close, game and handoff sheets
              agree at each time; B repeats 135 degrees at 0.400 and 0.433 s. A keeps a pale neck
              in every frame (bulb centre to cork about 6.6 texels against 5.1).
     top changes: the shadow's alpha from height (about half as dark at the apex, darkest before
              landing); drops with part of the flask's velocity, stronger gravity and at least 2 x 2
              texels, or cut the layer.
     other defects: neck-down frames (135 to 225 degrees) read as a drumstick; on the lit sheet the
              bulb turns olive and the cork merges into the warm floor away from the torch; at
              0.033 s the flask is already at 45 degrees beside her face; the stage grid lines draw
              over the shadow (check the real tile overlay in Phase B). The reviewer reported "the
              flask light does nothing"; the scene has had no light since r02.
```
