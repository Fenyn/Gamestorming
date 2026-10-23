# Death dust: round log

Effect: a slain creature (`CreatureDied`) breaks into its own pixels from the feet up, a one-texel
ember edge at the front, and the pixels drift away as ash. It replaces `DeathPoof`. The brief is
`%TEMP%\vfx_studio\ungilded\death_dust\brief.md` and the sheets are in
`%TEMP%\vfx_studio\ungilded\death_dust\rNN{c,g,l}\sheet.png` (close, game, lit).

## Files

- `build_death_dust.gd` writes `res://scenes/fx/death_dust.tscn`. It reads the rat frame
  (`assets/sprites/enemies/rat_v1/idle_1.png`) with `Image.load_from_file` (headless, a texture's
  `get_image()` comes back empty) and the token's lit material from `billboard_sprite.tscn`.
- `res://assets/shaders/lit_sprite.gdshader`: the erosion (`death_progress` and the `death_*`
  uniforms). The look values (`death_mix`, `death_cell`, `death_edge`, `death_edge_energy`) are set on
  the Lit material in `res://scenes/combat/billboard_sprite.tscn`.
- `res://assets/fx/death_dust/dust_pixel.gdshader`: the dust square (lit, born ember, cools to ash).
- The erosion threshold exists three times and must stay the same: `erosion_threshold` in the
  shader, `SpriteErosion.Threshold` in C#, `_threshold` here.

## Commands (same every round)

```
W=%TEMP%/vfx_studio/ungilded/death_dust
powershell -File $W/round.ps1 -Round rNN        # build, audit, close, game and lit captures
```

`round.ps1` runs, one Godot process at a time:

```
G=G:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64_console.exe
S=C:/Users/Midge/.claude/skills/vfx-studio
$G --log-file $W/build.log --path . --headless -s res://tools/vfx/death_dust/build_death_dust.gd
$G --log-file $W/audit.log --path . --headless -s $S/scripts/audit_effect.gd -- --scene=res://scenes/fx/death_dust.tscn --length=1.3 --particles=450 --lights=0
SCENE="--scene=res://scenes/fx/death_dust.tscn --strip-script=1 --orient=Body"
# close, neutral stage
$G --log-file $W/cap_c.log --path . --fixed-fps 60 --position -4000,-4000 -s $W/tools/capture_sheet_dd.gd -- $SCENE --out=$W/rNNc --label=rNNc --cam=1.5,0.9,1.5 --look=0,0.35,0 --fov=40 --times=0.033,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.85,1.0,1.15,1.3 --warmup=1.3
# game view, sewer look
$G --log-file $W/cap_g.log --path . --fixed-fps 60 --position -4000,-4000 -s $W/tools/capture_sheet_dd.gd -- $SCENE --out=$W/rNNg --label=rNNg --cam=10.9,18.4,10.9 --look=0,0.35,0 --fov=22 --tile=600 --cols=3 --times=0.033,0.15,0.3,0.45,0.6,0.75,0.9,1.1,1.3 --warmup=1.3 --env=res://scenes/looks/sewer.tscn
# lit view: the close camera, --lit=1 and the sewer look
$G --log-file $W/cap_l.log --path . --fixed-fps 60 --position -4000,-4000 -s $W/tools/capture_sheet_dd.gd -- $SCENE --out=$W/rNNl --label=rNNl <close options> --lit=1 --env=res://scenes/looks/sewer.tscn
```

No `--prop`: the scene's own `%Preview` is the stand-in, the rat at its in-game PixelSize 0.02 m
(not the 0.028 m the other effects' stand-ins use), drawn with the token's lit material and eroded
by `%Anim`. A `--prop` rat at the origin would stand whole over it.

## Tool notes

- `$W/tools/capture_sheet_dd.gd` is a copy of the skill's `capture_sheet.gd` with one option added:
  `--orient=<name>` turns the effect's node of that name to the camera's basis after instancing, as
  `DeathDust.cs` turns `%Body` in the game. The emission points lie in the sprite's billboard plane,
  so without it the dust would form a foreshortened rat beside the stand-in. The shared script is
  unchanged.
- `--log-file` must come before the script's own `--` arguments, or Godot hands it to the script
  and writes no log (the first r01 audit read was a stale log for this reason).
- The audit's travel estimate adds the default sphere radius and box extents, which a points
  emitter never uses; it warned about the visibility box at 3.2 m of travel for 0.4 m of real drift.
- The bands share one draw material and one render priority; the audit's shared-priority warnings
  are expected (one layer split in time).

## Hook (DeathDust : OneShotFx, integrated 2026-10-22)

- Scene `res://scenes/fx/death_dust.tscn`, root `Node3D` named DeathDust, with
  `res://scripts/fx/DeathDust.cs` attached by this build script when the file exists.
- Unique names: `%Ground` (empty), `%Body` (at the sprite's centre; holds `%Dust0` .. `%Dust5`),
  `%Preview` (the stand-in rat; hidden in the game), `%Anim` (AnimationPlayer, animation `play`,
  0.6 s: the preview's `death_progress` 0 to 1, the preview's 0.1 mm frame nudges, and
  `Body/DustK:speed_scale` 0 until K x 0.1 s, then 1). `DeathDust.Bands` names the six emitters;
  change it with `BANDS` here.
- Emitters ship with `emitting = false`; bands 1 to 5 also ship with `speed_scale = 0`, so a restart
  emits nothing until `%Anim` reaches the band's slice. The capture restarts every emitter at t = 0,
  and the speed_scale hold works there too. An `emitting` key would not: after a restart the
  one-shot's phase keeps running while emission is off, and the slots it passed are lost.
- Each band: `one_shot`, lifetime 0.65 s (randomness 0.45), explosiveness 0.846 (it emits over its
  0.1 s slice), `local_coords = false`, Z billboard, layers 2 (the sprite layer, which the
  spectacles glow skips), no shadow. ParticleProcessMaterial: `EMISSION_SHAPE_POINTS`, launch
  1.2..2.4 m/s up and right in Body space (spread 40), capped to 0.9 m/s by a quarter of the life
  (`velocity_limit_curve`), gravity 0.7 up plus 1.5 along the camera's right, weak turbulence
  (influence 0.01..0.04), alpha held to 0.45 of the life. Draw pass: a 0.02 m QuadMesh with
  `dust_pixel.gdshader`: born as pure glow (the edge's FFB871 at 0.64, read from the token's
  material, over a black albedo) cooling to the texel's colour over 0.15 of the life, then toward
  ash 4A403A, 85 percent by 0.7 of the life.
- The edge on the sprite: FFB871 at 0.64 over a black albedo, which the sewer look's Filmic at
  exposure 1.4 shows as FAD08A (the brief's FFD08A). Glow added to the lit colour went cream at any
  energy that showed (r06 to r09).
- The presenter (`GodotPresenter3D.Disintegrate`) handles `CreatureDied` for a creature
  (`UnitVisual3D.Disintegrates`, false for heroes): it instances the dust, calls
  `UnitVisual3D.Disintegrate(dust.SweepSeconds)`, sets the returned `SpriteErosion` on the dust,
  spawns it at the unit's feet under the popup layer and holds the beat for `SweepSeconds` (0.6 s),
  unpaced. The old gate was 0.3 s; heroes keep it with the corpse tint.
- `UnitVisual3D.Disintegrate` retires the bar, badge, plate, ring, blob shadow, crystal and picking
  as before, resets the tint, calls `BillboardSpriteAnimator.BeginErosion` (`DeathSweep`
  `Vector2.Down`, a random seed), tweens `ErosionProgress` 0 to 1 over the sweep while nudging the
  sprite 0.1 mm on alternate frames (`ShadowNudgeMetres`), and hides the sprite at the end.
  `BeginErosion` freezes the frame, reads it (from the source PNG when the renderer cannot hand the
  page back, headless), sets the shader's `death_*` uniforms and hides the see-through outline.
- `DeathDust.Build` hides `%Preview`, puts `%Body` at the sprite's centre facing the camera (and
  keeps it facing in `_Process`), sorts the frame's opaque texels into the six bands by
  `SpriteErosion.Threshold` (2x2 blocks above `MaxParticles`, 1200), fills each band's point
  (RGBF, metres in Body space, flipped with the sprite) and colour (RGBA8, texel times the sprite's
  tint) textures on a copy of its process material, scales the square to the sprite's pixel size,
  turns the wind to the game camera's right, restarts the bands and plays `%Anim`. `Lifetime` 1.3 s.
- `CombatScene.StartEncounter` preloads the scene (`FxLibrary.PreloadEncounterEffects`).

## Known limits

- The sheets use the grey grid stage and the lit stage; the in-game check is the two prologue_run
  shots of one rat (above). Not seen in game: the Tyrant's 0.046 m squares, a kill behind a pillar,
  a camera turned mid-sweep.
- The wind always blows to screen right. It does not follow the killer or the creature's facing.
- The edge and the dust ember are one colour for every kill. A typed kill could tint them with
  `DamageColors` (the edge from the token's material, the ember from the dust's draw material,
  which every dust shares, so a per-kill colour needs a per-instance copy).
- The threshold is computed three times (shader, C#, GDScript). The C# and the shader can differ
  by a float rounding at a band boundary, which moves one texel's dust by one band (0.1 s).
- A camera turned during the 0.6 s sweep turns the body and the dust still to come; dust already
  out keeps its place.
- Big bodies (over 1200 opaque texels) send one particle per 2x2 block, never tried on a sheet.

## Rounds

```
r01  first build: erosion bottom up (mix 0.65/0.25/0.1, cell 4), six bands over a 0.6 s sweep,
     dust 0.15..0.45 m/s, damping 0.4..0.8, rise 0.6, ember energy 2, edge energy 2
     fix during r01: thresholds bunched in 0.17..0.83, so the body was gone at 70 % of the sweep;
     added death_range (the frame's lowest and highest sum map to 0 and 1). Bands 37/93/106/154/52/5.
     cold read: a rat turns into glowing pixels from the feet up; the pixels hang in its shape and fade
     sheet: $W/r01c, r01g, r01l   score: 5/10   failed: 8, 13, 15, and the lit view keeps the rat's
     whole torch shadow to 1.3 s (omni shadows are cached; a uniform change does not re-render them)
r02  changed: %Preview moves 0.1 mm on alternate frames of the sweep (NUDGE); dust 0.35..0.9 m/s,
     damping 0.8..1.4, rise 0.8, turbulence influence 0.1..0.25; ember energy 2 -> 0.9, life 0.2 -> 0.12;
     edge energy 2 -> 1.2
     expected: the torch shadow erodes with the body; dust clears the body by 0.4 s; no bloom blob at 0.3 s
     result: the shadow erodes and is gone at 0.6 s. The bloom blob is smaller. The dust does not move.
     sheet: $W/r02*   score: 5/10   failed: 8, 13, 15
dbg1 debug build only (reverted): 3 m/s, no damping. The pixels moved a quarter of the expected
     distance in random directions. Cause: Godot's turbulence turns each particle's velocity toward the
     noise field by the influence share every frame, and in r02 the damping (above the rise) stopped
     every particle.
r03  changed: turbulence influence 0.1..0.25 -> 0.01..0.04, damping 0.3..0.6 (under the pull),
     speed 0.4..1.0, wind 0.5 m/s^2 along the camera's right; newborn pixels keep their own albedo and
     only add the ember as emission
     expected: dust drifts up and right off the body; newborn specks warm, not white
     result: the dust drifts, but most pixels are young at any moment, so the cloud keeps the rat's
     shape and slides as one mass
     sheet: $W/r03*   score: 6/10   failed: 2, 8, 15
r04  changed: launch 0.8..1.6 m/s capped to 0.45 m/s by a quarter of the life (velocity_limit_curve),
     no damping; lifetime randomness 0.3 -> 0.45
     expected: a scattered cloud above and right of the body at 0.5 s
     result: a little more spread; still a dotted rat. The bottom-up sweep sends the dust up across the
     body still standing, so loose pixels always lie over it
     sheet: $W/r04*   score: 6/10   failed: 2, 8, 15
r05  changed: sweep top-down (the back goes first); launch 1.2..2.4 m/s; wind 1.0
     expected: by 0.3 s the dust sits above the remaining lower half, not over it
     cold read: a rat breaks apart from the back down, its pixels lift off glowing and drift up and
     right; the feet go last
     result: reads as the event. The front is a white band at 0.3 to 0.4 s in the lit view.
     sheet: $W/r05*   score: 7/10   failed: 13, 15 (the game view is a small glitter puff)
     decision: top-down is the sweep (the brief left bottom-up or the hit side to the sheets)
r06  changed: the edge glows only within death_edge_lead 0.1 of the progress; ember energy 0.9 -> 0.7
     expected: a thin broken line at the front; specks pale orange
     result: about 1,000 pixels per tile differ from r05; the white band stays. Ember energy reverted in r07.
     sheet: $W/r06*   score: 7/10   failed: 13
r07  changed: edge texels keep their albedo and add the ember as emission (energy 1.5); ember energy back
     to 0.9, ember life 0.12 -> 0.06
     result: no visible change in the band. A 3x crop shows the white squares sit on the sprite's texel
     grid: they are edge texels, not dust.
     sheet: $W/r07*   score: 7/10   failed: 13
r08  changed: edge energy 1.5 -> 0.6; death_mix 0.65/0.25/0.1 -> 0.65/0.3/0.05 (fewer lone texels)
     result: still cream. dbg2 (edge energy 0, reverted) removed the band: an emission of 0.6 times
     FFD08A on the lit brown, times exposure 1.4, pushes red past 1 and Filmic turns it cream.
     sheet: $W/r08*   score: 7/10   failed: 13
r09  changed: edge energy 0.6 -> 0.3; ember energy 0.9 -> 0.35
     expected: the front light orange, newborn specks orange-tinted
     cold read: a rat crumbles from the back down along a pale warm line; its pixels lift off and drift up
     and right as a thinning cloud; the feet go last; nothing is left at 1.15 s
     sheet: $W/r09c, r09g, r09l   score: 8/10   failed: 8 (an even spray more than drifting streams),
     15 partly (subtle at 1x in the game view)
blind A/B 1 (opus, $W/review1, A = r09, B = r08, tile labels redrawn without round names):
     B (r08) 7/10, A (r09) 5/10. A fails gate 3: its tan edge (C9B099 close, luminance 180) is darker than
     the rat's pink tail (205), so it reads as paint, not glow. B's edge is legible but cream (E8D1AF,
     peaks FFFFD1 with R and G clipped in the lit view). Both: the dust centroid moves 0.18 m in a
     second, only 7 ember pixels at 0.60, never cools to ash, white tooth squares are the brightest
     dust; a one-texel foot strip lingers about 100 ms at 0.40 to 0.50.
     r09 lost and is reverted (edge 0.6, ember 0.9); r10 builds on r08 with the reviewer's two changes.
r10  changed (from r08):
     1. glow is emission over a black albedo, on the edge texels and on newborn dust; colour FFB871 at
        0.64, which shows as FAD08A through Filmic at exposure 1.4 (computed with Godot's filmic curve);
        the dust's ember energy is read from the token's material
     2. cooling: ember life 0.06 -> 0.15, ash share 0.6 -> 0.85 over 0.15..0.7 of the life
     3. drift: speed cap 0.45 -> 0.9 m/s, wind 1.0 -> 1.5
     expected: a gold front, not cream; gold specks at birth, dark ash late; the cloud about 0.5 m
     downwind by 0.85 s
     result: the front and the newborn pixels are gold in the lit view and orange-gold on the neutral
     stage; the cloud spreads further and darkens from 0.6 s; nothing left at 1.15 s
     sheet: $W/r10c, r10g, r10l   score: 8/10   failed: 8 partly (the dust is still a broad cloud, not
     streams), 15 partly (subtle at 1x)
blind A/B 2 (opus, $W/review2, A = r08, B = r10): B (r10) 7/10, A (r08) 6/10. B's edge in the lit view
     is FED187 (the brief's FFD08A), amber at game distance (E7B670), and its dust starts amber and
     cools toward ash (mean 524746 at 1.00 against 4A403A). A's edge goes pale toward white, its dust
     never shows the ember-to-ash change and hangs over the body. r10 kept; it is the delivered round.
     Its two notes for B, left open (round limit 10 reached): at 0.10 s only 3 percent of the body is
     gone, so bring the first break forward (10 to 15 percent, a continuous amber rim on the tail and
     spine) and flatten 0.20 to 0.40; and a steady wind from 0.40 s, so the dust is a thinning trail
     about 0.5 m downwind by 0.85 s instead of a speckle cloud over the body.
```

## In game (rendered prologue_run, 2026-10-22)

- `dev_shots/death_dust.png` (0.308 s after the first Encounter 1 death, the Player's hit on Rat A)
  and `death_dust_late.png` (0.808 s). At 0.31 s the back has broken into texel clusters along a pale
  gold edge, the head and tail are still whole, and gold and pink specks rise above; the edge reads
  under the sewer look. At 0.81 s the body is gone and a few dark ash specks drift to the right;
  nothing else is left (no outline, no shadow).
- Every death sends one dust: 1 in E1, 2 in E2, 5 in E3, 3 in E4 (two Dire Sewer Rats and the
  Tyrant); 423 to 478 particles each, six bands each; each lived 1.30 to 1.31 s. The spawn frame ran
  25 to 35 ms and the next three frames at most 38 ms.
- One E2 body (the second rat, whose death ends the encounter) read 0.861 and visible at the end of
  its sweep, then 1.000 and hidden 0.5 s later. A 137 ms frame (a capture) fell in its window; the
  dust and the spike's clock counted it and the token's tween did not. Which node stopped processing
  for that frame is not found. The check now reads the body after the sweep plus the window's
  longest frame, and again 0.5 s later.
