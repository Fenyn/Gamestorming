# Ungilded sprite normal maps (step 3 prep)

Status: built 2026-10-21 for the Prologue sprites (37 pages). The visible gain in the sewer is
small; see "Result" at the end.

Goal: each unit and actor frame gets a normal page of the same size, so a torch shades the
body's shape (folds, limbs, head) instead of the flat left/right `bend` the shader uses now.
Lighting must keep floor parity: a sprite in a torch pool stays as bright as the stone under it.

## What needs a normal page

Paths are under `ungilded/assets/sprites/`. One normal PNG per frame PNG.

| Group | Folder | Frames | Frame size | Used by |
|---|---|---|---|---|
| Prologue heroes | `heroes/player`, `heroes/friend` | 6 each (base, rest_1..5) | 64x72 | combat token, cutscene actor |
| Prologue rats | `enemies/rat_v1`, `rat_v2`, `rat_v3` | 8 each | 62x44 | combat, cutscene (`tyrant_rat_v2` reuses `rat_v2` frames) |
| Fringe enemies | `boar_base`, `dire_wolf_base`, `giant_monitor_lizard_base`, `giant_stag_beetle_base`, `giant_viper_base`, `goblin_base`, `grizzly_bear_base`, `kobold_base`, `spider_base`, `viper_base`, `wolf_base` | 12 each | 56x64 to 120x56 | combat harness, previews |
| Placeholders | `placeholder_small`, `_medium`, `_large` | 8 each | 48x36, 56x80, 96x120 | missing art only; skip |
| Mana Seed heroes | `heroes/cleric`, `recruit`, `rogue`, `veteran`, `wizard` | 4 pages each, 8x8 cells of 64 px | 512x512 page | harness presets only; skip until the Prologue uses them |
| Hand lantern | `decor/lantern.png` | 1 | 9x14 | Friend's lantern |

Prologue total: 12 hero frames and 24 rat frames, 36 normal pages. With the Fringe enemies it is
168 frames.

Not in scope: sewer and forest decor (`decor/sewer`, `decor/forest`, `decor/trees`) draw through
`StandardMaterial3D` with `Shaded` on, and flat floor decals gain nothing from a normal. Emotes are
unshaded.

## Where each texture is bound

- Units and cutscene actors draw through `scenes/combat/billboard_sprite.tscn`, material override
  `assets/shaders/lit_sprite.gdshader`.
- `BillboardSpriteAnimator.RefreshLighting` runs before every frame and writes the current
  `Texture` to `sprite_tex` and the feet height to `feet_y`. Authored folders (heroes with a
  `sprite.tres`, all enemies) change `Texture` per frame through `EnemyAnimationPlayer`. Mana Seed
  heroes keep one page and pick the cell with `Hframes`, `Vframes` and `Frame`.
- `hand_lantern.tscn` binds `lantern.png` to `sprite_tex` in the scene.

## Shader change

1. Add `uniform sampler2D normal_tex : hint_normal, filter_nearest, repeat_disable;` and
   `uniform bool has_normal_tex = false;`.
2. Decode `n = texture(normal_tex, UV).rgb * 2.0 - 1.0`. The quad faces the camera, so the map's
   x, y and z are the view's x, y and z. When `dFdx(UV.x) < 0` (FlipH), negate `n.x`.
3. Mix with the current world-up normal: `NORMAL = normalize(mix(up_normal, n, normal_share))`,
   with `normal_share` near 0.5 to start. A pure camera-facing map starves the sprite again when the
   torch is behind it, which is what the up normal fixed.
4. Keep `LIGHT_VERTEX` at the feet and keep the shadow pass as it is. The normal changes shading
   only.
5. When `has_normal_tex` is true, `bend` is not used. (Changed when built; see "Result".)

## Loader change

- In `RefreshLighting`, when `Texture` changes, look up its normal page in a dictionary cache keyed
  by the colour texture. Load `<frame>_n.png` from the same folder if it exists, else bind nothing
  and set `has_normal_tex` false. Put the suffix in one constant.
- Mana Seed pages: `<page>_n.png` on the same 8x8 grid. The UV is the same, so no other change.
- A frame with no normal page must still draw. Missing pages are a warning in the sprite spikes, not
  an error.

## File naming and import

- `idle_3.png` gets `idle_3_n.png` beside it, same size, same alpha mask. Commit the source or
  script that made it next to the masters in `design/`.
- Green channel points up (OpenGL convention, as Godot expects). Laigter and SpriteIlluminator can
  export either way, so set it once and check it (see below).
- Import: `compress/mode` Lossless, `compress/normal_map` Enable, `mipmaps/generate` off. Filtering
  comes from the shader hint.
- Fully transparent pixels: write (128, 128, 255). Alpha scissor discards them, but a wrong colour
  there bleeds in if filtering is ever turned on.

## Tools

- **Laigter**: free, open source desktop tool. Makes normal, parallax, specular and occlusion maps
  from a sprite, with a live light preview. Batch runs from the GUI. Good for a quick first pass.
- **SpriteIlluminator** (CodeAndWeb, paid): bevel and emboss from the alpha edge plus hand painting
  of normals. Better control on hair and cloth folds.
- **Script** (Python, numpy and PIL): height = blurred distance from the alpha edge (a soft bevel)
  plus a small share of luma, then normals from the Sobel gradient of the height. Runs over every
  frame the same way, so a re-export of the art can regenerate all pages in one command. It has the
  most predictable output for agent work, and a good default for step 3.
- Hand edits in Aseprite on top of any of these, for faces and weapons.

Pixel-art rule: one normal per source pixel, no smoothing across the alpha edge, and no detail
smaller than the art's own shading.

## How to check

1. Format check (script): every frame has a page, sizes match, alpha masks match, transparent
   pixels are (128, 128, 255), every opaque normal has length 1 within 2 %.
2. Light sweep: a dev scene or spike case puts one omni light left, right, in front and behind a
   standing unit and saves four stills side by side. Left light must brighten the left edge. If up
   and down are swapped, the green channel is inverted.
3. FlipH: the same sweep with the unit flipped. The lit side must stay on the light's side.
4. Floor parity: `sewer_look_shot_spike` `sewer_lit_pool.png`. The body's mean brightness must stay
   close to the stone beside it, as it is now without maps.
5. Look at 1x and 6x beside the current frames before calling it done (art quality gate).

## Result (2026-10-21)

- Generator: `ungilded/tools/art/sprite_normals.py`. Defaults `--bevel 6 --depth 3 --luma 1.5`.
  `--check` runs the format check. It also writes each page's `.import` params (lossless, normal
  map, no mipmaps, `fix_alpha_border` off, `detect_3d/compress_to` off so Godot never switches the
  page to VRAM compression).
- Shader: the plan's `mix(up, n, normal_share)` was tried first. It made the body darker than the
  floor under a light behind it (sweep mean 0.16 behind against 0.33 in front), and its side
  shading was weaker than `bend`. The built shader adds the page's x and y slope to world up
  (`normal_share` 1.0) and keeps `bend`. A flat pixel keeps world up, so floor parity holds from
  every side.
- Light direction: `LIGHT_VERTEX` stays at the feet, so every pixel shares one light direction.
  Godot's `light()` gets no light position, so the direction cannot come from the pixel while the
  attenuation and shadow come from the feet. A sample point up the body falls behind the shadow
  quad and shadows itself.
- Checks: `light_sweep_spike` (rendered) saves `dev_shots/light_sweep.png` and checks that a side
  light brightens its own side, flipped and not flipped.
- Lighting pass after the maps (approved 2026-10-21): `light_on_axis` takes each pixel's light at
  its own height on the body axis, `face_camera` 0.5, and a wrap `light()`. The sewer ambient is a
  sky gradient at 0.5 (cool above, warm dark below), so ambient now changes with the normal. A face
  lit from one side has a dark half, and that is intended.
- Open: boards without torches are very dark, and the normal pages leave smudges on the back of
  the hair.
