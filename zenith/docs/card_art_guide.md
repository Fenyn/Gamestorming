# School card art guide

How to make school card art (Strike, Art, Combat, Drill, Non-Combat, Mastery). Worked out on Tide Torrent (`tide_art_04`) over about fifteen review cycles on 2026-09-25. Portraits have their own guide, `portrait_guide.md`. The history of what was tried is in `card_art_notes.md`; this file is the current method.

## What a card shows

- A snapshot of a fight: a mage casting on the battlefield, or a battlemage channeling through a weapon. Never scenery or an object alone. The roster's `Art brief` is the spell's flavour, not the subject.
- The spell touches the rival and the rival reacts. A hit engulfs or breaks around the rival; it never passes through the body like a beam. Only a couple of the rival's elements (head, raised arms, a boot) show through the effect.
- Rivals need little detail. They are there to get blasted: a strong reaction pose and a clean silhouette.
- A named character is their identity (below) and follows `cast.md` and their personality portrait. Anonymous figures use house identities such as `draik_duelist`.
- Profile views are banned: they flatten the fight into a frieze. Over the shoulder (back three-quarter, a sliver of cheek) or a low spectator view.
- A two-handed cast shows water, fire or light leaving BOTH hands as two streams that join. One stream from one hand fails the brief even when both hands are visible.
- No symbol that reads as a real-world icon.

## Style

- Rich, detailed pixel art, not low-fidelity retro. The target is the personality portraits (`assets/card_art/personality/`): many tones per material, hue-shifted shadows (toward violet and indigo) and lights (toward warm white), crisp dark line work, clear strands in hair.
- Cards build at double resolution: 452x320, `scale = 2` in the card scene. The 3D render is 904x640.
- Stylisation is welcome when it makes the fight pop: coloured outlines (a school-coloured rim on the spell-facing side), a thin frame in school colours, navy outlines round the spell.
- Backgrounds stay quiet: a narrow, dark value range and low saturation. The figures and the spell carry the card. A saturated sky, even a good one, distracts.
- The school colour is the only high-chroma family, and it belongs to the magic. Tide runs navy to teal, with sea-glass and white foam only on crests, tips and spray.

## Pipeline

Everything below lives in the Kit, `F:\UnityNVME\Art\_Zenith\Kit\`. Paths are relative to it.

1. **Identities.** Each person is `identities/<name>.json`: a Quaternius base body, modular outfit parts and a hair mesh, all rebound to one armature, each mesh mapped to a kit material (`plate`, `trim`, `hood`, `hair`, `skin`, `cloak`, `lining`, `iron`).
2. **3D scene.** `blockout/<card>.json` places identities with an animation snapshot, a camera, lights, and the spell as geometry. Render headless:
   `"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" -b --factory-startup --python blockout/render_identities.py -- blockout/<card>.json <out_dir>`
   It writes `light.png`, `spell.png`, `albedo.png`, `ids.png`, `ids.json` and `anchors.lua` (card coordinates of hands, head, chest, pelvis).
3. **Convert.** `python blockout/to_grid.py <out_dir> blockout/<card>_map.json <prefix> --scale 1` writes one kit part per role: `<prefix>_caster.txt`, `<prefix>_rival.txt`, `<prefix>_fx.txt` (the spell). Copy them to `figure/3d/`, and `anchors.lua` to `scenes/anchors/<card>.lua`.
4. **Card scene.** `scenes/<card>.lua` lists the parts in `figures_1x` (caster on `Caster`, rival on `Rival`, the spell on `Spell front`), the backdrop, palettes, outlines and frame.
5. **Build** through the aseprite MCP `run_lua_script`:
   `local B = dofile("F:/UnityNVME/Art/_Zenith/Kit/build.lua"); B.build(dofile("F:/UnityNVME/Art/_Zenith/Kit/scenes/<card>.lua"))`
   Output: `F:\UnityNVME\Art\_Zenith\Tests\Cards\<out>.png` and `.aseprite`.
6. **Check.** `python F:\UnityNVME\Art\_Zenith\Tests\_scripts\cards\check.py <card.png> <out.png>`: colours (72 or fewer), loose pixels (3 or fewer), a 3x view, a hand-size thumbnail and a 4-value map. The value-share targets were set for the old light sky; with a quiet dark backdrop judge values by eye.
7. **Review** with fresh adversarial reviewers (below). Fix figure problems in 3D, the identity or the converter map; fix staging in the card scene.

### 3D scene keys (`blockout/<card>.json`)

- `size` [904, 640]; `camera` {`loc`, `target`, `lens`, `roll`}. Lens 40 at about 2 m keeps the caster from filling half the card.
- `actors`: `identity`, `role` (caster, rival), `loc`, `rot_z`, `scale`, `anim` {`file`, `action`, `frame`} from the Universal Animation Library 1 and 2, `pose` (small bone tweaks in degrees, added to the clip), `bone_scale` (stylised proportions, e.g. hands 1.35).
- `flat_shading` false for the vibrant style (true gave faceted planes); `cast_shadows` false (cast shadows convert to camouflage blotches); `smooth` lists meshes kept smooth.
- `key` {`dir` toward the light, `energy`}, `fill` {`dir`, `energy`} a shadowless sun so a figure seen from behind gets a lit side and a shadow side, `spell` {point light at the spell}, `sky` ambient (0.3).
- `water` (the spell as metaballs): `feeders` from finger bones (`caster.middle_02_l`) with `r0`, `r1`, `bow`; `target` (bone list, averaged); `knot` (where the feeders join, 0 to 1 toward the target) and `knot_offset`; `trunk_r`, `trunk_flare`; `cuff` (a swirl round each hand); `engulf` {`radius`, `front` (push toward camera so it covers the body), `blobs`, `blob_r`, `sheets`, `sheet_len`, `drops`, `away`}; `displace` {`strength`, `size`, `stretch` along the flow}; `foam` {`dir`, `up`, `island`, `far`, `knot`} a second material for white water; `ripple`, `resolution`, `seed`. Other elements can reuse this block with their own ramps.
- `psx` plus `--psx` on the command line renders a PS1-style test instead (flat colours, `psx_post.py` dithers it). Parked: without textures it reads as an untextured blockout.

### Identity keys (`identities/<name>.json`)

- `base`, `parts`, `hide`, `base_keep_bones` (keep only head, neck and hands of the base body), `materials` (mesh pattern to kit material).
- `drop_bones` cuts outfit vertices by bone (gloves off so bare hands show). `stretch` lengthens a mesh in rest pose (long hair past the collar); shading stays consistent, unlike a painted overlay. `smooth` keeps a mesh smooth.

### Converter map keys (`blockout/<card>_map.json`)

- `ramps` (palette files), `ramp_override` (match a card's `palette_override`), `steps` per material, `base` (the ramp step the darkest shade uses, so white plate sits high; skin from step 2 or it reads orange-brown), `shares` (percentile cuts), `soften` (blur a material's light over nearby cells before the cut: hair 2 turns barcode strands into locks), `detail` (albedo texture detail, `null` to turn off per material), `cluster` (passes that turn shading bands into solid clusters), `inner_lines` with `no_line` (a dark line where two materials meet; never on water or foam), `rim` and `rim_share` (spell-facing edge light), `gamma`.
- Vibrant long ramps live in `palettes/*_v.lua` (7 to 11 steps, hue-shifted). The `_hd` and short ramps stay for older parts.

### Card scene keys (`scenes/<card>.lua`)

- `scale` 2, `ramps`, `palette_override`, `horizon`, `flags`, `vp_x`, `dark_foreground`.
- `backdrop` {`file`, `at`}: a pack background recoloured by brightness into a quiet ramp (`backdrops/*_quiet.png`); `at` is in 226x160 card coordinates.
- `figures_1x`, `outlines` (per layer: `{color, lit, lit_color}` or a list of open sides), `border` (hex colours outside in, one card pixel each).
- Hooks: `<layer>_1x(img, R, B)` draws on a layer at full size after the figures; `detail_1x(d, R, B)` draws on a top layer. Place hand refinements from `anchors.lua`, never fixed pixels: every re-render moves the figures.

## What worked

- Posing real rigged characters from an animation library, then converting, instead of drawing figures from polygons or formulas.
- Building the spell in 3D with the figures. Depth decides what the water covers, the join of two streams merges naturally, and it shares the figures' shading. Nine cycles of 2D generated water never read as water.
- A foam material on up-facing faces, drops and far spray, plus noise stretched along the flow. Without them 3D water reads as plastic tubes.
- A shadowless fill light for over-the-shoulder casters; bare hands at about 1.15x (1.35x read oversized at double resolution).
- Casting hands as open palms toward the target (Alder `hand_r` [0, 0, -65] on Spell_Simple_Shoot frame 5), and the stream starting a hand's width in front of the palm (feeder `from` the hand bone with `lead` 0.1, no `cuff`). The hand then overlaps the start of the water. Streams started at the fingers read as the hands gripping a pipe.
- Try wrist and hand tweaks on a contact sheet first: render several small variants of one bone (each axis, both signs) without the spell and pick by eye. The rig's axes are not guessable.
- Break a light costume into two materials so the figure is not one white blob (Alder: indigo sleeves under white vambraces). Hide duplicate outfit pieces that stack (a second belt read as a tyre).
- Turn the head with a small `pose` yaw (Alder `Head` [0, -40, 0]) and scale it slightly (`bone_scale` Head 1.12) so the caster has a face; past about -50 the nose shows and it drifts toward profile.
- Recoloured pack backgrounds (`F:\UnityNVME\Art\Backgrounds\`) for shapes, kept quiet in value and colour.
- Double resolution with long hue-shifted ramps for the vibrant look.
- Fresh reviewers each cycle with a skeptical rating, plus a specialist who must test fixes before proposing them.

## What to avoid

- Figures drawn as polygons or with formula shading: clip art.
- Mixing pixel densities without intent. Half-size environment under full-size figures was flagged every cycle; a chunky background is fine only when it is quiet.
- Smooth light cut by percentile with cast shadows on: it looks traced (rotoscoped). Flat facets fixed that but read posterised; smooth shading plus fill light plus long ramps is the current balance.
- Stylised overlays painted over rendered parts (a drawn hair wedge clashed with rendered shading). Change the mesh instead.
- Hand-set bone rotations beyond small tweaks: the poses looked crazy. Pick another frame or clip.
- Fixed-coordinate hand refinements. They break on the next render.
- Water shapes: a smooth even jet reads as a limb or hose; a late join between diverging streams reads as open jaws; a round mass over the body reads as a figure; straight radial sheets read as glass or crystal; even petals read as a mace; foam through the middle reads as a lightning bolt; the converter's inner lines on water read as cracks.
- A bright moon or cloud break larger than the spell: the eye goes there.
- The caster's lit plate as the brightest mass on the card: the eye lands on her back, not the impact.
- Low-poly meshes with flat colours rendered straight (the PSX test): they read as blockouts.

## Review loop

- Write a short brief (target, files, user rules, style direction) in the scratchpad. Each cycle, fresh reviewers read it and judge the card at 1x, 3x and 110 px: a skeptical judge (overall rating, 8.5 = ships next to strong commercial pixel-art card games) and one or two specialists (figures, effects).
- Specialists test their fixes in their own folders before proposing them. Untested suggestions from reviewers often contradict each other across cycles (the join point swung back and forth).
- Judges plateaued around 6 to 6.5 while parameters changed; structural changes (3D water, double resolution, bare hands, fill light) moved the card more than tuning.

## Aseprite and tool gotchas

- `spr:newCel(layer, frame, img)` copies `img`. Draw first, then make the cel.
- `K.stamp` errors when a part's `scale` does not match the layer. Figure parts use `layer_scale = 1`.
- Blender: ID colours must be converted sRGB to linear or they come back shifted; import animation libraries before entering pose mode; `key.dir` points toward the light; the render output folder must exist; a multi-material object (water plus foam) must keep its slots through the ID swap.
- `render_identities.py` anchors are in 226x160 card coordinates; multiply by `scale` on a 2x card.

## Files

- Kit: `F:\UnityNVME\Art\_Zenith\Kit\` (`identities/`, `blockout/`, `palettes/`, `backdrops/`, `figure/3d/`, `scenes/`, `build.lua`, `kit.lua`)
- Models: `F:\UnityNVME\Art\Models\Quaternion\` (Universal Base Characters, Modular Character Outfits - Fantasy, Universal Animation Library 1 and 2)
- Outputs: `F:\UnityNVME\Art\_Zenith\Tests\Cards\`
- Install: `assets/card_art/<school>/<card id>.png`. The art size changed to 452x320 with the double-resolution method; confirm the card face handles it before installing. Install only after the user approves.
