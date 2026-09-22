# PolyBlocks EffectBlocks

A Godot 4 VFX asset pack by Bukkbeek (https://bukkbeek.itch.io/effectblocks). Roughly 90
low-poly 3D effect scenes built from `GPUParticles3D`, `MeshInstance3D`, `Decal` and a
handful of custom spatial shaders. No addon, no autoload, no C# and no plugin registration.
Everything is plain scenes plus a few demo scripts.

Local copies:

- v4: `F:/UnityNVME/Art/GodotVFX/EffectBlocks v4/PolyBlocks/EffectBlocks`
- v3: `F:/UnityNVME/Art/GodotVFX/PolyBlocks_EffectBlocks_v3/PolyBlocks/EffectBlocks`
- vendored subset in Eidolarch: `zenith/PolyBlocks/EffectBlocks` (see its `SOURCES.md` for licence notes)

## Folder layout

```
PolyBlocks/EffectBlocks/
  assets/<category>/*.tscn     the effects you actually instance
  scenes/EffectBlocks_demo.tscn  the showcase level
  scenes/other/*.tscn            per-category showcase rooms + camera_controller.gd
  source_files/
    audio/      one wav (small_explosion)
    materials/  shared binary .material and .tres resources
    meshes/     .mesh, .glb and prop scenes used as draw passes
    scripts/    demo driver scripts (see below)
    shaders/    14 .gdshader files
    textures/   sprites, decal textures, icons
```

The `res://PolyBlocks/EffectBlocks/...` path is baked into every scene, so keep the folder
at that path or fix the references yourself. The `.material` files are binary, which makes
path-preserving the easy option.

## How an effect scene is built

Three shapes, and you can tell which one you have by opening the scene root:

1. **Single emitter.** Root is a `GPUParticles3D` (`impacts/impact_4`, `other/dust`,
   `smoke/smoke_heavy`). Sometimes with a script attached.
2. **Composite.** Root is a `Node3D` with named children such as `Fire`, `Sparks`,
   `Smoke`, `Debri`, `Light`, `OmniLight3D` (`explosions/explosion_heavy`,
   `fire/fire_light`, `impacts/impact_1`).
3. **Shader mesh.** Root or child is a `MeshInstance3D` driven by a `ShaderMaterial` and
   engine `TIME` (`ground_effects/ground_effect_1`, `water/water`, `energy/electric_waves`,
   `space/blackhole`).

Ambient effects ship with `emitting = true` and loop forever. Burst effects ship with
`emitting = false`, `one_shot = true` and `explosiveness = 1.0`, and wait to be triggered.

## Playback API (there isn't one)

There is no `play()`, no `finished` signal and no self-cleanup. The scripts in
`source_files/scripts/` are demo drivers, not a runtime API. They either poll
`Input.is_action_just_pressed("ui_accept")` in `_process` or loop on an exported
`auto_animate` / `cooldown` pair. That means an unmodified burst effect replays every time
the player presses Enter or Space, anywhere in your game.

The scripts and what they expose:

| Script | Attached to | Trigger method |
| --- | --- | --- |
| `impacts.gd` | `impacts/impact_1,2,6` | `activate_effects()`, fades an `OmniLight3D` |
| `impact_single.gd` | `impacts/impact_3,4,5,7,8` | `activate_effects()` |
| `explosion_heavy.gd` | `explosions/explosion_heavy`, `explosion_electric` | `explosion()` |
| `explosion_light.gd` | `explosions/explosion_light` | `explosion()`, also plays audio |
| `ground_attack.gd` | all three `attacks/*` | `ground_attack()`, awaits a decal fade |
| `splashes.gd` | all three `splash/*` | `activate_effects()`, fades a decal in |
| `lightning.gd` | `energy/lightning` | `lightining()` (sic) |
| `muzzle_flash_1.gd`, `muzzle_flash_machinegun.gd`, `muzzle_flash_fps.gd` | `muzzle_flash/*` | `muzzle_flash()` / `fire()` |
| `light_flicker.gd` | fire, flamethrower, fireworks | ambient, `@tool`, animates energy/range/position |
| `simple_rotate.gd`, `simple_rotation_angle.gd`, `rune.gd`, `decal_glow.gd`, `worm_hole.gd`, `flying_birds.gd`, `tree_night.gd`, `omni_light.gd`, `env_toggle.gd`, `player_update_water.gd`, `camera_controller.gd` | demo / showcase only | ambient or input-driven |

The practical pattern is to strip the demo script and drive the particles yourself.

## Dropping an effect in and playing it

Minimal one-shot spawn from GDScript:

```gdscript
const IMPACT := preload("res://PolyBlocks/EffectBlocks/assets/impacts/impact_4.tscn")

func spawn_hit(parent: Node3D, at: Vector3) -> void:
    var fx: Node3D = IMPACT.instantiate()
    if fx.get_script() != null:
        fx.set_script(null)          # drop the demo Enter-key driver
    fx.position = at
    parent.add_child(fx)
    _burst(fx)
    get_tree().create_timer(1.2).timeout.connect(fx.queue_free)

func _burst(node: Node) -> void:
    if node is GPUParticles3D:
        node.one_shot = true
        node.preprocess = 0.0
        node.explosiveness = 1.0
        node.restart()
    for child in node.get_children():
        _burst(child)
```

For an ambient effect (fire, dust, fireflies, rain) just instantiate, add as a child and
leave it. Stop it with `emitting = false` and hide shader meshes with `visible = false`,
since shader animation runs off engine `TIME` and ignores `emitting`.

Eidolarch already wraps all of this in `zenith/scripts/ui/effect_blocks.gd`
(`EffectBlocks.make`, `.play`, `.tint`, `.motion`). Reuse that rather than writing a
second wrapper.

## Customising

**Colour.** Set `GPUParticles3D.process_material.color` for the particle tint, and for
mesh draw passes set `albedo_color` / `emission` on each surface material. Shader meshes
use their own uniform names, most often `primary_color` / `secondary_color`
(`portal.gdshader`), `emission_tint` (`gradient_scroll.gdshader`), `lightning_color` /
`glow_color`, `emission_color` (`electric_waves`), `water_color` / `ripple_color`.
Duplicate the material first: `fire_billboard.material`, `smoke_billboard.material`,
`shockwave.material` and friends are shared `ExtResource`s, so editing one in place
recolours every effect that uses it.

**Scale.** Scale the root node. For composite effects that is the `Node3D`; for a bare
`GPUParticles3D` root, note that particles with `local_coords = false` simulate in global
space, so velocities and gravity do not scale with the node. If a scaled burst looks wrong,
either turn on `local_coords` or scale `process_material.scale_min` / `scale_max` and the
velocity fields instead.

**Duration and timing.** `lifetime` sets how long a particle lives, `speed_scale` retimes
the whole system, `explosiveness = 1.0` makes it fire all at once, `preprocess` warms an
ambient system up so it does not start empty, and `fixed_fps` caps simulation rate
(the pack mostly uses 60; lowering it to 30 is an easy cost saving).

**Looping.** `one_shot = false` plus `emitting = true` loops. `one_shot = true` plus
`restart()` gives a single burst. `emitting = false` stops new particles but lets the
current ones finish.

**Visibility.** Several effects move particles well outside the node's default AABB. If an
effect vanishes at certain camera angles, set `visibility_aabb` explicitly.

## Shader uniforms

| Shader | Notable uniforms |
| --- | --- |
| `gradient_scroll` | `gradient_texture`, `flow_speed`, `emission_strength`, `emission_tint` |
| `portal` | `portal_texture`, `primary_color`, `secondary_color`, `outer_color`, `scale`, `rotation_speed`, `inner_transparency`, `glow_margin`, `emission_strength` |
| `lightning` | `lightning_color`, `glow_color`, `intensity`, `noise_scale`, `thickness`, `jitter`, `speed`, `flicker_*`, `y_billboard` |
| `electric_waves` | `noise`, `time_scale`, `scale`, `emission_color`, `emission_strength` |
| `blackhole` | `transparency_mask`, `emission_mask`, `portal_texture`, `rotation_speed`, `emission_strength` |
| `shockwave` | `screen_texture` (hint_screen_texture), `distortion_intensity`, `noise_influence` |
| `water` | `water_color`, `ripple_color`, `wave_strength`, `wave_speed`, `foam_distance`, `depth_texture` |
| `water_distortion` | `screen_texture`, `noise_texture`, `distortion_intensity`, `scroll_speed` |
| `god_rays` | `windNoise`, `tint_color`, `alpha_factor`, `hGradient`, `vGradient` |
| `hologram` | `hologram_color`, `scan_line_speed`, `rim_light_strength`, `noise_strength` |
| `scifi_shield` | `density`, `line_width`, `hex_line_color`, `rim_color`, `rim_power` |
| `stylized_assets` | `tint`, `texture_albedo`, `emission_texture`, `fresnel_*` (props, not effects) |
| `vegetation`, `vegetation_sway` | `windSpeed`, `windStrength`, `nightTime` (demo trees) |

## Catalog

### attacks (3)
- `attack_crystal`: one-shot ground burst of crystal spikes plus sparks and a glowing crack decal.
- `attack_earth`: same burst with rock spike meshes.
- `attack_fire`: same burst plus a looping flame/smoke/ember cluster on top.

### decals (17)
Static `Decal` nodes, one texture each, no animation unless noted.
`decal_blood_spalsh_1`, `decal_blood_splash_2`, `decal_bullet_hole_1/2/3`,
`decal_claw_mark_1`, `decal_crack_1/2/3`, `decal_footprint_1/2`, `decal_handprint_1/2`,
`decal_slime_1/2`, `decal_tire_skid_1`. `decal_crack_4` is crack 1 with `decal_glow.gd`
pulsing `emission_energy`.

### energy (7)
- `electric_sparks_1`: looping spark streaks, 16 particles, unshaded white.
- `electric_sparks_2`: explosive one-burst variant of the same streaks.
- `electric_sparks_3`: looping quad sparks, softer spread.
- `electric_waves`: single shader mesh, scrolling additive noise bands, loops.
- `laser`: beam mesh plus torus buds, glow mesh, emitter mesh and sparks, loops.
- `lightning`: two one-shot bolt emitters using `lightning.mesh`, driven by `lightning.gd`.
- `lightning_ball`: small looping orb of bolts with `electric_sparks_1` nested inside.

### explosions (3)
- `explosion_light`: small one-shot fire/sparks/smoke plus `small_explosion.wav`.
- `explosion_heavy`: fire, sparks, smoke, debris and 200 trailed debris-smoke particles, one-shot.
- `explosion_electric`: heavy explosion recoloured, fire pass uses the lightning shader.

### fire (4)
- `fire_light`: looping flame, smoke and embers plus a flickering `OmniLight3D`. 64/64/32 particles.
- `fire_heavy`: same build at 128/128/64 with longer lifetimes.
- `fire_magic`: same build with a stylised magic flame mesh and coloured sparks.
- `fireballs`: looping emitter that launches fireballs, each with a 600-particle trailed flame and smoke burst.

### ground_effects (2)
- `ground_effect_1`: flat disc mesh with the scrolling gradient shader, loops. Used as a base under most loot pickups.
- `ground_effect_2`: wider, softer variant of the same disc.

### impacts (8)
All one-shot.
- `impact_1`: sparkle plus expanding circle flash with a fading light.
- `impact_2`: sword icon flash plus 16 radial spark shards and a light.
- `impact_3`: 16-shard debris burst, single emitter.
- `impact_4`: 16-shard spark burst, slightly softer spread. Single emitter.
- `impact_5`: four sparkle quads with staggered emission.
- `impact_6`: explosion sprite flash plus circle flash and a light.
- `impact_7`: four star quads popping outward.
- `impact_8`: four skull quads drifting out.

### loot (17)
Pickup markers. Most are a `ground_effect_1` disc plus a floating icon and a looping
sparkle emitter, and most loop forever.
- `ammo`, `gun`, `swords`, `potion`: rotating icon mesh over a glowing disc.
- `loot_axe`, `loot_gun`, `loot_pickaxe`: icon sprite inside a rising cylinder beam with sparkles.
- `money`: coin mesh particles fountaining over a disc.
- `healing`: disc, rotating rune decal, rising cross sprites and sparkles.
- `power_up`: disc plus three rising power-up sprites and sparkles.
- `down_arrow`: disc plus a single bobbing arrow sprite.
- `eyes`, `skull`, `pheonix`, `plague_doctor`, `flowers`, `gears`: disc plus the named icon
  sprite and sparkles; `gears` uses an `AnimatedSprite3D`.

### muzzle_flash (4)
- `muzzle_flash_1`: two animated flash sprites, light, one-shot smoke, sparks and a bullet shell.
- `muzzle_flash_machinegun`: the same, held down while `ui_select` is pressed.
- `muzzle_flash_fps`: flash mesh for a first-person weapon, with cooldown.
- `flamethrower`: continuous 256-particle flame cone with smoke, sparks and three flickering lights.

### other (15)
- `coin_emitter`: looping fountain of coin meshes.
- `dust`: 16 slow drifting smoke billboards, loops.
- `dust_ring`: one-shot expanding ring of dust puffs.
- `falling_leaves`: 32 leaves, 8 second lifetime, loops.
- `fireflies`: 24 slow glowing motes, loops.
- `fireworks`: launcher plus one-shot burst, debris and two 600-particle smoke trails, with a flickering light.
- `flying_birds`: four bird meshes flapping via blend shapes and circling on a scripted path.
- `god_rays`: two shader quads for volumetric light shafts, loops.
- `heatwaves`: six rising torus meshes with the screen-distortion shader, loops.
- `portal_magic`: eight spark emitters around a shader portal disc plus a light, loops.
- `portal_fire`: single fire-coloured shader portal disc plus a light, loops.
- `rain`: 128 raindrops, 400 impact splashes and a `GPUParticlesCollisionBox3D`, loops.
- `shockwave`: one expanding distorted torus, 0.74s.
- `sparkles`: two-pass sparkle quads, loops.
- `tonardo` (sic): tornado meshes with an `AnimationPlayer`, three smoke rings, lightning and sparks.

### smoke (3)
- `smoke_light`: 64 soft puffs rising, loops.
- `smoke_heavy`: 640 billboards, dense column, loops.
- `smoke_toxic`: 64 green-tinted billboards, loops.

### space (4)
- `asteroid_field`: 32 drifting debris meshes looping, plus a one-shot scattered burst.
- `blackhole`: seven nested shader meshes (accretion spheres, event horizon, singularity, distortion).
- `stars`: two-pass twinkling star quads, loops. New in v4.
- `worm_hole`: inner and outer tunnel meshes with scrolling UVs, plus 64 sparks.

### splash (3)
One-shot, each fires 32 droplets then fades in a matching decal and a brief light.
- `blood_splash`, `slime_splash_1`, `slime_splash_2`.

### water (3)
- `water`: a shader plane with waves, foam, depth fade and screen distortion.
- `water_foam`: short foam burst emitter.
- `water_foam_long`: the same with 16 particles and a wider spread.

## Gotchas and dependencies

- **Godot version.** The pack's `project.godot` declares `config/features=("4.6",
  "Forward Plus")`. Most scenes are `format=4` (Godot 4.4+), and fourteen v4 files use the
  `unique_id=` node attribute and omit `load_steps`, which is Godot 4.6 syntax. Older
  editors will fail to open at least those files.
- **Renderer.** `shockwave.gdshader` and `water_distortion.gdshader` use
  `hint_screen_texture`, `water.gdshader` uses `hint_depth_texture`, and the decals are
  `Decal` nodes. Forward+ (or Mobile for most of it). The Compatibility renderer will not
  render these correctly.
- **Glow.** Emission energies run as high as 16 and the demo `Environment.tres` has glow
  and volumetric fog on. Without glow in your own `WorldEnvironment` many effects look flat.
- **Demo input actions.** `camera_controller.gd` and `env_toggle.gd` reference custom
  actions `w`, `a`, `s`, `d`, `q`, `e`, `f`, `shift`. The effect scripts use `ui_accept`
  and `ui_select`. If you copy a showcase scene without those actions you get runtime
  errors; if you keep `ui_accept`, pressing Enter replays effects in your game.
- **`omni_light.gd` declares `class_name controlled_light`**, which registers a global class
  name across your whole project. Rename or delete it if that clashes.
- **Shared materials.** `source_files/materials/*.material` are binary resources shared by
  many scenes. Duplicate before tinting, and keep the `res://PolyBlocks/EffectBlocks/`
  path so the binary references resolve.
- **Shader animation ignores `emitting`.** Portals, water, blackhole and the ground discs
  run on engine `TIME`. For a reduced-motion or pause mode you have to hide them.
- **Cost.** `smoke_heavy` (640), `fireballs` and `fireworks` (600-particle trailed passes)
  and `rain` (528 across two emitters) are the expensive ones.
- **No cleanup.** Nothing frees itself. Own the lifetime yourself.
- **Stray files in v4.** `scenes/` contains four editor temp files (`ene4DB6.tmp` and
  friends) and `source_files/meshes/` has two `.mesh.depren` leftovers. Harmless, but do
  not copy them into a project.

## v3 vs v4

v4 is a small content update, not a rework. Almost every file that `diff -rq` reports as
different is only a CRLF/LF line-ending change; comparing with `--strip-trailing-cr` leaves
a short list.

Added in v4:
- `assets/loot/flowers.tscn`
- `assets/loot/plague_doctor.tscn`
- `assets/space/stars.tscn`
- `assets/other/portal_fire.tscn`
- `source_files/scripts/omni_light.gd` (curve-driven light, used by the demo scene)

Renamed: `assets/other/portal.tscn` became `assets/other/portal_magic.tscn`. The contents
are byte-identical, but the UID and the file path changed, so any v3 reference to
`portal.tscn` breaks.

Changed content:
- `attacks/attack_crystal`, `attack_earth`, `attack_fire`: extra curve points on the spike
  scale curve and new `curve_x` / `curve_y` offset curves, so the spikes animate differently.
- `loot/pheonix`, `loot/skull`: the root node's +0.5 Y offset was removed and pushed down
  into the children, so the effect now sits on the origin instead of half a unit above it.
- `scenes/other/camera_controller.gd`: demo camera clamp widened (x max 80 to 60, z max 15 to 20).
- Several showcase scenes and `EffectBlocks_demo.tscn` rearranged for the new entries.
- `crowmask.png.import` and `flower.png.import` switched to VRAM-compressed (s3tc_bptc)
  with mipmaps. The textures themselves are unchanged and were already present in v3.

No files were removed, no shaders changed, and no runtime script behaviour changed apart
from the demo camera.

**Which version Eidolarch has:** v4. Every vendored `.tscn`, `.gd`, `.material` and
`.gdshader` under `zenith/PolyBlocks/EffectBlocks` is byte-identical to v4. Seven of those
eight scenes are also identical in v3; the deciding file is `other/portal_magic.tscn`,
which only exists under that name in v4. The three `.import` files differ from both
packages because Godot regenerated them for this project.
