# Acid splash: round log

Effect: a thrown Lesser Acid Flask shatters on the target and green acid splashes over it and
onto the squares beside it (PF2e: direct damage on the target, splash on every creature within
5 ft). The brief is `%TEMP%\vfx_studio\ungilded\acid_splash\brief.md` and the sheets are in
`%TEMP%\vfx_studio\ungilded\acid_splash\rNN{c,g}\sheet.png`.

Direction since r02: HD-2D pixel art (Octopath Traveler, Triangle Strategy). Every layer is a
code-drawn flipbook on the locked palette, sampled nearest, one texel = 0.028 m at FxScale 1.
Round 1 (smooth particles) is superseded.

## Files

- `build_acid_splash.gd` writes `res://scenes/fx/acid_splash.tscn`.
- `draw_acid_frames.py` writes `res://assets/fx/acid_splash/*.png` and checks every pixel
  against the palette (425A26 779539 A9BF58 E2E5A9 EEE5D2, index 0 transparent, one
  half-alpha entry: 425A26 at alpha 128). An off-list colour fails the run. The vapour colours
  (7C8B5D and its half-alpha) went with the vapour layer in r16. Since r24 it also writes
  `splat_n.png` and `puddles_n.png`, normal pages with the same cells, through the project's
  `tools/art/sprite_normals.py` (its import settings and checks); they are not palette art.
- `splat_frames.py` (since r22) draws the 18 body splat frames; `draw_acid_frames.py` calls it.
- Shaders: `res://assets/shaders/vfx/vfx_essential_pixel_{mix,add,premul,lit}.gdshader`, copies
  of the skill's assets. The lit one carries the splat and the puddles.
- Import: every PNG under `assets/fx/acid_splash/` has `compress/mode=0`,
  `mipmaps/generate=false`, `detect_3d/compress_to=0`.

## Commands (same every round)

```
G=G:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64_console.exe
S=C:/Users/Midge/.claude/skills/vfx-studio
python tools/vfx/acid_splash/draw_acid_frames.py --preview <work>/frames
$G --path . --headless --import
$G --path . --headless -s res://tools/vfx/acid_splash/build_acid_splash.gd --log-file <work>/build.log
$G --path . --headless -s $S/scripts/audit_effect.gd --log-file <work>/audit.log -- --scene=res://scenes/fx/acid_splash.tscn --length=1.45 --particles=100 --lights=1
PROP="--prop=res://assets/sprites/heroes/player/rest_1.png --prop-px=0.028 --prop-feet=6"
# close view, neutral stage
$G --path . --fixed-fps 60 --position -4000,-4000 -s $S/scripts/capture_sheet.gd --log-file <work>/cap_c.log -- --scene=res://scenes/fx/acid_splash.tscn --out=<work>/rNNc --label=rNNc --cam=2.4,1.7,2.4 --look=0,0.6,0 --fov=40 --times=0.033,0.067,0.117,0.15,0.217,0.3,0.4,0.5,0.65,0.85,1.1,1.4 --warmup=1.4 $PROP
# game view, sewer look
$G --path . --fixed-fps 60 --position -4000,-4000 -s $S/scripts/capture_sheet.gd --log-file <work>/cap_g.log -- --scene=res://scenes/fx/acid_splash.tscn --out=<work>/rNNg --label=rNNg --cam=10.9,18.4,10.9 --look=0,0.5,0 --fov=22 --tile=600 --cols=3 --times=0.033,0.083,0.15,0.25,0.4,0.6,0.85,1.1,1.4 --warmup=1.4 --env=res://scenes/looks/sewer.tscn $PROP
```

From r16 both capture commands also pass `--strip-script=1`: `scripts/fx/AcidSplash.cs` now exists,
the build attaches it, and as a OneShotFx it would free the scene after `Lifetime` mid-capture.
Camera, times and look are unchanged.

The stand-in target is the player's rest frame at 0.028 m per pixel (1.65 m, the FxScale 1
creature). Times are the timing table's key moments; even spacing (tiles at 0 and 0.127 s)
missed the 0.1 s flash. With `--warmup=1.4` the capture restarts a finished one-shot, and
explosive emitters then show from the frame after the restart, so the first tile is at 0.033 s.

## Tool fixes made for this effect (skill and project)

- Near-black sheets in r01: the project sets `rendering/viewport/hdr_2d=true`, so the root
  viewport holds linear values and `get_image()` saved them unconverted (background 0.11 sRGB
  read back as 3/255). `capture_sheet.gd` now sets `root.use_hdr_2d = false`, plus
  `content_scale_mode` disabled and aspect ignore so the labels render at full size.
- `capture_sheet.gd`: `--prop`, `--prop-px`, `--prop-feet` place a lit billboard stand-in target.
- `audit_effect.gd`: flat quads (orientation other than FACE_Z) no longer warn about not facing
  the camera; the overdraw index multiplies by the quad side in metres.
- `vfx_essential.gdshaderinc`: `VFX_FILTER` macro on the shape textures (diffuse 1 and 2, mask,
  dissolve, dissolve mask) with a `sample_shape` twin of `sample_slot` (Godot rejects one sampler
  parameter fed by different filters); `flipbook_mode` Random row (each particle keeps one row
  of variants and plays its columns over life); `pixel_dither` (alpha below 1 drops whole texels
  in a 4x4 Bayer pattern); `depth_pull` behind `VFX_DEPTH_PULL` (vertex moves toward the camera
  along its view ray, so a splat draws over the target billboard without moving on screen);
  per-particle varyings are `flat`, because interpolated values put fragments on different
  flipbook frames at a cell boundary (seen as horizontal stripes at t = 11/60 s).
- New wrappers `vfx_essential_pixel_{mix,add,premul}.gdshader` define `VFX_FILTER filter_nearest`
  and `VFX_DEPTH_PULL`.
- r24: `VFX_LIT` in the include and the wrapper `vfx_essential_pixel_lit.gdshader` (shaded,
  blend mix). ALBEDO from the frame; NORMAL leans from world up toward the camera (face_camera)
  and is tipped by a normal page sampled at the same flipbook cell (normal_base Billboard), or
  takes the mesh normal for flat ground quads (normal_base Mesh); light() is lit_sprite's wrapped
  diffuse (light_wrap) plus a hard on/off specular glint (glint, roughness); EMISSION is
  albedo times (emission_base + emission_strength on texels above sRGB luma emission_luma). Not
  copied from lit_sprite: light_on_axis (it needs the unit's feet height) and the sideways bend.
  The uniform is `light_wrap`, not `wrap`: the include has function parameters named `wrap`.
- r22: `<work>\capture_lit.gd`, a copy of the skill's capture script with `--lit=1` (cool key 0.08,
  a wall torch, a shaded floor, the hero with lit_sprite and its normal page). The shared script
  is unchanged.

## State after the first pass (r15)

- Superseded by the second pass (r16 to r21, below the first round log).
- Blind reviews: review 1 preferred r04 over r05 (r05 reverted); review 2 scored r12 7/10 and r11
  6/10 (r12 kept). Review 3 (r14 = B against r15 = A) reported after the hand-back: B (r14) 7/10,
  failed 13; A (r15) 6.5/10, failed 13 and 15. r15's checker-dithered vapour reads as a screen-door
  pattern and is lost at 24 m. r15 gained round specks, no "+" glints and faint specks in tile 12.
  The coordinator chose the narrower path: r16 cut the vapour and kept r15's other fixes.
- Review 3 top changes for r14: (1) flash emission down so only the 1 to 2 px cross passes the glow
  threshold, flash and light tinted toward E2E5A9/A9BF58, and the 0.07 s ring frame broken into
  glass arcs over the crown (the closed ring around a pale disc reads as an orb); (2) puddles to
  779539 with a 425A26 rim by about 0.4 s and drying from 0.65 s, so the body stays the brightest
  part after 0.5 s.
- Review 3 other notes: the half-alpha dark halo around the splat does not measure as darker on
  this stage; beads thrown upward hang beside the head at 0.4 to 0.5 s and read as gems; the sagging
  splat at 0.5 s is close to a green tabard; r14's puffs read as moss below knee height.

## Hook (AcidSplash : OneShotFx, integrated 2026-10-22)

- Scene `res://scenes/fx/acid_splash.tscn`, root `Node3D` named AcidSplash, with
  `res://scripts/fx/AcidSplash.cs` attached by this build script. Unique names: `%Ground` (Ring,
  Puddles), `%Body` (Droplets, Splat, Glass, Bubbles, Flash, and `%Light` since r23), `%Anim`
  (AnimationPlayer, animation `play`, drives `Body/Light:light_energy`). There is no `%Vapour` since
  r16. `%Light` rides the body's scale for its position only: at body scale 0.713 it sits 0.93 m
  above the impact, not 1.3 m. Its 4 m range does not scale, because Godot's `omni_range` is not
  affected by the node's or its parent's scale (the 4.6 class reference says so).
- `AcidSplash.cs` names every emitter in two lists: `BodyLayers` (Splat, Droplets, Bubbles) and
  `DirectLayers` (Flash, Glass, Ring, Puddles). A layer added to or cut from this build script must
  be added to or cut from those lists in the same change. A missing name makes `Build` throw, and
  the node then stays on the board until `ResetEncounter` frees it.
- The presenter (`GodotPresenter3D.SpawnHitEffect`) spawns it for every `DamageDealt` of acid
  damage, in place of the hit spark, under the combat scene's popup layer at the struck unit's feet
  (`on.Position`, the tile centre for a one-tile unit). Before `AddChild` it sets `ImpactHeight` to
  the unit's HP bar height times 0.6 and `FxScale` to `UnitSizeFactor` (bar height over 1.75, floor
  0.66). The sprite's hit flash, the hurt shake, the damage number, the crit shake and the health-bar
  hold are as before. Nothing waits on the effect; the flash (0.08 s) is the impact frame.
- `Build` moves `%Body` to `ImpactHeight`, scales it by `FxScale * BodyPixelScale`, calls
  `Restart()` on each listed emitter, plays `%Anim` and holds the tween for `Lifetime` (1.6 s), after
  which the base class frees the node. `%Ground` keeps its drawn size, position and rotation.
- `BodyPixelScale` is 1.08. Every creature that takes acid in the Prologue sits at the FxScale floor
  of 0.66: the rats (bar 0.53 m) and the Tyrant (bar 1.15 m). 0.028 x 0.66 x 1.08 = 0.020 m a texel,
  the Prologue sprites' pixel size, checked on the in-game shots `dev_shots/acid_splash.png` (0.15 s)
  and `acid_splash_late.png` (0.5 s). A Prologue hero (FxScale about 0.71) would get 0.0215 m texels.
  The Tyrant's sprite pixels are 0.046 m, so its splat texels are under half of them.
- `Minor` is set when the event is not a direct flask hit: the event has no bomb extras (any other
  acid damage), or `bomb_splash_only` is true (a creature the splash alone reached, and the target
  of a throw that missed). Minor restarts only the body layers, hides Flash, Glass, Ring, Puddles and
  Light, and does not play `%Anim`. The body keeps its full scale, because a smaller scale would make
  its texels finer than the sprite's pixels.
- Persistent damage raises no battle event, so a persistent acid tick plays no splash.
- `ResetEncounter` frees every child of the popup layer, so a splash still playing when an encounter
  is torn down goes with the rest.
- `CombatScene.StartEncounter` loads this scene as the board builds
  (`FxLibrary.PreloadEncounterEffects`). Loaded in the frame of the first hit instead, it ran that
  frame 101 ms before the spawn, and 181 ms in the first run after r28's new lit shader, which also
  drew a 430 ms frame after the spawn and showed no body layers at 0.15 s. With the preload the
  first hit's frame ran 18 ms before the spawn and 19 ms at most after it; later hits run 9 to 13 ms.
  Godot keeps compiled shaders in its cache, so the 430 ms frame was most likely the first compile
  of the new shader, and a player's first run after install may still see it once.
- In game (rendered prologue run, round 32): the splat's texels match the rat's pixels; at 0.15 s
  the light lifts Rat D and the wall by about 10 levels with almost no green shift (G minus R +1 to
  +4), so it reads as a faint brightening, not a green cast; the lit puddles take the torch (brighter
  and yellower on the torch side, with glints); nothing is blown out under the sewer look.
- Open decision: a Large (2 x 2) target stands centred on its space, a tile corner, so the eight
  floor splats land on the edge and corners of its own footprint instead of on the twelve squares
  around it. This is not solved.
- The Body layers carry `depth_pull` (0.15 to 0.6 m) so they draw over the target's billboard,
  which writes depth at the same spot; droplets behind the target are still hidden by it.

## Known limits

- The close and game sheets use the grey grid stage under a white sun of energy 1. Since r24 the
  splat and puddles are lit, so on that stage they read brighter than in the sewer, where the key
  light is 0.08. The lit sheet (`rNNl`) is the closer guide for in-game brightness; it is still a
  grey matte floor, not the sewer's stone.
- The light now rides on `%Body` 1.3 m above the impact. The adapter scales `%Body` by
  `FxScale * 1.08` (about 0.71 for every Prologue target), which lowers the light to about
  0.93 m above the impact. Whether Godot also scales the omni range with the node is not checked.
- The lit material does not take lit_sprite's `light_on_axis`: the splat is lit per pixel at its
  own position, so a light right beside the target can light the splat and the sprite under it
  from slightly different points.
- Under a warm torch at about 1.5 m the near puddles turn yellow-green despite emission_base 0.35.
  That is the torch's colour, kept on purpose; a stronger emission_base would flatten the lighting.
- Pixel size: frames are 0.028 m a texel at FxScale 1. The presenter scales Body by about 0.66 to 0.7
  for rats and the prologue heroes (PixelSize 0.02, about 1.2 m tall), which brings the splat's
  texels to about 0.02 m, the sprites' size. The Ground layers are not scaled and stay at 0.028 m.
  On the Large Tyrant (PixelSize 0.046) the splat texels are smaller than the sprite's.
- `depth_pull` 0.5 to 0.6 m on the Body layers assumes a target thinner than that toward the camera.
  The lit sprite bends its vertices (bend 0.6, half width 0.4); a Large target may need more pull.
- Rotated texels: the droplets are velocity-aligned, so their texels rotate off the screen grid.
  Every other layer stays upright (billboards) or lies flat on the floor.
- The overdraw index is 27.1 against the audit's 20. It comes from two flat ground quads that are
  almost all transparent: the 3.1 m ring (0.3 s) and the 3.58 m floor (1.44 s).
- Fixed layout: every throw shows the same splat drawing and the same floor pattern. Droplets,
  glass and bubbles vary per play. The adapter could mirror `%Ground` on X or Z at random for a
  second floor layout; the splats would stay on the tile centres. Mirroring `%Body` on X would
  give a second splat; with the lit material that also mirrors the normal page's x, which the
  shader does not flip (lit_sprite flips it for FlipH), so the splat would be lit from the wrong side.
- The floor layout assumes a one-tile target on its tile centre. A Large (2 x 2) target's
  neighbours sit 1.5 m out, so its floor splats would land inside its own footprint.
- Orbit check (r13, game camera at yaw 225, `angle_r13/sheet.png`): the same read from the far side;
  the splat still draws over the target. How many puddles land on the camera side changes per play.

## Rounds

```
r02  changed: rewrite for pixel art. Eight flipbook layers (ring, puddles, vapour, splat, droplets,
              glass, bubbles, flash) plus the light; frames drawn by draw_acid_frames.py
     expected: crisp pixel splat over the target, ground ring and puddles at one tile
     sheet: r02c, r02g   score: 5/10   failed: 2, 7
     cold read: white flash on a swordsman's chest, a spiky green ball bursts over him, a pale ring
              runs across the floor, blobs splat around him, slime drips, a dithered haze on his
              head, floor splats dry out. Game view: same event, ring and puddles read at 24 m.
     notes: the even radial tongues read as a sun or spiky ball, not liquid (2); the splat's end
              fade dithers into a checker net at 0.5 s (7); vapour is dither noise over the head;
              puddle landing frames look like stick insects.

r03  changed: splat tongues uneven (11 tongues, reach 8 to 20 px, two forks, curled tips, free beads
              between them, three uneven drips, lobed mass, off-centre core); splat end fade removed;
              vapour as solid 24 px puffs with an empty first frame
     expected: the peak reads as an irregular liquid crown; no checker net at 0.5 s; vapour reads as fumes
     sheet: r03c, r03g   score: 6/10   failed: 3
     result: crown reads as liquid, net gone. Vapour now reads as a green bush on the head and leaves
              a dither square at 1.1 s. The 20 outlined droplets pile over the splat at 0.07 to 0.15 s
              and the splat body is one light value.

r04  changed: droplets born on a 0.32 m sphere surface and drawn behind the splat (priority -1);
              splat pixels below the mass centre take the mid shade; puddle landing frame redrawn
              as a short seven-spike crown
     expected: clean splat silhouette at the peak; a darker lower half; no insect shapes on the floor
     sheet: r04c, r04g   score: 6/10   failed: 3 (weak)
     result: silhouette clean, beads leave from the rim. Lower-half shade is a small change. Landing
              frames now read as eight-point stars (not liquid). Vapour still reads as hair.

r05  changed: puddle landing frame = small blob with separate spray dots; vapour puffs smaller
              (radius 3.2 px at most), born at the impact point, faster rise
     expected: landing frames read as spatter; nothing green sits on the head
     sheet: r05c, r05g   score: 6/10   failed: 3 (weak)
     result: landing frames read as spatter (kept). Vapour still slows beside the head and reads as hair.

r06  changed: vapour moved from Body to Ground: 5 puffs from a 0.6 to 1.1 m ring, rising 0.4 to 0.7 m/s
     expected: the head stays clean from 0.4 s on; fumes rise off the splashed squares
     sheet: r06c, r06g   score: 6/10   failed: 3 (weak), 5 (0.3 s round mass ringed by beads)
     result: head clean; small dithered puffs rise from the floor ring. Open: the drips at 0.4 to 0.5 s
              read as tentacles; little acid stays on the target after 0.55 s.

r07  changed: splat 12 -> 18 frames (0.83 s, 46 ms a frame): after 480 ms the patches cling as stains
              that shrink and darken in place, drips end at 620 ms, sag stops at 6 px; bubbles get a
              second, larger row (up to 7 px) and sit 0.1 m lower
     expected: acid stays on the target until about 0.85 s, as the timing table's dissipation phase
              asks; bubbles visible at 24 m
     sheet: r07c, r07g   score: 6/10   failed: 3 (weak)
     result: stains and bubbles hold on the chest to 0.85 s; the body still shows green at 0.6 s in
              the game view. The 7 px ring bubbles read as round goggles at 0.85 s.

r08  changed: large bubble row capped at 5 px with no held ring frame; puddles drop to the mid
              value one frame after landing (frame 3), dark edge from frame 4
     expected: no goggle rings at 0.85 s; floor splats bright only for about 0.25 s after landing
     sheet: r08c, r08g   score: 6/10   failed: 3 (weak)
     result: as expected. Floor splats are mid green from about 0.5 s.

review 1 (after r08, on r04 = B and r05 = A, labels masked, opus)
     cold read A: a white flash on a swordsman's chest, a lime star of liquid over his head and torso
              with a pale ring on the floor, blobs land around his feet, liquid runs down him in
              columns, a sage cloud on his hair, floor blobs dry to flecks and are gone by 1.4 s.
     cold read B: the same, except the floor blobs land as spiky stars with pale centres and the
              head cloud is bigger and leaves a checker patch at 1.1 s.
     scores: A 6/10, B 6/10, both failed 5, 6, 8, 12. Gates pass on both.
     verdict: B (r04) is better by a small margin: the star landings show each puddle arriving on
              the neighbouring squares. r05 loses, so its landing frame is reverted in r09 (its
              vapour change was already replaced in r06).
     top changes: (1) sag and drip frames that keep the pale core and dark rim and split into 3 or 4
              thinning runs, with beads thrown at 2 to 4 m/s under gravity, stretched along their
              motion and in different sizes; (2) smaller greyer vapour away from the hair (done in r06).
     defects: flash at 0.03 s reads as an orb ringed by green dots; glass reads as sparks, nothing
              reads as a flask; ring end dashes read as grass; 0.3 s mass in a ring of beads reads as
              grapes; overlapping puddle outlines read as cracked tiles; drip columns read as bars or
              bottles; bubble pop reads as an emblem; dried puddles with holes read as padlocks.

r09  changed: puddle landing frame reverted to r04's spike crown (blind review); splat middle phase
              redrawn: the pale core holds until 520 ms, the mass flattens and drains into four
              uneven tapering runs that snap at 520 ms (beads fall, tops stay as stains); thrown
              beads leave at about 1.5 m/s and fall at 9.8 m/s^2, drawn as 22 ms streaks
     expected: at 0.3 s a pale-centred splat with beads falling away, not a lump in a ring of beads;
              thin runs at 0.5 s; small stains at 0.65 s
     sheet: r09c, r09g   score: 6.5/10   failed: 3 (weak), 6
     result: as expected at 0.3 s and 0.65 s. The 0.4 to 0.5 s coat still reads a little as a green vest.
              Removing the mass holes took away an eye shape the first draft had.

r10  changed: puddles drawn with no dark outline (overlaps made a grid) and dried in 2x2 speckle
              blocks instead of round holes (padlocks); ring frames 4 to 6 are spray dots, not dashes;
              landing spikes end in beads
     expected: no cracked-tile grid at 0.3 s, no padlock shapes at 1.1 s, no grass blades at 0.22 s
     sheet: r10c, r10g   score: 6.5/10   failed: 3 (weak), 6
     result: all three gone. Cost: in the game view the ring is no longer visible at 0.25 s (the dots
              are too small at 24 m); it still reads at 0.15 s.

r11  changed: glass shards 8 px angular pieces in quarter-turn tumble frames, 8 of them, emission 2.2;
              flash starburst redrawn with thin rays and a small core, emission 4 -> 2.5; droplets
              born on a 0.15 m sphere instead of 0.32 m
     expected: glass reads as broken flask pieces; the flash keeps a star shape; no ring of droplets
              around the flash
     sheet: r11c, r11g   score: 6.5/10   failed: 3 (weak), 6
     result: glass reads as white shards at 0.15 to 0.3 s (kept). The 0.033 s tile lands on the flash's
              second frame (the ring), so the starburst never shows; the droplet change made no visible
              difference and is reverted in r12.

r12  changed: droplet spawn radius back to 0.32 m; droplets hidden (alpha 0) for the first 6 percent
              of life; flash 3 -> 4 cells over 0.13 s with the starburst held for two cells
     expected: tile 1 shows the star, not the ring; no ring of green dots around the flash
     sheet: r12c, r12g   score: 7/10   failed: 6, 8 (particle droplets identical and not stretched)
     result: tile 1 is a crisp white four-point pixel star with bloom; the dot ring is gone.

review 2 (after r13, on r11 = A and r12 = B, labels masked, opus)
     cold read A: a green blob bursts on a swordsman's chest out of a white ring flash, throws beads,
              a pale ring and splats across the floor, sags down his tunic in drips, leaves dark
              specks that are gone by 1.4 s.
     cold read B: the same, opening with a white four-point star glint, then the ring at 0.07 s.
     scores: A 6/10 (failed 6, 11, 13), B 7/10 (failed 6, 11). Gates pass on both.
     verdict: B (r12) is better: the star reads as glass breaking and holds the impact for two
              tiles. r12 kept.
     failed checks for B: 6, the glass shards are one triangle in four turns and the puddle landings
              repeat one eight-arm asterisk; 11, the visible ring peaks near 1.0 m at 0.15 s and is
              gone by 0.22 s, puddles land at 0.8 to 1.0 m, so the diagonal neighbours (1.41 m) get none.
     top changes: (1) ring as ragged separate spray clumps with an A9BF58 body and 425A26 outline,
              growing to 1.5 m and visible until 0.3 s; (2) four distinct outlined landing splats with
              a 779539 shadow side instead of the asterisk.
     defects: the clean ring reads as a unit selection ring; flat white glass triangles read as UI
              corner brackets; pale landing frames read as sparkle stars at 24 m; "+" twinkles read as
              magic sparkle; vapour clumps at boot height read as moss; dried specks form letter
              shapes (F, L, C); tile 12 is empty where the brief asks for faint puddles.
     fit: the splat on the body would sit beside the sprite; the floor layers look generated.

r13  changed: particle droplets redrawn as four teardrop shapes (head at the top, tail below, two
              mirrored highlights) whose tails shorten over life; emitter aligned
              Z_BILLBOARD_Y_TO_VELOCITY so the head leads along the velocity
     expected: drops read as flung liquid streaking out and down, not identical octagon beads
     sheet: r13c, r13g   score: 7/10   failed: none clear; 3 and 5 borderline (see review 2)
     result: drops streak along their arcs at 0.12 to 0.4 s. Rotation puts a few jagged texels on them,
              which reads as motion at this size.

r14  changed: ring redrawn as a ragged band (radius and width wander) that breaks into 22 outlined
              spray clumps with spray thrown ahead, out to 51 px = 1.43 m, visible until 0.3 s;
              puddles 9 -> 12 on a 0.8 to 1.4 m ring so the diagonal squares are splashed; landing
              and full puddle frames get the dark outline and a shadow side, and each layout lands with
              its own few arms; glass in four different shard shapes with an acid-wet edge
     expected: at 0.15 to 0.22 s broken spray reaching the diagonal tiles instead of a selection ring;
              wet green splats on the neighbouring squares at 0.25 and 0.4 s in the game view, not stars
     sheet: r14c, r14g   score: 7/10   failed: none of the gates; open defects in the next entry
     result: as expected in both views. Open: vapour at boot height, dried specks shaped like letters,
              "+" crosses in the bubble and flash frames, tile 12 empty.

r15  changed: vapour 4 puffs born on the 0.7 to 1.2 m ring, rising 1.0 to 1.4 m/s, dithered from birth
              (alpha 0.65 to 0), 0.7 s life, no dark underside on the puffs; dried puddles shrink to a
              few round specks (no 2x2 block noise); "+" frames removed from bubbles, droplets and the
              flash's last frame (2x2 glints); puddle life 1.2 -> 1.3 s
     expected: fumes visibly rise from the splashed squares and are gone by about 1 s; no letter-shaped
              specks at 1.1 s; no "+" twinkles; faint specks in tile 12
     sheet: r15c, r15g   score: 7/10   failed: 6 (borderline)
     result: fumes rise to mid height by 0.65 s, still visibly dithered; specks are round; tile 12 holds
              a few faint specks in the game view. Side effect: the bubble rings now hold for two
              frames, and at 0.85 s two rings side by side on the chest read as goggles again.
```

## Astra review 1 (gpt-6-astra, read-only, on r15c, r15g and r14c)

Command: `codex exec -m gpt-6-astra --sandbox read-only --skip-git-repo-check -C <work> -i r15c/sheet.png
-i r15g/sheet.png -i r14c/sheet.png -o astra_review_1.md "$(cat astra_prompt_1.txt)"`. The prompt is
`<work>\astra_prompt_1.txt`. Full reply:

> The effect has a strong hit and a readable splash, but the opening currently communicates "green magical impact" more clearly than "acid flask." The liquid coating and ground splats establish acid afterward. r15 improves the vapour's prominence compared with r14, but its exposed checker pattern introduces a different distraction. The game view is the decisive reference: several details that look attractive close up become competing bright dots there.
>
> At impact, the flash dominates, backed by the splat's pale centre. That is the right order for a shattering flask, although the combined white area hides both the liquid shape and most of the glass. At 0.033 s, the four-point star is the strongest identifiable shape. It sells force more readily than breakage. The hit is sufficiently bright already.
>
> During spread, the body splat dominates through approximately 0.217 s, with the expanding ground ring supplying the secondary read. That hierarchy is appropriate: direct damage first, surrounding splash second. The crown of tongues at 0.117–0.15 s is particularly effective. However, the regular expanding ring briefly resembles a magical shockwave, and the detached droplets, glass and glints have similar small, bright silhouettes. They communicate energetic debris collectively, but their materials are difficult to distinguish.
>
> During dissipation, dominance transfers from the body coating to the ground splats. By 0.4–0.5 s, the game view places considerable emphasis on the bright foreground puddles. Some transfer is desirable, but the puddles remain fresh-looking while the body is already clearing. This weakens the sense of sustained corrosion on the target. The r15 vapour is less obstructive than r14's solid puffs, but its checker clusters read as patterned fragments more than rising fumes.
>
> During aftermath, the ground residue dominates, which is correct. At 0.85 s, it still has enough area to hold attention; by 1.1 s, it becomes sparse staining, and 1.4 s is nearly empty. The close view retains a small bright chest accent at 1.1 s that competes with this otherwise subdued finish. The sampled ending looks appropriately restrained, although contact sheets cannot establish whether the final erosion feels smooth or abruptly switches frames.
>
> The additive versus alpha-blended balance is structurally sensible. The issue is that alpha-blended pixels can still be extremely luminous: the flash, emissive splat core, bubbles and fresh puddle centres collectively produce several near-white accents. The game view shows the strongest bloom around the initial flash, but the later competition comes from bright opaque shapes as much as glow. I would preserve the flash's peak and reduce the area and persistence of competing pale pixels. Conversely, the vapour and dried puddles look flat because their internal shapes become uniform patches or checker patterns. They need better silhouettes and erosion, rather than additional emission.
>
> The value hierarchy holds best along the splat's outer tongues. Pale highlights sit inside a green body, with a darker underside and outline giving the liquid thickness. It collapses in the central mass around 0.067–0.217 s, where pale core, flash remnants and highlights merge. At game distance, the interior becomes a bright badge on the chest. The ground splats retain useful outlined shapes early, then lose their separation as they shrink. The half-alpha backing helps against the character, but the supplied floor cannot establish how well the dark rim will survive against near-black sewer stone. Nor can these sheets establish whether the actual light supports or overwhelms that separation.
>
> The overall timing has a good attack and a generous release. The grounded puddles and downward body runs give it weight. The weaker interval is approximately 0.15–0.4 s, when ring fragments, falling droplets, glass, new puddles, bubbles and vapour are all contributing small shapes. The sheets establish overlap, but do not prove that those layers start or end on identical frames. Visually, the main problem is insufficient separation between outward splash, landing and subsequent reaction. The fast vapour also competes with the falling liquid, pulling attention upward before the landing has fully resolved.
>
> At 24 m, the flash, broad splat silhouette, expanding footprint and larger puddles all read. The coating shrinking off the torso also reads. Individual glass shards, bubble rims, one-texel glints, thin outlines and vapour dithering mostly register as flicker or texture. The current game sheet communicates splash around the target, but it does not clearly establish comparable coverage across all eight neighbouring tiles. The foreground cluster is much more assertive than the far side.
>
> What is missing is a clear reaction after the liquid lands. Acid is communicated most specifically by liquid sticking, running, bubbling at contact and leaving an altered surface. Those ingredients exist here, but the opening spectacle and scattered particles overshadow their causal relationship. There is also little visible evidence of the flask itself beyond bright fragments. Without the incoming projectile or motion, the sheets alone cannot reliably distinguish glass from sparks.
>
> My first change would be to reduce the splat's pale interior to roughly a quarter of its visible area at its 0.12 s peak, retaining the existing outer silhouette and green body. By 0.3 s, pale pixels should survive mainly as narrow wet edges and isolated bubble highlights. Shorten the flash from 0.13 s to approximately 0.08 s while keeping its 0.03 s peak. The next sheet should retain the forceful first tile, reveal a clearly green liquid crown at 0.117–0.15 s, and show separated runs rather than a luminous chest patch at 0.3–0.5 s.
>
> My second change would be to make the dissipation explicitly contact-driven. Keep the four vapour puffs, anchor them to four actual puddle landings, and start each approximately 0.08 s after its puddle appears. Replace the all-over checker treatment with compact, irregular silhouettes that break away from their edges. Keep body bubbles attached to surviving wet runs. The next sheet should show liquid landing first, then a few coherent fumes above those same locations, with readable local sizzling on the torso and substantially less patterned debris.
>
> My third change would be to redistribute the twelve puddles so that eight principal splats occupy the eight neighbouring tile centres, with up to approximately 0.15 m of positional variation; use the other four as smaller connecting spatters. Stagger their arrivals across the existing landing interval, and take each pale centre down to body green within approximately 0.15 s of landing. The next game sheet should show surrounding coverage by 0.4 s, including the far side, while the 0.5–0.85 s tiles show subdued wet residue instead of a second bright burst concentrated below the target.

What I adopt and reject:
- Adopt (r18): change 1, the splat's pale interior cut to about a quarter of its area at the peak and
  to wet edges by 0.3 s, and the flash shortened to about 0.08 s. Reason: it is the value-hierarchy
  collapse in the central mass that every review also saw ("bright badge on the chest").
- Reject: change 2's vapour. The coordinator cut the vapour in r16 after four designs and both
  blind reviews failed it; anchoring it to the landings is a fifth design of a layer that has not
  read once.
- Adopt (r19): change 2's bubble part, bubbles kept on the surviving wet runs and stains instead of
  a sphere round the impact point. Reason: it ties the sizzle to the acid that is still there, and it
  removes the late chest accent at 1.1 s.
- Adopt (r20): change 3, eight principal splats on the eight neighbour tile centres and four smaller
  spatters, pale centres to body green within 0.15 s of landing. Reason: it shows the PF2e splash rule
  (every neighbouring square) at 24 m. GPU point emission picks its points at random, so this is
  built as one world-aligned ground decal flipbook with the eight splats drawn at the tile centres
  and their landings staggered in the frames, inside the existing `Puddles` node.
- Noted, not acted on yet: the ring still resembles a magical shockwave; droplets, glass and glints
  share one small bright silhouette.

## Rounds, second pass (r16 onward)

```
r16  changed: vapour layer cut (Vapour emitter, vapour.png and the two vapour palette entries gone);
              kept r15's round specks, 2x2 glints and faint tile-12 specks; flash redrawn as a 1 px
              cross, white only at its 2 px centre and inner arms, pale then acid green outward,
              emission 2.5 -> 1.6; the third flash cell (0.07 s) is five glass arcs and shard ticks
              with no centre disc; the light stays A9BF58
     expected: game tile 1 a tight green-white star with a halo no wider than the shoulders; no orb
              at 0.07 s; no fumes
     sheet: r16c, r16g   score: 7/10   failed: 6 (borderline)
     result: as expected: tile 1 halo about shoulder width in the game view, no ring or disc at
              0.07 s. The glass arcs are faint.

r17  changed: puddle frames: only the landing (frame 1) is bright and outlined; from frame 2
              (about 0.4 s) the pool is 779539 with an inner 425A26 rim, and it shrinks from frame 4
              (about 0.65 s); bubbles redrawn as filled beads with a shaded base, no hollow rings
     expected: after 0.5 s the acid on the body is the brightest part; no goggles at 0.85 s
     sheet: r17c, r17g   score: 7/10   failed: 6 (borderline)
     result: as expected in the close view; in the game view the 0.6 s floor is a step darker. The
              0.85 s chest shows a small bead cluster, no rings.

r18  changed: Astra change 1: splat pale core smaller (radius 3.5 -> 0 px by 300 ms; it held to
              520 ms) so later pale pixels are only the wet top edges; splat emission 1.3 -> 1.1;
              flash 0.13 -> 0.08 s (four 20 ms cells)
     expected: a clearly green crown at 0.07 to 0.15 s, separated runs instead of a luminous chest
              patch at 0.3 to 0.5 s
     sheet: r18c, r18g   score: 7/10   failed: 6 (borderline)
     result: measured effect-only pale pixels (B > 150 and G > 200, minus the clean 1.4 s tile)
              r17 -> r18: 2520 -> 1450 at 0.07 s, 2569 -> 1920 at 0.12 s, 1207 -> 875 at 0.3 s. At the
              0.12 s peak pale is about 8 percent of the green area. The 0.07 s tile is green, no ring.

r19  changed: Astra change 2 (bubble part): bubbles spawn on a 0.4 x 0.28 m box 0.12 m below the
              impact, where the runs and stains sit; three empty lead cells make each wait 0.22 s;
              16 bubbles over 0.39 s, each 0.65 s, so they show from about 0.22 to 1.04 s
     expected: no bubbles over the crown at 0.12 to 0.3 s; sizzle on the runs at 0.4 to 0.65 s; a
              clean chest at 1.1 s
     sheet: r19c, r19g   score: 7/10   failed: 6 (borderline)
     result: as expected in the close view. The game view shows the floor splats bunched on the
              camera side at 0.4 to 0.85 s, the gap Astra named.

r20  changed: Astra change 3: Puddles is now one world-aligned 128 px (3.58 m) ground flipbook,
              36 frames of 40 ms: eight splats on the eight neighbour tile centres (up to 0.11 m off)
              and four 0.6-size spatters between them, landing staggered 130 to 330 ms, bright for
              100 ms, mid green by 220 ms after landing, dried to specks by 1.44 s
     expected: in the game view every neighbour square, far side included, holds a splat by 0.4 s
     sheet: r20c, r20g   score: 7.5/10   failed: 6 (borderline)
     result: as expected: the 0.4 and 0.6 s game tiles show the 3 x 3 pattern round the target.
              Cost: every throw shows the same floor layout; the old random ring varied per play.

r21  changed: ring band lopsided (radius swings 15 percent round the ring) with three gaps, no
              pale inner line, emission 1.2 -> 1.0, body colour until frame 4; droplet emission
              1.2 -> 1.0 so only the white glass blooms in flight
     expected: at 0.07 to 0.12 s a broken splash front, not a glowing ellipse; glass and drops read
              as two materials
     sheet: r21c, r21g   score: 7.5/10   failed: 6 (borderline)
     result: the ring reads as thrown liquid in the close view and as a broken green ellipse at
              24 m. The droplet change is hard to see at 24 m.
```

## Astra review 2 (gpt-6-astra, read-only, on r21c, r21g and r15c)

Same command as review 1 with `-i r21c/sheet.png -i r21g/sheet.png -i r15c/sheet.png` and
`<work>\astra_prompt_2.txt` (the current layer list and the changes since r15). Full reply:

> The current version is cleaner and more readable than r15. It communicates a strong green liquid hit followed by ground contamination. At game distance, the remaining weaknesses are the circular footprint, the sustained brightness on the chest, and limited evidence of acid actively corroding something.
>
> During impact, the flash and splat dominate, which is right. The thinner cross gives the hit a sharp centre without washing out as much of the target as r15. During spread, the crown-shaped splat remains dominant while the ring and droplets establish expansion. That works through about 0.15 s, but by 0.217–0.3 s the chest still carries a broad, bright patch that competes with the landings. During dissipation, the runs and bubbles take over on the body, with the puddles providing a secondary footprint. This is the correct handoff, although the bright body details still merge at game distance. During aftermath, the floor residue dominates appropriately, and 1.4 s is convincingly clear.
>
> The additive flash is now proportionate. I would leave its strength alone until seeing the effect in motion. The hotter-looking elements are the clustered bubbles and pale wet highlights around 0.3–0.65 s: alpha blending does not stop them from becoming a luminous mass when their values and emission are high. Conversely, the settled puddles become rather flat olive shapes. That is useful for reducing distraction, but they lose some liquid character. The sheets cannot establish whether the light ties these unshaded layers into the environment. Near-black stone could also make the remaining pale accents more conspicuous than they are here.
>
> The value hierarchy holds best in the expanding splat around 0.117–0.217 s. There is a readable pale interior, green body, and dark edging around the tongues. It weakens where pale highlights occupy neighbouring parts of the chest and resolve into one bright patch. The runs have useful dark separation in close view, but much of that structure disappears in the game view. On the floor, the early bright splats have readable centres and boundaries; later, the body and rim compress into small green marks. The dark backing helps silhouette definition close up, but against near-black stone it may contribute little visible separation.
>
> The timing has more weight than r15 because the floor settles and dims instead of continuing to compete with the hit. The expanding band still risks reading as a ground shockwave: a substantial footprint appears while much of the airborne liquid is still travelling. Around 0.15–0.3 s, crown tips, droplets, glass, the breaking ring, new puddles, and starting bubbles all contribute small bright marks. Their overlapping activity matters more than exact simultaneous start times. The staggered landings help, but the sampled sheets cannot prove that each landing feels connected to a falling droplet. The body's draining motion supplies most of the liquid weight; the suspended beads contribute less.
>
> At 24 m, the initial hit, green chest coating, outward burst, surrounding contamination, and eventual clearing all survive. Individual glass shapes, dark inner puddle rims, tiny glints, and distinctions between bubbles and droplets mostly do not. The eight neighbouring splats give better coverage, but their combined silhouette still reads as a loose dotted circle around the actor. I would understand "nearby splash damage," but I would not confidently infer all eight affected squares from this sheet alone. The gameplay footprint needs stronger spatial grouping, rather than more particles.
>
> The missing corrosive cue is a clear relationship between a wet surface and its reaction. Green liquid and drifting beads can also read as slime or poison magic. The close view's clinging runs help considerably, but the game view does not clearly show bubbles swelling out of those runs, rupturing, and leaving a smaller stain. The same connection is missing on the floor. A few readable surface-bound reactions would sell acid better than restoring vapour. The flask shattering is also subordinate to the green burst: the white fragments register as impact sparkles more readily than unmistakable glass.
>
> I do not have the earlier review's exact three recommendations here, so I would not claim an exact three-for-three verdict. Judging the supplied changes, the flash restraint landed, although reducing the pale core has only partly solved the sustained bright chest read. Removing vapour landed strongly: the silhouette is cleaner and the effect fits the pixel treatment better. The aftermath changes also landed, with much better brightness decay and a cleaner finish. The tradeoffs are that removing vapour exposed the shortage of other corrosion cues, filled bubbles now resemble loose green beads at distance, and the more evenly distributed floor coverage reinforces a circular perimeter. Breaking the ring improved its texture, but did not completely remove its shockwave character.
>
> My first change would be to reshape the existing eight puddle clusters so each has one readable mass nearer its tile centre, with irregular inward streaks and fewer equally prominent perimeter flecks. Keep the coverage, but vary the silhouettes and bright landing accents. The next game-view sheet should show contamination occupying the neighbouring squares, with visible substance inside the footprint rather than mainly around its edge.
>
> My second change would be to make the body's transition from burst to coating more decisive between 0.217 and 0.4 s. Break the broad central patch into separated downward runs, expose more of the torso, and keep pale accents on only a few upper wet edges. The next sheet should retain the strong early crown but show distinctly hanging liquid by 0.3 s and a recognisable target beneath it by 0.4 s.
>
> My third change would be to replace some detached bubble activity with fewer, larger surface-bound boil-and-pop sequences on the body and selected puddles. Stagger them through roughly 0.3–0.8 s, with each pale cap appearing briefly before the bead collapses into darker residue. The next sheet should show discrete reaction points attached to wet patches, rather than a scattered halo of green dots. That would add corrosion without rebuilding the noise you just removed.
>
> I would score the game-view communication 7.5 out of 10: the direct hit and surrounding green splash are clear, but the exact eight-square coverage and actively corrosive character still need stronger visual evidence.

What I take from it (not built: r16 to r21 used the six rounds the coordinator allowed):
- Agree, next pass: change 2, the splat's 0.22 to 0.4 s frames break into separated runs earlier so
  the torso shows by 0.4 s. It is the one fault every review since r08 has named (lump, tabard,
  bright patch).
- Agree, next pass: change 3, fewer and larger boil-and-pop bubbles drawn into the splat and floor
  flipbooks (a pale cap, pop, darker residue) instead of a separate scatter of beads.
- Agree in part: change 1, one solid mass nearer each tile centre with fewer perimeter flecks. The
  "dotted circle" read is real at 24 m, but the board's own tile highlight in game may carry the
  eight-square read better than the effect; this needs the in-game check first.
- Astra's 7.5/10 for the game view matches my own score for r20 and r21.

## Fourth pass: state at hand-back

- On disk: r32 (scripts and the include in `<work>\keep\r32\`, scene and frames built from them).
  Sheets `<work>\r32c\sheet.png`, `r32g\sheet.png`, `r32l\sheet.png`.
- New in this pass: the splat on render layer 5, skipped by its own light (`light_cull_mask`);
  `light_desaturate` in the lit include; frames with a dark lower-right edge and a half-alpha halo,
  a visible run phase, torn floor spatters.
- Blind review 6 (opus): pair 1 r28 (A) against r32 (B) with all three views; pair 2 r32 (C)
  against r21 (D), close and game; each copied from its own round's folder (B and C are the same
  sheets on purpose). Staged in `<work>\review6\`. If r28 wins pair 1, `<work>\keep\r28\` holds it.

## Third pass: state at hand-back (superseded)

- On disk: r28 (scripts in `<work>\keep\r28\`, scene and frames built from them). Sheets
  `<work>\r28c\sheet.png`, `r28g\sheet.png`, `r28l\sheet.png`.
- Own score 7.5/10, check 6 borderline. Blind review 4 had chosen r21 over r20 (7 against 6).
- Blind review 5 (pair 1: r28 = A against r27 = B with all three views; pair 2: r21 = C against
  r28 = D, close and game) was still running at hand-back, staged in `<work>\review5\`. If it
  prefers r27, copy `<work>\keep\r27\` over the three scripts and the include, then run the
  draw script, the import pass and the build. If it prefers r21 over r28, the third pass lost.

## Blind review 5 and the override

Blind review 5 (opus, labels masked) reported after the hand-back: A (r28) 5/10, B (r27) 5/10,
C (r21) 6/10. D was meant to be r28 staged from its own files but was a byte copy of A, a staging
mistake; the next review stages each version from its own files.
- Against r28: gate 3 fails, the body splat at 0.07 to 0.30 s is 96 percent lime, pale and white
  with about 1 percent dark pixels, no rim and no halo, so core and body share one value and it
  reads as a spark or energy burst, not liquid; check 13 fails, the core blooms into a soft disc
  at 0.07 to 0.15 s (on the lit sheet a pale haze covers collar to belt); check 5 fails, the eight
  puddles are smooth near-uniform ovals with a centred white diamond, a ring of polka dots at 24 m,
  and under the torch they turn lemon yellow (hue near 46 degrees) and read as yolk or paint. The
  coat-and-run frames are barely visible; r21's drips at 0.40 s and torn floor spatters read as liquid.
- Its verdict: r21 is the better sheet, r28 the better base.

The coordinator overrode the keep-the-best rule on purpose: keep r28 (torn spray body, lit
material, light under Body) and merge r21's strengths into it in pass 4 (r29 to r32), then a
blind A/B of the last round against r28 and against r21, each staged from its own files.

## Third pass (r22 onward)

Blind review 4 (r20 against r21) chose r21, 7 to 6, so r21 is the base. User notes for this pass,
in their words: "The edges and shape of the acid splat look a little too cartoonish." and "I'd
also like the splat to have lighting and whatnot to play off the hd2d vibe."

## Astra review 3 (gpt-6-astra, read-only: pixel-liquid drawing rules)

Command as before with `-i r21c/sheet.png -i r21g/sheet.png -i splat_frames_r21.png` (the 18 splat
frames at 6x) and `<work>\astra_prompt_3.txt`, which quotes the user's sentence and asks for frame
drawing rules. Full reply:

> The biggest change should be to make the splat an uneven sheet that tears into streams. The current frames keep a recognizable, enclosed green shape for too long. Adding roughness to that same outline would leave the sticker impression intact.
>
> All dimensions below are native pixels in the 48 × 48 frame. Treat these as starting ranges, with the same underlying features tracked through successive frames.
>
> 1. Build an irregular silhouette with deliberate pixel steps.
>
> Make the main sheet roughly 20–26 px wide and 14–20 px tall at its fullest. Let a few extensions bring the total footprint to about 34–40 px. Offset the main mass from the centre of that footprint by 2–4 px.
>
> Along shallow slopes, mix horizontal runs of 2, 3 and 4 px before stepping vertically by 1 px. Along steep slopes, reverse that relationship. Short 1-by-1 staircases are useful on diagonal tips, but avoid repeating them around the entire mass.
>
> Keep some stretches smooth for 5–8 px. Put the sharp changes where liquid stretches, folds or tears. Use only 2–4 isolated one-pixel spurs on the main sheet, each continuing an existing direction of flow. Random spurs everywhere read as fuzz or corrosion.
>
> Cut a few unequal concavities into the silhouette. Early cuts can be 1–2 px deep; later cuts should become 3–7 px channels that actually divide the sheet. Avoid a regular sequence of rounded bulge, notch, rounded bulge.
>
> Use discs to join geometry internally, but remove their circular caps from exposed tips. Generate irregularity from a persistent shape mask that deforms with the liquid, rather than new random noise each frame.
>
> 2. Give tendrils different jobs and strongly unequal lengths.
>
> At peak expansion, use about 5–7 attached extensions: two long ones of 7–11 px, two or three medium ones of 3–6 px, and one or two short shoulders of 1–3 px. Leave at least one substantial sector with no tendril. Do not distribute them evenly around a centre.
>
> Build each long tendril along a slightly bent polyline. Start at 3 px thick for 2–3 px of length, narrow to 2 px, and finish with a 1 px thread for the last 2–4 px. Short tendrils can begin at 2 px. Offset the narrowing to one side occasionally so both edges do not converge symmetrically.
>
> Avoid putting a round bulb on every tip. Most tips should be clipped, slanted or pointed. Reserve a 2-by-2 or 2-by-3 terminal bead for one or two extensions that are visibly about to break.
>
> Across frames, stretch a thread, narrow its neck, then remove a 1–2 px segment at the neck. Transfer the detached portion to the separate droplet system. Do not also leave a floating copy in the billboard.
>
> By roughly 230 ms, most outward tendrils should have broken or collapsed. The remaining attached features should increasingly point downward.
>
> 3. Use four value steps across the sheet, without putting all four around every edge.
>
> Use A9BF58 for the main lit sheet. As an initial colour budget, give it about half the opaque liquid pixels, 779539 roughly a third, 425A26 about a tenth, and E2E5A9 the small remainder. These are area guides, not quotas.
>
> Make 779539 one or two connected, uneven regions under the main sheet and through thicker folds. Let it reach the silhouette in places. Do not make it a uniformly inset border.
>
> Place 425A26 in 2–4 small pockets beneath overlapping lips, at the underside of thick roots, and along one side of selected hanging runs. Use irregular patches around 2–5 px across. Avoid dark dots scattered through the interior.
>
> Put an off-centre pale impact patch of roughly 3-by-5 to 5-by-6 px in the earliest sheet, then stretch and break it into smaller pieces. It should lose area quickly. Do not retain a pale central disc while the outside grows.
>
> For surface highlights, use two or three short pale marks, typically 1 px thick and 2–4 px long, following a bend or raised lip. A 2-by-2 glint can sit on a thick bead. Keep highlights interrupted and mostly on the upper-left-facing surfaces, assuming that is the chosen lighting direction.
>
> Avoid nested masks based only on distance from the centre. Build the colour regions from offset, bent shapes that follow the sheet's stretching direction. A mid-value channel crossing the body is more useful than another concentric band.
>
> Reserve EEE5D2 for glass and the initial impact accent. With emission, first reduce the area of pale pixels if bloom joins separate highlights into one luminous plate.
>
> 4. Replace the closed outline with selected shadow accents.
>
> Put dark edge pixels on roughly 20–30 percent of the perimeter at peak expansion, concentrated along undersides, inward folds and the lower-right side. Use short runs of 2–5 px with substantial gaps. Some of those runs should connect directly to interior dark patches.
>
> Use 779539 along other shaded edges where necessary. Allow A9BF58 to meet transparency directly on lit edges. A one-pixel thread often needs only one colour; outlining it would change its apparent thickness completely.
>
> Use half-alpha 425A26 sparingly under a thick lip or on late residue. Do not dilate the whole silhouette with it. Against the near-black floor, that colour will contribute little to readability.
>
> At the game camera, preserve a few connected body-colour shapes and clear transparent gaps. Those carry the effect better than a continuous dark contour. Put small pale accents on selected outer bends, rather than tracing the boundary with light.
>
> 5. Turn the bottom edge into openings between unequal runs.
>
> As the sheet starts draining, cut three or four upward channels from its bottom edge. Make their widths unequal, around 2, 3 and 5 px, and their depths unequal, around 3–8 px. Offset their starting heights. This should destroy the horizontal lower boundary that currently makes the middle frames look like a bib.
>
> Leave three principal runs with lengths around 4, 8 and 12 px. Give one a 3 px root and the others 1–2 px roots. Their attachment points should start at different heights.
>
> A hanging run can have a thick root, a narrow shaft, a 1 px neck and a slightly wider end bead. Use a 2-by-3 or 3-by-3 irregular bead, with one corner removed. Only one or two runs need this full shape; another can end as a thin thread.
>
> Let runs lean sideways by 1–3 px over their length. Avoid parallel, equally spaced vertical bars.
>
> To detach a bead, lengthen the neck first, then break it. Shorten the remaining attached stump in the following frame. Meanwhile, widen the transparent channels upward through the parent sheet. By approximately 368 ms, there should be no broad connected band covering the torso.
>
> 6. Use eight distinct structural stages, rather than eight scales of one shape.
>
> At **0 ms**, draw a compact, angular rupture about 12–16 px across. Use unequal straight fragments and a small pale centre. Keep white confined to glass or a tiny impact accent. Since this sprite frame lasts 46 ms, avoid filling the whole burst with white.
>
> At **46 ms**, open a 20–24 px sheet with three leading extensions. Make one side travel farther than the other. Establish the asymmetry and the main fold that subsequent frames will inherit.
>
> At **138 ms**, reach the widest footprint. Have 5–7 unequal extensions, but allow the central sheet to become thinner or smaller as those extensions grow. Begin one or two edge tears. Stretch the pale patch into short marks.
>
> At **230 ms**, break the longest threads and begin downward drainage. Collapse an upper shoulder while another remains raised. Open the first substantial channels from below. The result should already be losing its crown shape.
>
> At **322 ms**, divide the sheet into two or three connected remnants with unequal hanging runs. Remove the central bridge over the chest before removing all the side material. Aim for roughly 35–45 percent of the peak opaque area.
>
> At **368 ms**, expose most of the torso. Retain narrow runs and a few small patches, together around 15–25 percent of the peak opaque area. Use no large pale patch and no continuous cross-body strip.
>
> At **506 ms**, break or shorten the remaining runs. Leave roughly 5–10 percent of the peak area as asymmetrical mid and dark residue. Remove pale highlights almost entirely.
>
> At **736 ms**, leave only a few small, separated stains, mostly dark or half-alpha dark. Erode their boundaries and remove components individually. Clear the remaining pixels by the end of the sequence around 828 ms.
>
> For the intervening frames, keep the same tendril roots, fold paths and tear locations. Move most surviving boundaries by 1–2 px per frame; let early tips travel farther. Grow tears along existing thin regions. Do not regenerate the silhouette independently or interpolate every feature toward one common centre.
>
> 7. The five most common mistakes are these.
>
> Equal rounded lobes make a flower or slime emblem. Replace them with two dominant extensions, several smaller ones, broad quiet stretches and unequal concavities.
>
> A continuous dark contour makes a sticker. Restrict dark accents to selected undersides and folds, and let lit body colour touch transparency.
>
> A broad pale centre surrounded by nested colour bands makes a badge. Break the light into an off-centre impact patch and small directional surface highlights.
>
> An evenly scalloped bottom with matching drips makes a bib. Cut unequal transparent channels upward, vary attachment heights and break the central connection early.
>
> Uniform scaling or fresh random noise makes an animated icon or a boiling blob. Track specific features as they stretch, thin, tear, drain and disappear.
>
> 8. Keep the current palette, the initial sharp impact, and the basic transition from splash to runs to stains.
>
> The olive mid and dark colours already give the liquid useful weight. The thin initial rays provide a good contrast to the thicker liquid that follows. The late frames also contain useful unequal fragments and negative space.
>
> Keep the separation between the body splat, airborne drops and ground splashes. The surrounding particles already communicate outward travel. That gives the body splat room to become smaller, more torn and less luminous earlier, while the overall hit remains readable.

What I adopt and reject:
- Adopt, r22: the whole structure. One persistent set of features tracked across all 18 frames
  (sheet lumps, six tendrils of unequal length and job with one empty sector, fold, tears, bottom
  channels, three unequal runs); tendrils taper 3 to 2 to 1 px with clipped tips, one beaded; the
  area schedule (peak at 138 ms, 35 to 45 percent at 322 ms, 15 to 25 percent at 368 ms, 5 to 10
  percent at 506 ms, cleared by 828 ms); the colour budget (about half body, a third mid, a tenth
  dark, little pale); dark edge on 20 to 30 percent of the perimeter in short runs on the lower-right
  undersides; 2 to 3 short pale highlight marks on upper-left lips; the off-centre impact patch.
- Adopt: drops that detach leave the billboard (no floating copy); the Droplets particles carry them.
- Adopt in part: the stair-step rules (2 to 4 px runs, 2 to 4 spurs). I take them through a
  persistent low-frequency noise on the sheet's iso level, not drawn by hand, and check the result
  on the 6x preview.
- Reject: none. Its point 8 (keep the palette, the thin opening rays and the splash, runs, stains
  order) matches the base.

## Rounds, third pass (r22 onward)

Three sheets a round from r22: `rNNc` and `rNNg` as before, and `rNNl`, a lit close view from
`<work>\capture_lit.gd` (a copy of the skill's capture script; the shared one is unchanged):
the sewer's dim cool key light (energy 0.08), a wall torch at (-1.3, 1.6, 0.5) with the prop's
values (colour 1, 0.6, 0.3, energy 3.5, range 6.5, attenuation 0.8, shadows), a shaded matte
floor (albedo 0.25), the hero drawn with `lit_sprite.gdshader` and its normal page, and the sewer
environment. Command: the close-view line with `-s <work>/capture_lit.gd`, `--env=res://scenes/looks/sewer.tscn`
and `--lit=1`, out `rNNl`.

```
r22  changed: the body splat redrawn by Astra review 3's rules in a new file, splat_frames.py:
              metaball lumps on a persistent noise, six unequal tapered tendrils (one beaded) with
              the lower left empty, a fold, a diagonal tear from 260 ms, four bottom channels,
              three unequal runs whose beads leave at 360 and 400 ms, stains; dark edge on part of
              the lower-right perimeter only; offset mid regions; a small off-centre pale patch
              gone by 230 ms; three short highlight marks. The old splat code and the halo are gone.
              Added the lit close sheet.
     expected: a torn liquid smear instead of a lobed outlined blob; torso visible by 0.4 s
     sheet: r22c, r22g, r22l   score: 7/10   failed: 6 (borderline), 13 on the lit sheet
     result: close view reads as splashed liquid (no closed contour, tendrils thin to 1 px, the
              chest shows at 0.4 s). Opaque area against the 138 ms peak: 36 percent at 322 ms,
              26 at 368, 6 at 506, empty by 782. The sheet is flatter than Astra's 14 to 20 px and
              reads softer at 24 m than r21. The lit sheet shows what the unshaded stage hid since
              r02: the OmniLight sat 0.7 m up on the target's axis at energy 2.5, and lit_sprite
              takes its light on that axis, so the hero gets a blown-out horizontal band and a 2 m
              bloom from 0.03 to 0.5 s.

r23  changed: Light moved under %Body (unique name %Light kept), 0.9 m above the impact point;
              energy 1.8 at 40 ms, 0.9 at 100 ms, 0.45 at 300 ms, 0.3 at 600 ms, 0 at 800 ms;
              range 3.0, attenuation 1.0 (the Anim track path is now Body/Light:light_energy);
              splat lumps spread 1.4 times taller (peak footprint 34 x 21 px)
     expected: on the lit sheet no band, a green tint on the hero from 0.03 to 0.3 s, gone by 0.8 s;
              a fuller splat at 24 m
     sheet: r23c, r23g, r23l   score: 7/10   failed: 6 (borderline)
     result: band and bloom gone; the head and shoulders take the green from 0.03 to 0.3 s and the
              hair is back to its own colour at 0.85 s. The hair over-brightens at 0.03 s and the
              floor spill is faint under the torch. The splat itself is still unshaded.

r24  changed: a lit pixel wrapper, vfx_essential_pixel_lit.gdshader (skill and project): the
              VFX_LIT block in the include takes ALBEDO from the frame, a normal page flipbook,
              lit_sprite's wrapped diffuse (light_wrap 0.35, normal leaning from up to the camera,
              face_camera 0.5) and a hard pixel glint in light(), and emits only texels above
              sRGB luma 0.8. Splat (billboard base, emission 1.6, roughness 0.35) and Puddles (mesh
              base, roughness 0.3) use it. Normal pages splat_n.png and puddles_n.png are written by
              draw_acid_frames.py through the project's tools/art/sprite_normals.py (bevel 3).
     expected: the splat and puddles take the torch: brighter on the torch side, darker away from
              it, glints on the puddles; the core still blooms
     sheet: r24c, r24g, r24l   score: 7/10   failed: 6 (borderline)
     result: on the lit sheet the puddles near the torch turn warm yellow with white pixel glints,
              the far ones stay dark green; the splat core blooms. But under the orange torch the
              green acid turns honey yellow, and the unlit views are a step darker on the splat.

r25  changed: emission_base 0.3 on the lit materials (every texel emits 30 percent of its albedo),
              so the acid keeps its own green; bubbles redrawn as boil-and-pop beads in three sizes
              (3, 5, 7 px) on 12 px cells: rise, swell, a one-frame pale cap, pop into four drops, a
              dark residue; nine of them, 0.25 m below the impact (well below the eyes), with a
              random start offset of up to two lead cells
     expected: green kept beside the torch; discrete reaction points on the runs, none on the head
     sheet: r25c, r25g, r25l   score: 7/10   failed: 6 (borderline)
     result: bubbles sit on the runs at 0.4 to 0.65 s and pop; none near the head. The near
              puddles are still yellow under the torch: the base share is too small against a
              3.5 energy torch at 1.5 m.

r26  changed: emission_base per material (splat 0.45, puddles 0.6); droplets redrawn as thin
              stretched drops (1 to 3 px heads, 1 px tails of 2 to 4 px, three sizes, dark only under
              the largest head), lifetime 0.65 -> 0.45 s, the last life frame one pixel, no dither;
              glass dims to grey at the end instead of dithering out
     expected: green kept beside the torch; streaking drops, none at full size near the floor; no
              checkerboard specks
     sheet: r26c, r26g, r26l   score: 7/10   failed: 6 (borderline)
     result: drops read as thin streaks along their arcs; no checker specks. The nearest puddle is
              still warm yellow beside the torch (kept: a torch that close would warm it).

r27  changed: floor splats redrawn: one solid metaball mass (main lump 6.6 px, four or five more)
              stretched along the throw direction away from the target, a short smear back toward
              it and two or three drops past it; the mass shrinks, then dries to its two or three
              thickest spots; the landing glint is 2x2 (a radius-1.4 disc drew a "+"); no dither
              and no fade on the floor, the frames empty out by themselves
     expected: eight squares read as eight squares at 24 m, not a dotted circle; no straight-edged
              puddle; no checker speck
     sheet: r27c, r27g, r27l   score: 7.5/10   failed: 6 (borderline)
     result: the 0.4 and 0.6 s game tiles show one splat on each neighbour square in a 3 x 3. In the
              sun-lit views the floor is as bright as the acid on the body after 0.5 s.

r28  changed: puddle emission_base 0.6 -> 0.35; Light 0.9 -> 1.3 m above the impact, range 3 -> 4 m,
              energy 2.6 at 40 ms, 1.3 at 100 ms, 0.65 at 300 ms, 0.35 at 600 ms, 0 at 800 ms
     expected: more green on the floor round the feet, less blow-out on the hair, a darker floor
              after 0.5 s
     sheet: r28c, r28g, r28l   score: 7.5/10   failed: 6 (borderline)
     result: measured on the lit sheet (floor patch right of the feet, G minus R; clean frame -47.9):
              -39.0 -> -34.4 at 0.03 s, -29.3 -> -27.4 at 0.15 s; hair mean 156 -> 152 at 0.03 s. Small,
              in the expected direction, kept. The floor change is hard to see by eye.
```

## Rounds, fourth pass (r29 onward, base r28 by the coordinator's override)

```
r29  changed: the splat draws on render layer 5 and the acid light's cull mask skips that layer
              (the light lifted every palette step one level; torches still light the splat);
              splat emission_base 0.45 -> 0.12, core emission 1.6 -> 0.9; frames: 1 px 425A26 edge
              outside every chip on its lower and right sides, a half-alpha 425A26 halo round the
              splat from 46 to 300 ms, the pale impact core cut to 12 to 15 px, two highlight marks
     expected: at 0.07 to 0.15 s a few-pixel white core inside a lime sheet with mid and dark
              patches, the shirt visible round it, no soft disc
     sheet: r29c, r29g, r29l   score: 6.5/10   failed: 3 (weak on the lit sheet), 5 (floor)
     result: as expected in the close view: effect pixels in the chest region (luma bins, against
              r28) mid 12 -> 25 percent and white 43 -> 31 percent at 0.12 s, mid 11 -> 32 at 0.30 s.
              No bloom disc. On the lit sheet the splat is darker and greener away from the torch,
              but its torch side turns yellow-olive, the same fault as the puddles.

r30  changed: the run phase back: three unequal runs (16, 11, 6 px; roots 4, 3, 2 px) from 230 to
              300 ms whose width wanders with a persistent noise and loses single pixels at the
              sides (torn edges); beads leave the tips at 390, 450 and 500 ms and fall inside the
              frame under gravity, each stump shortening 2 px and growing a smaller bead; the runs
              thin from 0.5 s and are gone by 0.72 s (left alone they read as stick figures); the
              coat lingers as torn smears to 0.64 s; bubble emission 1.6 -> 1.1
     expected: at 0.40 and 0.50 s two or three runs down the tunic with beads dropping, as r21 had
     sheet: r30c, r30g, r30l   score: 7/10   failed: 5 (floor)
     result: as expected in the close view; in the game view the green runs on the body show at
              0.40 s.

r31  changed: floor spatters redrawn after r21's floor: a small mass (3 or 4 lumps, main 4.8 px)
              with 4 to 6 unequal arms (the longest, 13 to 16 px, along the throw away from the
              target; about half end in a bead), 4 to 7 scattered specks, a strongly noised edge,
              no drawn highlight; each of the eight sits up to 6 px (0.17 m) off its tile centre at
              a size of 0.75 to 1.15; spatter cell 32 -> 40 px. New `light_desaturate` in the lit
              include (each light's colour mixed toward its luminance in the diffuse; the glint
              keeps the colour): puddles 0.6, puddle glint 1.0 -> 0.5
     expected: torn spatters on the eight squares at 24 m instead of a ring of ovals; puddles green
              under the torch with a warm glint
     sheet: r31c, r31g, r31l   score: 7.5/10   failed: none clear; 3 borderline on the lit sheet
     result: as expected. Lit sheet, floor band, pixels with saturation above 0.4 and value above
              0.35: share in the green hue band (60 to 100 degrees) against lemon (35 to 60), r28 ->
              r31: 64 -> 99 percent at 0.22 s, 47 -> 100 at 0.40 s, 44 -> 100 at 0.65 s. The splat's
              torch side is still yellow-olive.

r32  changed: flash emission 1.6 -> 1.2; splat light_desaturate 0.5
     expected: the dark backdrop stays dark at 0.03 s on the lit sheet; the splat's torch side green
     sheet: r32c, r32g, r32l   score: 7.5/10   failed: none clear
     result: backdrop mean at 0.03 s (left and right of the head above the horizon) 7.5 -> 4.5 of
              255 (r28: 22); the splat is green on its torch side at 0.22 and 0.30 s. The close view is
              unchanged (its sun is white).
```
