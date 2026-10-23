# Treat Wounds heal: round log

Effect: the Friend treats the Player's wounds after Encounter 2 with the Medicine skill (a check,
2d8 HP, `TreatWoundsBeat`). The same scene plays on every `Healed` battle event. Since r11 it is
first aid, not light: a linen roll touches the chest, the strip goes round the body twice and is
knotted, a pinch of powder is dabbed on, a few plain sparkles rise, and the bandage fades. The
brief is `%TEMP%\vfx_studio\ungilded\treat_wounds\brief.md` (the r01 to r10 brief is
`brief_r10.md` beside it) and the sheets are in `%TEMP%\vfx_studio\ungilded\treat_wounds\rNN{c,g}\sheet.png`.

HD-2D pixel art (Octopath Traveler, Triangle Strategy): every layer is a code-drawn flipbook on
the locked palette, sampled nearest, never scaled per particle. The wraps are drawn on the unit
sprites' own pixel grids.

## Files

- `build_treat_wounds.gd` writes `res://scenes/fx/treat_wounds.tscn`. With
  `-- --low=1 --out=res://tools/vfx/treat_wounds/rat_test.tscn` it writes the rat check scene (the
  Low set shown). `rat_test.tscn` in this folder is a check scene only; the game never loads it.
- `draw_treat_frames.py` writes `res://assets/fx/treat_wounds/{wrap,wrap_low,sparkle}.png` and
  checks every pixel against the palette: F4F6DA cream, 8CF28C mint, E6DCC6 linen, BFAE90 linen
  shadow, and F4F6DA, E6DCC6, 8CF28C at alpha 128. Index 0 is transparent. An off-list colour fails
  the run. E6DCC6 and BFAE90 are the two linen tones added in r11.
- `res://assets/fx/treat_wounds/pixel_lit_flipbook.gdshader` (new in r13): a lit pixel flipbook,
  so the bandage takes the room's light like the unit under it. The sparkles still use the shared
  `res://assets/shaders/vfx/vfx_essential_pixel_mix.gdshader`, unchanged.
- Import: every PNG under `assets/fx/treat_wounds/` has `compress/mode=0`,
  `mipmaps/generate=false`, `detect_3d/compress_to=0`.
- The r01 to r10 textures (ring, column, column_low, motes, pulse) were removed from
  `assets/fx/treat_wounds/`; copies are in `$W/keep/r10_assets/` and the r10 scripts in `$W/keep/r10/`.

## Commands (same every round)

```
G=G:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64_console.exe
S=C:/Users/Midge/.claude/skills/vfx-studio
W=%TEMP%/vfx_studio/ungilded/treat_wounds
python tools/vfx/treat_wounds/draw_treat_frames.py --preview $W/frames
$G --path . --headless --import          # after every draw: a changed PNG reaches the build only through it
$G --path . --headless -s res://tools/vfx/treat_wounds/build_treat_wounds.gd --log-file $W/build.log
$G --path . --headless -s $S/scripts/audit_effect.gd --log-file $W/audit.log -- --scene=res://scenes/fx/treat_wounds.tscn --length=1.4 --particles=9 --lights=1
PROP="--prop=res://assets/sprites/heroes/player/rest_1.png --prop-px=0.028 --prop-feet=6"
# close view, neutral stage
$G --path . --fixed-fps 60 --position -4000,-4000 -s $S/scripts/capture_sheet.gd --log-file $W/cap_c.log -- --scene=res://scenes/fx/treat_wounds.tscn --out=$W/rNNc --label=rNNc --cam=2.6,1.9,2.6 --look=0,0.8,0 --fov=40 --span=1.6 --steps=12 $PROP
# game view, sewer look
$G --path . --fixed-fps 60 --position -4000,-4000 -s $S/scripts/capture_sheet.gd --log-file $W/cap_g.log -- --scene=res://scenes/fx/treat_wounds.tscn --out=$W/rNNg --label=rNNg --cam=10.9,18.4,10.9 --look=0,0.8,0 --fov=22 --tile=600 --cols=3 --span=1.6 --steps=9 --env=res://scenes/looks/sewer.tscn $PROP
```

```
# rat check: the Low set on the rat stand-in (r06 to r10 used --fx-scale=0.94)
$G --path . --headless -s res://tools/vfx/treat_wounds/build_treat_wounds.gd --log-file $W/build_rat.log -- --low=1 --out=res://tools/vfx/treat_wounds/rat_test.tscn
RAT="--prop=res://assets/sprites/enemies/rat_v1/idle_1.png --prop-px=0.028 --prop-feet=2"
# the same two capture commands with --scene=res://tools/vfx/treat_wounds/rat_test.tscn, $RAT and labels rat_rNNc, rat_rNNg
# dark room check (from r12): $W/tools/capture_sheet_lit.gd, the close command plus --env=res://scenes/looks/sewer.tscn --floor=stone --sun=0.15, label lit_rNNc
```

`$W/round.sh rNN [rat]` runs the draw, import, build, audit and the close, game and rat captures.
The stand-in target is the player's rest frame at 0.028 m per pixel (1.65 m tall, feet on row 65
of 72). Close tiles fall at 0, 0.145, 0.29, 0.436 ... 1.6 s; game tiles every 0.2 s.

## Tool notes

- `capture_sheet_lit.gd` in the work folder is a copy of the skill's `capture_sheet.gd` with two
  options added: `--floor=stone` (a lit matte floor, albedo 0.32/0.30/0.28, in place of the
  unshaded grid) and `--sun=<energy>`. The skill's grid floor is unshaded, so no effect light ever
  shows on a sheet. The shared script is unchanged.
- A changed PNG reaches a headless build only through an import pass (`--headless --import`);
  `round.sh` imports after every draw. The first r02 capture showed the r01 frames for this reason.
- The neutral stage's sun lights everything, so lit and unshaded materials look the same there.
  The dark room sheet (`lit_rNNc`) is the only view where the r13 lit shader and the light show.

## Known limits

- Captured on the grey grid stage and on a flat dim floor only, never in the real sewer level.
  The in-game shot is still owed.
- The wrap is drawn for two sprites only: the player's `rest_1.png` (Tall) and `rat_v1/idle_1.png`
  (Low). Its columns are those sprites' columns, so on the Friend, the other heroes or any other
  enemy the band can miss the torso or cross an arm. Each new body shape needs its own wrap rows.
- The wrap follows the sprite only while the unit holds still. The rest frame is static; an idle
  that bobs or breathes would slide under the bandage.
- The unit's facing: the wraps are drawn for the sprite as it is in the file. A mirrored sprite
  (FlipH) needs the wrap flipped too; the scene does not know the facing.
- The bandage vanishes after 1.35 s while the sprite never shows it, as Astra warned. The fade is an
  even 0.3 s alpha fade so it does not read as a glitch, but the treatment leaves no trace.
- The light sits above the unit's head, not at the medic's side: the scene does not know where the
  medic stands.
- Sparkles: four (Tall) and two (Low), kept against Astra's advice because the user's direction
  asks for them; they are the effect's one remaining non-medical cue.
- The audit's "no color_ramp" warnings on the sparkles and the shared priorities of the Tall and
  Low emitters are expected: the sparkles' fades are drawn into their frames, and the two sets are
  never visible together.

## Hook (TreatWounds : OneShotFx, integrated 2026-10-22)

- Scene `res://scenes/fx/treat_wounds.tscn`, root `Node3D` named TreatWounds, with
  `res://scripts/fx/TreatWounds.cs` attached by this build script (`SCRIPT`, attached when the file
  exists, as the acid splash build does). Spawn the root at the unit's feet (y = 0), at the unit's
  sprite position.
- Unique names (every node the game touches):
  - `%Ground`: empty since r11 (nothing touches the floor). Kept for the contract.
  - `%Body`: holds the two sets. `TreatWounds.cs` scales it by `BodyPixelSize / FramePixelSize`
    (the sprite's pixel size over 0.028; 0.714 for the prologue's player and rat, PixelSize 0.02).
    This puts each wrap texel on a sprite texel. `FxScale` is unused. `%Body` does not move.
  - `%Tall`: `%Wrap`, `%Sparkles` (heroes).
  - `%Low`: `%WrapLow`, `%SparklesLow` (the rat). Ships hidden.
  - `%Light` (OmniLight3D, lantern FFB86B, 1.9 m up, range 1.1 m) and `%Anim` (AnimationPlayer,
    animation `play`, 0.9 s: `Light:light_energy` 0, 0.3 at 0.1 s, 0.3 at 0.6 s, 0 at 0.9 s).
- The presenter (`GodotPresenter3D.SpawnTreatWounds`) spawns it for every `Healed` event, in place of
  the old heal motes (removed), under the combat scene's popup layer at the healed unit's feet. The
  HP bar update and the heal number are as before. Before `AddChild` it sets `BodyPixelSize` from
  `UnitVisual3D.SpritePixelSize`, `UseLowSet` when the unit's HP bar is under 0.85 m (the bar is
  read because a Mana Seed hero reports no body height; the rat's bar is 0.53 m, and the Player
  took the tall set in the prologue run), and `HealerDirection`, the flat direction from the healed unit to the healer (zero when
  the unit heals itself or the healer is unknown).
- The set is chosen by that height cut, not by the sprite as the first draft of this hook asked.
- `Build` hides the unused set, restarts the visible set's two emitters, moves `%Light`
  `LightTowardHealer` (0.6 m) toward the healer at its own height, plays `%Anim` and holds the tween
  for `Lifetime` (1.4 s), after which the base class frees the node. Every delay is drawn into the
  frames, so all start on the same frame.
- `CombatScene.StartEncounter` loads this scene as the board builds
  (`FxLibrary.PreloadEncounterEffects`). The Encounter 2 heal's frame ran 27 ms before the spawn and
  35 ms at most after it in the rendered prologue run.
- In game (rendered prologue run, after Encounter 2): the wrap's texels sit on the Player's pixel
  grid. The band renders pink-lavender, not linen: the Player wears the spectacles from Scene 3b on,
  their violet glow sits about 0.3 m above the band, and the glow's light skips only the sprite
  layer, so it lights the wrap. The lantern light makes no measurable change (hair +3.6 levels in
  red, chest and shoulders 0 to 2): at 0.3 energy it is faint, and 0.6 m to the side the chest sits
  1.10 m from it, at the edge of the 1.1 m range. The hair does not turn orange.
- Open decision: put the wraps on the sprite render layer (or give the spectacles glow a cull mask
  that skips them) so the linen keeps its colour; and lengthen the light's range or shorten
  `LightTowardHealer` so the side light reaches the chest.
- Longest lifetime: the wrap, 1.36 s (sparkles 1.0 s, spawned over the first 0.3 s). `Lifetime =
  1.4` frees it safely.
- Timing for sound: the roll touches the chest at 0.08 s, the strip is taut at 0.48 s (a cloth
  pull), the knot is tied at 0.56 to 0.64 s.
- Quality dial: the low setting can drop `%Light`, `%Anim` and the sparkles; the wrap carries the read.
- Lifecycle (headless, `$W/tools/lifecycle_test.gd`): three plays 0.2 s apart, one replay mid-play,
  one free mid-play: no errors, nothing emitting after 1.5 s, light energy 0.

## Rounds

```
r01  changed: first build. Ring (flat, mix, 12 frames), Column (add, 16 frames, depth_pull 0.4),
              Motes (5, add), Sparkles (16, mix, 3 colour rows), Pulse (add, emission 3, chest),
              mint light on Anim
     expected: every layer on the sheet; ring by 0.15 s, column at the head by 0.6 s, pulse at 0.4 s
     sheet: r01c, r01g   score: 6/10   failed: 5, 13, 12 (weak), 8 (weak)
     cold read close: a green ring forms at a swordsman's feet, a green beam climbs through him, a
              white cross flashes on his chest, motes and sparkles, the beam leaves upward as a thin
              line over his head, the ring breaks into dashes; empty by 1.3 s.
     cold read game: the same event; at 0.4 s a large soft white halo covers his upper body.
     notes: the pulse's long cream rays at emission 3 bloom into a disc at 24 m (5, 13); the cream
              outer ring at 0.29 s reads as a white shockwave; sparkles stay low and half are hidden
              behind the sprite; the detached beam at 1.02 s reads as a stick above the head.

r02  changed: Pulse emission 3.0 -> 1.6 and its rays 11 -> 4 texels; outer ring drawn mint, not cream;
              Sparkles depth_pull 0.3, velocity 0.5..1.0 -> 0.8..1.4
     expected: no white halo over the chest at game 0.4 s; no white ring at close 0.29 s; more
              sparkles visible over the figure
     sheet: r02c, r02g   score: 6.5/10   failed: 12, 15 (weak)
     result: as expected. The first capture of r02 showed the old frames: a changed PNG reaches the
              build only through an import pass, so round.sh now imports after every draw.
              Still open: the detached beam stick at 1.02 s; sparkles are specks at 24 m.

r03  changed: column settle frames break into dashes, top held at row 4; column sides solid half-alpha
              bands instead of a 50% checker; big sparkle arms 3 -> 4 (cell 9 -> 11)
     expected: no stick above the head at 1.02 s; cleaner column sides; sparkles visible at 24 m
     sheet: r03c, r03g   score: 6.5/10   failed: 8 (weak), 15 (weak)
     result: sides cleaner, stick gone, but the dashed beam at 0.87 s reads as a ladder of bars over
              the head. The full column at 0.58 to 0.73 s is a flat green slab over the face, a
              lightsaber at 24 m: nothing shows the light rising.

r04  changed: column bright only within 10 rows of the rising front, mid band dimmer, trail dimmest;
              settle frames are six thin strands climbing 11 rows a frame; sparkles spawn up to
              0.75 m and rise at 1.0..1.6 m/s
     expected: the light reads as climbing (bright head, dim trail); no bars at 0.87 s; sparkles at
              head height
     sheet: r04c, r04g   score: 7/10   failed: 5 (weak), 12 (weak)
     result: as expected. The motes bloom into white orbs at the chest 0.58 to 1.16 s; the floor glow
              shows as a checker net between the feet; one strand stands above the head at 1.02 s.

r05  changed: Motes emission 1.6 -> 1.15 and no cream cores; floor glow 50% checker -> sparse dots
              (12% and 6%); strands 3 texels long in the last three frames and clipped at the head
     expected: no white orbs; no net between the feet; nothing above the head at 1.02 s
     sheet: r05c, r05g   score: 7/10   failed: 8 (weak), 15 (weak)
     result: as expected.

rat check after r05 (rat_r05c, rat_r05g; Body 0.66, rat stand-in 0.028 m/px)
     result: the column stands about 0.5 m above the 0.73 m rat at 0.58 to 0.73 s, a tower over it.
              Ring and sparkles fit the rat. The 0.66 scale was also wrong for this stand-in: see
              "Game scale" below.

light check after r05 (lit_r05g; capture copy with a lit stone floor, sun 0.15, sewer look)
     result: the light shows as a soft mint pool around the feet from 0.2 s, strongest at 0.4 to
              0.6 s, gone by 1.0 s.

review 1 (after r05, on r05 = A and r04 = B, labels masked, opus)
     cold read A: a green ring lights under a swordsman and a pale green beam climbs through him to
              above his head; white and gold crosses drift up; the ring breaks into dashes, the beam
              collapses to a hairline; clean by 1.16 s.
     cold read B: the same, but the beam's lower half is a dithered checker at the feet, and a short
              green bar floats above the head at 1.02 s.
     scores: A 4.5/10, B 5/10, both failed 1, 6, 9, 12, 14 (gate 1 caps both at 5).
     verdict: B (r04) by a small margin: its dithered column base fits the settle phase. r05 loses, so
              its floor-glow change is reverted in r06. Its strand and mote changes stay, because the
              reviewer also asked for the floating bar to go and read the motes as orbs in both.
     top changes: (1) column at the head by 0.40 to 0.45 s and no taller after, then lift off and thin
              until about 1.3 s; (2) smaller sparkles, mostly cream or gold, no dark rim over the column.
     defects: column tip reads as a blade above the head; a white block at the column foot reads as a
              lamp; strands read as render seams; motes read as orbs; no distinct chest pulse; the
              column turns the tunic teal and covers half the face at 0.58 to 0.73 s.

r06  changed: column re-keyed to 20 frames over 1.35 s: at the head by 0.41 s, holds, lifts off the
              floor from 0.68 s and thins with dither to specks at the head by 1.35 s; round ends at
              the head, mint foot glow, no strands. Sparkles drawn before the column (priority 0) with
              half-dark rims, rows cream and gold with their own twinkle orders. Floor glow restored to
              r04 (review 1). New: Body/Tall and Body/Low sets, column_low.png 32x48 for small units.
     expected: peak at close 0.44 s and game 0.4 s; dissipation 0.7 to 1.3 s; no dark crosses on the
              column; the rat's column no taller than the rat
     sheet: r06c, r06g, rat_r06c, rat_r06g   score: 7/10   failed: 12 (a green square at t = 0)
     result: as expected. Gate 1 passes. The rat's sparkles and motes rise to about 1 m and float
              above it.

r07  changed: column frame 0 empty; column emission 1.5 -> 1.3; the Low set gets its own sparkles
              (10) and motes (3), born below 0.45 m and rising less
     expected: nothing but the faint ring at t = 0; smaller bloom cloud at game 0.4 s; the rat's
              sparkles stay on its body
     sheet: r07c, r07g, rat_r07c, rat_r07g   score: 7/10   failed: 6 (motes are identical orbs)
     result: as expected. The motes still read as gold orbs on the chest and on the rat's back.

r08  changed: motes redrawn as 5x5 blinking light squares (pixel, 2x2, 3x3 plus), 10 (Low 6);
              pulse redrawn as a flat 48x48 hoop at chest height, spreading outward, no depth_pull
     expected: no orbs; a hoop of light around the body at the peak, distinct from the column
     sheet: r08c, r08g, rat_r08c, rat_r08g   score: 7.5/10   failed: none clear; criterion 4 weak
     result: as expected. The hoop reads well in the game view and on the rat; the close camera sees
              it nearly edge-on. The column still covers the left half of the face at 0.44 to 0.73 s.

r09  changed: column side bands narrower (half-width 1 + 3.5 s, haze 1 + 5 s); the settle dissolve
              uses fixed hashed 1x2 specks instead of the Bayer checker
     expected: more of the face and torso visible at 0.44 to 0.73 s; the leaving column breaks into
              specks instead of a checker net
     sheet: r09c, r09g, rat_r09c, rat_r09g   score: 7.5/10   failed: none clear
     result: as expected.

lit check after r09 (lit_r09c; close camera, lit stone floor, sewer look)
     result: the mint light pool spreads about 2 m around the feet at 0.15 to 0.73 s; the ring and
              sparkle rims read on lit stone. Under the sewer exposure the column blooms much brighter
              than on the neutral stage and washes out the middle of the figure at 0.29 to 0.73 s.

review 2 (after r09, on r08 = A and r09 = B, labels masked, opus)
     cold read A: a green ring lights on the floor; a pale green pillar climbs to the top of the head
              by 0.44 s with white and gold sparkles and a thin white hoop at the chest; the pillar
              lifts off and breaks into a checker of specks at the head; empty by 1.45 s.
     cold read B: the same, except the pillar settles by thinning into narrow vertical strands.
              Both match the goal; a ring plus a body-high pillar is also the language of a teleport,
              and the colour and the slow settle keep it reading as a heal.
     scores: A 7.5/10, B 8/10, no failed checks on either; both fail success criterion 6 (on the rat
              the column top reaches the tail tip, half a rat height above its back: a post on the rat).
     verdict: B (r09): its settle keeps a column shape and leaves the face clear; A lays a
              screen-door checker over the hair. r09 kept.
     top changes: (1) the rat's column top at its back, the hoop on the back; (2) the floor glow is a
              regular grid of texels that reads as a drain grate: make it irregular.
     defects: the edge-on hoop reads as a white "smile" line in the close view; bloom smear where the
              column head crosses the sword at 0.15 s; one late large star at 1.16 s; one strand above
              the hair at 1.16 s.

r10  changed: column tops lowered to the hair under the beam (hero row 9) and the rat's back (Low:
              LOW_K 18 / 56, top on row 27); ring floor glow drawn with fixed hashed noise instead of
              the Bayer grid; sparkle row 2 twinkles big earlier and ends small, spawn window
              0.54 -> 0.45 s
     expected: the rat's light wraps its body instead of standing on it; no grate pattern; no late
              large star
     sheet: r10c, r10g, rat_r10c, rat_r10g   score: 8/10   failed: none
     result: as expected. A few specks stay at the left of the hair at 1.16 s.

review 3 (after r10, on r10 = A and r09 = B, labels masked, opus, with rat close and game sheets)
     cold read A: a green ring lights up on the floor and a pale bar climbs through the swordsman to
              his head; white and gold four-point stars twinkle over his chest, then the ring breaks
              into chips and the bar thins away at his head; clean by 1.45 s. On the rat the bar stays
              within the body. Matches the goal.
     cold read B: the same on the hero, with a dotted lattice inside the ring; on the rat the bar
              shoots above its back and its last bits float in the air like a green wisp.
     scores: A 8/10, no failed checks; success criteria 1, 2, 4, 5, 6 pass, 3 fails on the pulse hoop
              only. B 7/10, failed 11; criteria 3 and 6 fail.
     verdict: A (r10). The hero sheets differ only in the ring fill and the sparkles; the rat sheets
              decide it. r10 is the delivered round.
     top changes (not made, listed as open): (1) for small units the floor ring outshines the short
              column at game 0.2 to 0.6 s, so the rat looks like it sits in a dish or a ward: shrink or
              dim the ring for the Low set; (2) at 0.44 to 0.58 s a line of single mint texels runs
              beside the column with a one-texel gap (the 25% haze), read as a dotted outline: close
              the gap or dither the edge into the body.
     defects: the hoop is a 1 px arc thinner than a sprite texel in the close view (edge-on) and reads
              as a halo or crown on the rat with bloom; the column is centred on the feet while the
              hero's head sits right of that, so the last specks at 1.16 to 1.31 s look like green
              hair; the rat's column stub at 0.15 s looks like a green can; the ring fill looks like
              grass or rune strokes; the mint column turns the blue tunic teal (a fourth hue on screen).

Stopped after r10: the independent score reached 8.
```

## Redesign from r11 (user feedback on r10)

The user, in their words: "The green column thing in the heal effect is weird for something that
simulates a medic patching you up with tools." Treat Wounds is the Medicine skill: bandages, salve,
a steady hand, by lantern light, no magic. From r11 the light column, the floor ring, the hoop, the
motes and the mint light pool are gone. The new brief is `$W/brief.md`; the r01 to r10 brief is
`$W/brief_r10.md`. The cold read to reach: someone patched up the swordsman's wound.

## Astra review 1 (gpt-6-astra, read-only, before drawing r11)

Asked how pixel-art games show a mundane first-aid heal at this pixel size, with the r10 sheets,
the sprites and the user's sentence. The reply, condensed only where it repeated itself:

1. The strongest medicine cue is a visible tool followed by contact with the wound. Stardew Valley
   shows the item above the head before the eating animation; Darkest Dungeon's Arbalest has
   Battlefield Bandage (Astra marked its recollection of the pose as a guess and could not verify
   torso-wrapping animations in the HD-2D games). For these sprites: a small linen roll entering
   from the medic's side, its free end touching the chest, then cloth pulled taut; a hand pressing
   a dressing would help. Strips winding themselves round an idle character can still suggest magic.
   In r10 the floor ring and the column across the face dominate and neither conveys treatment.
2. Wrap, as starting values: two turns of one continuous strip, 3 texels thick, 12 to 16 texels
   across the exposed tunic. Six application frames at 80 ms (contact, frontward pull, side turn,
   hidden passage, second overlap, tightening), two settling frames at 80 ms, hold to about 1.05 s,
   fade by 1.4 s. At the silhouette narrow the strip from 3 to 2 texels and let its moving tip
   vanish behind the torso, reappearing at the other edge a frame later; keep the finished front
   section still. Do not draw a full ellipse round the character. Three tones: cream base, muted
   warm shadow, pale highlight; a short highlight on the upper edge, a 1-texel shadow under overlaps
   and toward the sides, no continuous white edge, selective dark seams rather than a full outline.
   Knot: a compact 3x3 or 4x3 cluster off centre, unequal short tails, no loops, one tail tucked.
   Fade the still wrap evenly over 0.25 to 0.35 s; no random pixel deletion, blinking or upward
   disintegration.
3. What still says "spell": four to six rising four-point sparkles (prefer none; at most one brief
   still glint on a tool); luminous white cores, green or cyan emission, bloom halos, concentric
   rings, mirrored movement, constant-speed orbits, a synchronised brightness climax. Start with no
   added light; lantern light should come from the medic's side and stay steady. Salve: a 3 to 5
   texel powder cluster with two or three falling flecks, gone within about 0.2 s; ointment is a dab
   or smear, an expanding puff reads as powder.
4. Rat: one wrap round the ribcage behind the forelegs, across the long body axis, arching over the
   back and down the near flank, the far part hidden; 2 to 3 texels thick, a small overlap, a tucked
   end, clear of legs, muzzle and tail; fewer flecks and no rising sparkles.

Adopted: the roll as the tool and the contact frame; one strip, two turns, 3 texels, 13 texels
across; the 80 ms frame plan and the even fade; narrowing at the silhouette and no rear ellipse;
three linen tones without an outline; the knot shape; the 3 to 5 texel powder with three flecks;
the rat's ribcage wrap with fewer flecks.

Not adopted as given: the user's direction asks for four to six small late sparkles and a faint
lantern light, which Astra advises against. The sparkles stay, four of them, plain cream, no bloom
(emission 1.0), drawn as a separate emitter so a later round can test the effect without them in
the blind A/B. The light stays faint (0.35, lantern colour FFB86B from `hand_lantern.tscn`), on the
unit's axis because the medic's side is not known to the scene. No hand is drawn.

## Rounds from r11

```
r11  changed: rewrite. Removed the column, floor ring, hoop, motes and mint light. New: Wrap (one
              17-frame flipbook on the hero sprite's grid, 80 ms frames: roll on the chest, pulled
              across, behind the far shoulder, second pass, taut, knot; the salve puff at 0.24 s with
              three falling specks; held, even alpha fade 1.05 to 1.35 s), Sparkles (4 cream, frames
              0 to 5 empty, rising 0.15 to 0.3 m/s), Light (lantern FFB86B, 0.35); rat WrapLow
              round the ribcage, SparklesLow 3. Palette: linen E6DCC6 and BFAE90 added.
     expected: the cold read says bandage; band across the chest by 0.44 s; out by 1.4 s
     sheet: r11c, r11g, rat_r11c, rat_r11g   score: 6/10   failed: 2 (game view: a white patch)
     cold read close: a roll of cloth touches the swordsman's chest, a cream band is wound across his
              chest and knotted, a little powder puffs, three small sparkles rise, the band fades.
     cold read game: a small white bar appears on his chest and goes away; reads as "something on
              his chest", not clearly a bandage.
     notes: the two passes merge into one flat plate (no seam, no slant); the roll is a 4x5 blob that
              reads as a light; the powder is lost against the cream band.

r12  changed: passes slant two rows over the body (a spiral) and the first pass's shadow row is the
              seam between them; roll 5x6 with a lit top; knot tails longer (one over the belt);
              powder moved onto the blue tunic above the band, larger (6 texels, then an 11-texel cloud)
     expected: two separate turns of cloth read at 24 m; the roll reads as an object; powder visible
     sheet: r12c, r12g, rat_r12c, rat_r12g   score: 6.5/10   failed: none clear; criterion 1 weak in
              the game view
     result: as expected close up; at 24 m the band now shows a seam and a slant.
     dark room check (lit_r12c): the unshaded linen glows white against the dark tunic, the only
              bright shape in the room: it reads as a light, not cloth.

r13  changed: the wrap uses a new lit pixel flipbook shader (`pixel_lit_flipbook.gdshader`), so the
              linen takes the room's light like the unit; rat second pass moved one column back with
              a seam
     expected: in the dark room the bandage is as dark as the unit around it, no glow; neutral
              stage unchanged
     sheet: r13c, r13g, rat_r13c, rat_r13g, lit_r13c   score: 7/10   failed: none clear
     result: as expected. The first build had `flat varying` (Godot needs `varying flat`), which
              failed to compile; that build's sheets were thrown away and r13 recaptured.

r14  changed: frame 0 is the roll arriving from the medic's side, outside the body, before it
              touches (17 frames, application one frame later); rat roll comes down to the back; light
              moved to chest height (1.0 m, range 0.9)
     expected: the first tile shows a tool coming in, not cloth already on the body; the light lifts
              the chest and not the floor
     sheet: r14c, r14g, rat_r14c, rat_r14g, lit_r14c   score: 6/10   failed: 13
     result: the roll arrival reads. The light at chest height sits almost on the lit billboards and
              makes a hot orange disc on the chest at 0.15 to 0.58 s, the largest smooth shape on the
              sheets. Light change reverted in r15; roll arrival kept.

r15  changed: light moved above the head (1.9 m, range 1.1), energy 0.35 -> 0.3
     expected: no hot spot; a faint warm lift on the head and shoulders; no floor pool
     sheet: r15c, r15g, rat_r15c, rat_r15g, lit_r15c   score: 7/10   failed: none clear
     result: as expected. The two late sparkles at 0.87 to 1.02 s are now the brightest shapes in the
              dark room.

r16  changed: sparkle emission 1.0 -> 0.8 and rise 0.15..0.3 -> 0.1..0.2 m/s; SparklesLow 3 -> 2,
              born lower on the rat's back
     expected: the sparkles no brighter than the lit linen in the dark room; they stay near the
              chest; the rat's sparkles sit on its back
     sheet: r16c, r16g, rat_r16c, rat_r16g, lit_r16c   score: 7/10   failed: none
     result: as expected for the hero. The rat's two sparkles are hard to find on its back.

review 4 (after r16, on r12 = A and r16 = B, labels masked, opus; close, game, rat close, dark room)
     cold read A: a white pad appears on the swordsman's chest and becomes a cloth strip, wraps twice,
              is tied off with two hanging tails, two small twinkles sit on it, it fades. In the dark
              room the strip is pure white and a warm pool spreads round his feet: that pushes it
              toward a heal spell.
     cold read B: a white roll touches his side at the shield arm and crosses the chest, unspooling a
              strip; a powder puff on the upper chest; the strip settles into a tied band with tails,
              two twinkles, it fades. In the dark room the band is shaded like his clothes and warm
              light falls on his face and hair. First aid on every sheet; the twinkles are the only
              spell-like part, and they are small.
     scores: A 5/10, failed 13 (dark room: roll and band clip to white), criteria 2, 3, 7 fail.
              B 7/10, no failed checks, all seven criteria pass.
     verdict: B (r16). The light decides it: A lights the floor round the feet and its band clips to
              white, which repeats the floor glow the user rejected.
     top changes: (1) the lantern light turns the hair orange and leaves the band grey: light the
              chest from in front; (2) the powder at 0.44 s is a dithered cloud over the collar that
              hides the finished band: a 3 to 4 texel puff at the band's top edge with two specks.
     defects: rat tile 1 roll floats four texels above the back (a pill); hero tile 1 roll reads as a
              white ball; the 1.31 s fade tile shows a translucent rectangle; on the band the cream
              sparkle centre vanishes and leaves a ring of four mint dots; sparkles hover; the rat's
              sparkles are lost cream on cream; the rat's knot pokes above the back line.

r17  changed: powder a 4-texel pinch at the band's top edge with two specks; sparkles born above the
              band (hero 1.10 m, rat 0.53 m); rat roll frame 0 touching the back
     expected: a clean band at 0.44 s; sparkles visible, not lost on the linen; the rat's roll on its body
     sheet: r17c, r17g, rat_r17c, rat_r17g, lit_r17c   score: 6/10 (review 5)   failed: 7 (as briefed)
     result: as expected, but lost the blind A/B (review 5) and is reverted. r16 is the delivered round.

review 5 (after r17, on r17 = A and r16 = B, labels masked, opus; same four views)
     cold read A: a white roll appears at the swordsman's chest and unrolls into a striped cream band
              with a strap hanging toward the belt; two white-and-mint twinkles hover by his collar and
              chin; the band goes translucent and is gone by 1.45 s. First aid; the twinkles beside
              the face are the one spell-like part.
     cold read B: the same roll, band, strap and fade, plus a small checkered powder puff at the collar
              at 0.44 s, and the twinkles sit on the band. Reads as first aid a little more firmly: the
              twinkles look like glints on fresh linen.
     scores: A 6/10, B 7/10; both fail only check 7, which the brief asks for (an even fade). All seven
              criteria pass on both; the lit colours match the palette one to one.
     verdict: B (r16). Band, roll, light and timing are pixel-identical; sparkle placement decides it.
     top changes (open): (1) dark room 0.87 to 1.02 s: the sparkles are the brightest thing on screen
              while the lit band is dim: light the sparkles like the band, or drop the mint; (2) tile 1:
              the roll is a flat cream disc (and on the rat it floats): a roll end with a shadow spiral
              and a short loose tail, touching the body.
     defects: the lantern turns the hair and face orange and barely lifts the chest; the 1.31 s fade
              reads as a pane of glass (remove the strips one at a time instead); the half-wrapped band
              at 0.44 s is a lumpy white mass; the knot reads as a strap hanging over the belt buckle;
              B's powder puff reads as dither; the game sheets look like the neutral stage (the sewer
              look supplies glow, tonemap and fog, not the floor, and its fog is faint at 24 m).

Stopped after r17 (seven of the eight redesign rounds). Delivered: r16, rebuilt from the r16 scripts.
```

## Game scale

The prologue's authored heroes and rats use `PixelSize = 0.02`, not 0.028. In game the hero is
59 px x 0.02 = 1.18 m (HP bar 1.23 m, FxScale max(0.66, 1.23 / 1.75) = 0.703) and the rat
26 px x 0.02 = 0.52 m (FxScale 0.66, the floor). The sheets use the stand-ins at 0.028 m/px with
the effect at scale 1, which is the game's hero picture enlarged 1.4 times (0.703 x 1.4 = 0.98).
The matching rat check is the rat stand-in at 0.028 m/px with the effect at 0.66 / 0.703 = 0.94.
At that scale one column for every unit is 2.2 times the rat's height.
