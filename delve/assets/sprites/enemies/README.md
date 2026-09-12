# Enemy sprite resources

Each mapped folder contains `sprite.tres`, an `EnemySpriteDefinition` with an editable Godot `SpriteFrames` library. The renderer does not enumerate numbered PNGs or assume a frame count, clip name, or playback speed.

- `Frames`: named animations, textures (including atlas textures), relative frame durations, FPS, and looping.
- `IdleAnimation`: required name of the default clip.
- `MoveAnimation`: optional locomotion clip; absent/empty clips fall back to the authored idle.
- `AttackAnimation`: optional non-looping strike clip. Absent clips retain the lunge fallback.
- `AttackImpactFrame`: zero-based contact frame. Its delay derives from preceding frame durations and clip FPS.
- `AttackEffect`: optional `AttackAccent` scene, spawned at contact on hits and misses. Goblin/kobold use `attack_swipe.tscn`; wolf uses `attack_bite.tscn`. Color, lifetime, height, and reach are editable on those scenes. Damage sparks remain separate and hit-only.
- `PixelSize`: world units per source pixel.
- `FootMarginPixels`: distance from the frame bottom to the feet. Keep a consistent foot anchor across frames.
- `GroundAnchorX`: ground-contact center measured from the unflipped frame left edge; negative uses canvas center. The renderer mirrors this anchor with the sprite. Use it to keep long tails or asymmetric padding from shifting feet away from the token.
- `FacesRight`: facing direction of the source art.

The renderer can play authored clips through `PlayEnemyAnimation(name)`. Generic non-looping clips hold their final frame. `PlayAttack(out impactDelay)` plays the configured strike, protects it from movement changes, and returns to idle or movement after recovery. The presenter waits until its contact frame for hit effects. Frozen sprites hold their pose. A new strike restarts the wind-up.

Rats use eight-frame idles at 4.5 FPS (1.78 seconds per loop); missing-art placeholders retain 6 FPS. Goblin loops take 2 seconds, kobold 1.875 seconds, and wolf 2.25 seconds. Goblin, kobold, and wolf bases each have five timed frames in a looping `rest` clip (breathing and a brief blink). Goblin Warrior/Commando/War Chanter share the goblin base; Kobold Warrior/Scout share the kobold base; Wolf uses the wolf base. Outfits are not enabled. Dire Wolf has a separate larger base and articulated bite.

Add a new sprite by authoring a definition and adding its folder in `EnemySpriteMap`. PNG filenames are arbitrary because the `SpriteFrames` resource references them explicitly. Edit the resource in Godot to add clips or vary durations. No renderer code change is needed.

`python tools/export_enemy_bases.py` refreshes approved bases and rest clips from idle timing manifests, preserving other clips and placement. `python tools/export_enemy_attacks.py` refreshes attack frames and contact metadata, preserving rest and placement. Build attack masters first with Aseprite `--batch --script tools/build_enemy_attacks.lua`. Goblin and kobold use unarmed strikes; wolf uses a bite. Each has six frames over 0.58 seconds, with contact at 0.18 seconds. The native masters retain anatomical layers for later gear work.

For visual inspection, open `res://scenes/dev/enemy_sprite_preview.tscn` and press F6. It starts a playable combat encounter with all 12 species bases: rat, goblin, kobold, wolf, viper, hunting spider, boar, Giant Viper, Giant Monitor Lizard, Dire Wolf, Grizzly Bear and Giant Stag Beetle. Its initiative seed starts on Aldric's turn so the creatures wait while you inspect them. `enemy_sprite_shot_spike.tscn` captures the encounter and a close-up, checking 12 creatures and 11 authored attacks. `enemy_sprite_spike.tscn` checks playback, timing, freezing, placement, and mapping.
# Viper addition

`viper_base/sprite.tres` supplies the regular Viper's two-second idle and 0.58-second bite (contact at 0.18 seconds). Its separate bite-effect scene tunes reach and height for the raised snake head. Native layered masters and previews live in `design/viper-base`; rebuild them with Aseprite `tools/build_viper.lua`, then use the base and attack exporters below. Giant Viper uses its own thicker coil and bite in `giant_viper_base`.

## Complete Fringe roster

The full enemy preview uses three-tile spacing on the enemy side of the generated board. Pan, orbit and zoom the camera to inspect each creature. `PreviewEnemySpacing` is a dev-scene setting; normal encounters retain their deployment rules.

All 15 Fringe creatures have sprite mappings. Five separate bases cover Giant Viper, Giant Monitor Lizard, Dire Wolf, Grizzly Bear and Giant Stag Beetle. Their design directories use hyphens (`design/giant-viper-base`); runtime folders use underscores (`giant_viper_base`). `tools/enemy_sprite_sources.py` is the shared export list.

Each new creature has a layered base, idle and attack master, PNG frames, timing manifests and visual review material in its design directory. Rebuild with its matching `tools/build_<creature>.lua`, then run both enemy exporters. All five retain a four-pixel foot margin. The monitor uses PixelSize 0.018 and GroundAnchorX 80.5; the beetle uses 0.025 and 42.5. The other three use 0.02 and centered canvases. These are reviewed world placements; native art stays intact.

Use `scenes/dev/fringe_sprite_preview.tscn` for these five creatures in combat. `fringe_sprite_shot_spike.tscn` captures their group and individual idle/contact poses. Set `DELVE_SHOT_DIRECTORY` to save the captures in a chosen directory. The individual reviews and browser comparison are in `design/fringe-sprite-review`.

## Creature footprints

The rules engine supplies `TileWidth`: Medium/Small occupy 1x1, Large 2x2, Huge 3x3, and Gargantuan at least 4x4 ([Player Core](https://2e.aonprd.com/Rules.aspx?ID=2359)). Monster Core classifies Giant Monitor Lizard as Medium, and Dire Wolf, Grizzly Bear and Giant Stag Beetle as Large. Sprite canvas dimensions do not determine rules size.

The logical footprint stays at the engine anchor. The drawn body stands at the lowest occupied tile-center elevation and favors the center of the low supporting tiles. This presentation offset does not change reach, facing or target tiles. Spawning and movement use the same body placement. Deployment reserves every occupied tile and repairs overlap, walls and board-edge placements. Creature-targeted strikes, spells and skills highlight and accept every occupied tile. The ground marker outlines and lightly fills each occupied tile at its own terrain height, including raised tiles. It stays on the board during body lunges and pulses in brightness during the active turn. Markers hide during movement and return at the occupied destination. Normal terrain occlusion is retained.

The grounded visual prototype is enabled in `enemy_sprite_preview.tscn`. `enemy_grounding_shot_spike.tscn` captures all 12 species individually; the stepped-ground bear comparison is in `design/fringe-sprite-review/grounded-prototype/`. This is a presentation convention requested for Delve, not a claim of a specific PF2e uneven-footprint formula.

## Occluded-body silhouette

Token sprites now show a faint silhouette only where opaque geometry hides the body. It follows current animation frames, flipping and body alpha. The shared look is authored on the Silhouette material in `scenes/combat/billboard_sprite.tscn`. Run `creature_silhouette_spike.tscn` with a renderer for pixel-comparison checks. Latest bear captures: `design/fringe-sprite-review/silhouette/`.
